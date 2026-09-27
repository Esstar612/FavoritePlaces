import json
from contextlib import contextmanager
from itertools import pairwise
from types import SimpleNamespace

import pytest
from langchain_core.messages import AIMessage

from outing_agent import run as run_module
from outing_agent.graph.builder import build_graph
from outing_agent.graph.state import AgentContext
from outing_agent.places.fixtures import DEMO_UID, OTHER_UID, PLANNER_UID
from outing_agent.places.store import FixturePlacesStore
from outing_agent.run import RECURSION_LIMIT, run_recommendation
from outing_agent.tools.places_tools import TOOLS, get_place_details, plan_route, search_places
from tests.fakes import (
    ALL_RECOMMENDED,
    COUNTS_AS_GROUNDED,
    NOT_OWNED,
    OWNED_NOT_RETRIEVED,
    looping_model,
    recommendation_set,
    scripted_model,
    tool_turn,
)


class CountingStore:
    def __init__(self):
        self.calls = 0
        self._inner = FixturePlacesStore()

    def list_places(self, uid):
        self.calls += 1
        return self._inner.list_places(uid)


def _run(uid=DEMO_UID, store=None, store_kind="fixture", recommended=ALL_RECOMMENDED):
    graph = build_graph(scripted_model(recommended))
    return run_recommendation(
        graph,
        "a slow coffee morning",
        uid=uid,
        store=store or FixturePlacesStore(),
        store_kind=store_kind,
        provider="fake",
        model="scripted",
    )


def _runtime(uid=DEMO_UID):
    return SimpleNamespace(context=AgentContext(uid=uid, store=FixturePlacesStore()))


def test_run_calls_tools_and_keeps_only_grounded_owned_places():
    result = _run()

    assert [call.name for call in result.tool_calls] == ["search_places", "get_place_details"]
    assert [rec.place_id for rec in result.recommendations] == COUNTS_AS_GROUNDED
    assert [rec.order for rec in result.recommendations] == [1, 2]
    assert result.recommendations[0].title == "Blue Bottle Coffee"
    assert [rec.category for rec in result.recommendations] == ["cafe", "restaurant"]
    assert result.ungrounded_place_ids == [OWNED_NOT_RETRIEVED]
    assert result.rejected_place_ids == NOT_OWNED
    assert result.overview == "A slow morning of coffee and pastries."


def test_other_user_gets_none_of_the_demo_users_places():
    result = _run(uid=OTHER_UID)

    assert result.recommendations == []
    assert set(result.rejected_place_ids) == set(ALL_RECOMMENDED) - {"other-dolores-park"}
    assert result.ungrounded_place_ids == ["other-dolores-park"]


def test_store_is_read_once_per_run():
    store = CountingStore()

    _run(store=store)

    assert store.calls == 1


@pytest.mark.parametrize("store_kind, expect_disabled", [("firestore", True), ("fixture", False)])
def test_firestore_runs_are_not_traced(monkeypatch, store_kind, expect_disabled):
    calls = []

    @contextmanager
    def fake_tracing_context(**kwargs):
        calls.append(kwargs)
        yield

    monkeypatch.setattr(run_module, "tracing_context", fake_tracing_context)

    _run(store_kind=store_kind)

    assert calls == ([{"enabled": False}] if expect_disabled else [])


def test_tools_hide_runtime_and_uid_from_the_model():
    for tool in TOOLS:
        properties = tool.tool_call_schema.model_json_schema().get("properties", {})
        assert "runtime" not in properties
        assert "uid" not in properties


def test_search_rows_leave_out_notes():
    payload = json.loads(search_places.func(runtime=_runtime(), query="coffee"))

    assert [row["id"] for row in payload["places"]] == ["demo-blue-bottle"]
    assert "notes" not in payload["places"][0]


def test_details_only_return_the_users_own_places():
    payload = json.loads(
        get_place_details.func(runtime=_runtime(), place_ids=["demo-tartine", "other-dolores-park"])
    )

    assert [row["id"] for row in payload["places"]] == ["demo-tartine"]
    assert payload["places"][0]["notes"]
    assert payload["not_found"] == ["other-dolores-park"]


