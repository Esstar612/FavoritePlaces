# Outing agent

A Python service that recommends outings from a user's saved Favorite Places
using tool calling. FastAPI for the API, LangGraph for the agent, LangSmith for
tracing and evals. Anthropic and OpenAI sit behind one provider interface.

Status: scaffold only. The service exposes `GET /health` and nothing else yet.
See `BUILD_LOG.md` for progress.

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

## Layout

```
agent/
├── src/outing_agent/
│   ├── api/          FastAPI app and routes
│   ├── graph/        LangGraph graph and state
│   ├── tools/        tools the agent can call
│   ├── providers/    Anthropic and OpenAI behind one interface
│   └── config.py     provider, models, seed, confidence threshold
├── tests/
├── evals/
└── docs/
```
