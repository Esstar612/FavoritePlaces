from typing import Any

from langchain_core.language_models.fake_chat_models import GenericFakeChatModel
from langchain_core.messages import AIMessage
from langchain_core.runnables import RunnableLambda

from outing_agent.graph.state import Recommendation, RecommendationSet


class ScriptedChatModel(GenericFakeChatModel):
    final: Any = None

    def bind_tools(self, tools, **kwargs):
        return self

    def with_structured_output(self, schema, **kwargs):
        return RunnableLambda(lambda _: self.final)


def scripted_model(recommended_ids: list[str]) -> ScriptedChatModel:
    turns = [
        AIMessage(
            content="",
            tool_calls=[{"name": "search_places", "args": {"query": "coffee"}, "id": "call_1"}],
        ),
        AIMessage(
            content="",
            tool_calls=[
                {
                    "name": "get_place_details",
                    "args": {"place_ids": ["demo-blue-bottle", "demo-tartine"]},
                    "id": "call_2",
                }
            ],
        ),
        AIMessage(content="Coffee first, then pastries."),
    ]
    final = RecommendationSet(
        overview="A slow morning of coffee and pastries.",
        recommendations=[
            Recommendation(place_id=place_id, order=i + 1, reason="fits the request")
            for i, place_id in enumerate(recommended_ids)
        ],
    )
    return ScriptedChatModel(messages=iter(turns), final=final)


COUNTS_AS_GROUNDED = ["demo-blue-bottle", "demo-tartine"]
OWNED_NOT_RETRIEVED = "demo-sfmoma"
NOT_OWNED = ["other-dolores-park", "made-up-id"]
ALL_RECOMMENDED = [*COUNTS_AS_GROUNDED, OWNED_NOT_RETRIEVED, *NOT_OWNED]
