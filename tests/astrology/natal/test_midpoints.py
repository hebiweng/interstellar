from __future__ import annotations

import pytest

from interstellar_core.astrology.aspects import OFFICIAL_MAJOR_ASPECTS_V1
from interstellar_core.astrology.natal import calculate_midpoints, direct_indirect_midpoint


def point(point_id: str, longitude_deg: float) -> dict:
    return {
        "point_id": point_id,
        "position": {"ecliptic": {"longitude_deg": longitude_deg}},
    }


def test_shortest_arc_midpoint_crosses_zero_and_matches_gold_case() -> None:
    direct, indirect, ambiguous = direct_indirect_midpoint(350, 10)
    assert direct == pytest.approx(0)
    assert indirect == pytest.approx(180)
    assert ambiguous is False


def test_midpoint_result_includes_indirect_axis_and_within_orb_hits() -> None:
    result = calculate_midpoints(
        (point("sun", 350), point("moon", 10), point("mars", 90)),
        source_point_ids=("sun", "moon"),
        aspect_profile=OFFICIAL_MAJOR_ASPECTS_V1,
        hit_orb_deg=0,
    ).to_dict()
    assert result["midpoints"][0]["direct_midpoint_deg"] == pytest.approx(0)
    assert {
        (hit["midpoint_type"], hit["target_point_id"], hit["aspect_id"])
        for hit in result["hits"]
    } == {("direct", "mars", "square"), ("indirect", "mars", "square")}
