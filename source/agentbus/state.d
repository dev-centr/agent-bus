module agentbus.state;

import std.array : replace;
import std.datetime : Clock, UTC;
import std.json : JSONValue, parseJSON;
import std.string : endsWith, indexOf, toLower;
import std.uuid : randomUUID;

import d2sqlite3 : Database;

import agentbus.doors : worstCaseWarning;

class LiveDatabaseRefused : Exception
{
    this(string file = __FILE__, size_t line = __LINE__)
    {
        super(worstCaseWarning ~ " Pass --worst-case and --i-understand to write a live database.", file, line);
    }
}

class ComposerNotFound : Exception
{
    this(string composerId, string file = __FILE__, size_t line = __LINE__)
    {
        super("Composer " ~ composerId ~ " was not in the database.", file, line);
    }
}

bool isLiveCursorDb(string path)
{
    auto text = path.replace("/", "\\").toLower;
    return text.endsWith("\\globalstorage\\state.vscdb") && text.indexOf("\\cursor\\user\\") >= 0;
}

string richText(string prompt)
{
    JSONValue leaf;
    leaf["type"] = "text";
    leaf["text"] = prompt;
    JSONValue paragraph;
    paragraph["type"] = "paragraph";
    paragraph["content"] = [leaf];
    JSONValue doc;
    doc["type"] = "doc";
    doc["content"] = [paragraph];
    return doc.toString();
}

string writeUserBubble(string dbPath, string composerId, string prompt, bool worstCase, bool iUnderstand)
{
    if (isLiveCursorDb(dbPath) && !(worstCase && iUnderstand))
        throw new LiveDatabaseRefused();
    auto bubbleId = randomUUID.toString();
    auto now = Clock.currTime(UTC());
    auto created = now.toISOExtString();
    long nowMs = now.toUnixTime!long() * 1000;

    JSONValue bubble;
    bubble["_v"] = 3;
    bubble["type"] = 1;
    bubble["bubbleId"] = bubbleId;
    bubble["text"] = prompt;
    bubble["richText"] = richText(prompt);
    bubble["createdAt"] = created;
    bubble["isAgentic"] = false;
    bubble["unifiedMode"] = 2;
    bubble["conversationState"] = "";

    auto db = Database(dbPath);
    scope (exit)
        db.close();
    auto dataKey = "composerData:" ~ composerId;
    auto found = db.execute("SELECT value FROM cursorDiskKV WHERE key = ?1", dataKey);
    string raw;
    bool have;
    foreach (row; found)
    {
        raw = row.peek!string(0);
        have = true;
    }
    if (!have)
        throw new ComposerNotFound(composerId);
    auto data = parseJSON(raw);
    auto beforeState = data["conversationState"].str;
    data["text"] = prompt;
    data["richText"] = richText(prompt);
    data["lastUpdatedAt"] = nowMs;
    if (data["conversationState"].str != beforeState)
        throw new Exception("Refusing to change conversationState.");
    db.execute(
        "INSERT INTO cursorDiskKV (key, value) VALUES (?1, ?2)",
        "bubbleId:" ~ composerId ~ ":" ~ bubbleId,
        bubble.toString());
    db.execute("UPDATE cursorDiskKV SET value = ?1 WHERE key = ?2", data.toString(), dataKey);
    auto headers = db.execute("SELECT value FROM composerHeaders WHERE composerId = ?1", composerId);
    foreach (row; headers)
    {
        auto headerValue = parseJSON(row.peek!string(0));
        headerValue["lastUpdatedAt"] = nowMs;
        db.execute(
            "UPDATE composerHeaders SET lastUpdatedAt = ?1, value = ?2 WHERE composerId = ?3",
            nowMs,
            headerValue.toString(),
            composerId);
    }
    return bubbleId;
}

unittest
{
    assert(isLiveCursorDb(`C:\Users\rjamd\AppData\Roaming\Cursor\User\globalStorage\state.vscdb`));
    bool refused;
    try
        writeUserBubble(`C:\Users\rjamd\AppData\Roaming\Cursor\User\globalStorage\state.vscdb`, "nope", "hello", false, false);
    catch (LiveDatabaseRefused)
        refused = true;
    assert(refused);

    import std.file : mkdirRecurse, rmdirRecurse, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto dir = buildPath(tempDir, "agent-bus-db-" ~ randomUUID.toString());
    mkdirRecurse(dir);
    scope (exit)
        rmdirRecurse(dir);
    auto dbPath = buildPath(dir, "state.vscdb");
    {
        auto db = Database(dbPath);
        db.execute("CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value TEXT)");
        db.execute("CREATE TABLE composerHeaders (composerId TEXT PRIMARY KEY, lastUpdatedAt INTEGER, value TEXT)");
        db.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?1, ?2)",
            "composerData:cid",
            `{"conversationState":"opaque-blob","text":"","richText":""}`);
        db.execute(
            "INSERT INTO composerHeaders (composerId, lastUpdatedAt, value) VALUES (?1, ?2, ?3)",
            "cid",
            1,
            `{"composerId":"cid","lastUpdatedAt":1}`);
        db.close();
    }
    auto bubbleId = writeUserBubble(dbPath, "cid", "hello from the router", false, false);
    auto db = Database(dbPath);
    scope (exit)
        db.close();
    string bubbleRaw;
    foreach (row; db.execute("SELECT value FROM cursorDiskKV WHERE key = ?1", "bubbleId:cid:" ~ bubbleId))
        bubbleRaw = row.peek!string(0);
    auto bubble = parseJSON(bubbleRaw);
    assert(bubble["text"].str == "hello from the router");
    assert(bubble["type"].integer == 1);
    string dataRaw;
    foreach (row; db.execute("SELECT value FROM cursorDiskKV WHERE key = ?1", "composerData:cid"))
        dataRaw = row.peek!string(0);
    auto data = parseJSON(dataRaw);
    assert(data["conversationState"].str == "opaque-blob");
    assert(data["text"].str == "hello from the router");
}
