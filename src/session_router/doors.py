"""Choose the first door that can perform an operation."""

from __future__ import annotations

from dataclasses import dataclass

WORST_CASE_WARNING = (
    "Warning. Writing straight into Cursor's state database to fake a prompt "
    "submit can corrupt the chat store, deliver the prompt to the wrong "
    "composer, or break on the next app update."
)


class DoorError(LookupError):
    pass


@dataclass(frozen=True)
class Door:
    kind: str
    detail: object
    inherited: bool
    profile_version: str
    warning: str | None = None


def select_door(profile: dict, operation: str, *, inherited: bool) -> Door:
    operations = profile.get("operations") or {}
    if operation not in operations:
        raise DoorError(
            f"Profile {profile.get('version')} has no operation {operation!r}."
        )
    spec = operations[operation]
    version = profile["version"]
    if spec.get("mcp"):
        return Door("mcp", spec["mcp"], inherited, version)
    if spec.get("cli"):
        return Door("cli", list(spec["cli"]), inherited, version)
    if spec.get("hack"):
        return Door("hack", spec["hack"], inherited, version)
    if spec.get("worst_case"):
        return Door(
            "worst_case",
            spec["worst_case"],
            inherited,
            version,
            warning=WORST_CASE_WARNING,
        )
    raise DoorError(
        f"Operation {operation!r} has no door in profile {version}."
    )


def repair_checklist(app: str, failed_version: str, profile_version: str, operation: str) -> str:
    return "\n".join(
        [
            "The inherited hack needs a fix.",
            f"Fork this catalog, not the {app} harness.",
            f"Add or patch profiles/{app}/ for version {failed_version}.",
            f"It was tried with the profile from {profile_version} for operation {operation}.",
            "Open a pull request upstream that names the app, the version that failed,",
            "the older profile, and the change that made the hack work.",
        ]
    )
