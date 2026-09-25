from dataclasses import dataclass
from typing import Annotated, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages
from pydantic import BaseModel, Field

from outing_agent.places.store import PlacesStore


@dataclass(frozen=True)
class AgentContext:
    uid: str
    store: PlacesStore


class Recommendation(BaseModel):
    place_id: str = Field(description="ID of a saved place returned by one of the tools")
    order: int = Field(description="Visiting order, starting at 1")
    reason: str = Field(description="Why this place fits the request, based on its details")
    suggested_time: str | None = Field(
        default=None, description="When to go, if the place's details say"
    )


class RecommendationSet(BaseModel):
    overview: str = Field(description="One or two sentences describing the outing")
    recommendations: list[Recommendation]


class AgentState(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    recommendation_set: RecommendationSet | None
