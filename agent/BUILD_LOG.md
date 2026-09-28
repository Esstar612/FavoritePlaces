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

---

## 2026-09-25: Step 1, core agent (in progress)

### Part A: design (approved)

#### What we built
A design for `POST /recommend`, with no code yet. It was approved with four changes, all included below.

#### Decisions made
- **PlacesStore Protocol with one method, `list_places(uid)`.** The tools do all filtering, ID lookup, and distance math over that list, so each store enforces ownership in exactly one place. Rejected: extra methods such as `get_places(uid, ids)`, which would add a second place to get ownership right.
- **Two stores.**
  - `FirestorePlacesStore` queries the top-level `places` collection with `userId == uid`, ordered by `createdAt` descending, limited to 200.
  - `FixturePlacesStore` is a copy of `DEMO_PLACES` with fixed IDs, plus a second user so tests can catch data leaking between users. Rejected: parsing `backend/routes/user.js` at runtime, which is brittle and ties Python to JS syntax.
- **Three tools, none with a uid argument.**
  - `search_places` returns short rows with no notes.
  - `get_place_details` returns notes and summary for up to 5 IDs.
  - `plan_route` returns distances and a visiting order.
  - Because search leaves out notes and coordinates, a good answer needs more than one tool call.
- **uid delivery.** The graph is built with `context_schema`, and each tool takes `runtime: ToolRuntime[AgentContext]`.
  - Checked in the installed source (`langgraph` 1.2.12, `langchain-core` 1.6.5): injected args are left out of the model's tool schema and filtered out of tool callback inputs.
  - Rejected: `InjectedState`, because state is traced.
  - Rejected: `config["configurable"]`, because it can be copied into trace metadata.
  - Rejected: per-request closures, because tool objects would change every request.
- **Graph shape:** `agent`, then `tools`, then back to `agent`, and finally `finalize`, which produces structured output. `finalize` is where the Step 4 confidence check will plug in. Model creation sits behind `get_chat_model(provider)` for Step 2.
- **Changes from review.**
  1. **Grounding check.** Every place ID returned by any tool is recorded. After the run, recommendations are split three ways:
     - owned and retrieved: kept
     - owned but never retrieved: dropped, logged as `ungrounded_place_ids`
     - not owned: dropped, logged as `rejected_place_ids`
  2. **Request-scoped memoizing store,** so Firestore is read at most once per request, including the final check. The Protocol is unchanged.
  3. **Trace redaction in firestore mode.** Notes and summary are masked everywhere in traces. Fixture mode stays fully traced. Before showing the code, check that LangSmith's hiding hooks apply to LLM runs as well as tool runs.
  4. **200-place limit logged as a known limitation.** The store warns when a query returns exactly 200.

#### Known limitations
- `FirestorePlacesStore` reads at most 200 places per user, the same cap as `MAX_SEARCH_PLACES` in `backend/routes/ai.js`. A user with more than 200 places only gets recommendations from their 200 most recent (by `createdAt`), and a warning is logged when the cap is hit.

### Part B: store and auth

#### What we built
- `PLACES_STORE` (`fixture` or `firestore`, default `fixture`) and `CHECK_REVOKED` (default off) in `config.py` and `.env.example`
- `places/models.py`
- `places/fixtures.py`
- `places/store.py`: Protocol, `FirestorePlacesStore`, `FixturePlacesStore`, `RequestScopedPlacesStore`, `build_places_store`
- `api/auth.py`: the `get_verified_uid` dependency
- `tests/test_places_store.py`
- `tests/test_auth.py`

#### Decisions made
- **`check_revoked` defaults to off.** Turning it on means one more Firebase Auth call per request (more latency, and it needs credentials that can read users). In return it rejects revoked sessions and disabled users right away instead of when the token expires (up to 1 hour). The Express backend doesn't check revocation either. Guest accounts delete their places on sign-out, so a still-valid token for a deleted guest finds nothing. It's a config flag, so it can be turned on later.
- **Only token problems return 401.**
  - Invalid, expired, revoked, disabled, missing uid, and malformed headers all get a bare `401 Unauthorized`.
  - `CertificateFetchError` (can't reach Google's public keys) returns 503. Rejected: reporting that as 401, which would blame the user for our outage.
  - `get_firebase_app()` runs outside the error handling, so a misconfigured server shows up as a 500 instead of looking like bad tokens.
- **`RequestScopedPlacesStore` is bound to one uid** and raises if asked for a different one. That's a second guard on the trust rule. It returns copies so tools can't change cached data, and a lock keeps parallel tool calls from reading Firestore twice.
- **`FirestorePlacesStore` double-checks each document's `userId`** even though the query already filters by it. It skips malformed documents and logs a warning. Rejected: failing the whole request, which is what the app's `Place.fromFirestore` does.

#### Numbers measured
- `pytest -v` (config in `agent/pyproject.toml`, tests in `agent/tests/`): 38 passed in 1.00s.
  That is 16 in `test_auth.py`, 14 in `test_places_store.py`, 7 in `test_firebase_app.py`, and 1 in `test_health.py`.
- All of them ran with no Firebase credentials and no network: the Firestore client is mocked and `verify_id_token` is patched.

### Part C: tools, graph, endpoint

#### What we built
- `graph/state.py`: `AgentContext` (uid and store, passed as the run context), `AgentState`, and the `RecommendationSet` returned by the final step
- `tools/places_tools.py`: `search_places`, `get_place_details`, `plan_route`
- `providers/factory.py`: `get_chat_model(provider)`
- `graph/builder.py`: an agent and tools loop that ends in a structured `finalize` step
- `run.py`: `run_recommendation`, the grounding check, tool-call collection, and one structured log line per run
- `POST /recommend` in `api/app.py`
- Tests with a scripted fake chat model: `tests/fakes.py`, `tests/test_agent_run.py`, `tests/test_recommend_endpoint.py`
- `scripts/smoke.py`: one real run against the fixture store

#### Decisions made
- **Firestore-mode runs are not traced.** When `PLACES_STORE=firestore`, the agent run happens inside `langsmith.tracing_context(enabled=False)`, so real users' notes and summaries never reach LangSmith. Fixture mode stays fully traced. Redaction can be added later if firestore-mode traces are ever needed.
  - Rejected for now: masking notes and summaries with LangSmith's `anonymizer` or `hide_inputs`/`hide_outputs` hooks. That was checked in `langsmith` 0.14.0 and would work, but it needs its own leak tests and has known gaps: the model's own text can quote notes, and error strings only pass through `anonymizer`.
- **Tests never trace.** `tests/conftest.py` wraps every test in `tracing_context(enabled=False)`, which overrides `LANGSMITH_TRACING=true` from `.env`.
- **The response field is `overview`, not `summary`.** In this project "summary" only ever means a place's cached AI summary.
- **Grounding check, after each run.**
  - Place IDs count as retrieved when they appear in the `places` rows or the route `order` returned by any tool.
  - Recommendations the user owns and a tool returned are kept. Titles come from the store and order is renumbered.
  - Owned but never retrieved: `ungrounded_place_ids`. Not owned: `rejected_place_ids`.
  - Duplicate IDs are dropped.
  - Both lists go into the run result and the run log. They are left out of the HTTP response.
- **Run log.** Each run logs one JSON line with run ID, provider, model, store kind, tool calls with arguments, and the kept, ungrounded, and rejected IDs. It never includes the uid, the user's message, or place notes.
- **`/recommend` request body forbids extra fields,** so a `uid` in the body gets a 422 instead of being silently ignored.
- **Recursion limit of 12 graph steps** stops runaway tool loops.
- **The graph and store are built once, on first use,** through FastAPI dependencies. Tests override those dependencies.
- **Tests turn tracing off globally as well as per context.** `langsmith.configure(enabled=False)` covers TestClient's server thread, which doesn't inherit the test's `tracing_context`.
- **Firestore-mode reasoning isn't reviewable in LangSmith.** Because those runs aren't traced, review comes only from the run log (tool calls and grounding lists). Fixture-mode runs keep full traces, including the model's reasoning.

#### Problems hit and how we solved them
- **The first Part C test run: 52 passed, 1 failed.**
  - `test_recommend_returns_only_the_users_grounded_places` got a 422.
  - Cause: the test overrode the store dependency with the `FixturePlacesStore` class itself. FastAPI read its `places_by_uid` constructor argument as a request parameter.
  - Fixed by overriding with `lambda: FixturePlacesStore()`.
- **Pydantic serializer warnings on `context`, 2 per agent run.**
  - Cause: unsubscripted `ToolRuntime` takes `ContextT`'s default of `None` (`langgraph/prebuilt/tool_node.py:106`), so serializing the tool input expected `None` for `context`.
  - Fixed by annotating the tools with `ToolRuntime[Any]`.
  - Rejected: `ToolRuntime[AgentContext]`, which would make pydantic build a schema for the `PlacesStore` Protocol.
- **`scripts/smoke.py` failed before the first model call** with "Anthropic authentication failed: no API key". `agent/.env` had empty `ANTHROPIC_API_KEY` and `LANGSMITH_API_KEY`, and LangSmith also returned 401 for the trace upload. The keys need to be filled in.

#### Numbers measured
- `pytest -v` (config in `agent/pyproject.toml`, tests in `agent/tests/`): **53 passed in 0.75s** with no warnings. That is 10 in `test_agent_run.py`, 5 in `test_recommend_endpoint.py`, and the 38 from Parts A and B.
- `python scripts/smoke.py` (`agent/scripts/smoke.py`): one real run against the fixture store as `demo-user`, with default message "Plan me a relaxed Saturday morning: good coffee, then somewhere to walk." This is a single run, not a benchmark.
  - Provider `anthropic`, model `claude-sonnet-5`, run ID `14f54c62-354d-4acd-afe4-f86257f8dbd2`
  - Elapsed: 12.98 s
  - Tokens: 7,934 input, 963 output, 8,897 total. Of the output, 18 were reasoning tokens. No cache reads or writes.
  - 4 tool calls, in this order:
    - `search_places` (cafe, min_rating 4)
    - `search_places` (park, min_rating 4)
    - `get_place_details` (both picks)
    - `plan_route` (both picks)
  - 2 recommendations: Blue Bottle Coffee, then Golden Gate Park
  - 0 ungrounded, 0 rejected
  - Trace recorded in LangSmith project `favorite-places-outing-agent`
- The structured-output `finalize` step worked with `claude-sonnet-5`.
- **Trace check for smoke run `14f54c62-354d-4acd-afe4-f86257f8dbd2`, done in the LangSmith UI:** `demo-user` and `uid` appear nowhere in the root LangGraph run, the first `search_places` tool run, the first `ChatAnthropic` run, or the `finalize` run. That covers inputs, outputs, and metadata.
  - Tool run inputs show only the model's arguments (`category`, `min_rating`), with no injected runtime.
  - Run metadata holds only `provider`, `model`, `places_store`, `revision_id`, and LangGraph and SDK runtime fields.

#### Observations for Step 3 evals
- The answer called `plan_route`'s straight-line distance "a short 8.6km drive". The tool gives a straight line, not a road distance.
- The Golden Gate Park note says "Go on a weekday, weekends are packed". The request was for a Saturday, and the answer only said to arrive before the crowds. It didn't mention that the user's own note advises a weekday.
- Both are candidates for an answer-faithfulness scorer.

