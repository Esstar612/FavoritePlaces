import json

from evals.run_evals import check_scores
from evals.thresholds import load_thresholds

SCORES = {"grounded": [1.0, 1.0], "route_when_multi_stop": [1.0, 0.0], "fallback_rate": [1.0, 0.0]}
THRESHOLDS = {"anthropic": {"route_when_multi_stop": 0.8}}


def test_score_below_threshold_fails_a_full_run():
    lines, failures = check_scores("anthropic", SCORES, THRESHOLDS, enforce_thresholds=True)

    assert failures == ["anthropic:route_when_multi_stop"]
    assert any("threshold >= 0.80: FAIL" in line for line in lines)


def test_score_below_threshold_is_shown_but_does_not_fail_a_targeted_run():
    lines, failures = check_scores("anthropic", SCORES, THRESHOLDS, enforce_thresholds=False)

    assert failures == []
    assert any("threshold >= 0.80: FAIL" in line for line in lines)


def test_thresholds_are_per_provider():
    _, failures = check_scores("openai", SCORES, THRESHOLDS, enforce_thresholds=True)

    assert failures == []


def test_gates_fail_even_in_a_targeted_run():
    scores = {"grounded": [1.0, 0.0]}

    _, failures = check_scores("anthropic", scores, {}, enforce_thresholds=False)

    assert failures == ["anthropic:grounded"]


def test_report_only_scorers_never_fail():
    lines, failures = check_scores(
        "anthropic", {"fallback_rate": [0.0]}, {"anthropic": {"fallback_rate": 0.5}}, True
    )

    assert failures == []
    assert any("report only" in line for line in lines)


def test_missing_thresholds_file_means_no_thresholds(tmp_path):
    assert load_thresholds(tmp_path / "thresholds.json") == {}


def test_thresholds_file_is_read_by_provider(tmp_path):
    path = tmp_path / "thresholds.json"
    path.write_text(json.dumps({"confidence": 0.99, "providers": THRESHOLDS}))

    assert load_thresholds(path) == THRESHOLDS
