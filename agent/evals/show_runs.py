import argparse

from langsmith import Client

from evals.dataset import CASE_SETS, load_cases
from evals.experiments import load_runs
from evals.inspect_budget import describe
from outing_agent import config  # noqa: F401
from outing_agent.places.fixtures import FIXTURE_PLACES


def saved_text(uid: str, place_id: str) -> str:
    place = next((place for place in FIXTURE_PLACES.get(uid, []) if place.id == place_id), None)
    if place is None:
        return "not a saved place of this user"
    notes = place.notes or "(none)"
    summary = place.summary.model_dump_json() if place.summary else "(none)"
    return f"notes: {notes}  summary: {summary}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Print the runs of chosen cases in an experiment.")
    parser.add_argument("--experiment", required=True)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    args = parser.parse_args()
    unknown = sorted(set(args.case) - {case["id"] for case in load_cases(args.cases)})
    if unknown:
        parser.error(f"unknown case IDs in {args.cases}: {', '.join(unknown)}")

    runs = load_runs(Client(), args.experiment, CASE_SETS[args.cases][0])
    for case_id in args.case:
        case_runs = [run for run in runs if run.case_id == case_id]
        for rep, run in enumerate(case_runs, start=1):
            outputs = run.outputs
            print(f"\n=== {case_id} run {rep} of {len(case_runs)}")
            if not outputs:
                print("no output (the run failed)")
                continue
            print("tool calls:")
            for call in outputs["tool_calls"]:
                marker = " [graph]" if call.get("source") == "graph" else ""
                print(f"  {describe(call)}{marker}")
            if any(call.get("source") == "graph" for call in outputs["tool_calls"]):
                print(f"draft: {outputs.get('draft_place_ids')}")
                print(f"removed by fallback: {outputs.get('fallback_removed_place_ids')}")
            print(f"kind: {outputs.get('kind')}")
            print("recommendations:")
            for rec in outputs["recommendations"]:
                when = f" ({rec['suggested_time']})" if rec.get("suggested_time") else ""
                print(f"  {rec['order']}. {rec['title']} [{rec['place_id']}, {rec.get('category', '?')}]{when}: {rec['reason']}")
                print(f"     saved {saved_text(run.inputs['uid'], rec['place_id'])}")
            read = {
                place_id
                for call in outputs["tool_calls"]
                if call["name"] == "get_place_details"
                for place_id in call["args"].get("place_ids") or []
            }
            unread = [rec["place_id"] for rec in outputs["recommendations"] if rec["place_id"] not in read]
            print(f"unread in answer: {unread}")
            print(f"ungrounded: {outputs['ungrounded_place_ids']}  rejected: {outputs['rejected_place_ids']}")
            print(f"overview: {outputs['overview']}")


if __name__ == "__main__":
    main()