#### Resume claims moved forward
- **Claim 1:** a tool-calling agent that recommends outings from saved places, working end to end with Anthropic. The OpenAI side of the provider interface comes in Step 2.
- **Claim 2:** a FastAPI and LangGraph service, with fixture-mode runs traced in LangSmith. Evals in LangSmith come in Step 3.
- **Claim 4 (partly):** every run logs its tool calls and grounding lists, and fixture-mode traces include the model's reasoning. Confidence escalation comes in Step 4.

#### Case study
One line: "The agent reads only the signed-in user's places. The uid comes from the verified token through LangGraph runtime context and never reaches the model or traces, and every recommendation is checked against what the tools actually returned."

---

## 2026-09-25: Step 2, OpenAI behind the same provider interface

### What we built
- An OpenAI branch in `providers/factory.py`. `get_chat_model(provider)` returns `ChatAnthropic` or `ChatOpenAI` with the same token budget, timeout, and retries. The graph and tools are unchanged.
- `LLM_PROVIDER` in `config.py` and `.env.example` (default `anthropic`, checked against `MODELS`), replacing the fixed `DEFAULT_PROVIDER`. `MAX_OUTPUT_TOKENS = 4096` and `REQUEST_TIMEOUT_S = 60` are shared by both providers.
- `--provider` flag on `scripts/smoke.py`.
- `tests/test_providers.py`. These run offline with dummy keys and check each provider's model settings, rejection of an unknown provider, and that the graph compiles with each real provider model.

### Decisions made
- **`finalize` uses `with_structured_output(..., method="function_calling")` for both providers.**
  - In `langchain-openai` 1.6.6, `ChatOpenAI` defaults to `"json_schema"` (`chat_models/base.py:3862`), while `ChatAnthropic` defaults to `"function_calling"`.
  - Being explicit makes both behave the same way, and avoids OpenAI strict-schema rules on the optional `suggested_time`. That rule is not yet confirmed to fail here.
- **The output budget went from 2048 to 4096 tokens for both providers.** `gpt-6-sol` is a reasoning model, and its reasoning tokens count against `max_completion_tokens`. The same budget on both keeps the comparison fair.
- **No flag forces the Responses API.** `langchain-openai` 1.6.6 switches to it automatically for `gpt-6*` models when tools are bound (`chat_models/base.py:2010-2013`).
- **The provider is set per deployment through `LLM_PROVIDER`, not per request.** Step 3 evals call `get_chat_model` directly for each provider.

### Numbers measured
- `pytest -v` (config in `agent/pyproject.toml`, tests in `agent/tests/`): **59 passed in 2.07s**. That is the 53 from Step 1 plus 6 in `test_providers.py`.
- `python scripts/smoke.py --provider openai` (`agent/scripts/smoke.py`): one real run against the fixture store as `demo-user`, using the same default message as the Step 1 run. This is a single run, not a benchmark, so it isn't a fair comparison with the Anthropic run.
  - Provider `openai`, model `gpt-6-sol`, run ID `7fd4a5dd-a1ec-4410-b576-bb8a0487cc53`
  - Elapsed: 23.72 s
  - Tokens: 5,817 input (reported as 3,199 cache creation and 1,240 cache read), 658 output including 136 reasoning, 6,475 total
  - 5 tool calls:
    - `search_places` "coffee"
    - `search_places` "walk"
    - `get_place_details` (both picks)
    - `plan_route` (both picks)
    - `search_places` with no filters and limit 20
  - 2 recommendations: Blue Bottle Coffee, then Golden Gate Park
  - 0 ungrounded, 0 rejected
  - Trace recorded in LangSmith
- The same graph, tools, and `finalize` step worked unchanged with `gpt-6-sol`.

### Observations for Step 3 evals
- OpenAI sends every optional tool argument explicitly as `null`, and uses `limit: 12`. The tools handle both.
- The last call listed every saved place with no filters. The rows still leave out notes, but a tool-use scorer could flag unfiltered searches.
- Unlike the Step 1 Anthropic run, this answer passed on the "weekends are packed" note, and called 8.63 km the route tool's distance rather than a drive.

### Problems hit and how we solved them
None. Both the tests and the OpenAI smoke run passed on the first try.

### Resume claims moved forward
- **Claim 1:** complete. One provider interface (`get_chat_model`) runs the same tool-calling agent on Anthropic (`claude-sonnet-5`) and OpenAI (`gpt-6-sol`), next to the app's existing Gemini features.

### Case study
"The same LangGraph agent and tools run on Claude or GPT by changing one setting. The provider sits behind a single factory, and structured output is pinned to function calling so both return the same answer format."

---

## 2026-09-25: Step 3, evaluation suite gated in CI before deploy (in progress)

### Part A: design (approved)

#### Decisions made
- **Dataset.**
  - `evals/cases.json` holds 18 cases over the fixture store and is the source of truth.
  - `evals/sync_dataset.py` upserts the cases into the LangSmith dataset `outing-agent-v1`, keyed by case ID, and deletes cases that were removed.
  - Case types: single stop, multi-stop, constraints (favorites only, 5 stars only), nothing fits, a request for an unsaved place, cross-user, and one vague request tagged for Step 4.
- **Deterministic scorers first:**
  - `grounded`
  - `no_forbidden`
  - `expected_recall`
  - `details_before_recommending`
  - `route_when_multi_stop`
  - `required_tools_used`
  - `empty_when_nothing_fits`
  - `tool_call_budget`

  A scorer that doesn't apply to a case returns no score, so it doesn't inflate the mean. `no_forbidden` also counts picks the grounding check dropped, so it measures what the model chose, not what the user saw.
- **Gates.** `grounded` and `no_forbidden` must be 1.0 from the start. The other scorers are report-only until baselines exist.
- **Baselines come from at least 3 repetitions per provider,** because a single run of a model is noisy. `run_evals.py` defaults to 3 repetitions.
- **Cost guard.** Before any paid run, `run_evals.py` prints the planned number of agent runs (cases times repetitions times providers) and only proceeds with `--yes`.
- **CI** (`.github/workflows/agent-ci.yml`, to be added):
  - pytest runs on every push and pull request that touches `agent/`
  - paid evals run only on pushes to `main` and on manual dispatch
  - the Cloud Run deploy runs only after tests and evals pass on `main`
- **Google Cloud access from CI uses Workload Identity Federation.** GitHub's OIDC token is exchanged for short-lived credentials, so no service account key is stored as a secret. Rejected: a key JSON in GitHub secrets. It's a long-lived credential and the same risk that was avoided in the service with Application Default Credentials.
- **Cloud Run: max instances 1.** `/recommend` calls paid models, so capping scale caps spend from abuse.
- **Next planned addition: an LLM-judge `note_faithfulness` scorer,** added after the deterministic baseline. It's the only scorer that would catch an answer ignoring a note, like the Step 1 run missing "go on a weekday". Consider Gemini as the judge model, a third model the app already uses, so neither Claude nor GPT grades its own answers.

#### Action items
- Set a billing budget alert in the GCP project before the first deploy, since the deployed `/recommend` calls paid model APIs.

### Part B: dataset, scorers, runner

#### What we built
- `evals/cases.json` (18 cases) and `evals/dataset.py`, which loads the cases, checks their IDs are unique, and splits each one into inputs and reference outputs
- `evals/sync_dataset.py`
- `evals/scorers.py`, with the 8 scorers and `GATES`
- `evals/run_evals.py`, with the dry-run estimate, `--yes`, 3 repetitions by default, one experiment per provider, and a nonzero exit when a gate fails
- `tests/test_scorers.py`, with a unit test per scorer and consistency checks between the cases and the fixture data

#### Numbers measured
- `pytest -v`: **88 passed in 1.66s**. That is the 59 from before plus 29 in `tests/test_scorers.py`.
- `python -m evals.sync_dataset`: `outing-agent-v1: 18 cases (18 created, 0 updated, 0 deleted)`.
- `python -m evals.run_evals` (dry run): planned 18 cases x 3 repetitions x 2 providers = 108 agent runs. No model calls were made.
- **Baseline eval:** `python -m evals.run_evals --yes` (`agent/evals/run_evals.py`) ran 18 cases x 3 repetitions per provider on dataset `outing-agent-v1`. All gates passed.

  | Scorer | anthropic `claude-sonnet-5` (exp. `outing-agent-anthropic-e2bd63cf`) | openai `gpt-6-sol` (exp. `outing-agent-openai-dda3efab`) |
  |---|---|---|
  | grounded (gate 1.0) | 1.000 (n=54) | 1.000 (n=54) |
  | no_forbidden (gate 1.0) | 1.000 (n=54) | 1.000 (n=54) |
  | expected_recall | 0.972 (n=36) | 0.972 (n=36) |
  | details_before_recommending | 0.952 (n=42) | 1.000 (n=41) |
  | required_tools_used | 0.979 (n=48) | 1.000 (n=48) |
  | empty_when_nothing_fits | 0.917 (n=12) | 1.000 (n=12) |
  | route_when_multi_stop | 0.708 (n=24) | 0.850 (n=20) |
  | tool_call_budget | 1.000 (n=54) | 0.944 (n=54) |

  The n values are scored runs. Scorers that don't apply to a case are excluded, so n differs between scorers and, for scorers that depend on how many places were recommended, between providers.

#### Observations
- Neither provider recommended an unsaved or forbidden place in any of the 108 runs.
- Anthropic skipped `plan_route` in about 3 of 10 multi-stop answers (0.708), and once recommended something when nothing should fit (0.917).
- OpenAI went over the 6-tool-call budget in about 1 of 18 runs (0.944), which matches the extra unfiltered search seen in the Step 2 smoke run.
- Model cost for the baseline wasn't captured by the runner. The provider billing dashboards are the source for it.

### Part C: scorer fixes and day-plan coverage (second baseline pending)

#### What we built
- `route_when_multi_stop` now scores only cases with `expects_route: true`.
- `expected_recall` respects a new `requested_stop_count` field. The "Two stops, but only places I rated 5 stars" case now expects all three 5-star places (Blue Bottle, Tartine, Alcatraz) with `requested_stop_count: 2`, so any two of them score 1.0.
- Two new report-only scorers:
  - `covers_request`: every requested stop type appears among the recommendations, counting repeats, so two cafes are needed when two are asked for.
  - `respects_sequence`: when the user states an order, the recommended categories follow it as a subsequence of the visiting order.
- Case fields `requested_sequence` (place categories in the requested order) and `sequence_ordered`. The three existing demo day plans got sequences.
- Recommendations now carry the place's `category`, filled from the store the same way `title` is. It also appears in the `/recommend` response.
- A third fixture user, `planner-user`, with 10 places at approximate real San Francisco locations:
  - cafe x2, museum, restaurant x2, park x2, shopping x2, bar
  - all categories checked against `PlaceCategory` in `mobile/lib/models/place.dart`
  - `demo-user` stays an exact copy of the app's guest seed
