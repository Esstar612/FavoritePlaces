import pytest

from evals import scorers
from evals.dataset import CASE_SETS, REFERENCE_KEYS, load_cases, to_example
from outing_agent.places.fixtures import FIXTURE_PLACES
from outing_agent.places.models import CATEGORIES


def outputs(recs=(), tool_calls=(), ungrounded=(), rejected=(), categories=None):
    categories = categories or ["cafe"] * len(recs)
    return {
        "recommendations": [
            {"place_id": place_id, "category": category, "order": i + 1}
            for i, (place_id, category) in enumerate(zip(recs, categories))
        ],
        "tool_calls": [{"name": name, "args": args} for name, args in tool_calls],
        "ungrounded_place_ids": list(ungrounded),
        "rejected_place_ids": list(rejected),
    }


def reference(**overrides):
    ref = {
        "expected_place_ids": [],
        "forbidden_place_ids": [],
        "required_tools": [],
        "expects_route": False,
        "expects_empty": False,
        "must_mention": [],
        "requested_sequence": [],
        "sequence_ordered": False,
        "requested_stop_count": None,
    }
    ref.update(overrides)
    return ref


def score(scorer, out, ref=None):
    return scorer(outputs=out, reference_outputs=ref or reference())["score"]


DETAILS = ("get_place_details", {"place_ids": ["a", "b"]})
ROUTE = ("plan_route", {"place_ids": ["a", "b"]})
SEARCH = ("search_places", {"query": "coffee"})


def test_grounded():
    assert score(scorers.grounded, outputs(recs=["a"])) == 1
    assert score(scorers.grounded, outputs(recs=["a"], ungrounded=["b"])) == 0
    assert score(scorers.grounded, outputs(recs=["a"], rejected=["x"])) == 0
    assert score(scorers.grounded, {}) == 0


def test_no_forbidden_counts_dropped_picks_too():
    ref = reference(forbidden_place_ids=["f"])
    assert score(scorers.no_forbidden, outputs(recs=["a"]), ref) == 1
    assert score(scorers.no_forbidden, outputs(recs=["f"]), ref) == 0
    assert score(scorers.no_forbidden, outputs(rejected=["f"]), ref) == 0
    assert score(scorers.no_forbidden, {}, ref) == 0


def test_expected_recall():
    ref = reference(expected_place_ids=["a", "b"])
    assert score(scorers.expected_recall, outputs(recs=["a", "b", "c"]), ref) == 1
    assert score(scorers.expected_recall, outputs(recs=["a"]), ref) == 0.5
    assert score(scorers.expected_recall, outputs(), reference()) is None


def test_expected_recall_caps_at_requested_stop_count():
    ref = reference(expected_place_ids=["a", "b", "c"], requested_stop_count=2)
    assert score(scorers.expected_recall, outputs(recs=["a", "c"]), ref) == 1
    assert score(scorers.expected_recall, outputs(recs=["a", "x"]), ref) == 0.5


def test_covers_request_counts_repeated_stop_types():
    ref = reference(requested_sequence=["cafe", "cafe", "park"])
    both_cafes = outputs(recs=["a", "b", "c"], categories=["cafe", "cafe", "park"])
    one_cafe = outputs(recs=["a", "c"], categories=["cafe", "park"])
    assert score(scorers.covers_request, both_cafes, ref) == 1
    assert score(scorers.covers_request, one_cafe, ref) == 0
    assert score(scorers.covers_request, both_cafes, reference()) is None


def test_respects_sequence():
    ref = reference(requested_sequence=["cafe", "museum", "park"], sequence_ordered=True)
    in_order = outputs(recs=["a", "b", "c"], categories=["cafe", "museum", "park"])
    with_extra = outputs(recs=["a", "x", "b", "c"], categories=["cafe", "bar", "museum", "park"])
    swapped = outputs(recs=["a", "c", "b"], categories=["cafe", "park", "museum"])
    assert score(scorers.respects_sequence, in_order, ref) == 1
    assert score(scorers.respects_sequence, with_extra, ref) == 1
    assert score(scorers.respects_sequence, swapped, ref) == 0


