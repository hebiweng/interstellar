from __future__ import annotations

import pytest
from pydantic import ValidationError

from interstellar_api.config import ApiSettings


def test_api_settings_load_only_explicit_environment_values() -> None:
    settings = ApiSettings.from_env(
        {
            "INTERSTELLAR_ENVIRONMENT": "test",
            "INTERSTELLAR_DEBUG": "yes",
            "INTERSTELLAR_READY_ON_STARTUP": "0",
            "INTERSTELLAR_BUILD_COMMIT": "abc123",
            "INTERSTELLAR_API_HOST": "127.0.0.2",
            "INTERSTELLAR_API_PORT": "8123",
            "UNRELATED_ENVIRONMENT": "ignored",
        }
    )

    assert settings.environment == "test"
    assert settings.debug is True
    assert settings.ready_on_startup is False
    assert settings.build_commit == "abc123"
    assert settings.server_host == "127.0.0.2"
    assert settings.server_port == 8123


def test_api_settings_reject_invalid_boolean() -> None:
    with pytest.raises(ValueError, match="must be a boolean"):
        ApiSettings.from_env({"INTERSTELLAR_DEBUG": "sometimes"})


def test_api_settings_reject_invalid_api_version() -> None:
    with pytest.raises(ValidationError):
        ApiSettings.from_env({"INTERSTELLAR_API_VERSION": "latest"})


def test_api_settings_reject_invalid_port() -> None:
    with pytest.raises(ValidationError):
        ApiSettings.from_env({"INTERSTELLAR_API_PORT": "70000"})
