"""M0 HTTP response models."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict


class StrictResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")


class LivenessResponse(StrictResponse):
    status: Literal["alive"] = "alive"
    service: str
    version: str


class ProbeStatus(StrictResponse):
    ready: bool
    detail: str


class ReadinessResponse(StrictResponse):
    status: Literal["ready", "not_ready"]
    service: str
    version: str
    probes: dict[str, ProbeStatus]


class CapabilityStatus(StrictResponse):
    state: Literal["not_implemented", "available"]
    detail: str


class ServiceStatusResponse(StrictResponse):
    status: Literal["foundation"] = "foundation"
    service: str
    service_version: str
    api_version: str
    environment: str
    build_commit: str
    capabilities: dict[str, CapabilityStatus]
