import json
import os
import threading
from pathlib import Path

import firebase_admin
from firebase_admin import credentials

AGENT_DIR = Path(__file__).resolve().parents[2]
_lock = threading.Lock()


def _env(name: str) -> str | None:
    value = os.environ.get(name, "").strip()
    return value or None


def get_firebase_app() -> firebase_admin.App:
    with _lock:
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass

        raw_json = _env("FIREBASE_SERVICE_ACCOUNT_JSON")
        if raw_json:
            try:
                info = json.loads(raw_json)
            except json.JSONDecodeError:
                raise ValueError(
                    "FIREBASE_SERVICE_ACCOUNT_JSON is set but is not valid JSON"
                ) from None
            return firebase_admin.initialize_app(credentials.Certificate(info))

        key_path = _env("FIREBASE_SERVICE_ACCOUNT_PATH")
        if key_path:
            path = Path(key_path)
            if not path.is_absolute():
                path = AGENT_DIR / path
            if not path.is_file():
                raise FileNotFoundError(
                    f"FIREBASE_SERVICE_ACCOUNT_PATH is set but {path} does not exist"
                )
            return firebase_admin.initialize_app(credentials.Certificate(str(path)))

        project_id = _env("GOOGLE_CLOUD_PROJECT")
        options = {"projectId": project_id} if project_id else None
        return firebase_admin.initialize_app(credentials.ApplicationDefault(), options)
