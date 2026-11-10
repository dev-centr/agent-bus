# Agent bus

Read `removed-features.md` before changing doors, profiles, or the state-database writer.

An agent drives a harness, including the one it is in. `layer=mcp` stays inside that harness's MCP. `layer=harness-commander` is the CLI wrapper, the hack profile, or the warned state-database write.

Hack profiles live in `profiles/<app>/<version>.json`. An unlisted release uses the newest older profile. If that inherited profile fails, fork this repo, patch the profile for the version that failed, and open a pull request. Do not fork the harness to record a catalog fix.

The state-database writer is the last door. Do not run it on a live Cursor database unless the person has accepted the warning in `removed-features.md` for that run.
