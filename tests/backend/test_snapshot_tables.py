from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

from fastapi.testclient import TestClient
import pytest

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app
from interstellar_core.application.snapshot_tables import (
    SnapshotTableError,
    build_snapshot_table,
)


TABLE_IDS = (
    "table.chart_patterns",
    "table.essential_dignities",
    "table.receptions",
    "graph.dispositor_chain",
    "table.sect_condition",
    "table.arabic_parts",
)


def _table_ref() -> dict:
    return {
        "table_id": "traditional.rulerships.v1",
        "version": "1.0.0",
        "source_ids": ["source.traditional.v1"],
        "content_hash": "a" * 64,
    }


def _snapshot() -> dict:
    source_ids = ["source.traditional.v1"]
    rule_ids = ["rule.traditional.v1"]
    reception_document = {
        "receptions": [
            {
                "host_point_id": "mars",
                "guest_point_id": "sun",
                "dignity_kind": "domicile",
                "triplicity_role": None,
                "active_for_sect": None,
                "table_ref": _table_ref(),
                "rule_id": "rule.reception.v1",
            }
        ],
        "mutual_receptions": [
            {
                "point_a": "mars",
                "point_b": "venus",
                "a_receives_b_by": ["domicile"],
                "b_receives_a_by": ["term"],
                "rule_id": "rule.mutual_reception.v1",
            }
        ],
        "aspect_required": False,
        "algorithm_card_id": "ALG-NATAL-004",
        "rule_ids": rule_ids,
        "source_ids": source_ids,
        "excluded_capabilities": ["reception_interpretation"],
    }
    dispositor_document = {
        "edges": [
            {
                "subject_point_id": "sun",
                "subject_sign_id": "aries",
                "ruler_point_id": "mars",
                "table_ref": _table_ref(),
                "rule_id": "rule.dispositor.v1",
            }
        ],
        "cycles": [["mars", "venus"]],
        "final_dispositor_ids": ["mars"],
        "unresolved_ruler_ids": [],
        "algorithm_card_id": "ALG-NATAL-004",
        "rule_ids": rule_ids,
        "source_ids": source_ids,
    }
    sect_document = {
        "sect": "day",
        "sect_light_id": "sun",
        "diurnal_planet_ids": ["sun", "jupiter", "saturn"],
        "nocturnal_planet_ids": ["moon", "venus", "mars"],
        "conditional_planet_ids": ["mercury"],
        "algorithm_card_id": "ALG-NATAL-004",
        "rule_ids": rule_ids,
        "source_ids": source_ids,
        "excluded_capabilities": ["sect_interpretation"],
    }
    return {
        "id": "calculation-table-fixture",
        "input_fingerprint": f"sha256:{'b' * 64}",
        "engine": {"version": "0.1.0"},
        "result": {
            "points": [{"point_id": "fortune", "house": 2}],
            "patterns": [
                {
                    "stellium_id": "stellium.sign.aries",
                    "kind": "sign",
                    "participant_ids": ["sun", "mercury", "venus"],
                    "sign_index": 0,
                    "house": None,
                    "longitude_start_deg": None,
                    "longitude_span_deg": None,
                    "rule_ref": "rule.stellium.v1",
                },
                {
                    "pattern_id": "pattern.grand_trine.1",
                    "pattern_type": "grand_trine",
                    "participant_ids": ["sun", "moon", "jupiter"],
                    "roles": [
                        {
                            "role_id": "triangle",
                            "point_ids": ["sun", "moon", "jupiter"],
                        }
                    ],
                    "evidence_aspect_ids": ["aspect.1", "aspect.2", "aspect.3"],
                    "rule_ref": "rule.grand_trine.v1",
                },
            ],
            "dignities": [
                {
                    "point_id": "sun",
                    "longitude_deg": 10.0,
                    "sign_id": "aries",
                    "degree_in_sign": 10.0,
                    "sect": "day",
                    "applicable": True,
                    "unavailable_reason": None,
                    "dignities": [
                        {
                            "kind": "exaltation",
                            "ruler_id": "sun",
                            "sign_id": "aries",
                            "degree_in_sign": 10.0,
                            "role": None,
                            "is_active_for_sect": None,
                            "table_ref": _table_ref(),
                            "rule_id": "rule.exaltation.v1",
                        }
                    ],
                    "debilities": [],
                    "peregrine": False,
                    "algorithm_card_id": "ALG-NATAL-004",
                    "rule_ids": rule_ids,
                    "source_ids": source_ids,
                    "excluded_capabilities": ["dignity_interpretation"],
                }
            ],
            "receptions": [reception_document],
            "classical": {
                "availability": "available",
                "unavailable_reasons": [],
                "day_night_status": "day",
                "sun_altitude_deg": 31.25,
                "missing_traditional_planet_ids": [],
                "sect": sect_document,
                "dispositors": dispositor_document,
                "receptions": reception_document,
                "interpretation_boundary": "facts_only",
            },
            "lots": [
                {
                    "lot_id": "fortune",
                    "longitude_deg": 42.5,
                    "sign_id": "taurus",
                    "degree_in_sign": 12.5,
                    "sect": "day",
                    "formula_id": "lot.fortune.day.v1",
                    "formula_version": "1.0.0",
                    "formula_expression": "ASC + Moon - Sun",
                    "operands": [
                        {"point_id": "asc", "longitude_deg": 12.0, "coefficient": 1},
                        {"point_id": "moon", "longitude_deg": 50.0, "coefficient": 1},
                        {"point_id": "sun", "longitude_deg": 19.5, "coefficient": -1},
                    ],
                    "algorithm_card_id": "ALG-NATAL-005",
                    "rule_ids": ["rule.lot.fortune.v1"],
                    "source_ids": source_ids,
                    "excluded_capabilities": ["lot_interpretation"],
                }
            ],
        },
    }


