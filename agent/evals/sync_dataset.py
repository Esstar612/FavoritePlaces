import argparse

from langsmith import Client

from evals.dataset import CASE_SETS, load_cases, to_example
from outing_agent import config  # noqa: F401


def changed_fields(current, example: dict) -> list[str]:
    differences = []
    for field in ("inputs", "outputs", "metadata"):
        stored, wanted = getattr(current, field) or {}, example[field]
        # LangSmith adds its own metadata keys, such as dataset_split, so only ours are compared.
        keys = wanted.keys() if field == "metadata" else stored.keys() | wanted.keys()
        for key in sorted(keys):
            if stored.get(key) != wanted.get(key):
                differences.append(
                    f"{field}.{key}: stored {stored.get(key)!r}, wanted {wanted.get(key)!r}"
                )
    return differences


def main() -> None:
    parser = argparse.ArgumentParser(description="Upsert eval cases into a LangSmith dataset.")
    parser.add_argument("--cases", choices=sorted(CASE_SETS), default="main")
    parser.add_argument("--dry-run", action="store_true", help="show what would change without writing")
    args = parser.parse_args()
    dataset_name = CASE_SETS[args.cases][0]

    client = Client()
    if client.has_dataset(dataset_name=dataset_name):
        dataset = client.read_dataset(dataset_name=dataset_name)
        existing = {
            (example.metadata or {}).get("case_id"): example
            for example in client.list_examples(dataset_id=dataset.id)
        }
    elif args.dry_run:
        dataset, existing = None, {}
    else:
        dataset = client.create_dataset(
            dataset_name, description=f"Outing agent {args.cases} cases over the fixture store."
        )
        existing = {}

    cases = load_cases(args.cases)
    created = updated = 0
    to_create = []
    for case in cases:
        example = to_example(case)
        current = existing.get(case["id"])
        if current is None:
            to_create.append(example)
            created += 1
        elif differences := changed_fields(current, example):
            updated += 1
            if args.dry_run:
                print(f"  {case['id']}: {'; '.join(differences)}")
                continue
            client.update_example(
                current.id,
                inputs=example["inputs"],
                outputs=example["outputs"],
                metadata=example["metadata"],
            )
    if to_create and not args.dry_run:
        client.create_examples(dataset_id=dataset.id, examples=to_create)

    case_ids = {case["id"] for case in cases}
    deleted = 0
    for case_id, example in existing.items():
        if case_id not in case_ids:
            if not args.dry_run:
                client.delete_example(example.id)
            deleted += 1

    verb = "would be " if args.dry_run else ""
    print(
        f"{dataset_name}: {len(cases)} cases "
        f"({created} {verb}created, {updated} {verb}updated, {deleted} {verb}deleted)"
    )


if __name__ == "__main__":
    main()
