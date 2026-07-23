"""M3 natal fact pipeline.

The pipeline combines the M2 astronomical adapter with the independently
versioned M3 house, major-aspect and descriptive-distribution engines.  It
still produces facts only: chart-pattern recognition, dignities and any
interpretation remain explicit later-stage work.
"""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from copy import deepcopy
from dataclasses import asdict
from datetime import UTC, date, datetime, time, timedelta
from importlib.metadata import PackageNotFoundError, version
from itertools import combinations
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import swisseph as swe

from interstellar_core.application.recipe_preflight import canonical_hash
from interstellar_core.astrology.aspects import (
    OFFICIAL_MAJOR_ASPECTS_V1,
    OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1,
    OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1,
    OFFICIAL_STANDARD_ORBS_V1,
    AspectContext,
    AspectOrbAllowance,
    AspectPoint,
    MajorAspectProfile,
    OrbOverrideSet,
    OrbProfile,
    find_major_aspects,
    parse_orb_overrides,
)
from interstellar_core.astrology.classical import (
    TRADITIONAL_PLANET_IDS,
    Sect,
    TermsTable,
    TriplicityTable,
    calculate_receptions,
    calculate_supported_lots,
    calculate_traditional_dispositors,
    classify_solar_condition,
    evaluate_essential_dignity,
    sect_facts,
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
from interstellar_core.astrology.natal import (
    ANGLE_POINT_IDS,
    DEFAULT_LOT_IDS,
    DEFAULT_SPECIAL_DEGREE_PROFILE,
    PROFESSIONAL_POINT_IDS,
    add_opposite_nodes,
    angle_points_from_house_result,
    calculate_midpoints,
    calculate_mirror_points,
    calculate_natal_structure,
    calculate_special_degrees,
    lot_point_from_fact,
    mirror_profile,
)
from interstellar_core.astrology.timing import (
    calculate_annual_profections,
    calculate_firdaria,
    calculate_zodiacal_releasing,
)
from interstellar_core.astronomy.adapters import (
    AYANAMSA_MODES,
    CORE_POINT_IDS,
    DIRECT_POINT_REGISTRY,
    SwissEphemerisAdapter,
)
from interstellar_core.astronomy.derived import (
    derive_lunar_phase,
    signed_angular_difference,
)
from interstellar_core.astronomy.fixed_stars import (
    SwissFixedStarCalculator,
    calculate_fixed_star_contacts,
)


class AstronomicalSnapshotInputError(ValueError):
    """Raised when an M2 request cannot be calculated without guessing."""


PROFESSIONAL_CALCULATION_PROFILE_ID = "professional.natal.v1"
PROFESSIONAL_POINT_SET_ID = "points.professional.default.v1"
CURRENTLY_DERIVABLE_POINT_IDS = {
    *ANGLE_POINT_IDS,
    "true_south_node",
    "mean_south_node",
    *DEFAULT_LOT_IDS,
}


def _requested_final_point_ids(settings: Mapping[str, Any]) -> tuple[str, ...]:
    included = tuple(str(item) for item in settings.get("included_points") or ())
    if included:
        candidates = included
    elif settings.get(
        "calculation_profile_id"
    ) == PROFESSIONAL_CALCULATION_PROFILE_ID or PROFESSIONAL_POINT_SET_ID in set(
        settings.get("point_set_ids") or ()
    ):
        candidates = PROFESSIONAL_POINT_IDS
    else:
        candidates = CORE_POINT_IDS
    duplicates = sorted(point_id for point_id in set(candidates) if candidates.count(point_id) > 1)
    if duplicates:
        raise AstronomicalSnapshotInputError(
            "included_points contains duplicate ids: " + ", ".join(duplicates)
        )
    supported = set(DIRECT_POINT_REGISTRY) | CURRENTLY_DERIVABLE_POINT_IDS
    unknown = sorted(set(candidates) - supported)
    if unknown:
        raise AstronomicalSnapshotInputError(
            "included_points contains unsupported natal ids: " + ", ".join(unknown)
        )
    return candidates


def _direct_point_dependencies(final_ids: tuple[str, ...]) -> tuple[str, ...]:
    dependencies: list[str] = ["sun", "moon"]
    if set(final_ids) & set(DEFAULT_LOT_IDS):
        # The released Hermetic Lot family depends on these five planets. Using
        # the full locked dependency set also keeps explicit one-Lot requests
        # reproducible without relying on unrelated selected chart points.
        dependencies.extend(("mercury", "venus", "mars", "jupiter", "saturn"))
    for point_id in final_ids:
        if point_id in DIRECT_POINT_REGISTRY:
            dependencies.append(point_id)
        elif point_id == "true_south_node":
            dependencies.append("true_north_node")
        elif point_id == "mean_south_node":
            dependencies.append("mean_north_node")
    return tuple(dict.fromkeys(dependencies))


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
    points: Sequence[Mapping[str, Any]],
    included_point_ids: Sequence[str],
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
            "included_points contains unsupported natal ids: " + ", ".join(unknown)
        )
    return [deepcopy(available[point_id]) for point_id in included_point_ids]