def test_declared_professional_snapshot_tables_project_current_fact_shapes() -> None:
    snapshot = _snapshot()

    patterns = build_snapshot_table(snapshot, "table.chart_patterns")
    dignities = build_snapshot_table(snapshot, "table.essential_dignities")
    receptions = build_snapshot_table(snapshot, "table.receptions")
    dispositors = build_snapshot_table(snapshot, "graph.dispositor_chain")
    sect = build_snapshot_table(snapshot, "table.sect_condition")
    lots = build_snapshot_table(snapshot, "table.arabic_parts")

    assert [row["pattern_family"] for row in patterns.rows] == [
        "stellium",
        "geometric",
    ]
    assert json.loads(patterns.rows[1]["roles"])[0]["role_id"] == "triangle"
    assert json.loads(dignities.rows[0]["dignities"])[0]["kind"] == "exaltation"
    assert [row["reception_type"] for row in receptions.rows] == [
        "directed",
        "mutual",
    ]
    assert json.loads(receptions.rows[0]["table_ref"])["version"] == "1.0.0"
    assert dispositors.rows[0]["ruler_point_id"] == "mars"
    assert json.loads(dispositors.rows[0]["cycles"]) == [["mars", "venus"]]
    assert sect.rows[0]["sect_light_id"] == "sun"
    assert sect.rows[0]["conditional_planet_ids"] == "mercury"
    assert lots.rows[0]["house"] == 2
    assert json.loads(lots.rows[0]["operands"])[2]["coefficient"] == -1


def test_declared_tables_are_reachable_over_http_as_json_and_csv() -> None:
    app = create_app(ApiSettings(environment="test"))
    app.state.workflow_store.put_snapshot(_snapshot())

    with TestClient(app) as client:
        for table_id in TABLE_IDS:
            json_response = client.get(
                f"/api/v1/calculations/calculation-table-fixture/tables/{table_id}"
            )
            csv_response = client.get(
                f"/api/v1/calculations/calculation-table-fixture/tables/{table_id}",
                params={"format": "csv"},
            )

            assert json_response.status_code == 200, json_response.text
            assert json_response.json()["table_id"] == table_id
            assert csv_response.status_code == 200, csv_response.text
            assert csv_response.headers["content-type"].startswith("text/csv")
            assert csv_response.text.startswith(
                "snapshot_id,input_fingerprint,engine_version,"
            )


