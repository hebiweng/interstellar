"""Environment-backed API configuration without hidden file loading."""

from __future__ import annotations

import os
from collections.abc import Mapping
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator


def _parse_bool(value: str, *, name: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"{name} must be a boolean value")


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SWISS_EPHEMERIS_PATH = REPOSITORY_ROOT / "vendor" / "swisseph" / "ephe"
DEFAULT_GEONAMES_PATH = (
    REPOSITORY_ROOT / "vendor" / "geonames" / "cities500-2026-07-19.zip"
)
DEFAULT_GEONAMES_ADMIN1_PATH = (
    REPOSITORY_ROOT / "vendor" / "geonames" / "admin1CodesASCII-2026-07-19.txt"
)
DEFAULT_GEONAMES_ADMIN2_PATH = (
    REPOSITORY_ROOT / "vendor" / "geonames" / "admin2Codes-2026-07-19.txt"
)
DEFAULT_TIMEZONE_BOUNDARIES_PATH = (
    REPOSITORY_ROOT
    / "vendor"
    / "timezone-boundary-builder"
    / "timezones-2026b.geojson.zip"
)
DEFAULT_ACCOUNT_DATABASE_PATH = REPOSITORY_ROOT / "var" / "interstellar-accounts.sqlite3"


def _bundled_path(path: Path) -> str | None:
    return str(path) if path.exists() else None


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
    cors_allowed_origins: tuple[str, ...] = ()
    swiss_ephemeris_path: str | None = None
    geonames_path: str | None = None
    geonames_admin1_path: str | None = None
    geonames_admin2_path: str | None = None
    geonames_dataset_version: str = "unconfigured"
    timezone_boundaries_path: str | None = None
    timezone_boundaries_dataset_version: str = "unconfigured"
    deepseek_api_key: SecretStr | None = Field(default=None, exclude=True, repr=False)
    deepseek_base_url: str = Field(default="https://api.deepseek.com", min_length=1)
    deepseek_model: Literal["deepseek-v4-flash", "deepseek-v4-pro"] = "deepseek-v4-pro"
    account_database_path: str = str(DEFAULT_ACCOUNT_DATABASE_PATH)
    auth_cookie_name: str = Field(default="interstellar_session", min_length=1, max_length=80)
    auth_session_days: int = Field(default=30, ge=1, le=365)
    auth_cookie_secure: bool = False
    admin_bootstrap_email: str | None = None
    admin_bootstrap_password: SecretStr | None = Field(default=None, exclude=True, repr=False)
    admin_master_key: SecretStr | None = Field(default=None, exclude=True, repr=False)

    @field_validator("request_id_header")
    @classmethod
    def validate_header_name(cls, value: str) -> str:
        if any(char.isspace() for char in value):
            raise ValueError("request_id_header must not contain whitespace")
        return value

    @field_validator("cors_allowed_origins")
    @classmethod
    def validate_cors_origins(cls, values: tuple[str, ...]) -> tuple[str, ...]:
        for value in values:
            if not value.startswith(("http://", "https://")) or "*" in value:
                raise ValueError("CORS origins must be explicit http(s) origins")
        return values

    @classmethod
    def from_env(cls, environ: Mapping[str, str] | None = None) -> ApiSettings:
        source = os.environ if environ is None else environ
        prefix = "INTERSTELLAR_"

        def read(name: str, default: str) -> str:
            return source.get(f"{prefix}{name}", default)

        configured_swiss = read("SWISS_EPHEMERIS_PATH", "").strip()
        configured_geonames = read("GEONAMES_PATH", "").strip()
        configured_geonames_admin1 = read("GEONAMES_ADMIN1_PATH", "").strip()
        configured_geonames_admin2 = read("GEONAMES_ADMIN2_PATH", "").strip()
        configured_boundaries = read("TIMEZONE_BOUNDARIES_PATH", "").strip()
        configured_geonames_version = read("GEONAMES_DATASET_VERSION", "").strip()
        configured_boundaries_version = read(
            "TIMEZONE_BOUNDARIES_DATASET_VERSION", ""
        ).strip()
        if configured_geonames and not configured_geonames_version:
            raise ValueError(
                f"{prefix}GEONAMES_DATASET_VERSION is required with a custom GeoNames path"
            )
        if bool(configured_geonames_admin1) != bool(configured_geonames_admin2):
            raise ValueError(
                f"{prefix}GEONAMES_ADMIN1_PATH and {prefix}GEONAMES_ADMIN2_PATH "
                "must be configured together"
            )
        if configured_boundaries and not configured_boundaries_version:
            raise ValueError(
                f"{prefix}TIMEZONE_BOUNDARIES_DATASET_VERSION is required with a custom "
                "timezone boundary path"
            )
        geonames_path = configured_geonames or _bundled_path(DEFAULT_GEONAMES_PATH)
        boundaries_path = configured_boundaries or _bundled_path(
            DEFAULT_TIMEZONE_BOUNDARIES_PATH
        )

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
            cors_allowed_origins=tuple(
                origin.strip()
                for origin in read("CORS_ALLOWED_ORIGINS", "").split(",")
                if origin.strip()
            ),
            swiss_ephemeris_path=(
                configured_swiss or _bundled_path(DEFAULT_SWISS_EPHEMERIS_PATH)
            ),
            geonames_path=geonames_path,
            geonames_admin1_path=(
                configured_geonames_admin1
                or (
                    _bundled_path(DEFAULT_GEONAMES_ADMIN1_PATH)
                    if not configured_geonames
                    else None
                )
            ),
            geonames_admin2_path=(
                configured_geonames_admin2
                or (
                    _bundled_path(DEFAULT_GEONAMES_ADMIN2_PATH)
                    if not configured_geonames
                    else None
                )
            ),
            geonames_dataset_version=read(
                "GEONAMES_DATASET_VERSION",
                configured_geonames_version
                or ("cities500-2026-07-19" if geonames_path else "unconfigured"),
            ),
            timezone_boundaries_path=boundaries_path,
            timezone_boundaries_dataset_version=read(
                "TIMEZONE_BOUNDARIES_DATASET_VERSION",
                configured_boundaries_version
                or ("2026b-full" if boundaries_path else "unconfigured"),
            ),
            deepseek_api_key=(
                SecretStr(read("DEEPSEEK_API_KEY", "").strip())
                if read("DEEPSEEK_API_KEY", "").strip()
                else None
            ),
            deepseek_base_url=read("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/"),
            deepseek_model=read("DEEPSEEK_MODEL", "deepseek-v4-pro"),
            account_database_path=read(
                "ACCOUNT_DATABASE_PATH", str(DEFAULT_ACCOUNT_DATABASE_PATH)
            ),
            auth_cookie_name=read("AUTH_COOKIE_NAME", "interstellar_session"),
            auth_session_days=int(read("AUTH_SESSION_DAYS", "30")),
            auth_cookie_secure=_parse_bool(
                read(
                    "AUTH_COOKIE_SECURE",
                    "true" if read("ENVIRONMENT", "development") == "production" else "false",
                ),
                name=f"{prefix}AUTH_COOKIE_SECURE",
            ),
            admin_bootstrap_email=read("ADMIN_BOOTSTRAP_EMAIL", "").strip() or None,
            admin_bootstrap_password=(
                SecretStr(read("ADMIN_BOOTSTRAP_PASSWORD", ""))
                if read("ADMIN_BOOTSTRAP_PASSWORD", "")
                else None
            ),
            admin_master_key=(
                SecretStr(read("ADMIN_MASTER_KEY", ""))
                if read("ADMIN_MASTER_KEY", "")
                else None
            ),
        )
