import argparse
import json
import math
import random
from pathlib import Path
from statistics import mean

from langsmith import Client

from evals.dataset import CASE_SETS
from evals.experiments import load_runs, rescore
from evals.scorers import EVALUATORS, GATES, REPORT_ONLY
from outing_agent import config

ITERATIONS = 10_000
COLLAPSE_MARGIN = 0.10
THRESHOLDS_FILE = Path(__file__).with_name("thresholds.json")


def load_thresholds(path: Path = THRESHOLDS_FILE) -> dict[str, dict[str, float]]:
    if not path.exists():
        return {}
    return json.loads(path.read_text())["providers"]


def floor_to_step(value: float, step: float = 0.05) -> float:
    return math.floor(round(value / step, 9)) * step


def bootstrap_interval(
    per_case: list[list[float]], confidence: float, rng: random.Random
) -> tuple[float, float]:
    tail = (1 - confidence) / 2
    samples = []
    for _ in range(ITERATIONS):
        drawn = [score for scores in rng.choices(per_case, k=len(per_case)) for score in scores]
        samples.append(mean(drawn))
    samples.sort()
    return samples[int(tail * ITERATIONS)], samples[math.ceil((1 - tail) * ITERATIONS) - 1]


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap per-provider scorer thresholds.")
    parser.add_argument(
        "--experiment",
        action="append",
        required=True,
        metavar="PROVIDER=EXPERIMENT",
        help="e.g. anthropic=outing-agent-main-anthropic-05731736",
    )
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    parser.add_argument("--confidence", type=float, default=0.90)
    parser.add_argument(
        "--write", action="store_true", help=f"save the thresholds to {THRESHOLDS_FILE.name}"
    )
    args = parser.parse_args()
    computed = {
        "confidence": args.confidence,
        "case_set": args.cases,
        "experiments": dict(pair.split("=", 1) for pair in args.experiment),
        "providers": {},
    }

    client = Client()
    interval_label = f"{args.confidence:.0%} interval"
    print(
        f"{'scorer':<28} {'provider':<10} {'mean':>6} {'n':>4} {'cases':>5} "
        f"{interval_label:>15} {'threshold':>9}  rule"
    )
    for pair in args.experiment:
        provider, experiment = pair.split("=", 1)
        rng = random.Random(config.RANDOM_SEED)
        runs = load_runs(client, experiment, CASE_SETS[args.cases][0])
        scores = rescore(runs, EVALUATORS)
        for key in sorted(scores):
            if key in GATES or key in REPORT_ONLY:
                continue
            per_case = list(scores[key].values())
            flat = [score for case in per_case for score in case]
            low, high = bootstrap_interval(per_case, args.confidence, rng)
            rule = "bootstrap lower bound"
            threshold = floor_to_step(low)
            if low == high:
                threshold = floor_to_step(min(low, mean(flat) - COLLAPSE_MARGIN))
                rule = "collapsed interval: min(lower bound, mean - 0.10)"
            computed["providers"].setdefault(provider, {})[key] = round(threshold, 2)
            print(
                f"{key:<28} {provider:<10} {mean(flat):>6.3f} {len(flat):>4} {len(per_case):>5} "
                f"{f'[{low:.3f}, {high:.3f}]':>15} {threshold:>9.2f}  {rule}"
            )

    if args.write:
        THRESHOLDS_FILE.write_text(json.dumps(computed, indent=2) + "\n")
        print(f"\nWrote {THRESHOLDS_FILE}")


if __name__ == "__main__":
    main()
