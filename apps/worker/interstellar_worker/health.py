"""File heartbeat used by container and process supervisors."""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from time import time
from typing import Any


@dataclass(frozen=True, slots=True)
class Heartbeat:
    service: str
    version: str
    pid: int
    state: str
    sequence: int
    timestamp_unix: float
    timestamp: str


@dataclass(frozen=True, slots=True)
class HealthCheck:
    healthy: bool
    detail: str
    age_seconds: float | None


def write_heartbeat(path: Path, *, service: str, version: str, sequence: int) -> Heartbeat:
    path.parent.mkdir(parents=True, exist_ok=True)
    now = time()
    heartbeat = Heartbeat(
        service=service,
        version=version,
        pid=os.getpid(),
        state="idle",
        sequence=sequence,
        timestamp_unix=now,
        timestamp=datetime.fromtimestamp(now, tz=UTC).isoformat(),
    )
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(asdict(heartbeat), sort_keys=True), encoding="utf-8")
    temporary.replace(path)
    return heartbeat


def read_heartbeat(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("heartbeat payload must be an object")
    return data


def check_heartbeat(path: Path, *, max_age_seconds: float, now: float | None = None) -> HealthCheck:
    try:
        payload = read_heartbeat(path)
        timestamp = float(payload["timestamp_unix"])
    except FileNotFoundError:
        return HealthCheck(healthy=False, detail="heartbeat file is missing", age_seconds=None)
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return HealthCheck(healthy=False, detail="heartbeat file is invalid", age_seconds=None)

    age = max(0.0, (time() if now is None else now) - timestamp)
    if age > max_age_seconds:
        return HealthCheck(healthy=False, detail="heartbeat is stale", age_seconds=age)
    return HealthCheck(healthy=True, detail="heartbeat is current", age_seconds=age)
