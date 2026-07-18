"""M2 synchronous astronomical calculation endpoint."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any, Literal
from uuid import uuid4

from fastapi import APIRouter, Request, status
from interstellar_core.application.astronomical_snapshot import (
    AstronomicalSnapshotInputError,
    create_astronomical_snapshot,
)
from pydantic import BaseModel, ConfigDict, Field, model_validator

from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.workflow_store import WorkflowRecordNotFound

router = APIRouter(prefix="/api/v1", tags=["M2 Calculations"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SubjectReferencePayload(StrictModel):
    subject_version_id: str | None = Field(default=None, min_length=1, max_length=160)
    inline_subject: dict[str, Any] | None = None

    @model_validator(mode="after")
    def exactly_one_subject(self) -> SubjectReferencePayload:
        if (self.subject_version_id is None) == (self.inline_subject is None):
            raise ValueError("provide exactly one of subject_version_id or inline_subject")
        return self


class ChartDefinitionPayload(StrictModel):
    family: Literal[
        "natal",
        "transit",
        "progression",
        "direction",
        "return",
        "relationship",
        "horary",
        "electional",
        "relocation",
        "mundane",
        "harmonic",
        "custom",
    ]
    technique: str = Field(min_length=1, max_length=160)
    reference_time: dict[str, Any] | None = None
    reference_location: dict[str, Any] | None = None
    comparison_subjects: list[SubjectReferencePayload] = Field(default_factory=list)


class ChartSettingsPayload(StrictModel):
    zodiac: Literal["tropical", "sidereal", "draconic"]
    ayanamsa: str | None = None
    house_system: str = Field(min_length=1, max_length=40)
    center: Literal["geocentric", "heliocentric", "topocentric"]
    coordinate_frame: Literal["ecliptic", "equatorial", "horizontal"] | None = None
    node_type: Literal["true", "mean", "both"]
    aspect_set_id: str = Field(min_length=1, max_length=160)
    orb_profile_id: str = Field(min_length=1, max_length=160)
    included_points: list[str] = Field(default_factory=list)
    custom_parameters: dict[str, Any] = Field(default_factory=dict)


class VersionReferencePayload(StrictModel):
    id: str = Field(min_length=1, max_length=160)
    version: str = Field(min_length=1)
    content_hash: str


class ChartRequestPayload(StrictModel):
    subject: SubjectReferencePayload
    chart: ChartDefinitionPayload
    settings: ChartSettingsPayload
    analysis_model: VersionReferencePayload | None = None
    rule_pack_hash: str = Field(pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$")
    dataset_versions: dict[str, str]
    outputs: list[
        Literal["snapshot", "default_render_manifest", "svg", "png", "pdf", "json", "csv", "ics"]
    ] = Field(min_length=1)
    input_fingerprint: str | None = None


def _unsupported(fields: dict[str, Any]) -> ProblemException:
    return ProblemException(
        status=status.HTTP_422_UNPROCESSABLE_CONTENT,
        code=ErrorCode.INVALID_REQUEST,
        detail="The M2 astronomical slice cannot execute the requested settings without guessing.",
        fields=fields,
    )


@router.post("/calculations", status_code=status.HTTP_201_CREATED)
async def create_calculation(payload: ChartRequestPayload, request: Request) -> dict[str, Any]:
    if payload.subject.inline_subject is not None:
        raise _unsupported(
            {"subject.inline_subject": "planned after durable anonymous input wiring"}
        )
    if payload.chart.family != "natal":
        raise _unsupported({"chart.family": "M2 supports natal astronomical snapshots only"})
    incompatible: dict[str, str] = {}
    if payload.settings.zodiac != "tropical":
        incompatible["settings.zodiac"] = "M2 supports tropical positions only"
    if payload.settings.center != "geocentric":
        incompatible["settings.center"] = "M2 supports geocentric positions only"
    if payload.settings.coordinate_frame == "horizontal":
        incompatible["settings.coordinate_frame"] = (
            "horizontal coordinates require M7 observer work"
        )
    if incompatible:
        raise _unsupported(incompatible)

    assert payload.subject.subject_version_id is not None
    try:
        subject_version = request.app.state.workflow_store.get_subject_version(
            payload.subject.subject_version_id
        )
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Subject version was not found.",
        ) from exc

    request_document = payload.model_dump(mode="json", exclude_none=True)
    try:
        snapshot = create_astronomical_snapshot(
            snapshot_id=f"calculation-{uuid4()}",
            request_payload=request_document,
            subject_version=subject_version,
            now=datetime.now(UTC),
            engine_version=request.app.state.settings.service_version,
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"subject.time_spec": str(exc)}) from exc
    request.app.state.workflow_store.put_snapshot(snapshot)
    return snapshot