def _house_calculation(
    *,
    request_payload: Mapping[str, Any],
    julian_day_ut: float,
    location: Mapping[str, Any],
) -> Any:
    settings = request_payload["settings"]
    zodiac = str(settings.get("zodiac", "tropical"))
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
        zodiac = str(settings.get("zodiac", "tropical"))
        ayanamsa = settings.get("ayanamsa")
        if zodiac == "tropical":
            house_flags = 0
            sidereal_mode = None
            if ayanamsa is not None:
                raise AstronomicalSnapshotInputError(
                    "tropical zodiac must not declare an ayanamsa"
                )
        elif zodiac == "sidereal":
            if ayanamsa not in AYANAMSA_MODES:
                raise AstronomicalSnapshotInputError(
                    "sidereal zodiac requires a supported ayanamsa"
                )
            house_flags = swe.FLG_SIDEREAL
            sidereal_mode = AYANAMSA_MODES[str(ayanamsa)]
        else:
            raise AstronomicalSnapshotInputError(
                f"unsupported natal zodiac: {zodiac}"
            )
        latitude = float(location["latitude"])
        longitude = float(location["longitude"])
        return HouseCalculator().calculate(
            julian_day_ut=julian_day_ut,
            latitude_deg=latitude,
            longitude_deg=longitude,
            system=system,
            flags=house_flags,
            sidereal_mode=sidereal_mode,
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
        previous_cusp = cusps[placement.house - 1]
        next_cusp = cusps[placement.house % 12]
        span = (next_cusp - previous_cusp) % 360
        distance_from_previous = (longitude - previous_cusp) % 360
        distance_to_next = (next_cusp - longitude) % 360
        point["distance_from_previous_cusp_deg"] = distance_from_previous
        point["distance_to_next_cusp_deg"] = distance_to_next
        point["house_position_fraction"] = distance_from_previous / span if span > 0 else None
        if placement.on_cusp:
            point["status_refs"] = [*point.get("status_refs", []), "house.on_cusp"]
        populated_house_set["houses"][placement.house - 1]["point_ids"].append(point_id)
    return points, populated_house_set


def _major_aspects(
    points: list[dict[str, Any]],
    *,
    aspect_profile: MajorAspectProfile,
    orb_profile: OrbProfile,
    orb_overrides: OrbOverrideSet,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    aspect_points = [
        AspectPoint(
            id=str(point["point_id"]),
            longitude_deg=float(point["position"]["ecliptic"]["longitude_deg"]),
            longitude_speed_deg_per_day=(
                float(point["position"]["velocity"]["longitude_deg_per_day"])
                if point.get("motion_interpretation") == "meaningful"
                and point["position"]["velocity"].get("longitude_deg_per_day") is not None
                else None
            ),
        )
        for point in points
    ]
    point_classes = {
        str(point["point_id"]): (
            "luminary"
            if str(point["point_id"]) in {"sun", "moon"}
            else str(point.get("kind") or "other")
        )
        for point in points
    }
    result = []
    for left, right in combinations(aspect_points, 2):
        result.extend(
            aspect.to_dict()
            for aspect in find_major_aspects(
                left,
                right,
                context=AspectContext.WITHIN_CHART,
                major_profile=aspect_profile,
                orb_profile=orb_profile,
                orb_overrides=orb_overrides,
                point_classes=point_classes,
            )
        )
    sorted_result = sorted(
        result,
        key=lambda item: (item["point_a"], item["point_b"], item["type"]),
    )
    pair_count = len(aspect_points) * (len(aspect_points) - 1) // 2
    return sorted_result, {
        "selected_point_count": len(aspect_points),
        "evaluated_pair_count": pair_count,
        "matched_aspect_count": len(sorted_result),
        "orb_override_set": {
            "id": orb_overrides.id,
            "version": orb_overrides.version,
            "rule_count": len(orb_overrides.rules),
        },
        "excluded_pairs": [],
    }


def _aspect_profiles(
    settings: Mapping[str, Any],
) -> tuple[MajorAspectProfile, OrbProfile, OrbOverrideSet]:
    aspect_profiles = {
        OFFICIAL_MAJOR_ASPECTS_V1.id: OFFICIAL_MAJOR_ASPECTS_V1,
        OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1.id: (OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1),
    }
    orb_profiles = {
        OFFICIAL_STANDARD_ORBS_V1.id: OFFICIAL_STANDARD_ORBS_V1,
        OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1.id: OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1,
    }
    try:
        base_aspects = aspect_profiles[str(settings["aspect_set_id"])]
    except KeyError as exc:
        raise AstronomicalSnapshotInputError(
            "unsupported aspect_set_id: " + str(settings.get("aspect_set_id"))
        ) from exc
    try:
        base_orbs = orb_profiles[str(settings["orb_profile_id"])]
    except KeyError as exc:
        supported = ", ".join(sorted(orb_profiles))
        raise AstronomicalSnapshotInputError(
            "unsupported orb_profile_id: "
            + str(settings.get("orb_profile_id"))
            + "; supported profiles: "
            + supported
        ) from exc

    included = tuple(str(item) for item in settings.get("included_aspect_ids") or ())
    available_aspects = {item.id: item for item in base_aspects.aspects}
    if included:
        unknown = sorted(set(included) - set(available_aspects))
        if unknown:
            raise AstronomicalSnapshotInputError(
                "included_aspect_ids contains ids outside the selected aspect set: "
                + ", ".join(unknown)
            )
        selected_aspects = tuple(available_aspects[item] for item in included)
    else:
        selected_aspects = base_aspects.aspects

    try:
        orb_overrides = parse_orb_overrides(
            settings.get("orb_overrides"),
            known_aspect_ids=available_aspects,
            known_point_classes={
                "luminary", "planet", "angle", "node", "lunar_point",
                "dwarf_planet", "asteroid", "centaur", "lot", "hamburg",
                "hypothetical", "sensitive_point", "other",
            },
        )
    except ValueError as exc:
        raise AstronomicalSnapshotInputError(f"invalid orb overrides: {exc}") from exc

    aspect_profile = MajorAspectProfile(
        id=base_aspects.id,
        version=base_aspects.version,
        source=base_aspects.source,
        aspects=selected_aspects,
    )
    orb_profile = OrbProfile(
        id=base_orbs.id,
        version=base_orbs.version,
        source=base_orbs.source,
        allowances=tuple(
            AspectOrbAllowance(item.id, base_orbs.effective_orb(item.id))
            for item in selected_aspects
        ),
        probe_step_days=base_orbs.probe_step_days,
        exact_tolerance_deg=base_orbs.exact_tolerance_deg,
        relative_stationary_threshold_deg_per_day=(
            base_orbs.relative_stationary_threshold_deg_per_day
        ),
        probe_change_tolerance_deg=base_orbs.probe_change_tolerance_deg,
    )
    return aspect_profile, orb_profile, orb_overrides


def resolve_aspect_profiles(
    settings: Mapping[str, Any],
) -> tuple[MajorAspectProfile, OrbProfile, OrbOverrideSet]:
    """Resolve the shared aspect geometry, allowances, and user overrides.

    Single-chart calculations and cross-chart techniques intentionally use the
    same resolver so changing an aspect set or orb hierarchy cannot produce two
    different meanings in natal, current-sky, transit, or progression results.
    """

    return _aspect_profiles(settings)


def _day_night_status(
    *,
    sun_point: Mapping[str, Any],
    latitude_deg: float,
    longitude_deg: float,
    greenwich_sidereal_time_deg: float | None,
    horizon_tolerance_deg: float = 0.25,
) -> tuple[str, float | None]:
    """Resolve geometric day/night from Sun altitude without refraction."""

    if greenwich_sidereal_time_deg is None:
        return "indeterminate", None
    right_ascension = math.radians(
        float(sun_point["position"]["equatorial"]["right_ascension_deg"])
    )
    declination = math.radians(float(sun_point["position"]["equatorial"]["declination_deg"]))
    latitude = math.radians(float(latitude_deg))
    local_sidereal = (float(greenwich_sidereal_time_deg) + float(longitude_deg)) % 360
    hour_angle = math.radians(local_sidereal) - right_ascension
    altitude = math.degrees(
        math.asin(
            math.sin(latitude) * math.sin(declination)
            + math.cos(latitude) * math.cos(declination) * math.cos(hour_angle)
        )
    )
    if abs(altitude) <= horizon_tolerance_deg:
        return "indeterminate", altitude
    return ("day" if altitude > 0 else "night"), altitude


def _enrich_point_conditions(
    points: list[dict[str, Any]],
    *,
    obliquity_deg: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Attach explicit OOB, solar proximity, and east/west facts."""

    by_id = {str(point["point_id"]): point for point in points}
    sun = by_id.get("sun")
    if sun is None:
        return points, []
    sun_longitude = float(sun["position"]["ecliptic"]["longitude_deg"])
    solar_facts: list[dict[str, Any]] = []
    physical_kinds = {"luminary", "planet", "dwarf_planet", "asteroid", "centaur"}
    for point in points:
        declination = float(point["position"]["equatorial"]["declination_deg"])
        point["out_of_bounds"] = abs(declination) > abs(obliquity_deg)
        if point["kind"] not in physical_kinds:
            point["solar_relation"] = "not_applicable"
            point["solar_elongation_deg"] = None
            point["oriental_occidental"] = "not_applicable"
            point["visibility_state"] = "not_applicable"
            continue
        longitude = float(point["position"]["ecliptic"]["longitude_deg"])
        solar = classify_solar_condition(
            str(point["point_id"]),
            longitude,
            sun_longitude_deg=sun_longitude,
        )
        solar_payload = solar.to_dict()
        solar_facts.append(solar_payload)
        point["solar_relation"] = solar_payload["relation"]
        point["solar_elongation_deg"] = solar_payload["separation_deg"]
        if point["point_id"] == "sun":
            point["oriental_occidental"] = "not_applicable"
        else:
            point["oriental_occidental"] = (
                "oriental"
                if signed_angular_difference(longitude, sun_longitude) < 0
                else "occidental"
            )
        # Physical visibility requires a separate heliacal model; solar
        # proximity must not be relabelled as a visibility determination.
        point["visibility_state"] = "uncertain"
    return points, solar_facts


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


def _classical_documents(
    points: list[dict[str, Any]],
    *,
    day_night_status: str,
    sun_altitude_deg: float | None,
    solar_conditions: list[dict[str, Any]],
    terms_table: TermsTable,
    triplicity_table: TriplicityTable,
) -> tuple[
    dict[str, Any],
    list[dict[str, Any]],
    list[dict[str, Any]],
]:
    """Return explicit traditional facts or an honest unavailable document."""

    longitudes = {
        str(point["point_id"]): float(point["position"]["ecliptic"]["longitude_deg"])
        for point in points
        if str(point["point_id"]) in TRADITIONAL_PLANET_IDS
    }
    missing = sorted(set(TRADITIONAL_PLANET_IDS) - set(longitudes))
    if day_night_status not in {"day", "night"}:
        return (
            {
                "availability": "indeterminate",
                "unavailable_reasons": ["DAY_NIGHT_STATUS_INDETERMINATE"],
                "day_night_status": day_night_status,
                "sun_altitude_deg": sun_altitude_deg,
                "missing_traditional_planet_ids": missing,
                "sect": None,
                "solar_conditions": solar_conditions,
                "terms_table": terms_table.value,
                "triplicity_table": triplicity_table.value,
                "dispositors": None,
                "receptions": None,
                "interpretation_boundary": (
                    "Traditional facts only; no qualitative or predictive interpretation"
                ),
            },
            [],
            [],
        )

    sect = Sect(day_night_status)
    dignity_documents = [
        evaluate_essential_dignity(
            point_id,
            longitude,
            sect=sect,
            terms_table=terms_table,
            triplicity_table=triplicity_table,
        ).to_dict()
        for point_id, longitude in sorted(longitudes.items())
    ]
    dispositor_document = calculate_traditional_dispositors(longitudes).to_dict()
    reception_document = calculate_receptions(
        longitudes,
        sect=sect,
        terms_table=terms_table,
        triplicity_table=triplicity_table,
    ).to_dict()
    reasons = ["MISSING_TRADITIONAL_PLANETS"] if missing else []
    classical_document = {
        "availability": "indeterminate" if reasons else "available",
        "unavailable_reasons": reasons,
        "day_night_status": day_night_status,
        "sun_altitude_deg": sun_altitude_deg,
        "missing_traditional_planet_ids": missing,
        "sect": sect_facts(sect).to_dict(),
        "solar_conditions": solar_conditions,
        "terms_table": terms_table.value,
        "triplicity_table": triplicity_table.value,
        "dispositors": dispositor_document,
        "receptions": reception_document,
        "interpretation_boundary": (
            "Traditional facts only; no qualitative or predictive interpretation"
        ),
    }
    return classical_document, dignity_documents, [reception_document]


def _classical_tables(settings: Mapping[str, Any]) -> tuple[TermsTable, TriplicityTable]:
    classical_settings = settings.get("classical_settings") or {}
    if not isinstance(classical_settings, Mapping):
        raise AstronomicalSnapshotInputError("classical_settings must be an object")
    raw_terms = str(classical_settings.get("terms_table") or "egyptian.v1")
    raw_triplicity = str(
        classical_settings.get("triplicity_table") or "dorothean.v1"
    )
    terms_by_id = {
        "egyptian": TermsTable.EGYPTIAN,
        "egyptian.v1": TermsTable.EGYPTIAN,
        "ptolemaic": TermsTable.PTOLEMAIC,
        "ptolemaic.v1": TermsTable.PTOLEMAIC,
    }
    triplicity_by_id = {
        "dorothean": TriplicityTable.DOROTHEAN,
        "dorothean.v1": TriplicityTable.DOROTHEAN,
        "ptolemaic": TriplicityTable.PTOLEMAIC,
        "ptolemaic.v1": TriplicityTable.PTOLEMAIC,
    }
    if raw_terms not in terms_by_id:
        raise AstronomicalSnapshotInputError(
            "unsupported classical terms_table: " + raw_terms
        )
    if raw_triplicity not in triplicity_by_id:
        raise AstronomicalSnapshotInputError(
            "unsupported classical triplicity_table: " + raw_triplicity
        )
    return terms_by_id[raw_terms], triplicity_by_id[raw_triplicity]


def _date_level_instants(
    time_spec: Mapping[str, Any],
    location: Mapping[str, Any],
) -> tuple[datetime, datetime, datetime, tuple[datetime, ...]]:
    """Return the civil-day interval and deterministic probe instants.

    The midpoint is a reference position for display, never a fabricated birth
    time.  The probes span the complete local civil day, including DST days that
    are not exactly 24 hours long.
    """

    local_value = time_spec.get("local_value")
    if not isinstance(local_value, str):
        raise AstronomicalSnapshotInputError(
            "date-level TimeSpec requires a local calendar date"
        )
    try:
        local_date = date.fromisoformat(local_value)
    except ValueError as exc:
        raise AstronomicalSnapshotInputError(
            "date-level TimeSpec.local_value must be YYYY-MM-DD"
        ) from exc
    timezone_id = time_spec.get("timezone_id") or location.get("timezone_id")
    if not isinstance(timezone_id, str) or not timezone_id:
        raise AstronomicalSnapshotInputError(
            "date-level calculation requires an explicitly selected IANA timezone"
        )
    try:
        zone = ZoneInfo(timezone_id)
    except ZoneInfoNotFoundError as exc:
        raise AstronomicalSnapshotInputError(
            f"IANA timezone {timezone_id!r} is unavailable"
        ) from exc

    start_local = datetime.combine(local_date, time.min, tzinfo=zone)
    end_local = datetime.combine(local_date + timedelta(days=1), time.min, tzinfo=zone)
    start_utc = start_local.astimezone(UTC)
    end_utc = end_local.astimezone(UTC)
    duration = end_utc - start_utc
    reference_utc = start_utc + duration / 2
    final_probe = end_utc - timedelta(microseconds=1)
    probes = (
        start_utc,
        start_utc + duration / 4,
        reference_utc,
        start_utc + duration * 3 / 4,
        final_probe,
    )
    return start_utc, end_utc, reference_utc, probes


def _circular_delta(value: float, reference: float) -> float:
    return (value - reference + 180.0) % 360.0 - 180.0


def create_date_level_astronomical_snapshot(
    *,
    snapshot_id: str,
    request_payload: Mapping[str, Any],
    subject_version: Mapping[str, Any],
    now: datetime,
    engine_version: str,
    adapter: SwissEphemerisAdapter | None = None,
) -> dict[str, Any]:
    """Create a transparent date-range natal snapshot for unknown birth time.

    It exposes reference positions plus full-day uncertainty envelopes.  Houses,
    angles, Lots, within-chart aspects, structural and classical results are
    blocked because those would require inventing a time inside the day.
    """

    time_spec = subject_version.get("time_spec")
    location = subject_version.get("location")
    if not isinstance(time_spec, Mapping) or not isinstance(location, Mapping):
        raise AstronomicalSnapshotInputError(
            "The subject version requires both TimeSpec and Location."
        )
    if time_spec.get("precision") not in {"date", "unknown"}:
        raise AstronomicalSnapshotInputError(
            "date-level snapshot requires TimeSpec precision date or unknown"
        )
    start_utc, end_utc, reference_utc, probes = _date_level_instants(time_spec, location)
    settings = request_payload["settings"]
    requested_point_ids = _requested_final_point_ids(settings)
    supported_point_ids = tuple(
        point_id
        for point_id in requested_point_ids
        if point_id in DIRECT_POINT_REGISTRY
        or point_id in {"true_south_node", "mean_south_node"}
    )
    excluded_point_ids = tuple(
        point_id for point_id in requested_point_ids if point_id not in supported_point_ids
    )
    direct_point_ids = _direct_point_dependencies(supported_point_ids)
    calculator = adapter or SwissEphemerisAdapter(moshier_fallback="record")
    ephemerides = tuple(
        calculator.calculate(
            utc_instant=instant,
            point_ids=direct_point_ids,
            zodiac=str(settings.get("zodiac", "tropical")),
            ayanamsa=settings.get("ayanamsa"),
            center=str(settings.get("center", "geocentric")),
            observer=location,
        )
        for instant in probes
    )
    reference_ephemeris = ephemerides[2]
    if reference_ephemeris.true_obliquity_deg is None:
        raise AstronomicalSnapshotInputError(
            "Swiss Ephemeris did not return true obliquity for the date-level reference"
        )
    obliquity_deg = float(reference_ephemeris.true_obliquity_deg)

    sampled_points: list[dict[str, dict[str, Any]]] = []
    for ephemeris in ephemerides:
        available = add_opposite_nodes(
            ephemeris.points,
            obliquity_deg=float(ephemeris.true_obliquity_deg or obliquity_deg),
            julian_day_ut=ephemeris.julian_day_ut,
        )
        sampled_points.append({str(point["point_id"]): point for point in available})

    reference_points = _selected_points(
        list(sampled_points[2].values()),
        supported_point_ids,
    )
    ranges: dict[str, dict[str, Any]] = {}
    for point in reference_points:
        point_id = str(point["point_id"])
        reference_longitude = float(point["position"]["ecliptic"]["longitude_deg"])
        longitudes = [
            float(sample[point_id]["position"]["ecliptic"]["longitude_deg"])
            for sample in sampled_points
        ]
        signs = [str(sample[point_id]["sign"]) for sample in sampled_points]
        motion_states = [
            str(sample[point_id]["position"].get("motion_state") or "unknown")
            for sample in sampled_points
        ]
        deviations = [_circular_delta(value, reference_longitude) for value in longitudes]
        max_deviation = max(abs(value) for value in deviations)
        sign_stable = len(set(signs)) == 1
        motion_stable = len(set(motion_states)) == 1
        point["house"] = None
        point["distance_from_previous_cusp_deg"] = None
        point["distance_to_next_cusp_deg"] = None
        point["house_position_fraction"] = None
        point["position"]["uncertainty_arcsec"] = round(max_deviation * 3600, 6)
        point["status_refs"] = [
            *point.get("status_refs", []),
            "date_range.reference_position_not_birth_time",
            *( [] if sign_stable else ["date_range.sign_ambiguous"] ),
            *( [] if motion_stable else ["date_range.motion_state_changes"] ),
        ]
        ranges[point_id] = {
            "reference_longitude_deg": reference_longitude,
            "sample_longitudes_deg": longitudes,
            "signed_deviation_from_reference_deg": deviations,
            "maximum_uncertainty_deg": max_deviation,
            "signs_observed": list(dict.fromkeys(signs)),
            "sign_stable": sign_stable,
            "motion_states_observed": list(dict.fromkeys(motion_states)),
            "motion_state_stable": motion_stable,
        }

    reference_by_id = {str(point["point_id"]): point for point in reference_points}
    lunar = derive_lunar_phase(
        reference_by_id["sun"]["position"]["ecliptic"]["longitude_deg"],
        reference_by_id["moon"]["position"]["ecliptic"]["longitude_deg"],
    )
    normalized_input = {
        "subject_version": deepcopy(dict(subject_version)),
        "chart": deepcopy(dict(request_payload["chart"])),
        "settings": deepcopy(dict(settings)),
    }
    input_fingerprint = canonical_hash(normalized_input)
    engine = {"name": "interstellar-core", "version": engine_version, "content_hash": None}
    adapter_ref = {
        "name": "pysweph",
        "version": _package_version(
            "pysweph", reference_ephemeris.provenance.binding_version
        ),
        "content_hash": None,
    }
    dataset = {
        "id": "swiss_ephemeris_core",
        "version": reference_ephemeris.provenance.swiss_c_library_version,
        "checksum": None,
        "license": "AGPL-3.0-or-commercial",
        "source_uri": "https://www.astro.com/swisseph/",
    }
    datasets = [dataset]
    provenance = {
        "engine": engine,
        "adapter": adapter_ref,
        "datasets": datasets,
        "algorithm_cards": ["ALG-ASTRONOMY-001", "ALG-NATAL-UNKNOWN-TIME-001"],
        "rule_refs": ["astronomy.ephemeris_core", "natal.unknown_time_date_range"],
    }
    adapter_warning_groups: dict[tuple[str, str], set[str]] = {}
    for ephemeris in ephemerides:
        for item in ephemeris.warnings:
            key = (str(item.code), str(item.message))
            point_id = getattr(item, "point_id", None)
            if point_id:
                adapter_warning_groups.setdefault(key, set()).add(str(point_id))
            else:
                adapter_warning_groups.setdefault(key, set())
    date_level_adapter_warnings = [
        _warning(code, message, details={"point_ids": sorted(point_ids)})
        for (code, message), point_ids in sorted(adapter_warning_groups.items())
    ]
    warnings = [
        *date_level_adapter_warnings,
        _warning(
            "BIRTH_TIME_UNKNOWN_DATE_RANGE",
            "No birth time was invented. Point positions use the civil-day midpoint only as "
            "a labeled reference and include a full-day uncertainty envelope.",
            details={
                "interval_start_utc": _timestamp(start_utc),
                "interval_end_utc": _timestamp(end_utc),
                "reference_utc": _timestamp(reference_utc),
            },
        ),
        _warning(
            "TIME_DEPENDENT_NATAL_OUTPUTS_BLOCKED",
            "Houses, angles, Lots, aspects, structural and classical results are unavailable "
            "until a birth time or bounded time interval is provided.",
            details={"excluded_point_ids": list(excluded_point_ids)},
        ),
    ]
    uncertainty = {
        "mode": "civil_day_range",
        "reference_position_is_birth_time": False,
        "interval_start_utc": _timestamp(start_utc),
        "interval_end_utc": _timestamp(end_utc),
        "reference_utc": _timestamp(reference_utc),
        "probe_instants_utc": [_timestamp(item) for item in probes],
        "point_ranges": ranges,
        "time_confidence": time_spec.get("confidence"),
        "historical_confidence": time_spec.get("historical_confidence"),
    }
    astronomical_context = {
        "utc": _timestamp(reference_utc),
        "julian_day_ut": reference_ephemeris.julian_day_ut,
        "julian_day_tt": reference_ephemeris.julian_day_tt,
        "delta_t_seconds": reference_ephemeris.delta_t_seconds,
        "greenwich_sidereal_time_deg": reference_ephemeris.greenwich_sidereal_time_deg,
        "local_sidereal_time_deg": None,
        "obliquity_deg": obliquity_deg,
        "mean_obliquity_deg": reference_ephemeris.mean_obliquity_deg,
        "nutation_longitude_deg": reference_ephemeris.nutation_longitude_deg,
        "nutation_obliquity_deg": reference_ephemeris.nutation_obliquity_deg,
        "sunrise_utc": None,
        "sunset_utc": None,
        "day_night_status": "indeterminate",
        "sun_altitude_deg": None,
        "precession_model": "swiss_ephemeris_apparent_of_date",
        "nutation_model": "swiss_ephemeris_ecl_nut",
        "observer": deepcopy(dict(location)),
        "coordinate_settings": {
            "apparent": reference_ephemeris.provenance.apparent,
            "center": reference_ephemeris.provenance.center,
            "frame": reference_ephemeris.provenance.frame,
            "requested_ephemeris_mode": reference_ephemeris.provenance.requested_mode,
            "actual_ephemeris_modes": list(reference_ephemeris.provenance.actual_modes),
            "delta_t_function": reference_ephemeris.provenance.delta_t_function,
        },
        "uncertainty": uncertainty,
        "provenance": provenance,
    }
    blocked_reasons = ["EXACT_BIRTH_TIME_REQUIRED"]
    structure_document = {
        "availability": "unavailable",
        "unavailable_reasons": blocked_reasons,
        "date_level_point_ranges": ranges,
        "stelliums": {"availability": "unavailable", "facts": []},
        "geometric_patterns": {"availability": "unavailable", "facts": []},
        "jones_shape": {"availability": "unavailable", "reason": "EXACT_BIRTH_TIME_REQUIRED"},
    }
    classical_document = {
        "availability": "unavailable",
        "unavailable_reasons": blocked_reasons,
        "day_night_status": "indeterminate",
        "sun_altitude_deg": None,
        "missing_traditional_planet_ids": [],
        "sect": None,
        "solar_conditions": [],
        "dispositors": None,
        "receptions": None,
        "interpretation_boundary": "Exact birth time required for released classical natal facts",
    }
    chart_id = f"chart-{snapshot_id}"
    chart = {
        "chart_id": chart_id,
        "family": str(request_payload["chart"]["family"]),
        "technique": str(request_payload["chart"]["technique"]),
        "subject_version_refs": [str(subject_version["id"])],
        "time_spec": deepcopy(dict(time_spec)),
        "location": deepcopy(dict(location)),
        "settings": deepcopy(dict(settings)),
        "astronomical_context": astronomical_context,
        "points": deepcopy(reference_points),
        "house_set": None,
        "aspects": [],
        "aspect_evaluation": {
            "selected_point_count": len(reference_points),
            "evaluated_pair_count": 0,
            "matched_aspect_count": 0,
            "excluded_pairs": [{"reason": "EXACT_BIRTH_TIME_REQUIRED"}],
        },
        "distributions": [],
        "structure": deepcopy(structure_document),
        "patterns": [],
        "classical": deepcopy(classical_document),
        "dignities": [],
        "receptions": [],
        "lots": [],
        "midpoints": [],
        "warnings": deepcopy(warnings),
        "provenance": provenance,
    }
    reproducibility = {
        "engine": engine,
        "datasets": datasets,
        "rule_pack_hash": str(request_payload["rule_pack_hash"]),
        "input_fingerprint": input_fingerprint,
    }
    blocked_manifest_specs = (
        ("astronomy.houses_angles", "ALG-ASTRONOMY-003"),
        ("astronomy.aspects", "ALG-ASTRONOMY-004"),
        ("natal.patterns_distributions", "ALG-NATAL-003"),
        ("natal.dignity_reception", "ALG-NATAL-004"),
        ("natal.arabic_parts", "ALG-NATAL-005"),
        ("natal.standard_chart", "ALG-NATAL-001"),
    )
    manifests = [
        {
            "output_id": "manifest.astronomy.ephemeris_core",
            "status": "degraded",
            "calculation_id": "astronomy.ephemeris_core",
            "result_pointer": "/result/points",
            "maturity": "experimental",
            "view_ids": ["view.natal.date_level_points"],
            "table_ids": ["table.planet_positions", "table.planet_speeds"],
            "export_formats": ["json", "csv", "markdown_technical", "plaintext_technical"],
            "recommended_primary_view_id": "view.natal.date_level_points",
            "missing_inputs": ["exact_birth_time"],
            "warnings": deepcopy(warnings),
            "algorithm_cards": ["ALG-ASTRONOMY-001", "ALG-NATAL-UNKNOWN-TIME-001"],
            "reproducibility": reproducibility,
        },
        *[
            {
                "output_id": f"manifest.{calculation_id}",
                "status": "blocked",
                "calculation_id": calculation_id,
                "result_pointer": None,
                "maturity": "experimental",
                "view_ids": [],
                "table_ids": [],
                "export_formats": [],
                "recommended_primary_view_id": None,
                "missing_inputs": ["exact_birth_time"],
                "warnings": deepcopy(warnings[-1:]),
                "algorithm_cards": [algorithm_card],
                "reproducibility": reproducibility,
            }
            for calculation_id, algorithm_card in blocked_manifest_specs
        ],
    ]
    lunar_result = {
        **asdict(lunar),
        "phase": lunar.phase.value,
        "month_model": asdict(lunar.month_model),
        "reference_position_not_birth_time": True,
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
        "rule_pack_hash": str(request_payload["rule_pack_hash"]),
        "maturity": "experimental",
        "result": {
            "astronomical_context": {
                **astronomical_context,
                "lunar_phase": lunar_result,
                "adapter_provenance": asdict(reference_ephemeris.provenance),
            },
            "charts": [chart],
            "points": deepcopy(reference_points),
            "houses": [],
            "aspects": [],
            "distributions": [],
            "structure": deepcopy(structure_document),
            "patterns": [],
            "classical": deepcopy(classical_document),
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
        "warnings": deepcopy(warnings),
        "supersedes_id": None,
        "created_at": _timestamp(now),
    }


def create_astronomical_snapshot(
    *,
    snapshot_id: str,
    request_payload: Mapping[str, Any],
    subject_version: Mapping[str, Any],
    now: datetime,
    engine_version: str,
    adapter: SwissEphemerisAdapter | None = None,
) -> dict[str, Any]:
    """Calculate a canonical single-chart astronomical fact snapshot."""

    time_spec = subject_version.get("time_spec")
    location = subject_version.get("location")
    if not isinstance(time_spec, Mapping):
        raise AstronomicalSnapshotInputError("The subject version has no TimeSpec.")
    if not isinstance(location, Mapping):
        raise AstronomicalSnapshotInputError("The subject version has no Location.")
    utc_instant = _parse_selected_utc(time_spec)

    settings = request_payload["settings"]
    zodiac = str(settings.get("zodiac", "tropical"))
    final_point_ids = _requested_final_point_ids(settings)
    direct_point_ids = _direct_point_dependencies(final_point_ids)
    calculator = adapter or SwissEphemerisAdapter(moshier_fallback="record")
    ephemeris = calculator.calculate(
        utc_instant=utc_instant,
        point_ids=direct_point_ids,
        zodiac=zodiac,
        ayanamsa=settings.get("ayanamsa"),
        center=str(settings.get("center", "geocentric")),
        observer=location,
    )
    point_by_id = {str(point["point_id"]): point for point in ephemeris.points}
    lunar = derive_lunar_phase(
        point_by_id["sun"]["position"]["ecliptic"]["longitude_deg"],
        point_by_id["moon"]["position"]["ecliptic"]["longitude_deg"],
    )
    aspect_profile, orb_profile, orb_overrides = _aspect_profiles(settings)
    house_result = _house_calculation(
        request_payload=request_payload,
        julian_day_ut=ephemeris.julian_day_ut,
        location=location,
    )
    if ephemeris.true_obliquity_deg is None:
        raise AstronomicalSnapshotInputError(
            "Swiss Ephemeris did not return the true obliquity required for canonical "
            "equatorial coordinates and chart-dependent points."
        )
    obliquity_deg = float(ephemeris.true_obliquity_deg)
    available_points = add_opposite_nodes(
        ephemeris.points,
        obliquity_deg=obliquity_deg,
        julian_day_ut=ephemeris.julian_day_ut,
    )
    available_points.extend(
        angle_points_from_house_result(
            house_result,
            obliquity_deg=obliquity_deg,
            julian_day_ut=ephemeris.julian_day_ut,
        )
    )
    day_night_status, sun_altitude_deg = _day_night_status(
        sun_point=point_by_id["sun"],
        latitude_deg=float(location["latitude"]),
        longitude_deg=float(location["longitude"]),
        greenwich_sidereal_time_deg=ephemeris.greenwich_sidereal_time_deg,
    )
    lot_documents: list[dict[str, Any]] = []
    point_selection_warnings: list[dict[str, Any]] = []
    requested_lot_ids = set(DEFAULT_LOT_IDS) & set(final_point_ids)
    effective_point_ids = final_point_ids
    if requested_lot_ids and day_night_status in {"day", "night"}:
        asc_point = next(
            (point for point in available_points if point["point_id"] == "asc"),
            None,
        )
        if asc_point is None:
            raise AstronomicalSnapshotInputError(
                "The requested sect-aware Lots require a calculable Ascendant."
            )
        supported_lots = calculate_supported_lots(
            asc_longitude_deg=float(asc_point["position"]["ecliptic"]["longitude_deg"]),
            sun_longitude_deg=float(point_by_id["sun"]["position"]["ecliptic"]["longitude_deg"]),
            moon_longitude_deg=float(point_by_id["moon"]["position"]["ecliptic"]["longitude_deg"]),
            mercury_longitude_deg=float(
                point_by_id["mercury"]["position"]["ecliptic"]["longitude_deg"]
            ),
            venus_longitude_deg=float(
                point_by_id["venus"]["position"]["ecliptic"]["longitude_deg"]
            ),
            mars_longitude_deg=float(point_by_id["mars"]["position"]["ecliptic"]["longitude_deg"]),
            jupiter_longitude_deg=float(
                point_by_id["jupiter"]["position"]["ecliptic"]["longitude_deg"]
            ),
            saturn_longitude_deg=float(
                point_by_id["saturn"]["position"]["ecliptic"]["longitude_deg"]
            ),
            sect=Sect(day_night_status),
        )
        lot_documents = [
            lot_fact.to_dict()
            for lot_fact in supported_lots
            if lot_fact.lot_id.value in requested_lot_ids
        ]
        for lot_fact in supported_lots:
            if lot_fact.lot_id.value in requested_lot_ids:
                available_points.append(
                    lot_point_from_fact(
                        lot_fact,
                        obliquity_deg=obliquity_deg,
                        julian_day_ut=ephemeris.julian_day_ut,
                    )
                )
    elif requested_lot_ids:
        effective_point_ids = tuple(
            point_id for point_id in final_point_ids if point_id not in requested_lot_ids
        )
        point_selection_warnings.append(
            _warning(
                "LOT_REQUIRES_RESOLVED_SECT",
                "Sect-aware Lots were not fabricated because day/night status is "
                "indeterminate at the configured horizon tolerance.",
                details={"point_ids": sorted(requested_lot_ids)},
            )
        )
    points = _selected_points(available_points, effective_point_ids)
    points, solar_conditions = _enrich_point_conditions(
        points,
        obliquity_deg=obliquity_deg,
    )
    points, house_set = _place_points(points, house_result.house_set)
    fixed_star_ids = tuple(str(item) for item in settings.get("fixed_star_ids") or ())
    custom_parameters = settings.get("custom_parameters") or {}
    fixed_star_orb = float(
        custom_parameters.get("fixed_star_conjunction_orb_deg", 1.0)
    )
    try:
        fixed_star_result = SwissFixedStarCalculator(
            ephemeris_path=calculator.ephemeris_path,
        ).calculate(
            julian_day_ut=ephemeris.julian_day_ut,
            star_ids=fixed_star_ids,
            zodiac=zodiac,
            ayanamsa=settings.get("ayanamsa"),
        )
        fixed_star_contacts = calculate_fixed_star_contacts(
            fixed_star_result.stars,
            points,
            conjunction_orb_deg=fixed_star_orb,
        ) if fixed_star_ids else []
    except ValueError as exc:
        raise AstronomicalSnapshotInputError(str(exc)) from exc
    aspects, aspect_evaluation = _major_aspects(
        points,
        aspect_profile=aspect_profile,
        orb_profile=orb_profile,
        orb_overrides=orb_overrides,
    )
    mirror_document = calculate_mirror_points(
        points,
        profile=mirror_profile(
            contact_orb_deg=float(custom_parameters.get("mirror_contact_orb_deg", 1.0))
        ),
    ).to_dict()
    if zodiac == "tropical":
        special_degree_document = calculate_special_degrees(points).to_dict()
    else:
        special_degree_document = {
            "availability": "not_applicable",
            "unavailable_reason": "TROPICAL_ZODIAC_REQUIRED",
            "points": [],
            "critical_degrees": {
                "status": "not_evaluated",
                "table_id": None,
                "reason_code": "TROPICAL_ZODIAC_REQUIRED",
                "rule_ids": [],
                "source_ids": [],
            },
            "provenance": {
                "capability_id": "natal.special_degrees.v1",
                "profile_id": DEFAULT_SPECIAL_DEGREE_PROFILE.profile_id,
                "profile_zodiac": DEFAULT_SPECIAL_DEGREE_PROFILE.zodiac,
                "interpretation_boundary": (
                    "The selected sidereal zodiac was not evaluated against a tropical-only "
                    "special-degree profile"
                ),
            },
        }
    midpoint_document = calculate_midpoints(
        points,
        source_point_ids=("sun", "moon", "mercury", "venus", "mars", "jupiter"),
        aspect_profile=aspect_profile,
        hit_orb_deg=float(custom_parameters.get("midpoint_hit_orb_deg", 1.0)),
    ).to_dict()
    structure_document = calculate_natal_structure(points, aspects).to_dict()
    pattern_documents = [
        *structure_document["stelliums"]["facts"],
        *structure_document["geometric_patterns"]["facts"],
    ]
    terms_table, triplicity_table = _classical_tables(settings)
    classical_document, dignity_documents, reception_documents = _classical_documents(
        points,
        day_night_status=day_night_status,
        sun_altitude_deg=sun_altitude_deg,
        solar_conditions=solar_conditions,
        terms_table=terms_table,
        triplicity_table=triplicity_table,
    )
    is_natal = str(request_payload["chart"]["family"]) == "natal"
    local_birth_value = str(time_spec.get("local_value") or "")
    try:
        birth_date = datetime.fromisoformat(local_birth_value).date()
    except ValueError as exc:
        raise AstronomicalSnapshotInputError(
            "selected chart time requires an ISO local date"
        ) from exc
    asc_point = next((point for point in points if point["point_id"] == "asc"), None)
    profection_document = (
        calculate_annual_profections(
            birth_date=birth_date,
            ascendant_sign=str(asc_point["sign"]),
            as_of=now.date(),
        )
        if is_natal and asc_point is not None
        else None
    )
    firdaria_document = (
        calculate_firdaria(
            birth_utc=utc_instant,
            sect=Sect(day_night_status),
            as_of=now,
        )
        if is_natal and day_night_status in {"day", "night"}
        else None
    )
    zodiacal_releasing_documents: dict[str, Any] = {}
    if is_natal:
        for lot_id in ("fortune", "spirit"):
            lot_point = next((point for point in points if point["point_id"] == lot_id), None)
            if lot_point is not None:
                zodiacal_releasing_documents[lot_id] = calculate_zodiacal_releasing(
                    lot_id=lot_id,
                    lot_sign=str(lot_point["sign"]),
                    birth_utc=utc_instant,
                    as_of=now,
                )
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
            "ALG-NATAL-004",
            "ALG-NATAL-005",
            *(["ALG-NATAL-SPECIAL-DEGREES-001"] if zodiac == "tropical" else []),
            "ALG-NATAL-MIRROR-POINTS-001",
            "ALG-NATAL-MIDPOINTS-001",
            "ALG-TIMING-PROFECTIONS-001",
            "ALG-TIMING-FIRDARIA-001",
            "ALG-TIMING-ZR-001",
        ],
        "rule_refs": [
            "astronomy.ephemeris_core",
            "astronomy.houses_angles",
            "astronomy.aspects",
            "natal.patterns_distributions",
            "natal.dignity_reception",
            "natal.arabic_parts",
            *(["natal.special_degrees.v1"] if zodiac == "tropical" else []),
            "aspect.mirror.v1",
            "natal.midpoints",
            "timing.annual_profections",
            "timing.firdaria",
            "timing.zodiacal_releasing",
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
    classical_warnings: list[dict[str, Any]] = []
    if classical_document["availability"] != "available":
        classical_warnings.append(
            _warning(
                "CLASSICAL_FACTS_INDETERMINATE",
                "Some classical natal facts are indeterminate; inspect the explicit "
                "unavailable reasons instead of inferring a score.",
                details={
                    "reasons": classical_document["unavailable_reasons"],
                    "missing_traditional_planet_ids": classical_document[
                        "missing_traditional_planet_ids"
                    ],
                },
            )
        )
    all_warnings = [
        *adapter_warnings,
        *house_warnings,
        *point_selection_warnings,
        *distribution_warnings,
        *classical_warnings,
    ]
    chart_id = f"chart-{snapshot_id}"
    astronomical_context = {
        "utc": _timestamp(utc_instant),
        "julian_day_ut": ephemeris.julian_day_ut,
        "julian_day_tt": ephemeris.julian_day_tt,
        "delta_t_seconds": ephemeris.delta_t_seconds,
        "greenwich_sidereal_time_deg": ephemeris.greenwich_sidereal_time_deg,
        "local_sidereal_time_deg": (
            (ephemeris.greenwich_sidereal_time_deg + float(location["longitude"])) % 360
            if ephemeris.greenwich_sidereal_time_deg is not None
            else None
        ),
        "obliquity_deg": obliquity_deg,
        "mean_obliquity_deg": ephemeris.mean_obliquity_deg,
        "nutation_longitude_deg": ephemeris.nutation_longitude_deg,
        "nutation_obliquity_deg": ephemeris.nutation_obliquity_deg,
        "sunrise_utc": None,
        "sunset_utc": None,
        "day_night_status": day_night_status,
        "sun_altitude_deg": sun_altitude_deg,
        "precession_model": "swiss_ephemeris_apparent_of_date",
        "nutation_model": "swiss_ephemeris_ecl_nut",
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
        "aspect_evaluation": deepcopy(aspect_evaluation),
        "distributions": deepcopy(distributions),
        "structure": deepcopy(structure_document),
        "patterns": deepcopy(pattern_documents),
        "classical": deepcopy(classical_document),
        "dignities": deepcopy(dignity_documents),
        "receptions": deepcopy(reception_documents),
        "lots": deepcopy(lot_documents),
        "fixed_stars": deepcopy(list(fixed_star_result.stars)),
        "fixed_star_contacts": deepcopy(fixed_star_contacts),
        "special_degrees": deepcopy(special_degree_document),
        "mirror_points": deepcopy(mirror_document),
        "midpoints": deepcopy(midpoint_document),
        "profections": deepcopy(profection_document),
        "firdaria": deepcopy(firdaria_document),
        "zodiacal_releasing": deepcopy(zodiacal_releasing_documents),
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
    structure_status = (
        "generated" if structure_document["availability"] == "available" else "blocked"
    )
    classical_status = (
        "generated" if classical_document["availability"] == "available" else "blocked"
    )
    lots_requested = bool(set(DEFAULT_LOT_IDS) & set(final_point_ids))
    lots_status = "generated" if lot_documents else "blocked"
    fixed_stars_status = "generated" if fixed_star_ids else "not_requested"
    natal_status = (
        "blocked"
        if house_result.status == "unavailable"
        else "degraded"
        if (
            house_result.status == "degraded"
            or not distributions_available
            or structure_status != "generated"
            or classical_status != "generated"
            or (lots_requested and lots_status != "generated")
        )
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
            "status": (
                "generated"
                if distribution_status == "generated" and structure_status == "generated"
                else "blocked"
            ),
            "calculation_id": "natal.patterns_distributions",
            "result_pointer": (
                "/result/structure"
                if distribution_status == "generated" and structure_status == "generated"
                else None
            ),
            "maturity": "experimental",
            "view_ids": ["view.natal.structure"],
            "table_ids": [
                "table.elements",
                "table.modalities",
                "table.polarity",
                "table.chart_patterns",
            ],
            "export_formats": ["json", "csv"],
            "recommended_primary_view_id": None,
            "missing_inputs": (
                []
                if distribution_status == "generated" and structure_status == "generated"
                else ["complete_profile_points_and_houses"]
            ),
            "warnings": deepcopy(distribution_warnings),
            "algorithm_cards": ["ALG-NATAL-003"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.dignity_reception",
            "status": classical_status,
            "calculation_id": "natal.dignity_reception",
            "result_pointer": "/result/classical" if classical_status == "generated" else None,
            "maturity": "experimental",
            "view_ids": ["view.natal.classical"],
            "table_ids": [
                "table.essential_dignities",
                "table.receptions",
                "graph.dispositor_chain",
                "table.sect_condition",
            ],
            "export_formats": ["json", "csv", "markdown_technical"],
            "recommended_primary_view_id": None,
            "missing_inputs": (
                [] if classical_status == "generated" else ["resolved_sect_and_traditional_seven"]
            ),
            "warnings": deepcopy(classical_warnings),
            "algorithm_cards": ["ALG-NATAL-004"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.arabic_parts",
            "status": lots_status,
            "calculation_id": "natal.arabic_parts",
            "result_pointer": "/result/lots" if lots_status == "generated" else None,
            "maturity": "experimental",
            "view_ids": ["view.natal.lots"],
            "table_ids": ["table.arabic_parts"],
            "export_formats": ["json", "csv", "markdown_technical"],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if lots_status == "generated" else ["requested_lots"],
            "warnings": deepcopy(point_selection_warnings),
            "algorithm_cards": ["ALG-NATAL-005"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.astronomy.fixed_stars",
            "status": fixed_stars_status,
            "calculation_id": "astronomy.fixed_stars",
            "result_pointer": "/result/fixed_stars" if fixed_star_ids else None,
            "maturity": "experimental",
            "view_ids": ["view.natal.fixed_stars"] if fixed_star_ids else [],
            "table_ids": ["table.fixed_stars", "table.fixed_star_contacts"]
            if fixed_star_ids
            else [],
            "export_formats": ["json", "csv"] if fixed_star_ids else [],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if fixed_star_ids else ["fixed_star_ids"],
            "warnings": [],
            "algorithm_cards": ["ALG-ASTRONOMY-FIXED-STARS-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.special_degrees",
            "status": "generated" if zodiac == "tropical" else "blocked",
            "calculation_id": "natal.special_degrees.v1",
            "result_pointer": "/result/special_degrees" if zodiac == "tropical" else None,
            "maturity": "experimental",
            "view_ids": ["view.natal.special_degrees"] if zodiac == "tropical" else [],
            "table_ids": ["table.special_degrees"] if zodiac == "tropical" else [],
            "export_formats": ["json", "plaintext_technical"] if zodiac == "tropical" else [],
            "recommended_primary_view_id": None,
            "missing_inputs": [] if zodiac == "tropical" else ["zodiac:tropical"],
            "warnings": [],
            "algorithm_cards": ["ALG-NATAL-SPECIAL-DEGREES-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.mirror_points",
            "status": "generated",
            "calculation_id": "aspect.mirror.v1",
            "result_pointer": "/result/mirror_points",
            "maturity": "experimental",
            "view_ids": ["view.natal.mirror_points"],
            "table_ids": ["table.mirror_points", "table.mirror_contacts"],
            "export_formats": ["json", "plaintext_technical"],
            "recommended_primary_view_id": None,
            "missing_inputs": [],
            "warnings": [],
            "algorithm_cards": ["ALG-NATAL-MIRROR-POINTS-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.midpoints",
            "status": "generated",
            "calculation_id": "natal.midpoints",
            "result_pointer": "/result/midpoints",
            "maturity": "experimental",
            "view_ids": ["view.natal.midpoints"],
            "table_ids": ["table.midpoints", "table.midpoint_hits"],
            "export_formats": ["json", "plaintext_technical"],
            "recommended_primary_view_id": None,
            "missing_inputs": [],
            "warnings": [],
            "algorithm_cards": ["ALG-NATAL-MIDPOINTS-001"],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.timing.natal_periods",
            "status": "generated" if profection_document and firdaria_document else "blocked",
            "calculation_id": "timing.natal_periods",
            "result_pointer": "/result/profections" if profection_document else None,
            "maturity": "experimental",
            "view_ids": ["view.natal.firdaria", "view.natal.profections", "view.natal.zr"],
            "table_ids": [
                "table.annual_profections",
                "table.firdaria",
                "table.zodiacal_releasing",
            ],
            "export_formats": ["json", "plaintext_technical"],
            "recommended_primary_view_id": None,
            "missing_inputs": (
                []
                if profection_document and firdaria_document
                else ["resolved_ascendant_and_sect"]
            ),
            "warnings": [],
            "algorithm_cards": [
                "ALG-TIMING-PROFECTIONS-001",
                "ALG-TIMING-FIRDARIA-001",
                "ALG-TIMING-ZR-001",
            ],
            "reproducibility": reproducibility,
        },
        {
            "output_id": "manifest.natal.standard_chart",
            "status": natal_status,
            "calculation_id": "natal.standard_chart",
            "result_pointer": "/result/charts/0" if house_set else None,
            "maturity": "experimental",
            "view_ids": [
                "wheel.natal",
                "view.natal.basic",
                "view.natal.classical",
                "view.natal.structure",
                "view.natal.technical_document",
            ],
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
            "export_formats": [
                "svg",
                "png",
                "pdf",
                "json",
                "csv",
                "markdown_technical",
                "plaintext_technical",
            ]
            if house_set
            else [],
            "recommended_primary_view_id": "wheel.natal" if house_set else None,
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
    if not is_natal:
        manifests = [
            manifest
            for manifest in manifests
            if manifest["output_id"] != "manifest.timing.natal_periods"
        ]
        chart_manifest = manifests[-1]
        chart_family = str(request_payload["chart"]["family"])
        chart_technique = str(request_payload["chart"]["technique"])
        if chart_family == "progression" and chart_technique == "progression.secondary":
            chart_manifest.update({
                "output_id": "manifest.progression.secondary",
                "calculation_id": "progression.secondary",
                "view_ids": [
                    "wheel.secondary_progression",
                    "view.secondary_progression.basic",
                    "view.secondary_progression.aspects",
                ],
                "recommended_primary_view_id": (
                    "wheel.secondary_progression" if house_set else None
                ),
                "algorithm_cards": [
                    "ALG-TIMING-SECONDARY-PROGRESSION-001",
                    "ALG-ASTRONOMY-001",
                    "ALG-ASTRONOMY-003",
                    "ALG-ASTRONOMY-004",
                ],
            })
        else:
            chart_manifest.update({
                "output_id": "manifest.mundane.current_sky",
                "calculation_id": "mundane.current_sky",
                "view_ids": [
                    "wheel.current_sky",
                    "view.current_sky.basic",
                    "view.current_sky.aspects",
                    "view.current_sky.events",
                ],
                "recommended_primary_view_id": (
                    "wheel.current_sky" if house_set else None
                ),
                "algorithm_cards": [
                    "ALG-ASTRONOMY-001",
                    "ALG-ASTRONOMY-003",
                    "ALG-ASTRONOMY-004",
                ],
            })
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
            "structure": deepcopy(structure_document),
            "patterns": deepcopy(pattern_documents),
            "classical": deepcopy(classical_document),
            "dignities": deepcopy(dignity_documents),
            "receptions": deepcopy(reception_documents),
            "lots": deepcopy(lot_documents),
            "fixed_stars": deepcopy(list(fixed_star_result.stars)),
            "fixed_star_contacts": deepcopy(fixed_star_contacts),
            "special_degrees": deepcopy(special_degree_document),
            "mirror_points": deepcopy(mirror_document),
            "midpoints": deepcopy(midpoint_document),
            "profections": deepcopy(profection_document),
            "firdaria": deepcopy(firdaria_document),
            "zodiacal_releasing": deepcopy(zodiacal_releasing_documents),
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
