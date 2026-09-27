import pytest
from langchain_anthropic import ChatAnthropic
from langchain_openai import ChatOpenAI

from outing_agent.config import MAX_OUTPUT_TOKENS, MODELS, REQUEST_TIMEOUT_S
from outing_agent.graph.builder import build_graph
from outing_agent.providers.factory import get_chat_model


@pytest.fixture(autouse=True)
def dummy_keys(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-anthropic-key")
    monkeypatch.setenv("OPENAI_API_KEY", "test-openai-key")


def test_anthropic_model_settings():
    model = get_chat_model("anthropic")

    assert isinstance(model, ChatAnthropic)
    assert model.model == MODELS["anthropic"]
    assert model.max_tokens == MAX_OUTPUT_TOKENS
    assert model.default_request_timeout == REQUEST_TIMEOUT_S
    assert model.max_retries == 2


def test_openai_model_settings():
    model = get_chat_model("openai")

    assert isinstance(model, ChatOpenAI)
    assert model.model_name == MODELS["openai"]
    assert model.max_tokens == MAX_OUTPUT_TOKENS
    assert model.request_timeout == REQUEST_TIMEOUT_S
    assert model.max_retries == 2


def test_model_name_can_be_overridden():
    assert get_chat_model("openai", model="gpt-6-luna").model_name == "gpt-6-luna"


def test_unknown_provider_is_rejected():
    with pytest.raises(ValueError):
        get_chat_model("gemini")


@pytest.mark.parametrize("provider", sorted(MODELS))
def test_graph_builds_with_each_provider(provider):
    graph = build_graph(get_chat_model(provider))

    assert {"agent", "tools", "finalize"} <= set(graph.get_graph().nodes)
