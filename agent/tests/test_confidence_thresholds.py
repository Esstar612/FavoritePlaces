import json

from outing_agent.config import confidence_threshold


def test_missing_file_means_no_threshold(tmp_path):
    assert confidence_threshold("anthropic", tmp_path / "confidence_thresholds.json") is None


def test_provider_missing_from_the_file_means_no_threshold(tmp_path):
    path = tmp_path / "confidence_thresholds.json"
    path.write_text(json.dumps({"providers": {"openai": 0.4}}))

    assert confidence_threshold("anthropic", path) is None
    assert confidence_threshold("openai", path) == 0.4
