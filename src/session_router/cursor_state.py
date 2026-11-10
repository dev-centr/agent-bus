"""Last-resort writer for a Cursor composer SQLite database.

The live globalStorage database is refused unless the caller passes both
acknowledgment flags. The opaque conversation blob is never rewritten, so this
does not start a generation by itself.
"""

from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

from session_router.doors import WORST_CASE_WARNING


class LiveDatabaseRefused(RuntimeError):
    def __init__(self):
        super().__init__(WORST_CASE_WARNING + " Pass --worst-case and --i-understand to write a live database.")


class ComposerNotFound(LookupError):
    pass


def is_live_cursor_db(path: Path) -> bool:
    text = str(path).replace("/", "\\").lower()
    return text.endswith("\\globalstorage\\state.vscdb") and "\\cursor\\user\\" in text


def rich_text(prompt: str) -> str:
    return json.dumps(
        {
            "type": "doc",
            "content": [
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": prompt}],
                }
            ],
        },
        separators=(",", ":"),
    )


def write_user_bubble(
    db_path: Path,
    composer_id: str,
    prompt: str,
    *,
    worst_case: bool = False,
    i_understand: bool = False,
) -> str:
    if is_live_cursor_db(db_path) and not (worst_case and i_understand):
        raise LiveDatabaseRefused()
    bubble_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    created = now.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    now_ms = int(now.timestamp() * 1000)
    bubble = {
        "_v": 3,
        "type": 1,
        "bubbleId": bubble_id,
        "text": prompt,
        "richText": rich_text(prompt),
        "createdAt": created,
        "isAgentic": False,
        "unifiedMode": 2,
        "conversationState": "",
    }
    uri = f"file:{db_path}?mode=rw"
    connection = sqlite3.connect(uri, uri=True)
    try:
        row = connection.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f"composerData:{composer_id}",),
        ).fetchone()
        if row is None:
            raise ComposerNotFound(composer_id)
        data = json.loads(row[0])
        before_state = data.get("conversationState")
        data["text"] = prompt
        data["richText"] = rich_text(prompt)
        data["lastUpdatedAt"] = now_ms
        if data.get("conversationState") != before_state:
            raise RuntimeError("Refusing to change conversationState.")
        connection.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f"bubbleId:{composer_id}:{bubble_id}", json.dumps(bubble)),
        )
        connection.execute(
            "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
            (json.dumps(data), f"composerData:{composer_id}"),
        )
        header = connection.execute(
            "SELECT value FROM composerHeaders WHERE composerId = ?",
            (composer_id,),
        ).fetchone()
        if header is not None:
            header_value = json.loads(header[0])
            header_value["lastUpdatedAt"] = now_ms
            connection.execute(
                "UPDATE composerHeaders SET lastUpdatedAt = ?, value = ? WHERE composerId = ?",
                (now_ms, json.dumps(header_value), composer_id),
            )
        connection.commit()
    finally:
        connection.close()
    return bubble_id
