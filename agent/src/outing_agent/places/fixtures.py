from datetime import datetime, timezone

from outing_agent.places.models import Place

DEMO_UID = "demo-user"
OTHER_UID = "other-user"
PLANNER_UID = "planner-user"
SPARSE_UID = "sparse-user"


def _date(day: int) -> datetime:
    return datetime(2026, 8, day, 12, 0, tzinfo=timezone.utc)


_DEMO_PLACES = [
    Place(
        id="demo-blue-bottle",
        title="Blue Bottle Coffee",
        category="cafe",
        rating=5,
        is_favorite=True,
        lat=37.7955,
        lng=-122.3937,
        address="1 Ferry Building, San Francisco, CA",
        tags=["Hidden Gem", "Great Views"],
        notes=(
            "Amazing pour over, got there at 8am and it was quiet. Pricey but "
            "worth it. The window seats look out over the bay. Gets packed by 10."
        ),
        visit_date=_date(22),
        created_at=_date(23),
    ),
    Place(
        id="demo-golden-gate-park",
        title="Golden Gate Park",
        category="park",
        rating=4,
        is_favorite=False,
        lat=37.7694,
        lng=-122.4862,
        address="501 Stanyan St, San Francisco, CA",
        tags=["Family Friendly", "Quiet"],
        notes=(
            "Huge. Rent a bike near the entrance, walking the whole thing takes "
            "hours. The Japanese Tea Garden is worth the entry fee. Go on a "
            "weekday, weekends are packed."
        ),
        visit_date=_date(21),
        created_at=_date(22),
    ),
    Place(
        id="demo-tartine",
        title="Tartine Bakery",
        category="restaurant",
        rating=5,
        is_favorite=True,
        lat=37.7614,
        lng=-122.4241,
        address="600 Guerrero St, San Francisco, CA",
        tags=["Must Visit", "Good Food"],
        notes=(
            "The morning bun is the thing to get. Line is long but moves fast. "
            "Cash only used to be true, not anymore. Get there before 9 or after 2."
        ),
        visit_date=_date(20),
        created_at=_date(21),
    ),
    Place(
        id="demo-sfmoma",
        title="SFMOMA",
        category="museum",
        rating=4,
        is_favorite=False,
        lat=37.7857,
        lng=-122.4011,
        address="151 3rd St, San Francisco, CA",
        tags=["Instagrammable"],
        notes=(
            "Seven floors, do not try to do it all in one visit. The living wall "
            "on floor 3 is the best photo spot. Free for under 18."
        ),
        visit_date=_date(19),
        created_at=_date(20),
    ),
    Place(
        id="demo-alcatraz",
        title="Alcatraz Island",
        category="other",
        rating=5,
        is_favorite=False,
        lat=37.8267,
        lng=-122.4230,
        address="Alcatraz Island, San Francisco, CA, USA",
        tags=["Must Visit"],
        notes=(
            "Book the night tour, it sells out weeks ahead. The audio guide is "
            "genuinely good. Bring a jacket, the crossing is cold even in summer."
        ),
        visit_date=_date(18),
        created_at=_date(19),
    ),
]

_OTHER_PLACES = [
    Place(
        id="other-dolores-park",
        title="Mission Dolores Park",
        category="park",
        rating=5,
        is_favorite=True,
        lat=37.7596,
        lng=-122.4269,
        address="Dolores St & 19th St, San Francisco, CA",
        tags=["Sunny", "Picnic"],
        notes="Best on a sunny weekend afternoon. Bring a blanket.",
        visit_date=_date(10),
        created_at=_date(11),
    ),
    Place(
        id="other-city-lights",
        title="City Lights Bookstore",
        category="shopping",
        rating=4,
        is_favorite=False,
        lat=37.7976,
        lng=-122.4065,
        address="261 Columbus Ave, San Francisco, CA",
        tags=["Quiet"],
        notes="Poetry room upstairs. Open late.",
        visit_date=_date(12),
        created_at=_date(13),
    ),
]

def _planner_place(place_id, title, category, rating, is_favorite, lat, lng, address, tags, notes, day):
    return Place(
        id=place_id,
        title=title,
        category=category,
        rating=rating,
        is_favorite=is_favorite,
        lat=lat,
        lng=lng,
        address=address,
        tags=tags,
        notes=notes,
        visit_date=_date(day),
        created_at=_date(day + 1),
    )