def test_legitimate_empty_professional_tables_return_headers_not_409() -> None:
    snapshot = deepcopy(_snapshot())
    snapshot["result"]["patterns"] = []
    snapshot["result"]["dignities"] = []
    snapshot["result"]["receptions"] = []
    snapshot["result"]["lots"] = []
    snapshot["result"]["classical"].update(
        {
            "availability": "indeterminate",
            "unavailable_reasons": ["DAY_NIGHT_STATUS_INDETERMINATE"],
            "day_night_status": "indeterminate",
            "sect": None,
            "dispositors": None,
            "receptions": None,
        }
    )

    for table_id in TABLE_IDS:
        table = build_snapshot_table(snapshot, table_id)
        if table_id == "table.sect_condition":
            assert len(table.rows) == 1
            assert table.rows[0]["availability"] == "indeterminate"
        else:
            assert table.rows == ()
        assert table.to_csv().count("\n") == 1 + len(table.rows)

    with pytest.raises(SnapshotTableError, match="table has no generated rows"):
        build_snapshot_table(snapshot, "table.house_cusps")


def test_professional_natal_snapshot_reaches_every_declared_specialized_table() -> None:
    ephemeris_path = Path(__file__).resolve().parents[2] / "vendor" / "swisseph" / "ephe"
    app = create_app(
        ApiSettings(
            environment="test",
            swiss_ephemeris_path=str(ephemeris_path),
        )
    )
    birth = {
        "workspace_id": "workspace-table-integration",
        "version": {
            "kind": "person",
            "display_name": "Professional Table Subject",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": "2000-01-01T20:00",
                "precision": "minute",
                "timezone_id": "Asia/Shanghai",
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high",
                "source": {"kind": "test_fixture"},
                "warnings": [],
            },
            "location": {
                "name": "Shanghai",
                "country_code": "CN",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "timezone_id": "Asia/Shanghai",
                "source": "test_fixture",
                "warnings": [],
            },
            "attributes": {},
            "source": {"kind": "test_fixture"},
        },
    }

    with TestClient(app) as client:
        saved = client.post("/api/v1/subjects", json=birth)
        assert saved.status_code == 201, saved.text
        payload = {
            "subject": {"subject_version_id": saved.json()["version"]["id"]},
            "chart": {"family": "natal", "technique": "natal.standard_chart"},
            "settings": {
                "calculation_profile_id": "professional.natal.v1",
                "zodiac": "tropical",
                "house_system": "placidus",
                "center": "geocentric",
                "coordinate_frame": "ecliptic",
                "node_type": "true",
                "aspect_set_id": "official.aspects.professional_natal.v1",
                "orb_profile_id": "official.orbs.professional_natal.v1",
                "included_points": [],
                "custom_parameters": {},
            },
            "rule_pack_hash": f"sha256:{'c' * 64}",
            "dataset_versions": {},
            "outputs": ["snapshot", "json"],
        }
        calculation = client.post("/api/v1/calculations", json=payload)
        assert calculation.status_code == 201, calculation.text
        snapshot = calculation.json()
        declared = {
            table_id
            for manifest in snapshot["result"]["output_manifest"]
            for table_id in manifest["table_ids"]
        }
        assert set(TABLE_IDS) <= declared

        tables = {
            table_id: client.get(
                f"/api/v1/calculations/{snapshot['id']}/tables/{table_id}"
            )
            for table_id in TABLE_IDS
        }

    assert all(response.status_code == 200 for response in tables.values())
    assert len(tables["table.essential_dignities"].json()["rows"]) == 7
    assert len(tables["graph.dispositor_chain"].json()["rows"]) == 7
    assert len(tables["table.sect_condition"].json()["rows"]) == 1
    assert {row["lot_id"] for row in tables["table.arabic_parts"].json()["rows"]} == {
        "fortune",
        "spirit",
        "lot_basis",
        "lot_exaltation",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
    }
