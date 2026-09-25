import json
from contextlib import contextmanager
from types import SimpleNamespace

import pytest

from outing_agent import run as run_module
from outing_agent.graph.builder import build_graph
from outing_agent.graph.state import AgentContext
from outing_agent.places.fixtures import DEMO_UID, OTHER_UID
from outing_agent.places.store import FixturePlacesStore
from outing_agent.run import run_recommendation
from outing_agent.tools.places_tools import TOOLS, get_place_details, plan_route, search_places
from tests.fakes import (
    ALL_RECOMMENDED,
    COUNTS_AS_GROUNDED,
    NOT_OWNED,
    OWNED_NOT_RETRIEVED,
    scripted_model,
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


def test_route_visits_nearest_first_and_reports_unknown_ids():
    payload = json.loads(
        plan_route.func(
            runtime=_runtime(),
            place_ids=["demo-blue-bottle", "demo-golden-gate-park", "demo-sfmoma", "nope"],
        )
    )

    assert payload["order"] == ["demo-blue-bottle", "demo-sfmoma", "demo-golden-gate-park"]
    assert len(payload["legs"]) == 2
    assert payload["not_found"] == ["nope"]


def test_route_needs_two_known_places():
    payload = json.loads(plan_route.func(runtime=_runtime(), place_ids=["demo-sfmoma", "nope"]))

    assert "error" in payload