- 7 new day-plan cases for `planner-user` in `evals/cases.json`, 25 cases in total. One of them, "coffee, then a movie, then dinner", includes a stop that can't be satisfied, because no movie theater is saved.
- 3 held-out day-plan cases in `evals/cases_holdout.json`. They sync to the separate dataset `outing-agent-holdout-v1` and run only on request with `--cases holdout`. They are not part of the CI gate.

#### Decisions made
- **Multi-stop day planning is the core use case.** In the first baseline's day-plan cases, `plan_route` was called in 15 of 15 OpenAI runs and 14 of 15 Claude runs.
- **Route scorer bug.** The first version scored every run that recommended 2 or more places. On cases that don't expect a route, those runs were offering alternatives, which correctly needs no route. So every zero on non-route cases was a false miss, and the fix scores only `expects_route` cases.
- **`planner-user` is a new fixture user rather than extra places for `demo-user`.** `demo-user` has one place per category and can't express plans like "coffee, then a cafe to work in". Adding places to it would have changed the expected answers of the existing cases.
- **CI gates stay `grounded` and `no_forbidden` at 1.0** until the second baseline.
- **Thresholds for the other scorers will come from the second baseline.** Each is the lower bound of a 90% bootstrap interval over each provider's cases, resampling whole cases with all their repetitions, rounded down to 0.05. If an interval collapses because every case is perfect, the threshold is the smaller of that lower bound and the mean minus 0.10, flagged. `grounded` and `no_forbidden` are excluded from the bootstrap and stay at 1.0. CI runs the same number of repetitions as the baseline.

#### Real misses in the first baseline
- Claude, 5-star case, repetition 3: only `search_places`, with no details and no route.
- Claude, "Where can I get good coffee?" as `other-user`, repetition 2: recommended a bookstore and a park instead of nothing.
- OpenAI, breakfast pastry, repetition 1: read Tartine's details, then recommended nothing.
- OpenAI: 3 runs over the tool budget, each from 5 or 6 consecutive searches.

#### Observations
- First baseline cost, from the provider dashboards: Claude $1.42 and 512k tokens, OpenAI $0.65 and 237k tokens, over 54 runs each. Both providers have the same per-token price, so the difference comes from Claude using about twice the tokens.

#### Numbers measured
- `pytest -v`: **130 passed in 2.01s**.
- `python -m evals.sync_dataset`: `outing-agent-v1: 25 cases (7 created, 18 updated, 0 deleted)`.
- `python -m evals.sync_dataset --cases holdout`: `outing-agent-holdout-v1: 3 cases (3 created, 0 updated, 0 deleted)`.
- `python -m evals.run_evals` (dry run): planned 25 cases x 3 repetitions x 2 providers = 150 agent runs.
- **Second baseline, first attempt:** stopped early. Some Anthropic runs in experiment `outing-agent-main-anthropic-19412122` failed with `GraphRecursionError: Recursion limit of 12 reached`. Those results aren't used.

- `pytest -v` after the fix: **132 passed in 1.94s**.
- **Second baseline:** `python -m evals.run_evals --yes` ran 25 cases x 3 repetitions per provider on `outing-agent-v1`. All gates passed.

  | Scorer | anthropic `claude-sonnet-5` (exp. `outing-agent-main-anthropic-05731736`) | openai `gpt-6-sol` (exp. `outing-agent-main-openai-26bcf3c3`) |
  |---|---|---|
  | grounded (gate 1.0) | 1.000 (n=75) | 1.000 (n=75) |
  | no_forbidden (gate 1.0) | 1.000 (n=75) | 1.000 (n=75) |
  | covers_request | 1.000 (n=30) | 1.000 (n=30) |
  | respects_sequence | 1.000 (n=27) | 1.000 (n=27) |
  | route_when_multi_stop | 0.972 (n=36) | 1.000 (n=36) |
  | expected_recall | 0.954 (n=54) | 0.981 (n=54) |
  | details_before_recommending | 0.952 (n=63) | 1.000 (n=62) |
  | required_tools_used | 0.986 (n=69) | 1.000 (n=69) |
  | empty_when_nothing_fits | 0.917 (n=12) | 1.000 (n=12) |
  | tool_call_budget | 0.827 (n=75) | 0.840 (n=75) |

- After the route scorer fix, `route_when_multi_stop` went from 0.708 to 0.972 for Anthropic and from 0.850 to 1.000 for OpenAI.
- Both providers covered every requested stop type and kept the stated order in every day-plan run.
- `tool_call_budget` is the weakest scorer for both providers: about 1 in 6 runs is over budget.

#### Problems hit and how we solved them
- **Day plans hit LangGraph's recursion limit.**
  - Each tool round takes two graph steps (agent, then tools), plus one step for `finalize`, so a limit of 12 allowed about 5 tool rounds.
  - 3 and 4-stop day plans need more rounds, especially when the model makes one search per round.
  - A crashed run returns nothing, so it fails the `grounded` gate. In production `/recommend` would return a 500 for the core use case.
  - Fix:
    - Graph state now includes LangGraph's `RemainingSteps`, and the agent routes to `finalize` once 3 or fewer steps remain, so a run always ends with an answer.
    - `finalize` drops a trailing model turn whose tool calls never got results, because both provider APIs reject a conversation that ends on unanswered tool calls.
    - The recursion limit went from 12 to 20.
    - Tool calls with no result are left out of the run's `tool_calls`.
  - Test: a fake model that requests a tool on every turn still finishes with a recommendation.
- **The tool-call budget was too tight for day plans.** Four stops need about 4 searches, 1 details call, and 1 route. `tool_call_budget` is now 3 plus the number of requested stops for day-plan cases, and stays 6 for other cases.

#### Threshold work in progress
- `evals/thresholds.py`, first pass at a 90% interval, rescoring the second-baseline experiments (`outing-agent-main-anthropic-05731736`, `outing-agent-main-openai-26bcf3c3`):
  - 9 of 16 rows collapsed to 0.90 because every run scored 1.0. That covers both day-plan scorers for Anthropic, and every OpenAI row except `expected_recall` and `tool_call_budget`.
  - The bootstrap lower bounds were:
    - Anthropic: `details_before_recommending` 0.90, `empty_when_nothing_fits` 0.80, `expected_recall` 0.85, `required_tools_used` 0.95, `route_when_multi_stop` 0.90, `tool_call_budget` 0.70
    - OpenAI: `expected_recall` 0.90, `tool_call_budget` 0.70
  - Not adopted: each bootstrapped row fails about 5% of the time with no regression, and with 8 such checks too many deploys would be blocked by noise. Next pass uses a 99% interval for the bootstrapped rows (`--confidence 0.99`) and keeps the collapsed-interval rule.
- The threshold and inspection scripts now rescore experiment outputs locally with the current `evals/scorers.py` (`evals/experiments.py`) instead of reading stored LangSmith feedback. A scorer change can then be checked against existing runs without paying for a rerun.
- `tool_call_budget` misses are being reviewed with `evals/inspect_budget.py` before the budget is finalized.

- **`tool_call_budget` misses, from `evals/inspect_budget.py` on the second baseline:** 23 of 25 misses were day-plan cases, including all 12 of OpenAI's.
  - **Main cause:** `plan_route` always visited stops nearest-first from the first ID, which conflicted with sequences users stated.
  - **How the models compensated:** both called `plan_route` once per leg to get distances in the user's order. Claude also made a full route call on top. For a 4-stop plan that meant up to 4 route calls.
  - **Other causes:**
    - searching several ways to confirm a requested stop can't be satisfied (the movie case)
    - some genuinely wasted searches, such as duplicate searches and cafe searches nobody asked for
- **Fix: `plan_route` keeps the given order by default.**
  - A new `optimize` flag gives nearest-first ordering for when the user leaves the order open.
  - The result reports `optimized`.
  - The tool description says one call returns every leg.
  - The system prompt adds: call `plan_route` once with the stops in the user's order, set `optimize` only when the order is open, never call it per leg, and present the stops in the order it returns.
  - Rejected: a `keep_order` flag that defaults to off, because a model that forgets it breaks the stated order silently.
- **Truncation is now reported.** `plan_route` and `get_place_details` return IDs beyond their 5-ID limit as `truncated` instead of dropping them silently.
- **`evening-coffee-movie-dinner` now has `requested_stop_count: 3`,** because the user asked for three stops and one can't be satisfied. The case-validity test allows a stop count with no expected places, as long as it's at least the length of `requested_sequence`.
- **The tool-call budget formula is held** until a baseline with the fixed tool. Candidates to compare from that baseline: flat 6, 2 + 2 per stop, 2 + 1 per stop.
- **The next baseline measures the tool fix and the system prompt change together.** Any change in results can't be put down to either one alone.

- **LangSmith trace limit hit during the third baseline attempt.**
  - The upload failed with `429 ... Monthly unique traces usage limit exceeded` on the free Developer plan (5,000 traces a month, then pay-as-you-go). That run's results are incomplete and aren't used.
  - The granular usage page showed 3,608 traces in the last 30 days, from roughly 400 agent runs.
  - **Cause:** `evaluate()` traces every scorer call as its own trace in a separate `evaluators` project by default (`langsmith` 0.14.0, `evaluation/_runner.py:1712-1721`). A 150-run baseline with 10 scorers made about 1,650 traces instead of about 150.
  - **Fix:** `run_evals.py` passes `disable_evaluator_tracing=True` (`_runner.py:111`, `1967-1968`). Scores are still uploaded to each experiment as feedback. `inspect_budget.py` and `thresholds.py` read the agent runs and re-score them locally, so they're unaffected.
  - **Account change:** a card was added to lift the hard cap, with a $10 a month spend limit on traces and Base (14-day) retention. LangSmith links in this log stop working after 14 days, and the figures recorded here are the lasting record.
  - **Revisit when the Gemini judge is added,** since its model calls may be worth tracing.

- **Third baseline, with the `plan_route` fix, the system prompt change, and scorer tracing off:**
  - `pytest -v` gave 135 passed in 1.69s.
  - `python -m evals.sync_dataset` reported `0 created, 25 updated, 0 deleted`. Only 1 case changed, so the sync's equality check is treating unchanged examples as different. To investigate.
  - `python -m evals.run_evals --yes` passed all gates.

  | Scorer | anthropic (exp. `outing-agent-main-anthropic-30cc7ee6`) | vs 2nd baseline | openai (exp. `outing-agent-main-openai-9ebfd8a2`) | vs 2nd baseline |
  |---|---|---|---|---|
  | grounded (gate) | 1.000 (n=75) | = | 1.000 (n=75) | = |
  | no_forbidden (gate) | 1.000 (n=75) | = | 1.000 (n=75) | = |
  | covers_request | 1.000 (n=30) | = | 1.000 (n=30) | = |
  | respects_sequence | 1.000 (n=27) | = | 1.000 (n=27) | = |
  | tool_call_budget | 0.973 (n=75) | up from 0.827 | 0.907 (n=75) | up from 0.840 |
  | route_when_multi_stop | 0.833 (n=36) | down from 0.972 | 1.000 (n=36) | = |
  | details_before_recommending | 0.855 (n=62) | down from 0.952 | 1.000 (n=63) | = |
  | required_tools_used | 0.899 (n=69) | down from 0.986 | 1.000 (n=69) | = |
  | expected_recall | 0.926 (n=54) | down from 0.954 | 1.000 (n=54) | up from 0.981 |
  | empty_when_nothing_fits | 0.917 (n=12) | = | 1.000 (n=12) | = |

  - Tool-call budget misses fell for both providers.
  - Claude now skips `get_place_details` and `plan_route` more often. The tool fix and the prompt change were measured together, so this can't be put down to either one alone.
  - Per-case detail comes next, from `evals/inspect_budget.py`.

