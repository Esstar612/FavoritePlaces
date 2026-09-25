"""Service configuration. Secrets come from agent/.env, never from this file."""

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
