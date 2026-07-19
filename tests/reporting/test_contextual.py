from __future__ import annotations

from copy import deepcopy

import pytest
from interstellar_core.reporting import (
    ContextualInterpretationInputError,
    ContextualItemKind,
    InterpretationLocale,
    InterpretationRequest,
    interpret_snapshot_item,
)


def _point(
    point_id: str,
    *,
    sign: str,
    house: int | None,
    motion: str = "direct",
    motion_interpretation: str = "meaningful",
) -> dict:
    return {
        "point_id": point_id,
        "kind": "planet",
        "position": {
            "ecliptic": {"longitude_deg": 341.25, "latitude_deg": 0.0},
            "motion_state": motion,
        },
        "sign": sign,
        "degree_in_sign": 11.25,
        "house": house,
        "retrograde": motion == "retrograde",
        "motion_interpretation": motion_interpretation,
    }


def snapshot_fixture() -> dict:
    sun = _point(
        "sun",
        sign="pisces",
        house=7,
        motion_interpretation="not_applicable",
    )
    moon = _point(
        "moon",
        sign="capricorn",
        house=5,
        motion_interpretation="not_applicable",
    )
    mercury = _point(
        "mercury",
        sign="pisces",
        house=7,
        motion="retrograde",
    )
    return {
        "id": "snapshot-contextual-1",
        "result": {
            "points": [sun, moon, mercury],
            "aspects": [
                {
                    "aspect_id": "aspect-sun-moon-square",
                    "point_a": "sun",
                    "point_b": "moon",
                    "context": "within_chart",
                    "type": "square",
                    "exact_angle_deg": 90.0,
                    "actual_angle_deg": 91.0,
                    "orb_deg": 1.0,
                    "orb_ratio": 0.875,
                    "applying_state": "applying",
                    "direction": "sinister",
                    "strength": 0.875,
                }
            ],
            "houses": [
                {
                    "number": 7,
                    "cusp_longitude_deg": 330.0,
                    "sign": "pisces",
                    "degree_in_sign": 0.0,
                    "traditional_ruler_ids": ["jupiter"],
                    "modern_ruler_ids": ["neptune"],
                    "intercepted_signs": [],
                    "repeated_cusp_sign": False,
                }
            ],
            "structure": {
                "geometric_patterns": {
                    "facts": [
                        {
                            "pattern_id": "pattern-t-square-1",
                            "pattern_type": "t_square",
                            "participant_ids": ["sun", "moon", "mercury"],
                            "roles": [],
                            "evidence_aspect_ids": ["a", "b", "c"],
                            "rule_ref": "ALG-NATAL-003:pattern.geometry.v1",
                        }
                    ]
                }
            },
            "dignities": [
                {
                    "point_id": "jupiter",
                    "longitude_deg": 100.0,
                    "sign_id": "cancer",
                    "degree_in_sign": 10.0,
                    "sect": "day",
                    "applicable": True,
                    "unavailable_reason": None,
                    "dignities": [
                        {
                            "kind": "exaltation",
                            "ruler_id": "jupiter",
                            "sign_id": "cancer",
                            "degree_in_sign": 10.0,
                            "role": None,
                            "is_active_for_sect": None,
                            "table_ref": {
                                "table_id": "classical.exaltations.v1",
                                "version": "1.0.0",
                                "source_ids": ["SRC-CLASSICAL-PTOLEMY-001"],
                                "content_hash": "a" * 64,
                            },
                            "rule_id": "classical.exaltation.v1",
                        }
                    ],
                    "debilities": [],
                    "peregrine": False,
                    "algorithm_card_id": "ALG-NATAL-004",
                    "rule_ids": ["classical.exaltation.v1"],
                    "source_ids": ["SRC-CLASSICAL-PTOLEMY-001"],
                    "excluded_capabilities": [],
                }
            ],
        },
    }


def _interpret(kind: ContextualItemKind, path: str, *, snapshot: dict | None = None):
    return interpret_snapshot_item(
        snapshot or snapshot_fixture(),
        InterpretationRequest(item_kind=kind, result_path=path),
    )


def test_point_intrinsic_is_deterministic_and_fully_versioned() -> None:
    first = _interpret(ContextualItemKind.POINT_INTRINSIC, "/result/points/0")
    second = _interpret(ContextualItemKind.POINT_INTRINSIC, "/result/points/0")

    assert first == second
    document = first.to_dict()
    assert document["status"] == "published"
    assert document["meaning"]["statement_key"] == "point.intrinsic.sun"
    assert document["fact"]["point_id"] == "sun"
    assert document["content_hash"].startswith("sha256:")
    assert document["provenance"]["algorithm_card"]["id"] == "ALG-REPORT-003"
    assert document["provenance"]["rule"]["version"] == "1.0.0"
    assert document["provenance"]["template"]["status"] == "available"
    assert document["provenance"]["maturity"] == "experimental"
    assert document["provenance"]["ai_used"] is False
    assert all(source["version"] for source in document["provenance"]["sources"])