- **`evals/inspect_budget.py` on the third baseline:**
  - **The per-leg workaround is gone.** Every route case made exactly one `plan_route` call per run, except one Claude run of `saturday-coffee-work-park`, which made 2.
  - **Claude made no `plan_route` call at all** in any run of `evening-coffee-movie-dinner` or `five-stars-only`. That accounts for its 6 route misses (30/36 = 0.833). In `five-stars-only` it made only 1 tool call per run.
  - **Budget candidates, share of runs within budget:**

    | Candidate | anthropic | openai |
    |---|---|---|
    | flat 6 | 0.947 | 0.920 |
    | 2 + 2 per stop | 0.987 | 0.947 |
    | 2 + 1 per stop | 0.920 | 0.840 |
    | current, 3 + stops | 0.973 | 0.907 |

  - **Runs still over budget under 2 + 2 per stop:**
    - Claude: `saturday-market-then-lunch` run 1 (7 calls)
    - OpenAI: `art-then-food` run 1 (7 calls), `evening-coffee-movie-dinner` runs 1 and 3 (9 calls each), `saturday-market-then-lunch` run 3 (7 calls)

    All of these were repeated or unrequested searches, for example searching cinema, theater, and film one after another, or looking for cafes in a lunch request.

- **2026-09-26: Claude answered two cases from search rows alone.**
  - In the third baseline, Claude's 6 runs of `five-stars-only` and `evening-coffee-movie-dinner` never called `get_place_details` or `plan_route`. Its reasons cited only ratings, tags and the favourite flag, never the notes. In the movie case it did correctly say no theater was saved.
  - **Grounding caveat:** `grounded` counts IDs returned by any tool, including `search_places` rows. A green `grounded` means nothing was invented or taken from another user, not that details were read. `details_before_recommending` covers that.
  - **Prompt change:** the system prompt now says that search results are only a shortlist, that every recommended place must be read with `get_place_details`, and that the reason comes from its notes and summary. It also says to call `plan_route` once whenever two or more stops are recommended, even if a requested stop could not be found.
  - **Design decision: recommendations come only from the user's own data.** A place with no notes or summary is described by its rating, tags and category, with a plain statement that there are no notes for it, never with details from general knowledge. The system prompt says this.
  - **Targeted check before any new baseline:** `run_evals.py` gained a repeatable `--case` option, and targeted experiments are prefixed `-targeted`. A targeted run is a check, not a baseline, so its numbers never set thresholds. The run: Claude only, those 2 cases, 5 repetitions, 10 agent runs.
  - **Pass bar, fixed before running.** All 10 runs must meet all three conditions below, and anything less, including 8 or 9 of 10, fails:
    1. `details_before_recommending` is 1.0 in every run.
    2. `plan_route` is called exactly once per run, counted from the `show_runs` tool-call lists.
    3. Every reason uses the place's saved record, checked by reading the `show_runs` output, which prints each place's notes and summary next to its reason:
       - For a place with notes or a summary, the reason includes at least one specific fact from them. Paraphrase is fine. A reason citing only rating, tags or favourite status fails.
       - For a place with no notes and no summary, the reason says there are no notes and contains no detail that isn't in the place's record.
  - **If it fails:** a graph step that fetches details for any recommended place not yet read before `finalize`, not stricter grounding, which would turn weak answers into empty ones.
  - **`sparse-user` fixture added for the next full baseline.** It has 4 places. Coit Tower and Boba Guys are well-known real places with empty notes and no summary, so there's a real pull toward general knowledge. House of Prime Rib and Palace of Fine Arts have notes. `planner-user` is unchanged.
    - Two cases were added: `sparse-view-single-stop` (Coit Tower) and `sparse-boba-then-dinner` (Boba Guys, then House of Prime Rib, with a route). The main set is now 27 cases.
    - The dataset must be synced before the next full baseline.
  - **Targeted result: fail, 6 of 10 runs met the bar.** Experiment `outing-agent-main-targeted-anthropic-4e3a9203`. Summary from `run_evals`: `details_before_recommending` 0.700, `route_when_multi_stop` 0.600, `required_tools_used` 0.600 (n=10 each), gates passed.
    - `evening-coffee-movie-dinner`: 5 of 5 passed. Every run read details for all four candidates, called `plan_route` once, and gave reasons from the notes ("grab and go", "dorado style"). All 5 said no theater was saved.
    - `five-stars-only`: 1 of 5 passed (run 5). Runs 1 to 3 called only `search_places(min_rating=5)` and gave reasons from ratings and tags alone, the same failure as the baseline. Run 4 read details and used the notes but skipped `plan_route`.
    - When Claude read the details, the reasons used the notes in every run. The failure is skipping the tools, not ignoring what they return. The prompt worked on the case whose searches did not already return a clear shortlist, and mostly failed on the case where `min_rating=5` did.
    - One overview (`five-stars-only` run 5) placed Tartine "in the Mission", which is not in its record. Condition 3 covers reasons only, so this did not fail the run. It is a case for the planned note-faithfulness judge.
    - `show_runs` now rejects unknown case IDs. A typo in `--case` had printed nothing.
    - **Next:** the fallback graph step, widened to also call `plan_route` when two or more stops are recommended without one, since 4 of the 5 `five-stars-only` runs skipped it.
- **2026-09-26: a fallback step reads details and plans the route before the final answer.**
  - **Design:** after `finalize`, a `fallback` node runs when the draft recommends a place the model retrieved but never read, or is an itinerary of two or more stops with no route.
    - It calls the tool functions directly in Python, since the tools only read `runtime.context`. No assistant tool-call turn is inserted, so neither provider sees unusual message ordering.
    - It then runs `finalize` once more, with the draft answer and the tool results in one added user message.
    - It goes straight to `END`, so it runs at most once per request.
    - Places the model never retrieved are not read on its behalf. Grounding still drops them.
  - **The rewrite may drop places but not add them.** Added places are removed and recorded in `fallback_removed_place_ids`. An empty rewrite is accepted. A non-empty rewrite made only of new places reverts to the draft.
  - **`kind` on the answer:** `itinerary` or `options`. Only itineraries are routed. Options are never routed or reordered. The system prompt now says not to call `plan_route` for alternatives, and the finalize prompt says how to set `kind`.
  - **Step budget:** the finalize reserve went from 3 to 4 and `RECURSION_LIMIT` from 20 to 21, so the agent keeps 17 steps.
  - **Measuring the model separately from the guardrail:**
    - Every tool call carries `source`, either `model` or `graph`.
    - `details_before_recommending`, `route_when_multi_stop`, `required_tools_used` and `tool_call_budget` count only model calls.
    - When the fallback ran, `details_before_recommending` scores the draft's grounded picks (`draft_grounded_place_ids`), so an invented ID is treated the same whether or not the fallback fired.
    - `no_forbidden` also counts the raw draft (`draft_place_ids`) and `fallback_removed_place_ids`, so it keeps measuring what the model chose.
    - `fallback_rate` (1 if the fallback ran) is report-only. It is excluded from thresholds, since higher is worse.
    - Outputs from older baselines, which have no `source` or draft fields, score as before.
  - **Pass bar for the targeted rerun, fixed before running.** Same 10 runs. All 10 must meet all four:
    - (a) every place in the final answer was read, from either source
    - (b) `plan_route` called exactly once, from either source
    - (c) every reason uses the saved notes, as defined for condition 3 above
    - (d) no run errors
  - **What the rerun can and can't show:**
    - (a) and (b) are now guaranteed by the graph, so the real test is (c) and (d).
    - The model's own tool use is measured by the separately reported model-only details and route scores and `fallback_rate`.
    - One limit on (b): the fallback routes only answers the model marks `itinerary`. A two-stop plan marked `options` gets no route, and (b) would catch it.
    - **Confound:** the rerun measures the system prompt's route change and the fallback together. The model-only route and details numbers can't be put down to either one alone.
  - **Cost:** the fallback's extra model calls are measured with `evals/fallback_cost.py` after the next baseline. No estimate is recorded before then.
  - **Targeted rerun result: fail, 7 of 10 runs met the bar.** Experiment `outing-agent-main-targeted-anthropic-cea5336d`. `pytest`: 154 passed.
    - (a) every place read: 10 of 10. (c) reasons use the notes: 10 of 10. (d) no errors: 10 of 10.
    - (b) one `plan_route` call: 7 of 10. All 3 failures are the predicted gap: the model marked a multi-stop answer `options`, so the fallback did not route it.
      - `five-stars-only` run 1: two places marked options, though the request was "Two stops".
      - `five-stars-only` run 4: three places marked options, for a two-stop request.
      - `evening-coffee-movie-dinner` run 1: coffee plus a choice of two dinners, marked options.
    - Fallback use: 5 of 10 runs (`five-stars-only` runs 1, 3 and 4; `evening-coffee-movie-dinner` runs 2 and 3). It removed no places.
    - Model-only numbers, from the `run_evals` summary: `details_before_recommending` 0.700, `route_when_multi_stop` 0.400, `required_tools_used` 0.400, `fallback_rate` 0.500 (n=10 each). Gates passed.
    - The model's own `plan_route` calls fell from 6 of 10 in the previous targeted run to 4 of 10. In the evening case they fell from 5 of 5 to 2 of 5. This run also added the system prompt sentence telling the model not to route alternatives, so the drop can't be put down to either change alone, and 10 runs can't separate it from noise.
    - **Reasons that passed (c) but distort the notes:** Zuni's notes say "Best as a long, slow lunch", and runs 1 and 4 of the evening case present it as a long, slow dinner. Evening run 1 gives "opens at 7am" as a reason for an evening coffee. Both are cases for the planned note-faithfulness judge.
