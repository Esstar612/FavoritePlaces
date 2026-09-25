"""Service configuration. Secrets come from agent/.env, never from this file."""

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

DEFAULT_PROVIDER = "anthropic"

# Checked 2026-09-24 against the provider docs. Both are $2 / $10 per MTok,
# so cross-provider evals compare the same price tier.
# https://platform.claude.com/docs/en/about-claude/models/overview
# https://developers.openai.com/api/docs/models
MODELS = {
    "anthropic": "claude-sonnet-5",
    "openai": "gpt-6-sol",
}

RANDOM_SEED = 42

# Chosen later from eval data. None means escalation is not configured yet.
CONFIDENCE_THRESHOLD: float | None = None

# Where saved places come from: "fixture" (demo data, no credentials) or
# "firestore" (the app's real data). Fixture is the default so tests and local
# runs never need Firebase credentials.
PLACES_STORE = os.environ.get("PLACES_STORE", "").strip() or "fixture"
if PLACES_STORE not in ("fixture", "firestore"):
    raise ValueError(f"PLACES_STORE must be 'fixture' or 'firestore', got {PLACES_STORE!r}")

# Whether token verification also checks for revoked sessions and disabled
# users. Off by default, matching the Express backend. See BUILD_LOG Step 1.
CHECK_REVOKED = os.environ.get("CHECK_REVOKED", "").strip().lower() in ("1", "true", "yes")