def test_respects_sequence_skips_unordered_and_non_day_plan_cases():
    unordered = reference(requested_sequence=["cafe", "park"], sequence_ordered=False)
    recs = outputs(recs=["a", "b"], categories=["park", "cafe"])
    assert score(scorers.respects_sequence, recs, unordered) is None
    assert score(scorers.respects_sequence, recs, reference()) is None


def test_details_before_recommending():
    assert score(scorers.details_before_recommending, outputs(recs=["a", "b"], tool_calls=[DETAILS])) == 1
    assert score(scorers.details_before_recommending, outputs(recs=["a", "c"], tool_calls=[DETAILS])) == 0
    assert score(scorers.details_before_recommending, outputs()) is None


def test_route_when_multi_stop_only_scores_route_cases():
    route_case = reference(expects_route=True)
    assert score(scorers.route_when_multi_stop, outputs(recs=["a", "b"], tool_calls=[ROUTE]), route_case) == 1
    assert score(scorers.route_when_multi_stop, outputs(recs=["a", "b"], tool_calls=[DETAILS]), route_case) == 0
    assert score(scorers.route_when_multi_stop, outputs(recs=["a", "b"], tool_calls=[DETAILS])) is None


def test_required_tools_used():
    ref = reference(required_tools=["search_places", "get_place_details"])
    assert score(scorers.required_tools_used, outputs(tool_calls=[SEARCH, DETAILS]), ref) == 1
    assert score(scorers.required_tools_used, outputs(tool_calls=[SEARCH]), ref) == 0
    assert score(scorers.required_tools_used, outputs(), reference()) is None


def test_empty_when_nothing_fits():
    ref = reference(expects_empty=True)
    assert score(scorers.empty_when_nothing_fits, outputs(), ref) == 1
    assert score(scorers.empty_when_nothing_fits, outputs(recs=["a"]), ref) == 0
    assert score(scorers.empty_when_nothing_fits, outputs(recs=["a"]), reference()) is None


def test_tool_call_budget():
    within = outputs(tool_calls=[SEARCH] * scorers.DEFAULT_TOOL_CALL_BUDGET)
    over = outputs(tool_calls=[SEARCH] * (scorers.DEFAULT_TOOL_CALL_BUDGET + 1))
    assert score(scorers.tool_call_budget, within) == 1
    assert score(scorers.tool_call_budget, over) == 0
    assert score(scorers.tool_call_budget, {}) == 0


def test_tool_call_budget_is_two_plus_two_per_requested_stop():
    four_stops = reference(requested_sequence=["cafe", "museum", "restaurant", "park"])
    assert scorers.tool_call_limit(four_stops) == 10
    assert score(scorers.tool_call_budget, outputs(tool_calls=[SEARCH] * 10), four_stops) == 1
    assert score(scorers.tool_call_budget, outputs(tool_calls=[SEARCH] * 11), four_stops) == 0


def test_tool_call_budget_counts_unsatisfiable_stops():
    movie = reference(requested_sequence=["cafe", "restaurant"], requested_stop_count=3)
    assert scorers.tool_call_limit(movie) == 8


def test_every_scorer_reports_its_own_key():
    for scorer in scorers.EVALUATORS:
        assert scorer(outputs=outputs(), reference_outputs=reference())["key"] == scorer.__name__


def test_gates_only_name_real_scorers():
    assert set(scorers.GATES) <= {scorer.__name__ for scorer in scorers.EVALUATORS}


def test_report_only_names_real_scorers_that_are_not_gates():
    assert set(scorers.REPORT_ONLY) <= {scorer.__name__ for scorer in scorers.EVALUATORS}
    assert not set(scorers.REPORT_ONLY) & set(scorers.GATES)


def after_fallback(out, *graph_calls, draft=(), draft_grounded=None, removed=()):
    return {
        **out,
        "tool_calls": [
            *out["tool_calls"],
            *({"name": name, "args": args, "source": "graph"} for name, args in graph_calls),
        ],
        "draft_place_ids": list(draft),
        "draft_grounded_place_ids": list(draft if draft_grounded is None else draft_grounded),
        "fallback_removed_place_ids": list(removed),
    }


