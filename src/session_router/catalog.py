"""Load hack profiles from profiles/<app>/<version>.json."""

from __future__ import annotations

import json
from pathlib import Path


def profiles_root(start: Path | None = None) -> Path:
    if start is not None:
        return start
    return Path(__file__).resolve().parents[2] / "profiles"


def load_app(root: Path, app: str) -> list[dict]:
    folder = root / app
    if not folder.is_dir():
        raise FileNotFoundError(f"No profiles for app {app!r} under {folder}.")
    found = []
    for path in sorted(folder.glob("*.json")):
        profile = json.loads(path.read_text(encoding="utf-8"))
        profile["_path"] = str(path)
        found.append(profile)
    if not found:
        raise FileNotFoundError(f"No JSON profiles in {folder}.")
    return found
