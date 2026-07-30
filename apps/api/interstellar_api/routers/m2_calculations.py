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
    resolve_aspect_profiles,
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
from interstellar_core.astrology.aspects import (
    AspectContext,
    AspectPoint,
    find_major_aspects,
)
from interstellar_core.astronomy.adapters import AYANAMSA_MODES, SwissEphemerisAdapter
from interstellar_core.astronomy.adapters.swiss_ephemeris import SIGN_IDS
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


class TertiaryProgressionPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    target_date: date
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


class SolarReturnPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    target_year: int = Field(ge=1800, le=2200)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    residence_name: str | None = Field(default=None, max_length=200)
    timezone_id: str | None = Field(default=None, max_length=80)
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


class LunarReturnPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    reference_date: date | None = None
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    residence_name: str | None = Field(default=None, max_length=200)
    timezone_id: str | None = Field(default=None, max_length=80)
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


class SolarArcPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    target_date: date
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


class RelocationPayload(StrictModel):
    reference_snapshot: dict[str, Any]
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    residence_name: str | None = Field(default=None, max_length=200)
    timezone_id: str | None = Field(default=None, max_length=80)
    settings: ChartSettingsPayload
    rule_pack_hash: str = Field(
        pattern=r"^(?:sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$"
    )


class HarmonicChartPayload(StrictModel):
    reference_snapshot: dict[str, Any]
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


def _secondary_snapshot_for_target(
    *,
    reference_snapshot: dict[str, Any],
    target_date: date,
    settings_document: dict[str, Any],
    rule_pack_hash: str,
    engine_version: str,
    adapter: SwissEphemerisAdapter,
) -> dict[str, Any]:
    progressed_subject, _progressed_local = _progressed_subject_version(
        reference_snapshot,
        target_date,
    )
    return create_astronomical_snapshot(
        snapshot_id=f"calculation-{uuid4()}",
        request_payload={
            "subject": {"subject_version_id": progressed_subject["id"]},
            "chart": {"family": "progression", "technique": "progression.secondary"},
            "settings": settings_document,
            "rule_pack_hash": rule_pack_hash,
            "dataset_versions": {},
            "outputs": ["snapshot", "json"],
        },
        subject_version=progressed_subject,
        now=datetime.now(UTC),
        engine_version=engine_version,
        adapter=adapter,
    )


def _snapshot_point_sign(snapshot: dict[str, Any], point_id: str) -> str | None:
    result = snapshot.get("result")
    points = result.get("points") if isinstance(result, dict) else None
    if not isinstance(points, list):
        return None
    for point in points:
        if isinstance(point, dict) and point.get("point_id") == point_id:
            sign = point.get("sign")
            return sign if isinstance(sign, str) else None
    return None


def _natal_birth_date(reference_snapshot: dict[str, Any]) -> date:
    normalized = reference_snapshot.get("normalized_input")
    natal_subject = normalized.get("subject_version") if isinstance(normalized, dict) else None
    time_spec = natal_subject.get("time_spec") if isinstance(natal_subject, dict) else None
    local_value = time_spec.get("local_value") if isinstance(time_spec, dict) else None
    if not isinstance(local_value, str):
        raise AstronomicalSnapshotInputError(
            "the natal snapshot does not contain a reusable local birth date"
        )
    return datetime.fromisoformat(local_value).date()


