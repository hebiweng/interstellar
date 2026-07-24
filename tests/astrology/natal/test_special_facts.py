from __future__ import annotations

import math

import pytest

from interstellar_core.astrology.natal import (
    DEFAULT_MIRROR_PROFILE,
    DEFAULT_SPECIAL_DEGREE_PROFILE,
    RULE_ANTISCIA_V1,
    RULE_CONTRA_ANTISCIA_V1,
    RULE_DECAN_INDEX_V1,
    RULE_TERMINAL_29_V1,
    RULE_VIA_COMBUSTA_V1,
    MirrorContactType,
    RuleEvaluationStatus,
    calculate_mirror_points,
    calculate_natal_special_facts,
    calculate_special_degrees,
    mirror_profile,
)
from interstellar_core.domain import DomainError


def point(point_id: str, longitude_deg: float) -> dict:
    return {
        "point_id": point_id,
        "position": {"ecliptic": {"longitude_deg": longitude_deg}},
    }


def test_default_degree_profile_and_every_published_rule_are_versioned_and_hashed() -> None:
    profile = DEFAULT_SPECIAL_DEGREE_PROFILE
    assert profile.profile_id == "natal.special_degrees.lilly_equal_decans.v1"
    assert profile.version == "1.0.0"
    assert profile.zodiac == "tropical"
    assert profile.via_combusta_start_longitude_deg == 195
    assert profile.via_combusta_end_longitude_deg == 225
    assert profile.critical_degree_table_id is None
    assert len(profile.content_hash) == 64

    for rule in (
        RULE_DECAN_INDEX_V1,
        RULE_VIA_COMBUSTA_V1,
        RULE_TERMINAL_29_V1,
        RULE_ANTISCIA_V1,
        RULE_CONTRA_ANTISCIA_V1,
    ):
        assert rule.rule_id.endswith(".v1")
        assert rule.version == "1.0.0"
        assert rule.source_ids
        assert rule.definition
        assert len(rule.content_hash) == 64


@pytest.mark.parametrize(
    ("longitude", "expected"),
    [
        (194.999999, False),
        (195.0, True),
        (224.999999, True),
        (225.0, False),
    ],
)
def test_via_combusta_uses_documented_half_open_libra15_scorpio15_boundaries(
    longitude: float,
    expected: bool,
) -> None:
    result = calculate_special_degrees((point("moon", longitude),))
    assert result.points[0].in_via_combusta is expected


@pytest.mark.parametrize(
    ("longitude", "decan", "start", "end", "terminal"),
    [
        (0.0, 1, 0.0, 10.0, False),
        (9.999999, 1, 0.0, 10.0, False),
        (10.0, 2, 10.0, 20.0, False),
        (19.999999, 2, 10.0, 20.0, False),
        (20.0, 3, 20.0, 30.0, False),
        (28.999999, 3, 20.0, 30.0, False),
        (29.0, 3, 20.0, 30.0, True),
        (29.999999, 3, 20.0, 30.0, True),
        (359.999999, 3, 20.0, 30.0, True),
    ],
)
def test_decan_and_terminal_degree_are_sign_relative_interval_facts(
    longitude: float,
    decan: int,
    start: float,
    end: float,
    terminal: bool,
) -> None:
    fact = calculate_special_degrees((point("p", longitude),)).points[0]
    assert fact.decan_index == decan
    assert fact.decan_start_deg == start
    assert fact.decan_end_deg == end
    assert fact.in_terminal_degree_29 is terminal


def test_critical_degrees_are_explicitly_not_evaluated_instead_of_guessed() -> None:
    result = calculate_special_degrees((point("sun", 13.0), point("moon", 29.0)))

    critical = result.critical_degrees
    assert critical.status is RuleEvaluationStatus.NOT_EVALUATED
    assert critical.table_id is None
    assert critical.reason_code == "NO_VERSIONED_CRITICAL_DEGREE_TABLE_SELECTED"
    assert critical.rule_ids == ()
    assert critical.source_ids == ()
    assert all(item.critical_degree_match is None for item in result.points)
    assert "critical_degree_table" in result.provenance.excluded_capabilities


def test_special_degree_result_is_deterministic_and_carries_full_provenance() -> None:
    result = calculate_special_degrees((point("venus", 225), point("sun", 195)))
    payload = result.to_dict()

    assert [item["point_id"] for item in payload["points"]] == ["sun", "venus"]
    provenance = payload["provenance"]
    assert provenance["capability_id"] == "natal.special_degrees.v1"
    assert provenance["profile_content_hash"] == DEFAULT_SPECIAL_DEGREE_PROFILE.content_hash
    assert provenance["evaluated_point_count"] == 2
    assert len(provenance["rules"]) == 3
    assert all(len(rule["content_hash"]) == 64 for rule in provenance["rules"])
    assert "meaning" not in provenance["interpretation_boundary"].lower()


