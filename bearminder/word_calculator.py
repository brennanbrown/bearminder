from typing import Dict, Any, List, Tuple, Set
from .bear_collector import BearNote


def calculate_deltas(notes: List[BearNote], previous: Dict[str, Dict[str, Any]]) -> Tuple[int, List[dict], Set[str], List[Tuple[str, str, int]], List[Tuple[str, int, str]]]:
    """
    Returns:
      total_delta: int
      snapshots: list of snapshot dicts suitable for DB upsert
      unique_tags: set of tags seen in modified notes
      per_note_deltas: list of tuples (note_id, title, delta)
      per_note_time_deltas: list of tuples (title, delta, last_modified_iso)
    """
    total = 0
    snapshots: List[dict] = []
    tags: Set[str] = set()
    per_note: List[Tuple[str, str, int]] = []
    per_note_time: List[Tuple[str, int, str]] = []

    for n in notes:
        prev_wc = int(previous.get(n.note_id, {}).get("word_count", 0))
        delta = max(0, n.word_count - prev_wc)
        total += delta
        snapshots.append(
            {
                "note_id": n.note_id,
                "title": n.title,
                "word_count": n.word_count,
                "last_modified": n.last_modified.isoformat(),
                "tags": ",".join(n.tags),
            }
        )
        tags.update(n.tags)
        per_note.append((n.note_id, n.title, delta))
        per_note_time.append((n.title, delta, n.last_modified.isoformat()))

    return total, snapshots, tags, per_note, per_note_time
