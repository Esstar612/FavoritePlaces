import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

DEFAULT_PROVIDER = "anthropic"

MODELS = {
    "anthropic": "claude-sonnet-5",
    "openai": "gpt-6-sol",
}

RANDOM_SEED = 42

CONFIDENCE_THRESHOLD: float | None = None

PLACES_STORE = os.environ.get("PLACES_STORE", "").strip() or "fixture"
if PLACES_STORE not in ("fixture", "firestore"):
    raise ValueError(f"PLACES_STORE must be 'fixture' or 'firestore', got {PLACES_STORE!r}")

CHECK_REVOKED = os.environ.get("CHECK_REVOKED", "").strip().lower() in ("1", "true", "yes")