def _find_secondary_sign_boundary(
    *,
    reference_snapshot: dict[str, Any],
    target_date: date,
    settings_document: dict[str, Any],
    rule_pack_hash: str,
    engine_version: str,
    adapter: SwissEphemerisAdapter,
    point_id: str,
    current_sign: str,
    direction: Literal["ingress", "egress"],
    step_days: int,
    max_years: int,
) -> tuple[date | None, str]:
    birth_date = _natal_birth_date(reference_snapshot)

    def sign_at(day: date) -> str | None:
        if day < birth_date:
            return None
        snapshot = _secondary_snapshot_for_target(
            reference_snapshot=reference_snapshot,
            target_date=day,
            settings_document=settings_document,
            rule_pack_hash=rule_pack_hash,
            engine_version=engine_version,
            adapter=adapter,
        )
        return _snapshot_point_sign(snapshot, point_id)

    if direction == "ingress":
        inside = target_date
        outside = target_date
        for _ in range(max_years * 366 // step_days + 2):
            candidate = max(birth_date, outside - timedelta(days=step_days))
            if candidate == outside:
                return birth_date, "birth_or_before"
            if sign_at(candidate) != current_sign:
                outside = candidate
                break
            outside = candidate
            inside = candidate
        else:
            return None, "not_found"
        low = outside
        high = inside
        while (high - low).days > 1:
            mid = low + timedelta(days=(high - low).days // 2)
            if sign_at(mid) == current_sign:
                high = mid
            else:
                low = mid
        return high, "found"

    inside = target_date
    outside = target_date
    for _ in range(max_years * 366 // step_days + 2):
        candidate = outside + timedelta(days=step_days)
        if sign_at(candidate) != current_sign:
            outside = candidate
            break
        outside = candidate
        inside = candidate
    else:
        return None, "not_found"
    low = inside
    high = outside
    while (high - low).days > 1:
        mid = low + timedelta(days=(high - low).days // 2)
        if sign_at(mid) == current_sign:
            low = mid
        else:
            high = mid
    return high, "found"


def _secondary_sign_periods(
    *,
    reference_snapshot: dict[str, Any],
    target_date: date,
    progressed_snapshot: dict[str, Any],
    settings_document: dict[str, Any],
    rule_pack_hash: str,
    engine_version: str,
    adapter: SwissEphemerisAdapter,
) -> list[dict[str, Any]]:
    periods: list[dict[str, Any]] = []
    for point_id, step_days, max_years in (("moon", 45, 5), ("sun", 366, 40)):
        sign = _snapshot_point_sign(progressed_snapshot, point_id)
        if sign is None:
            continue
        ingress, ingress_status = _find_secondary_sign_boundary(
            reference_snapshot=reference_snapshot,
            target_date=target_date,
            settings_document=settings_document,
            rule_pack_hash=rule_pack_hash,
            engine_version=engine_version,
            adapter=adapter,
            point_id=point_id,
            current_sign=sign,
            direction="ingress",
            step_days=step_days,
            max_years=max_years,
        )
        egress, egress_status = _find_secondary_sign_boundary(
            reference_snapshot=reference_snapshot,
            target_date=target_date,
            settings_document=settings_document,
            rule_pack_hash=rule_pack_hash,
            engine_version=engine_version,
            adapter=adapter,
            point_id=point_id,
            current_sign=sign,
            direction="egress",
            step_days=step_days,
            max_years=max_years,
        )
        periods.append({
            "point_id": point_id,
            "sign": sign,
            "ingress_date": ingress.isoformat() if ingress else None,
            "egress_date": egress.isoformat() if egress else None,
            "ingress_status": ingress_status,
            "egress_status": egress_status,
            "boundary_resolution": "date",
        })
    return periods


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
        adapter = SwissEphemerisAdapter(
            moshier_fallback="record",
            ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
        )
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
            adapter=adapter,
        )
        progressed_sign_periods = _secondary_sign_periods(
            reference_snapshot=payload.reference_snapshot,
            target_date=payload.target_date,
            progressed_snapshot=progressed_snapshot,
            settings_document=settings_document,
            rule_pack_hash=payload.rule_pack_hash,
            engine_version=request.app.state.settings.service_version,
            adapter=adapter,
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
        "progressed_sign_periods": progressed_sign_periods,
        "comparison": comparison,
    }


# ---------------------------------------------------------------------------
# Shared helpers for the additional timing/derived chart endpoints.
# ---------------------------------------------------------------------------


def _natal_subject_context(
    reference_snapshot: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], datetime, ZoneInfo]:
    """Extract the natal subject, time spec, location and local birth moment."""
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
            "the natal snapshot lacks reusable time and location"
        )
    if time_spec.get("precision") not in {"minute", "hour"}:
        raise AstronomicalSnapshotInputError(
            "this technique requires a known birth time"
        )
    local_value = time_spec.get("local_value")
    timezone_id = time_spec.get("timezone_id") or location.get("timezone_id")
    if not isinstance(local_value, str) or not isinstance(timezone_id, str):
        raise AstronomicalSnapshotInputError(
            "this technique requires local birth time and IANA timezone"
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
    return natal_subject, time_spec, location, birth_local, zone


def _event_subject_version(
    *,
    natal_subject: dict[str, Any],
    time_spec: dict[str, Any],
    location: dict[str, Any],
    utc_instant: datetime,
    chart_role: str,
    technique_description: str,
    display_label: str,
    extra_attributes: dict[str, Any],
) -> dict[str, Any]:
    """Build a derived event subject around an already-known UTC instant.

    The snapshot pipeline trusts ``selected_utc`` as the authoritative moment;
    ``local_value`` is derived from the location timezone for display only.
    """
    timezone_id = (
        time_spec.get("timezone_id") or location.get("timezone_id") or "UTC"
    )
    try:
        zone = ZoneInfo(str(timezone_id))
    except ZoneInfoNotFoundError as exc:
        raise AstronomicalSnapshotInputError(
            f"the timezone {timezone_id!r} cannot be resolved"
        ) from exc
    local_dt = utc_instant.astimezone(zone)
    utc_text = (
        utc_instant.astimezone(UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )
    subject = deepcopy(natal_subject)
    subject.update({
        "id": f"{chart_role}-subject-{uuid4()}",
        "kind": "event",
        "display_name": (
            f"{natal_subject.get('display_name') or 'Natal subject'} {display_label}"
        ),
    })
    subject["time_spec"] = {
        **deepcopy(time_spec),
        "timezone_id": str(timezone_id),
        "local_value": local_dt.replace(second=0, microsecond=0).isoformat(
            timespec="minutes"
        ),
        "precision": "minute",
        "selected_utc": utc_text,
        "utc_candidates": [utc_text],
        "confidence": time_spec.get("confidence") or "unknown",
        "source": {"kind": "derived", "description": technique_description},
        "warnings": [],
    }
    subject["location"] = deepcopy(location)
    subject["attributes"] = {
        **deepcopy(natal_subject.get("attributes") or {}),
        "chart_role": chart_role,
        **extra_attributes,
    }
    return subject


def _snapshot_point_longitude(snapshot: dict[str, Any], point_id: str) -> float:
    result = snapshot.get("result")
    points = result.get("points") if isinstance(result, dict) else None
    if isinstance(points, list):
        for point in points:
            if not isinstance(point, dict) or point.get("point_id") != point_id:
                continue
            position = point.get("position")
            ecliptic = position.get("ecliptic") if isinstance(position, dict) else None
            longitude = ecliptic.get("longitude_deg") if isinstance(ecliptic, dict) else None
            if isinstance(longitude, (int, float)):
                return float(longitude) % 360
    raise AstronomicalSnapshotInputError(
        f"the natal snapshot has no {point_id} longitude"
    )


def _reference_zodiac(reference_snapshot: dict[str, Any]) -> tuple[str, str | None]:
    """Return the zodiac/ayanamsa the natal snapshot longitudes were computed in."""
    request_payload = reference_snapshot.get("request")
    settings = (
        request_payload.get("settings") if isinstance(request_payload, dict) else None
    )
    if not isinstance(settings, dict):
        return "tropical", None
    zodiac = settings.get("zodiac")
    ayanamsa = settings.get("ayanamsa")
    return (
        str(zodiac) if zodiac in {"tropical", "sidereal"} else "tropical",
        str(ayanamsa) if isinstance(ayanamsa, str) else None,
    )


def _angular_delta(longitude: float, target: float) -> float:
    """Signed shortest angular distance from target to longitude, in [-180, 180)."""
    return (longitude - target + 540.0) % 360.0 - 180.0


def _find_return_instant(
    *,
    adapter: SwissEphemerisAdapter,
    natal_longitude: float,
    point_id: Literal["sun", "moon"],
    estimate_utc: datetime,
    window_back_days: float,
    window_forward_days: float,
    zodiac: str,
    ayanamsa: str | None,
    nearest: bool,
) -> datetime:
    """Locate the UTC instant the point returns to its natal longitude.

    A coarse 6-hour scan brackets sign changes of the angular delta, then a
    bisection refines the crossing to about one minute of time.
    """
    zodiac_mode: Literal["tropical", "sidereal"] = (
        "sidereal" if zodiac == "sidereal" else "tropical"
    )

    def longitude_at(moment: datetime) -> float:
        result = adapter.calculate(
            utc_instant=moment,
            point_ids=[point_id],
            zodiac=zodiac_mode,
            ayanamsa=ayanamsa,
        )
        point = result.points[0]
        return float(point["position"]["ecliptic"]["longitude_deg"]) % 360

    step = timedelta(hours=6)
    start = estimate_utc - timedelta(days=window_back_days)
    end = estimate_utc + timedelta(days=window_forward_days)
    crossings: list[tuple[datetime, datetime]] = []
    previous_moment = start
    previous_delta = _angular_delta(longitude_at(start), natal_longitude)
    current = start + step
    while current <= end:
        current_delta = _angular_delta(longitude_at(current), natal_longitude)
        if previous_delta < 0 <= current_delta and (current_delta - previous_delta) < 180:
            crossings.append((previous_moment, current))
        previous_moment = current
        previous_delta = current_delta
        current += step
    if not crossings:
        raise AstronomicalSnapshotInputError(
            f"no {point_id} return to the natal longitude was found in the search window"
        )
    if nearest:
        low, high = min(
            crossings,
            key=lambda pair: min(
                abs((pair[0] - estimate_utc).total_seconds()),
                abs((pair[1] - estimate_utc).total_seconds()),
            ),
        )
    else:
        low, high = crossings[0]
    while (high - low) > timedelta(seconds=60):
        mid = low + (high - low) / 2
        if _angular_delta(longitude_at(mid), natal_longitude) < 0:
            low = mid
        else:
            high = mid
    return high


def _self_aspects(
    points: list[Any],
    settings_document: dict[str, Any],
) -> list[dict[str, Any]]:
    """Recompute mutual aspects for a mathematically derived chart."""
    aspect_profile, orb_profile, orb_overrides = resolve_aspect_profiles(
        settings_document
    )
    aspect_points: list[AspectPoint] = []
    for point in points:
        if not isinstance(point, dict):
            continue
        point_id = point.get("point_id")
        position = point.get("position")
        ecliptic = position.get("ecliptic") if isinstance(position, dict) else None
        longitude = ecliptic.get("longitude_deg") if isinstance(ecliptic, dict) else None
        if isinstance(point_id, str) and isinstance(longitude, (int, float)):
            aspect_points.append(
                AspectPoint(
                    id=point_id,
                    longitude_deg=float(longitude),
                    longitude_speed_deg_per_day=0.0,
                )
            )
    found: list[dict[str, Any]] = []
    for index, left in enumerate(aspect_points):
        for right in aspect_points[index + 1 :]:
            for aspect in find_major_aspects(
                left,
                right,
                context=AspectContext.PROGRESSION,
                major_profile=aspect_profile,
                orb_profile=orb_profile,
                orb_overrides=orb_overrides,
            ):
                fact = aspect.to_dict()
                fact.update({
                    "aspect_id": f"derived.{left.id}.{right.id}.{aspect.type}",
                    "point_a": left.id,
                    "point_b": right.id,
                })
                found.append(fact)
    found.sort(
        key=lambda item: (
            float(item["orb_deg"]),
            str(item["point_a"]),
            str(item["point_b"]),
        )
    )
    return found


_DERIVED_ONLY_RESULT_KEYS = (
    "structure",
    "patterns",
    "classical",
    "dignities",
    "receptions",
    "dispositors",
    "midpoints",
    "mirror_points",
    "special_degrees",
    "profections",
    "firdaria",
    "zodiacal_releasing",
    "lots",
    "fixed_star_contacts",
    "distributions",
)


def _shifted_snapshot(
    *,
    reference_snapshot: dict[str, Any],
    transform_description: str,
    transform: Any,
    family: str,
    technique: str,
    shift_houses: bool,
    recompute_aspects: bool,
    settings_document: dict[str, Any],
) -> dict[str, Any]:
    """Derive a chart by transforming every natal longitude mathematically.

    Solar arc directions shift all longitudes by one arc; harmonic charts
    multiply them. Point-in-house assignments intentionally keep the natal
    values: with shifted houses the relative placement is unchanged, and for
    harmonic charts the natal house is the interpretively meaningful fact.
    """
    derived = deepcopy(reference_snapshot)
    derived["id"] = f"calculation-{uuid4()}"
    derived["status"] = "complete"
    derived["maturity"] = "implemented"
    result = derived.get("result")
    if not isinstance(result, dict):
        raise AstronomicalSnapshotInputError("the natal snapshot has no result payload")
    points = result.get("points")
    if not isinstance(points, list):
        raise AstronomicalSnapshotInputError("the natal snapshot has no points")
    for point in points:
        if not isinstance(point, dict):
            continue
        position = point.get("position")
        ecliptic = position.get("ecliptic") if isinstance(position, dict) else None
        longitude = ecliptic.get("longitude_deg") if isinstance(ecliptic, dict) else None
        if not isinstance(longitude, (int, float)):
            continue
        shifted = float(transform(float(longitude))) % 360
        sign_index = min(int(shifted // 30), 11)
        ecliptic["longitude_deg"] = shifted
        point["sign"] = SIGN_IDS[sign_index]
        point["degree_in_sign"] = shifted - sign_index * 30
    if shift_houses:
        houses = result.get("houses")
        if isinstance(houses, list):
            for house in houses:
                if not isinstance(house, dict):
                    continue
                cusp = house.get("cusp_longitude_deg")
                if not isinstance(cusp, (int, float)):
                    continue
                shifted = float(transform(float(cusp))) % 360
                sign_index = min(int(shifted // 30), 11)
                house["cusp_longitude_deg"] = shifted
                house["sign"] = SIGN_IDS[sign_index]
                house["degree_in_sign"] = shifted - sign_index * 30
    charts = result.get("charts")
    if isinstance(charts, list) and charts and isinstance(charts[0], dict):
        charts[0]["family"] = family
        charts[0]["technique"] = technique
    request_payload = derived.get("request")
    if isinstance(request_payload, dict):
        request_payload["chart"] = {"family": family, "technique": technique}
        request_payload["settings"] = deepcopy(settings_document)
    if recompute_aspects:
        result["aspects"] = _self_aspects(points, settings_document)
    for key in _DERIVED_ONLY_RESULT_KEYS:
        result.pop(key, None)
    warnings = derived.get("warnings")
    if isinstance(warnings, list):
        warnings.append({
            "code": "DERIVED_CHART_TRANSFORM",
            "message": transform_description,
        })
    return derived


def _store_comparison(
    *,
    request: Request,
    reference_snapshot: dict[str, Any],
    moving_snapshot: dict[str, Any],
    settings_document: dict[str, Any],
) -> dict[str, Any]:
    comparison_result = create_cross_chart_comparison(
        reference_snapshot=reference_snapshot,
        moving_snapshot=moving_snapshot,
        settings=settings_document,
        context=AspectContext.PROGRESSION,
    )
    comparison = {
        "id": f"comparison-{uuid4()}",
        "status": "complete",
        "maturity": "implemented",
        "result": comparison_result,
        "warnings": [],
    }
    request.app.state.workflow_store.put_snapshot(moving_snapshot)
    request.app.state.workflow_store.put_snapshot(comparison)
    return comparison


@router.post("/calculations/tertiary-progressions", status_code=status.HTTP_201_CREATED)
async def create_tertiary_progression(
    payload: TertiaryProgressionPayload,
    request: Request,
) -> dict[str, Any]:
    """Tertiary progression: one month of life equals one ephemeris day."""
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "tertiary progressions require the active person's last natal snapshot"
            )
        })
    try:
        natal_subject, time_spec, location, birth_local, zone = (
            _natal_subject_context(payload.reference_snapshot)
        )
        elapsed_days = (payload.target_date - birth_local.date()).days
        if elapsed_days < 0:
            raise AstronomicalSnapshotInputError(
                "the tertiary-progression target date cannot precede birth"
            )
        elapsed_months = elapsed_days / (365.24219893 / 12.0)
        progressed_local = birth_local + timedelta(days=elapsed_months)
        progressed_utc = progressed_local.replace(tzinfo=zone).astimezone(UTC)
        progressed_subject = _event_subject_version(
            natal_subject=natal_subject,
            time_spec=time_spec,
            location=location,
            utc_instant=progressed_utc,
            chart_role="tertiary_progression",
            technique_description=(
                "Tertiary progression: one mean month of life equals "
                "one ephemeris day after birth"
            ),
            display_label=f"tertiary progression {payload.target_date.isoformat()}",
            extra_attributes={
                "reference_snapshot_id": payload.reference_snapshot.get("id"),
                "target_date": payload.target_date.isoformat(),
                "progression_key": "1_mean_month_to_1_day",
            },
        )
        settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
        adapter = SwissEphemerisAdapter(
            moshier_fallback="record",
            ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
        )
        progressed_snapshot = create_astronomical_snapshot(
            snapshot_id=f"calculation-{uuid4()}",
            request_payload={
                "subject": {"subject_version_id": progressed_subject["id"]},
                "chart": {"family": "progression", "technique": "progression.tertiary"},
                "settings": settings_document,
                "rule_pack_hash": payload.rule_pack_hash,
                "dataset_versions": {},
                "outputs": ["snapshot", "json"],
            },
            subject_version=progressed_subject,
            now=datetime.now(UTC),
            engine_version=request.app.state.settings.service_version,
            adapter=adapter,
        )
        comparison = _store_comparison(
            request=request,
            reference_snapshot=payload.reference_snapshot,
            moving_snapshot=progressed_snapshot,
            settings_document=settings_document,
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"tertiary_progression": str(exc)}) from exc
    return {
        "id": f"tertiary-progression-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "target_date": payload.target_date.isoformat(),
        "progressed_time": progressed_local.replace(
            second=0, microsecond=0
        ).isoformat(timespec="minutes"),
        "progressed_snapshot": progressed_snapshot,
        "comparison": comparison,
    }


def _residence_location(
    *,
    natal_location: dict[str, Any],
    latitude: float,
    longitude: float,
    residence_name: str | None,
    timezone_id: str | None,
) -> dict[str, Any]:
    location = deepcopy(natal_location)
    location.update({
        "name": residence_name or natal_location.get("name"),
        "latitude": latitude,
        "longitude": longitude,
        "timezone_id": timezone_id or natal_location.get("timezone_id"),
        "source": "user_input",
        "warnings": [],
    })
    return location


def _create_return_chart(
    *,
    payload: SolarReturnPayload | LunarReturnPayload,
    request: Request,
    point_id: Literal["sun", "moon"],
    chart_role: str,
    family: str,
    technique: str,
    display_label: str,
    estimate_utc: datetime,
    window_back_days: float,
    window_forward_days: float,
    extra_attributes: dict[str, Any],
) -> dict[str, Any]:
    natal_subject, time_spec, _natal_location, _birth_local, _zone = (
        _natal_subject_context(payload.reference_snapshot)
    )
    residence = _residence_location(
        natal_location=_natal_location,
        latitude=payload.latitude,
        longitude=payload.longitude,
        residence_name=payload.residence_name,
        timezone_id=payload.timezone_id,
    )
    zodiac, ayanamsa = _reference_zodiac(payload.reference_snapshot)
    natal_longitude = _snapshot_point_longitude(payload.reference_snapshot, point_id)
    adapter = SwissEphemerisAdapter(
        moshier_fallback="record",
        ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
    )
    return_utc = _find_return_instant(
        adapter=adapter,
        natal_longitude=natal_longitude,
        point_id=point_id,
        estimate_utc=estimate_utc,
        window_back_days=window_back_days,
        window_forward_days=window_forward_days,
        zodiac=zodiac,
        ayanamsa=ayanamsa,
        nearest=True,
    )
    return_subject = _event_subject_version(
        natal_subject=natal_subject,
        time_spec={
            **time_spec,
            "timezone_id": residence.get("timezone_id")
            or time_spec.get("timezone_id"),
        },
        location=residence,
        utc_instant=return_utc,
        chart_role=chart_role,
        technique_description=(
            f"{display_label}: exact {point_id} return to the natal longitude"
        ),
        display_label=display_label,
        extra_attributes={
            "reference_snapshot_id": payload.reference_snapshot.get("id"),
            **extra_attributes,
        },
    )
    settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
    return_snapshot = create_astronomical_snapshot(
        snapshot_id=f"calculation-{uuid4()}",
        request_payload={
            "subject": {"subject_version_id": return_subject["id"]},
            "chart": {"family": family, "technique": technique},
            "settings": settings_document,
            "rule_pack_hash": payload.rule_pack_hash,
            "dataset_versions": {},
            "outputs": ["snapshot", "json"],
        },
        subject_version=return_subject,
        now=datetime.now(UTC),
        engine_version=request.app.state.settings.service_version,
        adapter=adapter,
    )
    comparison = _store_comparison(
        request=request,
        reference_snapshot=payload.reference_snapshot,
        moving_snapshot=return_snapshot,
        settings_document=settings_document,
    )
    return {
        "return_snapshot": return_snapshot,
        "comparison": comparison,
        "return_time_utc": (
            return_utc.astimezone(UTC)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z")
        ),
    }


@router.post("/calculations/solar-return", status_code=status.HTTP_201_CREATED)
async def create_solar_return(
    payload: SolarReturnPayload,
    request: Request,
) -> dict[str, Any]:
    """Solar return: the moment the Sun returns to its natal longitude."""
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "solar returns require the active person's last natal snapshot"
            )
        })
    try:
        _subject, _ts, _loc, birth_local, zone = _natal_subject_context(
            payload.reference_snapshot
        )
        try:
            estimate_local = birth_local.replace(year=payload.target_year)
        except ValueError:
            estimate_local = birth_local.replace(
                year=payload.target_year, day=28
            )
        estimate_utc = estimate_local.replace(tzinfo=zone).astimezone(UTC)
        outcome = _create_return_chart(
            payload=payload,
            request=request,
            point_id="sun",
            chart_role="solar_return",
            family="return",
            technique="return.solar",
            display_label=f"solar return {payload.target_year}",
            estimate_utc=estimate_utc,
            window_back_days=4.0,
            window_forward_days=4.0,
            extra_attributes={"target_year": payload.target_year},
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"solar_return": str(exc)}) from exc
    return {
        "id": f"solar-return-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "target_year": payload.target_year,
        **outcome,
    }