def test_mirror_formulas_return_known_antiscia_and_contra_antiscia_longitudes() -> None:
    result = calculate_mirror_points(
        (point("aries_10", 10), point("cancer_10", 100), point("capricorn_10", 280))
    )
    by_id = {item.point_id: item for item in result.mirror_points}

    assert by_id["aries_10"].antiscia_longitude_deg == 170
    assert by_id["aries_10"].antiscia_sign_id == "virgo"
    assert by_id["aries_10"].antiscia_degree_in_sign == 20
    assert by_id["aries_10"].contra_antiscia_longitude_deg == 350
    assert by_id["aries_10"].contra_antiscia_sign_id == "pisces"
    assert by_id["aries_10"].contra_antiscia_degree_in_sign == 20
    assert by_id["cancer_10"].antiscia_longitude_deg == 80
    assert by_id["capricorn_10"].antiscia_longitude_deg == 260


def test_mirror_contacts_are_pairwise_with_explicit_error_orb_and_rule() -> None:
    result = calculate_mirror_points(
        (
            point("a", 10.0),
            point("antiscia_exact", 170.0),
            point("contra_near", 350.5),
            point("outside", 172.0),
        ),
        profile=mirror_profile(contact_orb_deg=1.0),
    )
    by_key = {(item.contact_type, item.point_a, item.point_b): item for item in result.contacts}

    antiscia = by_key[(MirrorContactType.ANTISCIA, "a", "antiscia_exact")]
    assert antiscia.separation_from_exact_deg == 0
    assert antiscia.orb_fraction_remaining == 1
    assert antiscia.rule_id == RULE_ANTISCIA_V1.rule_id
    contra = by_key[(MirrorContactType.CONTRA_ANTISCIA, "a", "contra_near")]
    assert contra.separation_from_exact_deg == 0.5
    assert contra.orb_fraction_remaining == 0.5
    assert contra.rule_id == RULE_CONTRA_ANTISCIA_V1.rule_id
    assert not any(
        {item.point_a, item.point_b} == {"a", "outside"}
        for item in result.contacts
    )
    assert result.provenance.evaluated_pair_count == 6
    assert result.provenance.matched_contact_count == len(result.contacts)


def test_mirror_orb_is_inclusive_versioned_and_changes_profile_hash() -> None:
    one_degree = mirror_profile(contact_orb_deg=1)
    half_degree = mirror_profile(contact_orb_deg=0.5)
    points = (point("a", 10), point("b", 170.5))

    assert one_degree.content_hash != half_degree.content_hash
    contact = calculate_mirror_points(points, profile=half_degree).contacts[0]
    assert contact.contact_type is MirrorContactType.ANTISCIA
    assert math.isclose(contact.separation_from_exact_deg, 0.5)
    assert contact.orb_fraction_remaining == 0


def test_combined_report_interface_is_json_safe_and_preserves_both_rule_sets() -> None:
    report = calculate_natal_special_facts((point("sun", 195), point("moon", 345)))
    payload = report.to_dict()

    assert payload["special_degrees"]["points"][0]["in_via_combusta"] is False
    assert payload["special_degrees"]["points"][1]["in_via_combusta"] is True
    contacts = payload["mirrors"]["contacts"]
    assert contacts[0]["contact_type"] == "antiscia"
    assert payload["mirrors"]["provenance"]["capability_id"] == "aspect.mirror.v1"
    assert len(payload["mirrors"]["provenance"]["profile_content_hash"]) == 64
    assert len(DEFAULT_MIRROR_PROFILE.content_hash) == 64


@pytest.mark.parametrize(
    "bad_point",
    [
        {"point_id": "sun"},
        point("sun", -0.01),
        point("sun", 360),
        point("sun", float("nan")),
    ],
)
def test_invalid_canonical_points_are_rejected_not_wrapped(bad_point: dict) -> None:
    with pytest.raises(DomainError, match="longitude|requires"):
        calculate_special_degrees((bad_point,))


def test_duplicate_point_ids_and_invalid_orbs_are_rejected() -> None:
    with pytest.raises(DomainError, match="more than once"):
        calculate_mirror_points((point("sun", 10), point("sun", 20)))
    with pytest.raises(ValueError, match="orb"):
        mirror_profile(contact_orb_deg=-0.1)
    with pytest.raises(ValueError, match="orb"):
        mirror_profile(contact_orb_deg=30)
