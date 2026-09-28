import json
from pathlib import Path

CASE_SETS = {
    "main": ("outing-agent-v1", Path(__file__).with_name("cases.json")),
    "holdout": ("outing-agent-holdout-v1", Path(__file__).with_name("cases_holdout.json")),
    "start_place": (
        "outing-agent-start-place-v1",
        Path(__file__).with_name("cases_start_place.json"),
    ),
}

INPUT_KEYS = ("uid", "message", "clarification", "start_place_id")
REFERENCE_KEYS = (
    "expected_place_ids",
    "forbidden_place_ids",
    "required_tools",
    "expects_route",
    "expects_empty",
    "must_mention",
    "requested_sequence",
    "sequence_ordered",
    "requested_stop_count",
    "expects_clarification",
)


def load_cases(case_set: str = "main") -> list[dict]:
    path = CASE_SETS[case_set][1]
    cases = json.loads(path.read_text())
    ids = [case["id"] for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError(f"case ids in {path.name} must be unique")
    return cases


def to_example(case: dict) -> dict:
    return {
        "inputs": {key: case[key] for key in INPUT_KEYS if key in case},
        "outputs": {key: case[key] for key in REFERENCE_KEYS},
        "metadata": {"case_id": case["id"], "tags": case["tags"]},
    }