def test_tool_use_scorers_count_only_model_calls():
    out = after_fallback(outputs(recs=["a", "b"], tool_calls=[SEARCH]), DETAILS, ROUTE, draft=["a", "b"])
    required = reference(required_tools=["search_places", "get_place_details"], expects_route=True)
    assert score(scorers.details_before_recommending, out) == 0
    assert score(scorers.route_when_multi_stop, out, required) == 0
    assert score(scorers.required_tools_used, out, required) == 0

    at_budget = outputs(tool_calls=[SEARCH] * scorers.DEFAULT_TOOL_CALL_BUDGET)
    assert score(scorers.tool_call_budget, after_fallback(at_budget, DETAILS, ROUTE)) == 1


def test_fallback_rate():
    assert score(scorers.fallback_rate, outputs(recs=["a"], tool_calls=[SEARCH, DETAILS])) == 0
    assert score(scorers.fallback_rate, after_fallback(outputs(recs=["a"], tool_calls=[SEARCH]), DETAILS)) == 1
    assert score(scorers.fallback_rate, {}) is None


def test_details_before_recommending_scores_the_grounded_draft_after_a_fallback():
    read_a = ("get_place_details", {"place_ids": ["a"]})
    read_c = ("get_place_details", {"place_ids": ["c"]})
    dropped_unread_pick = after_fallback(
        outputs(recs=["a"], tool_calls=[SEARCH, read_a]), read_c, draft=["a", "c"]
    )
    routed_only = after_fallback(outputs(recs=["a", "b"], tool_calls=[SEARCH, DETAILS]), ROUTE, draft=["a", "b"])
    assert score(scorers.details_before_recommending, dropped_unread_pick) == 0
    assert score(scorers.details_before_recommending, routed_only) == 1


def test_ungrounded_draft_pick_is_ignored_by_details_but_seen_by_no_forbidden():
    read_a = ("get_place_details", {"place_ids": ["a"]})
    out = after_fallback(
        outputs(recs=["a"], tool_calls=[SEARCH, read_a]),
        ROUTE,
        draft=["a", "x"],
        draft_grounded=["a"],
    )
    assert score(scorers.details_before_recommending, out) == 1
    assert score(scorers.no_forbidden, out, reference(forbidden_place_ids=["x"])) == 0


def test_no_forbidden_counts_draft_and_removed_picks():
    ref = reference(forbidden_place_ids=["f"])
    in_draft = after_fallback(outputs(recs=["a"], tool_calls=[SEARCH]), DETAILS, draft=["a", "f"])
    removed = after_fallback(outputs(recs=["a"], tool_calls=[SEARCH]), DETAILS, draft=["a"], removed=["f"])
    assert score(scorers.no_forbidden, in_draft, ref) == 0
    assert score(scorers.no_forbidden, removed, ref) == 0


ALL_CASES = [case for case_set in sorted(CASE_SETS) for case in load_cases(case_set)]


def test_case_ids_are_unique_across_sets():
    ids = [case["id"] for case in ALL_CASES]
    assert len(ids) == len(set(ids))


@pytest.mark.parametrize("case", ALL_CASES, ids=lambda case: case["id"])
def test_case_is_consistent_with_fixtures(case):
    owned = {uid: {place.id: place for place in places} for uid, places in FIXTURE_PLACES.items()}
    all_ids = {place_id for places in owned.values() for place_id in places}
    assert set(to_example(case)["outputs"]) == set(REFERENCE_KEYS)
    assert case["uid"] in owned
    assert set(case["expected_place_ids"]) <= set(owned[case["uid"]])
    assert set(case["forbidden_place_ids"]) <= all_ids
    assert not set(case["expected_place_ids"]) & set(case["forbidden_place_ids"])
    assert set(case["requested_sequence"]) <= set(CATEGORIES)
    if case["expects_empty"]:
        assert not case["expected_place_ids"]
        assert not case["requested_sequence"]
    if case["requested_stop_count"] is not None:
        assert case["requested_stop_count"] > 0
        assert case["requested_stop_count"] >= len(case["requested_sequence"])
        if case["expected_place_ids"]:
            assert case["requested_stop_count"] <= len(case["expected_place_ids"])
    user_categories = {place.category for place in owned[case["uid"]].values()}
    assert set(case["requested_sequence"]) <= user_categories


@pytest.mark.parametrize("case", ALL_CASES, ids=lambda case: case["id"])
def test_required_tools_are_real_tools(case):
    from outing_agent.tools.places_tools import TOOLS

    assert set(case["required_tools"]) <= {tool.name for tool in TOOLS}
