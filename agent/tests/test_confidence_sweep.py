from types import SimpleNamespace

from evals.confidence_sweep import first_round_confidences, pick_threshold, sweep


def row(threshold, asked_vague, needless):
    return {"threshold": threshold, "asked_vague": asked_vague, "needless": needless}


def test_sweep_counts_confidences_below_each_threshold():
    rows = {r["threshold"]: r for r in sweep(vague=[0.3, 0.5], clear=[0.9, 0.95, 0.4, 0.9])}

    assert rows[0.35] == row(0.35, 0.5, 0.0)
    assert rows[0.55] == row(0.55, 1.0, 0.25)
    assert rows[0.05] == row(0.05, 0.0, 0.0)


def test_pick_takes_the_most_vague_asked_within_the_needless_cap():
    rows = [row(0.4, 0.5, 0.0), row(0.6, 0.75, 0.05), row(0.8, 1.0, 0.2)]

    assert pick_threshold(rows) == 0.6


def test_pick_breaks_ties_toward_the_lower_threshold():
    rows = [row(0.5, 0.75, 0.0), row(0.6, 0.75, 0.0)]

    assert pick_threshold(rows) == 0.5


def test_no_pick_when_confidence_does_not_separate():
    rows = [row(0.4, 0.25, 0.0), row(0.8, 1.0, 0.3)]

    assert pick_threshold(rows) is None


def test_no_pick_without_vague_runs():
    assert pick_threshold(sweep(vague=[], clear=[0.9])) is None


def test_first_round_confidences_split_by_label_and_skip_round_trips():
    def run(conf, vague, clarified=False):
        inputs = {"uid": "u", **({"clarification": {}} if clarified else {"message": "m"})}
        return SimpleNamespace(
            inputs=inputs,
            outputs={} if conf is None else {"confidence": conf},
            reference={"expects_clarification": vague},
        )

    runs = [run(0.3, True), run(0.9, False), run(0.2, False, clarified=True), run(None, False)]

    assert first_round_confidences(runs) == ([0.3], [0.9])
