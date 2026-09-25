import json
import logging
import uuid
from contextlib import nullcontext

from langchain_core.messages import AIMessage, AnyMessage, HumanMessage, ToolMessage
from langsmith import tracing_context
from pydantic import BaseModel

from outing_agent.graph.state import AgentContext, RecommendationSet
from outing_agent.places.models import Place
from outing_agent.places.store import PlacesStore, RequestScopedPlacesStore

log = logging.getLogger(__name__)

RECURSION_LIMIT = 12


class RecommendedPlace(BaseModel):
    place_id: str
    title: str
    order: int
    reason: str
    suggested_time: str | None = None


class ToolCall(BaseModel):
    name: str
    args: dict


class RecommendationResult(BaseModel):
    run_id: str
    provider: str
    model: str
    overview: str
    recommendations: list[RecommendedPlace]
    tool_calls: list[ToolCall]
    ungrounded_place_ids: list[str]
    rejected_place_ids: list[str]


def run_recommendation(
    graph,
    message: str,
    *,
    uid: str,
    store: PlacesStore,
    store_kind: str,
    provider: str,
    model: str,
) -> RecommendationResult:
    scoped_store = RequestScopedPlacesStore(store, uid)
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
            {"messages": [HumanMessage(message)], "recommendation_set": None},
            config=config,
            context=AgentContext(uid=uid, store=scoped_store),
        )

    messages = state["messages"]
    owned = {place.id: place for place in scoped_store.list_places(uid)}
    kept, ungrounded, rejected = ground_recommendations(
        state.get("recommendation_set"), owned, retrieved_place_ids(messages)
    )
    result = RecommendationResult(
        run_id=run_id,
        provider=provider,
        model=model,
        overview=state["recommendation_set"].overview if state.get("recommendation_set") else "",
        recommendations=kept,
        tool_calls=collect_tool_calls(messages),
        ungrounded_place_ids=ungrounded,
        rejected_place_ids=rejected,
    )
    _log_run(result, store_kind)
    return result


def retrieved_place_ids(messages: list[AnyMessage]) -> set[str]:
    ids: set[str] = set()
    for message in messages:
        if not isinstance(message, ToolMessage):
            continue
        try:
            payload = json.loads(message.content)
        except (TypeError, ValueError):
            continue
        if not isinstance(payload, dict):
            continue
        ids.update(
            row["id"]
            for row in payload.get("places", [])
            if isinstance(row, dict) and isinstance(row.get("id"), str)
        )
        ids.update(place_id for place_id in payload.get("order", []) if isinstance(place_id, str))
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
                    order=len(kept) + 1,
                    reason=rec.reason,
                    suggested_time=rec.suggested_time,
                )
            )
    return kept, ungrounded, rejected


def collect_tool_calls(messages: list[AnyMessage]) -> list[ToolCall]:
    return [
        ToolCall(name=call["name"], args=call["args"])
        for message in messages
        if isinstance(message, AIMessage)
        for call in message.tool_calls
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
                "recommended_place_ids": [rec.place_id for rec in result.recommendations],
                "ungrounded_place_ids": result.ungrounded_place_ids,
                "rejected_place_ids": result.rejected_place_ids,
            }
        )
    )
