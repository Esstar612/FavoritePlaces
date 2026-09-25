from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

from outing_agent.graph.state import AgentContext, AgentState, RecommendationSet
from outing_agent.tools.places_tools import TOOLS

SYSTEM_PROMPT = """You plan outings using only the user's own saved places.

Use the tools to find candidates, read their details, and, for outings with
more than one stop, plan a route. Only recommend places the tools returned.
Base timing and tips on each place's notes and summary, not on general
knowledge. If nothing saved fits, say so plainly."""

FINALIZE_PROMPT = """Now give the final answer in the required format: a short
overview and the recommended places in visiting order, using only place IDs
the tools returned."""


def build_graph(model: BaseChatModel):
    agent_model = model.bind_tools(TOOLS)
    finalize_model = model.with_structured_output(RecommendationSet)

    def agent(state: AgentState) -> dict:
        reply = agent_model.invoke([SystemMessage(SYSTEM_PROMPT), *state["messages"]])
        return {"messages": [reply]}

    def finalize(state: AgentState) -> dict:
        # Ending on a user turn avoids a forced tool call directly after an assistant turn.
        result = finalize_model.invoke(
            [SystemMessage(SYSTEM_PROMPT), *state["messages"], HumanMessage(FINALIZE_PROMPT)]
        )
        return {"recommendation_set": result}

    graph = StateGraph(AgentState, context_schema=AgentContext)
    graph.add_node("agent", agent)
    graph.add_node("tools", ToolNode(TOOLS))
    graph.add_node("finalize", finalize)
    graph.add_edge(START, "agent")
    graph.add_conditional_edges("agent", tools_condition, {"tools": "tools", END: "finalize"})
    graph.add_edge("tools", "agent")
    graph.add_edge("finalize", END)
    return graph.compile()
