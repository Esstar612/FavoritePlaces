from types import SimpleNamespace

from evals.dataset import load_cases, to_example
from evals.sync_dataset import changed_fields

EXAMPLE = to_example(load_cases("main")[0])


def stored(inputs=None, outputs=None, metadata=None):
    return SimpleNamespace(
        inputs=dict(EXAMPLE["inputs"]) if inputs is None else inputs,
        outputs=dict(EXAMPLE["outputs"]) if outputs is None else outputs,
        metadata=dict(EXAMPLE["metadata"]) if metadata is None else metadata,
    )


def test_matching_example_has_no_changes():
    assert changed_fields(stored(), EXAMPLE) == []


def test_metadata_keys_added_by_langsmith_are_ignored():
    current = stored(metadata={**EXAMPLE["metadata"], "dataset_split": ["base"]})

    assert changed_fields(current, EXAMPLE) == []


def test_changed_metadata_we_set_is_reported():
    current = stored(metadata={**EXAMPLE["metadata"], "tags": ["old-tag"]})

    assert [change.split(":")[0] for change in changed_fields(current, EXAMPLE)] == [
        "metadata.tags"
    ]


def test_changed_reference_value_is_reported():
    current = stored(
        outputs={**EXAMPLE["outputs"], "expects_route": not EXAMPLE["outputs"]["expects_route"]}
    )

    assert [change.split(":")[0] for change in changed_fields(current, EXAMPLE)] == [
        "outputs.expects_route"
    ]


def test_reference_key_removed_from_the_cases_is_reported():
    current = stored(outputs={**EXAMPLE["outputs"], "retired_key": 1})

    assert [change.split(":")[0] for change in changed_fields(current, EXAMPLE)] == [
        "outputs.retired_key"
    ]


def test_missing_stored_fields_count_as_changes():
    current = SimpleNamespace(inputs=None, outputs=None, metadata=None)

    assert changed_fields(current, EXAMPLE)
