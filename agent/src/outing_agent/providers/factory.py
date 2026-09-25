from langchain_core.language_models import BaseChatModel

from outing_agent.config import DEFAULT_PROVIDER, MODELS


def get_chat_model(provider: str | None = None, model: str | None = None) -> BaseChatModel:
    provider = provider or DEFAULT_PROVIDER
    name = model or MODELS[provider]
    if provider == "anthropic":
        from langchain_anthropic import ChatAnthropic

        return ChatAnthropic(model=name, max_tokens=2048, timeout=60, max_retries=2)
    raise ValueError(f"unsupported provider {provider!r}")
