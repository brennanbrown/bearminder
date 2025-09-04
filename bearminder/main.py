import json
import typer
from pathlib import Path
from datetime import datetime, timedelta, timezone

from .config import Config
from .db import ensure_db, get_conn, load_previous_snapshot, upsert_snapshots, log_sync, get_last_successful_sync_time
from .bear_collector import fetch_modified_notes
from .word_calculator import calculate_deltas
from .beeminder_sync import BeeminderClient
from .scheduler import start_scheduler

app = typer.Typer(help="BearMinder CLI")


@app.command()
def init_db():
    """Create the SQLite database and tables."""
    cfg = Config(Path.cwd()).as_app_config()
    ensure_db(cfg.db_path)
    typer.echo(f"Initialized DB at {cfg.db_path}")


@app.command()
def sync_once(
    since_hours: int = typer.Option(36, help="Look back window in hours"),
    ignore_last_sync: bool = typer.Option(False, help="Ignore last successful sync time and use lookback window"),
):
    """Run a single sync cycle: collect -> compute -> post -> persist."""
    cfg = Config(Path.cwd()).as_app_config()
    ensure_db(cfg.db_path)

    with get_conn(cfg.db_path) as conn:
        last_sync = get_last_successful_sync_time(conn)
        if ignore_last_sync or last_sync is None:
            since = datetime.now() - timedelta(hours=since_hours)
        else:
            since = last_sync
        notes = fetch_modified_notes(since, cfg.bear_tags, debug=cfg.debug)
        prev = load_previous_snapshot(conn)
        total, snapshots, tags, per_note, per_note_time = calculate_deltas(notes, prev)

        # Helpers: sanitize and truncate titles for compact comments
        def _clean_trunc(s: str, limit: int) -> str:
            if not s:
                return "Untitled"
            cleaned = " ".join(str(s).split())  # collapse whitespace/newlines
            if len(cleaned) <= limit:
                return cleaned
            if limit <= 1:
                return cleaned[:limit]
            return cleaned[: max(0, limit - 1)] + "…"

        # Build comment
        titles_raw = [s["title"] for s in snapshots]
        # De-duplicate while preserving order
        seen = set()
        uniq_titles = []
        for t in titles_raw:
            if t not in seen:
                seen.add(t)
                uniq_titles.append(t)
        titles = [_clean_trunc(t, cfg.truncate_length) for t in uniq_titles[: cfg.max_note_titles]]
        tag_list = list(tags)[: cfg.max_tags]
        top_note = None
        if snapshots:
            sn = max(snapshots, key=lambda s: s.get("word_count", 0))
            top_note = (_clean_trunc(sn.get("title"), cfg.truncate_length), sn.get("word_count", 0))
        # Session split (AM/PM) from last_modified timestamps
        am_words = 0
        pm_words = 0
        for title, delta, iso_ts in per_note_time:
            try:
                hour = int(iso_ts[11:13])
            except Exception:
                hour = 12
            if hour < 12:
                am_words += delta
            else:
                pm_words += delta
        # Single-line compact comment for better Beeminder tooltip rendering
        parts = [
            f"📝 {total}w",
            f"📚 {len(snapshots)} notes",
            f"🏷️ {len(tag_list)} tags",
            f"Sessions: {am_words}AM + {pm_words}PM",
        ]
        if top_note:
            parts.append(f"Top: \"{top_note[0]}\" ({top_note[1]}w)")
        if titles:
            parts.append("Notes: " + ", ".join(f'\"{t}\"' for t in titles))
        if tag_list:
            parts.append("Tags: " + " ".join('#' + t for t in tag_list))
        if total == 0:
            parts.append("No writing today")
        comment = " | ".join(parts)

        client = BeeminderClient(cfg.beeminder.username, cfg.beeminder.api_token, dry_run=cfg.dry_run)
        try:
            now_ts = int(datetime.now(tz=timezone.utc).timestamp())
            # Duplicate prevention: skip if recent datapoint has same value and comment
            recents = client.get_recent_datapoints(cfg.beeminder.goal_name, count=5)
            if any(dp.get("value") == total and dp.get("comment") == comment for dp in recents):
                resp = "{\"status\": \"skipped-duplicate\"}"
            else:
                resp = client.post_datapoint(cfg.beeminder.goal_name, total, comment, timestamp=now_ts)
            log_sync(conn, total_words=total, notes_processed=len(snapshots), beeminder_response=resp, success=True)
            upsert_snapshots(conn, snapshots)
            typer.echo(f"Sync complete. Value={total}. DryRun={cfg.dry_run}.")
            # Emit status.json for GUI
            status_dir = cfg.db_path.parent
            status_dir.mkdir(parents=True, exist_ok=True)
            status = {
                "last_sync": datetime.now(tz=timezone.utc).isoformat(),
                "value": total,
                "notes_count": len(snapshots),
                "tags_count": len(tag_list),
                "comment": comment,
                "beeminder_response": resp,
                "success": True,
                "dry_run": cfg.dry_run,
            }
            with open(status_dir / "status.json", "w", encoding="utf-8") as f:
                json.dump(status, f, ensure_ascii=False, indent=2)
        except Exception as e:
            log_sync(conn, total_words=total, notes_processed=len(snapshots), beeminder_response=str(e), success=False)
            # Emit failure status for GUI
            status_dir = cfg.db_path.parent
            status_dir.mkdir(parents=True, exist_ok=True)
            status = {
                "last_sync": datetime.now(tz=timezone.utc).isoformat(),
                "value": total,
                "notes_count": len(snapshots),
                "tags_count": len(tag_list),
                "comment": comment,
                "error": str(e),
                "success": False,
                "dry_run": cfg.dry_run,
            }
            try:
                with open(status_dir / "status.json", "w", encoding="utf-8") as f:
                    json.dump(status, f, ensure_ascii=False, indent=2)
            finally:
                raise


@app.command()
def schedule():
    """Start the scheduler that runs sync at configured morning/evening times."""
    typer.echo("Starting scheduler. Press Ctrl+C to stop.")
    start_scheduler()


@app.command()
def post_test(
    value: int = typer.Argument(..., help="Datapoint value to post"),
    comment: str = typer.Option("", "--comment", help="Optional comment"),
    dry_run: bool = typer.Option(False, "--dry-run/--no-dry-run", help="Override dry-run for this post"),
):
    """Post a manual test datapoint to Beeminder immediately."""
    cfg = Config(Path.cwd()).as_app_config()
    client = BeeminderClient(cfg.beeminder.username, cfg.beeminder.api_token, dry_run=dry_run)
    ts = int(datetime.now().timestamp())
    resp = client.post_datapoint(cfg.beeminder.goal_name, value, comment, timestamp=ts)
    typer.echo(f"Posted test datapoint value={value}, dry_run={dry_run}. Response: {resp}")


if __name__ == "__main__":
    app()