- **2026-09-26: clearer rules for `kind`, from the prompts only.**
  - **Finding:** the fallback worked, and every failure in the rerun came from the model labelling a plan `options`. That label comes from prompt wording, so only text the model reads was changed.
  - **Finalize prompt:**
    - `itinerary` when the user asks for a number of stops, a sequence (first, then, after), or a plan for a day or part of one.
    - `options` only when the user asks for ideas or asks to choose between places.
    - `options` when the request matches neither rule.
    - When the user asks for a number of stops, recommend exactly that many, or fewer if not enough saved places fit.
  - **The `kind` field description** in `state.py` now states the same rules, since the structured-output schema shows it to the model.
  - **System prompt:** removed the sentence telling the model not to route alternatives. The fallback already never routes options, and the sentence arrived with the drop in the model's own route calls.
  - **Deferred: two choices for one stop.** An itinerary stop offering two equally good places is a reasonable product idea, but it isn't what failed.
    - It would change the answer schema, stop numbering, grounding, the fallback's routing and three scorers.
    - No current case has a genuine tie to test it.
    - It gives the model a way to hedge by adding places.
    - It may fit Step 4, where a tie is a natural moment for a clarifying question.
  - **Confound:** compared with the last run, three things changed at once: the system prompt, the finalize prompt and the `kind` field description. Any change in the model-only route numbers can't be put down to any one of them.
  - `show_runs` now prints each place's category, so repeated stop types are judged from categories, not titles.
  - **Pass bar, fixed before running.** The run is Claude only, with 4 cases x 5 repetitions = 20 agent runs.
    - **Judged:** the 10 runs of `five-stars-only` and `evening-coffee-movie-dinner`. All 10 must meet all of these:
      - (a) every place in the final answer was read
      - (b) `plan_route` called exactly once
      - (c) every reason uses the saved notes
      - (d) no run errors
      - (e) `kind` is `itinerary`
      - (f) no more stops than requested: 2 and 3 respectively
      - (g) no repeated stop category, since neither request asks for one
    - **Report-only:** the 10 runs of `rainy-afternoon-indoors` and `memorable-evening`, both single-stop requests. They show each run's `kind` and whether the fallback ran, to check the new rules don't turn ordinary requests into itineraries.
    - The model-only details and route numbers for each judged case are counted by hand from the `show_runs` tool-call lists, using only calls without the `[graph]` marker. The `run_evals` summary averages over all 4 cases.
    - **If `kind` fails again:** stop tuning prompts. The next option is deciding from the request, not the model's label, whether a multi-place answer gets routed.
  - **Targeted result: pass, 10 of 10 judged runs met (a) to (g).** Experiment `outing-agent-main-targeted-anthropic-3932be60`. `pytest`: 154 passed.
    - Every judged run was an `itinerary` of 2 stops with no repeated category, read every recommended place, called `plan_route` once, and gave reasons from the notes.
    - **Model-only counts** (hand-counted from `show_runs`, calls without `[graph]`):

      | Case | Model read every pick | Model called `plan_route` |
      |---|---|---|
      | `five-stars-only` | 1 of 5 | 1 of 5 |
      | `evening-coffee-movie-dinner` | 5 of 5 | 4 of 5 |

    - Fallback use: 5 of 20 runs. It ran in `five-stars-only` runs 1, 3, 4 and 5, and in `evening-coffee-movie-dinner` run 1. It never ran in the report-only cases and removed no places.
    - `five-stars-only` stays the case where Claude answers from `search_places(min_rating=5)` rows. The fallback now covers it, and the model-only numbers keep showing it.
    - **Report-only cases:**
      - `rainy-afternoon-indoors`: `options` in 4 of 5 runs, `itinerary` in 1 (run 4: 3 stops, routed by the model). "A plan for a day or part of one" can pull an afternoon request into an itinerary. Worth watching in the full baseline.
      - `memorable-evening`: `options` with one place in 5 of 5.
    - **Summary over all 20 runs:** `details_before_recommending` 0.800, `route_when_multi_stop` 0.500 (n=10), `required_tools_used` 0.750, `tool_call_budget` 0.850, `fallback_rate` 0.250. Gates passed.
    - **Budget misses:** all 3 were in report-only cases, each 7 model calls against a limit of 6:
      - `rainy-afternoon-indoors` run 2 (5 searches, details, and `plan_route` on an `options` answer)
      - `rainy-afternoon-indoors` run 4 (5 searches, details, route)
      - `memorable-evening` run 5 (6 searches, details)
    - With the "do not route alternatives" sentence gone, the model routed an `options` answer once. That call counts against the budget. `inspect_budget` should be checked after the full baseline.
    - Zuni is again presented as a slow dinner in `evening-coffee-movie-dinner` run 2, though its notes say lunch. That is left for the note-faithfulness judge.
- **2026-09-26: fourth baseline, with the fallback, both providers.**
  - `sync_dataset`: 27 cases (2 created, 25 updated, 0 deleted). "25 updated" is the known equality bug, which reports unchanged examples as updated.
  - `run_evals --yes`: 27 cases x 3 repetitions x 2 providers = 162 agent runs. All gates passed.

    | Scorer | anthropic (claude-sonnet-5) | openai (gpt-6-sol) |
    |---|---|---|
    | covers_request | 1.000 (n=33) | 1.000 (n=33) |
    | details_before_recommending | 0.940 (n=67) | 1.000 (n=68) |
    | empty_when_nothing_fits | 0.917 (n=12) | 1.000 (n=12) |
    | expected_recall | 0.917 (n=60) | 0.983 (n=60) |
    | fallback_rate (report only) | 0.086 (n=81) | 0.000 (n=81) |
    | grounded (gate) | 1.000 (n=81) | 1.000 (n=81) |
    | no_forbidden (gate) | 1.000 (n=81) | 1.000 (n=81) |
    | required_tools_used | 0.920 (n=75) | 1.000 (n=75) |
    | respects_sequence | 1.000 (n=30) | 1.000 (n=30) |
    | route_when_multi_stop | 0.846 (n=39) | 1.000 (n=39) |
    | tool_call_budget | 0.975 (n=81) | 0.963 (n=81) |

    Experiments: `outing-agent-main-anthropic-309daa2f`, `outing-agent-main-openai-53ce3fae`.
  - **Not directly comparable with the third baseline.** Two sparse cases were added, and the tool-use scorers now count only the model's own calls.
  - **Fallback use:** it ran in about 1 in 12 Claude runs (`fallback_rate` 0.086), and never for GPT. So the fallback's second finalize has not run against OpenAI outside tests.
  - **Checked before thresholds:**
    - **Claude's nothing-fits miss:** `nothing-fits-sushi` run 1 recommended Tartine Bakery while saying it doesn't fit, "included here for reference". The other 11 nothing-fits runs returned no places. The finalize prompt says to recommend only places that fit, but nothing forbids adding a non-fitting place for reference.
    - **Sparse cases, no-notes rule:** all 12 runs (6 per provider) gave Coit Tower and Boba Guys reasons that say there are no notes and use only rating, tags and category. House of Prime Rib reasons used its notes in every run. One Claude overview (`sparse-view-single-stop` run 3) calls Coit Tower "known for its great views over San Francisco". That is close to general knowledge, but it only restates the "Great Views" tag and the saved address.
  - **Fallback cost** (`evals/fallback_cost.py`):

    | | Claude | GPT |
    |---|---|---|
    | Fallback ran | 7 of 81 runs | 0 of 81 runs |
    | Fallback model calls | 7 | 0 |
    | Fallback tokens | 23,770 | 0 |
    | Fallback cost (LangSmith) | 0.0666 | 0 |
    | All model calls | 390 | 379 |
    | All tokens | 1,026,087 | 505,564 |
    | All cost (LangSmith) | 2.7346 | 1.1954 |

    - The fallback used 2.3% of Claude's tokens.
    - Matching model calls to fallback runs worked, so the totals are complete.
  - **Budget (`inspect_budget`):** "2 + 2 per stop" is still the best candidate for both providers: 0.975 for Claude and 0.963 for GPT, against 0.926 for flat 6 and 0.827 and 0.852 for 2 + 1 per stop.
    - Over budget: Claude in `other-user-sunny-afternoon` run 1 and `saturday-market-then-lunch` run 3. GPT in `art-then-food` run 3 and `saturday-market-then-lunch` runs 1 and 2.
    - `saturday-market-then-lunch` goes over for both models the same way: after reading that Zuni is "best as a long, slow lunch", they search again for a quick lunch and read La Taqueria. That is the notes changing the plan, which is wanted, so the budget is not raised for it.
  - **Fix before thresholds:** the finalize prompt now says to recommend only places that fit, to return no places when none fit, and never to include a place for reference.
    - Thresholds must come from a baseline run with the final prompt, so the fourth baseline will not set them.
    - Targeted check first: the 4 nothing-fits cases, Claude only, 5 repetitions each, 20 runs. The bar is that all 20 return no places.
    - **Result: pass.** Experiment `outing-agent-main-targeted-anthropic-8905a28a`.
      - `empty_when_nothing_fits` 1.000 (n=20).
      - `required_tools_used` 1.000 (n=15), `tool_call_budget` 1.000 (n=20).
      - `fallback_rate` 0.000 (n=20). Gates passed.
  - **Model-only `plan_route` on route cases, fourth baseline:**
    - Claude called it in 0 of 3 `five-stars-only` runs, 2 of 3 `evening-coffee-movie-dinner` runs, and 1 of 3 `saturday-market-then-lunch` runs, and in every run of the other route cases.
    - GPT called it in every run.
