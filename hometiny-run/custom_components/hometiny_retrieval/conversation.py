"""Retrieval baseline: no model. The community's question, 'how would a traditional approach do?'

Tool: the LLM API tool whose name and description share the most words with the utterance
(each shared word weighted by how few tools contain it; English stopwords dropped, light suffix
stripping). Arguments, from the tool's own schema: 'name' is the exposed entity whose name best
matches the utterance, an enum takes the option the utterance names, a number takes the first
number in the utterance, and 'domain' is left out. It sees what a model sees: the tools, the
utterance, the exposed entities.
"""

from __future__ import annotations

import difflib
import math
import re
from typing import Any, Literal

from probatio import to_openapi

from homeassistant.components import conversation
from homeassistant.components.homeassistant.exposed_entities import async_should_expose
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_LLM_HASS_API, MATCH_ALL
from homeassistant.core import HomeAssistant
from homeassistant.helpers import device_registry as dr, llm
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

DOMAIN = "hometiny_retrieval"


STOP = set("a an and are as at be by do for from has have in is it its of on or please set that the this to up "
           "with you your my me i can could would will what which who how when where hass".split())


def _stem(word: str) -> str:
    """Light suffix stripping, so close, closes and closed meet, and lights meets light."""
    if word.endswith("s") and not word.endswith("ss") and len(word) > 3:
        word = word[:-1]
    for suffix in ("ing", "ed"):
        if word.endswith(suffix) and len(word) - len(suffix) >= 3:
            word = word[: -len(suffix)]
            break
    return word[:-1] if word.endswith("e") and len(word) > 3 else word


def _words(text: str) -> set[str]:
    spaced = re.sub(r"(?<=[a-z])(?=[A-Z])|_", " ", text or "")
    return {_stem(w) for w in re.findall(r"[a-z0-9]+", spaced.lower()) if w not in STOP}


def pick_tool(text: str, tools: list[dict[str, Any]]) -> dict[str, Any] | None:
    """The tool sharing the most idf-weighted words with the utterance."""
    docs = [_words(t["name"]) | _words(t.get("description", "")) for t in tools]
    query = _words(text)
    def score(doc: set[str]) -> float:
        return sum(math.log(1 + len(docs) / sum(w in d for d in docs)) for w in query & doc)
    best = max(zip(tools, docs), key=lambda pair: score(pair[1]), default=(None, set()))
    return best[0] if best[0] is not None and score(best[1]) > 0 else None


def fill_args(text: str, tool: dict[str, Any], entities: dict[str, str]) -> dict[str, Any]:
    """Fill arguments from the utterance and the exposed entities (name -> entity_id)."""
    props = tool.get("parameters", {}).get("properties", {})
    low, args = text.lower(), {}
    entity = max(entities, key=lambda n: difflib.SequenceMatcher(None, n.lower(), low).find_longest_match().size, default=None)
    number = re.search(r"\d+(?:\.\d+)?", text)
    for key, spec in props.items():
        options = spec.get("enum") or spec.get("items", {}).get("enum") or []
        if key == "name" and entity:
            args[key] = entity
        elif key == "domain":
            continue  # optional; two entities can share a name, so a guessed domain can only exclude the right one
        elif options and (hit := [o for o in options if str(o).lower() in low]):
            args[key] = hit[0] if "enum" in spec else hit
        elif spec.get("type") in ("integer", "number") and number:
            args[key] = int(float(number.group())) if spec["type"] == "integer" else float(number.group())
    return args


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Add the conversation entity."""
    async_add_entities([RetrievalConversationEntity(entry)])


class RetrievalConversationEntity(
    conversation.ConversationEntity, conversation.AbstractConversationAgent
):
    """A no-model baseline driven through Home Assistant's LLM API."""

    _attr_has_entity_name = True
    _attr_name = None
    _attr_supported_features = conversation.ConversationEntityFeature.CONTROL

    def __init__(self, entry: ConfigEntry) -> None:
        """Initialize the entity."""
        self.entry = entry
        self._attr_unique_id = entry.entry_id
        self._attr_device_info = dr.DeviceInfo(
            identifiers={(DOMAIN, entry.entry_id)},
            name=entry.title,
            model="retrieval-baseline",
            entry_type=dr.DeviceEntryType.SERVICE,
        )

    @property
    def supported_languages(self) -> list[str] | Literal["*"]:
        """Return the supported languages."""
        return MATCH_ALL

    async def async_added_to_hass(self) -> None:
        """Register as a conversation agent."""
        await super().async_added_to_hass()
        conversation.async_set_agent(self.hass, self.entry, self)

    async def async_will_remove_from_hass(self) -> None:
        """Unregister the agent."""
        conversation.async_unset_agent(self.hass, self.entry)
        await super().async_will_remove_from_hass()

    async def _async_handle_message(
        self,
        user_input: conversation.ConversationInput,
        chat_log: conversation.ChatLog,
    ) -> conversation.ConversationResult:
        """Answer one utterance."""
        settings = {**self.entry.data, **self.entry.options}
        try:
            await chat_log.async_provide_llm_data(
                user_input.as_llm_context(DOMAIN),
                settings.get(CONF_LLM_HASS_API),
                None,
                user_input.extra_system_prompt,
            )
        except conversation.ConverseError as err:
            return err.as_conversation_result()

        tools = []
        if chat_log.llm_api:
            serializer = chat_log.llm_api.custom_serializer
            tools = [
                {"name": t.name, "description": t.description or "",
                 "parameters": to_openapi(t.parameters, custom_serializer=serializer)}
                for t in chat_log.llm_api.tools
            ]
        entities = {
            state.name: state.entity_id
            for state in self.hass.states.async_all()
            if async_should_expose(self.hass, conversation.DOMAIN, state.entity_id)
        }
        tool = pick_tool(user_input.text, tools)
        if tool is not None:
            call = llm.ToolInput(tool_name=tool["name"], tool_args=fill_args(user_input.text, tool, entities))
            async for _result in chat_log.async_add_assistant_content(
                conversation.AssistantContent(agent_id=self.entity_id, tool_calls=[call])
            ):
                pass
        chat_log.async_add_assistant_content_without_tools(
            conversation.AssistantContent(
                agent_id=self.entity_id,
                content="Done." if tool is not None else "Sorry, I could not find an action for that.",
            )
        )
        return conversation.async_get_result_from_chat_log(user_input, chat_log)
