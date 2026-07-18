"""Environment-backed worker configuration."""

from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path


def _positive_float(value: str, *, name: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be numeric") from exc
    if parsed <= 0:
        raise ValueError(f"{name} must be greater than zero")
    return parsed


@dataclass(frozen=True, slots=True)
class WorkerSettings:
    service_name: str
    service_version: str
    heartbeat_path: Path
    heartbeat_interval_seconds: float
    heartbeat_max_age_seconds: float

    @classmethod
    def from_env(cls, environ: Mapping[str, str] | None = None) -> WorkerSettings:
        source = os.environ if environ is None else environ
        prefix = "INTERSTELLAR_WORKER_"

        def read(name: str, default: str) -> str:
            return source.get(f"{prefix}{name}", default)

        service_name = read("SERVICE_NAME", "interstellar-worker").strip()
        service_version = read("SERVICE_VERSION", "0.1.0").strip()
        if not service_name or not service_version:
            raise ValueError("worker service name and version must not be empty")
        return cls(
            service_name=service_name,
            service_version=service_version,
            heartbeat_path=Path(read("HEARTBEAT_PATH", "/tmp/interstellar-worker-heartbeat.json")),
            heartbeat_interval_seconds=_positive_float(
                read("HEARTBEAT_INTERVAL_SECONDS", "10"),
                name=f"{prefix}HEARTBEAT_INTERVAL_SECONDS",
            ),
            heartbeat_max_age_seconds=_positive_float(
                read("HEARTBEAT_MAX_AGE_SECONDS", "30"),
                name=f"{prefix}HEARTBEAT_MAX_AGE_SECONDS",
            ),
        )
