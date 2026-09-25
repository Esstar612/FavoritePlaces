"""Saved place records, mirroring the Firestore documents the app writes."""

from datetime import datetime
from typing import Literal, get_args

from pydantic import BaseModel, Field

Category = Literal[
    "restaurant", "cafe", "park", "museum", "shopping",
    "entertainment", "hotel", "bar", "gym", "other",
]
CATEGORIES: tuple[str, ...] = get_args(Category)


class PlaceSummary(BaseModel):
    """The cached AI summary stored on a place."""

    why_i_liked_it: str = ""
    tips: str = ""
    best_time_to_go: str = ""


class Place(BaseModel):
    """One saved place. No userId: the store query enforces ownership."""

    id: str
    title: str
    category: Category = "other"
    tags: list[str] = Field(default_factory=list)
    notes: str = ""
    rating: int = 0
    is_favorite: bool = False
    lat: float
    lng: float
    address: str
    visit_date: datetime | None = None
    created_at: datetime | None = None
    summary: PlaceSummary | None = None
