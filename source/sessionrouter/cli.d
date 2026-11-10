module sessionrouter.cli;

enum catalogVersion = "0.1.0";

import std.stdio : stderr, writeln;
import std.string : indexOf, replace, startsWith;

import sessionrouter.catalog : loadApp;
import sessionrouter.doors : Door, DoorError, repairChecklist, selectDoor;
import sessionrouter.state : ComposerNotFound, LiveDatabaseRefused, writeUserBubble;
import sessionrouter.versioning : VersionError, resolveProfile;

struct Args
{
    string profiles;
    string command;
    string app;
    string versionText;
    string operation;
    string chatId;
    string text;
    string db;
    string profileVersion;
    bool worstCase;
    bool iUnderstand;
}

int run(string[] argv, string defaultProfiles)
{
    Args args;
    string error;
    if (!parseArgs(argv, args, error))
    {
        stderr.writeln(error);
        return 1;
    }
    if (args.profiles.length == 0)
        args.profiles = defaultProfiles;
    if (args.command == "version")
    {
        writeln(catalogVersion);
        return 0;
    }
    if (args.command == "repair-needed")
    {
        writeln(repairChecklist(args.app, args.versionText, args.profileVersion, args.operation));
        return 0;
    }
    Door door;
    try
    {
        bool inherited;
        auto profiles = loadApp(args.profiles, args.app);
        auto profile = resolveProfile(profiles, args.versionText, inherited);
        door = selectDoor(profile, args.operation, inherited);
    }
    catch (VersionError exc)
    {
        stderr.writeln(exc.msg);
        return 1;
    }
    catch (DoorError exc)
    {
        stderr.writeln(exc.msg);
        return 1;
    }
    if (args.command == "resolve")
    {
        printDoor(args, door);
        return 0;
    }
    if (args.command != "submit")
    {
        stderr.writeln("Unknown command " ~ args.command);
        return 1;
    }
    if (door.inherited)
        writeln(repairChecklist(args.app, args.versionText, door.profileVersion, args.operation));
    if (door.kind == "mcp")
    {
        writeln("Call the harness MCP tool: " ~ door.detail);
        return 0;
    }
    if (door.kind == "cli")
    {
        writeln("cli=" ~ door.detail.replace("{chatId}", args.chatId));
        return 0;
    }
    if (door.kind == "hack")
    {
        writeln("hack=" ~ door.detail);
        return 0;
    }
    if (door.kind != "worst_case" || door.detail != "state-db")
    {
        stderr.writeln("No submitter for door " ~ door.kind ~ ".");
        return 1;
    }
    writeln(door.warning);
    if (args.db.length == 0)
    {
        stderr.writeln("Refusing to write without --db.");
        return 2;
    }
    try
    {
        auto bubbleId = writeUserBubble(args.db, args.chatId, args.text, args.worstCase, args.iUnderstand);
        writeln("bubble=" ~ bubbleId);
        writeln("conversationState was left unchanged. This write does not start a generation.");
        return 0;
    }
    catch (LiveDatabaseRefused exc)
    {
        stderr.writeln(exc.msg);
        return 2;
    }
    catch (ComposerNotFound exc)
    {
        stderr.writeln(exc.msg);
        return 1;
    }
}

private void printDoor(Args args, Door door)
{
    writeln("door=" ~ door.kind);
    writeln("profile=" ~ door.profileVersion);
    writeln("inherited=" ~ (door.inherited ? "true" : "false"));
    writeln("detail=" ~ door.detail);
    if (door.warning.length)
        writeln(door.warning);
    if (door.inherited)
        writeln(repairChecklist(args.app, args.versionText, door.profileVersion, args.operation));
}

private bool parseArgs(string[] argv, ref Args args, out string error)
{
    if (argv.length < 2)
    {
        error = "Usage: session-router [--profiles DIR] version|resolve|repair-needed|submit ...";
        return false;
    }
    size_t index = 1;
    while (index < argv.length && argv[index].startsWith("--"))
    {
        if (!takeFlag(argv, index, args, error))
            return false;
    }
    if (index >= argv.length)
    {
        error = "Missing command.";
        return false;
    }
    args.command = argv[index];
    index++;
    while (index < argv.length)
    {
        if (!takeFlag(argv, index, args, error))
            return false;
    }
    if (args.command == "version")
        return true;
    if (args.command == "repair-needed")
        return require(args.app, "--app", error) && require(args.versionText, "--version", error)
            && require(args.profileVersion, "--profile-version", error)
            && require(args.operation, "--operation", error);
    if (args.command == "resolve")
        return require(args.app, "--app", error) && require(args.versionText, "--version", error)
            && require(args.operation, "--operation", error);
    if (args.command == "submit")
        return require(args.app, "--app", error) && require(args.versionText, "--version", error)
            && require(args.operation, "--operation", error) && require(args.chatId, "--chat-id", error)
            && require(args.text, "--text", error);
    error = "Unknown command " ~ args.command;
    return false;
}

private bool takeFlag(string[] argv, ref size_t index, ref Args args, out string error)
{
    auto flag = argv[index];
    if (flag == "--worst-case")
    {
        args.worstCase = true;
        index++;
        return true;
    }
    if (flag == "--i-understand")
    {
        args.iUnderstand = true;
        index++;
        return true;
    }
    if (index + 1 >= argv.length)
    {
        error = "Missing value for " ~ flag;
        return false;
    }
    auto value = argv[index + 1];
    switch (flag)
    {
    case "--profiles":
        args.profiles = value;
        break;
    case "--app":
        args.app = value;
        break;
    case "--version":
        args.versionText = value;
        break;
    case "--operation":
        args.operation = value;
        break;
    case "--chat-id":
        args.chatId = value;
        break;
    case "--text":
        args.text = value;
        break;
    case "--db":
        args.db = value;
        break;
    case "--profile-version":
        args.profileVersion = value;
        break;
    default:
        error = "Unknown argument " ~ flag;
        return false;
    }
    index += 2;
    return true;
}

private bool require(string value, string flag, out string error)
{
    if (value.length)
        return true;
    error = "Missing " ~ flag ~ ".";
    return false;
}

unittest
{
    assert(repairChecklist("cursor", "9.0.0", "3.29.15", "prompt-existing-desktop-chat")
        .indexOf("Fork this catalog") >= 0);
}
