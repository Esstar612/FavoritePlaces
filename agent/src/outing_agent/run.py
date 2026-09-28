import json
import logging
import uuid
from contextlib import nullcontext
from itertools import pairwise
from typing import Literal

from langchain_core.messages import AIMessage, AnyMessage, HumanMessage, ToolMessage
from langsmith import tracing_context
from pydantic import BaseModel

from outing_agent.config import confidence_threshold
from outing_agent.graph.state import AgentContext, RecommendationSet
from outing_agent.places.geo import haversine_km
from outing_agent.places.models import Place
from outing_agent.places.store import PlacesStore, RequestScopedPlacesStore

log = logging.getLogger(__name__)

RECURSION_LIMIT = 21

# Product choices, not measurements: straight-line distance stretched for streets, at an easy pace.
WALK_KMH = 4.8
DETOUR_FACTOR = 1.3
MAX_WALK_MIN = 30


class RecommendedPlace(BaseModel):
    place_id: str
    title: str
    category: str
    order: int
    reason: str
    suggested_time: str | None = None


class ToolCall(BaseModel):
    name: str
    args: dict
    source: Literal["model", "graph"] = "model"
    result_place_ids: list[str] = []
    matched: int | None = None


class Leg(BaseModel):
    from_place_id: str
    to_place_id: str
    walk_minutes: int | None


class RecommendationResult(BaseModel):
    run_id: str
    provider: str
    model: str
    overview: str
    kind: str | None
    recommendations: list[RecommendedPlace]
    legs: list[Leg]
    tool_calls: list[ToolCall]
    ungrounded_place_ids: list[str]
    rejected_place_ids: list[str]
    draft_place_ids: list[str]
    draft_grounded_place_ids: list[str]
    fallback_removed_place_ids: list[str]
    confidence: float | None
    escalated: bool
    clarifying_question: str | None
    clarification_round: bool
    start_place_id: str | None = None


START_REST = "whatever fits best after it."


class UnknownStartPlace(ValueError):
    pass


def request_text(
    message: str | None, clarification: dict | None, start: Place | None = None
) -> str:
    if clarification is None:
        text = message
    else:
        text = (
            f"{clarification['original_message']}\n\n"
            f"You asked: {clarification['question']}\n"
            f"My answer: {clarification['answer']}"
        )
    if start is None:
        return text
    return f"Plan an outing that starts at {start.title} ({start.id}), then {text or START_REST}"


def anchor_start(
    stops: list[RecommendedPlace], start: Place, kind: str | None
) -> tuple[list[RecommendedPlace], str | None]:
    others = [stop for stop in stops if stop.place_id != start.id]
    if not others:
        return stops, kind
    if kind != "itinerary":
        others = others[:1]
    first = next((stop for stop in stops if stop.place_id == start.id), None) or RecommendedPlace(
        place_id=start.id, title=start.title, category=start.category, order=1, reason=""
    )
    ordered = [first, *others]
    return [stop.model_copy(update={"order": i}) for i, stop in enumerate(ordered, 1)], "itinerary"


def run_recommendation(
    graph,
    message: str | None,
    *,
    clarification: dict | None = None,
    start_place_id: str | None = None,
    uid: str,
    store: PlacesStore,
    store_kind: str,
    provider: str,
    model: str,
) -> RecommendationResult:
    scoped_store = RequestScopedPlacesStore(store, uid)
    start = None
    if start_place_id is not None:
        start = next((p for p in scoped_store.list_places(uid) if p.id == start_place_id), None)
        if start is None:
            raise UnknownStartPlace(start_place_id)
    start_only = start is not None and message is None and clarification is None
    run_id = str(uuid.uuid4())
    config = {
        "run_id": run_id,
        "recursion_limit": RECURSION_LIMIT,
        "metadata": {"provider": provider, "model": model, "places_store": store_kind},
    }
    # Firestore mode holds real users' notes, so those runs stay out of LangSmith.
    tracing = tracing_context(enabled=False) if store_kind == "firestore" else nullcontext()
    with tracing:
        state = graph.invoke(
            {
                "messages": [HumanMessage(request_text(message, clarification, start))],
                "recommendation_set": None,
                "draft_set": None,
                "fallback_calls": [],
                "fallback_removed_place_ids": [],
                "clarification_allowed": clarification is None and not start_only,
                "start_only": start_only,
                "confidence_threshold": confidence_threshold(provider),
                "escalated": False,
            },
            config=config,
            context=AgentContext(uid=uid, store=scoped_store),
        )

    messages = state["messages"]
    owned = {place.id: place for place in scoped_store.list_places(uid)}
    retrieved = retrieved_place_ids(messages)
    if start is not None:
        retrieved.add(start.id)
    final_set = state.get("recommendation_set")
    draft_set = state.get("draft_set") or final_set
    escalated = state.get("escalated", False)
    kept, ungrounded, rejected = ground_recommendations(final_set, owned, retrieved)
    kind = final_set.kind if final_set else None
    if escalated:
        kept = []
    elif start is not None:
        kept, kind = anchor_start(kept, start, kind)
    draft_kept, _, _ = ground_recommendations(draft_set, owned, retrieved)
    draft_recs = sorted(draft_set.recommendations, key=lambda r: r.order) if draft_set else []
    result = RecommendationResult(
        run_id=run_id,
        provider=provider,
        model=model,
        overview=final_set.overview if final_set and not escalated else "",
        kind=kind,
        recommendations=kept,
        legs=walking_legs(kept, owned, kind),
        tool_calls=collect_tool_calls(messages, state.get("fallback_calls", [])),
        ungrounded_place_ids=ungrounded,
        rejected_place_ids=rejected,
        draft_place_ids=[rec.place_id for rec in draft_recs],
        draft_grounded_place_ids=[rec.place_id for rec in draft_kept],
        fallback_removed_place_ids=state.get("fallback_removed_place_ids", []),
        confidence=draft_set.confidence if draft_set else None,
        escalated=escalated,
        clarifying_question=draft_set.clarifying_question if escalated and draft_set else None,
        clarification_round=clarification is not None,
        start_place_id=start_place_id,
    )
    _log_run(result, store_kind)
    return result


