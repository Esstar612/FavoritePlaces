# CLAUDE.md

Working rules for this repo. The current project is `agent/`, a Python service
that recommends outings from a user's saved places using tool calling.

## What the agent work has to prove

1. An agent that recommends outings from saved places with tool calling, behind
   one provider interface over Anthropic (Claude API) and OpenAI, added
   alongside the app's existing Gemini features.
2. Built as a Python service with FastAPI and LangGraph, with evals run in
   LangSmith.
3. An evaluation suite scoring the agent's tool use and answers, run in CI
   before every deploy.
4. The agent escalates with a clarifying question below a confidence
   threshold, and every run logs its reasoning and tool calls for review.

## Who writes what

- Claude handles mechanical work directly: scaffolding, config, boilerplate,
  file moves, docs.
- Core logic is written by the owner. For graph structure and state, tool
  definitions, prompts, the provider interface, how the agent reads saved
  places, confidence scoring and the escalation threshold, and eval scorers,
  Claude shows the code with a short explanation and the owner places it.

## Running things

- Claude never runs tests, scripts, evals, or the server. Claude gives the
  exact command; the owner runs it and pastes the output back.

## Numbers

- Never invent numbers. Every figure in any doc (eval scores, latency, cost)
  must come from output the owner pasted. If there is no measured figure yet,
  say so instead of estimating.

## Library APIs

- LangGraph, LangChain, and LangSmith APIs change often. Check the current docs
  for the installed versions (see `agent/pyproject.toml`) instead of writing
  from memory, and say so explicitly when unsure an API still exists.

## Data access and trust

- The agent reads Firestore with Firebase Admin credentials, which bypass
  `firestore.rules`. The service is therefore the only access control on a
  user's places.
- The uid used by every tool comes only from the verified Firebase ID token.
  Never take it from the request body, tool arguments, or model output.
- Firebase initializes lazily, on first use. Nothing initializes it at import
  time. `/health`, pytest, and the evals on the fixture store must all run with
  no credentials configured.

## Boundaries

- Do not modify existing app code (`mobile/`, `backend/`, root Firebase config,
  existing workflows) without asking first. `agent/` is Claude's to scaffold.

## Writing

- No em dashes in any writing: code comments, docs, commit messages.
- Near-zero code comments. Only explain a non-obvious why (business logic,
  algorithmic reasoning, or a technical constraint the code can't show).
  No what, history, TODO, sync or maintenance notes, file descriptions, or
  test explanations. If unsure, leave it out.
- Commit messages carry no AI attribution (no Co-Authored-By trailers).

## Build log

- After every completed step, append a dated entry to `agent/BUILD_LOG.md`
  using the section template at the top of that file.
- Entries describe the work, decisions, numbers, and problems only. Never
  record who wrote, placed, or approved what.
