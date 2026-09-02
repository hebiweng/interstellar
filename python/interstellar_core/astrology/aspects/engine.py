"""Pure deterministic major-aspect calculation."""

from __future__ import annotations

import hashlib
from collections.abc import Mapping
from dataclasses import dataclass

from interstellar_core.astronomy.derived import smallest_angular_separation

from .models import (
    ApplyingReason,
    ApplyingState,
    AspectContext,
    AspectDirection,
    AspectPoint,
    CanonicalAspect,
    MajorAspectDefinition,
    MajorAspectProfile,
    OrbProfile,
)
from .orb_overrides import OrbOverrideSet
from .profiles import OFFICIAL_MAJOR_ASPECTS_V1, OFFICIAL_STANDARD_ORBS_V1


@dataclass(frozen=True, slots=True)
class _ApplyingClassification:
    state: ApplyingState
    reason: ApplyingReason


def _classify_applying_state(
    point_a: AspectPoint,
    point_b: AspectPoint,
    aspect: MajorAspectDefinition,
    current_orb_deg: float,
    orb_profile: OrbProfile,
) -> _ApplyingClassification:
    if current_orb_deg <= orb_profile.exact_tolerance_deg:
        return _ApplyingClassification(
            ApplyingState.EXACT,
            ApplyingReason.EXACT_WITHIN_TOLERANCE,
        )
    speed_a = point_a.longitude_speed_deg_per_day
    speed_b = point_b.longitude_speed_deg_per_day
    if speed_a is None or speed_b is None:
        return _ApplyingClassification(
            ApplyingState.INDETERMINATE,
            ApplyingReason.SPEED_UNAVAILABLE,
        )
    if abs(speed_b - speed_a) <= orb_profile.relative_stationary_threshold_deg_per_day:
        return _ApplyingClassification(
            ApplyingState.INDETERMINATE,
            ApplyingReason.RELATIVE_STATIONARY,
        )

    step = orb_profile.probe_step_days
    future_a = point_a.longitude_deg + speed_a * step
    future_b = point_b.longitude_deg + speed_b * step
    future_angle = smallest_angular_separation(future_a, future_b)
    future_orb = abs(future_angle - aspect.exact_angle_deg)
    change = future_orb - current_orb_deg
    if abs(change) <= orb_profile.probe_change_tolerance_deg:
        return _ApplyingClassification(
            ApplyingState.INDETERMINATE,
            ApplyingReason.PROBE_CHANGE_BELOW_TOLERANCE,
        )
    if change < 0:
        return _ApplyingClassification(
            ApplyingState.APPLYING,
            ApplyingReason.PROBED_FORWARD,
        )
    return _ApplyingClassification(
        ApplyingState.SEPARATING,
        ApplyingReason.PROBED_FORWARD,
    )


def _canonical_point_order(point_a: AspectPoint, point_b: AspectPoint) -> tuple[str, str]:
    return tuple(sorted((point_a.id, point_b.id)))


def _build_aspect_id(
    point_a_id: str,
    point_b_id: str,
    context: AspectContext,
    aspect_type: str,
) -> str:
    readable = f"aspect:{context.value}:{point_a_id}:{point_b_id}:{aspect_type}"
    if len(readable) <= 160:
        return readable
    digest = hashlib.sha256(readable.encode("utf-8")).hexdigest()
    return f"aspect:{context.value}:{aspect_type}:sha256:{digest}"


def find_major_aspects(
    point_a: AspectPoint,
    point_b: AspectPoint,
    *,
    context: AspectContext = AspectContext.WITHIN_CHART,
    major_profile: MajorAspectProfile = OFFICIAL_MAJOR_ASPECTS_V1,
    orb_profile: OrbProfile = OFFICIAL_STANDARD_ORBS_V1,
    orb_overrides: OrbOverrideSet | None = None,
    point_classes: Mapping[str, str] | None = None,
) -> tuple[CanonicalAspect, ...]:
    """Return every major-aspect hit, ordered by orb then profile order."""
    if point_a.id == point_b.id:
        raise ValueError("an aspect requires two distinct point ids")
    actual_angle = smallest_angular_separation(
        point_a.longitude_deg,
        point_b.longitude_deg,
    )
    canonical_a, canonical_b = _canonical_point_order(point_a, point_b)
    hits: list[tuple[float, int, CanonicalAspect]] = []
    for profile_index, aspect in enumerate(major_profile.aspects):
        preset_orb = orb_profile.effective_orb(aspect.id)
        effective = (
            orb_overrides.resolve(
                preset_orb_deg=preset_orb,
                preset_rule_ref=f"{orb_profile.id}@{orb_profile.version}",
                preset_source=orb_profile.source,
                context=context,
                aspect_id=aspect.id,
                point_a=canonical_a,
                point_b=canonical_b,
                point_classes=point_classes,
            )
            if orb_overrides is not None
            else None
        )
        effective_orb = effective.orb_deg if effective is not None else preset_orb
        error = abs(actual_angle - aspect.exact_angle_deg)
        if error > effective_orb:
            continue
        orb_ratio = 1.0 if effective_orb == 0 else max(0.0, 1.0 - error / effective_orb)
        applying = _classify_applying_state(
            point_a,
            point_b,
            aspect,
            error,
            orb_profile,
        )
        hits.append(
            (
                error,
                profile_index,
                CanonicalAspect(
                    aspect_id=_build_aspect_id(
                        canonical_a,
                        canonical_b,
                        context,
                        aspect.id,
                    ),
                    point_a=canonical_a,
                    point_b=canonical_b,
                    context=context,
                    type=aspect.id,
                    exact_angle_deg=aspect.exact_angle_deg,
                    actual_angle_deg=actual_angle,
                    orb_deg=error,
                    orb_ratio=orb_ratio,
                    applying_state=applying.state,
                    applying_reason=applying.reason,
                    direction=AspectDirection.NOT_APPLICABLE,
                    strength=orb_ratio,
                    entered_at=None,
                    exact_hits=(),
                    left_at=None,
                    rule_refs=(
                        "ALG-ASTRONOMY-004",
                        f"{major_profile.id}@{major_profile.version}",
                        f"{orb_profile.id}@{orb_profile.version}",
                        *(
                            (effective.rule_ref,)
                            if effective is not None and effective.scope != "preset"
                            else ()
                        ),
                    ),
                ),
            )
        )
    hits.sort(key=lambda hit: (hit[0], hit[1]))
    return tuple(hit[2] for hit in hits)


def find_closest_major_aspect(
    point_a: AspectPoint,
    point_b: AspectPoint,
    *,
    context: AspectContext = AspectContext.WITHIN_CHART,
    major_profile: MajorAspectProfile = OFFICIAL_MAJOR_ASPECTS_V1,
    orb_profile: OrbProfile = OFFICIAL_STANDARD_ORBS_V1,
    orb_overrides: OrbOverrideSet | None = None,
    point_classes: Mapping[str, str] | None = None,
) -> CanonicalAspect | None:
    """Return the tightest hit; no-hit is represented by ``None``."""
    hits = find_major_aspects(
        point_a,
        point_b,
        context=context,
        major_profile=major_profile,
        orb_profile=orb_profile,
        orb_overrides=orb_overrides,
        point_classes=point_classes,
    )
    return hits[0] if hits else None