@router.post("/calculations/lunar-return", status_code=status.HTTP_201_CREATED)
async def create_lunar_return(
    payload: LunarReturnPayload,
    request: Request,
) -> dict[str, Any]:
    """Lunar return: the moment the Moon returns to its natal longitude."""
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "lunar returns require the active person's last natal snapshot"
            )
        })
    reference_date = payload.reference_date or datetime.now(UTC).date()
    estimate_utc = datetime(
        reference_date.year,
        reference_date.month,
        reference_date.day,
        12,
        tzinfo=UTC,
    )
    try:
        outcome = _create_return_chart(
            payload=payload,
            request=request,
            point_id="moon",
            chart_role="lunar_return",
            family="return",
            technique="return.lunar",
            display_label=f"lunar return near {reference_date.isoformat()}",
            estimate_utc=estimate_utc,
            window_back_days=28.0,
            window_forward_days=28.0,
            extra_attributes={"reference_date": reference_date.isoformat()},
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"lunar_return": str(exc)}) from exc
    return {
        "id": f"lunar-return-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "reference_date": reference_date.isoformat(),
        **outcome,
    }


@router.post("/calculations/solar-arc", status_code=status.HTTP_201_CREATED)
async def create_solar_arc(
    payload: SolarArcPayload,
    request: Request,
) -> dict[str, Any]:
    """Solar arc direction: every natal longitude shifted by the Sun's
    secondary-progression arc."""
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "solar arc directions require the active person's last natal snapshot"
            )
        })
    try:
        progressed_subject, progressed_local = _progressed_subject_version(
            payload.reference_snapshot,
            payload.target_date,
        )
        progressed_utc_text = str(
            progressed_subject["time_spec"]["selected_utc"]
        ).replace("Z", "+00:00")
        progressed_utc = datetime.fromisoformat(progressed_utc_text)
        zodiac, ayanamsa = _reference_zodiac(payload.reference_snapshot)
        natal_sun = _snapshot_point_longitude(payload.reference_snapshot, "sun")
        adapter = SwissEphemerisAdapter(
            moshier_fallback="record",
            ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
        )
        progressed_ephemeris = adapter.calculate(
            utc_instant=progressed_utc,
            point_ids=["sun"],
            zodiac="sidereal" if zodiac == "sidereal" else "tropical",
            ayanamsa=ayanamsa,
        )
        progressed_sun = (
            float(
                progressed_ephemeris.points[0]["position"]["ecliptic"][
                    "longitude_deg"
                ]
            )
            % 360
        )
        arc_deg = (progressed_sun - natal_sun) % 360
        settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
        directed_snapshot = _shifted_snapshot(
            reference_snapshot=payload.reference_snapshot,
            transform_description=(
                f"Solar arc direction: all natal longitudes shifted by "
                f"{arc_deg:.4f} degrees (Sun's secondary-progression arc)"
            ),
            transform=lambda longitude: longitude + arc_deg,
            family="direction",
            technique="direction.solar_arc",
            shift_houses=True,
            recompute_aspects=False,
            settings_document=settings_document,
        )
        comparison = _store_comparison(
            request=request,
            reference_snapshot=payload.reference_snapshot,
            moving_snapshot=directed_snapshot,
            settings_document=settings_document,
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"solar_arc": str(exc)}) from exc
    return {
        "id": f"solar-arc-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "target_date": payload.target_date.isoformat(),
        "arc_deg": arc_deg,
        "progressed_time": progressed_local.replace(
            second=0, microsecond=0
        ).isoformat(timespec="minutes"),
        "directed_snapshot": directed_snapshot,
        "comparison": comparison,
    }


