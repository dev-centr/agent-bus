"""Command line for the session router."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from session_router.catalog import load_app, profiles_root
from session_router.cursor_state import ComposerNotFound, LiveDatabaseRefused, write_user_bubble
from session_router.doors import DoorError, repair_checklist, select_door
from session_router.versioning import VersionError, resolve_profile


def _root(value: str | None) -> Path:
    if value:
        return Path(value)
    return profiles_root()


def _resolve(args: argparse.Namespace):
    profiles = load_app(_root(args.profiles), args.app)
    profile, inherited = resolve_profile(profiles, args.version)
    door = select_door(profile, args.operation, inherited=inherited)
    return profile, door


def cmd_resolve(args: argparse.Namespace) -> int:
    try:
        _profile, door = _resolve(args)
    except (FileNotFoundError, VersionError, DoorError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(f"door={door.kind}")
    print(f"profile={door.profile_version}")
    print(f"inherited={str(door.inherited).lower()}")
    print(f"detail={door.detail}")
    if door.warning:
        print(door.warning)
    if door.inherited:
        print(repair_checklist(args.app, args.version, door.profile_version, args.operation))
    return 0


def cmd_repair_needed(args: argparse.Namespace) -> int:
    print(repair_checklist(args.app, args.version, args.profile_version, args.operation))
    return 0


def cmd_submit(args: argparse.Namespace) -> int:
    try:
        _profile, door = _resolve(args)
    except (FileNotFoundError, VersionError, DoorError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    if door.inherited:
        print(repair_checklist(args.app, args.version, door.profile_version, args.operation))
    if door.kind == "mcp":
        print(f"Call the harness MCP tool: {door.detail}")
        return 0
    if door.kind == "cli":
        argv = [part.replace("{chatId}", args.chat_id or "") for part in door.detail]
        print("cli=" + " ".join(argv))
        return 0
    if door.kind == "hack":
        print(f"hack={door.detail}")
        return 0
    if door.kind != "worst_case" or door.detail != "state-db":
        print(f"No submitter for door {door.kind}.", file=sys.stderr)
        return 1
    print(door.warning)
    if not args.db:
        print("Refusing to write without --db.", file=sys.stderr)
        return 2
    try:
        bubble_id = write_user_bubble(
            Path(args.db),
            args.chat_id,
            args.text,
            worst_case=args.worst_case,
            i_understand=args.i_understand,
        )
    except LiveDatabaseRefused as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except ComposerNotFound:
        print(f"Composer {args.chat_id} was not in the database.", file=sys.stderr)
        return 1
    print(f"bubble={bubble_id}")
    print("conversationState was left unchanged. This write does not start a generation.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="session-router")
    parser.add_argument("--profiles", help="Directory that contains one folder per app.")
    sub = parser.add_subparsers(dest="command", required=True)

    resolve = sub.add_parser("resolve")
    resolve.add_argument("--app", required=True)
    resolve.add_argument("--version", required=True)
    resolve.add_argument("--operation", required=True)
    resolve.set_defaults(func=cmd_resolve)

    repair = sub.add_parser("repair-needed")
    repair.add_argument("--app", required=True)
    repair.add_argument("--version", required=True)
    repair.add_argument("--profile-version", required=True)
    repair.add_argument("--operation", required=True)
    repair.set_defaults(func=cmd_repair_needed)

    submit = sub.add_parser("submit")
    submit.add_argument("--app", required=True)
    submit.add_argument("--version", required=True)
    submit.add_argument("--operation", required=True)
    submit.add_argument("--chat-id", required=True)
    submit.add_argument("--text", required=True)
    submit.add_argument("--db")
    submit.add_argument("--worst-case", action="store_true")
    submit.add_argument("--i-understand", action="store_true")
    submit.set_defaults(func=cmd_submit)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
