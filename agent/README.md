# Outing agent

A Python service that recommends outings from a user's saved Favorite Places
using tool calling. FastAPI for the API, LangGraph for the agent, LangSmith for
tracing and evals. Anthropic and OpenAI sit behind one provider interface.

Status: deployed to Cloud Run as `favorite-places-agent`, behind a CI eval gate.
It exposes `GET /health` and `POST /recommend`. See `BUILD_LOG.md` for how it
was built and measured.

## Setup

Requires Python 3.11 or newer. Run everything from this `agent/` folder.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"
cp .env.example .env    # then fill in the keys
```

### Firebase credentials

The service reads saved places from Firestore. It checks three options in
order, and the first non-empty one wins:

1. `FIREBASE_SERVICE_ACCOUNT_JSON`: the whole service account key as one string.
2. `FIREBASE_SERVICE_ACCOUNT_PATH`: a path to a key file. A relative path
   resolves against `agent/`, not the working directory. If it is set and the
   file is missing, the first Firestore call fails with an error naming the
   path. It does not fall back to option 3.
3. Neither set: Application Default Credentials. On Cloud Run this is the
   service's attached service account, so no key is needed. Locally, run
   `gcloud auth application-default login`. `GOOGLE_CLOUD_PROJECT` is passed
   as the project ID.

A fresh `.env` copied from `.env.example` uses option 3. `serviceAccountKey.json`
is gitignored. Firebase initializes on first use, so `/health` and the tests
need no credentials at all.

## Run

```bash
uvicorn outing_agent.api.app:app --reload --reload-dir src --port 8001
curl http://localhost:8001/health
```

Port 8001 keeps it clear of the Express backend on 8080. `--reload-dir src`
limits the file watcher to our code. Without it, the reloader also watches
`.venv/` and restarts over and over while Dropbox syncs the installed packages.

## Test

```bash
pytest
```

## Smoke run

One real request against the fixture store as `demo-user`. It needs `ANTHROPIC_API_KEY`, and it traces to LangSmith if `LANGSMITH_TRACING=true`:

```bash
python scripts/smoke.py
python scripts/smoke.py "somewhere quiet to spend a rainy afternoon"
python scripts/smoke.py --provider openai
```

The OpenAI run needs `OPENAI_API_KEY`. `LLM_PROVIDER` in `.env` picks the provider the service uses; it defaults to `anthropic`.

## Evals

The eval cases live in `evals/cases.json` (27 main cases) and
`evals/cases_holdout.json` (3 holdout cases). They run against the fixture
store, so they need model and LangSmith keys but no Firebase credentials.

```bash
python -m evals.sync_dataset --dry-run      # show what would change in LangSmith
python -m evals.sync_dataset                # upload the cases
python -m evals.run_evals                   # dry run: prints the plan only
python -m evals.run_evals --yes             # full run, both providers, paid
python -m evals.run_evals --provider anthropic --case five-stars-only --repetitions 5 --yes
python -m evals.show_runs --experiment EXPERIMENT_NAME --case five-stars-only
```

- A full or holdout run fails on any gate (`grounded`, `no_forbidden`) or any
  per-provider threshold in `evals/thresholds.json`. A targeted `--case` run
  shows thresholds but only fails on gates.
- Thresholds come from `python -m evals.thresholds --confidence 0.99
  --experiment anthropic=... --experiment openai=... --write`. They assume a
  full-size run (27 cases x 3 repetitions).
- The holdout runs on request only:
  `python -m evals.sync_dataset --cases holdout` then
  `python -m evals.run_evals --cases holdout --yes`.

## CI and deploy

`.github/workflows/agent-ci.yml` runs on PRs and pushes to `main` that change
`agent/` code (not Markdown), and on manual dispatch:

1. `pytest`.
2. `container`: builds the image and checks `/health`, a 401 without a token,
   the non-root user, and the image contents.
3. `evals` (push to `main` and manual runs): syncs the dataset and runs the
   full suite on both providers. Any gate or threshold failure stops the
   pipeline.
4. `deploy` (push to `main` only): signs in to Google Cloud through Workload
   Identity Federation (no key file; only `main` can get credentials), pushes
   the image to Artifact Registry and deploys to Cloud Run, then smoke-checks
   the live URL.

The Cloud Run service runs at most one instance, reads places from Firestore
through its own service account (Firestore read-only), and gets its Anthropic
key from Secret Manager (`anthropic-api-key`). LangSmith tracing is off in
production, because runs there read real users' notes.

### Environment

| Variable | Default | Notes |
|---|---|---|
| `LLM_PROVIDER` | `anthropic` | or `openai` |
| `PLACES_STORE` | `fixture` | `firestore` in production |
| `RECOMMEND_LIMIT_PER_USER_PER_HOUR` | `20` | product choice, not a measured figure |
| `RECOMMEND_LIMIT_GLOBAL_PER_HOUR` | `200` | product choice, not a measured figure |
| `CHECK_REVOKED` | `false` | also reject revoked sessions |

### Escalation

Every answer carries `confidence` (0 to 1: how clearly the request says which
saved places would fit) and, when the service asks instead of answering, a
`clarifying_question`. The service asks when confidence is below the
provider's threshold in `src/outing_agent/confidence_thresholds.json`. A
provider missing from that file never escalates.

`POST /recommend` takes either `{"message": ...}` or
`{"clarification": {"original_message": ..., "question": ..., "answer": ...}}`,
each field up to 500 characters. A clarified request never asks again, so
there is at most one question per request.

Thresholds are picked from a full eval run with
`python -m evals.confidence_sweep --experiment anthropic=... --experiment openai=... --write`.
The rule takes the threshold that asks on the most vague requests while
asking needlessly on at most 5% of clear ones, and requires asking on at least
half of the vague ones. The 5% and the half are product choices, not measured
figures.

### Guest access and spend caps

Guests (Firebase anonymous sign-in) have full access, including
`/recommend`, so anyone can try the app without signing up. Because a new
guest uid costs nothing, the per-user limit alone doesn't cap spend. The caps
are the global hourly limit, the spend limit on the Anthropic workspace that
owns the production key, and a GCP billing budget alert.

### Rotating the Anthropic key

The production key expires on **2026-12-31**. Create a new key in the same
Anthropic workspace, then add it as a new secret version without a trailing
newline. Read it silently, one command at a time:

```bash
read -s "KEY?New Anthropic key: "; echo
printf '%s' "$KEY" | gcloud secrets versions add anthropic-api-key --data-file=-
unset KEY
gcloud run services update favorite-places-agent --region us-central1 --update-secrets ANTHROPIC_API_KEY=anthropic-api-key:latest
```

Then disable the old secret version and delete the old key in the Anthropic
console.

## Layout

```
agent/
├── src/outing_agent/
│   ├── api/          FastAPI app and routes
│   ├── graph/        LangGraph graph and state
│   ├── tools/        tools the agent can call
│   ├── providers/    Anthropic and OpenAI behind one interface
│   └── config.py     provider, models, limits, confidence thresholds file
├── tests/
├── evals/
└── docs/
```
