import json

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import AIMessage, AnyMessage, HumanMessage, SystemMessage, ToolMessage
from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition
from langgraph.runtime import Runtime

from outing_agent.graph.state import AgentContext, AgentState, RecommendationSet
from outing_agent.run import retrieved_place_ids
from outing_agent.tools.places_tools import TOOLS

SYSTEM_PROMPT = """You plan outings using only the user's own saved places.

Use search_places to find candidates. Search results are only a shortlist:
before recommending any place, read it with get_place_details, and base the
reason, timing, and tips on its notes and summary, not on its rating or tags
alone. If a place has no notes or summary, base the reason on its rating,
tags, and category, say that there are no notes for it, and never fill in
details from general knowledge. If nothing saved fits, say so plainly.

Whenever you recommend two or more stops to visit one after another in one
outing, call plan_route once with the stops in the order the user asked for,
even if one of the requested stops could not be found. Set optimize only when
the user leaves the order open. One call returns every leg, so never call it
per leg. Present the stops in the order plan_route returns."""

FINALIZE_PROMPT = """Now give the final answer in the required format: a short
overview, the kind of answer, and the recommended places, using only place IDs
the tools returned. Recommend only places that fit the request. If none fit,
return no places and say so in the overview; never include a place for
reference. Set kind to itinerary when the user asks for a number of
stops, a sequence (first, then, after), or a plan for a day or part of one,
and list the stops in visiting order. Set kind to options only when the user
asks for ideas or asks you to choose between places, and list the best fit
first. If the request matches neither rule, set kind to options. If the user
asks for a number of stops, recommend exactly that many, or fewer if not
enough saved places fit.

Also give confidence, a number from 0 to 1 for how clearly you understood what
the user wants. It is not about whether any saved place matches: a clear
request with no matching saved places still gets high confidence, and you say
plainly that nothing fits. A request is clear when it tells you which of their
saved places would fit: a kind of place, an activity, or a quality or mood such
as memorable, romantic, relaxing or quiet. A quality counts only if it would
rank their saved places differently, so "nice" does not count. A time on its
own, like "this weekend" or "Saturday", does not make a request clear. Use 0.9
or more for a clear request; about 0.5 when you had to guess what they want;
0.2 or less when you can't tell. Always give clarifying_question: the one short
question that would most improve the answer, even when you are confident."""

CLARIFIED_NOTE = """

The user has already answered a clarifying question. Recommend; do not ask another."""

FALLBACK_PROMPT = """Your draft answer used places you had not read, or it is an
itinerary without a route. The draft and the missing tool results are below:
details for each recommended place you had not read, and a route if the draft
is an itinerary without one.

Draft answer:
{draft}

Tool results:
{results}

Rewrite the draft in the required format. Base each reason, timing, and tips on
the place's notes and summary. If a place has no notes or summary, say so and
use only its rating, tags, and category. You may drop a place whose details
show it does not fit, but do not add any place. Keep the same kind. If a route
is included, list the stops in its order; otherwise keep the draft's order."""

FINALIZE_RESERVE_STEPS = 4


def route_after_agent(state: AgentState) -> str:
    if state["remaining_steps"] <= FINALIZE_RESERVE_STEPS:
        return "finalize"
    return tools_condition(state)


def _answered_messages(messages: list[AnyMessage]) -> list[AnyMessage]:
    # Both provider APIs reject a conversation that ends on tool calls with no results.
    if messages and isinstance(messages[-1], AIMessage) and messages[-1].tool_calls:
        return messages[:-1]
    return messages


def _read_place_ids(messages: list[AnyMessage]) -> set[str]:
    ids: set[str] = set()
    for message in messages:
        if not (isinstance(message, ToolMessage) and message.name == "get_place_details"):
            continue
        try:
            payload = json.loads(message.content)
        except (TypeError, ValueError):
            continue
        ids.update(row["id"] for row in payload.get("places", []) if isinstance(row, dict))
    return ids


def fallback_calls(state: AgentState) -> list[dict]:
    messages = state["messages"]
    draft = state.get("recommendation_set")
    if draft is None:
        return []
    # Places the model never retrieved are left for grounding to drop, not read on its behalf.
    retrieved = retrieved_place_ids(messages)
    ordered = sorted(draft.recommendations, key=lambda rec: rec.order)
    place_ids = [pid for pid in dict.fromkeys(rec.place_id for rec in ordered) if pid in retrieved]
    calls = []
    unread = [pid for pid in place_ids if pid not in _read_place_ids(messages)]
    if unread:
        calls.append({"name": "get_place_details", "args": {"place_ids": unread}})
    routed = any(isinstance(m, ToolMessage) and m.name == "plan_route" for m in messages)
    if draft.kind == "itinerary" and len(place_ids) >= 2 and not routed:
        calls.append({"name": "plan_route", "args": {"place_ids": place_ids}})
    return calls


