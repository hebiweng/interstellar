"""Process health and service status endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Request, Response, status

from interstellar_api.config import ApiSettings
from interstellar_api.models import (
    CapabilityStatus,
    LivenessResponse,
    ProbeStatus,
    ReadinessResponse,
    ServiceStatusResponse,
)
from interstellar_api.readiness import ReadinessRegistry

router = APIRouter(tags=["Service"])


def _settings(request: Request) -> ApiSettings:
    return request.app.state.settings


@router.get("/health/live", response_model=LivenessResponse, include_in_schema=False)
async def live(request: Request) -> LivenessResponse:
    settings = _settings(request)
    return LivenessResponse(service=settings.service_name, version=settings.service_version)


@router.get("/health/ready", response_model=ReadinessResponse, include_in_schema=False)
async def ready(request: Request, response: Response) -> ReadinessResponse:
    settings = _settings(request)
    registry: ReadinessRegistry = request.app.state.readiness
    results = await registry.check()
    is_ready = bool(results) and all(result.ready for result in results.values())
    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return ReadinessResponse(
        status="ready" if is_ready else "not_ready",
        service=settings.service_name,
        version=settings.service_version,
        probes={
            name: ProbeStatus(ready=result.ready, detail=result.detail)
            for name, result in results.items()
        },
    )


@router.get("/api/v1/status", response_model=ServiceStatusResponse)
async def service_status(request: Request) -> ServiceStatusResponse:
    settings = _settings(request)
    return ServiceStatusResponse(
        service=settings.service_name,
        service_version=settings.service_version,
        api_version=settings.api_version,
        environment=settings.environment,
        build_commit=settings.build_commit,
        capabilities={
            "input_normalization": CapabilityStatus(
                state="available",
                detail="M1 local-time normalization and subject-version envelope are available.",
            ),
            "recipe_preflight": CapabilityStatus(
                state="available",
                detail=(
                    "M1 can expose required, optional, blocked, and unavailable work "
                    "without executing astrology."
                ),
            ),
            "astrology_calculation": CapabilityStatus(
                state="not_implemented",
                detail="Scheduled for M2 and later; M1 snapshots contain no astrology facts.",
            ),
            "report_generation": CapabilityStatus(
                state="not_implemented",
                detail="Scheduled for later milestones; no report inference runs in M1.",
            ),
        },
    )
