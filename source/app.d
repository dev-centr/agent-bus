module app;

import std.file : exists, getcwd;
import std.path : buildPath;
import std.stdio : stderr;

import agentbus.cli : run;

int main(string[] argv)
{
    auto profiles = buildPath(getcwd(), "profiles");
    if (!exists(profiles))
    {
        stderr.writeln("No profiles directory in the working directory. Pass --profiles.");
    }
    return run(argv, profiles);
}
