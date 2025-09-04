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
