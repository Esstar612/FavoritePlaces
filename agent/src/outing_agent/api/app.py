import logging
import sys
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, model_validator

from outing_agent import config
from outing_agent.api.auth import get_verified_uid
from outing_agent.api.rate_limit import RateLimiter
from outing_agent.graph.builder import build_graph
from outing_agent.places.store import PlacesStore, build_places_store
from outing_agent.providers.factory import get_chat_model
from outing_agent.run import Leg, RecommendedPlace, ToolCall, run_recommendation

GLOBAL_KEY = "*"
RATE_WINDOW_S = 3600


def _configure_logging() -> None:
    logger = logging.getLogger("outing_agent")
    if logger.handlers:
        return
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


_configure_logging()
app = FastAPI(title="Favorite Places Outing Agent")
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_origin_regex=config.CORS_ORIGIN_REGEX,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)


@dataclass(frozen=True)
class Agent:
    graph: Any
    provider: str
    model: str


class Clarification(BaseModel):
    model_config = ConfigDict(extra="forbid")

    original_message: str = Field(min_length=1, max_length=500)
    question: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=500)


class RecommendRequest(BaseModel):
    # A uid in the body is rejected outright; it only ever comes from the verified token.
    model_config = ConfigDict(extra="forbid")

    message: str | None = Field(default=None, min_length=1, max_length=500)
    clarification: Clarification | None = None

    @model_validator(mode="after")
    def _one_of(self):
        if (self.message is None) == (self.clarification is None):
            raise ValueError("send either message or clarification")
        return self


class RecommendResponse(BaseModel):
    run_id: str
    provider: str
    model: str
    overview: str
    recommendations: list[RecommendedPlace]
    legs: list[Leg]
    tool_calls: list[ToolCall]
    confidence: float | None
    clarifying_question: str | None


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


@lru_cache(maxsize=1)
def get_rate_limiters() -> tuple[RateLimiter, RateLimiter]:
    # In memory is enough because Cloud Run runs at most one instance.
    return (
        RateLimiter(config.RECOMMEND_LIMIT_PER_USER_PER_HOUR, RATE_WINDOW_S),
        RateLimiter(config.RECOMMEND_LIMIT_GLOBAL_PER_HOUR, RATE_WINDOW_S),
    )


def rate_limited_uid(
    uid: str = Depends(get_verified_uid),
    limiters: tuple[RateLimiter, RateLimiter] = Depends(get_rate_limiters),
) -> str:
    per_user, overall = limiters
    # Per user first, so a user already over their own limit can't use up the global cap.
    if not per_user.allow(uid) or not overall.allow(GLOBAL_KEY):
        raise HTTPException(
            429, "Too many requests. Try again later.", headers={"Retry-After": str(RATE_WINDOW_S)}
        )
    return uid


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/recommend", response_model=RecommendResponse)
def recommend(
    body: RecommendRequest,
    uid: str = Depends(rate_limited_uid),
    store: PlacesStore = Depends(get_places_store),
    agent: Agent = Depends(get_agent),
) -> RecommendResponse:
    result = run_recommendation(
        agent.graph,
        body.message,
        clarification=body.clarification.model_dump() if body.clarification else None,
        uid=uid,
        store=store,
        store_kind=config.PLACES_STORE,
        provider=agent.provider,
        model=agent.model,
    )
    return RecommendResponse.model_validate(result.model_dump())
