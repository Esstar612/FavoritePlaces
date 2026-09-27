from collections import defaultdict
from collections.abc import Callable, Iterable
from dataclasses import dataclass

from langsmith import Client


@dataclass(frozen=True)
class ExperimentRun:
    case_id: str
    inputs: dict
    outputs: dict
    reference: dict


def load_runs(client: Client, experiment: str, dataset_name: str) -> list[ExperimentRun]:
    examples = {example.id: example for example in client.list_examples(dataset_name=dataset_name)}
    runs = []
    for run in client.list_runs(project_name=experiment, is_root=True):
        example = examples[run.reference_example_id]
        runs.append(
            ExperimentRun(
                case_id=example.metadata["case_id"],
                inputs=dict(example.inputs),
                outputs=run.outputs or {},
                reference=dict(example.outputs),
            )
        )
    return runs


def rescore(
    runs: Iterable[ExperimentRun], evaluators: Iterable[Callable[..., dict]]
) -> dict[str, dict[str, list[float]]]:
    scores: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    evaluators = list(evaluators)
    for run in runs:
        for evaluator in evaluators:
            result = evaluator(outputs=run.outputs, reference_outputs=run.reference)
            if result["score"] is not None:
                scores[result["key"]][run.case_id].append(float(result["score"]))
    return scores
