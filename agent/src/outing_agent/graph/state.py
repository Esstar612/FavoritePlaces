from dataclasses import dataclass
from typing import Annotated, Literal, TypedDict

from langchain_core.messages import AnyMessage
from langgraph.graph.message import add_messages
from langgraph.managed import RemainingSteps
from pydantic import BaseModel, Field

from outing_agent.places.store import PlacesStore


@dataclass(frozen=True)
class AgentContext:
    uid: str
    store: PlacesStore


class Recommendation(BaseModel):
    place_id: str = Field(description="ID of a saved place returned by one of the tools")
    order: int = Field(
        description="Position starting at 1: visiting order for an itinerary, best fit first for options"
    )
    reason: str = Field(description="Why this place fits the request, based on its details")
    suggested_time: str | None = Field(
        default=None, description="When to go, if the place's details say"
    )


class RecommendationSet(BaseModel):
    overview: str = Field(description="One or two sentences describing the outing")
    kind: Literal["itinerary", "options"] = Field(
        description="itinerary: the user asked for a number of stops, a sequence "
        "(first, then, after), or a plan for a day or part of one. options: the user "
        "asked for ideas or to choose between places, or the request matches neither."
    )
    recommendations: list[Recommendation]


class AgentState(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]
    recommendation_set: RecommendationSet | None
    draft_set: RecommendationSet | None
    fallback_calls: list[dict]
    fallback_removed_place_ids: list[str]
    remaining_steps: RemainingSteps
