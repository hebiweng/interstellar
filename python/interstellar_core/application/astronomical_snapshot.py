"""M3 natal fact pipeline.

The pipeline combines the M2 astronomical adapter with the independently
versioned M3 house, major-aspect and descriptive-distribution engines.  It
still produces facts only: chart-pattern recognition, dignities and any
interpretation remain explicit later-stage work.
"""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
from dataclasses import asdict
from datetime import UTC, datetime
from importlib.metadata import PackageNotFoundError, version
from itertools import combinations
from typing import Any

from interstellar_core.application.recipe_preflight import canonical_hash
from interstellar_core.astrology.aspects import (
    OFFICIAL_MAJOR_ASPECTS_V1,
    OFFICIAL_STANDARD_ORBS_V1,
    AspectContext,
    AspectPoint,
    find_major_aspects,
)
from interstellar_core.astrology.distributions import (
    MODERN_TEN_PROFILE_V1,
    DistributionPoint,
    calculate_distributions,
    profile_by_id,
)
from interstellar_core.astrology.houses import (
    HouseCalculationError,
    HouseCalculator,
    HouseSystem,
    assign_points_to_houses,
)
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


def _selected_points(
    points: tuple[dict[str, Any], ...],
    included_point_ids: list[str],
) -> list[dict[str, Any]]:
    """Apply the request's point projection without silently ignoring ids."""

    available = {str(point["point_id"]): point for point in points}
    if not included_point_ids:
        return [deepcopy(point) for point in points]
    duplicate_ids = sorted(
        point_id for point_id in set(included_point_ids) if included_point_ids.count(point_id) > 1
    )
    if duplicate_ids:
        raise AstronomicalSnapshotInputError(
            "included_points contains duplicate ids: " + ", ".join(duplicate_ids)
        )
    unknown = sorted(set(included_point_ids) - set(available))
    if unknown:
        raise AstronomicalSnapshotInputError(
            "included_points contains unsupported M3 ids: " + ", ".join(unknown)
        )
    return [deepcopy(available[point_id]) for point_id in included_point_ids]


def _house_calculation(
    *,
    request_payload: Mapping[str, Any],
    julian_day_ut: float,
    location: Mapping[str, Any],
) -> Any:
    settings = request_payload["settings"]
    custom_parameters = settings.get("custom_parameters") or {}
    if not isinstance(custom_parameters, Mapping):
        raise AstronomicalSnapshotInputError("settings.custom_parameters must be an object")
    try:
        system = HouseSystem(str(settings["house_system"]).lower())
    except (KeyError, ValueError) as exc:
        raise AstronomicalSnapshotInputError(
            f"unsupported house system: {settings.get('house_system')}"
        ) from exc
    try:
        latitude = float(location["latitude"])
        longitude = float(location["longitude"])
        return HouseCalculator().calculate(
            julian_day_ut=julian_day_ut,
            latitude_deg=latitude,
            longitude_deg=longitude,
            system=system,
            allow_fallback_whole_sign=bool(
                custom_parameters.get("allow_house_fallback_whole_sign", False)
            ),
        )
    except (KeyError, TypeError, ValueError, HouseCalculationError) as exc:
        raise AstronomicalSnapshotInputError(f"house calculation cannot run: {exc}") from exc


def _place_points(
    points: list[dict[str, Any]],
    house_set: dict[str, Any] | None,
) -> tuple[list[dict[str, Any]], dict[str, Any] | None]:
    if house_set is None:
        return points, None
    populated_house_set = deepcopy(house_set)
    cusps = tuple(float(house["cusp_longitude_deg"]) for house in populated_house_set["houses"])
    longitudes = {
        str(point["point_id"]): float(point["position"]["ecliptic"]["longitude_deg"])
        for point in points
    }
    placements = assign_points_to_houses(longitudes, cusps)
    for point in points:
        point_id = str(point["point_id"])
        placement = placements[point_id]
        point["house"] = placement.house
        longitude = longitudes[point_id]
        next_cusp = cusps[placement.house % 12]
        point["distance_to_next_cusp_deg"] = (next_cusp - longitude) % 360
        if placement.on_cusp:
            point["status_refs"] = [*point.get("status_refs", []), "house.on_cusp"]
        populated_house_set["houses"][placement.house - 1]["point_ids"].append(point_id)
    return points, populated_house_set


