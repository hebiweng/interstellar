"""M2 synchronous astronomical calculation endpoint."""

from __future__ import annotations

import time
from copy import deepcopy
from datetime import UTC, date, datetime, timedelta
from typing import Any, Literal
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Query, Request, Response, status
from interstellar_core.application.astronomical_snapshot import (
    AstronomicalSnapshotInputError,
    create_astronomical_snapshot,
    create_date_level_astronomical_snapshot,
)
from interstellar_core.application.chart_comparison import (
    create_cross_chart_comparison,
)
from interstellar_core.application.natal_technical_export import (
    NatalTechnicalExportError,
    natal_technical_document_content_hash,
    render_natal_technical_document,
)
from interstellar_core.application.snapshot_tables import (
    SnapshotTableError,
    build_snapshot_table,
    table_json_bytes,
)
from interstellar_core.astrology.aspects import AspectContext
from interstellar_core.astronomy.adapters import AYANAMSA_MODES, SwissEphemerisAdapter
from pydantic import BaseModel, ConfigDict, Field, model_validator

from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.routers.accounts import current_user
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


class OrbOverridePayload(StrictModel):
    scope: Literal["point_pair", "point_class", "aspect", "chart_context"]
    point_a: str | None = None
    point_b: str | None = None
    point_class: str | None = None
    aspect_id: str | None = None
    chart_context: str | None = None
    orb_deg: float = Field(ge=0, le=30)


class ClassicalSettingsPayload(StrictModel):
    rulership_system: str | None = None
    dignity_table: str | None = None
    triplicity_table: str | None = None
    terms_table: str | None = None
    decan_or_face_table: str | None = None
    sect_rules: str | None = None
    lot_formula_set: str | None = None


class ChartSettingsPayload(StrictModel):
    calculation_profile_id: str | None = Field(default=None, min_length=1, max_length=160)
    analysis_system_id: str | None = Field(default=None, min_length=1, max_length=160)
    zodiac: Literal["tropical", "sidereal", "draconic"]
    ayanamsa: str | None = None
    house_system: str = Field(min_length=1, max_length=40)
    center: Literal["geocentric", "heliocentric", "topocentric"]
    coordinate_frame: Literal["ecliptic", "equatorial", "horizontal"] | None = None
    node_type: Literal["true", "mean", "both"]
    high_latitude_policy: (
        Literal["block", "allow_distorted", "fallback_whole_sign", "fallback_equal"] | None
    ) = None
    aspect_set_id: str = Field(min_length=1, max_length=160)
    orb_profile_id: str = Field(min_length=1, max_length=160)
    point_set_ids: list[str] = Field(default_factory=list)
    included_points: list[str] = Field(default_factory=list)
    minor_body_ids: list[str] = Field(default_factory=list)
    fixed_star_ids: list[str] = Field(default_factory=list)
    lot_formula_ids: list[str] = Field(default_factory=list)
    hypothetical_point_ids: list[str] = Field(default_factory=list)
    included_aspect_ids: list[str] = Field(default_factory=list)
    orb_overrides: list[OrbOverridePayload] = Field(default_factory=list)
    classical_settings: ClassicalSettingsPayload | None = None
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
        Literal[
            "snapshot",
            "default_render_manifest",
            "svg",
            "png",
            "pdf",
            "json",
            "csv",
            "ics",
            "markdown_technical",
            "plaintext_technical",
        ]
    ] = Field(min_length=1)
    input_fingerprint: str | None = None


class ChartComparisonPayload(StrictModel):
    reference_snapshot_id: str | None = Field(default=None, min_length=1, max_length=160)
    reference_snapshot: dict[str, Any] | None = None
    moving_snapshot_id: str = Field(min_length=1, max_length=160)
    context: Literal["transit", "progression"]
    settings: ChartSettingsPayload

    @model_validator(mode="after")
    def exactly_one_reference_snapshot(self) -> ChartComparisonPayload:
        if (self.reference_snapshot_id is None) == (self.reference_snapshot is None):
            raise ValueError(
                "provide exactly one of reference_snapshot_id or reference_snapshot"
            )
        return self


class SecondaryProgressionPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    target_date: date
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


def _unsupported(fields: dict[str, Any]) -> ProblemException:
    return ProblemException(
        status=status.HTTP_422_UNPROCESSABLE_CONTENT,
        code=ErrorCode.INVALID_REQUEST,
        detail="The M2 astronomical slice cannot execute the requested settings without guessing.",
        fields=fields,
    )


