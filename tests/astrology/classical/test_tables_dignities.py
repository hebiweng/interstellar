from __future__ import annotations

import pytest

from interstellar_core.astrology.classical import (
    CHALDEAN_FACES_TABLE_REF,
    DOROTHEAN_TRIPLICITY_TABLE_REF,
    EGYPTIAN_TERMS,
    EGYPTIAN_TERMS_TABLE_REF,
    EXALTATION_TABLE_REF,
    MODERN_RULERSHIP_TABLE_REF,
    TRADITIONAL_RULERSHIP_TABLE_REF,
    DignityKind,
    EssentialStatusLevel,
    EssentialStatusPolarity,
    Sect,
    TriplicityRole,
    evaluate_essential_dignity,
    face_ruler,
    term_ruler,
)
from interstellar_core.domain import DomainError


def _kinds(result: object, attribute: str) -> set[DignityKind]:
    return {item.kind for item in getattr(result, attribute)}


def test_every_classical_table_has_stable_version_sources_and_hash() -> None:
    for table in (
        TRADITIONAL_RULERSHIP_TABLE_REF,
        MODERN_RULERSHIP_TABLE_REF,
        EXALTATION_TABLE_REF,
        DOROTHEAN_TRIPLICITY_TABLE_REF,
        EGYPTIAN_TERMS_TABLE_REF,
        CHALDEAN_FACES_TABLE_REF,
    ):
        assert table.table_id.startswith("table.")
        assert table.version == "1.0.0"
        assert table.source_ids
        assert len(table.content_hash) == 64


def test_every_egyptian_terms_sign_is_contiguous_and_covers_zero_to_thirty() -> None:
    assert len(EGYPTIAN_TERMS) == 12
    for intervals in EGYPTIAN_TERMS.values():
        assert len(intervals) == 5
        assert intervals[0].start_deg == 0.0
        assert intervals[-1].end_deg == 30.0
        assert all(
            left.end_deg == right.start_deg
            for left, right in zip(intervals[:-1], intervals[1:], strict=True)
        )


@pytest.mark.parametrize(
    ("degree", "expected"),
    [
        (0.0, "jupiter"),
        (5.999999, "jupiter"),
        (6.0, "venus"),
        (13.999999, "venus"),
        (14.0, "mercury"),
        (21.0, "mars"),
        (26.0, "saturn"),
        (29.999999, "saturn"),
    ],
)
def test_egyptian_terms_use_half_open_boundaries(degree: float, expected: str) -> None:
    ruler_id, interval = term_ruler("aries", degree)
    assert ruler_id == expected
    assert interval.contains(degree)


@pytest.mark.parametrize(
    ("degree", "expected", "decan"),
    [(0.0, "mars", 1), (9.999999, "mars", 1), (10.0, "sun", 2), (20.0, "venus", 3)],
)
def test_chaldean_faces_use_ten_degree_boundaries(
    degree: float,
    expected: str,
    decan: int,
) -> None:
    assert face_ruler("aries", degree) == (expected, decan)


def test_sun_in_aries_day_has_exaltation_active_triplicity_and_face() -> None:
    result = evaluate_essential_dignity("sun", 19.0, sect=Sect.DAY)
    assert result.applicable is True
    assert result.peregrine is False
    assert _kinds(result, "dignities") == {
        DignityKind.EXALTATION,
        DignityKind.TRIPLICITY,
        DignityKind.FACE,
    }
    triplicity = next(
        item for item in result.dignities if item.kind is DignityKind.TRIPLICITY
    )
    assert triplicity.role is TriplicityRole.DAY
    assert triplicity.is_active_for_sect is True


def test_out_of_sect_triplicity_is_reported_but_does_not_prevent_peregrine() -> None:
    result = evaluate_essential_dignity("sun", 241.0, sect=Sect.NIGHT)
    triplicity = next(
        item for item in result.dignities if item.kind is DignityKind.TRIPLICITY
    )
    assert triplicity.role is TriplicityRole.DAY
    assert triplicity.is_active_for_sect is False
    assert result.peregrine is True


def test_detriment_and_fall_are_separate_debility_facts() -> None:
    sun = evaluate_essential_dignity("sun", 301.0, sect=Sect.DAY)
    moon = evaluate_essential_dignity("moon", 211.0, sect=Sect.NIGHT)
    assert DignityKind.DETRIMENT in _kinds(sun, "debilities")
    assert DignityKind.FALL in _kinds(moon, "debilities")


def test_non_traditional_planet_is_explicitly_unavailable() -> None:
    result = evaluate_essential_dignity("neptune", 350.0, sect=Sect.NIGHT)
    assert result.applicable is False
    assert result.unavailable_reason == "POINT_OUTSIDE_TRADITIONAL_SEVEN"
    assert result.dignities == ()
    assert result.debilities == ()
    assert result.peregrine is None


def test_invalid_degree_and_sect_are_rejected_instead_of_wrapped_or_guessed() -> None:
    with pytest.raises(DomainError) as longitude:
        evaluate_essential_dignity("sun", 360.0, sect=Sect.DAY)
    assert longitude.value.code == "CLASSICAL_LONGITUDE_INVALID"

    with pytest.raises(DomainError) as sect:
        evaluate_essential_dignity("sun", 0.0, sect="day")  # type: ignore[arg-type]
    assert sect.value.code == "CLASSICAL_SECT_INVALID"


def test_to_dict_serializes_enums_tuples_and_nested_table_refs() -> None:
    payload = evaluate_essential_dignity("sun", 19.0, sect=Sect.DAY).to_dict()
    assert payload["sect"] == "day"
    assert isinstance(payload["dignities"], list)
    assert payload["dignities"][0]["table_ref"]["content_hash"]
    assert payload["profile_id"] == "classical.essential.traditional_seven.v1"
    assert payload["status_facts"][0]["label_key"].startswith("classical.essential.")


def test_competitor_fixture_keeps_all_reliable_traditional_statuses() -> None:
    """The supplied 66-point export mixes traditions; only seven-planet facts belong here."""

    moon = evaluate_essential_dignity("moon", 285 + 40 / 60, sect=Sect.DAY)
    mercury = evaluate_essential_dignity("mercury", 341 + 38 / 60, sect=Sect.DAY)
    mars = evaluate_essential_dignity("mars", 13 + 52 / 60, sect=Sect.DAY)

    assert {item.status_id for item in moon.status_facts if item.active} >= {
        DignityKind.DETRIMENT,
        DignityKind.PEREGRINE,
    }
    assert {item.status_id for item in mercury.status_facts if item.active} >= {
        DignityKind.DETRIMENT,
        DignityKind.FALL,
        DignityKind.PEREGRINE,
    }
    assert {item.status_id for item in mars.status_facts if item.active} == {
        DignityKind.DOMICILE
    }

    mercury_fall = next(
        item for item in mercury.status_facts if item.status_id is DignityKind.FALL
    )
    assert mercury_fall.polarity is EssentialStatusPolarity.DEBILITY
    assert mercury_fall.level is EssentialStatusLevel.MAJOR
    assert mercury_fall.table_ref is EXALTATION_TABLE_REF


@pytest.mark.parametrize("point_id", ["uranus", "true_north_node", "pallas", "cupido"])
def test_nontraditional_competitor_labels_are_not_promoted_to_classical_dignity(
    point_id: str,
) -> None:
    result = evaluate_essential_dignity(point_id, 318.0, sect=Sect.DAY)
    assert result.applicable is False
    assert result.unavailable_reason == "POINT_OUTSIDE_TRADITIONAL_SEVEN"
    assert result.status_facts == ()
