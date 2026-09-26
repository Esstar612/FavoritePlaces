import json
import math
from typing import Any

from langchain_core.tools import tool
from langgraph.prebuilt import ToolRuntime

from outing_agent.places.models import Category, Place

MAX_SEARCH_LIMIT = 20
MAX_DETAIL_IDS = 5
MAX_ROUTE_IDS = 5
MIN_QUERY_WORD = 3
EARTH_RADIUS_KM = 6371.0


def _places(runtime: ToolRuntime[Any]) -> list[Place]:
    context = runtime.context
    return context.store.list_places(context.uid)


def _row(place: Place) -> dict:
    return {
        "id": place.id,
        "title": place.title,
        "category": place.category,
        "tags": place.tags,
        "rating": place.rating,
        "is_favorite": place.is_favorite,
        "address": place.address,
    }


@tool
def search_places(
    runtime: ToolRuntime[Any],
    query: str | None = None,
    category: Category | None = None,
    tags: list[str] | None = None,
    favorites_only: bool = False,
    min_rating: int | None = None,
    limit: int = 8,
) -> str:
    """Search the user's saved places.

    Returns short rows (id, title, category, tags, rating, is_favorite,
    address) without notes. Call get_place_details for notes, tips, and the
    best time to go. query matches words in titles, tags, categories,
    addresses, and notes. tags keeps places with at least one of the given
    tags. min_rating is 1 to 5. limit is 1 to 20.
    """
    places = _places(runtime)
    words = [w for w in (query or "").lower().split() if len(w) >= MIN_QUERY_WORD]
    wanted_tags = {t.lower() for t in tags or []}
    scored = []
    for place in places:
        if category and place.category != category:
            continue
        if favorites_only and not place.is_favorite:
            continue
        if min_rating is not None and place.rating < min_rating:
            continue
        if wanted_tags and not wanted_tags & {t.lower() for t in place.tags}:
            continue
        score = 0
        if words:
            haystack = " ".join(
                [place.title, place.category, place.address, place.notes, *place.tags]
            ).lower()
            score = sum(1 for w in words if w in haystack)
            if score == 0:
                continue
        scored.append((score, place.rating, place))
    scored.sort(key=lambda item: (item[0], item[1]), reverse=True)
    limit = max(1, min(limit, MAX_SEARCH_LIMIT))
    return json.dumps(
        {
            "places": [_row(p) for _, _, p in scored[:limit]],
            "matched": len(scored),
            "total_saved": len(places),
        }
    )


@tool
def get_place_details(runtime: ToolRuntime[Any], place_ids: list[str]) -> str:
    """Get full details for up to 5 of the user's saved places by ID.

    Returns notes, the cached summary (why they liked it, tips, best time to
    go), visit date, and coordinates. IDs that are not the user's saved places
    come back in not_found. Only the first 5 IDs are used; any beyond that
    come back in truncated.
    """
    by_id = {p.id: p for p in _places(runtime)}
    unique_ids = list(dict.fromkeys(place_ids))
    requested, truncated = unique_ids[:MAX_DETAIL_IDS], unique_ids[MAX_DETAIL_IDS:]
    found, not_found = [], []
    for place_id in requested:
        place = by_id.get(place_id)
        if place is None:
            not_found.append(place_id)
            continue
        found.append(
            {
                **_row(place),
                "notes": place.notes,
                "summary": place.summary.model_dump() if place.summary else None,
                "visit_date": place.visit_date.date().isoformat() if place.visit_date else None,
                "lat": place.lat,
                "lng": place.lng,
            }
        )
    return json.dumps({"places": found, "not_found": not_found, "truncated": truncated})


@tool
def plan_route(runtime: ToolRuntime[Any], place_ids: list[str], optimize: bool = False) -> str:
    """Plan a route through 2 to 5 of the user's saved places.

    Stops are visited in the order given, so pass them in the order the user
    asked for. Set optimize to true only when the user leaves the order open:
    the route then starts at the first ID and always goes to the nearest place
    not yet visited. One call returns every leg with its straight-line distance
    in km, plus the total, so there is no need to call it per leg. Only the
    first 5 IDs are used; any beyond that come back in truncated. IDs that are
    not the user's saved places come back in not_found.
    """
    by_id = {p.id: p for p in _places(runtime)}
    unique_ids = list(dict.fromkeys(place_ids))
    requested, truncated = unique_ids[:MAX_ROUTE_IDS], unique_ids[MAX_ROUTE_IDS:]
    stops = [by_id[pid] for pid in requested if pid in by_id]
    not_found = [pid for pid in requested if pid not in by_id]
    if len(stops) < 2:
        return json.dumps(
            {
                "error": "need at least 2 saved place IDs",
                "not_found": not_found,
                "truncated": truncated,
            }
        )
    route = _nearest_neighbor_order(stops) if optimize else stops
    legs = [
        {"from": a.id, "to": b.id, "km": round(_haversine_km(a, b), 2)}
        for a, b in zip(route, route[1:])
    ]
    return json.dumps(
        {
            "order": [p.id for p in route],
            "optimized": optimize,
            "legs": legs,
            "total_km": round(sum(leg["km"] for leg in legs), 2),
            "not_found": not_found,
            "truncated": truncated,
        }
    )


def _nearest_neighbor_order(stops: list[Place]) -> list[Place]:
    route, remaining = [stops[0]], stops[1:]
    while remaining:
        nearest = min(remaining, key=lambda p: _haversine_km(route[-1], p))
        route.append(nearest)
        remaining.remove(nearest)
    return route


def _haversine_km(a: Place, b: Place) -> float:
    lat1, lat2 = math.radians(a.lat), math.radians(b.lat)
    d_lat = lat2 - lat1
    d_lng = math.radians(b.lng - a.lng)
    h = math.sin(d_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(d_lng / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(h))


TOOLS = [search_places, get_place_details, plan_route]
