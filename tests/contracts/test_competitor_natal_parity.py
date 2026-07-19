from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python"))

SCHEMAS = ROOT / "packages" / "canonical-schema"
SPEC = yaml.safe_load(
    (
        ROOT
        / "tests"
        / "contracts"
        / "specs"
        / "competitor-natal-parity.yaml"
    ).read_text(encoding="utf-8")
)


def _schema(name: str) -> dict:
    return json.loads((SCHEMAS / name).read_text(encoding="utf-8"))


def _current_materialized_professional_ids() -> set[str]:
    from interstellar_core.application.astronomical_snapshot import (
        CURRENTLY_DERIVABLE_POINT_IDS,
    )
    from interstellar_core.astrology.natal import PROFESSIONAL_POINT_IDS
    from interstellar_core.astronomy.adapters import DIRECT_POINT_REGISTRY

    executable = set(DIRECT_POINT_REGISTRY) | set(CURRENTLY_DERIVABLE_POINT_IDS)
    return set(PROFESSIONAL_POINT_IDS) & executable


def test_source_inventory_counts_and_labels_are_accounted_for() -> None:
    observed = SPEC["observed_inventory"]
    points = SPEC["point_inventory"]
    signs = SPEC["sign_index"]

    assert observed == {
        "point_rows": 66,
        "house_rows": 12,
        "aspect_rows": 262,
        "aspect_type_count": 10,
        "sign_index_rows": 12,
    }
    assert [point["ordinal"] for point in points] == list(range(1, 67))
    assert len({point["source_label"] for point in points}) == 66
    assert [sign["index"] for sign in signs] == list(range(1, 13))
    assert len({sign["interstellar_id"] for sign in signs}) == 12
    assert len(SPEC["source"]["sha256"]) == 64


def test_point_gap_matrix_matches_the_current_professional_runtime() -> None:
    from interstellar_core.astrology.natal import PROFESSIONAL_POINT_IDS

    points = SPEC["point_inventory"]
    profile = SPEC["interstellar_professional_profile"]
    materialized = _current_materialized_professional_ids()
    status_counts = Counter(point["coverage_status"] for point in points)
    covered_rows = status_counts["covered"] + status_counts["covered_parameterized"]

    assert len(materialized) == profile["materialized_point_count"] == 47
    assert covered_rows == profile["source_rows_covered"] == 41
    assert (
        status_counts["declared_not_materialized"]
        == profile["source_rows_declared_not_materialized"]
        == 0
    )
    assert (
        status_counts["research_blocked"]
        == profile["source_rows_research_blocked"]
        == 25
    )

    for point in points:
        point_ids = set(point["interstellar_ids"])
        if point["coverage_status"] in {"covered", "covered_parameterized"}:
            assert point_ids
            assert point_ids <= materialized
        elif point["coverage_status"] == "declared_not_materialized":
            assert point_ids <= set(PROFESSIONAL_POINT_IDS)
            assert point_ids.isdisjoint(materialized)
            assert point["independent_source_required"] is True
            assert point["gap_reason"]
        else:
            assert point["coverage_status"] == "research_blocked"
            assert not point_ids
            assert point["independent_source_required"] is True
            assert point["gap_reason"]


def test_competitor_aspect_geometries_are_covered_but_row_count_is_not_a_gate() -> None:
    from interstellar_core.astrology.aspects import (
        OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1,
    )

    observation = SPEC["aspect_observation"]
    policy = SPEC["parity_policy"]
    source_types = observation["types"]
    interstellar_angles = {
        aspect.id: aspect.exact_angle_deg
        for aspect in OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1.aspects
    }

    assert len(source_types) == SPEC["observed_inventory"]["aspect_type_count"]
    assert sum(item["observed_rows"] for item in source_types) == 262
    assert {item["interstellar_id"] for item in source_types} <= set(
        interstellar_angles
    )
    for item in source_types:
        assert interstellar_angles[item["interstellar_id"]] == pytest.approx(
            item["angle_deg"]
        )

    assert policy["aspect_count_is_release_floor"] is False
    assert len(policy["aspect_count_rationale"]) >= 3
    assert {
        "exact_and_actual_angles",
        "orb_and_orb_ratio",
        "applying_state_and_direction",
        "versioned_aspect_and_orb_profiles",
        "rule_references_and_reproducibility",
    } <= set(policy["aspect_quality_gates"])


def test_schema_field_dimensions_are_not_narrower_than_the_source_export() -> None:
    request = _schema("chart-request.schema.json")
    result = _schema("chart-result.schema.json")
    time_spec = _schema("time-spec.schema.json")
    location = _schema("location.schema.json")
    assertions = SPEC["schema_assertions"]
    actual_properties = {
        "chart_definition": request["$defs"]["ChartDefinition"]["properties"],
        "chart_settings": request["$defs"]["ChartSettings"]["properties"],
        "time_spec": time_spec["properties"],
        "location": location["properties"],
        "point": result["$defs"]["Point"]["properties"],
        "house": result["$defs"]["House"]["properties"],
        "aspect": result["$defs"]["Aspect"]["properties"],
        "astronomical_context": result["$defs"]["AstronomicalContext"][
            "properties"
        ],
    }

    for dimension, required_fields in assertions.items():
        assert set(required_fields) <= set(actual_properties[dimension])

    houses = result["$defs"]["HouseSet"]["properties"]["houses"]
    assert houses["minItems"] == houses["maxItems"] == 12
    assert set(SPEC["house_contract"]["source_fields"]) <= set(
        result["$defs"]["House"]["properties"]
    )
    assert set(SPEC["aspect_observation"]["source_fields"]) <= set(
        result["$defs"]["Aspect"]["properties"]
    )


def test_release_gate_cannot_claim_ready_while_parity_gaps_remain() -> None:
    gate = SPEC["gap_gate"]
    counts = gate["blocking_counts"]
    point_statuses = Counter(
        point["coverage_status"] for point in SPEC["point_inventory"]
    )
    setting_statuses = Counter(
        item["status"] for item in SPEC["source_input_and_settings"]
    )
    context_statuses = Counter(
        item["status"] for item in SPEC["source_astronomical_context"]
    )

    assert counts["declared_not_materialized_points"] == point_statuses[
        "declared_not_materialized"
    ]
    assert counts["research_blocked_points"] == point_statuses["research_blocked"]
    assert counts["runtime_null_astronomical_fields"] == context_statuses[
        "schema_declared_runtime_null"
    ]
    assert counts["generic_or_out_of_scope_setting_fields"] == sum(
        count for status, count in setting_statuses.items() if status != "covered"
    )
    assert sum(counts.values()) > 0
    assert gate["status"] == SPEC["parity_policy"]["release_status"] == "blocked"
    assert (
        SPEC["parity_policy"]["current_executable_source_point_rows"]
        < SPEC["parity_policy"]["target_executable_source_point_rows"]
    )
