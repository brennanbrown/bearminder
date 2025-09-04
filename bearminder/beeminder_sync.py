import json
import time
from typing import Optional
import requests

class BeeminderClient:
    def __init__(self, username: str, token: Optional[str], dry_run: bool = True):
        self.username = username
        self.token = token
        self.dry_run = dry_run or not token

    def post_datapoint(self, goal: str, value: int, comment: str, timestamp: Optional[int] = None) -> str:
        payload = {
            "value": value,
            "comment": comment,
        }
        if timestamp is not None:
            payload["timestamp"] = timestamp
        if self.dry_run:
            return json.dumps({"status": "dry-run", "payload": payload})
        url = f"https://www.beeminder.com/api/v1/users/{self.username}/goals/{goal}/datapoints.json"
        resp = requests.post(url, data={**payload, "auth_token": self.token}, timeout=20)
        resp.raise_for_status()
        return resp.text

    def get_recent_datapoints(self, goal: str, count: int = 5) -> list:
        if self.dry_run:
            # In dry-run, simulate empty list so we don't block test posts
            return []
        url = f"https://www.beeminder.com/api/v1/users/{self.username}/goals/{goal}/datapoints.json"
        params = {"auth_token": self.token, "count": count}
        resp = requests.get(url, params=params, timeout=20)
        resp.raise_for_status()
        return resp.json()
