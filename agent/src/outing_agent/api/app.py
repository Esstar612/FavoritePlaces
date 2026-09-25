from dataclasses import dataclass
from functools import lru_cache
from typing import Any

from fastapi import Depends, FastAPI
from pydantic import BaseModel, ConfigDict, Field

from outing_agent import config
from outing_agent.api.auth import get_verified_uid
from outing_agent.graph.builder import build_graph
from outing_agent.places.store import PlacesStore, build_places_store
from outing_agent.providers.factory import get_chat_model
from outing_agent.run import RecommendedPlace, ToolCall, run_recommendation

app = FastAPI(title="Favorite Places Outing Agent")


@dataclass(frozen=True)
class Agent:
    graph: Any
    provider: str
    model: str


class RecommendRequest(BaseModel):
    # A uid in the body is rejected outright; it only ever comes from the verified token.
    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=500)


class RecommendResponse(BaseModel):
    run_id: str
    provider: str
    model: str
    overview: str
    recommendations: list[RecommendedPlace]
    tool_calls: list[ToolCall]


@lru_cache(maxsize=1)
def get_places_store() -> PlacesStore:
    return build_places_store(config.PLACES_STORE)


@lru_cache(maxsize=1)
def get_agent() -> Agent:
    provider = config.LLM_PROVIDER
    return Agent(
        graph=build_graph(get_chat_model(provider)),
        provider=provider,
        model=config.MODELS[provider],
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/recommend", response_model=RecommendResponse)
def recommend(
    body: RecommendRequest,
    uid: str = Depends(get_verified_uid),
    store: PlacesStore = Depends(get_places_store),
    agent: Agent = Depends(get_agent),
) -> RecommendResponse:
    result = run_recommendation(
        agent.graph,
        body.message,
        uid=uid,
        store=store,
        store_kind=config.PLACES_STORE,
        provider=agent.provider,
        model=agent.model,
    )
    return RecommendResponse.model_validate(result.model_dump())
