"""Environment-backed API configuration without hidden file loading."""

from __future__ import annotations

import os
from collections.abc import Mapping
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _parse_bool(value: str, *, name: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"{name} must be a boolean value")


class ApiSettings(BaseModel):
    """Validated process configuration loaded from ``INTERSTELLAR_*`` variables."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    service_name: str = Field(default="interstellar-api", min_length=1, max_length=80)
    service_version: str = Field(default="0.1.0", min_length=1, max_length=80)
    api_version: str = Field(default="v1", pattern=r"^v[1-9][0-9]*$")
    environment: Literal["development", "test", "staging", "production"] = "development"
    debug: bool = False
    ready_on_startup: bool = True
    request_id_header: str = Field(default="X-Request-ID", min_length=1, max_length=80)
    build_commit: str = Field(default="unknown", min_length=1, max_length=160)
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    server_host: str = Field(default="127.0.0.1", min_length=1, max_length=255)
    server_port: int = Field(default=8018, ge=1, le=65535)

    @field_validator("request_id_header")
    @classmethod
    def validate_header_name(cls, value: str) -> str:
        if any(char.isspace() for char in value):
            raise ValueError("request_id_header must not contain whitespace")
        return value

    @classmethod
    def from_env(cls, environ: Mapping[str, str] | None = None) -> ApiSettings:
        source = os.environ if environ is None else environ
        prefix = "INTERSTELLAR_"

        def read(name: str, default: str) -> str:
            return source.get(f"{prefix}{name}", default)

        return cls(
            service_name=read("SERVICE_NAME", "interstellar-api"),
            service_version=read("SERVICE_VERSION", "0.1.0"),
            api_version=read("API_VERSION", "v1"),
            environment=read("ENVIRONMENT", "development"),
            debug=_parse_bool(read("DEBUG", "false"), name=f"{prefix}DEBUG"),
            ready_on_startup=_parse_bool(
                read("READY_ON_STARTUP", "true"), name=f"{prefix}READY_ON_STARTUP"
            ),
            request_id_header=read("REQUEST_ID_HEADER", "X-Request-ID"),
            build_commit=read("BUILD_COMMIT", "unknown"),
            log_level=read("LOG_LEVEL", "INFO").upper(),
            server_host=read("API_HOST", "127.0.0.1"),
            server_port=int(read("API_PORT", "8018")),
        )
