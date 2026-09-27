import logging
from unittest.mock import MagicMock

import pytest
from google.cloud.firestore import FieldFilter

from outing_agent.places.fixtures import DEMO_UID, OTHER_UID
from outing_agent.places.store import (
    MAX_PLACES,
    FirestorePlacesStore,
    FixturePlacesStore,
    RequestScopedPlacesStore,
)

DEMO_IDS = {
    "demo-blue-bottle",
    "demo-golden-gate-park",
    "demo-tartine",
    "demo-sfmoma",
    "demo-alcatraz",
}


def _record(uid, title="Cafe", **overrides):
    data = {
        "userId": uid,
        "title": title,
        "category": "cafe",
        "tags": ["Quiet"],
        "notes": "some notes",
        "rating": 4,
        "isFavorite": False,
        "lat": 37.7,
        "lng": -122.4,
        "address": "1 Main St, San Francisco, CA",
        "photoUrls": [],
        "visitDate": "2026-08-01T10:00:00.000",
        "createdAt": "2026-08-01T10:00:00.000",
    }
    data.update(overrides)
    return data


def _doc(doc_id, data):
    doc = MagicMock()
    doc.id = doc_id
    doc.to_dict.return_value = data
    return doc


def _client(docs):
    client = MagicMock()
    query = (
        client.collection.return_value.where.return_value.order_by.return_value.limit.return_value
    )
    query.stream.return_value = iter(docs)
    return client


def _store(client):
    return FirestorePlacesStore(client_factory=lambda: client)


@pytest.mark.parametrize("uid", [DEMO_UID, "abc123"])
def test_firestore_store_filters_by_the_given_uid(uid):
    client = _client([_doc("p1", _record(uid))])

    places = _store(client).list_places(uid)

    client.collection.assert_called_once_with("places")
    where = client.collection.return_value.where
    where.assert_called_once()
    assert where.call_args.args == ()
    field_filter = where.call_args.kwargs["filter"]
    expected = FieldFilter("userId", "==", uid)
    assert field_filter.field_path == "userId"
    assert field_filter.op_string == expected.op_string
    assert field_filter.value == uid
    limit = client.collection.return_value.where.return_value.order_by.return_value.limit
    limit.assert_called_once_with(MAX_PLACES)
    assert [p.id for p in places] == ["p1"]


def test_firestore_store_drops_docs_owned_by_someone_else():
    client = _client([_doc("mine", _record("u1")), _doc("theirs", _record("u2"))])

    places = _store(client).list_places("u1")

    assert [p.id for p in places] == ["mine"]


def test_firestore_store_rejects_empty_uid():
    client = _client([])
    with pytest.raises(ValueError):
        _store(client).list_places("")
    client.collection.assert_not_called()


def test_firestore_store_parses_like_the_app():
    data = _record(
        "u1",
        category="not-a-category",
        visitDate="not a date",
        lat=37,
        summary={"whyILikedIt": "views", "tips": "go early", "bestTimeToGo": "8am"},
    )
    client = _client([_doc("p1", data)])

    (place,) = _store(client).list_places("u1")

    assert place.category == "other"
    assert place.visit_date is None
    assert place.lat == 37.0
    assert place.summary is not None
    assert place.summary.best_time_to_go == "8am"


def test_firestore_store_skips_malformed_docs():
    client = _client([_doc("ok", _record("u1")), _doc("bad", {"userId": "u1"})])

    places = _store(client).list_places("u1")

    assert [p.id for p in places] == ["ok"]


def test_firestore_store_warns_when_the_limit_is_hit(caplog):
    docs = [_doc(f"p{i}", _record("u1")) for i in range(MAX_PLACES)]
    client = _client(docs)

    with caplog.at_level(logging.WARNING, logger="outing_agent.places.store"):
        places = _store(client).list_places("u1")

    assert len(places) == MAX_PLACES
    assert any(str(MAX_PLACES) in r.getMessage() for r in caplog.records)


def test_firestore_store_does_not_warn_below_the_limit(caplog):
    client = _client([_doc("p1", _record("u1"))])

    with caplog.at_level(logging.WARNING, logger="outing_agent.places.store"):
        _store(client).list_places("u1")

    assert caplog.records == []


def test_fixture_store_returns_only_that_users_places():
    store = FixturePlacesStore()

    demo = {p.id for p in store.list_places(DEMO_UID)}
    other = {p.id for p in store.list_places(OTHER_UID)}

    assert demo == DEMO_IDS
    assert other
    assert demo.isdisjoint(other)


def test_fixture_store_unknown_user_has_no_places():
    assert FixturePlacesStore().list_places("nobody") == []


def test_fixture_store_returns_copies():
    store = FixturePlacesStore()
    first = store.list_places(DEMO_UID)
    first[0].notes = "changed"
    first.clear()

    again = store.list_places(DEMO_UID)

    assert len(again) == len(DEMO_IDS)
    assert all(p.notes != "changed" for p in again)


class _CountingStore:
    def __init__(self):
        self.calls = 0
        self._inner = FixturePlacesStore()

    def list_places(self, uid):
        self.calls += 1
        return self._inner.list_places(uid)


def test_request_scoped_store_hits_the_backing_store_once():
    inner = _CountingStore()
    store = RequestScopedPlacesStore(inner, DEMO_UID)

    for _ in range(3):
        assert {p.id for p in store.list_places(DEMO_UID)} == DEMO_IDS

    assert inner.calls == 1


def test_request_scoped_store_refuses_a_different_uid():
    inner = _CountingStore()
    store = RequestScopedPlacesStore(inner, DEMO_UID)

    with pytest.raises(ValueError):
        store.list_places(OTHER_UID)
    assert inner.calls == 0


def test_request_scoped_store_returns_copies():
    store = RequestScopedPlacesStore(_CountingStore(), DEMO_UID)
    store.list_places(DEMO_UID)[0].notes = "changed"

    assert all(p.notes != "changed" for p in store.list_places(DEMO_UID))
