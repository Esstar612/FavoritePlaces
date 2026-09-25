# Build log

One dated entry per completed step, newest last. Every figure under "Numbers
measured" comes from pasted command output, with the command and file that
produced it.

Entry template:

```
## YYYY-MM-DD: Step N, short title

### What we built
### Decisions made
(alternatives considered, and why we rejected them)
### Numbers measured
(figure, command, file that produced it; or "none yet")
### Problems hit and how we solved them
### Resume claims moved forward
(1 provider-agnostic tool-calling agent, 2 FastAPI + LangGraph + LangSmith,
3 evals in CI before deploy, 4 confidence escalation + run logging)
### Case study
(one line for the Favorite Places portfolio case study, or "none")
```

---

## 2026-09-24: Step 0, setup and discovery

### What we built
- `CLAUDE.md` at the repo root with the working rules for this project.
- This build log.
- A read-only audit of the existing app (framework, saved-place storage and
  record shape, Gemini features, backend and CI).
- The `agent/` scaffold: `pyproject.toml`, `.env.example`, a config module, the
  `api`, `graph`, `tools` and `providers` subpackages, `tests/`, `evals/`,
  `docs/`, and a stub FastAPI app with only `GET /health`.
- `.gitignore` entries so `agent/.env`, the virtualenv and Python caches are
  never committed.

### Decisions made
- **Package layout:** `agent/src/outing_agent/` with `api`, `graph`, `tools`
  and `providers` inside it, rather than putting those four directly under
  `src/`. Rejected the flat version because it would install top-level
  packages named `api` and `tools`, which collide easily with other installed
  packages.
- **Build backend:** hatchling. Rejected setuptools because it needs extra
  config for a src layout; rejected Poetry and uv-specific config to keep
  `pyproject.toml` standard (PEP 621) and installable with plain pip.
- **pytest as an optional `dev` extra** instead of a runtime dependency, so a
  production image does not ship the test runner.
- **Version pins:** lower bound at the current stable release, upper bound
  below the next major (or next minor for 0.x packages), so installs are
  reproducible enough without freezing patch fixes.
- **Port 8001** for the agent, since the Express backend already uses 8080.
- **Confidence threshold left as `None`** in config, to be chosen from eval data.
- **Saved-places access: the service reads Firestore directly.** It verifies
  the caller's Firebase ID token and queries the `places` collection
  (`userId == uid`) through a places-store interface. Evals use a fixture store
  built from `DEMO_PLACES` in `backend/routes/user.js`.
  - Rejected: the app sends places in the request (the `/ai/smart-search`
    pattern). Tools would only filter a list they were handed, which is weak
    proof of tool calling, and it needs a Flutter change.
  - Rejected: Express as a gateway. It changes existing backend code, adds a
    second deploy and an extra network hop, and hides the Python service.
- **uid trust rule.** Admin SDK reads bypass `firestore.rules`, so the service
  is the only access control. Every tool's uid comes only from the verified ID
  token, never from the request body, tool arguments, or model output. Added to
  `CLAUDE.md`.
- **Credential resolution (change 1).** First non-empty option wins:
  `FIREBASE_SERVICE_ACCOUNT_JSON`, then `FIREBASE_SERVICE_ACCOUNT_PATH`, then
  Application Default Credentials. Empty strings count as unset, because
  python-dotenv 1.2.3 sets `FOO=` to `""` rather than skipping it (checked in
  its `parser.py` and `main.py`). `.env.example` leaves the JSON empty and the
  path commented out, so a fresh `.env` uses ADC.
  - A set but missing key path raises `FileNotFoundError` naming the path.
    Rejected: silently falling back to ADC, which hides a misconfiguration.
  - Relative key paths resolve against `agent/`. Rejected: the working
    directory, which breaks when commands run from the repo root.
  - Invalid JSON raises a `ValueError` naming the variable, raised `from None`
    so the key contents never reach a traceback.
- **Lazy Firebase init (change 2).** Nothing initializes Firebase at import;
  `/health`, pytest, and fixture-store evals run with no credentials. Rejected:
  import-time init, which would make all three need credentials. Added to
  `CLAUDE.md`.
- **Explicit `projectId` under ADC.** firebase-admin 7.7.0 resolves the project
  as `options['projectId']`, then the credential's project, then
  `GOOGLE_CLOUD_PROJECT`. Passing it explicitly stops a laptop's gcloud ADC
  project from winning. Omitted when empty.
- **firebase-admin 7.7.0** (current stable on PyPI) added to dependencies.
- **Model IDs, checked 2026-09-24 against provider docs.**
  - `claude-sonnet-5` confirmed current
    (https://platform.claude.com/docs/en/about-claude/models/overview).
  - `gpt-5-mini` replaced: its only snapshot shuts down 2026-12-11
    (https://developers.openai.com/api/docs/deprecations).
  - Chose `gpt-6-sol` (https://developers.openai.com/api/docs/models), which
    lists function calling and costs the same $2 / $10 per MTok as Sonnet 5, so
    cross-provider evals compare one price tier. Rejected `gpt-6-luna` and
    `gpt-5.6-terra` as cheaper tiers that would skew the comparison.

### Numbers measured
- `pytest -v` (config in `agent/pyproject.toml`, tests in `agent/tests/`):
  8 passed in 0.25s. That is 7 in `test_firebase_app.py` and 1 in
  `test_health.py`, all with no Firebase credentials configured.
- `curl http://localhost:8001/health` against
  `uvicorn outing_agent.api.app:app`: `GET /health` returned 200 OK.
- `pip install -e ".[dev]"` on Python 3.14.0 resolved every pinned version as
  chosen, plus transitive `anthropic` 1.8.0 and `openai` 3.19.2.

### Problems hit and how we solved them
- Only Python 3.14 is installed locally (no 3.11 to 3.13). The project requires
  `>=3.11`, and every dependency installed cleanly on 3.14.0, so no downgrade
  was needed.
- `uvicorn --reload` restarted dozens of times after startup. WatchFiles was
  watching `agent/.venv/`, and because the repo lives in Dropbox, files under
  `site-packages` kept registering as changed. Fixed by adding
  `--reload-dir src` so only our source is watched. Confirmed: with that flag
  uvicorn reported watching only `agent/src` and started once with no reloads.
  Rejected: dropping
  `--reload`, which loses auto-restart during development.

### Resume claims moved forward
- Claim 2 (FastAPI and LangGraph service skeleton, LangSmith env wired).
- Claim 1: provider config for Anthropic and OpenAI with verified model IDs,
  and a real data source (Firestore) for the tools to call.

### Case study
none
