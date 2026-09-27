from collections import Counter

DEFAULT_TOOL_CALL_BUDGET = 6
DAY_PLAN_BASE_TOOL_CALLS = 2
DAY_PLAN_CALLS_PER_STOP = 2

GATES = {"grounded": 1.0, "no_forbidden": 1.0}
REPORT_ONLY = {"fallback_rate"}


def _recommended(outputs: dict) -> list[str]:
    return [rec["place_id"] for rec in outputs.get("recommendations", [])]


def _model_calls(outputs: dict) -> list[dict]:
    return [
        call for call in outputs.get("tool_calls", []) if call.get("source", "model") == "model"
    ]


def _calls(outputs: dict, name: str) -> list[dict]:
    return [call for call in _model_calls(outputs) if call["name"] == name]


def _fallback_ran(outputs: dict) -> bool:
    return any(call.get("source") == "graph" for call in outputs.get("tool_calls", []))


def grounded(outputs: dict, reference_outputs: dict) -> dict:
    ok = (
        "recommendations" in outputs
        and not outputs.get("ungrounded_place_ids")
        and not outputs.get("rejected_place_ids")
    )
    return {"key": "grounded", "score": int(ok)}


def no_forbidden(outputs: dict, reference_outputs: dict) -> dict:
    if "recommendations" not in outputs:
        return {"key": "no_forbidden", "score": 0}
    picked = {
        *_recommended(outputs),
        *outputs.get("ungrounded_place_ids", []),
        *outputs.get("rejected_place_ids", []),
        *outputs.get("draft_place_ids", []),
        *outputs.get("fallback_removed_place_ids", []),
    }
    forbidden = set(reference_outputs["forbidden_place_ids"])
    return {"key": "no_forbidden", "score": int(not picked & forbidden)}


def expected_recall(outputs: dict, reference_outputs: dict) -> dict:
    expected = set(reference_outputs["expected_place_ids"])
    if not expected:
        return {"key": "expected_recall", "score": None}
    found = expected & set(_recommended(outputs))
    needed = len(expected)
    if reference_outputs["requested_stop_count"] is not None:
        needed = min(needed, reference_outputs["requested_stop_count"])
    return {"key": "expected_recall", "score": min(len(found), needed) / needed}


def details_before_recommending(outputs: dict, reference_outputs: dict) -> dict:
    recommended = set(
        outputs.get("draft_grounded_place_ids", [])
        if _fallback_ran(outputs)
        else _recommended(outputs)
    )
    if not recommended:
        return {"key": "details_before_recommending", "score": None}
    detailed = {
        place_id
        for call in _calls(outputs, "get_place_details")
        for place_id in call["args"].get("place_ids") or []
    }
    return {"key": "details_before_recommending", "score": int(recommended <= detailed)}


def route_when_multi_stop(outputs: dict, reference_outputs: dict) -> dict:
    if not reference_outputs["expects_route"]:
        return {"key": "route_when_multi_stop", "score": None}
    return {"key": "route_when_multi_stop", "score": int(bool(_calls(outputs, "plan_route")))}


def required_tools_used(outputs: dict, reference_outputs: dict) -> dict:
    required = set(reference_outputs["required_tools"])
    if not required:
        return {"key": "required_tools_used", "score": None}
    called = {call["name"] for call in _model_calls(outputs)}
    return {"key": "required_tools_used", "score": int(required <= called)}


def empty_when_nothing_fits(outputs: dict, reference_outputs: dict) -> dict:
    if not reference_outputs["expects_empty"]:
        return {"key": "empty_when_nothing_fits", "score": None}
    return {"key": "empty_when_nothing_fits", "score": int(not _recommended(outputs))}


def _recommended_categories(outputs: dict) -> list[str]:
    recs = sorted(outputs.get("recommendations", []), key=lambda rec: rec["order"])
    return [rec["category"] for rec in recs]


def covers_request(outputs: dict, reference_outputs: dict) -> dict:
    requested = reference_outputs["requested_sequence"]
    if not requested:
        return {"key": "covers_request", "score": None}
    missing = Counter(requested) - Counter(_recommended_categories(outputs))
    return {"key": "covers_request", "score": int(not missing)}


def respects_sequence(outputs: dict, reference_outputs: dict) -> dict:
    requested = reference_outputs["requested_sequence"]
    if not requested or not reference_outputs["sequence_ordered"]:
        return {"key": "respects_sequence", "score": None}
    remaining = iter(_recommended_categories(outputs))
    in_order = all(category in remaining for category in requested)
    return {"key": "respects_sequence", "score": int(in_order)}


def requested_stops(reference_outputs: dict) -> int:
    if reference_outputs["requested_stop_count"] is not None:
        return reference_outputs["requested_stop_count"]
    return len(reference_outputs["requested_sequence"])


def tool_call_limit(reference_outputs: dict) -> int:
    stops = requested_stops(reference_outputs)
    if stops:
        return DAY_PLAN_BASE_TOOL_CALLS + DAY_PLAN_CALLS_PER_STOP * stops
    return DEFAULT_TOOL_CALL_BUDGET


def tool_call_budget(outputs: dict, reference_outputs: dict) -> dict:
    if "tool_calls" not in outputs:
        return {"key": "tool_call_budget", "score": 0}
    within = len(_model_calls(outputs)) <= tool_call_limit(reference_outputs)
    return {"key": "tool_call_budget", "score": int(within)}


def fallback_rate(outputs: dict, reference_outputs: dict) -> dict:
    if "tool_calls" not in outputs:
        return {"key": "fallback_rate", "score": None}
    return {"key": "fallback_rate", "score": int(_fallback_ran(outputs))}


EVALUATORS = [
    grounded,
    no_forbidden,
    expected_recall,
    details_before_recommending,
    route_when_multi_stop,
    required_tools_used,
    empty_when_nothing_fits,
    covers_request,
    respects_sequence,
    tool_call_budget,
    fallback_rate,
]
