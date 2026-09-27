import argparse
from collections import defaultdict

from langsmith import Client

from evals.dataset import CASE_SETS
from evals.experiments import load_runs
from evals.scorers import _model_calls, requested_stops, tool_call_limit
from outing_agent import config  # noqa: F401

CANDIDATE_BUDGETS = {
    "flat 6": lambda stops: 6,
    "2 + 2 per stop": lambda stops: 2 + 2 * stops if stops else 6,
    "2 + 1 per stop": lambda stops: 2 + stops if stops else 6,
}


def describe(call: dict) -> str:
    args = {key: value for key, value in call["args"].items() if value not in (None, [], False)}
    return f"{call['name']}({', '.join(f'{k}={v}' for k, v in args.items())})"


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect tool_call_budget misses and candidate budgets.")
    parser.add_argument("--experiment", action="append", required=True, metavar="PROVIDER=EXPERIMENT")
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    args = parser.parse_args()

    client = Client()
    for pair in args.experiment:
        provider, experiment = pair.split("=", 1)
        runs = load_runs(client, experiment, CASE_SETS[args.cases][0])
        by_case = defaultdict(list)
        for run in runs:
            by_case[run.case_id].append(run)

        print(f"\n=== {provider} ({experiment}): runs over the current budget")
        route_calls = {
            case_id: [
                sum(call["name"] == "plan_route" for call in _model_calls(run.outputs))
                for run in case_runs
            ]
            for case_id, case_runs in by_case.items()
        }
        for case_id in sorted(by_case):
            for rep, run in enumerate(by_case[case_id], start=1):
                calls = _model_calls(run.outputs) if "tool_calls" in run.outputs else None
                limit = tool_call_limit(run.reference)
                if calls is None or len(calls) > limit:
                    stops = requested_stops(run.reference)
                    count = "no output" if calls is None else len(calls)
                    print(f"- {case_id} run {rep}: stops={stops} limit={limit} calls={count}")
                    for call in calls or []:
                        print(f"    {describe(call)}")

        print(f"\n=== {provider}: tool calls per run, and runs within each candidate budget")
        names = [*CANDIDATE_BUDGETS, "current (ref)"]
        print(f"{'case':<32} {'stops':>5} {'calls':<10} " + " ".join(f"{n[:14]:>14}" for n in names))
        totals = {name: 0 for name in names}
        run_count = 0
        for case_id in sorted(by_case):
            case_runs = by_case[case_id]
            stops = requested_stops(case_runs[0].reference)
            counts = [len(_model_calls(run.outputs)) for run in case_runs]
            has_output = ["tool_calls" in run.outputs for run in case_runs]
            cells = []
            for name in names:
                if name in CANDIDATE_BUDGETS:
                    limit = CANDIDATE_BUDGETS[name](stops)
                else:
                    limit = tool_call_limit(case_runs[0].reference)
                within = sum(ok and count <= limit for ok, count in zip(has_output, counts))
                totals[name] += within
                cells.append(f"{within}/{len(case_runs)}")
            run_count += len(case_runs)
            print(
                f"{case_id:<32} {stops:>5} {'/'.join(map(str, counts)):<10} "
                + " ".join(f"{cell:>14}" for cell in cells)
            )
        print(
            f"{'mean':<32} {'':>5} {'':<10} "
            + " ".join(f"{totals[name] / run_count:>14.3f}" for name in names)
        )

        print(f"\n=== {provider}: plan_route calls per run on route cases")
        for case_id in sorted(by_case):
            if by_case[case_id][0].reference["expects_route"]:
                print(f"{case_id:<32} {'/'.join(map(str, route_calls[case_id]))}")


if __name__ == "__main__":
    main()