def test_route_optimize_visits_nearest_first():
    payload = json.loads(
        plan_route.func(
            runtime=_runtime(),
            place_ids=["demo-blue-bottle", "demo-golden-gate-park", "demo-sfmoma", "nope"],
            optimize=True,
        )
    )

    assert payload["order"] == ["demo-blue-bottle", "demo-sfmoma", "demo-golden-gate-park"]
    assert len(payload["legs"]) == 2
    assert payload["not_found"] == ["nope"]
    assert payload["optimized"] is True


def test_route_keeps_the_given_order_by_default():
    ids = ["demo-sfmoma", "demo-golden-gate-park", "demo-blue-bottle"]

    payload = json.loads(plan_route.func(runtime=_runtime(), place_ids=ids))

    assert payload["order"] == ids
    assert [(leg["from"], leg["to"]) for leg in payload["legs"]] == list(pairwise(ids))
    assert payload["optimized"] is False
    assert payload["truncated"] == []


PLANNER_IDS = [
    "planner-sightglass",
    "planner-workshop-cafe",
    "planner-de-young",
    "planner-zuni",
    "planner-crissy-field",
    "planner-trick-dog",
]


def test_route_reports_ids_beyond_the_limit():
    payload = json.loads(plan_route.func(runtime=_runtime(PLANNER_UID), place_ids=PLANNER_IDS))

    assert payload["order"] == PLANNER_IDS[:5]
    assert len(payload["legs"]) == 4
    assert payload["truncated"] == PLANNER_IDS[5:]
    assert payload["not_found"] == []


def test_details_report_ids_beyond_the_limit():
    payload = json.loads(
        get_place_details.func(runtime=_runtime(PLANNER_UID), place_ids=PLANNER_IDS)
    )

    assert [row["id"] for row in payload["places"]] == PLANNER_IDS[:5]
    assert payload["truncated"] == PLANNER_IDS[5:]
    assert payload["not_found"] == []


def test_route_needs_two_known_places():
    payload = json.loads(plan_route.func(runtime=_runtime(), place_ids=["demo-sfmoma", "nope"]))

    assert "error" in payload


def test_run_that_never_stops_calling_tools_still_finalizes():
    model = looping_model("demo-blue-bottle")

    result = run_recommendation(
        build_graph(model),
        "coffee",
        uid=DEMO_UID,
        store=FixturePlacesStore(),
        store_kind="fixture",
        provider="fake",
        model="looping",
    )

    assert 0 < len(result.tool_calls) < RECURSION_LIMIT
    assert [rec.place_id for rec in result.recommendations] == ["demo-blue-bottle"]
    assert result.tool_calls[-1].name == "get_place_details"
    assert result.tool_calls[-1].source == "graph"
    assert len(model.finalize_inputs) == 2
    for finalize_messages in model.finalize_inputs:
        before_prompt = finalize_messages[-2]
        assert not (isinstance(before_prompt, AIMessage) and before_prompt.tool_calls)


BLUE_BOTTLE, TARTINE, ALCATRAZ = "demo-blue-bottle", "demo-tartine", "demo-alcatraz"
FIVE_STAR_SEARCH = [tool_turn("search_places", {"min_rating": 5}, "call_1")]


def _run_model(model):
    return run_recommendation(
        build_graph(model),
        "two stops, only places I rated 5 stars",
        uid=DEMO_UID,
        store=FixturePlacesStore(),
        store_kind="fixture",
        provider="fake",
        model="scripted",
    )


def _calls(result):
    return [(call.name, call.args.get("place_ids"), call.source) for call in result.tool_calls]