@router.post("/calculations", status_code=status.HTTP_201_CREATED)
async def create_calculation(payload: ChartRequestPayload, request: Request) -> dict[str, Any]:
    started = time.monotonic()
    analytics_user = current_user(request)
    analytics_metadata = {
        "chart_family": payload.chart.family,
        "technique": payload.chart.technique,
        "analysis_type": payload.settings.analysis_system_id or "natal",
    }
    if payload.subject.inline_subject is not None:
        raise _unsupported(
            {"subject.inline_subject": "planned after durable anonymous input wiring"}
        )
    supported_techniques = {
        "natal": "natal.standard_chart",
        "mundane": "mundane.current_sky",
    }
    expected_technique = supported_techniques.get(payload.chart.family)
    if expected_technique is None:
        raise _unsupported({
            "chart.family": "This synchronous slice supports natal and mundane current-sky charts"
        })
    if payload.chart.technique != expected_technique:
        raise _unsupported({
            "chart.technique": (
                f"{payload.chart.family} requires technique {expected_technique!r} in this slice"
            )
        })
    incompatible: dict[str, str] = {}
    if payload.settings.zodiac == "draconic":
        incompatible["settings.zodiac"] = (
            "draconic is a separate chart transform and is not a natal zodiac toggle"
        )
    elif payload.settings.zodiac == "tropical" and payload.settings.ayanamsa is not None:
        incompatible["settings.ayanamsa"] = "tropical zodiac must not declare an ayanamsa"
    elif payload.settings.zodiac == "sidereal" and payload.settings.ayanamsa not in AYANAMSA_MODES:
        incompatible["settings.ayanamsa"] = "sidereal zodiac requires one of: " + ", ".join(
            sorted(AYANAMSA_MODES)
        )
    if payload.settings.center == "heliocentric":
        incompatible["settings.center"] = (
            "heliocentric charts require separate Earth/Sun-origin and house semantics; "
            "use geocentric or topocentric for natal.standard_chart"
        )
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
    expected_subject_kind = "person" if payload.chart.family == "natal" else "event"
    if subject_version.get("kind") != expected_subject_kind:
        raise _unsupported({
            "subject.kind": (
                f"{payload.chart.technique} requires a {expected_subject_kind!r} subject; "
                "current-sky calculations never reuse or overlay a person"
            )
        })

    request_document = payload.model_dump(mode="json", exclude_none=True)
    try:
        calculation_function = (
            create_date_level_astronomical_snapshot
            if subject_version.get("time_spec", {}).get("precision") in {"date", "unknown"}
            else create_astronomical_snapshot
        )
        snapshot = calculation_function(
            snapshot_id=f"calculation-{uuid4()}",
            request_payload=request_document,
            subject_version=subject_version,
            now=datetime.now(UTC),
            engine_version=request.app.state.settings.service_version,
            adapter=SwissEphemerisAdapter(
                moshier_fallback="record",
                ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
            ),
        )
    except AstronomicalSnapshotInputError as exc:
        request.app.state.account_store.record_event(
            "calculation_failed",
            actor_email=analytics_user["email"] if analytics_user else None,
            success=False,
            duration_ms=round((time.monotonic() - started) * 1_000),
            metadata={**analytics_metadata, "error_code": "astronomical_input"},
        )
        raise _unsupported({"subject.time_spec": str(exc)}) from exc
    request.app.state.workflow_store.put_snapshot(snapshot)
    request.app.state.account_store.record_event(
        "calculation_completed",
        actor_email=analytics_user["email"] if analytics_user else None,
        success=True,
        duration_ms=round((time.monotonic() - started) * 1_000),
        metadata=analytics_metadata,
    )
    return snapshot


def _snapshot_technique(snapshot: dict[str, Any]) -> str | None:
    result = snapshot.get("result")
    charts = result.get("charts") if isinstance(result, dict) else None
    chart = charts[0] if isinstance(charts, list) and charts else None
    return chart.get("technique") if isinstance(chart, dict) else None