# Coordinates are approximate real San Francisco locations.
_PLANNER_PLACES = [
    _planner_place(
        "planner-sightglass", "Sightglass Coffee", "cafe", 5, True, 37.7770, -122.4086,
        "270 7th St, San Francisco, CA", ["Good Coffee"],
        "Opens at 7am. Great espresso, but there is almost no seating, so it is a grab and go stop.", 1,
    ),
    _planner_place(
        "planner-workshop-cafe", "Workshop Cafe", "cafe", 4, False, 37.7895, -122.4011,
        "180 Montgomery St, San Francisco, CA", ["Work Friendly", "Quiet"],
        "Plenty of outlets and big tables, fine to work for hours. Quiet on weekdays, busy on Saturday afternoons.", 2,
    ),
    _planner_place(
        "planner-de-young", "de Young Museum", "museum", 4, False, 37.7715, -122.4687,
        "50 Hagiwara Tea Garden Dr, San Francisco, CA", ["Must Visit"],
        "The tower observation deck is free. Go early, before the tour groups arrive.", 3,
    ),
    _planner_place(
        "planner-zuni", "Zuni Cafe", "restaurant", 5, True, 37.7735, -122.4217,
        "1658 Market St, San Francisco, CA", ["Good Food"],
        "The roast chicken for two takes about an hour. Book ahead. Best as a long, slow lunch.", 4,
    ),
    _planner_place(
        "planner-la-taqueria", "La Taqueria", "restaurant", 4, False, 37.7509, -122.4181,
        "2889 Mission St, San Francisco, CA", ["Good Food", "Quick"],
        "Order it dorado style. Fast once you order, but the line is long around noon.", 5,
    ),
    _planner_place(
        "planner-crissy-field", "Crissy Field", "park", 5, True, 37.8039, -122.4648,
        "1199 E Beach, San Francisco, CA", ["Great Views", "Waterfront"],
        "Flat walk along the bay with views of the Golden Gate Bridge. An easy way to end a day.", 6,
    ),
    _planner_place(
        "planner-lands-end", "Lands End Trail", "park", 4, False, 37.7876, -122.5051,
        "680 Point Lobos Ave, San Francisco, CA", ["Great Views", "Waterfront"],
        "Best at sunset. Very windy, wear layers. Rocky in a few spots.", 7,
    ),
    _planner_place(
        "planner-green-apple", "Green Apple Books", "shopping", 4, False, 37.7830, -122.4645,
        "506 Clement St, San Francisco, CA", ["Quiet"],
        "Two floors of used books. Easy to lose an hour here.", 8,
    ),
    _planner_place(
        "planner-trick-dog", "Trick Dog", "bar", 4, False, 37.7593, -122.4115,
        "3010 20th St, San Francisco, CA", ["Cocktails"],
        "The cocktail menu changes twice a year. Gets loud after 9.", 9,
    ),
    _planner_place(
        "planner-ferry-building", "Ferry Building Marketplace", "shopping", 4, False, 37.7955, -122.3937,
        "1 Ferry Building, San Francisco, CA", ["Market", "Waterfront"],
        "Farmers market on Saturdays until 2pm. Crowded by noon.", 10,
    ),
]

_SPARSE_PLACES = [
    _planner_place(
        "sparse-coit-tower", "Coit Tower", "other", 4, False, 37.8024, -122.4058,
        "1 Telegraph Hill Blvd, San Francisco, CA", ["Great Views"], "", 11,
    ),
    _planner_place(
        "sparse-boba-guys", "Boba Guys", "cafe", 4, False, 37.7614, -122.4214,
        "3491 19th St, San Francisco, CA", ["Drinks"], "", 12,
    ),
    _planner_place(
        "sparse-house-of-prime-rib", "House of Prime Rib", "restaurant", 5, True, 37.7932, -122.4222,
        "1906 Van Ness Ave, San Francisco, CA", ["Good Food"],
        "Order the English cut. Reservations needed on weekends.", 13,
    ),
    _planner_place(
        "sparse-palace-of-fine-arts", "Palace of Fine Arts", "park", 4, False, 37.8029, -122.4484,
        "3601 Lyon St, San Francisco, CA", ["Quiet"],
        "Good for a slow walk around the lagoon.", 14,
    ),
]

FIXTURE_PLACES: dict[str, list[Place]] = {
    DEMO_UID: _DEMO_PLACES,
    OTHER_UID: _OTHER_PLACES,
    PLANNER_UID: _PLANNER_PLACES,
    SPARSE_UID: _SPARSE_PLACES,
}