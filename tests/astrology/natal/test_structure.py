from __future__ import annotations

from collections.abc import Iterable

import pytest

from interstellar_core.astrology.natal import (
    JonesShapeStatus,
    StructureAvailability,
    StructureProfile,
    calculate_natal_structure,
)
from interstellar_core.domain.errors import DomainError


def point(point_id: str, longitude: float, house: int | None = 1) -> dict:
    return {
        "point_id": point_id,
        "position": {"ecliptic": {"longitude_deg": longitude}},
        "house": house,
    }


def aspect(point_a: str, point_b: str, aspect_type: str) -> dict:
    ordered = tuple(sorted((point_a, point_b)))
    return {
        "aspect_id": f"aspect:{ordered[0]}:{ordered[1]}:{aspect_type}",
        "point_a": point_a,
        "point_b": point_b,
        "type": aspect_type,
    }


def aspects(entries: Iterable[tuple[str, str, str]]) -> list[dict]:
    return [aspect(*entry) for entry in entries]


def profile(*point_ids: str) -> StructureProfile:
    return StructureProfile(
        profile_id="test.structure.profile",
        version="1.0.0",
        tradition="test",
        participant_ids=tuple(point_ids),
        description="Synthetic deterministic structure test profile",
    )


def category_map(result) -> dict[str, tuple[str, ...]]:  # type: ignore[no-untyped-def]
    return {item.category_id: item.point_ids for item in result.categories}


def test_house_distributions_angularity_and_provenance_are_versioned_facts() -> None:
    result = calculate_natal_structure(
        (
            point("a", 2, 1),
            point("b", 93, 4),
            point("c", 181, 7),
            point("d", 271, 10),
            point("asc", 0, 1),
            point("dsc", 180, 7),
            point("mc", 270, 10),
            point("ic", 90, 4),
        ),
        (),
        profile=profile("a", "b", "c", "d"),
    )

    assert result.availability is StructureAvailability.AVAILABLE
    assert category_map(result.hemispheres) == {
        "below_horizon": ("a", "b"),
        "above_horizon": ("c", "d"),
        "eastern": ("a", "d"),
        "western": ("b", "c"),
    }
    assert category_map(result.quadrants) == {
        "quadrant_1": ("a",),
        "quadrant_2": ("b",),
        "quadrant_3": ("c",),
        "quadrant_4": ("d",),
    }
    assert category_map(result.house_modes)["angular"] == ("a", "b", "c", "d")
    assert all(fact.house_mode == "angular" for fact in result.angularity.facts)
    assert all(fact.band == "on_angle" for fact in result.angularity.facts)
    assert result.angularity.available_angle_ids == ("asc", "dsc", "mc", "ic")
    assert result.jones_shape.status is JonesShapeStatus.INDETERMINATE
    assert result.jones_shape.shape_id is None
    assert result.jones_shape.reasons == (
        "NO_VERSIONED_JONES_CLASSIFICATION_RULE_IN_PROFILE",
    )
    provenance = result.provenance
    assert provenance.profile_content_hash.startswith("sha256:")
    assert provenance.interpretation_boundary.startswith("Geometry and placement facts")
    assert provenance.evaluation_counts == result.to_dict()["provenance"][
        "evaluation_counts"
    ] or provenance.evaluation_counts.profile_participant_count == 4


def test_longitude_stellium_wraps_across_zero_without_false_sign_or_house_group() -> None:
    result = calculate_natal_structure(
        (
            point("a", 358, 12),
            point("b", 1, 1),
            point("c", 5, 2),
        ),
        (),
        profile=profile("a", "b", "c"),
    )

    longitude_clusters = [
        fact for fact in result.stelliums.facts if fact.kind == "longitude_cluster"
    ]
    assert len(longitude_clusters) == 1
    cluster = longitude_clusters[0]
    assert cluster.participant_ids == ("a", "b", "c")
    assert cluster.longitude_start_deg == 358
    assert cluster.longitude_span_deg == 7
    assert not [fact for fact in result.stelliums.facts if fact.kind == "sign"]
    assert not [fact for fact in result.stelliums.facts if fact.kind == "house"]
    assert result.stelliums.evaluated_longitude_window_count == 3


