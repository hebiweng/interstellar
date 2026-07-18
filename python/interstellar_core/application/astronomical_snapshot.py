"""M2 astronomical calculation pipeline.

The pipeline deliberately stops at reproducible astronomical facts. Houses,
angles, aspects, patterns and interpretation remain blocked until their own
milestones pass validation.
"""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
from dataclasses import asdict
from datetime import UTC, datetime
from importlib.metadata import PackageNotFoundError, version
from typing import Any

from interstellar_core.application.recipe_preflight import canonical_hash
from interstellar_core.astronomy.adapters import SwissEphemerisAdapter
from interstellar_core.astronomy.derived import derive_lunar_phase


class AstronomicalSnapshotInputError(ValueError):
    """Raised when an M2 request cannot be calculated without guessing."""


def _timestamp(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_selected_utc(time_spec: Mapping[str, Any]) -> datetime:
    selected = time_spec.get("selected_utc")
    if not isinstance(selected, str) or not selected:
        raise AstronomicalSnapshotInputError(
            "A single selected_utc instant is required; ambiguous or unknown times "
            "cannot be guessed."
        )
    try:
        parsed = datetime.fromisoformat(selected.replace("Z", "+00:00"))
    except ValueError as exc:
        raise AstronomicalSnapshotInputError("selected_utc is not a valid ISO instant") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise AstronomicalSnapshotInputError("selected_utc must be timezone-aware")
    return parsed.astimezone(UTC)


def _package_version(distribution: str, fallback: str) -> str:
    try:
        return version(distribution)
    except PackageNotFoundError:
        return fallback


def _warning(
    code: str,
    message: str,
    *,
    details: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
        "severity": "warning",
        "path": None,
        "details": dict(details or {}),
    }


def _adapter_warning(warning: Any) -> dict[str, Any]:
    point_id = getattr(warning, "point_id", None)
    return _warning(
        str(warning.code),
        str(warning.message),
        details={"point_id": point_id} if point_id else {},
    )


def create_astronomical_snapshot(
    *,
    snapshot_id: str,
    request_payload: Mapping[str, Any],
    subject_version: Mapping[str, Any],
    now: datetime,
    engine_version: str,
    adapter: SwissEphemerisAdapter | None = None,
) -> dict[str, Any]:
    """Calculate a canonical, explicitly partial M2 snapshot."""

    time_spec = subject_version.get("time_spec")
    location = subject_version.get("location")
    if not isinstance(time_spec, Mapping):
        raise AstronomicalSnapshotInputError("The subject version has no TimeSpec.")
    if not isinstance(location, Mapping):
        raise AstronomicalSnapshotInputError("The subject version has no Location.")
    utc_instant = _parse_selected_utc(time_spec)

    calculator = adapter or SwissEphemerisAdapter(moshier_fallback="record")
    ephemeris = calculator.calculate(utc_instant=utc_instant)
    point_by_id = {point["point_id"]: point for point in ephemeris.points}
    lunar = derive_lunar_phase(
        point_by_id["sun"]["position"]["ecliptic"]["longitude_deg"],
        point_by_id["moon"]["position"]["ecliptic"]["longitude_deg"],
    )

    normalized_input = {
        "subject_version": deepcopy(dict(subject_version)),
        "chart": deepcopy(dict(request_payload["chart"])),
        "settings": deepcopy(dict(request_payload["settings"])),
    }
    input_fingerprint = canonical_hash(normalized_input)
    rule_pack_hash = str(request_payload["rule_pack_hash"])
    engine = {
        "name": "interstellar-core",
        "version": engine_version,
        "content_hash": None,
    }
    adapter_ref = {
        "name": "pysweph",
        "version": _package_version(
            "pysweph",
            ephemeris.provenance.binding_version,
        ),
        "content_hash": None,
    }
    dataset = {
        "id": "swiss_ephemeris_core",
        "version": ephemeris.provenance.swiss_c_library_version,
        "checksum": None,
        "license": "AGPL-3.0-or-commercial",
        "source_uri": "https://www.astro.com/swisseph/",
    }
    datasets = [dataset]
    provenance = {
        "engine": engine,
        "adapter": adapter_ref,
        "datasets": datasets,
        "algorithm_cards": ["ALG-ASTRONOMY-001"],
        "rule_refs": ["astronomy.ephemeris_core"],
    }
    adapter_warnings = [_adapter_warning(item) for item in ephemeris.warnings]
    partial_warning = _warning(
        "M2_PARTIAL_CHART",
        "Astronomical points are calculated; houses, angles and aspects await M3 validation.",
        details={"blocked_components": ["astronomy.houses_angles", "astronomy.aspects"]},
    )
    chart_id = f"chart-{snapshot_id}"
    astronomical_context = {
        "utc": _timestamp(utc_instant),
        "julian_day_ut": ephemeris.julian_day_ut,
        "julian_day_tt": ephemeris.julian_day_tt,
        "delta_t_seconds": ephemeris.delta_t_seconds,
        "observer": deepcopy(dict(location)),
        "coordinate_settings": {
            "apparent": ephemeris.provenance.apparent,
            "center": ephemeris.provenance.center,
            "frame": ephemeris.provenance.frame,
            "requested_ephemeris_mode": ephemeris.provenance.requested_mode,
            "actual_ephemeris_modes": list(ephemeris.provenance.actual_modes),
            "delta_t_function": ephemeris.provenance.delta_t_function,
        },
        "provenance": provenance,
        "uncertainty": {
            "time_seconds": time_spec.get("uncertainty_seconds"),
            "time_confidence": time_spec.get("confidence"),
            "historical_confidence": time_spec.get("historical_confidence"),
        },
    }
    chart = {
        "chart_id": chart_id,
        "family": str(request_payload["chart"]["family"]),
        "technique": str(request_payload["chart"]["technique"]),
        "subject_version_refs": [str(subject_version["id"])],
        "time_spec": deepcopy(dict(time_spec)),
        "location": deepcopy(dict(location)),
        "settings": deepcopy(dict(request_payload["settings"])),
        "astronomical_context": astronomical_context,
        "points": [deepcopy(point) for point in ephemeris.points],
        "house_set": None,
        "aspects": [],
        "distributions": [],
        "patterns": [],
        "dignities": [],
        "receptions": [],
        "lots": [],
        "midpoints": [],
        "warnings": [partial_warning, *adapter_warnings],
        "provenance": provenance,
    }
    reproducibility = {
        "engine": engine,
        "datasets": datasets,
        "rule_pack_hash": rule_pack_hash,
        "input_fingerprint": input_fingerprint,
    }
    manifests = [
        {
            "output_id": "manifest.astronomy.ephemeris_core",
            "status": "generated",
            "calculation_id": "astronomy.ephemeris_core",
            "result_pointer": "/result/points",
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": ["table.planet_positions"],
            "export_formats": ["json", "csv"],
            "recommended_primary_view_id": None,
            "missing_inputs": [],
            "warnings": adapter_warnings,
            "algorithm_cards": ["ALG-ASTRONOMY-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.standard_chart",
            "status": "blocked",
            "calculation_id": "natal.standard_chart",
            "result_pointer": None,
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": [],
            "export_formats": [],
            "recommended_primary_view_id": None,
            "missing_inputs": ["astronomy.houses_angles", "astronomy.aspects"],
            "warnings": [partial_warning],
            "algorithm_cards": ["ALG-NATAL-001"],
            "reproducibility": reproducibility,
        },
    ]
    lunar_result = {
        **asdict(lunar),
        "phase": lunar.phase.value,
        "month_model": asdict(lunar.month_model),
    }
    return {
        "id": snapshot_id,
        "schema_version": "1.0.0",
        "status": "partial",
        "request": deepcopy(dict(request_payload)),
        "normalized_input": normalized_input,
        "input_fingerprint": input_fingerprint,
        "engine": engine,
        "adapters": [adapter_ref],
        "datasets": datasets,
        "analysis_model": None,
        "recipe": None,
        "rule_pack_hash": rule_pack_hash,
        "maturity": "experimental",
        "result": {
            "astronomical_context": {
                **astronomical_context,
                "lunar_phase": lunar_result,
                "adapter_provenance": asdict(ephemeris.provenance),
            },
            "charts": [chart],
            "points": [deepcopy(point) for point in ephemeris.points],
            "houses": [],
            "aspects": [],
            "distributions": [],
            "patterns": [],
            "dignities": [],
            "receptions": [],
            "lots": [],
            "midpoints": [],
            "directions": [],
            "returns": [],
            "periods": [],
            "events": [],
            "relationships": [],
            "geography": [],
            "mundane": [],
            "topic_results": [],
            "evidence": [],
            "output_manifest": manifests,
        },
        "warnings": [partial_warning, *adapter_warnings],
        "supersedes_id": None,
        "created_at": _timestamp(now),
    }