def _major_aspects(points: list[dict[str, Any]]) -> list[dict[str, Any]]:
    aspect_points = [
        AspectPoint(
            id=str(point["point_id"]),
            longitude_deg=float(point["position"]["ecliptic"]["longitude_deg"]),
            longitude_speed_deg_per_day=float(
                point["position"]["velocity"]["longitude_deg_per_day"]
            ),
        )
        for point in points
    ]
    result = []
    for left, right in combinations(aspect_points, 2):
        result.extend(
            aspect.to_dict()
            for aspect in find_major_aspects(
                left,
                right,
                context=AspectContext.WITHIN_CHART,
            )
        )
    return sorted(result, key=lambda item: (item["point_a"], item["point_b"], item["type"]))


def _distribution_documents(
    points: list[dict[str, Any]],
    *,
    profile_id: str,
) -> tuple[list[dict[str, Any]], bool]:
    try:
        profile = profile_by_id(profile_id)
    except Exception as exc:
        raise AstronomicalSnapshotInputError(str(exc)) from exc
    allowed_ids = {item.point_id for item in profile.point_weights}
    distribution = calculate_distributions(
        (
            DistributionPoint(
                point_id=str(point["point_id"]),
                longitude_deg=float(point["position"]["ecliptic"]["longitude_deg"]),
            )
            for point in points
            if str(point["point_id"]) in allowed_ids
        ),
        profile=profile,
    )
    participants = [asdict(participant) for participant in distribution.participants]
    provenance = asdict(distribution.provenance)
    documents: list[dict[str, Any]] = []
    for dimension in distribution.dimensions:
        categories = []
        singular = {
            "elements": "element",
            "modalities": "modality",
            "polarities": "polarity",
        }[dimension.dimension]
        for category in dimension.categories:
            category_payload = asdict(category)
            category_payload["participant_ids"] = [
                participant["point_id"]
                for participant in participants
                if participant[singular] == category.category_id
            ]
            categories.append(category_payload)
        calculation_id = {
            "elements": "distribution.elements.v1",
            "modalities": "distribution.modalities.v1",
            "polarities": "distribution.polarity.v1",
        }[dimension.dimension]
        documents.append(
            {
                "distribution_id": calculation_id,
                "dimension": dimension.dimension,
                "availability": dimension.availability.value,
                "unavailable_reasons": list(distribution.unavailable_reasons),
                "denominator": dimension.denominator,
                "threshold": asdict(dimension.threshold),
                "categories": categories,
                "participants": participants,
                "provenance": provenance,
            }
        )
    return documents, distribution.availability.value == "available"


