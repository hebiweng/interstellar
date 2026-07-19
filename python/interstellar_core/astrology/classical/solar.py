"""Astrological solar-proximity conditions, distinct from physical visibility."""

from __future__ import annotations

import hashlib
import json

from interstellar_core.astrology.classical.models import (
    SolarConditionResult,
    SolarRelation,
    SolarThresholdProfile,
)
from interstellar_core.astrology.classical.sources import (
    ALG_DIGNITY_RECEPTION,
    RULE_SOLAR_CONDITION_V1,
    SRC_LILLY_CHRISTIAN_ASTROLOGY,
)
from interstellar_core.astrology.classical.tables import sign_and_degree


def _profile_hash(values: dict[str, object]) -> str:
    payload = json.dumps(values, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


_SOLAR_PROFILE_VALUES = {
    "profile_id": "solar_condition.lilly.v1",
    "version": "1.0.0",
    "cazimi_deg": 17 / 60,
    "combust_deg": 8.5,
    "under_beams_deg": 17.0,
    "source_ids": (SRC_LILLY_CHRISTIAN_ASTROLOGY,),
}
LILLY_SOLAR_THRESHOLDS_V1 = SolarThresholdProfile(
    **_SOLAR_PROFILE_VALUES,
    content_hash=_profile_hash(_SOLAR_PROFILE_VALUES),
)


def classify_solar_condition(
    point_id: str,
    point_longitude_deg: float,
    *,
    sun_longitude_deg: float,
    profile: SolarThresholdProfile = LILLY_SOLAR_THRESHOLDS_V1,
) -> SolarConditionResult:
    sign_and_degree(point_longitude_deg)
    sign_and_degree(sun_longitude_deg)
    raw = abs(point_longitude_deg - sun_longitude_deg)
    separation = min(raw, 360.0 - raw)
    if point_id == "sun":
        relation = SolarRelation.NOT_APPLICABLE
    elif separation <= profile.cazimi_deg:
        relation = SolarRelation.CAZIMI
    elif separation <= profile.combust_deg:
        relation = SolarRelation.COMBUST
    elif separation <= profile.under_beams_deg:
        relation = SolarRelation.UNDER_BEAMS
    else:
        relation = SolarRelation.FREE
    return SolarConditionResult(
        point_id=point_id,
        sun_longitude_deg=sun_longitude_deg,
        point_longitude_deg=point_longitude_deg,
        separation_deg=separation,
        relation=relation,
        threshold_profile=profile,
        algorithm_card_id=ALG_DIGNITY_RECEPTION,
        rule_ids=(RULE_SOLAR_CONDITION_V1,),
        source_ids=profile.source_ids,
        excluded_capabilities=("physical_visibility", "heliacal_events", "oriental_occidental"),
    )