@pytest.mark.parametrize(
    ("pattern_type", "point_ids", "edges"),
    [
        (
            "grand_trine",
            ("a", "b", "c"),
            (("a", "b", "trine"), ("a", "c", "trine"), ("b", "c", "trine")),
        ),
        (
            "t_square",
            ("a", "b", "c"),
            (
                ("a", "b", "opposition"),
                ("a", "c", "square"),
                ("b", "c", "square"),
            ),
        ),
        (
            "grand_cross",
            ("a", "b", "c", "d"),
            (
                ("a", "b", "opposition"),
                ("c", "d", "opposition"),
                ("a", "c", "square"),
                ("a", "d", "square"),
                ("b", "c", "square"),
                ("b", "d", "square"),
            ),
        ),
        (
            "yod",
            ("a", "b", "c"),
            (
                ("a", "b", "sextile"),
                ("a", "c", "quincunx"),
                ("b", "c", "quincunx"),
            ),
        ),
        (
            "kite",
            ("a", "b", "c", "d"),
            (
                ("a", "b", "trine"),
                ("a", "c", "trine"),
                ("b", "c", "trine"),
                ("a", "d", "opposition"),
                ("b", "d", "sextile"),
                ("c", "d", "sextile"),
            ),
        ),
        (
            "mystic_rectangle",
            ("a", "b", "c", "d"),
            (
                ("a", "b", "opposition"),
                ("c", "d", "opposition"),
                ("a", "c", "trine"),
                ("a", "d", "sextile"),
                ("b", "c", "sextile"),
                ("b", "d", "trine"),
            ),
        ),
    ],
)
def test_required_geometric_patterns_are_detected_from_canonical_aspect_edges(
    pattern_type: str,
    point_ids: tuple[str, ...],
    edges: tuple[tuple[str, str, str], ...],
) -> None:
    result = calculate_natal_structure(
        tuple(point(point_id, index * 40, index + 1) for index, point_id in enumerate(point_ids)),
        aspects(edges),
        profile=profile(*point_ids),
    )

    matches = [
        fact
        for fact in result.geometric_patterns.facts
        if fact.pattern_type == pattern_type
    ]
    assert matches
    assert matches[0].participant_ids == tuple(sorted(point_ids))
    assert matches[0].evidence_aspect_ids
    assert matches[0].rule_ref.endswith(f"{pattern_type}.v1")


def test_multiple_patterns_are_preserved_and_candidate_counts_are_explicit() -> None:
    point_ids = ("a", "b", "c", "d", "e", "f")
    result = calculate_natal_structure(
        tuple(point(point_id, index * 30, index % 12 + 1) for index, point_id in enumerate(point_ids)),
        aspects(
            (
                ("a", "b", "trine"),
                ("a", "c", "trine"),
                ("b", "c", "trine"),
                ("d", "e", "sextile"),
                ("d", "f", "quincunx"),
                ("e", "f", "quincunx"),
            )
        ),
        profile=profile(*point_ids),
    )

    pattern_types = {fact.pattern_type for fact in result.geometric_patterns.facts}
    assert {"grand_trine", "yod"} <= pattern_types
    evaluations = {
        item.pattern_type: item for item in result.geometric_patterns.evaluations
    }
    assert evaluations["grand_trine"].candidate_combination_count == 20
    assert evaluations["yod"].candidate_combination_count == 20
    assert evaluations["kite"].candidate_combination_count == 15
    assert evaluations["grand_trine"].matched_pattern_count == 1
    assert evaluations["yod"].matched_pattern_count == 1


def test_profile_projection_and_evaluation_counts_do_not_silently_include_extra_points() -> None:
    result = calculate_natal_structure(
        (
            point("a", 0, 1),
            point("b", 60, 2),
            point("c", 120, 3),
            point("d", 180, 4),
            point("extra", 90, 10),
        ),
        aspects((('a', 'b', 'trine'), ('a', 'extra', 'square'))),
        profile=profile("a", "b", "c", "d"),
    )

    counts = result.provenance.evaluation_counts
    assert counts.supplied_point_count == 5
    assert counts.profile_expected_point_count == 4
    assert counts.profile_participant_count == 4
    assert counts.excluded_point_count == 1
    assert counts.expected_point_pair_count == 6
    assert counts.supplied_aspect_count == 2
    assert counts.usable_aspect_count == 1
    assert result.provenance.excluded_point_ids == ("extra",)
    assert result.geometric_patterns.excluded_aspect_count == 1


def test_missing_profile_points_and_houses_are_explicitly_indeterminate() -> None:
    result = calculate_natal_structure(
        (point("a", 0, None), point("b", 60, 2)),
        (),
        profile=profile("a", "b", "c"),
    )

    assert result.availability is StructureAvailability.INDETERMINATE
    assert result.unavailable_reasons == (
        "MISSING_PROFILE_PARTICIPANTS",
        "MISSING_HOUSE_ASSIGNMENTS",
    )
    assert result.provenance.missing_participant_ids == ("c",)
    assert result.hemispheres.availability is StructureAvailability.INDETERMINATE
    assert result.angularity.availability is StructureAvailability.INDETERMINATE


def test_duplicate_points_and_unknown_aspect_endpoints_are_rejected() -> None:
    with pytest.raises(DomainError, match="point supplied more than once"):
        calculate_natal_structure(
            (point("a", 0), point("a", 10)),
            (),
            profile=profile("a"),
        )

    with pytest.raises(DomainError, match="not present in canonical points"):
        calculate_natal_structure(
            (point("a", 0), point("b", 10), point("c", 20)),
            (aspect("a", "missing", "trine"),),
            profile=profile("a", "b", "c"),
        )
