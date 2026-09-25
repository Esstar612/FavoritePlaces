from langchain_core.language_models import BaseChatModel

from outing_agent.config import LLM_PROVIDER, MAX_OUTPUT_TOKENS, MODELS, REQUEST_TIMEOUT_S


def get_chat_model(provider: str | None = None, model: str | None = None) -> BaseChatModel:
    provider = provider or LLM_PROVIDER
    if provider not in MODELS:
        raise ValueError(f"unsupported provider {provider!r}")
    name = model or MODELS[provider]
    if provider == "anthropic":
        from langchain_anthropic import ChatAnthropic

        return ChatAnthropic(
            model=name, max_tokens=MAX_OUTPUT_TOKENS, timeout=REQUEST_TIMEOUT_S, max_retries=2
        )
    from langchain_openai import ChatOpenAI

    return ChatOpenAI(
        model=name,
        max_completion_tokens=MAX_OUTPUT_TOKENS,
        timeout=REQUEST_TIMEOUT_S,
        max_retries=2,
    )
