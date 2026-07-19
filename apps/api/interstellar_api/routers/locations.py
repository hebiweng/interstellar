"""Offline place search backed by versioned GeoNames and timezone boundaries."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Query, Request, status
from interstellar_core.domain.errors import DomainError
from interstellar_core.location.models import LocationCandidate
from interstellar_core.location.resolver import LocationResolver
from pydantic import BaseModel, ConfigDict

from interstellar_api.errors import ErrorCode, ProblemException

router = APIRouter(prefix="/api/v1/locations", tags=["Locations"])


class _StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class LocationSearchItem(_StrictModel):
    id: str
    label: str
    match_score: float
    match_reasons: list[str]
    location: dict[str, Any]
    timezone_status: str
    timezone_candidates: list[dict[str, Any]]


class LocationDatasetInfo(_StrictModel):
    provider: str
    version: str
    license: str


class LocationSearchResponse(_StrictModel):
    items: list[LocationSearchItem]
    datasets: list[LocationDatasetInfo]


def _resolver(request: Request) -> LocationResolver:
    resolver = getattr(request.app.state, "location_resolver", None)
    if not isinstance(resolver, LocationResolver):
        raise ProblemException(
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.INTERNAL_ERROR,
            title="Location dataset unavailable",
            detail=(
                "This deployment has not mounted the versioned GeoNames and "
                "timezone-boundary datasets required for offline place search."
            ),
            retryable=False,
        )
    return resolver


def _item(candidate: LocationCandidate) -> LocationSearchItem:
    place = candidate.place
    admin = " / ".join(place.admin_path)
    label_parts = [place.name, admin, place.country_code]
    return LocationSearchItem(
        id=f"geonames:{place.geonames_id}",
        label=" · ".join(part for part in label_parts if part),
        match_score=candidate.match_score,
        match_reasons=list(candidate.match_reasons),
        location=candidate.to_canonical(),
        timezone_status=candidate.timezone.status.value,
        timezone_candidates=[
            {
                "timezone_id": item.timezone_id,
                "source": item.source,
                "source_version": item.source_version,
                "confidence": item.confidence,
                "boundary_match": item.boundary_match,
            }
            for item in candidate.timezone.candidates
        ],
    )


@router.get("/search", response_model=LocationSearchResponse)
def search_locations(
    request: Request,
    q: Annotated[str, Query(min_length=1, max_length=160)],
    country_code: Annotated[str | None, Query(min_length=2, max_length=2)] = None,
    admin_hint: Annotated[list[str] | None, Query(max_length=80)] = None,
    limit: Annotated[int, Query(ge=1, le=25)] = 10,
) -> LocationSearchResponse:
    resolver = _resolver(request)
    try:
        candidates = resolver.search(
            q,
            country_code=country_code,
            admin_hints=admin_hint or (),
            limit=limit,
        )
    except DomainError as exc:
        raise ProblemException(
            status=status.HTTP_400_BAD_REQUEST,
            code=ErrorCode.INVALID_REQUEST,
            title="Invalid location search",
            detail=exc.detail,
            fields={"domain_code": exc.code},
        ) from exc

    settings = request.app.state.settings
    return LocationSearchResponse(
        items=[_item(candidate) for candidate in candidates],
        datasets=[
            LocationDatasetInfo(
                provider="GeoNames",
                version=settings.geonames_dataset_version,
                license="CC-BY-4.0",
            ),
            LocationDatasetInfo(
                provider="Timezone Boundary Builder",
                version=settings.timezone_boundaries_dataset_version,
                license="ODbL-1.0",
            ),
        ],
    )
