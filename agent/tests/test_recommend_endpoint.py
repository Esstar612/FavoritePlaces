import pytest
from fastapi.testclient import TestClient

from outing_agent.api import app as app_module
from outing_agent.api.auth import get_verified_uid
from outing_agent.api.rate_limit import RateLimiter
from outing_agent.graph.builder import build_graph
from outing_agent.places.fixtures import DEMO_UID, FIXTURE_PLACES
from outing_agent.places.store import FixturePlacesStore
from tests.fakes import ALL_RECOMMENDED, COUNTS_AS_GROUNDED, scripted_model


@pytest.fixture
def client():
    app = app_module.app
    app.dependency_overrides[app_module.get_places_store] = lambda: FixturePlacesStore()
    app.dependency_overrides[app_module.get_agent] = lambda: app_module.Agent(
        graph=build_graph(scripted_model(ALL_RECOMMENDED)), provider="fake", model="scripted"
    )
    app.dependency_overrides[app_module.get_rate_limiters] = lambda: (
        RateLimiter(100, 3600),
        RateLimiter(100, 3600),
    )
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_recommend_without_token_is_401(client):
    response = client.post("/recommend", json={"message": "coffee"})

    assert response.status_code == 401


def test_recommend_returns_only_the_users_grounded_places(client):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID

    response = client.post("/recommend", json={"message": "a slow coffee morning"})

    assert response.status_code == 200
    body = response.json()
    owned_ids = {place.id for place in FIXTURE_PLACES[DEMO_UID]}
    returned_ids = [rec["place_id"] for rec in body["recommendations"]]
    assert returned_ids == COUNTS_AS_GROUNDED
    assert set(returned_ids) <= owned_ids
    assert any(call["name"] == "search_places" for call in body["tool_calls"])
    assert body["overview"]
    assert "ungrounded_place_ids" not in body
    assert "rejected_place_ids" not in body
    assert body["confidence"] == 0.9
    assert body["clarifying_question"] is None


def test_recommend_rejects_a_uid_in_the_body(client):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID

    response = client.post("/recommend", json={"message": "coffee", "uid": "someone-else"})

    assert response.status_code == 422


@pytest.mark.parametrize("message", ["", "x" * 501])
def test_recommend_rejects_empty_or_long_messages(client, message):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID

    response = client.post("/recommend", json={"message": message})

    assert response.status_code == 422


def test_recommend_over_the_limit_is_429_with_retry_after(client):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID
    limiters = (RateLimiter(1, 3600), RateLimiter(100, 3600))
    client.app.dependency_overrides[app_module.get_rate_limiters] = lambda: limiters

    first = client.post("/recommend", json={"message": "coffee"})
    second = client.post("/recommend", json={"message": "coffee"})

    assert first.status_code == 200
    assert second.status_code == 429
    assert second.headers["Retry-After"] == "3600"


def test_unauthenticated_request_is_401_even_when_limits_are_used_up(client):
    exhausted = RateLimiter(1, 3600)
    exhausted.allow(app_module.GLOBAL_KEY)
    client.app.dependency_overrides[app_module.get_rate_limiters] = lambda: (
        RateLimiter(1, 3600),
        exhausted,
    )

    response = client.post("/recommend", json={"message": "coffee"})

    assert response.status_code == 401


CLARIFICATION = {
    "original_message": "Plan my Saturday",
    "question": "Morning or evening?",
    "answer": "Morning, coffee first.",
}


def test_recommend_accepts_a_clarification(client):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID

    response = client.post("/recommend", json={"clarification": CLARIFICATION})

    assert response.status_code == 200
    assert response.json()["recommendations"]


@pytest.mark.parametrize(
    "body",
    [
        {},
        {"message": "coffee", "clarification": CLARIFICATION},
        {"clarification": {**CLARIFICATION, "answer": ""}},
        {"clarification": {**CLARIFICATION, "question": "x" * 501}},
        {"clarification": {**CLARIFICATION, "uid": "someone-else"}},
        {"clarification": {"original_message": "Plan my Saturday", "answer": "Morning"}},
    ],
    ids=["neither", "both", "empty-answer", "long-question", "extra-field", "missing-question"],
)
def test_recommend_rejects_bad_clarification_requests(client, body):
    client.app.dependency_overrides[get_verified_uid] = lambda: DEMO_UID

    response = client.post("/recommend", json=body)

    assert response.status_code == 422