def _progressed_subject_version(
    reference_snapshot: dict[str, Any],
    target_date: date,
) -> tuple[dict[str, Any], datetime]:
    normalized = reference_snapshot.get("normalized_input")
    if not isinstance(normalized, dict):
        raise AstronomicalSnapshotInputError(
            "the natal snapshot does not contain its normalized birth input"
        )
    natal_subject = normalized.get("subject_version")
    if not isinstance(natal_subject, dict):
        raise AstronomicalSnapshotInputError(
            "the natal snapshot does not contain a reusable subject version"
        )
    time_spec = natal_subject.get("time_spec")
    location = natal_subject.get("location")
    if not isinstance(time_spec, dict) or not isinstance(location, dict):
        raise AstronomicalSnapshotInputError(
            "secondary progressions require natal time and location"
        )
    if time_spec.get("precision") not in {"minute", "hour"}:
        raise AstronomicalSnapshotInputError(
            "secondary progressions require a known birth time"
        )
    local_value = time_spec.get("local_value")
    timezone_id = time_spec.get("timezone_id") or location.get("timezone_id")
    if not isinstance(local_value, str) or not isinstance(timezone_id, str):
        raise AstronomicalSnapshotInputError(
            "secondary progressions require local birth time and IANA timezone"
        )
    try:
        birth_local = datetime.fromisoformat(local_value)
        zone = ZoneInfo(timezone_id)
    except (ValueError, ZoneInfoNotFoundError) as exc:
        raise AstronomicalSnapshotInputError(
            "the natal local time or timezone cannot be resolved"
        ) from exc
    if birth_local.tzinfo is not None:
        birth_local = birth_local.astimezone(zone).replace(tzinfo=None)
    elapsed_days = (target_date - birth_local.date()).days
    if elapsed_days < 0:
        raise AstronomicalSnapshotInputError(
            "the secondary-progression target date cannot precede birth"
        )

    # Standard secondary progression: one mean tropical year of life maps to
    # one ephemeris day after birth. Retain the natal civil time and place.
    progressed_local = birth_local + timedelta(days=elapsed_days / 365.24219893)
    progressed_zoned = progressed_local.replace(tzinfo=zone)
    progressed_utc = progressed_zoned.astimezone(UTC)
    progressed_subject = deepcopy(natal_subject)
    progressed_subject.update({
        "id": f"progression-subject-{uuid4()}",
        "kind": "event",
        "display_name": (
            f"{natal_subject.get('display_name') or 'Natal subject'} "
            f"secondary progression {target_date.isoformat()}"
        ),
    })
    progressed_utc_text = (
        progressed_utc.replace(microsecond=0).isoformat().replace("+00:00", "Z")
    )
    progressed_subject["time_spec"] = {
        **deepcopy(time_spec),
        "local_value": progressed_local.replace(second=0, microsecond=0).isoformat(
            timespec="minutes"
        ),
        "precision": "minute",
        "selected_utc": progressed_utc_text,
        "utc_candidates": [progressed_utc_text],
        "confidence": time_spec.get("confidence") or "unknown",
        "source": {
            "kind": "derived",
            "description": (
                "Secondary progression: one tropical year of life equals "
                "one ephemeris day after birth"
            ),
        },
        "warnings": [],
    }
    progressed_subject["location"] = deepcopy(location)
    progressed_subject["attributes"] = {
        **deepcopy(natal_subject.get("attributes") or {}),
        "chart_role": "secondary_progression",
        "reference_snapshot_id": reference_snapshot.get("id"),
        "target_date": target_date.isoformat(),
        "progression_key": "1_mean_tropical_year_to_1_day",
    }
    return progressed_subject, progressed_local


@router.post("/calculations/comparisons", status_code=status.HTTP_201_CREATED)
async def create_calculation_comparison(
    payload: ChartComparisonPayload,
    request: Request,
) -> dict[str, Any]:
    try:
        reference_snapshot = (
            payload.reference_snapshot
            if payload.reference_snapshot is not None
            else request.app.state.workflow_store.get_snapshot(
                payload.reference_snapshot_id
            )
        )
        moving_snapshot = request.app.state.workflow_store.get_snapshot(
            payload.moving_snapshot_id
        )
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="One or both comparison snapshots were not found.",
        ) from exc

    expected_techniques = (
        ("natal.standard_chart", "mundane.current_sky")
        if payload.context == "transit"
        else ("natal.standard_chart", "progression.secondary")
    )
    actual_techniques = (
        _snapshot_technique(reference_snapshot),
        _snapshot_technique(moving_snapshot),
    )
    if actual_techniques != expected_techniques:
        raise _unsupported({
            "comparison.snapshots": (
                f"{payload.context} requires {expected_techniques[0]!r} as the fixed "
                f"reference and {expected_techniques[1]!r} as the moving layer"
            )
        })

    try:
        comparison_result = create_cross_chart_comparison(
            reference_snapshot=reference_snapshot,
            moving_snapshot=moving_snapshot,
            settings=payload.settings.model_dump(mode="json", exclude_none=True),
            context=(
                AspectContext.TRANSIT
                if payload.context == "transit"
                else AspectContext.PROGRESSION
            ),
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"comparison.snapshots": str(exc)}) from exc

    comparison = {
        "id": f"comparison-{uuid4()}",
        "status": "complete",
        "maturity": "implemented",
        "result": comparison_result,
        "warnings": [],
    }
    request.app.state.workflow_store.put_snapshot(comparison)
    return comparison