def test_fallback_reads_unread_picks_and_routes_an_itinerary():
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE],
        kind="itinerary",
        turns=FIVE_STAR_SEARCH,
        revised=recommendation_set([BLUE_BOTTLE, TARTINE], "itinerary", "from the notes"),
    )

    result = _run_model(model)

    assert _calls(result) == [
        ("search_places", None, "model"),
        ("get_place_details", [BLUE_BOTTLE, TARTINE], "graph"),
        ("plan_route", [BLUE_BOTTLE, TARTINE], "graph"),
    ]
    assert [rec.place_id for rec in result.recommendations] == [BLUE_BOTTLE, TARTINE]
    assert {rec.reason for rec in result.recommendations} == {"from the notes"}
    assert result.kind == "itinerary"
    assert result.draft_place_ids == [BLUE_BOTTLE, TARTINE]
    assert result.draft_grounded_place_ids == [BLUE_BOTTLE, TARTINE]
    assert result.fallback_removed_place_ids == []


def test_second_finalize_sees_the_draft_and_the_tool_results():
    model = scripted_model([BLUE_BOTTLE, TARTINE], kind="itinerary", turns=FIVE_STAR_SEARCH)

    _run_model(model)

    first, second = model.finalize_inputs
    prompt = second[-1].content
    assert model.finals[0].model_dump_json() in prompt
    assert "Amazing pour over" in prompt
    assert '"legs"' in prompt
    assert first[:-1] == second[:-1]


def test_fallback_keeps_the_draft_order_for_options():
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE],
        turns=FIVE_STAR_SEARCH,
        revised=recommendation_set([TARTINE, BLUE_BOTTLE], "options", "from the notes"),
    )

    result = _run_model(model)

    assert _calls(result) == [
        ("search_places", None, "model"),
        ("get_place_details", [BLUE_BOTTLE, TARTINE], "graph"),
    ]
    assert [rec.place_id for rec in result.recommendations] == [BLUE_BOTTLE, TARTINE]
    assert [rec.order for rec in result.recommendations] == [1, 2]
    assert result.kind == "options"


@pytest.mark.parametrize(
    "revised_ids, final_ids, removed",
    [
        ([BLUE_BOTTLE, ALCATRAZ], [BLUE_BOTTLE], [ALCATRAZ]),
        ([ALCATRAZ], [BLUE_BOTTLE, TARTINE], [ALCATRAZ]),
        ([], [], []),
    ],
    ids=["added-place-removed", "all-new-reverts-to-draft", "empty-accepted"],
)
def test_second_answer_may_drop_places_but_not_add_them(revised_ids, final_ids, removed):
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE],
        kind="itinerary",
        turns=FIVE_STAR_SEARCH,
        revised=recommendation_set(revised_ids, "itinerary"),
    )

    result = _run_model(model)

    assert [rec.place_id for rec in result.recommendations] == final_ids
    assert result.fallback_removed_place_ids == removed
    assert result.draft_place_ids == [BLUE_BOTTLE, TARTINE]


def test_no_fallback_when_the_model_read_and_routed():
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE],
        kind="itinerary",
        turns=[
            *FIVE_STAR_SEARCH,
            tool_turn("get_place_details", {"place_ids": [BLUE_BOTTLE, TARTINE]}, "call_2"),
            tool_turn("plan_route", {"place_ids": [BLUE_BOTTLE, TARTINE]}, "call_3"),
        ],
    )

    result = _run_model(model)

    assert {call.source for call in result.tool_calls} == {"model"}
    assert len(model.finalize_inputs) == 1
    assert result.draft_place_ids == [BLUE_BOTTLE, TARTINE]
    assert result.fallback_removed_place_ids == []


def test_fallback_does_not_read_places_the_model_never_retrieved():
    model = scripted_model(
        [BLUE_BOTTLE, OWNED_NOT_RETRIEVED], kind="itinerary", turns=FIVE_STAR_SEARCH
    )

    result = _run_model(model)

    assert _calls(result) == [
        ("search_places", None, "model"),
        ("get_place_details", [BLUE_BOTTLE], "graph"),
    ]
    assert result.ungrounded_place_ids == [OWNED_NOT_RETRIEVED]
    assert result.draft_place_ids == [BLUE_BOTTLE, OWNED_NOT_RETRIEVED]
    assert result.draft_grounded_place_ids == [BLUE_BOTTLE]


