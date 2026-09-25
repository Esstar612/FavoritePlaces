import logging
import threading
from collections.abc import Callable, Mapping
from datetime import datetime
from typing import Any, Protocol

from firebase_admin import firestore
from google.cloud.firestore import FieldFilter, Query

from outing_agent.firebase_app import get_firebase_app
from outing_agent.places.fixtures import FIXTURE_PLACES
from outing_agent.places.models import CATEGORIES, Place, PlaceSummary

log = logging.getLogger(__name__)

# Matches MAX_SEARCH_PLACES in backend/routes/ai.js.
MAX_PLACES = 200


class PlacesStore(Protocol):
    def list_places(self, uid: str) -> list[Place]: ...


class FirestorePlacesStore:
    def __init__(self, client_factory: Callable[[], Any] | None = None):
        self._client_factory = client_factory or _default_client

    def list_places(self, uid: str) -> list[Place]:
        if not uid:
            raise ValueError("uid is required")
        query = (
            self._client_factory()
            .collection("places")
            .where(filter=FieldFilter("userId", "==", uid))
            .order_by("createdAt", direction=Query.DESCENDING)
            .limit(MAX_PLACES)
        )
        docs = list(query.stream())
        if len(docs) == MAX_PLACES:
            log.warning(
                "places query hit the %d place limit; older places are not visible to the agent",
                MAX_PLACES,
            )
        places = []
        for doc in docs:
            data = doc.to_dict() or {}
            # Defense in depth in case the query ever returns another user's document.
            if data.get("userId") != uid:
                log.warning("dropped place %s: owner does not match the query", doc.id)
                continue
            place = place_from_firestore(doc.id, data)
            if place is not None:
                places.append(place)
        return places


def _default_client():
    return firestore.client(app=get_firebase_app())


class FixturePlacesStore:
    def __init__(self, places_by_uid: Mapping[str, list[Place]] | None = None):
        self._places = FIXTURE_PLACES if places_by_uid is None else places_by_uid

    def list_places(self, uid: str) -> list[Place]:
        return [p.model_copy(deep=True) for p in self._places.get(uid, [])]


class RequestScopedPlacesStore:
    def __init__(self, inner: PlacesStore, uid: str):
        self._inner = inner
        self._uid = uid
        self._places: list[Place] | None = None
        self._lock = threading.Lock()

    def list_places(self, uid: str) -> list[Place]:
        if uid != self._uid:
            raise ValueError("this store is bound to a different user")
        with self._lock:
            if self._places is None:
                self._places = self._inner.list_places(uid)
        return [p.model_copy(deep=True) for p in self._places]


def build_places_store(kind: str) -> PlacesStore:
    if kind == "fixture":
        return FixturePlacesStore()
    if kind == "firestore":
        return FirestorePlacesStore()
    raise ValueError(f"unknown places store {kind!r}")


def place_from_firestore(doc_id: str, data: Mapping[str, Any]) -> Place | None:
    # Mirrors Place.fromFirestore in mobile/lib/models/place.dart.
    category = data.get("category")
    try:
        return Place(
            id=doc_id,
            title=data["title"],
            category=category if category in CATEGORIES else "other",
            tags=[str(t) for t in data.get("tags") or []],
            notes=data.get("notes") or "",
            rating=int(data.get("rating") or 0),
            is_favorite=bool(data.get("isFavorite", False)),
            lat=float(data["lat"]),
            lng=float(data["lng"]),
            address=data["address"],
            visit_date=_parse_date(data.get("visitDate")),
            created_at=_parse_date(data.get("createdAt")),
            summary=_parse_summary(data.get("summary")),
        )
    except (KeyError, TypeError, ValueError) as error:
        # Error type only: field values could include a user's notes.
        log.warning("skipped malformed place %s: %s", doc_id, type(error).__name__)
        return None


def _parse_date(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return None
    return None


def _parse_summary(value: Any) -> PlaceSummary | None:
    if not isinstance(value, Mapping):
        return None
    return PlaceSummary(
        why_i_liked_it=str(value.get("whyILikedIt") or ""),
        tips=str(value.get("tips") or ""),
        best_time_to_go=str(value.get("bestTimeToGo") or ""),
    )
