import langsmith
import pytest
from langsmith import tracing_context


@pytest.fixture(autouse=True)
def _no_langsmith_tracing():
    langsmith.configure(enabled=False)
    with tracing_context(enabled=False):
        yield
