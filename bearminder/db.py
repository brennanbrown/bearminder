import sqlite3
from pathlib import Path
from typing import Optional, Iterable, Dict, Any
from datetime import datetime

SCHEMA_NOTE_SNAPSHOTS = """
CREATE TABLE IF NOT EXISTS note_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_id TEXT,
    title TEXT,
    word_count INTEGER,
    last_modified TIMESTAMP,
    tags TEXT,
    snapshot_date DATE
);
CREATE INDEX IF NOT EXISTS idx_note_snapshots_note_date ON note_snapshots(note_id, snapshot_date);
"""

SCHEMA_NOTE_STATE = """
CREATE TABLE IF NOT EXISTS note_state (
    note_id TEXT PRIMARY KEY,
    title TEXT,
    word_count INTEGER,
    last_modified TIMESTAMP,
    tags TEXT
);
"""

SCHEMA_SYNC_LOG = """
CREATE TABLE IF NOT EXISTS sync_log (
    sync_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_time TIMESTAMP,
    total_words INTEGER,
    notes_processed INTEGER,
    beeminder_response TEXT,
    success BOOLEAN
);
"""


def ensure_db(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as conn:
        c = conn.cursor()
        # Create current tables if not present
        c.executescript(SCHEMA_NOTE_SNAPSHOTS)
        c.execute(SCHEMA_NOTE_STATE)
        c.execute(SCHEMA_SYNC_LOG)
        # Migrate legacy note_snapshots schema (where note_id was PRIMARY KEY)
        try:
            c.execute("PRAGMA table_info(note_snapshots)")
            cols = [row[1] for row in c.fetchall()]
            has_id = any(col == "id" for col in cols)
            if not has_id:
                # Legacy table detected: rebuild as new schema with historical rows
                c.execute(
                    """
                    ALTER TABLE note_snapshots RENAME TO note_snapshots_legacy;
                    """
                )
                c.executescript(SCHEMA_NOTE_SNAPSHOTS)  # recreate with new definition
                # Copy legacy data into new table; legacy columns match sans id
                c.execute(
                    """
                    INSERT INTO note_snapshots (note_id, title, word_count, last_modified, tags, snapshot_date)
                    SELECT note_id, title, word_count, last_modified, tags, snapshot_date FROM note_snapshots_legacy;
                    """
                )
                c.execute("DROP TABLE note_snapshots_legacy;")
        except Exception:
            # Best-effort migration; ignore if PRAGMA not available or table missing
            pass
        conn.commit()


def get_conn(path: Path) -> sqlite3.Connection:
    return sqlite3.connect(path)


def load_previous_snapshot(conn: sqlite3.Connection) -> Dict[str, Dict[str, Any]]:
    """Load the latest known state per note for delta calculations."""
    cur = conn.cursor()
    cur.execute("SELECT note_id, title, word_count, last_modified, tags FROM note_state")
    result: Dict[str, Dict[str, Any]] = {}
    for row in cur.fetchall():
        result[row[0]] = {
            "title": row[1],
            "word_count": row[2],
            "last_modified": row[3],
            "tags": row[4],
        }
    return result


def upsert_snapshots(conn: sqlite3.Connection, snapshots: Iterable[Dict[str, Any]]) -> None:
    """Persist snapshots: append to historical table and update current state."""
    cur = conn.cursor()
    snaps = list(snapshots)
    # Historical append
    cur.executemany(
        """
        INSERT INTO note_snapshots (note_id, title, word_count, last_modified, tags, snapshot_date)
        VALUES (:note_id, :title, :word_count, :last_modified, :tags, DATE('now'))
        """,
        snaps,
    )
    # Current state upsert
    cur.executemany(
        """
        INSERT INTO note_state (note_id, title, word_count, last_modified, tags)
        VALUES (:note_id, :title, :word_count, :last_modified, :tags)
        ON CONFLICT(note_id) DO UPDATE SET
            title=excluded.title,
            word_count=excluded.word_count,
            last_modified=excluded.last_modified,
            tags=excluded.tags
        """,
        snaps,
    )
    conn.commit()


def log_sync(conn: sqlite3.Connection, total_words: int, notes_processed: int, beeminder_response: Optional[str], success: bool) -> None:
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO sync_log (sync_time, total_words, notes_processed, beeminder_response, success) VALUES (DATETIME('now'), ?, ?, ?, ?)",
        (total_words, notes_processed, beeminder_response, int(success)),
    )
    conn.commit()


def get_last_successful_sync_time(conn: sqlite3.Connection) -> Optional[datetime]:
    cur = conn.cursor()
    cur.execute(
        "SELECT sync_time FROM sync_log WHERE success = 1 ORDER BY sync_time DESC LIMIT 1"
    )
    row = cur.fetchone()
    if not row:
        return None
    # SQLite DATETIME('now') returns in 'YYYY-MM-DD HH:MM:SS'
    return datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S")
