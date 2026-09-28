import json
from contextlib import contextmanager
from itertools import pairwise
from types import SimpleNamespace

import pytest
from langchain_core.messages import AIMessage, ToolMessage

from outing_agent import run as run_module
from outing_agent.graph.builder import (
    CLARIFIED_NOTE,
    FINALIZE_PROMPT,
    START_ONLY_NOTE,
    build_graph,
    finalize_prompt,
)
from outing_agent.graph.state import AgentContext
from outing_agent.places.fixtures import DEMO_UID, OTHER_UID, PLANNER_UID
from outing_agent.places.models import Place
from outing_agent.places.store import FixturePlacesStore
from outing_agent.run import (
    RECURSION_LIMIT,
    RecommendedPlace,
    UnknownStartPlace,
    anchor_start,
    request_text,
    run_recommendation,
)
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
    assert [(leg.from_place_id, leg.to_place_id) for leg in result.legs] == [(BLUE_BOTTLE, TARTINE)]


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
    assert result.legs == []


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


def _answer(payload, call_id):
    return ToolMessage(json.dumps(payload), tool_call_id=call_id)


def test_tool_calls_carry_the_places_each_call_returned():
    messages = [
        tool_turn("search_places", {"query": "coffee"}, "c1"),
        _answer({"places": [{"id": "a"}, {"id": "b"}], "matched": 4, "total_saved": 5}, "c1"),
        tool_turn("get_place_details", {"place_ids": ["a", "x"]}, "c2"),
        _answer({"places": [{"id": "a"}], "not_found": ["x"], "truncated": []}, "c2"),
        tool_turn("plan_route", {"place_ids": ["b", "a"]}, "c3"),
        _answer({"order": ["b", "a"], "legs": [], "not_found": [], "truncated": []}, "c3"),
    ]

    calls = run_module.collect_tool_calls(messages, [])

    assert [(c.name, c.result_place_ids, c.matched, c.source) for c in calls] == [
        ("search_places", ["a", "b"], 4, "model"),
        ("get_place_details", ["a"], None, "model"),
        ("plan_route", ["b", "a"], None, "model"),
    ]


def test_fallback_calls_carry_their_results():
    fallback = [
        {
            "name": "plan_route",
            "args": {"place_ids": ["a", "b"]},
            "result": json.dumps({"order": ["a", "b"], "legs": []}),
        }
    ]

    [call] = run_module.collect_tool_calls([], fallback)

    assert (call.source, call.result_place_ids, call.matched) == ("graph", ["a", "b"], None)


def test_unparseable_tool_result_gives_no_places():
    messages = [
        tool_turn("search_places", {"query": "coffee"}, "c1"),
        ToolMessage("Error: boom", tool_call_id="c1"),
    ]

    [call] = run_module.collect_tool_calls(messages, [])

    assert (call.result_place_ids, call.matched) == ([], None)


def _place(place_id, lat):
    return Place(id=place_id, title=place_id, lat=lat, lng=-122.4, address="SF")


def _stop(place_id, order):
    return RecommendedPlace(
        place_id=place_id, title=place_id, category="other", order=order, reason="r"
    )


def test_itinerary_legs_estimate_walking_minutes():
    owned = {"a": _place("a", 37.77), "b": _place("b", 37.78), "c": _place("c", 37.81)}
    stops = [_stop("a", 1), _stop("b", 2), _stop("c", 3)]

    legs = run_module.walking_legs(stops, owned, "itinerary")

    assert [(leg.from_place_id, leg.to_place_id, leg.walk_minutes) for leg in legs] == [
        ("a", "b", 18),
        ("b", "c", None),
    ]


def test_options_get_no_legs():
    owned = {"a": _place("a", 37.77), "b": _place("b", 37.78)}

    assert run_module.walking_legs([_stop("a", 1), _stop("b", 2)], owned, "options") == []


def test_one_stop_gets_no_legs():
    assert run_module.walking_legs([_stop("a", 1)], {"a": _place("a", 37.77)}, "itinerary") == []


def _ids(stops):
    return [stop.place_id for stop in stops]


