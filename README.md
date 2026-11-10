<div align="center">

<a href="https://github.com/dev-centr/agent-bus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/dev-centr/agent-bus?style=for-the-badge" alt="License"></a>
<a href="https://github.com/dev-centr/agent-bus/issues"><img src="https://img.shields.io/github/issues/dev-centr/agent-bus?style=for-the-badge" alt="Issues"></a>

# Agent bus

An agent uses this catalog to drive a harness, including the harness it is already in. The command picks the door for that harness release.

People wiring an agent to an existing chat, or recording what to do when a studio removes a command, use this catalog instead of inventing a one-off each time.

</div>

## Install

From the registry:

```shell
dub fetch agent-bus
```

From a checkout, the command is a Dub executable. If DMD is not on `PATH`, pass `--compiler=ldc2`.

```shell
dub build --compiler=ldc2
```

## Use

Resolve the door for a Cursor release. A version that has no profile uses the newest older one, and the command prints the fork-and-pull-request checklist.

```shell
dub run --compiler=ldc2 -- resolve --app cursor --version 3.29.15 --operation prompt-existing-desktop-chat
```

`layer=mcp` means the harness's own MCP carries the action, and that MCP may route it inside the harness. `layer=harness-commander` means the hop leaves that MCP pattern: a CLI wrapper, a hack profile, or the warned state-database write.

Resume of a CLI session is a harness-commander hop:

```shell
dub run --compiler=ldc2 -- resolve --app cursor --version 3.29.15 --operation resume-cli-session
```

The state-database writer is the last door. It refuses a live Cursor database unless you pass both `--worst-case` and `--i-understand`. It inserts a user bubble and leaves the conversation blob unchanged, so it does not start a generation.

## Profiles

Add `profiles/<app>/<version>.json` with `mcp`, `cli`, `hack`, and `worst_case` for each operation. Read `removed-features.md` before adding a door.

## Built with

**Runtime**

- [D](https://dlang.org/) and [Dub](https://dub.pm/)
- [LDC](https://github.com/ldc-developers/ldc) when DMD is not installed
- [d2sqlite3](https://github.com/dlang-community/d2sqlite3) and the SQLite library it ships, for the last-resort composer write

## Changelog

See [CHANGELOG.adoc](CHANGELOG.adoc).
