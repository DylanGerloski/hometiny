"""Config flow: one entry, no options. The evaluation harness creates the entry itself."""

from typing import Any

from homeassistant.config_entries import ConfigFlow, ConfigFlowResult


class RetrievalConfigFlow(ConfigFlow, domain="hometiny_retrieval"):
    """Create the single entry."""

    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Create the entry with no settings."""
        return self.async_create_entry(title="HomeTiny retrieval baseline", data={})
