import argparse

from langsmith import Client

from evals.dataset import CASE_SETS, load_cases, to_example
from outing_agent import config  # noqa: F401


def main() -> None:
    parser = argparse.ArgumentParser(description="Upsert eval cases into a LangSmith dataset.")
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    args = parser.parse_args()
    dataset_name = CASE_SETS[args.cases][0]

    client = Client()
    if client.has_dataset(dataset_name=dataset_name):
        dataset = client.read_dataset(dataset_name=dataset_name)
    else:
        dataset = client.create_dataset(
            dataset_name, description=f"Outing agent {args.cases} cases over the fixture store."
        )

    existing = {
        (example.metadata or {}).get("case_id"): example
        for example in client.list_examples(dataset_id=dataset.id)
    }
    cases = load_cases(args.cases)
    created = updated = 0
    to_create = []
    for case in cases:
        example = to_example(case)
        current = existing.get(case["id"])
        if current is None:
            to_create.append(example)
            created += 1
        elif (current.inputs, current.outputs, current.metadata) != (
            example["inputs"],
            example["outputs"],
            example["metadata"],
        ):
            client.update_example(
                current.id,
                inputs=example["inputs"],
                outputs=example["outputs"],
                metadata=example["metadata"],
            )
            updated += 1
    if to_create:
        client.create_examples(dataset_id=dataset.id, examples=to_create)

    case_ids = {case["id"] for case in cases}
    deleted = 0
    for case_id, example in existing.items():
        if case_id not in case_ids:
            client.delete_example(example.id)
            deleted += 1

    print(
        f"{dataset_name}: {len(cases)} cases "
        f"({created} created, {updated} updated, {deleted} deleted)"
    )


if __name__ == "__main__":
    main()
