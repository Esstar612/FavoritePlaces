import logging
import sys

import pytest
from fastapi import HTTPException

from outing_agent.api import app as app_module
from outing_agent.api.rate_limit import RateLimiter


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


def test_allows_up_to_the_limit_then_refuses():
    limiter = RateLimiter(2, 3600)

    assert [limiter.allow("u") for _ in range(3)] == [True, True, False]


def test_window_expires():
    clock = FakeClock()
    limiter = RateLimiter(1, 3600, clock=clock)
    assert limiter.allow("u")
    assert not limiter.allow("u")

    clock.now = 3600

    assert limiter.allow("u")


def test_users_are_counted_separately():
    limiter = RateLimiter(1, 3600)

    assert limiter.allow("a")
    assert limiter.allow("b")
    assert not limiter.allow("a")


def test_global_cap_refuses_a_fresh_user_once_reached():
    limiters = (RateLimiter(5, 3600), RateLimiter(2, 3600))
    app_module.rate_limited_uid("a", limiters)
    app_module.rate_limited_uid("b", limiters)

    with pytest.raises(HTTPException) as refused:
        app_module.rate_limited_uid("c", limiters)

    assert refused.value.status_code == 429


def test_user_over_their_own_limit_does_not_use_up_the_global_cap():
    limiters = (RateLimiter(1, 3600), RateLimiter(2, 3600))
    app_module.rate_limited_uid("a", limiters)
    for _ in range(3):
        with pytest.raises(HTTPException):
            app_module.rate_limited_uid("a", limiters)

    assert app_module.rate_limited_uid("b", limiters) == "b"


def test_service_logs_outing_agent_info_to_stdout():
    logger = logging.getLogger("outing_agent")

    assert logger.isEnabledFor(logging.INFO)
    assert any(getattr(handler, "stream", None) is sys.stdout for handler in logger.handlers)
