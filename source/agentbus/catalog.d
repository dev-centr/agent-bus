module agentbus.catalog;

import std.algorithm : sort;
import std.file : dirEntries, exists, isDir, readText, SpanMode;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : buildPath;

import agentbus.versioning : Profile, VersionError;

Profile[] loadApp(string root, string app)
{
    auto folder = buildPath(root, app);
    if (!exists(folder) || !isDir(folder))
        throw new VersionError("No profiles for app '" ~ app ~ "' under " ~ folder ~ ".");
    string[] paths;
    foreach (entry; dirEntries(folder, "*.json", SpanMode.shallow))
        paths ~= entry.name;
    sort(paths);
    if (paths.length == 0)
        throw new VersionError("No JSON profiles in " ~ folder ~ ".");
    Profile[] found;
    foreach (path; paths)
        found ~= readProfile(path);
    return found;
}

private Profile readProfile(string path)
{
    auto json = parseJSON(readText(path));
    Profile profile;
    profile.versionText = json["version"].str;
    auto operations = json["operations"].object;
    foreach (name, spec; operations)
    {
        profile.operations ~= name;
        storeOptional(profile.mcp, name, spec, "mcp");
        storeArray(profile.cli, name, spec, "cli");
        storeOptional(profile.hack, name, spec, "hack");
        storeOptional(profile.worstCase, name, spec, "worst_case");
    }
    return profile;
}

private void storeOptional(ref string[string] target, string operation, JSONValue spec, string field)
{
    if (field !in spec)
        return;
    auto value = spec[field];
    if (value.type == JSONType.null_)
        return;
    target[operation] = value.str;
}

private void storeArray(ref string[][string] target, string operation, JSONValue spec, string field)
{
    if (field !in spec)
        return;
    auto value = spec[field];
    if (value.type == JSONType.null_)
        return;
    string[] items;
    foreach (item; value.array)
        items ~= item.str;
    if (items.length)
        target[operation] = items;
}

unittest
{
    import std.file : mkdirRecurse, rmdirRecurse, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto root = buildPath(tempDir, "agent-bus-profiles-" ~ randomUUID.toString());
    mkdirRecurse(buildPath(root, "cursor"));
    scope (exit)
        rmdirRecurse(root);
    write(buildPath(root, "cursor", "3.29.15.json"), `{
        "app": "cursor",
        "version": "3.29.15",
        "operations": {
            "prompt-existing-desktop-chat": {"mcp": null, "cli": null, "hack": null, "worst_case": "state-db"},
            "resume-cli-session": {"mcp": null, "cli": ["agent", "--resume", "{chatId}"], "hack": null, "worst_case": null}
        }
    }`);
    auto profiles = loadApp(root, "cursor");
    assert(profiles.length == 1);
    assert(profiles[0].worstCase["prompt-existing-desktop-chat"] == "state-db");
    assert(profiles[0].cli["resume-cli-session"] == ["agent", "--resume", "{chatId}"]);
}