- **2026-09-26: fifth baseline, with the final prompt. Thresholds will come from this one.**
  - `run_evals --yes`: 162 agent runs, all gates passed.

    | Scorer | anthropic (claude-sonnet-5) | openai (gpt-6-sol) |
    |---|---|---|
    | covers_request | 1.000 (n=33) | 1.000 (n=33) |
    | details_before_recommending | 0.984 (n=64) | 1.000 (n=69) |
    | empty_when_nothing_fits | 1.000 (n=12) | 1.000 (n=12) |
    | expected_recall | 0.958 (n=60) | 1.000 (n=60) |
    | fallback_rate (report only) | 0.025 (n=81) | 0.000 (n=81) |
    | grounded (gate) | 1.000 (n=81) | 1.000 (n=81) |
    | no_forbidden (gate) | 1.000 (n=81) | 1.000 (n=81) |
    | required_tools_used | 0.973 (n=75) | 1.000 (n=75) |
    | respects_sequence | 1.000 (n=30) | 1.000 (n=30) |
    | route_when_multi_stop | 0.949 (n=39) | 1.000 (n=39) |
    | tool_call_budget | 0.951 (n=81) | 0.951 (n=81) |

    Experiments: `outing-agent-main-anthropic-058737f5`, `outing-agent-main-openai-fdd08625`.
  - **A fallback rate of 0 is the goal.** It means the model read every pick and routed every itinerary by itself, and GPT's model-only details and route scores of 1.000 confirm it. The metric is report-only and exists to catch a regression if it rises.
  - Claude's `fallback_rate` fell from 0.086 in the fourth baseline to 0.025. The nothing-fits sentence was the only change between them, so this is most likely run-to-run variation and isn't put down to that sentence.
  - **Follow-up: the fallback has never run against OpenAI in a live run.** Its logic is covered by the tests, and the direct-call design sends only an ordinary user message, so no provider-specific risk is known. That is an argument from design, not a measurement. A live test that forces the fallback once per provider, skipped by default, would close it.
  - **Budget (`inspect_budget`):** "2 + 2 per stop" is kept. It is the best candidate for both providers at 0.951 each, against flat 6 (0.889 Claude, 0.938 GPT) and 2 + 1 per stop (0.827, 0.802).
    - Each provider went over budget in 4 runs, 8 in all:

      | Run | Provider | Calls (limit) | Accepted? |
      |---|---|---|---|
      | `saturday-market-then-lunch` run 1 | Claude | 7 (6) | Yes: after reading that Zuni is "best as a long, slow lunch", the model looked for and read a quicker lunch |
      | `saturday-market-then-lunch` run 3 | Claude | 7 (6) | Yes, same reason |
      | `saturday-market-then-lunch` run 1 | GPT | 7 (6) | Yes, same reason |
      | `saturday-market-then-lunch` run 3 | GPT | 7 (6) | Yes, same reason |
      | `evening-coffee-movie-dinner` run 3 | GPT | 9 (8) | Yes: after reading details it compared another cafe before keeping Sightglass |
      | `other-user-sunny-afternoon` run 1 | Claude | 7 (6) | No: six searches that repeat each other |
      | `rainy-afternoon-indoors` run 3 | Claude | 8 (6) | No: an extra search after reading details, and a route on a two-place answer |
      | `art-then-food` run 3 | GPT | 7 (6) | No: read Tartine before finding the museum, then searched again for a gallery |

    - The 3 runs not accepted are inefficient searching, not the notes changing the plan. The budget scorer is meant to catch exactly that, so it stays a scored regression signal, not a gate.
  - **Model-only `plan_route`:** Claude missed it in 1 of 3 runs of `evening-coffee-movie-dinner` and of `five-stars-only`, and routed every run of the other route cases. GPT routed every run of every route case.
  - **Holdout:** `sync_dataset --cases holdout` reported 3 cases (0 created, 3 updated, 0 deleted). "Updated" is the known equality bug.
    - `run_evals --cases holdout --yes`: 3 cases x 3 repetitions x 2 providers = 18 runs.
    - Every scorer was 1.000 for both providers, with `fallback_rate` 0.000 and both gates passed.
    - Experiments: `outing-agent-holdout-anthropic-c536a150`, `outing-agent-holdout-openai-4407b1cc`.
    - It is only 9 runs per provider, all on multi-stop cases, so it shows the thresholds are not overfit to the main cases in these runs. It is not a measure of rarer failures.
  - **Thresholds, 99% confidence, from the fifth baseline** (`evals.thresholds --confidence 0.99`):

    | Scorer | Claude mean | Claude 99% interval | Claude threshold | GPT mean | GPT 99% interval | GPT threshold |
    |---|---|---|---|---|---|---|
    | covers_request | 1.000 | [1.000, 1.000] | 0.90 (collapsed) | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | details_before_recommending | 0.984 | [0.935, 1.000] | 0.90 | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | empty_when_nothing_fits | 1.000 | [1.000, 1.000] | 0.90 (collapsed) | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | expected_recall | 0.958 | [0.850, 1.000] | 0.85 | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | required_tools_used | 0.973 | [0.920, 1.000] | 0.90 | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | respects_sequence | 1.000 | [1.000, 1.000] | 0.90 (collapsed) | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | route_when_multi_stop | 0.949 | [0.846, 1.000] | 0.80 | 1.000 | [1.000, 1.000] | 0.90 (collapsed) |
    | tool_call_budget | 0.951 | [0.864, 1.000] | 0.85 | 0.951 | [0.864, 1.000] | 0.85 |

    - Gates (`grounded`, `no_forbidden` at 1.0) and report-only scorers are excluded.
    - Claude's route threshold of 0.80 is loose. It is a model-habit signal only, since the fallback guarantees routes for itineraries. It was not hand-tuned.
    - `empty_when_nothing_fits` at 0.90 allows one miss in 12, which matches the one miss in the fourth baseline.
    - **CI caveat:** these thresholds assume a run the size of the baseline (27 cases x 3 repetitions). A smaller CI run would need thresholds recomputed for its size.
  - **How thresholds are stored and checked:**
    - `thresholds.py --write` saves exactly what it prints to `evals/thresholds.json`, with the confidence level, case set and source experiments. No number is typed by hand.
    - `run_evals.py` loads that file. A full or holdout run fails, exiting 1, when a scorer is below its provider's threshold, the same as a failed gate. A targeted `--case` run shows the thresholds but does not fail on them, since a few cases can't be compared with a full baseline. Gates still fail targeted runs.
    - Report-only scorers are never checked against thresholds.
    - Tests: `tests/test_run_evals.py`. `pytest`: 161 passed.
  - **Written and verified:**
    - `thresholds --write` printed the same table (same random seed) and wrote `evals/thresholds.json`, whose values match it.
    - The holdout was rerun against the saved thresholds (`outing-agent-holdout-anthropic-eab99af3`, `outing-agent-holdout-openai-58ff1551`): every scorer 1.000 for both providers, every threshold and gate passed.
- **2026-09-26: `sync_dataset` no longer reports unchanged examples as updated.**
  - **Cause:** a new `--dry-run` option, which prints each field that would change and writes nothing, showed that LangSmith adds `metadata.dataset_split: ['base']` to every example. It was the only difference on all 27 main examples.
  - **Fix:** metadata is compared only on the keys the cases set. Inputs and outputs are still compared in full, so a reference key removed from the cases still triggers an update.
  - **Verified:**
    - `pytest`: 167 passed, including 6 new tests in `tests/test_sync_dataset.py`.
    - `sync_dataset --dry-run`: `outing-agent-v1` 27 cases, 0 created, 0 updated, 0 deleted.
    - `--cases holdout --dry-run`: `outing-agent-holdout-v1` 3 cases, 0 created, 0 updated, 0 deleted.

#### Known limitations
- `langsmith` `Client.list_runs()`, used by `evals/experiments.py`, is deprecated and will be removed after **Jan 31, 2027**. The warning points to `client.runs.query()`, which takes project IDs and a time window rather than a project name. Migrate before that date.

---

## 2026-09-27: Step 3 complete, eval gate in CI before every deploy

### What we built
- **Request limits:** 20 requests per user per hour and 200 overall per hour on `/recommend`. Both defaults are product choices, not measured figures. The per-user check runs first.
- **Service logging:** the service logs `outing_agent` INFO lines to stdout, so each `recommendation_run` line reaches Cloud Run logs as structured JSON.
- **Container:** `agent/Dockerfile`, Python 3.14 slim, running as uid 1001, with only `pyproject.toml`, `README.md` and `src/` in the image.
- **`.github/workflows/agent-ci.yml`:**
  - `pytest` and `container` run on every PR and push.
  - On a push to `main`, `evals` syncs the dataset and runs the full main suite on both providers, failing on any gate or threshold.
  - `deploy` then pushes the image to Artifact Registry and deploys `favorite-places-agent` to Cloud Run (us-central1, at most 1 instance), followed by a smoke check on the live URL.
- **GCP setup:**
  - an Artifact Registry repo
  - a runtime service account (`roles/datastore.viewer`, plus access to the `anthropic-api-key` secret only)
  - a deployer service account
  - Workload Identity Federation for GitHub, limited to this repo's ID and `refs/heads/main`, with no JSON key
  - a US$10 monthly budget alert on the billing account
