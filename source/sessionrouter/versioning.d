module sessionrouter.versioning;

import std.conv : to;
import std.regex : matchFirst, regex;
import std.string : strip;

struct ReleaseVersion
{
    int major;
    int minor;
    int patch;
    int commitsAfter;
}

class VersionError : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

struct Profile
{
    string versionText;
    string[string] mcp;
    string[][string] cli;
    string[string] hack;
    string[string] worstCase;
    string[] operations;
}

ReleaseVersion parseVersion(string text)
{
    auto pattern = regex(`^(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g[0-9a-fA-F]+)?$`);
    auto hit = matchFirst(text.strip, pattern);
    if (hit.empty)
        throw new VersionError("Version '" ~ text ~ "' is not a release or a commits-after-release build.");
    ReleaseVersion parsed;
    parsed.major = to!int(hit[1]);
    parsed.minor = to!int(hit[2]);
    parsed.patch = to!int(hit[3]);
    parsed.commitsAfter = hit[4].length ? to!int(hit[4]) : 0;
    return parsed;
}

private int[3] baseOf(ReleaseVersion version_)
{
    return [version_.major, version_.minor, version_.patch];
}

Profile resolveProfile(Profile[] profiles, string versionText, out bool inherited)
{
    if (profiles.length == 0)
        throw new VersionError("No hack profiles are loaded.");
    auto requested = parseVersion(versionText);
    Profile* exact;
    foreach (ref profile; profiles)
    {
        auto parsed = parseVersion(profile.versionText);
        if (parsed.major == requested.major && parsed.minor == requested.minor
            && parsed.patch == requested.patch && parsed.commitsAfter == 0)
            exact = &profile;
    }
    if (requested.commitsAfter == 0 && exact !is null)
    {
        inherited = false;
        return *exact;
    }
    Profile* chosen;
    int[3] chosenBase = [-1, -1, -1];
    foreach (ref profile; profiles)
    {
        auto parsed = parseVersion(profile.versionText);
        auto base = baseOf(parsed);
        auto want = baseOf(requested);
        if (base[0] < want[0] || (base[0] == want[0] && base[1] < want[1])
            || (base[0] == want[0] && base[1] == want[1] && base[2] <= want[2]))
        {
            if (chosen is null || base[0] > chosenBase[0]
                || (base[0] == chosenBase[0] && base[1] > chosenBase[1])
                || (base[0] == chosenBase[0] && base[1] == chosenBase[1] && base[2] > chosenBase[2]))
            {
                chosen = &profile;
                chosenBase = base;
            }
        }
    }
    if (chosen is null)
        throw new VersionError("No hack profile is at or before " ~ versionText ~ ".");
    inherited = true;
    return *chosen;
}

unittest
{
    auto parsed = parseVersion("3.29.15-4-gabc1234");
    assert(parsed.major == 3 && parsed.minor == 29 && parsed.patch == 15);
    assert(parsed.commitsAfter == 4);

    Profile only;
    only.versionText = "3.29.15";
    bool inherited;
    auto exact = resolveProfile([only], "3.29.15", inherited);
    assert(!inherited && exact.versionText == "3.29.15");

    auto newer = resolveProfile([only], "3.30.0", inherited);
    assert(inherited && newer.versionText == "3.29.15");

    auto between = resolveProfile([only], "3.29.15-4-gabc1234", inherited);
    assert(inherited && between.versionText == "3.29.15");

    bool threw;
    try
        resolveProfile([only], "0.1.0", inherited);
    catch (VersionError)
        threw = true;
    assert(threw);
}
