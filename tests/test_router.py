import io
import json
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from session_router.cache import IndexCache
from session_router.catalog import load_app
from session_router.cli import main
from session_router.cursor_state import LiveDatabaseRefused, is_live_cursor_db, write_user_bubble
from session_router.doors import select_door
from session_router.versioning import resolve_profile

ROOT = Path(__file__).resolve().parents[1] / "profiles"


class ResolveTests(unittest.TestCase):
    def setUp(self):
        self.profiles = load_app(ROOT, "cursor")

    def test_exact_release_is_not_inherited(self):
        profile, inherited = resolve_profile(self.profiles, "3.29.15")
        self.assertEqual(profile["version"], "3.29.15")
        self.assertFalse(inherited)

    def test_newer_release_uses_previous_profile(self):
        profile, inherited = resolve_profile(self.profiles, "3.30.0")
        self.assertEqual(profile["version"], "3.29.15")
        self.assertTrue(inherited)

    def test_commits_between_releases_use_that_release(self):
        profile, inherited = resolve_profile(self.profiles, "3.29.15-4-gabc1234")
        self.assertEqual(profile["version"], "3.29.15")
        self.assertTrue(inherited)

    def test_version_before_every_profile_fails(self):
        with self.assertRaises(Exception):
            resolve_profile(self.profiles, "0.1.0")

    def test_desktop_chat_is_the_warned_last_door(self):
        profile, inherited = resolve_profile(self.profiles, "3.29.15")
        door = select_door(profile, "prompt-existing-desktop-chat", inherited=inherited)
        self.assertEqual(door.kind, "worst_case")
        self.assertEqual(door.detail, "state-db")
        self.assertIn("corrupt the chat store", door.warning)

    def test_cli_resume_stops_at_the_cli_door(self):
        profile, inherited = resolve_profile(self.profiles, "3.29.15")
        door = select_door(profile, "resume-cli-session", inherited=inherited)
        self.assertEqual(door.kind, "cli")
        self.assertEqual(door.detail[0], "agent")


class CacheTests(unittest.TestCase):
    def test_stale_mtime_is_a_miss_and_other_stores_do_not_match(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = IndexCache(Path(tmp) / "index.json")
            cache.put("cursor", "desktop", "abc", "Connectome", 10)
            self.assertIsNone(cache.get("cursor", "desktop", "abc", 11))
            self.assertIsNone(cache.get_for_store("cursor", "cli", "abc", 10))
            hit = cache.get_for_store("cursor", "desktop", "abc", 10)
            self.assertEqual(hit["title"], "Connectome")
            saved = Path(tmp, "index.json").read_text(encoding="utf-8")
            self.assertNotIn("transcript", saved)


class StateTests(unittest.TestCase):
    def test_live_database_is_refused_without_both_flags(self):
        live = Path(r"C:\Users\rjamd\AppData\Roaming\Cursor\User\globalStorage\state.vscdb")
        self.assertTrue(is_live_cursor_db(live))
        with self.assertRaises(LiveDatabaseRefused):
            write_user_bubble(live, "nope", "hello")

    def test_fixture_gains_a_bubble_and_keeps_conversation_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "state.vscdb"
            connection = sqlite3.connect(db)
            connection.execute("CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value TEXT)")
            connection.execute(
                "CREATE TABLE composerHeaders (composerId TEXT PRIMARY KEY, lastUpdatedAt INTEGER, value TEXT)"
            )
            original = {"conversationState": "opaque-blob", "text": "", "richText": ""}
            connection.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                ("composerData:cid", json.dumps(original)),
            )
            connection.execute(
                "INSERT INTO composerHeaders (composerId, lastUpdatedAt, value) VALUES (?, ?, ?)",
                ("cid", 1, json.dumps({"composerId": "cid", "lastUpdatedAt": 1})),
            )
            connection.commit()
            connection.close()

            bubble_id = write_user_bubble(db, "cid", "hello from the router")
            connection = sqlite3.connect(db)
            bubble = json.loads(
                connection.execute(
                    "SELECT value FROM cursorDiskKV WHERE key = ?",
                    (f"bubbleId:cid:{bubble_id}",),
                ).fetchone()[0]
            )
            data = json.loads(
                connection.execute(
                    "SELECT value FROM cursorDiskKV WHERE key = ?",
                    ("composerData:cid",),
                ).fetchone()[0]
            )
            connection.close()
            self.assertEqual(bubble["text"], "hello from the router")
            self.assertEqual(bubble["type"], 1)
            self.assertEqual(data["conversationState"], "opaque-blob")
            self.assertEqual(data["text"], "hello from the router")


class CliTests(unittest.TestCase):
    def test_resolve_prints_the_repair_checklist_for_an_inherited_profile(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = main(
                [
                    "--profiles",
                    str(ROOT),
                    "resolve",
                    "--app",
                    "cursor",
                    "--version",
                    "3.29.15-2-gdeadbee",
                    "--operation",
                    "prompt-existing-desktop-chat",
                ]
            )
        text = buf.getvalue()
        self.assertEqual(code, 0)
        self.assertIn("door=worst_case", text)
        self.assertIn("inherited=true", text)
        self.assertIn("Fork this catalog", text)
        self.assertIn("corrupt the chat store", text)


if __name__ == "__main__":
    unittest.main()
