"""M1 input, normalization, preflight, and immutable-envelope endpoints."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any, Literal
from uuid import uuid4

from fastapi import APIRouter, Request, status
from interstellar_core.application.recipe_preflight import (
    canonical_hash,
    create_noncomputing_snapshot,
    resolve_analysis_recipe,
)
from interstellar_core.time import (
    DatasetReference,
    SourceReference,
    TimeNormalizationStatus,
    TimeSpecInput,
    normalize_time_spec,
)
from pydantic import BaseModel, ConfigDict, Field, model_validator

from interstellar_api.catalogs import AnalysisModelCatalog, CatalogError
from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.workflow_store import WorkflowRecordNotFound, WorkflowStore

router = APIRouter(prefix="/api/v1", tags=["M1 Workflow"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SourcePayload(StrictModel):
    kind: str = Field(min_length=1, max_length=160)
    description: str | None = None
    uri: str | None = None
    version: str | None = None
    license: str | None = None
    retrieved_at: str | None = None

    def domain(self) -> SourceReference:
        return SourceReference(**self.model_dump())


class DatasetPayload(StrictModel):
    id: str
    version: str
    checksum: str | None = None
    license: str | None = None
    source_uri: str | None = None

    def domain(self) -> DatasetReference:
        return DatasetReference(**self.model_dump())


class TimeSpecPayload(StrictModel):
    calendar: str
    local_value: str
    precision: str
    timezone_id: str | None = None
    utc_candidates: list[str] = Field(default_factory=list, max_length=2)
    selected_utc: str | None = None
    confidence: str
    source: SourcePayload
    timezone_dataset: DatasetPayload | None = None
    historical_confidence: str | None = None
    uncertainty_seconds: int | None = Field(default=None, ge=0)
    warnings: list[dict[str, Any]] = Field(default_factory=list)


class LocationPayload(StrictModel):
    id: str | None = None
    name: str = Field(min_length=1, max_length=240)
    country_code: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    admin_path: list[str] = Field(default_factory=list)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, lt=180)
    elevation_m: float | None = Field(default=None, ge=-500, le=10000)
    timezone_id: str | None = None
    geonames_id: int | None = Field(default=None, ge=1)
    source: str | SourcePayload
    source_version: str | None = None
    accuracy_m: float | None = Field(default=None, ge=0)
    warnings: list[dict[str, Any]] = Field(default_factory=list)


SubjectKind = Literal[
    "person",
    "event",
    "project",
    "organization",
    "country",
    "relationship",
    "question",
    "location",
]


class SubjectVersionInputPayload(StrictModel):
    kind: SubjectKind
    display_name: str = Field(min_length=1, max_length=240)
    time_spec: TimeSpecPayload | None = None
    location: LocationPayload | None = None
    attributes: dict[str, Any]
    participant_version_ids: list[str] | None = None
    anchor_version_ids: list[str] | None = None
    source: SourcePayload


class SubjectCreatePayload(StrictModel):
    workspace_id: str = Field(min_length=1, max_length=160)
    version: SubjectVersionInputPayload


class AnalysisDraftCreatePayload(StrictModel):
    workspace_id: str | None = None
    entry_point_id: str
    selection: dict[str, Any]
    subject_roles: list[dict[str, Any]] = Field(min_length=1)
    time_context: dict[str, Any] | None = None
    locations: list[LocationPayload] = Field(default_factory=list)
    allowed_overrides: dict[str, Any] = Field(default_factory=dict)
    optional_extensions: list[str] = Field(default_factory=list)
    requested_outputs: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def one_selection(self) -> AnalysisDraftCreatePayload:
        if len(self.selection) != 1:
            raise ValueError("selection must contain exactly one entry")
        return self


class RecipeResolvePayload(StrictModel):
    draft_id: str
    draft_revision: int = Field(ge=1)


class RecipeConfirmPayload(StrictModel):
    recipe_content_hash: str
    outputs: list[str] = Field(min_length=1)
    report_requests: list[dict[str, Any]] = Field(default_factory=list)


def _id(prefix: str) -> str:
    return f"{prefix}-{uuid4()}"


def _now() -> datetime:
    return datetime.now(UTC)


def _iso(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _not_found(resource: str) -> ProblemException:
    return ProblemException(
        status=status.HTTP_404_NOT_FOUND,
        code=ErrorCode.NOT_FOUND,
        detail=f"{resource} was not found.",
    )


def _store(request: Request) -> WorkflowStore:
    return request.app.state.workflow_store


def _catalog(request: Request) -> AnalysisModelCatalog:
    return request.app.state.analysis_model_catalog


def _normalize_time(payload: TimeSpecPayload | None) -> tuple[dict[str, Any] | None, str]:
    if payload is None:
        return None, "unknown"
    result = normalize_time_spec(
        TimeSpecInput(
            calendar=payload.calendar,
            local_value=payload.local_value,
            precision=payload.precision,
            confidence=payload.confidence,
            source=payload.source.domain(),
            timezone_id=payload.timezone_id,
            timezone_dataset=(
                payload.timezone_dataset.domain() if payload.timezone_dataset else None
            ),
            historical_confidence=payload.historical_confidence,
            uncertainty_seconds=payload.uncertainty_seconds,
        )
    )
    if result.time_spec is None or result.status in {
        TimeNormalizationStatus.INVALID,
        TimeNormalizationStatus.NONEXISTENT,
        TimeNormalizationStatus.UNSUPPORTED,
    }:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail=result.error_detail or "The supplied local time cannot be normalized.",
            fields={"time_spec": {"code": result.error_code, "status": result.status.value}},
        )
    return result.time_spec.to_dict(), result.time_spec.precision.value


@router.post("/subjects", status_code=status.HTTP_201_CREATED)
async def create_subject(payload: SubjectCreatePayload, request: Request) -> dict[str, Any]:
    normalized_time, _precision = _normalize_time(payload.version.time_spec)
    created_at = _iso(_now())
    subject_id = _id("subject")
    version_id = _id("subject-version")
    version_payload = payload.version.model_dump(mode="json", exclude_none=True)
    version_payload["time_spec"] = normalized_time
    version = {
        "id": version_id,
        "subject_id": subject_id,
        **version_payload,
        "version": 1,
        "content_hash": canonical_hash(version_payload),
        "created_at": created_at,
    }
    subject = {
        "id": subject_id,
        "workspace_id": payload.workspace_id,
        "kind": payload.version.kind,
        "display_name": payload.version.display_name,
        "current_version_id": version_id,
        "created_at": created_at,
        "deleted_at": None,
    }
    _store(request).put_subject(subject, version)
    return {"subject": subject, "version": version}


@router.get("/subjects/{subject_id}")
async def get_subject(subject_id: str, request: Request) -> dict[str, Any]:
    try:
        return _store(request).get_subject(subject_id)
    except WorkflowRecordNotFound as exc:
        raise _not_found("Subject") from exc


@router.post("/analysis-drafts", status_code=status.HTTP_201_CREATED)
async def create_analysis_draft(
    payload: AnalysisDraftCreatePayload, request: Request
) -> dict[str, Any]:
    created_at = _iso(_now())
    draft = {
        "draft_id": _id("draft"),
        **payload.model_dump(mode="json"),
        "revision": 1,
        "status": "editing",
        "expires_at": _iso(_now() + timedelta(hours=1)),
        "created_at": created_at,
        "updated_at": created_at,
    }
    _store(request).put_draft(draft)
    return draft


@router.post("/analysis-recipes/resolve", status_code=status.HTTP_201_CREATED)
async def resolve_recipe(payload: RecipeResolvePayload, request: Request) -> dict[str, Any]:
    try:
        draft = _store(request).get_draft(payload.draft_id)
    except WorkflowRecordNotFound as exc:
        raise _not_found("Analysis draft") from exc
    if draft["revision"] != payload.draft_revision:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.INVALID_REQUEST,
            detail="The requested draft revision is stale.",
        )
    model_id = draft["selection"].get("analysis_model_id")
    if not model_id:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="M1 preflight currently accepts analysis_model_id selection only.",
        )
    try:
        preset = _catalog(request).get(str(model_id))
    except CatalogError as exc:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail=str(exc),
        ) from exc

    primary_role = draft["subject_roles"][0]
    version_id = primary_role.get("subject_version_id")
    if not version_id:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="M1 preflight requires a saved subject_version_id.",
        )
    try:
        version = _store(request).get_subject_version(version_id)
    except WorkflowRecordNotFound as exc:
        raise _not_found("Subject version") from exc
    time_spec = version.get("time_spec") or {}
    recipe = resolve_analysis_recipe(
        recipe_id=_id("recipe"),
        source_draft_id=draft["draft_id"],
        source_draft_revision=draft["revision"],
        entry_point_id=draft["entry_point_id"],
        subject_roles=draft["subject_roles"],
        model_preset=preset,
        available_components=set(),
        time_precision=str(time_spec.get("precision", "unknown")),
        has_exact_location=version.get("location") is not None,
        datasets=[],
        requested_view_ids=draft["requested_outputs"].get("view_ids"),
        requested_exports=draft["requested_outputs"].get("exports"),
        now=_now(),
        expires_at=_now() + timedelta(hours=1),
    )
    _store(request).put_recipe(recipe)
    return recipe


@router.post(
    "/analysis-recipes/{recipe_id}/confirm",
    status_code=status.HTTP_201_CREATED,
)
async def confirm_recipe(
    recipe_id: str, payload: RecipeConfirmPayload, request: Request
) -> dict[str, Any]:
    try:
        recipe = _store(request).get_recipe(recipe_id)
    except WorkflowRecordNotFound as exc:
        raise _not_found("Analysis recipe") from exc
    if recipe["content_hash"] != payload.recipe_content_hash:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.INVALID_REQUEST,
            detail="recipe_content_hash does not match the immutable recipe.",
        )
    role = recipe["subject_roles"][0]
    version = _store(request).get_subject_version(role["subject_version_id"])
    snapshot = create_noncomputing_snapshot(
        snapshot_id=_id("calculation"),
        recipe=recipe,
        normalized_input={"subject_version": version},
        datasets=recipe["dataset_requirements"],
        now=_now(),
        engine_version=request.app.state.settings.service_version,
    )
    _store(request).put_snapshot(snapshot)
    return snapshot


@router.get("/calculations/{snapshot_id}")
async def get_calculation(snapshot_id: str, request: Request) -> dict[str, Any]:
    try:
        return _store(request).get_snapshot(snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise _not_found("Calculation snapshot") from exc
