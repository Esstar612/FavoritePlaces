"""Demo places for tests, evals, and local runs without credentials.

DEMO_UID's places are copied from DEMO_PLACES in backend/routes/user.js (the
guest sandbox seed), with fixed IDs and dates so runs are reproducible. Keep
them in sync if that seed changes. OTHER_UID exists so tests and evals can
catch one user's places leaking into another user's results.
"""

from datetime import datetime, timezone

from outing_agent.places.models import Place

DEMO_UID = "demo-user"
OTHER_UID = "other-user"


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

FIXTURE_PLACES: dict[str, list[Place]] = {
    DEMO_UID: _DEMO_PLACES,
    OTHER_UID: _OTHER_PLACES,
}