@router.post("/calculations/secondary-progressions", status_code=status.HTTP_201_CREATED)
async def create_secondary_progression(
    payload: SecondaryProgressionPayload,
    request: Request,
) -> dict[str, Any]:
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "secondary progressions require the active person's last natal snapshot"
            )
        })
    try:
        progressed_subject, progressed_local = _progressed_subject_version(
            payload.reference_snapshot,
            payload.target_date,
        )
        settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
        request_document = {
            "subject": {"subject_version_id": progressed_subject["id"]},
            "chart": {
                "family": "progression",
                "technique": "progression.secondary",
            },
            "settings": settings_document,
            "rule_pack_hash": payload.rule_pack_hash,
            "dataset_versions": {},
            "outputs": ["snapshot", "json"],
        }
        progressed_snapshot = create_astronomical_snapshot(
            snapshot_id=f"calculation-{uuid4()}",
            request_payload=request_document,
            subject_version=progressed_subject,
            now=datetime.now(UTC),
            engine_version=request.app.state.settings.service_version,
            adapter=SwissEphemerisAdapter(
                moshier_fallback="record",
                ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
            ),
        )
        comparison_result = create_cross_chart_comparison(
            reference_snapshot=payload.reference_snapshot,
            moving_snapshot=progressed_snapshot,
            settings=settings_document,
            context=AspectContext.PROGRESSION,
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"secondary_progression": str(exc)}) from exc

    comparison = {
        "id": f"comparison-{uuid4()}",
        "status": "complete",
        "maturity": "implemented",
        "result": comparison_result,
        "warnings": [],
    }
    request.app.state.workflow_store.put_snapshot(progressed_snapshot)
    request.app.state.workflow_store.put_snapshot(comparison)
    return {
        "id": f"secondary-progression-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "target_date": payload.target_date.isoformat(),
        "progressed_time": progressed_local.replace(
            second=0, microsecond=0
        ).isoformat(timespec="minutes"),
        "progressed_snapshot": progressed_snapshot,
        "comparison": comparison,
    }


@router.get("/calculations/{snapshot_id}/tables/{table_id}")
async def get_calculation_table(
    snapshot_id: str,
    table_id: str,
    request: Request,
    output_format: Literal["json", "csv"] = Query(default="json", alias="format"),
) -> Response:
    try:
        snapshot = request.app.state.workflow_store.get_snapshot(snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Calculation snapshot was not found.",
        ) from exc
    try:
        table = build_snapshot_table(snapshot, table_id)
    except SnapshotTableError as exc:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.INVALID_REQUEST,
            detail=str(exc),
        ) from exc

    headers = {
        "Content-Disposition": f'attachment; filename="{snapshot_id}-{table_id}.{output_format}"',
        "X-Interstellar-Snapshot-ID": snapshot_id,
        "X-Interstellar-Input-Fingerprint": snapshot["input_fingerprint"],
    }
    if output_format == "csv":
        return Response(
            content=table.to_csv().encode("utf-8"),
            media_type="text/csv; charset=utf-8",
            headers=headers,
        )
    return Response(
        content=table_json_bytes(table),
        media_type="application/json",
        headers=headers,
    )


@router.get("/calculations/{snapshot_id}/exports/natal-technical")
async def get_natal_technical_export(
    snapshot_id: str,
    request: Request,
    output_format: Literal["markdown", "plaintext"] = Query(
        default="markdown",
        alias="format",
    ),
) -> Response:
    try:
        snapshot = request.app.state.workflow_store.get_snapshot(snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Calculation snapshot was not found.",
        ) from exc
    try:
        document_hash = natal_technical_document_content_hash(snapshot)
        document = render_natal_technical_document(
            snapshot,
            output_format=output_format,
        )
    except NatalTechnicalExportError as exc:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.INVALID_REQUEST,
            detail=str(exc),
        ) from exc
    extension = "md" if output_format == "markdown" else "txt"
    user = current_user(request)
    request.app.state.account_store.record_event(
        "report_exported",
        actor_email=user["email"] if user else None,
        success=True,
        metadata={"export_format": output_format, "analysis_type": "natal"},
    )
    return Response(
        content=document.encode("utf-8"),
        media_type=(
            "text/markdown; charset=utf-8"
            if output_format == "markdown"
            else "text/plain; charset=utf-8"
        ),
        headers={
            "Content-Disposition": (
                f'attachment; filename="{snapshot_id}-natal-technical.{extension}"'
            ),
            "X-Interstellar-Snapshot-ID": snapshot_id,
            "X-Interstellar-Input-Fingerprint": snapshot["input_fingerprint"],
            "X-Interstellar-Document-Hash": document_hash,
            "ETag": f'"{document_hash}"',
            "Cache-Control": "private, no-transform",
        },
    )