@pytest.mark.parametrize(
    "kind, stops, expected_ids, expected_kind",
    [
        ("itinerary", ["x", "s", "y"], ["s", "x", "y"], "itinerary"),
        ("itinerary", ["x", "y"], ["s", "x", "y"], "itinerary"),
        ("options", ["x", "s", "y"], ["s", "x"], "itinerary"),
        ("options", ["s"], ["s"], "options"),
        ("options", [], [], "options"),
    ],
    ids=["reorder", "insert", "trim-options", "only-start", "nothing"],
)
def test_anchor_start(kind, stops, expected_ids, expected_kind):
    start = _place("s", 37.77)
    stop_list = [_stop(place_id, i) for i, place_id in enumerate(stops, 1)]

    anchored, anchored_kind = anchor_start(stop_list, start, kind)

    assert _ids(anchored) == expected_ids
    assert [stop.order for stop in anchored] == list(range(1, len(expected_ids) + 1))
    assert anchored_kind == expected_kind


def test_inserted_start_place_has_an_empty_reason():
    anchored, _ = anchor_start([_stop("x", 1)], _place("s", 37.77), "itinerary")

    assert anchored[0].reason == ""


def test_request_text_is_unchanged_without_a_start_place():
    assert request_text("coffee", None, None) == "coffee"
    assert request_text(None, CLARIFICATION, None) == request_text(None, CLARIFICATION)


def _run_from(start_place_id, store=None, model=None):
    model = model or scripted_model(ALL_RECOMMENDED)
    return model, run_recommendation(
        build_graph(model),
        "a slow coffee morning",
        start_place_id=start_place_id,
        uid=DEMO_UID,
        store=store or FixturePlacesStore(),
        store_kind="fixture",
        provider="fake",
        model="scripted",
    )


def test_run_from_a_start_place_puts_it_first_with_one_leg():
    model, result = _run_from(TARTINE)

    assert _ids(result.recommendations) == [TARTINE, BLUE_BOTTLE]
    assert result.kind == "itinerary"
    assert [(leg.from_place_id, leg.to_place_id) for leg in result.legs] == [(TARTINE, BLUE_BOTTLE)]
    assert result.start_place_id == TARTINE
    (finalize_messages,) = model.finalize_inputs
    assert finalize_messages[1].content == (
        "Plan an outing that starts at Tartine Bakery (demo-tartine), then a slow coffee morning"
    )


def test_run_without_a_start_place_sends_the_plain_request():
    model, _ = _run_from(None)

    (finalize_messages,) = model.finalize_inputs
    assert finalize_messages[1].content == "a slow coffee morning"


def test_unknown_start_place_fails_before_the_graph_runs():
    store = CountingStore()
    model = scripted_model(ALL_RECOMMENDED)

    with pytest.raises(UnknownStartPlace):
        _run_from("other-dolores-park", store=store, model=model)

    assert store.calls == 1
    assert model.finalize_inputs == []


def test_finalize_prompt_notes():
    assert finalize_prompt({"clarification_allowed": True}) == FINALIZE_PROMPT
    assert finalize_prompt({"clarification_allowed": False}) == FINALIZE_PROMPT + CLARIFIED_NOTE
    assert finalize_prompt({"clarification_allowed": False, "start_only": True}) == (
        FINALIZE_PROMPT + START_ONLY_NOTE
    )


def _low_confidence_run(monkeypatch, message):
    _with_threshold(monkeypatch, 0.6)
    model = scripted_model(ALL_RECOMMENDED, confidence=0.3)
    result = run_recommendation(
        build_graph(model),
        message,
        start_place_id=BLUE_BOTTLE,
        uid=DEMO_UID,
        store=FixturePlacesStore(),
        store_kind="fixture",
        provider="fake",
        model="scripted",
    )
    return model, result


def test_a_start_place_alone_never_asks(monkeypatch):
    model, result = _low_confidence_run(monkeypatch, None)

    assert result.escalated is False
    assert result.recommendations[0].place_id == BLUE_BOTTLE
    (finalize_messages,) = model.finalize_inputs
    assert finalize_messages[-1].content.endswith(START_ONLY_NOTE)


def test_a_start_place_with_a_message_can_still_ask(monkeypatch):
    _, result = _low_confidence_run(monkeypatch, "somewhere nice")

    assert result.escalated is True
    assert result.recommendations == []
