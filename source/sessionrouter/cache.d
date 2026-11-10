module sessionrouter.cache;

import std.file : exists, mkdirRecurse, readText, write;
import std.string : indexOf;
import std.json : JSONValue, parseJSON;
import std.path : dirName;

struct CacheRow
{
    string app;
    string store;
    string chatId;
    string title;
    long sourceMtime;
}

struct IndexCache
{
    string path;
    CacheRow[] rows;

    static IndexCache open(string path)
    {
        IndexCache cache;
        cache.path = path;
        if (exists(path))
        {
            auto parsed = parseJSON(readText(path));
            foreach (item; parsed.array)
            {
                CacheRow row;
                row.app = item["app"].str;
                row.store = item["store"].str;
                row.chatId = item["chat_id"].str;
                row.title = item["title"].str;
                row.sourceMtime = item["source_mtime"].integer;
                cache.rows ~= row;
            }
        }
        return cache;
    }

    void put(string app, string store, string chatId, string title, long sourceMtime)
    {
        CacheRow[] kept;
        foreach (row; rows)
        {
            if (row.app == app && row.store == store && row.chatId == chatId)
                continue;
            kept ~= row;
        }
        CacheRow next;
        next.app = app;
        next.store = store;
        next.chatId = chatId;
        next.title = title;
        next.sourceMtime = sourceMtime;
        kept ~= next;
        rows = kept;
        save();
    }

    CacheRow* getForStore(string app, string store, string chatId, long sourceMtime)
    {
        foreach (ref row; rows)
        {
            if (row.app == app && row.store == store && row.chatId == chatId)
            {
                if (row.sourceMtime != sourceMtime)
                    return null;
                return &row;
            }
        }
        return null;
    }

    private void save()
    {
        import std.path : dirName;
        mkdirRecurse(dirName(path));
        JSONValue[] items;
        foreach (row; rows)
        {
            JSONValue item;
            item["app"] = row.app;
            item["store"] = row.store;
            item["chat_id"] = row.chatId;
            item["title"] = row.title;
            item["source_mtime"] = row.sourceMtime;
            items ~= item;
        }
        JSONValue document = items;
        write(path, document.toPrettyString() ~ "\n");
    }
}

unittest
{
    import std.file : rmdirRecurse, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto dir = buildPath(tempDir, "session-router-cache-" ~ randomUUID.toString());
    scope (exit)
        rmdirRecurse(dir);
    auto cache = IndexCache.open(buildPath(dir, "index.json"));
    cache.put("cursor", "desktop", "abc", "Connectome", 10);
    assert(cache.getForStore("cursor", "desktop", "abc", 11) is null);
    assert(cache.getForStore("cursor", "cli", "abc", 10) is null);
    auto hit = cache.getForStore("cursor", "desktop", "abc", 10);
    assert(hit !is null && hit.title == "Connectome");
    import std.file : readText;
    assert(readText(buildPath(dir, "index.json")).indexOf("transcript") < 0);
}
