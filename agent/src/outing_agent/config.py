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

CONFIDENCE_THRESHOLD: float | None = None

PLACES_STORE = os.environ.get("PLACES_STORE", "").strip() or "fixture"
if PLACES_STORE not in ("fixture", "firestore"):
    raise ValueError(f"PLACES_STORE must be 'fixture' or 'firestore', got {PLACES_STORE!r}")

CHECK_REVOKED = os.environ.get("CHECK_REVOKED", "").strip().lower() in ("1", "true", "yes")
