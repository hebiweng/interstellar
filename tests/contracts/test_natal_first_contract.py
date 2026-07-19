from __future__ import annotations

import json
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = ROOT / "packages" / "canonical-schema"
SPEC = yaml.safe_load(
    (ROOT / "tests" / "contracts" / "specs" / "natal-first-slice.yaml").read_text(
        encoding="utf-8"
    )
)


def _schema(name: str) -> dict[str, object]:
    return json.loads((SCHEMAS / name).read_text(encoding="utf-8"))


def test_natal_settings_are_typed_not_hidden_in_custom_parameters() -> None:
    chart_request = _schema("chart-request.schema.json")
    properties = chart_request["$defs"]["ChartSettings"]["properties"]
    assert set(SPEC["chart_settings_required_properties"]) <= set(properties)


def test_professional_point_house_and_aspect_fields_are_declared() -> None:
    chart_result = _schema("chart-result.schema.json")
    definitions = chart_result["$defs"]
    assert set(SPEC["point_required_or_declared_properties"]) <= set(
        definitions["Point"]["properties"]
    )
    assert set(SPEC["house_required_or_declared_properties"]) <= set(
        definitions["House"]["properties"]
    )
    assert set(SPEC["aspect_required_properties"]) == set(
        definitions["Aspect"]["required"]
    )


def test_technical_export_formats_are_public_contract_values() -> None:
    chart_request = _schema("chart-request.schema.json")
    manifest = _schema("output-manifest.schema.json")
    request_formats = set(chart_request["properties"]["outputs"]["items"]["enum"])
    manifest_formats = set(manifest["properties"]["export_formats"]["items"]["enum"])
    expected = set(SPEC["required_technical_exports"])
    assert expected <= request_formats
    assert expected <= manifest_formats


def test_motion_contract_supports_not_applicable_semantics() -> None:
    chart_result = _schema("chart-result.schema.json")
    position_states = set(
        chart_result["$defs"]["CelestialPosition"]["properties"]["motion_state"]["enum"]
    )
    interpretation_states = set(
        chart_result["$defs"]["Point"]["properties"]["motion_interpretation"]["enum"]
    )
    assert "not_applicable" in position_states
    assert "not_applicable" in interpretation_states


def test_classical_dignity_statuses_are_typed_and_source_traceable() -> None:
    chart_result = _schema("chart-result.schema.json")
    definitions = chart_result["$defs"]
    result = definitions["EssentialDignityResult"]
    status = definitions["EssentialStatusFact"]

    assert {
        "profile_id",
        "applicable",
        "unavailable_reason",
        "dignities",
        "debilities",
        "peregrine",
        "status_facts",
    } <= set(result["required"])
    assert {
        "status_id",
        "polarity",
        "level",
        "active",
        "label_key",
        "table_ref",
        "rule_id",
    } <= set(status["required"])
    assert "peregrine" in status["properties"]["status_id"]["enum"]
