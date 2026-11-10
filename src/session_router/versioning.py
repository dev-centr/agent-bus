"""Release versions for hack profiles."""

from __future__ import annotations

import re

_RELEASE = re.compile(
    r"^(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g[0-9a-fA-F]+)?$"
)


class VersionError(ValueError):
    pass


def parse_version(text: str) -> tuple[tuple[int, int, int], int]:
    """Return ((major, minor, patch), commits after that release)."""
    match = _RELEASE.match(text.strip())
    if match is None:
        raise VersionError(
            f"Version {text!r} is not a release or a commits-after-release build."
        )
    base = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
    extra = int(match.group(4) or 0)
    return base, extra


def resolve_profile(profiles: list[dict], version_text: str) -> tuple[dict, bool]:
    """Pick the profile for a version.

    An exact release uses its own profile. A build of commits after a release,
    or a release with no profile, uses the newest older profile. The second
    value is true when the chosen profile was inherited.
    """
    if not profiles:
        raise VersionError("No hack profiles are loaded.")
    base, extra = parse_version(version_text)
    exact = [
        profile
        for profile in profiles
        if parse_version(profile["version"]) == (base, 0)
    ]
    if extra == 0 and exact:
        return exact[0], False
    older = [
        profile
        for profile in profiles
        if parse_version(profile["version"])[0] <= base
    ]
    if not older:
        raise VersionError(
            f"No hack profile is at or before {version_text}."
        )
    chosen = max(older, key=lambda profile: parse_version(profile["version"])[0])
    return chosen, True