def _payload(content) -> dict:
    try:
        payload = json.loads(content)
    except (TypeError, ValueError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _payload_place_ids(payload: dict) -> list[str]:
    return [
        *[
            row["id"]
            for row in payload.get("places", [])
            if isinstance(row, dict) and isinstance(row.get("id"), str)
        ],
        *[place_id for place_id in payload.get("order", []) if isinstance(place_id, str)],
    ]


def retrieved_place_ids(messages: list[AnyMessage]) -> set[str]:
    ids: set[str] = set()
    for message in messages:
        if isinstance(message, ToolMessage):
            ids.update(_payload_place_ids(_payload(message.content)))
    return ids


def ground_recommendations(
    recommendation_set: RecommendationSet | None,
    owned: dict[str, Place],
    retrieved: set[str],
) -> tuple[list[RecommendedPlace], list[str], list[str]]:
    kept: list[RecommendedPlace] = []
    ungrounded: list[str] = []
    rejected: list[str] = []
    seen: set[str] = set()
    recommendations = recommendation_set.recommendations if recommendation_set else []
    for rec in sorted(recommendations, key=lambda r: r.order):
        if rec.place_id in seen:
            continue
        seen.add(rec.place_id)
        if rec.place_id not in owned:
            rejected.append(rec.place_id)
        elif rec.place_id not in retrieved:
            ungrounded.append(rec.place_id)
        else:
            kept.append(
                RecommendedPlace(
                    place_id=rec.place_id,
                    title=owned[rec.place_id].title,
                    category=owned[rec.place_id].category,
                    order=len(kept) + 1,
                    reason=rec.reason,
                    suggested_time=rec.suggested_time,
                )
            )
    return kept, ungrounded, rejected


def walking_legs(
    recommendations: list[RecommendedPlace], owned: dict[str, Place], kind: str | None
) -> list[Leg]:
    if kind != "itinerary":
        return []
    legs = []
    for a, b in pairwise(recommendations):
        km = haversine_km(owned[a.place_id], owned[b.place_id]) * DETOUR_FACTOR
        minutes = max(1, round(km / WALK_KMH * 60))
        legs.append(
            Leg(
                from_place_id=a.place_id,
                to_place_id=b.place_id,
                walk_minutes=minutes if minutes <= MAX_WALK_MIN else None,
            )
        )
    return legs


def _tool_call(name: str, args: dict, content, source: str = "model") -> ToolCall:
    payload = _payload(content)
    matched = payload.get("matched")
    return ToolCall(
        name=name,
        args=args,
        source=source,
        result_place_ids=_payload_place_ids(payload),
        matched=matched if isinstance(matched, int) else None,
    )


def collect_tool_calls(messages: list[AnyMessage], fallback_calls: list[dict]) -> list[ToolCall]:
    results = {m.tool_call_id: m.content for m in messages if isinstance(m, ToolMessage)}
    return [
        *[
            _tool_call(call["name"], call["args"], results[call["id"]])
            for message in messages
            if isinstance(message, AIMessage)
            for call in message.tool_calls
            if call["id"] in results
        ],
        *[
            _tool_call(call["name"], call["args"], call.get("result"), source="graph")
            for call in fallback_calls
        ],
    ]


def _log_run(result: RecommendationResult, store_kind: str) -> None:
    log.info(
        json.dumps(
            {
                "event": "recommendation_run",
                "run_id": result.run_id,
                "provider": result.provider,
                "model": result.model,
                "places_store": store_kind,
                "tool_calls": [call.model_dump() for call in result.tool_calls],
                "kind": result.kind,
                "recommended_place_ids": [rec.place_id for rec in result.recommendations],
                "ungrounded_place_ids": result.ungrounded_place_ids,
                "rejected_place_ids": result.rejected_place_ids,
                "draft_place_ids": result.draft_place_ids,
                "draft_grounded_place_ids": result.draft_grounded_place_ids,
                "fallback_removed_place_ids": result.fallback_removed_place_ids,
                "confidence": result.confidence,
                "escalated": result.escalated,
                "clarification_round": result.clarification_round,
                "start_place_id": result.start_place_id,
            }
        )
    )
