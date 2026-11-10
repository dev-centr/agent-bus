module sessionrouter.doors;

import std.string : format, indexOf;

import sessionrouter.versioning : Profile;

enum worstCaseWarning =
    "Warning. Writing straight into Cursor's state database to fake a prompt "
    ~ "submit can corrupt the chat store, deliver the prompt to the wrong "
    ~ "composer, or break on the next app update.";

class DoorError : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

struct Door
{
    string kind;
    string detail;
    bool inherited;
    string profileVersion;
    string warning;
}

Door selectDoor(Profile profile, string operation, bool inherited)
{
    bool known;
    foreach (name; profile.operations)
        if (name == operation)
            known = true;
    if (!known)
        throw new DoorError("Profile " ~ profile.versionText ~ " has no operation '" ~ operation ~ "'.");

    Door door;
    door.inherited = inherited;
    door.profileVersion = profile.versionText;
    if (auto mcp = operation in profile.mcp)
    {
        door.kind = "mcp";
        door.detail = *mcp;
        return door;
    }
    if (auto cli = operation in profile.cli)
    {
        import std.string : join;
        door.kind = "cli";
        door.detail = (*cli).join(" ");
        return door;
    }
    if (auto hack = operation in profile.hack)
    {
        door.kind = "hack";
        door.detail = *hack;
        return door;
    }
    if (auto worst = operation in profile.worstCase)
    {
        door.kind = "worst_case";
        door.detail = *worst;
        door.warning = worstCaseWarning;
        return door;
    }
    throw new DoorError("Operation '" ~ operation ~ "' has no door in profile " ~ profile.versionText ~ ".");
}

string repairChecklist(string app, string failedVersion, string profileVersion, string operation)
{
    return format!"The inherited hack needs a fix.
Fork this catalog, not the %s harness.
Add or patch profiles/%s/ for version %s.
It was tried with the profile from %s for operation %s.
Open a pull request upstream that names the app, the version that failed,
the older profile, and the change that made the hack work."(app, app, failedVersion, profileVersion, operation);
}

unittest
{
    import sessionrouter.versioning : Profile;

    Profile profile;
    profile.versionText = "3.29.15";
    profile.operations = ["prompt-existing-desktop-chat", "resume-cli-session"];
    profile.worstCase["prompt-existing-desktop-chat"] = "state-db";
    profile.cli["resume-cli-session"] = ["agent", "--resume", "{chatId}"];

    auto worst = selectDoor(profile, "prompt-existing-desktop-chat", false);
    assert(worst.kind == "worst_case");
    assert(worst.detail == "state-db");
    assert(worst.warning.indexOf("corrupt the chat store") >= 0);

    auto cli = selectDoor(profile, "resume-cli-session", false);
    assert(cli.kind == "cli");
    assert(cli.detail == "agent --resume {chatId}");
}