def create_astronomical_snapshot(
    *,
    snapshot_id: str,
    request_payload: Mapping[str, Any],
    subject_version: Mapping[str, Any],
    now: datetime,
    engine_version: str,
    adapter: SwissEphemerisAdapter | None = None,
) -> dict[str, Any]:
    """Calculate a canonical M3 natal fact snapshot."""

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
    settings = request_payload["settings"]
    if settings.get("aspect_set_id") != OFFICIAL_MAJOR_ASPECTS_V1.id:
        raise AstronomicalSnapshotInputError(
            "M3 supports aspect_set_id " + OFFICIAL_MAJOR_ASPECTS_V1.id
        )
    if settings.get("orb_profile_id") != OFFICIAL_STANDARD_ORBS_V1.id:
        raise AstronomicalSnapshotInputError(
            "M3 supports orb_profile_id " + OFFICIAL_STANDARD_ORBS_V1.id
        )
    included_point_ids = list(settings.get("included_points") or [])
    points = _selected_points(ephemeris.points, included_point_ids)
    house_result = _house_calculation(
        request_payload=request_payload,
        julian_day_ut=ephemeris.julian_day_ut,
        location=location,
    )
    points, house_set = _place_points(points, house_result.house_set)
    aspects = _major_aspects(points)
    custom_parameters = settings.get("custom_parameters") or {}
    distribution_profile_id = str(
        custom_parameters.get(
            "distribution_profile_id",
            MODERN_TEN_PROFILE_V1.profile_id,
        )
    )
    distributions, distributions_available = _distribution_documents(
        points,
        profile_id=distribution_profile_id,
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
        "algorithm_cards": [
            "ALG-ASTRONOMY-001",
            "ALG-ASTRONOMY-003",
            "ALG-ASTRONOMY-004",
            "ALG-NATAL-003",
        ],
        "rule_refs": [
            "astronomy.ephemeris_core",
            "astronomy.houses_angles",
            "astronomy.aspects",
            "natal.patterns_distributions",
        ],
    }
    adapter_warnings = [_adapter_warning(item) for item in ephemeris.warnings]
    house_warnings = [
        {
            **item.to_canonical(),
            "path": "/result/charts/0/house_set",
            "details": dict(item.details or {}),
        }
        for item in house_result.warnings
    ]
    distribution_warnings: list[dict[str, Any]] = []
    if not distributions_available:
        distribution_warnings.append(
            _warning(
                "DISTRIBUTION_INPUT_INCOMPLETE",
                "The selected point projection does not contain every point required by the "
                "distribution profile; percentages and threshold flags are unavailable.",
                details={"profile_id": distribution_profile_id},
            )
        )
    all_warnings = [*adapter_warnings, *house_warnings, *distribution_warnings]
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
        "points": deepcopy(points),
        "house_set": deepcopy(house_set),
        "aspects": deepcopy(aspects),
        "distributions": deepcopy(distributions),
        "patterns": [],
        "dignities": [],
        "receptions": [],
        "lots": [],
        "midpoints": [],
        "warnings": deepcopy(all_warnings),
        "provenance": provenance,
    }
    reproducibility = {
        "engine": engine,
        "datasets": datasets,
        "rule_pack_hash": rule_pack_hash,
        "input_fingerprint": input_fingerprint,
    }
    houses_status = {
        "available": "generated",
        "degraded": "degraded",
        "unavailable": "blocked",
    }[house_result.status]
    distribution_status = "generated" if distributions_available else "blocked"
    natal_status = (
        "blocked"
        if house_result.status == "unavailable"
        else "degraded"
        if house_result.status == "degraded" or not distributions_available
        else "generated"
    )
    manifests = [
        {
            "output_id": "manifest.astronomy.ephemeris_core",
            "status": "generated",
            "calculation_id": "astronomy.ephemeris_core",
            "result_pointer": "/result/points",
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": ["table.planet_positions", "table.planet_speeds"],
            "export_formats": ["json", "csv"],
            "recommended_primary_view_id": None,
            "missing_inputs": [],
            "warnings": adapter_warnings,
            "algorithm_cards": ["ALG-ASTRONOMY-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.astronomy.houses_angles",
            "status": houses_status,
            "calculation_id": "astronomy.houses_angles",
            "result_pointer": "/result/charts/0/house_set" if house_set else None,
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": ["table.house_cusps"] if house_set else [],
            "export_formats": ["json", "csv"] if house_set else [],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if house_set else ["supported_house_system_at_latitude"],
            "warnings": deepcopy(house_warnings),
            "algorithm_cards": ["ALG-ASTRONOMY-003"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.astronomy.aspects",
            "status": "generated",
            "calculation_id": "astronomy.aspects",
            "result_pointer": "/result/aspects",
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": ["table.natal_aspects"],
            "export_formats": ["json", "csv"],
            "recommended_primary_view_id": None,
            "missing_inputs": [],
            "warnings": [],
            "algorithm_cards": ["ALG-ASTRONOMY-004"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.patterns_distributions",
            "status": distribution_status,
            "calculation_id": "natal.patterns_distributions",
            "result_pointer": "/result/distributions",
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": ["table.elements", "table.modalities", "table.polarity"],
            "export_formats": ["json", "csv"],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if distributions_available else ["complete_profile_points"],
            "warnings": deepcopy(distribution_warnings),
            "algorithm_cards": ["ALG-NATAL-003"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.standard_chart",
            "status": natal_status,
            "calculation_id": "natal.standard_chart",
            "result_pointer": "/result/charts/0" if house_set else None,
            "maturity": "experimental",
            "view_ids": [],
            "table_ids": [
                "table.planet_positions",
                "table.planet_speeds",
                "table.house_cusps",
                "table.natal_aspects",
                "table.elements",
                "table.modalities",
                "table.polarity",
            ]
            if house_set
            else [],
            "export_formats": ["json", "csv"] if house_set else [],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if house_set else ["astronomy.houses_angles"],
            "warnings": deepcopy([*house_warnings, *distribution_warnings]),
            "algorithm_cards": [
                "ALG-NATAL-001",
                "ALG-ASTRONOMY-003",
                "ALG-ASTRONOMY-004",
            ],
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
        "status": "succeeded" if natal_status == "generated" else "partial",
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
            "points": deepcopy(points),
            "houses": deepcopy(house_set["houses"] if house_set else []),
            "aspects": deepcopy(aspects),
            "distributions": deepcopy(distributions),
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
        "warnings": deepcopy(all_warnings),
        "supersedes_id": None,
        "created_at": _timestamp(now),
    }