def finalize_prompt(state: AgentState) -> str:
    if state.get("clarification_allowed", True):
        return FINALIZE_PROMPT
    return FINALIZE_PROMPT + CLARIFIED_NOTE


def should_escalate(state: AgentState) -> bool:
    draft = state.get("recommendation_set")
    threshold = state.get("confidence_threshold")
    return bool(
        draft
        and state.get("clarification_allowed")
        and threshold is not None
        and draft.confidence < threshold
    )


def route_after_finalize(state: AgentState) -> str:
    if should_escalate(state):
        return "escalate"
    return "fallback" if fallback_calls(state) else END


def escalate(state: AgentState) -> dict:
    return {"escalated": True}


def _keep_draft_places(
    revised: RecommendationSet, draft: RecommendationSet
) -> tuple[RecommendationSet, list[str]]:
    allowed = {rec.place_id for rec in draft.recommendations}
    added = [rec.place_id for rec in revised.recommendations if rec.place_id not in allowed]
    kept = [rec for rec in revised.recommendations if rec.place_id in allowed]
    if revised.recommendations and not kept:
        return draft, added
    if draft.kind == "options":
        position = {rec.place_id: rec.order for rec in draft.recommendations}
        kept.sort(key=lambda rec: position[rec.place_id])
    else:
        kept.sort(key=lambda rec: rec.order)
    kept = [rec.model_copy(update={"order": i}) for i, rec in enumerate(kept, start=1)]
    return revised.model_copy(update={"kind": draft.kind, "recommendations": kept}), added


def build_graph(model: BaseChatModel):
    agent_model = model.bind_tools(TOOLS)
    finalize_model = model.with_structured_output(RecommendationSet, method="function_calling")
    tools_by_name = {tool.name: tool for tool in TOOLS}

    def agent(state: AgentState) -> dict:
        reply = agent_model.invoke([SystemMessage(SYSTEM_PROMPT), *state["messages"]])
        return {"messages": [reply]}

    def finalize(state: AgentState) -> dict:
        # Ending on a user turn avoids a forced tool call directly after an assistant turn.
        result = finalize_model.invoke(
            [
                SystemMessage(SYSTEM_PROMPT),
                *_answered_messages(state["messages"]),
                HumanMessage(finalize_prompt(state)),
            ]
        )
        return {"recommendation_set": result}

    def fallback(state: AgentState, runtime: Runtime[AgentContext]) -> dict:
        draft = state["recommendation_set"]
        calls = fallback_calls(state)
        # The tools only read runtime.context, so no model tool-call turn is needed to run them.
        for call in calls:
            call["result"] = tools_by_name[call["name"]].func(runtime=runtime, **call["args"])
        prompt = FALLBACK_PROMPT.format(
            draft=draft.model_dump_json(),
            results="\n\n".join(f"{call['name']}: {call['result']}" for call in calls),
        )
        revised = finalize_model.invoke(
            [
                SystemMessage(SYSTEM_PROMPT),
                *_answered_messages(state["messages"]),
                HumanMessage(prompt),
            ]
        )
        final, removed = _keep_draft_places(revised, draft)
        return {
            "recommendation_set": final,
            "draft_set": draft,
            "fallback_calls": calls,
            "fallback_removed_place_ids": removed,
        }

    graph = StateGraph(AgentState, context_schema=AgentContext)
    graph.add_node("agent", agent)
    graph.add_node("tools", ToolNode(TOOLS))
    graph.add_node("finalize", finalize)
    graph.add_node("fallback", fallback)
    graph.add_node("escalate", escalate)
    graph.add_edge(START, "agent")
    graph.add_conditional_edges(
        "agent",
        route_after_agent,
        {"tools": "tools", END: "finalize", "finalize": "finalize"},
    )
    graph.add_edge("tools", "agent")
    graph.add_conditional_edges(
        "finalize",
        route_after_finalize,
        {"escalate": "escalate", "fallback": "fallback", END: END},
    )
    graph.add_edge("fallback", END)
    graph.add_edge("escalate", END)
    return graph.compile()
