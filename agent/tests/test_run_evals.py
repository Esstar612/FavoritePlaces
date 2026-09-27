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


def test_eval_target_passes_clarification_through(monkeypatch):
    from evals import run_evals

    calls = []

    class Result:
        def model_dump(self):
            return {}

    def fake_run(graph, message, **kwargs):
        calls.append((message, kwargs))
        return Result()

    monkeypatch.setattr(run_evals, "get_chat_model", lambda provider: None)
    monkeypatch.setattr(run_evals, "build_graph", lambda model: "graph")
    monkeypatch.setattr(run_evals, "run_recommendation", fake_run)
    clarification = {
        "original_message": "Plan my Saturday.",
        "question": "Morning?",
        "answer": "Yes",
    }
    target = run_evals.make_target("anthropic")

    target({"uid": "planner-user", "clarification": clarification})
    target({"uid": "demo-user", "message": "coffee"})

    assert calls[0][0] is None
    assert calls[0][1]["clarification"] == clarification
    assert calls[0][1]["uid"] == "planner-user"
    assert calls[1][0] == "coffee"
    assert calls[1][1]["clarification"] is None