@router.post("/calculations/relocation", status_code=status.HTTP_201_CREATED)
async def create_relocation(
    payload: RelocationPayload,
    request: Request,
) -> dict[str, Any]:
    """Relocation chart: same birth instant, new place; houses/angles recalculated."""
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "relocation charts require the active person's last natal snapshot"
            )
        })
    try:
        natal_subject, time_spec, natal_location, birth_local, zone = (
            _natal_subject_context(payload.reference_snapshot)
        )
        natal_utc_text = time_spec.get("selected_utc")
        if not isinstance(natal_utc_text, str):
            natal_utc = birth_local.replace(tzinfo=zone).astimezone(UTC)
        else:
            natal_utc = datetime.fromisoformat(
                natal_utc_text.replace("Z", "+00:00")
            ).astimezone(UTC)
        relocated_location = _residence_location(
            natal_location=natal_location,
            latitude=payload.latitude,
            longitude=payload.longitude,
            residence_name=payload.residence_name,
            timezone_id=payload.timezone_id,
        )
        relocated_timezone = str(
            relocated_location.get("timezone_id")
            or time_spec.get("timezone_id")
            or "UTC"
        )
        try:
            relocated_zone = ZoneInfo(relocated_timezone)
        except ZoneInfoNotFoundError as exc:
            raise AstronomicalSnapshotInputError(
                f"the timezone {relocated_timezone!r} cannot be resolved"
            ) from exc
        relocated_local = natal_utc.astimezone(relocated_zone)
        natal_utc_normalized = (
            natal_utc.replace(microsecond=0).isoformat().replace("+00:00", "Z")
        )
        relocated_subject = deepcopy(natal_subject)
        relocated_subject.update({
            "id": f"relocation-subject-{uuid4()}",
            "kind": "person",
            "display_name": (
                f"{natal_subject.get('display_name') or 'Natal subject'} "
                f"relocation {payload.residence_name or 'new location'}"
            ),
        })
        relocated_subject["time_spec"] = {
            **deepcopy(time_spec),
            "timezone_id": relocated_timezone,
            "local_value": relocated_local.replace(
                second=0, microsecond=0
            ).isoformat(timespec="minutes"),
            "precision": "minute",
            "selected_utc": natal_utc_normalized,
            "utc_candidates": [natal_utc_normalized],
            "confidence": time_spec.get("confidence") or "unknown",
            "source": {
                "kind": "derived",
                "description": (
                    "Relocation: identical birth instant recalculated "
                    "for a new location"
                ),
            },
            "warnings": [],
        }
        relocated_subject["location"] = relocated_location
        relocated_subject["attributes"] = {
            **deepcopy(natal_subject.get("attributes") or {}),
            "chart_role": "relocation",
            "reference_snapshot_id": payload.reference_snapshot.get("id"),
        }
        settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
        adapter = SwissEphemerisAdapter(
            moshier_fallback="record",
            ephemeris_path=request.app.state.settings.swiss_ephemeris_path,
        )
        relocated_snapshot = create_astronomical_snapshot(
            snapshot_id=f"calculation-{uuid4()}",
            request_payload={
                "subject": {"subject_version_id": relocated_subject["id"]},
                "chart": {"family": "relocation", "technique": "relocation.chart"},
                "settings": settings_document,
                "rule_pack_hash": payload.rule_pack_hash,
                "dataset_versions": {},
                "outputs": ["snapshot", "json"],
            },
            subject_version=relocated_subject,
            now=datetime.now(UTC),
            engine_version=request.app.state.settings.service_version,
            adapter=adapter,
        )
        request.app.state.workflow_store.put_snapshot(relocated_snapshot)
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({"relocation": str(exc)}) from exc
    return {
        "id": f"relocation-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "residence": {
            "name": relocated_location.get("name"),
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "timezone_id": relocated_timezone,
        },
        "relocated_snapshot": relocated_snapshot,
    }


