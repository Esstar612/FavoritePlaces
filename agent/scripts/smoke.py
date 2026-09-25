import argparse
import json
import os
import time

from langchain_core.callbacks import get_usage_metadata_callback
from langchain_core.tracers.context import tracing_v2_enabled

from outing_agent import config
from outing_agent.graph.builder import build_graph
from outing_agent.places.fixtures import DEMO_UID
from outing_agent.places.store import FixturePlacesStore
from outing_agent.providers.factory import get_chat_model
from outing_agent.run import run_recommendation

DEFAULT_MESSAGE = "Plan me a relaxed Saturday morning: good coffee, then somewhere to walk."


def main() -> None:
    parser = argparse.ArgumentParser(description="One real agent run against the fixture store.")
    parser.add_argument("message", nargs="?", default=DEFAULT_MESSAGE)
    parser.add_argument("--provider", choices=sorted(config.MODELS), default=config.LLM_PROVIDER)
    args = parser.parse_args()

    provider = args.provider
    model = config.MODELS[provider]
    graph = build_graph(get_chat_model(provider))

    started = time.perf_counter()
    with tracing_v2_enabled(project_name=os.environ.get("LANGSMITH_PROJECT")) as tracer:
        with get_usage_metadata_callback() as usage:
            result = run_recommendation(
                graph,
                args.message,
                uid=DEMO_UID,
                store=FixturePlacesStore(),
                store_kind="fixture",
                provider=provider,
                model=model,
            )
    elapsed = time.perf_counter() - started

    print(f"provider: {provider}  model: {model}  run_id: {result.run_id}")
    print(f"elapsed_seconds: {elapsed:.2f}")
    print(f"token_usage: {json.dumps(usage.usage_metadata, default=str)}")
    print(f"\noverview: {result.overview}")
    print("\nrecommendations:")
    for rec in result.recommendations:
        when = f" ({rec.suggested_time})" if rec.suggested_time else ""
        print(f"  {rec.order}. {rec.title} [{rec.place_id}]{when}: {rec.reason}")
    print("\ntool_calls:")
    for call in result.tool_calls:
        print(f"  {call.name} {json.dumps(call.args)}")
    print(f"\nungrounded_place_ids: {result.ungrounded_place_ids}")
    print(f"rejected_place_ids: {result.rejected_place_ids}")
    try:
        print(f"\nlangsmith_run_url: {tracer.get_run_url()}")
    except ValueError as error:
        print(f"\nlangsmith_run_url: unavailable ({error})")


if __name__ == "__main__":
    main()
