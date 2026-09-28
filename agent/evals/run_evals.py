import argparse
import os
import subprocess
import sys
from collections import defaultdict
from statistics import mean

from langsmith import Client, evaluate

from evals.dataset import CASE_SETS, load_cases
from evals.scorers import EVALUATORS, GATES, REPORT_ONLY
from evals.thresholds import load_thresholds
from outing_agent import config
from outing_agent.graph.builder import build_graph
from outing_agent.places.store import FixturePlacesStore
from outing_agent.providers.factory import get_chat_model
from outing_agent.run import run_recommendation

DEFAULT_REPETITIONS = 3
MAX_CONCURRENCY = 4
# Sets too small or too different to compare with thresholds set on the main cases.
THRESHOLDLESS_CASE_SETS = {"start_place"}


def make_target(provider: str):
    graph = build_graph(get_chat_model(provider))
    model = config.MODELS[provider]

    def target(inputs: dict) -> dict:
        result = run_recommendation(
            graph,
            inputs.get("message"),
            clarification=inputs.get("clarification"),
            start_place_id=inputs.get("start_place_id"),
            uid=inputs["uid"],
            store=FixturePlacesStore(),
            store_kind="fixture",
            provider=provider,
            model=model,
        )
        return result.model_dump()

    return target


def enforces_thresholds(case_set: str, case_ids: list[str] | None) -> bool:
    return not case_ids and case_set not in THRESHOLDLESS_CASE_SETS


def git_revision() -> str:
    if sha := os.environ.get("GITHUB_SHA"):
        return sha[:7]
    try:
        return subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def collect_scores(results) -> dict[str, list[float]]:
    scores: dict[str, list[float]] = defaultdict(list)
    for row in results:
        for evaluation in row["evaluation_results"]["results"]:
            if evaluation.score is not None:
                scores[evaluation.key].append(float(evaluation.score))
    return scores


def check_scores(
    provider: str,
    scores: dict[str, list[float]],
    thresholds: dict[str, dict[str, float]],
    enforce_thresholds: bool,
) -> tuple[list[str], list[str]]:
    lines, failures = [], []
    for key in sorted(scores):
        values = scores[key]
        gate = GATES.get(key)
        threshold = None if key in REPORT_ONLY else thresholds.get(provider, {}).get(key)
        status = "  report only" if key in REPORT_ONLY else ""
        if gate is not None:
            passed = mean(values) >= gate
            status = f"  gate >= {gate}: {'pass' if passed else 'FAIL'}"
            if not passed:
                failures.append(f"{provider}:{key}")
        elif threshold is not None:
            passed = mean(values) >= threshold
            status = f"  threshold >= {threshold:.2f}: {'pass' if passed else 'FAIL'}"
            if not passed and enforce_thresholds:
                failures.append(f"{provider}:{key}")
        lines.append(f"  {key:<30} mean {mean(values):.3f}  n={len(values)}{status}")
    return lines, failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the outing agent evals in LangSmith.")
    parser.add_argument("--provider", choices=[*sorted(config.MODELS), "both"], default="both")
    parser.add_argument("--repetitions", type=int, default=DEFAULT_REPETITIONS)
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    parser.add_argument(
        "--case", action="append", metavar="CASE_ID", help="run only these case IDs"
    )
    parser.add_argument("--yes", action="store_true", help="actually run the paid model calls")
    args = parser.parse_args()
    dataset_name = CASE_SETS[args.cases][0]

    providers = sorted(config.MODELS) if args.provider == "both" else [args.provider]
    cases = load_cases(args.cases)
    if args.case:
        unknown = sorted(set(args.case) - {case["id"] for case in cases})
        if unknown:
            print(f"Unknown case IDs in {args.cases}: {', '.join(unknown)}")
            return 2
        cases = [case for case in cases if case["id"] in args.case]
    agent_runs = len(cases) * args.repetitions * len(providers)
    print(
        f"Plan: {dataset_name}, {len(cases)} cases x {args.repetitions} repetitions x {len(providers)} "
        f"provider(s) ({', '.join(providers)}) = {agent_runs} agent runs, "
        "each making several paid model calls."
    )
    if not args.yes:
        print("Dry run only. Re-run with --yes to spend on model calls.")
        return 0

    client = Client()
    if not client.has_dataset(dataset_name=dataset_name):
        print(
            f"Dataset {dataset_name} not found. Run `python -m evals.sync_dataset --cases {args.cases}` first."
        )
        return 2

    data = dataset_name
    prefix = f"outing-agent-{args.cases}"
    if args.case:
        data = [
            example
            for example in client.list_examples(dataset_name=dataset_name)
            if example.metadata.get("case_id") in args.case
        ]
        missing = sorted(set(args.case) - {example.metadata["case_id"] for example in data})
        if missing:
            print(f"Case IDs not in {dataset_name}: {', '.join(missing)}. Run the sync first.")
            return 2
        prefix = f"{prefix}-targeted"

    revision = git_revision()
    thresholds = load_thresholds()
    enforce = enforces_thresholds(args.cases, args.case)
    failures = []
    for provider in providers:
        results = evaluate(
            make_target(provider),
            data=data,
            evaluators=EVALUATORS,
            experiment_prefix=f"{prefix}-{provider}",
            metadata={
                "provider": provider,
                "model": config.MODELS[provider],
                "revision": revision,
                "case_set": args.cases,
                "case_ids": args.case or "all",
            },
            num_repetitions=args.repetitions,
            max_concurrency=MAX_CONCURRENCY,
            client=client,
            disable_evaluator_tracing=True,
        )
        scores = collect_scores(results)
        print(f"\n{provider} ({config.MODELS[provider]}), experiment {results.experiment_name}")
        lines, provider_failures = check_scores(
            provider, scores, thresholds, enforce_thresholds=enforce
        )
        print("\n".join(lines))
        failures.extend(provider_failures)
        if args.case:
            case_args = " ".join(f"--case {case_id}" for case_id in args.case)
            print(
                f"\n  Inspect: python -m evals.show_runs --experiment {results.experiment_name} "
                f"--cases {args.cases} {case_args}"
            )

    if failures:
        print(f"\nFailures: {', '.join(failures)}")
        return 1
    print("\nAll gates and thresholds passed." if thresholds and enforce else "\nAll gates passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
