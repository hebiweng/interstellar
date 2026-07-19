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
            "INTERSTELLAR_CORS_ALLOWED_ORIGINS": "http://localhost:3000, https://workspace.example",
            "UNRELATED_ENVIRONMENT": "ignored",
        }
    )

    assert settings.environment == "test"
    assert settings.debug is True
    assert settings.ready_on_startup is False
    assert settings.build_commit == "abc123"
    assert settings.server_host == "127.0.0.2"
    assert settings.server_port == 8123
    assert settings.cors_allowed_origins == (
        "http://localhost:3000",
        "https://workspace.example",
    )
    assert settings.swiss_ephemeris_path is not None
    assert settings.geonames_path is not None
    assert settings.geonames_admin1_path is not None
    assert settings.geonames_admin2_path is not None
    assert settings.geonames_dataset_version == "cities500-2026-07-19"
    assert settings.timezone_boundaries_path is not None
    assert settings.timezone_boundaries_dataset_version == "2026b-full"


def test_api_settings_reject_invalid_boolean() -> None:
    with pytest.raises(ValueError, match="must be a boolean"):
        ApiSettings.from_env({"INTERSTELLAR_DEBUG": "sometimes"})


def test_api_settings_reject_invalid_api_version() -> None:
    with pytest.raises(ValidationError):
        ApiSettings.from_env({"INTERSTELLAR_API_VERSION": "latest"})


def test_api_settings_reject_invalid_port() -> None:
    with pytest.raises(ValidationError):
        ApiSettings.from_env({"INTERSTELLAR_API_PORT": "70000"})


def test_api_settings_reject_wildcard_cors_origin() -> None:
    with pytest.raises(ValidationError, match="explicit http"):
        ApiSettings.from_env({"INTERSTELLAR_CORS_ALLOWED_ORIGINS": "*"})


def test_custom_location_dataset_paths_require_explicit_versions() -> None:
    with pytest.raises(ValueError, match="GEONAMES_DATASET_VERSION"):
        ApiSettings.from_env({"INTERSTELLAR_GEONAMES_PATH": "/srv/custom/geonames.zip"})
    with pytest.raises(ValueError, match="TIMEZONE_BOUNDARIES_DATASET_VERSION"):
        ApiSettings.from_env(
            {"INTERSTELLAR_TIMEZONE_BOUNDARIES_PATH": "/srv/custom/timezones.zip"}
        )


def test_custom_geonames_admin_files_must_be_configured_as_a_pair() -> None:
    with pytest.raises(ValueError, match="must be configured together"):
        ApiSettings.from_env(
            {"INTERSTELLAR_GEONAMES_ADMIN1_PATH": "/srv/custom/admin1.txt"}
        )
