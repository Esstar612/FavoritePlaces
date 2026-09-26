from itertools import count
from typing import Any

from langchain_core.language_models.fake_chat_models import GenericFakeChatModel
from langchain_core.messages import AIMessage
from langchain_core.runnables import RunnableLambda
from pydantic import Field

from outing_agent.graph.state import Recommendation, RecommendationSet


class ScriptedChatModel(GenericFakeChatModel):
    finals: list = Field(default_factory=list)
    finalize_inputs: list = Field(default_factory=list)

    def bind_tools(self, tools, **kwargs):
        return self

    def with_structured_output(self, schema, **kwargs):
        def respond(messages):
            self.finalize_inputs.append(messages)
            return self.finals[min(len(self.finalize_inputs), len(self.finals)) - 1]

        return RunnableLambda(respond)


def recommendation_set(
    place_ids: list[str], kind: str = "options", reason: str = "fits the request"
) -> RecommendationSet:
    return RecommendationSet(
        overview="A slow morning of coffee and pastries.",
        kind=kind,
        recommendations=[
            Recommendation(place_id=place_id, order=i + 1, reason=reason)
            for i, place_id in enumerate(place_ids)
        ],
    )


def tool_turn(name: str, args: dict, call_id: str) -> AIMessage:
    return AIMessage(content="", tool_calls=[{"name": name, "args": args, "id": call_id}])


def scripted_model(
    recommended_ids: list[str],
    *,
    kind: str = "options",
    turns: list[AIMessage] | None = None,
    revised: RecommendationSet | None = None,
) -> ScriptedChatModel:
    if turns is None:
        turns = [
            tool_turn("search_places", {"query": "coffee"}, "call_1"),
            tool_turn(
                "get_place_details", {"place_ids": ["demo-blue-bottle", "demo-tartine"]}, "call_2"
            ),
        ]
    finals = [recommendation_set(recommended_ids, kind)]
    if revised is not None:
        finals.append(revised)
    return ScriptedChatModel(
        messages=iter([*turns, AIMessage(content="Coffee first, then pastries.")]), finals=finals
    )


COUNTS_AS_GROUNDED = ["demo-blue-bottle", "demo-tartine"]
OWNED_NOT_RETRIEVED = "demo-sfmoma"
NOT_OWNED = ["other-dolores-park", "made-up-id"]
ALL_RECOMMENDED = [*COUNTS_AS_GROUNDED, OWNED_NOT_RETRIEVED, *NOT_OWNED]


class LoopingChatModel(GenericFakeChatModel):
    final: Any = None
    finalize_inputs: list = Field(default_factory=list)

    def bind_tools(self, tools, **kwargs):
        return self

    def with_structured_output(self, schema, **kwargs):
        def respond(messages):
            self.finalize_inputs.append(messages)
            return self.final

        return RunnableLambda(respond)


def looping_model(final_place_id: str) -> LoopingChatModel:
    turns = (
        AIMessage(
            content="",
            tool_calls=[{"name": "search_places", "args": {"query": "coffee"}, "id": f"loop_{i}"}],
        )
        for i in count()
    )
    final = RecommendationSet(
        overview="Coffee.",
        kind="options",
        recommendations=[Recommendation(place_id=final_place_id, order=1, reason="fits")],
    )
    return LoopingChatModel(messages=turns, final=final)