def _with_threshold(monkeypatch, threshold):
    monkeypatch.setattr(run_module, "confidence_threshold", lambda provider: threshold)


def test_low_confidence_escalates_with_the_question_and_no_places(monkeypatch):
    _with_threshold(monkeypatch, 0.6)
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE], kind="itinerary", turns=FIVE_STAR_SEARCH, confidence=0.3
    )

    result = _run_model(model)

    assert result.escalated is True
    assert result.recommendations == []
    assert result.overview == ""
    assert result.clarifying_question == "Morning or evening?"
    assert result.confidence == 0.3
    assert len(model.finalize_inputs) == 1
    assert {call.source for call in result.tool_calls} == {"model"}
    assert result.draft_place_ids == [BLUE_BOTTLE, TARTINE]


def test_confident_answer_is_not_escalated(monkeypatch):
    _with_threshold(monkeypatch, 0.6)
    model = scripted_model([BLUE_BOTTLE, TARTINE], confidence=0.9)

    result = _run_model(model)

    assert result.escalated is False
    assert result.clarifying_question is None
    assert [rec.place_id for rec in result.recommendations] == [BLUE_BOTTLE, TARTINE]
    assert result.overview


def test_no_threshold_never_escalates(monkeypatch):
    _with_threshold(monkeypatch, None)
    model = scripted_model([BLUE_BOTTLE, TARTINE], confidence=0.0)

    result = _run_model(model)

    assert result.escalated is False
    assert result.clarifying_question is None
    assert result.recommendations


def test_reported_confidence_is_the_drafts_even_after_the_fallback(monkeypatch, caplog):
    _with_threshold(monkeypatch, 0.5)
    model = scripted_model(
        [BLUE_BOTTLE, TARTINE],
        kind="itinerary",
        turns=FIVE_STAR_SEARCH,
        confidence=0.8,
        revised=recommendation_set([BLUE_BOTTLE, TARTINE], "itinerary", confidence=0.2),
    )

    with caplog.at_level("INFO", logger="outing_agent.run"):
        result = _run_model(model)

    assert len(model.finalize_inputs) == 2
    assert result.confidence == 0.8
    assert result.escalated is False
    logged = [
        json.loads(r.getMessage()) for r in caplog.records if "recommendation_run" in r.getMessage()
    ]
    assert logged[-1]["confidence"] == 0.8
    assert logged[-1]["escalated"] is False


CLARIFICATION = {
    "original_message": "Plan my Saturday",
    "question": "Morning or evening?",
    "answer": "Morning, coffee first.",
}


def test_request_text_without_a_clarification_is_the_message():
    assert run_module.request_text("coffee", None) == "coffee"


def test_request_text_combines_the_clarification_into_one_message():
    text = run_module.request_text(None, CLARIFICATION)

    assert text == (
        "Plan my Saturday\n\nYou asked: Morning or evening?\nMy answer: Morning, coffee first."
    )


def test_clarified_request_recommends_even_with_zero_confidence(monkeypatch):
    _with_threshold(monkeypatch, 0.6)
    model = scripted_model([BLUE_BOTTLE, TARTINE], confidence=0.0)

    result = run_recommendation(
        build_graph(model),
        None,
        clarification=CLARIFICATION,
        uid=DEMO_UID,
        store=FixturePlacesStore(),
        store_kind="fixture",
        provider="fake",
        model="scripted",
    )

    assert result.escalated is False
    assert result.clarification_round is True
    assert result.clarifying_question is None
    assert [rec.place_id for rec in result.recommendations] == [BLUE_BOTTLE, TARTINE]
    (finalize_messages,) = model.finalize_inputs
    assert finalize_messages[1].content == run_module.request_text(None, CLARIFICATION)
    assert "do not ask another" in finalize_messages[-1].content
