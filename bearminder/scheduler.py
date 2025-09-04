from datetime import time
from zoneinfo import ZoneInfo
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from pathlib import Path
from .config import Config
from .db import ensure_db, get_conn, load_previous_snapshot, upsert_snapshots, log_sync
from .bear_collector import fetch_modified_notes
from .word_calculator import calculate_deltas
from .beeminder_sync import BeeminderClient


def _run_sync_internal():
    cfg = Config(Path.cwd()).as_app_config()
    ensure_db(cfg.db_path)

    # For scheduled runs, Beeminder expects daily totals; we use a 36h lookback
    # so morning run includes previous day and evening captures current day progress.
    from datetime import datetime, timedelta

    since = datetime.now() - timedelta(hours=36)
    notes = fetch_modified_notes(since, cfg.bear_tags, debug=cfg.debug)

    with get_conn(cfg.db_path) as conn:
        prev = load_previous_snapshot(conn)
        total, snapshots, tags, per_note, per_note_time = calculate_deltas(notes, prev)

        titles = [s["title"] for s in snapshots][: cfg.max_note_titles]
        tag_list = list(tags)[: cfg.max_tags]
        top_note = None
        if snapshots:
            sn = max(snapshots, key=lambda s: s.get("word_count", 0))
            top_note = (sn.get("title"), sn.get("word_count", 0))
        # Session split (AM/PM)
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
            # Duplicate prevention: skip if recent datapoint has same value and comment
            recents = client.get_recent_datapoints(cfg.beeminder.goal_name, count=5)
            if any(dp.get("value") == total and dp.get("comment") == comment for dp in recents):
                resp = "{\"status\": \"skipped-duplicate\"}"
            else:
                resp = client.post_datapoint(cfg.beeminder.goal_name, total, comment)
            log_sync(conn, total_words=total, notes_processed=len(snapshots), beeminder_response=resp, success=True)
            upsert_snapshots(conn, snapshots)
            print(f"[Scheduler] Sync complete. Value={total}. DryRun={cfg.dry_run}.")
        except Exception as e:
            log_sync(conn, total_words=total, notes_processed=len(snapshots), beeminder_response=str(e), success=False)
            raise


def start_scheduler():
    cfg = Config(Path.cwd()).as_app_config()

    # Try to use configured timezone, fallback to UTC if tzdata not present
    try:
        tz = ZoneInfo(cfg.timezone)
    except Exception:
        tz = ZoneInfo("UTC")
        print(f"Warning: timezone '{cfg.timezone}' not found. Falling back to UTC.")
    scheduler = BackgroundScheduler(timezone=tz)

    # Morning at configured time
    scheduler.add_job(
        _run_sync_internal,
        trigger=CronTrigger.from_crontab(_to_cron(cfg.schedule_morning)),
        id="morning_sync",
        replace_existing=True,
    )

    # Evening at configured time
    scheduler.add_job(
        _run_sync_internal,
        trigger=CronTrigger.from_crontab(_to_cron(cfg.schedule_evening)),
        id="evening_sync",
        replace_existing=True,
    )

    scheduler.start()
    print(f"Scheduler started. Timezone={cfg.timezone}. Morning={cfg.schedule_morning}, Evening={cfg.schedule_evening}")
    try:
        import time as _t
        while True:
            _t.sleep(1)
    except KeyboardInterrupt:
        scheduler.shutdown()
        print("Scheduler stopped.")


def _to_cron(hhmm: str) -> str:
    # Convert "HH:MM" to cron string "MIN HOUR * * *"
    hh, mm = hhmm.split(":")
    return f"{int(mm)} {int(hh)} * * *"
