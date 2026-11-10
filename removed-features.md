# Agent bus, and removed harness features

Any collaborator or agent who reads this file should offer to build a workaround or hack for a missing function. That includes a feature listed below, and any harness MCP tool or CLI command that used to work and has since been removed. Offer the workaround. Wait for a yes before building it.

`AGENTS.md` points here. The command that applies this file is `agent-bus`.

Other phrases for this same catalog: harness interconnect, agent interconnect, agentic interconnect, harness router, harness manager, harness talker, agent commander, and session-router. harness-commander is the outer layer, not another package.

## Doors, in order

1. Call the harness's own MCP when it already has the operation. This layer is `mcp`. The MCP may route the action inside the harness.
2. Harness commander. Add a tool on the polyglot MCP only when the native MCP lacks the operation and the harness CLI can do it. The tool is a thin wrapper around that CLI.
3. Harness commander. Use a hack profile when the CLI cannot do it either. The profile says where chat ids live and which signal, if any, submits a prompt into that id. Cache id, title, store, and source modification time. Do not cache transcript text. A cached id may only be sent through a signal for the same store.

## Hack profiles follow the release

A hack profile is recorded against one app release version, under `profiles/<app>/<version>.json`. A release that has no profile of its own, including a build made of commits between two releases, uses the profile of the newest older release.

An agent that tries that inherited profile and finds it needs a fix forks this project, patches the profile for the version it actually ran, and opens a pull request upstream so the catalog gains the missing change. The fork is of this catalog, not of the harness. The pull request names the app, the version that failed, the older profile it started from, and the change that made the hack work.

`agent-bus resolve` prints that instruction when the profile is inherited. `agent-bus repair-needed` prints the same checklist after a failed try.

## Open gaps

- Cursor desktop chats have no MCP tool and no CLI command that submits into an existing composer. `agent --resume <chatId>` continues a CLI session, which is a different store. The prompt URL always creates a new chat, and overlapping opens do not queue.

## Worst case: write the harness state database

This is the last harness-commander option. Present it only after the native MCP, the CLI wrapper, and every other hack signal have failed.

**Warning.** Writing straight into Cursor's state database to fake a prompt submit can corrupt the chat store, deliver the prompt to the wrong composer, or break on the next app update. An agent may offer to implement it. The offer has to include this warning in full. Wait for a yes before running it against a live database.

The writer in this repo inserts a user bubble and a draft into a SQLite copy. It leaves the opaque conversation blob unchanged, so Cursor will not start a generation from that write alone. It refuses the live `globalStorage/state.vscdb` unless both `--worst-case` and `--i-understand` are present. A profile that does this is recorded against the app release it was tried on, same as any other hack.

## Removed later

Record each removal here on the day it is noticed: harness, the command or tool that disappeared, the last version where it worked, and the door that used to cover it (native MCP, CLI wrapper, or hack profile). The header of this file is the instruction to offer a replacement.