def _create_harmonic_chart(
    *,
    payload: HarmonicChartPayload,
    request: Request,
    harmonic: int,
    technique: str,
) -> dict[str, Any]:
    if _snapshot_technique(payload.reference_snapshot) != "natal.standard_chart":
        raise _unsupported({
            "reference_snapshot": (
                "harmonic charts require the active person's last natal snapshot"
            )
        })
    try:
        settings_document = payload.settings.model_dump(mode="json", exclude_none=True)
        harmonic_snapshot = _shifted_snapshot(
            reference_snapshot=payload.reference_snapshot,
            transform_description=(
                f"Harmonic {harmonic}: every natal longitude multiplied by "
                f"{harmonic} modulo 360 degrees"
            ),
            transform=lambda longitude: longitude * harmonic,
            family="harmonic",
            technique=technique,
            shift_houses=False,
            recompute_aspects=True,
            settings_document=settings_document,
        )
        comparison = _store_comparison(
            request=request,
            reference_snapshot=payload.reference_snapshot,
            moving_snapshot=harmonic_snapshot,
            settings_document=settings_document,
        )
    except AstronomicalSnapshotInputError as exc:
        raise _unsupported({technique: str(exc)}) from exc
    return {
        "id": f"harmonic-{harmonic}-{uuid4()}",
        "status": "complete",
        "reference_snapshot_id": payload.reference_snapshot.get("id"),
        "harmonic": harmonic,
        "harmonic_snapshot": harmonic_snapshot,
        "comparison": comparison,
    }


@router.post("/calculations/dodecatemoria", status_code=status.HTTP_201_CREATED)
async def create_dodecatemoria(
    payload: HarmonicChartPayload,
    request: Request,
) -> dict[str, Any]:
    """Dodecatemoria (12th harmonic): each natal longitude times 12 mod 360."""
    return _create_harmonic_chart(
        payload=payload,
        request=request,
        harmonic=12,
        technique="harmonic.dodecatemoria",
    )


@router.post("/calculations/tridecatemoria", status_code=status.HTTP_201_CREATED)
async def create_tridecatemoria(
    payload: HarmonicChartPayload,
    request: Request,
) -> dict[str, Any]:
    """Tridecatemoria (13th harmonic): each natal longitude times 13 mod 360."""
    return _create_harmonic_chart(
        payload=payload,
        request=request,
        harmonic=13,
        technique="harmonic.tridecatemoria",
    )


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
