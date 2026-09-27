import os

from langchain_core.language_models import BaseChatModel

from outing_agent.config import LLM_PROVIDER, MAX_OUTPUT_TOKENS, MODELS, REQUEST_TIMEOUT_S


def _api_key(env_var: str) -> dict:
    # A key copied from a secret store or pasted into a shell can carry a trailing newline, which is an illegal HTTP header value.
    key = os.environ.get(env_var, "").strip()
    return {"api_key": key} if key else {}


def get_chat_model(provider: str | None = None, model: str | None = None) -> BaseChatModel:
    provider = provider or LLM_PROVIDER
    if provider not in MODELS:
        raise ValueError(f"unsupported provider {provider!r}")
    name = model or MODELS[provider]
    if provider == "anthropic":
        from langchain_anthropic import ChatAnthropic

        return ChatAnthropic(
            model=name,
            max_tokens=MAX_OUTPUT_TOKENS,
            timeout=REQUEST_TIMEOUT_S,
            max_retries=2,
            **_api_key("ANTHROPIC_API_KEY"),
        )
    from langchain_openai import ChatOpenAI

    return ChatOpenAI(
        model=name,
        max_completion_tokens=MAX_OUTPUT_TOKENS,
        timeout=REQUEST_TIMEOUT_S,
        max_retries=2,
        **_api_key("OPENAI_API_KEY"),
    )
