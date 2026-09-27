import argparse

from langsmith import Client

from outing_agent import config  # noqa: F401

FIELDS = ["id", "parent_run_ids", "total_tokens", "total_cost"]


def main() -> None:
    parser = argparse.ArgumentParser(description="Tokens and cost spent by the fallback node.")
    parser.add_argument(
        "--experiment", action="append", required=True, metavar="PROVIDER=EXPERIMENT"
    )
    args = parser.parse_args()

    client = Client()
    for pair in args.experiment:
        provider, experiment = pair.split("=", 1)
        roots = list(client.list_runs(project_name=experiment, is_root=True, select=["id"]))
        fallback_ids = {
            run.id
            for run in client.list_runs(
                project_name=experiment, filter='eq(name, "fallback")', select=["id"]
            )
        }
        llm_runs = list(client.list_runs(project_name=experiment, run_type="llm", select=FIELDS))
        in_fallback = [run for run in llm_runs if fallback_ids & set(run.parent_run_ids or [])]

        print(f"\n=== {provider} ({experiment})")
        print(f"agent runs {len(roots)}, fallback ran in {len(fallback_ids)}")
        if fallback_ids and not in_fallback:
            print(
                "no model calls could be matched to a fallback run; the totals below are incomplete"
            )
        for label, runs in (("all model calls", llm_runs), ("fallback model calls", in_fallback)):
            tokens = sum(run.total_tokens or 0 for run in runs)
            costs = [run.total_cost for run in runs if run.total_cost is not None]
            cost = f"cost {sum(costs):.4f}" if costs else "cost not recorded"
            missing = len(runs) - len(costs)
            note = f" ({missing} calls without cost)" if costs and missing else ""
            print(f"  {label:<22} calls {len(runs):>4}  tokens {tokens:>9}  {cost}{note}")
        total_tokens = sum(run.total_tokens or 0 for run in llm_runs)
        if total_tokens:
            share = sum(run.total_tokens or 0 for run in in_fallback) / total_tokens
            print(f"  fallback share of tokens {share:.1%}")


if __name__ == "__main__":
    main()
