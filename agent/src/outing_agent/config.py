import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

DEFAULT_PROVIDER = "anthropic"

# Same $2 / $10 per MTok tier, so cross-provider evals compare like with like.
MODELS = {
    "anthropic": "claude-sonnet-5",
    "openai": "gpt-6-sol",
}

RANDOM_SEED = 42

# Set from eval data in Step 4.
CONFIDENCE_THRESHOLD: float | None = None

# Fixture by default so tests and local runs never need Firebase credentials.
PLACES_STORE = os.environ.get("PLACES_STORE", "").strip() or "fixture"
if PLACES_STORE not in ("fixture", "firestore"):
    raise ValueError(f"PLACES_STORE must be 'fixture' or 'firestore', got {PLACES_STORE!r}")

# Off by default to match the Express backend, which skips the extra Auth call.
CHECK_REVOKED = os.environ.get("CHECK_REVOKED", "").strip().lower() in ("1", "true", "yes")
