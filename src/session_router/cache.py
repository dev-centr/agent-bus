"""Index of chat ids. Transcript text is never stored."""

from __future__ import annotations

import json
from pathlib import Path


class IndexCache:
    def __init__(self, path: Path):
        self.path = path
        self._rows: list[dict] = []
        if path.is_file():
            self._rows = json.loads(path.read_text(encoding="utf-8"))

    def put(self, app: str, store: str, chat_id: str, title: str, source_mtime: int) -> None:
        self._rows = [
            row
            for row in self._rows
            if not (row["app"] == app and row["store"] == store and row["chat_id"] == chat_id)
        ]
        self._rows.append(
            {
                "app": app,
                "store": store,
                "chat_id": chat_id,
                "title": title,
                "source_mtime": source_mtime,
            }
        )
        self._write()

    def get(self, app: str, store: str, chat_id: str, source_mtime: int) -> dict | None:
        for row in self._rows:
            if row["app"] == app and row["store"] == store and row["chat_id"] == chat_id:
                if row["source_mtime"] != source_mtime:
                    return None
                return row
        return None

    def get_for_store(self, app: str, store: str, chat_id: str, source_mtime: int) -> dict | None:
        """Return a row only when the caller names the same store the id was cached in."""
        return self.get(app, store, chat_id, source_mtime)

    def _write(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self._rows, indent=2) + "\n", encoding="utf-8")
