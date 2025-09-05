# BearMinder

Track Bear app daily word count and sync to Beeminder.

## Quick start

1. Python 3.10+
2. Install deps:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure:
   - Copy `.env.example` to `.env` and fill values
   - Optionally edit `config.yaml`

### Configure Bear database path (macOS)

BearMinder reads Bear locally via a read-only SQLite database. On first run, if the database isn't found automatically, set `BEAR_DB_PATH` to the full path of Bear's `database.sqlite`.

Common locations:

- Bear 2: `~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite`
- Alternate container: `~/Library/Group Containers/2ELUDT6HF6.com.shinyfrog.bear/Application Data/database.sqlite`
- Bear 1 (legacy): `~/Library/Containers/net.shinyfrog.bear/Data/Documents/Application Data/database.sqlite`

Set environment variable (e.g., in `.env`):

```
BEAR_DB_PATH=/Users/you/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite
```

## Background mode (macOS launchd)

Run BearMinder automatically in the background and at login using a per-user LaunchAgent.

Scripts are provided under `scripts/` to install/uninstall:

```
# install (writes a LaunchAgent plist and starts it)
./scripts/install_launchd.sh

# uninstall (stops the agent and removes the plist)
./scripts/uninstall_launchd.sh
```

What it does:

- Installs `~/Library/LaunchAgents/com.brennan.bearminder.plist`.
- Runs `python -m bearminder.main schedule` in your repo directory at login and keeps it alive.
- Prefers the repo virtualenv Python at `.venv/bin/python`, otherwise falls back to `python3`/`python` on your PATH.
- Writes logs to `data/launchd.out.log` and `data/launchd.err.log`.

Notes:

- Configure `.env` and `config.yaml` before installing so the scheduler has the right credentials and settings.
- The scheduler posts at times configured in `config.yaml` under `schedule.morning_time` and `schedule.evening_time` (local timezone in `schedule.timezone`).
- To check status, see `data/status.json` after syncs complete. The GUI can read this file.
- To run in preview mode (no Beeminder posts), set `BEAR_MINDER_DRY_RUN=true` in your `.env`.

## macOS menu bar (tray) icon

When the GUI app is running, a menu bar icon is available with quick actions:

- Open BearMinder (shows the main window)
- Sync now (runs a quick sync of the last hour)
- Open config.yaml
- Open data folder
- Quit

The tray is implemented in `gui/src-tauri/src/lib.rs` using Tauri v2's tray API.

Notes:

- The DB is opened in read-only mode via SQLite URI; no modifications are made.
- Only titles, plain text, and modified timestamps are read to compute word counts.

4. Initialize DB:
   ```bash
   python -m bearminder.main init-db
   ```
5. Run a dry-run sync (no network post if token missing or dry_run=true):
   ```bash
   python -m bearminder.main sync-once
   ```

By default, when `debug=true`, Bear integration uses simulated data. Set `debug=false` to use the real local SQLite integration (read-only) described above.

## Structure
- `bearminder/config.py` – load config from YAML + env
- `bearminder/db.py` – SQLite schema and helpers
- `bearminder/bear_collector.py` – Bear integration (stubbed)
- `bearminder/word_calculator.py` – delta computation
- `bearminder/beeminder_sync.py` – Beeminder client
- `bearminder/main.py` – CLI (init-db, sync-once)

## Next steps
- Implement real Bear API queries via `bear://` URL scheme on macOS
- Add scheduler (APScheduler) for 9AM/9PM cadence
- Enrich Beeminder comment format per spec (sessions, top note)
- Robust error handling and logging
