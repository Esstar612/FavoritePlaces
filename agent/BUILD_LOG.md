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