- **Keys:** the production Anthropic key lives in its own workspace, `outing-agent-prod`, with its own spend limit, and only in Secret Manager. It expires on 2026-12-31. CI uses the separate keys the evals already used.
- **Provider factory:** strips whitespace from `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` (PR #15).
- **PR structure:** the work was split from one large PR into a stack of 13 reviewable PRs (#1 to #13). `CONTRIBUTING.md` now has a "Keep PRs reviewable" guideline.

### Decisions made
- **The eval gate runs the full suite on both providers,** 27 cases x 3 repetitions x 2 = 162 runs, the size the thresholds were set on.
  - A smaller run would need recomputed thresholds.
  - Running only the deployed provider would leave GPT regressions unseen until a manual run.
- **The holdout is not in CI.** At 9 runs per provider, main-set thresholds would be flaky on it, so it runs on request.
- **Guests keep full access, including `/recommend`,** because recruiters try the app as guests. A new guest uid costs nothing, so the per-user limit doesn't cap spend. The global limit, the Anthropic workspace spend limit and the budget alert do.
- **The container is checked in CI, not locally,** since there's no local Docker. The deploy builds on the same runners.
- **WIF is used instead of a service account key.** The condition uses the numeric repository ID, as the WIF docs advise, not the repo name.
- **Deferred:**
  - Anthropic identity federation instead of an API key, pending a check that the SDK supports it
  - a live test that forces the fallback on each provider
  - type checking with mypy or pyright

### Numbers measured
- **CI run 36305317505** (first deploy, stack merge):

  | Job | Time |
  |---|---|
  | `pytest` | 40s |
  | `container` | 30s |
  | `evals` | 8m45s |
  | `deploy` | 1m28s |

  All gates and thresholds passed. Revision `favorite-places-agent-00001-4v7`. Experiments `outing-agent-main-anthropic-55d7db8e` and `outing-agent-main-openai-bc4f9712`.
- **CI run 36307896634** (after PR #15):

  | Job | Time |
  |---|---|
  | `pytest` (177 passed) | 25s |
  | `container` | 43s |
  | `evals` | 10m28s |
  | `deploy` | 1m41s |

  All gates and thresholds passed. Revision `favorite-places-agent-00003-htl`. Experiments `outing-agent-main-anthropic-287f1c98` and `outing-agent-main-openai-9b74ceb9`.
- **Eval scores, run 1 then run 2:**

  | Scorer | Claude | GPT |
  |---|---|---|
  | covers_request | 0.939, 0.970 | 1.000, 1.000 |
  | details_before_recommending | 0.955, 0.954 | 1.000, 1.000 |
  | empty_when_nothing_fits | 1.000, 1.000 | 1.000, 1.000 |
  | expected_recall | 0.942, 0.950 | 0.983, 1.000 |
  | fallback_rate (report only) | 0.049, 0.037 | 0.000, 0.000 |
  | required_tools_used | 0.933, 0.960 | 1.000, 1.000 |
  | respects_sequence | 0.933, 0.967 | 1.000, 1.000 |
  | route_when_multi_stop | 0.872, 0.923 | 1.000, 1.000 |
  | tool_call_budget | 0.988, 0.963 | 0.963, 0.963 |

  `grounded` and `no_forbidden` were 1.000 in both runs for both providers.
  - Claude's `covers_request` and `respects_sequence` were 1.000 in the fifth baseline and 0.939 and 0.933 in run 1, then 0.970 and 0.967 in run 2. All are above the 0.90 thresholds, and consistent with run-to-run variation.
- **Live check** against revision `00002-8g2`, as a guest (anonymous sign-in, then `/user/seed-demo` seeding 5 places):
  - `/recommend` for "Somewhere for coffee this morning" returned the guest's own Blue Bottle Coffee from Firestore.
  - The reason came from its notes (pour-over, quiet at 8am, bay-view window seats).
  - The model called `search_places` and `get_place_details` itself, so the fallback didn't run.
  - The `recommendation_run` line appeared in Cloud Run logs with tool calls, place IDs and `places_store: firestore`.
- **Eval cost per push:** not measured yet. It comes from `fallback_cost.py` on a CI experiment.

### Problems hit and how we solved them
- **The first live request returned a 500.** The Anthropic key in Secret Manager ended with a newline, from pasting it, pressing Enter, then Ctrl-D. A newline is an illegal HTTP header value, so every model call failed with `APIConnectionError`.
  - The HTTP error message included the key, so it was written to Cloud Run logs. **The key was treated as leaked:** deleted in the Anthropic console, replaced, stored as secret version 2 with `printf '%s'`, and version 1 disabled.
  - The service was moved to the new version with `gcloud run services update`.
  - PR #15 now strips whitespace from provider keys, and the README's rotation steps use the safe form.
- **Pasting multi-line commands into the terminal broke them twice:** a `gcloud services enable` split across lines, and a backslash continuation with trailing spaces. Commands that read input (`read -s`, `gh secret set`) must run on their own. Later commands were given as single lines.
- **A cherry-pick failed during the PR split** because a file changed mid-operation, most likely Dropbox syncing the repo folder. The retry matched the original exactly: `git diff` against the old top commit was empty.
- **The GitHub stack preview first seemed to stop short.** Creating the stack from the bottom, then adding the top two PRs, gave the full 13.

### Resume claims moved forward
- **3 (evals in CI before deploy): complete.** Every push to `main` that changes agent code runs the full eval suite on both providers, and only a pass deploys.
- **4 (run logging):** every production run logs its tool calls and the places it chose to Cloud Run. Confidence escalation is still Step 4.
- **2:** the FastAPI service now runs on Cloud Run.

### Case study
Evals gate every deploy: a push to `main` runs 162 scored agent runs across Claude and GPT, and the Cloud Run deploy only happens if every gate and per-provider threshold passes.

---

## 2026-09-27: Step 4, confidence escalation

### What we built
- **Confidence and a clarifying question.** `finalize` returns `confidence` (0 to 1) and a `clarifying_question`.
  - Below the provider's threshold, the graph escalates: no fallback, no places, an empty overview, and the question in the response.
  - The reported confidence is always the draft's, the value the decision used.
- **Per-provider thresholds** in `src/outing_agent/confidence_thresholds.json`, written by `evals/confidence_sweep.py --write`. A provider missing from the file never escalates. `config.CONFIDENCE_THRESHOLD` was removed.
- **One clarification round.** `POST /recommend` takes `message` or a `clarification` object (`original_message`, `question`, `answer`, each up to 500 characters). The server stays stateless, and a clarified request never escalates again.
- **Eval cases:**
  - Every case gained `expects_clarification`.
  - The main set has 32 cases: 4 vague, and 2 round trips, one of them a two-stop day plan.
  - The holdout has 6 cases, 2 of them vague.
- **Scorers:** report-only `asks_when_vague` and `no_needless_question`, based on `escalated`. `empty_when_nothing_fits` now scores 0 on an escalated run.
- **CI:** `pytest` and `container` run on every PR, and are now required checks on `main`.

### Decisions made
- **Confidence is reported by the model and calibrated on eval data,** not computed from signals or from agreement between repeated runs. Computing it from signals would have missed meaning, and repeated runs would have multiplied cost.
- **What makes a request clear:** it says which saved places would fit, through a kind of place, an activity, or a quality that ranks them.
  - A time alone ("this weekend", "Saturday") isn't enough, and neither is "nice".
  - The same rule is in the finalize prompt and in the `confidence` field description, so they never contradict each other.
  - `memorable-evening` stays a clear case, because "memorable" ranks the saved places.
- **Whether to ask is decided by the threshold, not the model.**
- **A clarified request is sent as one user message** combining the original request, the question and the answer. There's no assistant turn, because the question text comes from the client.
- **The threshold rule was fixed before seeing any data:**
  - Pick the highest share of vague runs asked, with needless questions at or below 0.05 of clear runs.
  - Require at least 0.5 of vague runs asked.
  - Ties go to the lower threshold.
  - 0.05 and 0.5 are product choices.
- **The holdout runs before the merge,** because merging turns escalation on in production.
- **Deferred:** Anthropic identity federation instead of an API key, and a live test that forces the fallback.

### Numbers measured
- **Run A** (CI run 36312308423, the Step 4 stack merge, no threshold yet):

  | Job | Result |
  |---|---|
  | `pytest` | 221 passed, 24s |
  | `container` | 35s |
  | evals | 32 cases x 3 x 2 = 192 agent runs, 10m56s |
  | deploy | 1m32s, revision `favorite-places-agent-00005-fj4` |

  All gates and thresholds passed. Experiments `outing-agent-main-anthropic-648ff8bd` and `outing-agent-main-openai-81389cb3`.

  | Scorer | Claude | GPT |
  |---|---|---|
  | covers_request | 1.000 (n=36) | 1.000 (n=36) |
  | details_before_recommending | 0.958 (n=71) | 1.000 (n=83) |
  | empty_when_nothing_fits | 1.000 (n=12) | 1.000 (n=12) |
  | expected_recall | 0.962 (n=66) | 0.985 (n=66) |
  | fallback_rate (report only) | 0.031 (n=96) | 0.000 (n=96) |
  | required_tools_used | 0.963 (n=81) | 1.000 (n=81) |
  | respects_sequence | 1.000 (n=33) | 1.000 (n=33) |
  | route_when_multi_stop | 0.929 (n=42) | 1.000 (n=42) |
  | tool_call_budget | 0.969 (n=96) | 0.948 (n=96) |
  | asks_when_vague (report only) | 0.000 (n=12) | 0.000 (n=12) |
  | no_needless_question (report only) | 1.000 (n=84) | 1.000 (n=84) |

  `grounded` and `no_forbidden` were 1.000 for both providers. The two escalation scorers read 0.000 and 1.000 because no threshold existed yet.
- **Confidence sweep on Run A** (12 vague and 78 clear first-round runs per provider; asked_vague / needless):
  - **Claude:** 0.15 → 0.750 / 0.000; 0.20 to 0.30 → 0.917 / 0.000; **0.35 → 1.000 / 0.000 (picked)**; 0.55 → 1.000 / 0.013; 0.95 → 1.000 / 0.808.
  - **GPT:** up to 0.20 → 0.000 / 0.000; 0.25 to 0.50 → 0.083 / 0.000; **0.55 → 1.000 / 0.000 (picked)**; 0.95 → 1.000 / 0.064.
  - These figures are **in-sample:** the thresholds were picked on these runs.
- **Holdout, out of sample** (local run before the merge, with the new thresholds; 6 cases x 3 x 2 = 36 agent runs; experiments `outing-agent-holdout-anthropic-de1a2901` and `outing-agent-holdout-openai-d4faea68`):

  | Provider | asks_when_vague (n=6) | no_needless_question (n=12) |
  |---|---|---|
  | Claude | **0.833** | 1.000 |
  | GPT | **1.000** | 1.000 |

  All gates and thresholds passed on the holdout. These are the figures measured on cases the thresholds weren't picked from.

- **Gate thresholds recomputed from Run A** (`thresholds.py --confidence 0.99 --write`, stacked with the escalation PR so one CI run checks both):

  | Scorer | Claude (old → new) | GPT (old → new) |
  |---|---|---|
  | details_before_recommending | 0.90 → 0.80 | 0.90 → 0.90 |
  | required_tools_used | 0.90 → 0.85 | 0.90 → 0.90 |
  | route_when_multi_stop | 0.80 → 0.70 | 0.90 → 0.90 |
  | tool_call_budget | 0.85 → 0.85 | 0.85 → 0.80 |

  - Every other threshold is unchanged. The source intervals: Claude details [0.826, 1.000], required tools [0.852, 1.000], route [0.714, 1.000]; GPT budget [0.844, 1.000].
  - **Why Run A and not a new run:** it used the final prompt. No clear run fell below the new confidence thresholds, so clear runs behave the same with escalation on.
  - **The one difference:** the 12 vague runs per provider were scored by `details_before_recommending` in Run A. With escalation on they return no places and aren't scored.

- **Run B** (CI run 36314896551, merge of #29 and #30, the first run with escalation on). Job times are from the job start and end timestamps:

  | Job | Result |
  |---|---|
  | `pytest` | 221 passed, 38s |
  | `container` | 33s |
  | evals | 192 agent runs, 11m21s |
  | deploy | 1m16s, revision `favorite-places-agent-00006-m45` |

  All gates and thresholds passed. Experiments `outing-agent-main-anthropic-5d78502d` and `outing-agent-main-openai-4ec20976`.

  | Scorer | Claude | GPT |
  |---|---|---|
  | covers_request | 1.000 (n=36) | 0.972 (n=36) |
  | details_before_recommending | 0.957 (n=70) | 1.000 (n=71) |
  | empty_when_nothing_fits | 1.000 (n=12) | 1.000 (n=12) |
  | expected_recall | 0.924 (n=66) | 0.977 (n=66) |
  | fallback_rate (report only) | 0.042 (n=96) | 0.000 (n=96) |
  | required_tools_used | 0.951 (n=81) | 1.000 (n=81) |
  | respects_sequence | 1.000 (n=33) | 0.970 (n=33) |
  | route_when_multi_stop | 0.905 (n=42) | 1.000 (n=42) |
  | tool_call_budget | 1.000 (n=96) | 0.958 (n=96) |
  | asks_when_vague (report only) | **1.000** (n=12) | **1.000** (n=12) |
  | no_needless_question (report only) | **1.000** (n=84) | **0.988** (n=84) |

  - `grounded` and `no_forbidden` were 1.000 for both providers.
  - `empty_when_nothing_fits` stayed at 1.000, and it scores 0 on an escalated run, so no nothing-fits case escalated.
  - GPT asked 1 needless question in 84 clear runs. Which case it was hasn't been checked yet.
  - `asks_when_vague` here is in-sample. The holdout figures above are the out-of-sample ones.
- **Live check** against revision `00006-m45`, as a new guest (anonymous sign-in, then `/user/seed-demo` seeding 5 places):
  - "Somewhere nice." escalated: confidence 0.1, no places, an empty overview, no tool calls, and a clarifying question asking what kind of place or mood.
  - The clarification round trip, answered "Somewhere with a view of the bay.", returned the guest's Blue Bottle Coffee with confidence 0.9, and the reason came from its notes (bay-view window seats).
  - The model called `search_places` three times and `get_place_details` once. Every call was tagged `source: model`, so the fallback didn't run.
  - Cloud Run logged both `recommendation_run` lines: confidence 0.1, escalated, round 0 with no places; then confidence 0.9, not escalated, clarification round, with the Blue Bottle place ID.

### Observations
- **Model confidence separates vague from clear requests well for both providers.** Neither asked needlessly on any clear run in Run A or on the holdout. In Run B, GPT asked once in 84 clear runs.
- **GPT's vague runs cluster just under its 0.55 threshold,** consistent with the rubric's "about 0.5". The fixed tie rule chose 0.55, even though every threshold from 0.55 to 0.90 scored the same. The holdout's 6 of 6 suggests the thin margin holds.
- **Claude missed 1 of 6 held-out vague runs.** That's too few to justify changing the rule.
- **Every recomputed threshold got looser or stayed the same.**
  - Run A's means are close to the fifth baseline's, but its run-to-run spread is wider, and each threshold is a lower bound from a single run.
  - **Claude's route threshold of 0.70 is a weak regression check.** The fallback still guarantees a route for every itinerary, so users are protected.
  - Basing thresholds on several runs of the same prompt would tighten them. That's a later change.
- **The escalated live run made no tool calls,** so its question was generic rather than based on the guest's places. Searching first could give a sharper question, at the cost of tool calls on every vague request.

### Problems hit and how we solved them
- **Rebasing PR 3 onto the amended PR 2 first replayed PR 2's old commit and conflicted.** `git rebase --onto` replayed only PR 3's own commit.
- **Dropbox again changed files mid-operation during a branch switch.** Retrying on a clean tree worked.

### Resume claims moved forward
- **4 (confidence escalation and run logging): complete.** Below a per-provider threshold picked on eval data, the agent asks one clarifying question instead of guessing, and every production run logs its confidence, escalation, clarification round, tool calls and chosen places to Cloud Run.
- **3:** the eval gate now also reports whether each provider asks on vague requests and stays quiet on clear ones.

### Case study
Vague requests get a question, not a guess: each model reports its confidence, the threshold is calibrated per provider on 90 scored eval runs and checked on held-out cases, and a clarified request comes back with grounded recommendations.

### Later
- Let `thresholds.py` pool several experiments of the same prompt, to tighten the gate thresholds.
- Identify GPT's needless question in Run B.
- A live test that forces the fallback on each provider.
- Anthropic identity federation instead of an API key.

---

## 2026-09-28: Step 5, the Plan screen

### What we built
- **Agent API changes the Plan screen needed** (#33 to #36, merged as one stack for one paid eval run):
  - **CORS:** `CORSMiddleware` allows the two Hosting origins (`CORS_ORIGINS`) and localhost on any port (`CORS_ORIGIN_REGEX`), with `GET` and `POST`, the `Authorization` and `Content-Type` headers, and no credentials.
  - **What each tool call found:** `ToolCall.result_place_ids` (the rows `search_places` returned, the places `get_place_details` found, or `plan_route`'s order) and `matched` (`search_places`' total). Only IDs come back; the app looks up names and notes locally, and the Cloud Run logs stay IDs only.
  - **Walking legs:** `legs` on `itinerary` answers, one per pair of consecutive stops, with `walk_minutes`, or `null` over 30 minutes. `_haversine_km` moved to `places/geo.py` as `haversine_km`, shared with `plan_route`.
  - **A start place:** an optional `start_place_id`, which must be one of the caller's own places (a foreign or unknown ID gets a 422). The start place becomes stop 1. A request that's only a start place never asks a question. Without a start place, the model's input is unchanged.
- **The Plan screen in the Flutter app** (#37 to #45):
  - a bottom bar with Places, Plan and Favorites
  - `AgentService` calling `/recommend`, and a plan notifier with one clarification round
  - the compose, thinking, question, nothing-fits, error and results states
  - results with a static route map, numbered stops, each stop's reason, and the walking legs
  - "How I got this", listing every tool call with what it found
- **An eval case set, `start_place`** (3 cases), run on request. It isn't in the CI gate.

### Decisions made
- **Walking times, not distances, so no units setting.** A real transit time would need a routing API, left for later; a leg over 30 minutes shows "Transit or a ride" with no number.
- **The walking estimate is straight-line distance x 1.3, at 4.8 km/h, capped at 30 minutes.** All three are product choices, not measurements, and the app labels the times "about".
- **Legs follow the final recommended order,** computed on the server, not the model's own `plan_route` call, which may be missing or in a different order.
- **Tool results come back as IDs, not text,** so no titles or notes reach the logs.
- **The "Thinking" steps are a timed animation in the app,** because `/recommend` isn't streamed.
- **"Skip and surprise me" sends "Surprise me" as the one clarification answer,** so it needs no API change.
- **A start-only request never escalates.** GPT drafted a plan for it, then reported confidence under its threshold and asked a question.

### Numbers measured
- **The stack's merge run** (CI run 36360813263, `gh run view 36360813263 --log`), both providers, 96 runs each, all gates and thresholds passed:

  | Scorer | Claude (`outing-agent-main-anthropic-23a90ead`) | GPT (`outing-agent-main-openai-5d4446b5`) |
  |---|---|---|
  | `grounded` (gate) | 1.000 | 1.000 |
  | `no_forbidden` (gate) | 1.000 | 1.000 |
  | `covers_request` | 1.000 | 1.000 |
  | `details_before_recommending` | 0.971 | 1.000 |
  | `empty_when_nothing_fits` | 1.000 | 1.000 |
  | `expected_recall` | 0.955 | 1.000 |
  | `required_tools_used` | 0.963 | 1.000 |
  | `respects_sequence` | 1.000 | 1.000 |
  | `route_when_multi_stop` | 0.929 | 1.000 |
  | `tool_call_budget` | 0.990 | 0.979 |
  | `fallback_rate` (report only) | 0.031 | 0.000 |
  | `asks_when_vague` (report only) | 1.000 | 1.000 |
  | `no_needless_question` (report only) | 1.000 | 1.000 |

- **`start_place` cases** (`run_evals --cases start_place`, 18 runs, from #36): every gate passed, and Claude scored 1.000 on every scorer. GPT's 3 misses were all on `start-alone`, which led to the start-only rule. After the fix, a `start-alone` re-measure (6 runs) gave `expected_recall` 1.000 for both providers. `no_needless_question` is 1.000 by construction on `start-alone` and `start-with-clarification`, since escalation is off for both, so these runs aren't calibration evidence.
- **CORS preflight against production** (`curl -si -X OPTIONS .../recommend` with the Hosting origin): `HTTP/2 200`, `access-control-allow-origin: https://favorite-places-app-94adb.web.app`, `access-control-allow-methods: GET, POST`.
- **Live check on the hosted app** (2026-09-28, an existing guest session with the 5 sample places): "Coffee by the water, then some art" returned Blue Bottle Coffee then SFMOMA, "Walk about 21 min" between them, a route map, and "How I got this" with 5 tool calls, each showing what it found ("No matches", "1 match: SFMOMA", "1 match: Blue Bottle Coffee"). The answer took just under a minute; it wasn't timed, so there's no latency figure.

### Problems hit and how we solved them
- **The agent had no CORS,** so the browser would have blocked every call from the Hosting domain. Fixed in #33 before any Flutter code called it.
- **GPT asked a question on a start-only request** after drafting a plan. A start-only request now skips escalation, with its own note to the model.

### Resume claims moved forward
- **1 (provider-agnostic tool-calling agent):** the agent is now used from the app's Plan screen, including by guests, and every answer shows the tool calls behind it.
- **3 (evals in CI before deploy):** the stack's merge ran the full gate on both providers before deploying.

### Case study
Recruiters using the guest login can ask the Plan tab for an outing and see the agent's stops, walking times and every tool call it made, all drawn from their own saved places.

---

## 2026-09-28: Step 5 follow-up, prompt caching on Claude requests

### What we built
- The Anthropic chat model sends a top-level `cache_control: {"type": "ephemeral"}` (#86). The API places the cache breakpoint on the request's last cacheable block and moves it forward as the conversation grows, so each agent-loop call reads the previous call's prefix from cache.
- OpenAI is unchanged; it caches automatically.
- A test checks the request payload carries `cache_control`, with no network call.

### Decisions made
- **Automatic caching rather than one breakpoint on the system prompt.** The system prompt and three tool definitions alone looked likely to fall under Sonnet 5's 1,024-token caching minimum; the saving is in the growing conversation and its tool results.
- **The finalize call binds a different tool,** so it isn't expected to read the agent loop's cache.
- **Pricing,** per Anthropic's prompt-caching page for Sonnet 5: 5-minute cache writes cost 1.25x base input, and reads 0.1x.

### Numbers measured
- **The merge run** (CI run 36421686082, `gh run view 36421686082 --log`), all gates and thresholds passed:

  | Scorer | Claude, Step 5 run (23a90ead) | Claude, this run (79232ce8) | GPT, this run (9c541271) |
  |---|---|---|---|
  | `grounded` (gate) | 1.000 | 1.000 | 1.000 |
  | `no_forbidden` (gate) | 1.000 | 1.000 | 1.000 |
  | `covers_request` | 1.000 | 1.000 | 1.000 |
  | `details_before_recommending` | 0.971 | 0.986 | 1.000 |
  | `empty_when_nothing_fits` | 1.000 | 0.917 | 1.000 |
  | `expected_recall` | 0.955 | 0.902 | 0.985 |
  | `required_tools_used` | 0.963 | 0.938 | 1.000 |
  | `respects_sequence` | 1.000 | 1.000 | 1.000 |
  | `route_when_multi_stop` | 0.929 | 0.881 | 1.000 |
  | `tool_call_budget` | 0.990 | 1.000 | 0.958 |
  | `fallback_rate` (report only) | 0.031 | 0.042 | 0.000 |
  | `asks_when_vague` (report only) | 1.000 | 1.000 | 1.000 |
  | `no_needless_question` (report only) | 1.000 | 0.964 | 1.000 |

- **Cache reads in one trace** (LangSmith, experiment `outing-agent-main-anthropic-79232ce8`, row 1, repetition 1, "An evening out: browse for books first, then dinner, then cocktails"):

  | Claude call | Input tokens | Cache read | Cache write | Output tokens | Cost |
  |---|---|---|---|---|---|
  | 1st | 1,557 | 0 | 1,555 | 191 | $0.0058 |
  | 2nd | 2,232 | 1,555 | 675 | 105 | $0.0031 |
  | 3rd | 2,980 | 2,230 | 748 | 606 | $0.0084 |

- **Experiment totals, Claude, 96 runs each** (LangSmith dataset `outing-agent-v1`, Cost chart):

  | | #29, Step 5 run, no caching | #31, this run |
  |---|---|---|
  | Input tokens | 1.093M | 1.068M |
  | Input cost | $2.19 | $1.34 |
  | Output tokens | 102.2K | 101.1K |
  | Output cost | $1.02 | $1.01 |
  | Total cost | $3.21 | $2.35 |

### Observations
- **Caching works across agent turns.** Each call reads back what the one before it wrote (1,555 tokens, then 1,555 + 675 = 2,230). The first call's cached prefix was 1,555 tokens, above the 1,024 minimum.
- **Input cost fell from $2.19 to $1.34 (about 39%) on almost the same input tokens,** and total cost from $3.21 to $2.35 (about 27%). Output cost didn't change. The costs are LangSmith's own pricing of the traced tokens, and this is one run on each side.
- **Several Claude scores were lower in this run than in the Step 5 run** (`expected_recall` 0.955 to 0.902, `route_when_multi_stop` 0.929 to 0.881, one missed `empty_when_nothing_fits` case), while `details_before_recommending` and `tool_call_budget` rose. Caching doesn't change what the model sees, and GPT, which this change didn't touch, also moved (`expected_recall` 1.000 to 0.985). Two runs can't separate run-to-run variance from a real change; every threshold still passed.

### Problems hit and how we solved them
- **Anthropic reported a low prompt-cache hit rate** on this project's API traffic, which is the outing agent. That prompted this change.
- **Production has `LANGSMITH_TRACING=false`,** so a live `/recommend` call leaves no trace. The cache reads were measured on the CI eval run's traces instead.

### Resume claims moved forward
- **1:** the agent's Claude requests now reuse cached prompt prefixes across tool-calling turns, cutting input cost in the eval suite.

### Case study
Turning on Anthropic's automatic prompt caching cut the eval suite's Claude input cost from $2.19 to $1.34 on the same 96 runs, with every quality gate still passing.

### Later
- Repeat the eval run to see whether the lower Claude scores are variance.
- Measure caching on production traffic, which would need tracing or usage logging in Cloud Run.
