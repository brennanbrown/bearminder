from dataclasses import dataclass
from typing import List, Optional
from datetime import datetime, timedelta
import random
import os
import sqlite3


@dataclass
class BearNote:
    note_id: str
    title: str
    word_count: int
    last_modified: datetime
    tags: List[str]


def fetch_modified_notes(since: Optional[datetime], tags_filter: Optional[List[str]] = None, debug: bool = True) -> List[BearNote]:
    """
    Placeholder Bear API integration.
    - When debug=True, returns simulated notes modified since given time.
    - When debug=False on macOS, reads Bear's local SQLite database in read-only mode.
    """
    if not debug:
        notes = _fetch_notes_via_sqlite(since, tags_filter)
        return notes

    now = datetime.now()
    base_notes = [
        ("1", "Blog post draft", 423, ["writing", "blog", "draft"]),
        ("2", "Daily journal", 218, ["writing", "journal", "personal"]),
        ("3", "Project brainstorm", 156, ["work", "ideas", "productivity"]),
        ("4", "Random notes", 50, ["misc"]) ,
    ]
    notes: List[BearNote] = []
    for nid, title, wc, tags in base_notes:
        lm = now - timedelta(hours=random.randint(0, 36))
        if since and lm < since:
            continue
        if tags_filter and not (set(tags_filter) & set(tags)):
            continue
        # Add some small random change to mimic edits
        wc = wc + random.randint(0, 40)
        notes.append(BearNote(nid, title, wc, lm, tags))
    return notes

def _find_bear_db_path() -> Optional[str]:
    candidates = [
        os.environ.get("BEAR_DB_PATH"),
        "~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite",  # Bear 2
        "~/Library/Group Containers/2ELUDT6HF6.com.shinyfrog.bear/Application Data/database.sqlite",  # alt container
        "~/Library/Containers/net.shinyfrog.bear/Data/Documents/Application Data/database.sqlite",   # Bear 1 legacy
    ]
    for p in candidates:
        if not p:
            continue
        full = os.path.expanduser(p)
        if os.path.exists(full):
            return full
    return None


def _choose_note_table_and_columns(conn: sqlite3.Connection):
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    candidates = []
    for t in tables:
        try:
            info = conn.execute(f"PRAGMA table_info('{t}')").fetchall()
        except Exception:
            continue
        cols = {r[1].lower(): r[1] for r in info}
        lc_names = list(cols.keys())
        # Heuristic matches (prefer real title over subtitle)
        preferred_titles = [c for c in lc_names if c in ('ztitle', 'title')]
        if preferred_titles:
            title_col = cols[preferred_titles[0]]
        else:
            # fallback: any column containing 'title' but not 'subtitle'
            title_col = next((cols[c] for c in lc_names if 'title' in c and 'subtitle' not in c), None)
        text_col = next((cols[c] for c in lc_names if c in ('text', 'ztext') or 'body' in c or 'content' in c), None)
        mod_col = next((cols[c] for c in lc_names if 'modif' in c or 'updated' in c or c in ('zmodificationdate','modified')), None)
        id_col = next((cols[c] for c in lc_names if c in ('id','z_pk','zidentifier','uuid')), None)
        if not (title_col and text_col and mod_col and id_col):
            continue
        # Score candidate tables
        score = 0
        name_l = t.lower()
        if 'note' in name_l or 'zsfnote' in name_l:
            score += 3
        # Prefer CoreData-style columns
        if text_col.lower().startswith('z'):
            score += 1
        if mod_col.lower().startswith('z'):
            score += 1
        # Check sample data to ensure text is non-empty in many rows
        try:
            sample = conn.execute(f"SELECT {text_col} FROM {t} LIMIT 50").fetchall()
            nonempty = sum(1 for (v,) in sample if v)
            score += min(nonempty, 10)  # up to +10
        except Exception:
            pass
        candidates.append((score, t, id_col, title_col, text_col, mod_col))
    if not candidates:
        raise RuntimeError("Could not identify Bear notes table and columns")
    candidates.sort(key=lambda x: x[0], reverse=True)
    best = candidates[0]
    print(f"[BearCollector] Using table '{best[1]}' (score {best[0]}). Columns: id={best[2]}, title={best[3]}, text={best[4]}, mod={best[5]}")
    return best[1], best[2], best[3], best[4], best[5]


def _apple_epoch_to_unix(ts: float) -> float:
    # Core Data timestamps are seconds since 2001-01-01. Convert to Unix.
    # Handle milliseconds first
    if ts > 1e12:
        ts = ts / 1000.0
    # If still implausibly large, divide again
    if ts > 3_000_000_000:
        ts = ts / 1000.0
    # If timestamp is earlier than 2001-01-01 in Unix, treat it as Apple epoch and convert
    APPLE_EPOCH_UNIX = 978307200
    if 0 < ts < APPLE_EPOCH_UNIX:
        return ts + APPLE_EPOCH_UNIX
    return ts


def _fetch_notes_via_sqlite(since: Optional[datetime], tags_filter: Optional[List[str]] = None) -> List[BearNote]:
    db_path = _find_bear_db_path()
    if not db_path:
        print("[BearCollector] Bear database not found. Set BEAR_DB_PATH to the database.sqlite path.")
        return []
    try:
        uri = f"file:{db_path}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
    except Exception as e:
        print(f"[BearCollector] Failed to open Bear DB at {db_path}: {e}")
        return []

    try:
        table, id_col, title_col, text_col, mod_col = _choose_note_table_and_columns(conn)
        rows = conn.execute(f"SELECT {id_col}, {title_col}, {text_col}, {mod_col} FROM {table}").fetchall()
        print(f"[BearCollector] Queried {len(rows)} rows from '{table}'.")
    except Exception as e:
        print(f"[BearCollector] Failed querying Bear DB: {e}")
        conn.close()
        return []
    finally:
        # Intentionally not closing here if success; we'll close below after processing
        pass

    cutoff = int(since.timestamp()) if since else None
    notes: List[BearNote] = []
    for rid, title, text, modval in rows:
        # Convert modification timestamp
        ts = 0
        try:
            if isinstance(modval, (int, float)):
                ts = _apple_epoch_to_unix(float(modval))
            elif isinstance(modval, str):
                # Try parse ISO format
                try:
                    ts = datetime.fromisoformat(modval).timestamp()
                except Exception:
                    ts = 0
            else:
                ts = 0
        except Exception:
            ts = 0
        if cutoff and ts and ts < cutoff:
            continue

        # Word count from plain text
        body = text or ""
        # Basic tokenization on whitespace
        wc = len([w for w in str(body).split() if w])
        lm = datetime.fromtimestamp(ts) if ts else datetime.now()
        nid = str(rid)
        # Tags from DB are complex; omit for now as requested (all notes)
        notes.append(BearNote(nid, title or "Untitled", wc, lm, tags=[]))

    conn.close()

    # Optional tag filtering (unused now)
    if tags_filter:
        notes = [n for n in notes if set(tags_filter) & set(n.tags)]
    return notes
