import argparse
import json

from langsmith import Client

from evals.dataset import CASE_SETS
from evals.experiments import load_runs
from outing_agent.config import CONFIDENCE_THRESHOLDS_FILE

THRESHOLDS = [round(0.05 * step, 2) for step in range(1, 20)]
MAX_NEEDLESS = 0.05
MIN_ASKED_VAGUE = 0.5


def sweep(vague: list[float], clear: list[float]) -> list[dict]:
    rows = []
    for threshold in THRESHOLDS:
        asked = sum(conf < threshold for conf in vague) / len(vague) if vague else 0.0
        needless = sum(conf < threshold for conf in clear) / len(clear) if clear else 0.0
        rows.append({"threshold": threshold, "asked_vague": asked, "needless": needless})
    return rows


def pick_threshold(rows: list[dict]) -> float | None:
    allowed = [row for row in rows if row["needless"] <= MAX_NEEDLESS]
    if not allowed:
        return None
    best = max(row["asked_vague"] for row in allowed)
    if best < MIN_ASKED_VAGUE:
        return None
    return min(row["threshold"] for row in allowed if row["asked_vague"] == best)


def first_round_confidences(runs) -> tuple[list[float], list[float]]:
    vague, clear = [], []
    for run in runs:
        confidence = run.outputs.get("confidence")
        if confidence is None or "clarification" in run.inputs:
            continue
        (vague if run.reference.get("expects_clarification") else clear).append(confidence)
    return vague, clear


def main() -> None:
    parser = argparse.ArgumentParser(description="Pick per-provider confidence thresholds.")
    parser.add_argument(
        "--experiment", action="append", required=True, metavar="PROVIDER=EXPERIMENT"
    )
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    parser.add_argument(
        "--write", action="store_true", help=f"save to {CONFIDENCE_THRESHOLDS_FILE.name}"
    )
    args = parser.parse_args()

    client = Client()
    picked = {}
    for pair in args.experiment:
        provider, experiment = pair.split("=", 1)
        vague, clear = first_round_confidences(
            load_runs(client, experiment, CASE_SETS[args.cases][0])
        )
        print(f"\n=== {provider} ({experiment}): {len(vague)} vague runs, {len(clear)} clear runs")
        print(f"{'threshold':>9} {'asked_vague':>11} {'needless':>8}")
        rows = sweep(vague, clear)
        for row in rows:
            print(f"{row['threshold']:>9.2f} {row['asked_vague']:>11.3f} {row['needless']:>8.3f}")
        threshold = pick_threshold(rows)
        if threshold is None:
            print(
                f"no threshold asks on at least {MIN_ASKED_VAGUE:.0%} of vague runs with at most "
                f"{MAX_NEEDLESS:.0%} needless questions; confidence doesn't separate them"
            )
        else:
            print(f"pick: {threshold:.2f}")
            picked[provider] = threshold

    if args.write:
        if not picked:
            print("\nNothing written: no provider has a threshold.")
            return
        CONFIDENCE_THRESHOLDS_FILE.write_text(
            json.dumps(
                {
                    "max_needless": MAX_NEEDLESS,
                    "min_asked_vague": MIN_ASKED_VAGUE,
                    "case_set": args.cases,
                    "experiments": dict(pair.split("=", 1) for pair in args.experiment),
                    "providers": picked,
                },
                indent=2,
            )
            + "\n"
        )
        print(f"\nWrote {CONFIDENCE_THRESHOLDS_FILE}")


if __name__ == "__main__":
    main()