@pytest.mark.parametrize(
    ("kind", "path", "expected_key"),
    [
        (ContextualItemKind.POINT_IN_SIGN, "/result/points/0", "point.in_sign"),
        (ContextualItemKind.POINT_IN_HOUSE, "/result/points/0", "point.in_house"),
        (ContextualItemKind.MOTION, "/result/points/2", "motion.retrograde"),
        (ContextualItemKind.NATAL_ASPECT, "/result/aspects/0", "aspect.square"),
        (
            ContextualItemKind.HOUSE_CUSP_RULER,
            "/result/houses/0",
            "house.cusp_ruler",
        ),
        (
            ContextualItemKind.STRUCTURE_INDICATOR,
            "/result/structure/geometric_patterns/facts/0",
            "structure.t_square",
        ),
        (
            ContextualItemKind.CLASSICAL_CONDITION,
            "/result/dignities/0",
            "classical.essential_condition",
        ),
    ],
)
def test_all_required_item_kinds_publish_structured_meanings(
    kind: ContextualItemKind,
    path: str,
    expected_key: str,
) -> None:
    result = _interpret(kind, path).to_dict()

    assert result["status"] == "published"
    assert result["meaning"]["statement_key"] == expected_key
    assert result["meaning"]["text"]
    assert result["provenance"]["sources"]
    assert result["provenance"]["template"]["content_hash"].startswith("sha256:")


def test_motion_not_applicable_never_invents_sun_retrograde_meaning() -> None:
    result = _interpret(ContextualItemKind.MOTION, "/result/points/0").to_dict()

    assert result["status"] == "not_applicable"
    assert result["meaning"] is None
    assert result["unavailable_reason"] == "MOTION_INTERPRETATION_NOT_APPLICABLE"
    assert result["provenance"]["template"]["status"] == "unavailable"


def test_classical_condition_preserves_snapshot_declared_sources() -> None:
    result = _interpret(
        ContextualItemKind.CLASSICAL_CONDITION,
        "/result/dignities/0",
    ).to_dict()

    source_ids = {source["source_id"] for source in result["provenance"]["sources"]}
    assert "SRC-CLASSICAL-PTOLEMY-001" in source_ids


def test_missing_house_blocks_only_house_layer_and_preserves_fact() -> None:
    snapshot = snapshot_fixture()
    snapshot["result"]["points"][0]["house"] = None

    result = _interpret(
        ContextualItemKind.POINT_IN_HOUSE,
        "/result/points/0",
        snapshot=snapshot,
    ).to_dict()

    assert result["status"] == "blocked_by_input_quality"
    assert result["fact"]["point_id"] == "sun"
    assert result["unavailable_reason"] == "MISSING_HOUSE_ASSIGNMENT"


def test_missing_rule_is_explicit_unavailable_without_generic_fallback() -> None:
    snapshot = snapshot_fixture()
    snapshot["result"]["points"].append(
        _point("invented_point", sign="pisces", house=7)
    )

    result = _interpret(
        ContextualItemKind.POINT_INTRINSIC,
        "/result/points/3",
        snapshot=snapshot,
    ).to_dict()

    assert result["status"] == "unavailable"
    assert result["meaning"] is None
    assert result["unavailable_reason"] == "POINT_INTRINSIC_RULE_UNAVAILABLE"
    assert result["provenance"]["generation_mode"] == "deterministic_rule_template"


def test_unpublished_locale_is_explicit_unavailable() -> None:
    result = interpret_snapshot_item(
        snapshot_fixture(),
        InterpretationRequest(
            item_kind=ContextualItemKind.POINT_INTRINSIC,
            result_path="/result/points/0",
            locale=InterpretationLocale.EN_US,
        ),
    ).to_dict()

    assert result["status"] == "unavailable"
    assert result["unavailable_reason"] == "TEMPLATE_LOCALE_UNAVAILABLE"


@pytest.mark.parametrize(
    "path",
    ["/request/settings", "/result/points/999", "/result/points/not-an-index"],
)
def test_invalid_or_out_of_scope_pointer_is_rejected(path: str) -> None:
    with pytest.raises(ContextualInterpretationInputError):
        _interpret(ContextualItemKind.POINT_INTRINSIC, path)


def test_semantic_fact_change_produces_new_interpretation_identity() -> None:
    first_snapshot = snapshot_fixture()
    second_snapshot = deepcopy(first_snapshot)
    second_snapshot["result"]["points"][0]["sign"] = "aries"

    first = _interpret(
        ContextualItemKind.POINT_IN_SIGN,
        "/result/points/0",
        snapshot=first_snapshot,
    )
    second = _interpret(
        ContextualItemKind.POINT_IN_SIGN,
        "/result/points/0",
        snapshot=second_snapshot,
    )

    assert first.interpretation_id != second.interpretation_id
    assert first.content_hash != second.content_hash
