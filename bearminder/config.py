import os
import yaml
from dataclasses import dataclass
from typing import Optional, List
from pathlib import Path
from dotenv import load_dotenv


DEFAULT_CONFIG = {
    "bear": {
        "callback_timeout": "30s",
        "retry_attempts": 3,
        "tags": [],
    },
    "beeminder": {
        "username": "your_username",
        "goal_name": "writing",
        "api_token": None,
    },
    "schedule": {
        "morning_time": "09:00",
        "evening_time": "21:00",
        "timezone": "America/Edmonton",
    },
    "metadata": {
        "max_note_titles": 5,
        "max_tags": 8,
        "truncate_length": 100,
    },
    "app": {
        "db_path": "data/bearminder.db",
        "debug": True,
        "dry_run": True,
    },
}


@dataclass
class BeeminderConfig:
    username: str
    goal_name: str
    api_token: Optional[str]


@dataclass
class AppConfig:
    bear_tags: List[str]
    beeminder: BeeminderConfig
    schedule_morning: str
    schedule_evening: str
    timezone: str
    max_note_titles: int
    max_tags: int
    truncate_length: int
    db_path: Path
    debug: bool
    dry_run: bool


class Config:
    def __init__(self, root: Path):
        self.root = root
        self._data = DEFAULT_CONFIG.copy()
        load_dotenv(root / ".env")
        self._load_yaml(root / "config.yaml")
        # Allow env overrides
        self._data["beeminder"]["username"] = os.getenv(
            "BEEMINDER_USERNAME", self._data["beeminder"]["username"]
        )
        self._data["beeminder"]["goal_name"] = os.getenv(
            "BEEMINDER_GOAL", self._data["beeminder"]["goal_name"]
        )
        self._data["beeminder"]["api_token"] = os.getenv(
            "BEEMINDER_TOKEN", self._data["beeminder"].get("api_token")
        )
        self._data["app"]["db_path"] = os.getenv(
            "BEAR_MINDER_DB", self._data["app"]["db_path"]
        )
        self._data["app"]["debug"] = self._str_to_bool(
            os.getenv("BEAR_MINDER_DEBUG", str(self._data["app"]["debug"]))
        )
        self._data["app"]["dry_run"] = self._str_to_bool(
            os.getenv("BEAR_MINDER_DRY_RUN", str(self._data["app"]["dry_run"]))
        )

    def _load_yaml(self, path: Path):
        if path.exists():
            with open(path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
            # shallow merge per section
            for k, v in data.items():
                if isinstance(v, dict) and k in self._data:
                    self._data[k].update(v)
                else:
                    self._data[k] = v

    def _str_to_bool(self, v: str) -> bool:
        return str(v).lower() in {"1", "true", "yes", "y", "on"}

    def as_app_config(self) -> AppConfig:
        beem = self._data["beeminder"]
        sched = self._data["schedule"]
        meta = self._data["metadata"]
        app = self._data["app"]
        return AppConfig(
            bear_tags=self._data["bear"].get("tags", []),
            beeminder=BeeminderConfig(
                username=beem["username"], goal_name=beem["goal_name"], api_token=beem.get("api_token")
            ),
            schedule_morning=sched["morning_time"],
            schedule_evening=sched["evening_time"],
            timezone=sched["timezone"],
            max_note_titles=int(meta["max_note_titles"]),
            max_tags=int(meta["max_tags"]),
            truncate_length=int(meta["truncate_length"]),
            db_path=(self.root / app["db_path"]).expanduser(),
            debug=bool(app["debug"]),
            dry_run=bool(app["dry_run"]),
        )
