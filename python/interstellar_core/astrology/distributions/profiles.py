"""Official immutable distribution profiles."""

from __future__ import annotations

from interstellar_core.domain.errors import DomainError

from .models import DimensionThreshold, DistributionProfile, PointWeight

_THRESHOLDS_V1 = (
    DimensionThreshold("elements", missing_weight_max=0.0, overrepresented_percentage_min=40.0),
    DimensionThreshold("modalities", missing_weight_max=0.0, overrepresented_percentage_min=50.0),
    DimensionThreshold("polarities", missing_weight_max=0.0, overrepresented_percentage_min=65.0),
)

MODERN_TEN_PROFILE_V1 = DistributionProfile(
    profile_id="official.distribution.modern_ten.v1",
    version="1.0.0",
    tradition="modern_western",
    point_weights=(
        PointWeight("sun", 2.0),
        PointWeight("moon", 2.0),
        PointWeight("mercury", 1.0),
        PointWeight("venus", 1.0),
        PointWeight("mars", 1.0),
        PointWeight("jupiter", 1.0),
        PointWeight("saturn", 1.0),
        PointWeight("uranus", 1.0),
        PointWeight("neptune", 1.0),
        PointWeight("pluto", 1.0),
    ),
    thresholds=_THRESHOLDS_V1,
    description=("Ten-body modern profile: Sun and Moon weight 2; Mercury through Pluto weight 1"),
)

CLASSICAL_SEVEN_PROFILE_V1 = DistributionProfile(
    profile_id="official.distribution.classical_seven.v1",
    version="1.0.0",
    tradition="classical_western",
    point_weights=(
        PointWeight("sun", 2.0),
        PointWeight("moon", 2.0),
        PointWeight("mercury", 1.0),
        PointWeight("venus", 1.0),
        PointWeight("mars", 1.0),
        PointWeight("jupiter", 1.0),
        PointWeight("saturn", 1.0),
    ),
    thresholds=_THRESHOLDS_V1,
    description="Classical seven-planet profile: Sun and Moon weight 2; other five weight 1",
)

_PROFILES = {
    profile.profile_id: profile for profile in (MODERN_TEN_PROFILE_V1, CLASSICAL_SEVEN_PROFILE_V1)
}


def profile_by_id(profile_id: str) -> DistributionProfile:
    try:
        return _PROFILES[profile_id]
    except KeyError as exc:
        raise DomainError(
            "DISTRIBUTION_PROFILE_UNKNOWN", f"unknown distribution profile: {profile_id}"
        ) from exc
