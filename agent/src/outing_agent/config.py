import json
import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

MODELS = {
    "anthropic": "claude-sonnet-5",
    "openai": "gpt-6-sol",
}

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "").strip() or "anthropic"
if LLM_PROVIDER not in MODELS:
    raise ValueError(f"LLM_PROVIDER must be one of {sorted(MODELS)}, got {LLM_PROVIDER!r}")

MAX_OUTPUT_TOKENS = 4096
REQUEST_TIMEOUT_S = 60

RANDOM_SEED = 42

CONFIDENCE_THRESHOLDS_FILE = Path(__file__).with_name("confidence_thresholds.json")


def confidence_threshold(provider: str, path: Path = CONFIDENCE_THRESHOLDS_FILE) -> float | None:
    if not path.exists():
        return None
    return json.loads(path.read_text())["providers"].get(provider)


PLACES_STORE = os.environ.get("PLACES_STORE", "").strip() or "fixture"
if PLACES_STORE not in ("fixture", "firestore"):
    raise ValueError(f"PLACES_STORE must be 'fixture' or 'firestore', got {PLACES_STORE!r}")

CHECK_REVOKED = os.environ.get("CHECK_REVOKED", "").strip().lower() in ("1", "true", "yes")


def _positive_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    value = int(raw)
    if value < 1:
        raise ValueError(f"{name} must be a positive integer, got {raw!r}")
    return value


RECOMMEND_LIMIT_PER_USER_PER_HOUR = _positive_int("RECOMMEND_LIMIT_PER_USER_PER_HOUR", 20)
RECOMMEND_LIMIT_GLOBAL_PER_HOUR = _positive_int("RECOMMEND_LIMIT_GLOBAL_PER_HOUR", 200)
