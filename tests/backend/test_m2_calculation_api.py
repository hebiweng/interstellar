from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient
import pytest

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app
from interstellar_api.workflow_store import WorkflowRecordConflict, WorkflowStore


def _client() -> TestClient:
    return TestClient(create_app(ApiSettings(environment="test")))


def _professional_client() -> TestClient:
    ephemeris_path = (
        Path(__file__).resolve().parents[2] / "vendor" / "swisseph" / "ephe"
    )
    return TestClient(
        create_app(
            ApiSettings(
                environment="test",
                swiss_ephemeris_path=str(ephemeris_path),
            )
        )
    )


def _birth_payload(
    *, precision: str = "minute", local_value: str = "2000-01-01T20:00"
) -> dict:
    return {
        "workspace_id": "workspace-m2",
        "version": {
            "kind": "person",
            "display_name": "M2 Virtual Subject",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": local_value,
                "precision": precision,
                "timezone_id": "Asia/Shanghai" if precision != "date" else None,
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high" if precision != "date" else "unknown",
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


def _calculation_payload(version_id: str) -> dict:
    return {
        "subject": {"subject_version_id": version_id},
        "chart": {"family": "natal", "technique": "natal.standard_chart"},
        "settings": {
            "zodiac": "tropical",
            "house_system": "placidus",
            "center": "geocentric",
            "coordinate_frame": "ecliptic",
            "node_type": "true",
            "aspect_set_id": "official.aspects.major.v1",
            "orb_profile_id": "official.orbs.standard.v1",
            "included_points": [],
            "custom_parameters": {},
        },
        "rule_pack_hash": f"sha256:{'a' * 64}",
        "dataset_versions": {},
        "outputs": ["snapshot", "json"],
    }


def _current_sky_payload(version_id: str) -> dict:
    payload = _calculation_payload(version_id)
    payload["chart"] = {"family": "mundane", "technique": "mundane.current_sky"}
    return payload


def _sky_event_payload() -> dict:
    payload = _birth_payload()
    payload["version"]["kind"] = "event"
    payload["version"]["display_name"] = "Current sky reference moment"
    return payload


def test_selected_utc_to_reproducible_m3_natal_fact_snapshot() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        response = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        )

        assert response.status_code == 201, response.text
        snapshot = response.json()
        assert snapshot["status"] == "succeeded"
        assert snapshot["maturity"] == "experimental"
        assert snapshot["engine"]["version"] == "0.1.0"
        assert snapshot["adapters"][0]["name"] == "pysweph"
        assert snapshot["adapters"][0]["version"] == "2.10.3.6"
        assert snapshot["input_fingerprint"].startswith("sha256:")

        points = snapshot["result"]["points"]
        assert [point["point_id"] for point in points] == [
            "sun",
            "moon",
            "mercury",
            "venus",
            "mars",
            "jupiter",
            "saturn",
            "uranus",
            "neptune",
            "pluto",
        ]
        assert all(1 <= point["house"] <= 12 for point in points)
        assert all(point["distance_to_next_cusp_deg"] >= 0 for point in points)
        assert all(point["position"]["epoch"].startswith("JDUT:") for point in points)
        context = snapshot["result"]["astronomical_context"]
        assert context["julian_day_ut"] == 2451545.0
        assert context["julian_day_tt"] > context["julian_day_ut"]
        assert context["delta_t_seconds"] > 0
        assert 0 <= context["lunar_phase"]["illumination_fraction"] <= 1

        manifests = {
            item["calculation_id"]: item
            for item in snapshot["result"]["output_manifest"]
        }
        assert manifests["astronomy.ephemeris_core"]["status"] == "generated"
        assert manifests["astronomy.houses_angles"]["status"] == "generated"
        assert manifests["astronomy.aspects"]["status"] == "generated"
        assert manifests["natal.patterns_distributions"]["status"] == "generated"
        assert manifests["natal.standard_chart"]["status"] == "generated"
        assert len(snapshot["result"]["houses"]) == 12
        assert snapshot["result"]["aspects"]
        assert len(snapshot["result"]["distributions"]) == 3
        assert {warning["code"] for warning in snapshot["warnings"]} <= {
            "EPHEMERIS_FALLBACK_MOSHIER",
            "SWISS_EPHEMERIS_MESSAGE",
        }

        chart = snapshot["result"]["charts"][0]
        assert chart["house_set"]["system"] == "placidus"
        assert set(chart["house_set"]["angles"]) == {"asc", "dsc", "mc", "ic"}
        assigned_ids = {
            point_id
            for house in chart["house_set"]["houses"]
            for point_id in house["point_ids"]
        }
        assert assigned_ids == {point["point_id"] for point in points}
        assert all(
            0 <= aspect["actual_angle_deg"] <= 180 for aspect in chart["aspects"]
        )
        assert all(0 <= aspect["strength"] <= 1 for aspect in chart["aspects"])
        for distribution in chart["distributions"]:
            assert distribution["availability"] == "available"
            assert sum(
                category["percentage"] for category in distribution["categories"]
            ) == pytest.approx(100.0)

        fetched = client.get(f"/api/v1/calculations/{snapshot['id']}")
        assert fetched.status_code == 200
        assert fetched.json() == snapshot

        table_json = client.get(
            f"/api/v1/calculations/{snapshot['id']}/tables/table.planet_positions"
        )
        assert table_json.status_code == 200
        assert len(table_json.json()["rows"]) == 10
        assert table_json.json()["metadata"]["snapshot_id"] == snapshot["id"]
        table_csv = client.get(
            f"/api/v1/calculations/{snapshot['id']}/tables/table.planet_positions",
            params={"format": "csv"},
        )
        assert table_csv.status_code == 200
        assert table_csv.headers["content-type"].startswith("text/csv")
        assert snapshot["id"] in table_csv.text.splitlines()[1]

        expected_table_sizes = {
            "table.planet_positions": 10,
            "table.planet_speeds": 10,
            "table.house_cusps": 12,
            "table.natal_aspects": len(snapshot["result"]["aspects"]),
            "table.elements": 4,
            "table.modalities": 3,
            "table.polarity": 2,
        }
        for table_id, expected_size in expected_table_sizes.items():
            table_response = client.get(
                f"/api/v1/calculations/{snapshot['id']}/tables/{table_id}"
            )
            assert table_response.status_code == 200, table_response.text
            assert len(table_response.json()["rows"]) == expected_size
            csv_response = client.get(
                f"/api/v1/calculations/{snapshot['id']}/tables/{table_id}",
                params={"format": "csv"},
            )
            assert csv_response.status_code == 200
            assert csv_response.text.count("\n") >= expected_size

        repeated = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        ).json()
        assert repeated["input_fingerprint"] == snapshot["input_fingerprint"]
        assert repeated["result"]["points"] == snapshot["result"]["points"]
        assert (
            repeated["result"]["astronomical_context"]["julian_day_ut"]
            == (snapshot["result"]["astronomical_context"]["julian_day_ut"])
        )
        assert repeated["result"]["houses"] == snapshot["result"]["houses"]
        assert repeated["result"]["aspects"] == snapshot["result"]["aspects"]
        assert (
            repeated["result"]["distributions"] == snapshot["result"]["distributions"]
        )


def test_current_sky_is_a_single_event_chart_without_person_timing_results() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_sky_event_payload()).json()
        response = client.post(
            "/api/v1/calculations",
            json=_current_sky_payload(saved["version"]["id"]),
        )

        assert response.status_code == 201, response.text
        snapshot = response.json()
        assert len(snapshot["result"]["charts"]) == 1
        assert snapshot["result"]["charts"][0]["family"] == "mundane"
        assert snapshot["result"]["charts"][0]["technique"] == "mundane.current_sky"
        assert snapshot["result"]["profections"] is None
        assert snapshot["result"]["firdaria"] is None
        assert snapshot["result"]["zodiacal_releasing"] == {}
        output_ids = {
            item["output_id"] for item in snapshot["result"]["output_manifest"]
        }
        assert "manifest.mundane.current_sky" in output_ids
        assert "manifest.timing.natal_periods" not in output_ids


def test_transit_comparison_reuses_natal_and_current_sky_snapshots() -> None:
    with _client() as client:
        natal_subject = client.post("/api/v1/subjects", json=_birth_payload()).json()
        sky_subject = client.post("/api/v1/subjects", json=_sky_event_payload()).json()
        natal_snapshot = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(natal_subject["version"]["id"]),
        ).json()
        sky_snapshot = client.post(
            "/api/v1/calculations",
            json=_current_sky_payload(sky_subject["version"]["id"]),
        ).json()

        response = client.post(
            "/api/v1/calculations/comparisons",
            json={
                "reference_snapshot": natal_snapshot,
                "moving_snapshot_id": sky_snapshot["id"],
                "context": "transit",
                "settings": _calculation_payload("unused")["settings"],
            },
        )

    assert response.status_code == 201, response.text
    comparison = response.json()
    assert comparison["status"] == "complete"
    result = comparison["result"]
    assert result["context"] == "transit"
    assert result["reference_snapshot_id"] == natal_snapshot["id"]
    assert result["moving_snapshot_id"] == sky_snapshot["id"]
    assert len(result["moving_points_in_reference_houses"]) == len(
        sky_snapshot["result"]["points"]
    )
    assert all(
        1 <= placement["reference_house"] <= 12
        for placement in result["moving_points_in_reference_houses"]
    )
    assert result["cross_aspects"]
    assert all(
        aspect["context"] == "transit" for aspect in result["cross_aspects"]
    )
    assert all(
        aspect["moving_point_id"] and aspect["reference_point_id"]
        for aspect in result["cross_aspects"]
    )


def test_secondary_progression_reuses_natal_snapshot_and_returns_comparison() -> None:
    with _client() as client:
        natal_subject = client.post("/api/v1/subjects", json=_birth_payload()).json()
        natal_snapshot = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(natal_subject["version"]["id"]),
        ).json()
        response = client.post(
            "/api/v1/calculations/secondary-progressions",
            json={
                "reference_snapshot": natal_snapshot,
                "target_date": "2026-07-23",
                "settings": _calculation_payload("unused")["settings"],
                "rule_pack_hash": f"sha256:{'b' * 64}",
            },
        )

    assert response.status_code == 201, response.text
    result = response.json()
    assert result["status"] == "complete"
    assert result["reference_snapshot_id"] == natal_snapshot["id"]
    assert result["target_date"] == "2026-07-23"
    assert result["progressed_time"].startswith("2000-01-28T")
    progressed = result["progressed_snapshot"]
    assert progressed["result"]["charts"][0]["family"] == "progression"
    assert progressed["result"]["charts"][0]["technique"] == "progression.secondary"
    output_ids = {
        item["output_id"] for item in progressed["result"]["output_manifest"]
    }
    assert "manifest.progression.secondary" in output_ids
    comparison = result["comparison"]["result"]
    assert comparison["context"] == "progression"
    assert comparison["reference_snapshot_id"] == natal_snapshot["id"]
    assert comparison["moving_snapshot_id"] == progressed["id"]
    assert comparison["cross_aspects"]
    assert len(comparison["moving_points_in_reference_houses"]) == len(
        progressed["result"]["points"]
    )


def test_classical_tables_orb_hierarchy_and_special_facts_reach_snapshot() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        version_id = saved["version"]["id"]

        zero_orb_payload = _calculation_payload(version_id)
        zero_orb_payload["settings"]["orb_overrides"] = [
            {"scope": "chart_context", "chart_context": "within_chart", "orb_deg": 0}
        ]
        zero_orb = client.post("/api/v1/calculations", json=zero_orb_payload)
        assert zero_orb.status_code == 201, zero_orb.text

        pair_payload = _calculation_payload(version_id)
        pair_payload["settings"]["orb_overrides"] = [
            {"scope": "chart_context", "chart_context": "within_chart", "orb_deg": 0},
            {
                "scope": "point_pair",
                "point_a": "sun",
                "point_b": "moon",
                "orb_deg": 30,
            },
        ]
        pair_payload["settings"]["classical_settings"] = {
            "triplicity_table": "ptolemaic.v1",
            "terms_table": "ptolemaic.v1",
        }
        pair_response = client.post("/api/v1/calculations", json=pair_payload)
        assert pair_response.status_code == 201, pair_response.text

    zero_snapshot = zero_orb.json()
    pair_snapshot = pair_response.json()
    assert len(pair_snapshot["result"]["aspects"]) > len(
        zero_snapshot["result"]["aspects"]
    )
    sun_moon = [
        aspect
        for aspect in pair_snapshot["result"]["aspects"]
        if {aspect["point_a"], aspect["point_b"]} == {"sun", "moon"}
    ]
    assert sun_moon
    assert all(any("point_pair" in ref for ref in aspect["rule_refs"]) for aspect in sun_moon)

    classical = pair_snapshot["result"]["classical"]
    assert classical["triplicity_table"] == "ptolemaic"
    assert classical["terms_table"] == "ptolemaic"
    assert "ptolemaic" in json.dumps(
        pair_snapshot["result"]["dignities"], ensure_ascii=False
    )

    special_degrees = pair_snapshot["result"]["special_degrees"]
    mirrors = pair_snapshot["result"]["mirror_points"]
    assert len(special_degrees["points"]) == len(pair_snapshot["result"]["points"])
    assert len(mirrors["mirror_points"]) == len(pair_snapshot["result"]["points"])
    assert special_degrees["provenance"]["algorithm_card_id"] == (
        "ALG-NATAL-SPECIAL-DEGREES-001"
    )
    assert mirrors["provenance"]["algorithm_card_id"] == "ALG-NATAL-MIRROR-POINTS-001"


def test_sidereal_snapshot_does_not_apply_tropical_special_degree_profile() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"].update(
            {"zodiac": "sidereal", "ayanamsa": "fagan_bradley"}
        )
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 201, response.text
    snapshot = response.json()
    special_degrees = snapshot["result"]["special_degrees"]
    mirrors = snapshot["result"]["mirror_points"]
    manifest = next(
        item
        for item in snapshot["result"]["output_manifest"]
        if item["output_id"] == "manifest.natal.special_degrees"
    )
    assert special_degrees["availability"] == "not_applicable"
    assert special_degrees["points"] == []
    assert special_degrees["provenance"]["profile_zodiac"] == "tropical"
    assert manifest["status"] == "blocked"
    assert manifest["table_ids"] == []
    assert mirrors["mirror_points"]


def test_professional_natal_profile_materializes_signs_points_structure_and_classical() -> (
    None
):
    with _professional_client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["calculation_profile_id"] = "professional.natal.v1"
        payload["settings"]["aspect_set_id"] = "official.aspects.professional_natal.v1"
        payload["settings"]["orb_profile_id"] = "official.orbs.professional_natal.v1"
        response = client.post("/api/v1/calculations", json=payload)
        assert response.status_code == 201, response.text
        snapshot_id = response.json()["id"]
        markdown_export = client.get(
            f"/api/v1/calculations/{snapshot_id}/exports/natal-technical",
            params={"format": "markdown"},
        )
        plaintext_export = client.get(
            f"/api/v1/calculations/{snapshot_id}/exports/natal-technical",
            params={"format": "plaintext"},
        )
        ai_catalog = client.get("/api/v1/ai/providers")
        ai_preview = client.post(
            "/api/v1/ai/analyses/preview",
            json={
                "snapshot_id": snapshot_id,
                "provider_id": "moonshot",
                "model_id": "kimi",
                "document_format": "markdown",
                "analysis_focus": "Review the materialized natal facts only.",
                "store_response": True,
            },
        )
        assert ai_preview.status_code == 200, ai_preview.text
        ai_preview_body = ai_preview.json()
        ai_without_consent = client.post(
            "/api/v1/ai/analyses",
            json={
                "snapshot_id": snapshot_id,
                "provider_id": "openai",
                "model_id": "gpt",
                "document_format": "markdown",
                "payload_hash": ai_preview_body["payload_hash"],
                "consent_to_send_snapshot": False,
                "authority_for_subject_data": True,
                "consent_policy_version": "2026-07-19",
            },
        )
        ai_unconfigured = client.post(
            "/api/v1/ai/analyses",
            json={
                "snapshot_id": snapshot_id,
                "provider_id": "moonshot",
                "model_id": "kimi",
                "document_format": "markdown",
                "analysis_focus": "Review the materialized natal facts only.",
                "payload_hash": ai_preview_body["payload_hash"],
                "consent_to_send_snapshot": True,
                "authority_for_subject_data": True,
                "consent_policy_version": "2026-07-19",
            },
        )
        professional_table_ids = [
            "table.planet_positions",
            "table.planet_speeds",
            "table.house_cusps",
            "table.natal_aspects",
            "table.elements",
            "table.modalities",
            "table.polarity",
            "table.chart_patterns",
            "table.essential_dignities",
            "table.receptions",
            "graph.dispositor_chain",
            "table.sect_condition",
            "table.arabic_parts",
        ]
        professional_tables = {
            table_id: (
                client.get(f"/api/v1/calculations/{snapshot_id}/tables/{table_id}"),
                client.get(
                    f"/api/v1/calculations/{snapshot_id}/tables/{table_id}",
                    params={"format": "csv"},
                ),
            )
            for table_id in professional_table_ids
        }

    snapshot = response.json()
    point_ids = [point["point_id"] for point in snapshot["result"]["points"]]
    assert len(point_ids) == 62
    assert point_ids[:10] == [
        "sun",
        "moon",
        "mercury",
        "venus",
        "mars",
        "jupiter",
        "saturn",
        "uranus",
        "neptune",
        "pluto",
    ]
    assert {
        "asc",
        "dsc",
        "mc",
        "ic",
        "true_north_node",
        "true_south_node",
        "chiron",
        "ceres",
        "fortune",
        "spirit",
        "lot_basis",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
        "lot_exaltation",
        "cupido",
        "hades",
        "zeus",
        "kronos",
        "apollon",
        "admetos",
        "vulkanus",
        "poseidon",
    } <= set(point_ids)
    assert all(point["sign"] for point in snapshot["result"]["points"])
    assert all(
        0 <= point["degree_in_sign"] < 30 for point in snapshot["result"]["points"]
    )
    assert snapshot["result"]["structure"]["availability"] == "available"
    assert snapshot["result"]["classical"]["availability"] == "available"
    assert len(snapshot["result"]["dignities"]) == 7
    assert {lot["lot_id"] for lot in snapshot["result"]["lots"]} == {
        "fortune",
        "spirit",
        "lot_basis",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
        "lot_exaltation",
    }
    chart = snapshot["result"]["charts"][0]
    assert chart["aspect_evaluation"]["selected_point_count"] == 62
    assert chart["aspect_evaluation"]["evaluated_pair_count"] == 1891
    assert {aspect["type"] for aspect in chart["aspects"]} - {
        "conjunction",
        "sextile",
        "square",
        "trine",
        "opposition",
    }
    assert chart["classical"]["sect"]["sect"] in {"day", "night"}
    assert markdown_export.status_code == 200
    assert markdown_export.headers["content-type"].startswith("text/markdown")
    assert "## 完整点位" in markdown_export.text
    assert "## 完整相位" in markdown_export.text
    assert "## 输入质量与分析提醒" in markdown_export.text
    assert "结构化证据与原始高级结果" not in markdown_export.text
    assert "结果覆盖与输出清单" not in markdown_export.text
    assert "定位星链" not in markdown_export.text
    assert "output_manifest" not in markdown_export.text
    assert "input_fingerprint" not in markdown_export.text
    assert "algorithm_card_id" not in markdown_export.text
    assert "rule_ids" not in markdown_export.text
    assert "not_calculated_in_virtual_fixture" not in markdown_export.text
    assert "/result/structure" not in markdown_export.text
    assert "manifest.natal.standard_chart" not in markdown_export.text
    assert "福点：" in markdown_export.text
    assert markdown_export.headers["x-interstellar-document-hash"].startswith("sha256:")
    assert (
        markdown_export.headers["x-interstellar-document-hash"]
        == plaintext_export.headers["x-interstellar-document-hash"]
        == ai_preview_body["document_content_hash"]
    )
    assert markdown_export.headers["etag"] == (
        f'"{markdown_export.headers["x-interstellar-document-hash"]}"'
    )
    assert plaintext_export.status_code == 200
    assert plaintext_export.headers["content-type"].startswith("text/plain")
    assert "=== 古典与希腊化事实 ===" in plaintext_export.text
    assert "=== 输入质量与分析提醒 ===" in plaintext_export.text
    assert "=== 结果覆盖与输出清单 ===" not in plaintext_export.text
    for table_id, (json_response, csv_response) in professional_tables.items():
        assert json_response.status_code == 200, (table_id, json_response.text)
        assert "rows" in json_response.json()
        assert csv_response.status_code == 200, (table_id, csv_response.text)
        assert csv_response.headers["content-type"].startswith("text/csv")
    assert ai_catalog.status_code == 200
    assert [item["provider_id"] for item in ai_catalog.json()["providers"]] == [
        "deepseek",
        "openai",
        "moonshot",
    ]
    assert ai_preview_body["provider_configured"] is False
    assert ai_preview_body["availability"] == "not_configured"
    assert ai_preview_body["payload_hash"].startswith("sha256:")
    assert ai_preview_body["character_count"] > 1_000
    assert ai_preview_body["preview_excerpt"]
    assert ai_without_consent.status_code == 422
    assert ai_unconfigured.status_code == 409
    assert ai_unconfigured.json()["code"] == "AI_PROVIDER_NOT_CONFIGURED"
    assert ai_unconfigured.json()["fields"]["availability"] == "not_configured"


def test_natal_ai_test_adapter_requires_unchanged_preview_and_keeps_snapshot_immutable() -> (
    None
):
    ephemeris_path = (
        Path(__file__).resolve().parents[2] / "vendor" / "swisseph" / "ephe"
    )
    app = create_app(
        ApiSettings(
            environment="test",
            swiss_ephemeris_path=str(ephemeris_path),
        )
    )
    captured: list[dict] = []

    def executor(payload: dict) -> dict:
        captured.append(payload)
        return {"text": "isolated test response", "finish_reason": "stop"}

    app.state.natal_ai_provider_overrides = {
        "openai": {
            "configured": True,
            "availability": "configured",
            "blocking_reason": None,
            "data_destination": "test-adapter://isolated",
            "retention_policy": "test only; no third-party transfer",
            "models": [
                {
                    "model_id": "gpt",
                    "label": "GPT isolated test adapter",
                    "configured": True,
                    "context_limit": 100_000,
                }
            ],
        }
    }
    app.state.natal_ai_executor = executor

    with TestClient(app) as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["calculation_profile_id"] = "professional.natal.v1"
        response = client.post("/api/v1/calculations", json=payload)
        assert response.status_code == 201, response.text
        snapshot = response.json()
        snapshot_before = json.dumps(snapshot, ensure_ascii=False, sort_keys=True)
        preview_request = {
            "snapshot_id": snapshot["id"],
            "provider_id": "openai",
            "model_id": "gpt",
            "document_format": "markdown",
            "analysis_focus": "relationship between structure and dignities",
            "store_response": True,
        }
        preview = client.post("/api/v1/ai/analyses/preview", json=preview_request)
        assert preview.status_code == 200, preview.text
        preview_body = preview.json()
        changed = client.post(
            "/api/v1/ai/analyses",
            json={
                **preview_request,
                "analysis_focus": "changed after consent",
                "payload_hash": preview_body["payload_hash"],
                "consent_to_send_snapshot": True,
                "authority_for_subject_data": True,
                "consent_policy_version": "2026-07-19",
            },
        )
        submitted = client.post(
            "/api/v1/ai/analyses",
            json={
                **preview_request,
                "payload_hash": preview_body["payload_hash"],
                "consent_to_send_snapshot": True,
                "authority_for_subject_data": True,
                "consent_policy_version": "2026-07-19",
            },
        )
        snapshot_after = client.app.state.workflow_store.get_snapshot(snapshot["id"])

    assert preview_body["provider_configured"] is True
    assert changed.status_code == 409
    assert changed.json()["code"] == "AI_PAYLOAD_CHANGED_AFTER_CONSENT"
    assert submitted.status_code == 202, submitted.text
    artifact = submitted.json()
    assert artifact["ai_generated"] is True
    assert artifact["calculation_writeback"] is False
    assert artifact["document_content_hash"] == preview_body["document_content_hash"]
    assert artifact["response"]["text"] == "isolated test response"
    assert len(captured) == 1
    assert "technical_document" in captured[0]
    assert "snapshot" not in captured[0]
    assert (
        json.dumps(snapshot_after, ensure_ascii=False, sort_keys=True)
        == snapshot_before
    )


def test_sidereal_natal_api_requires_and_preserves_explicit_ayanamsa() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        tropical_payload = _calculation_payload(saved["version"]["id"])
        tropical = client.post("/api/v1/calculations", json=tropical_payload)
        sidereal_payload = _calculation_payload(saved["version"]["id"])
        sidereal_payload["settings"]["zodiac"] = "sidereal"
        sidereal_payload["settings"]["ayanamsa"] = "lahiri"
        sidereal = client.post("/api/v1/calculations", json=sidereal_payload)

    assert tropical.status_code == 201, tropical.text
    assert sidereal.status_code == 201, sidereal.text
    tropical_snapshot = tropical.json()
    sidereal_snapshot = sidereal.json()
    provenance = sidereal_snapshot["result"]["astronomical_context"][
        "adapter_provenance"
    ]
    assert sidereal_snapshot["request"]["settings"]["zodiac"] == "sidereal"
    assert sidereal_snapshot["request"]["settings"]["ayanamsa"] == "lahiri"
    assert provenance["zodiac"] == "sidereal"
    assert provenance["ayanamsa"] == "lahiri"
    assert 20 < provenance["ayanamsa_value_deg"] < 30
    assert (
        sidereal_snapshot["result"]["points"][0]["sign"]
        != tropical_snapshot["result"]["points"][0]["sign"]
    )
    assert sidereal_snapshot["result"]["houses"][0][
        "cusp_longitude_deg"
    ] != pytest.approx(
        tropical_snapshot["result"]["houses"][0]["cusp_longitude_deg"],
        abs=1e-3,
    )


def test_sidereal_natal_api_rejects_missing_or_unknown_ayanamsa() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["zodiac"] = "sidereal"
        missing = client.post("/api/v1/calculations", json=payload)
        payload["settings"]["ayanamsa"] = "invented"
        unknown = client.post("/api/v1/calculations", json=payload)

    assert missing.status_code == 422
    assert unknown.status_code == 422
    assert "settings.ayanamsa" in missing.json()["fields"]
    assert "settings.ayanamsa" in unknown.json()["fields"]


def test_natal_api_materializes_selected_fixed_stars_and_contacts() -> None:
    with _professional_client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["fixed_star_ids"] = ["aldebaran", "spica", "regulus"]
        payload["settings"]["custom_parameters"] = {
            "fixed_star_conjunction_orb_deg": 2.0,
        }
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 201, response.text
    snapshot = response.json()
    stars = snapshot["result"]["fixed_stars"]
    assert [star["star_id"] for star in stars] == ["aldebaran", "spica", "regulus"]
    assert all(star["position"]["center"] == "geocentric" for star in stars)
    assert all(star["formula_ref"] == "ephemeris.swiss.fixed_star.v1" for star in stars)
    chart = snapshot["result"]["charts"][0]
    assert chart["fixed_stars"] == stars
    assert chart["fixed_star_contacts"] == snapshot["result"]["fixed_star_contacts"]
    manifest = next(
        item
        for item in snapshot["result"]["output_manifest"]
        if item["calculation_id"] == "astronomy.fixed_stars"
    )
    assert manifest["status"] == "generated"
    assert manifest["result_pointer"] == "/result/fixed_stars"


def test_natal_api_rejects_unknown_fixed_star_ids() -> None:
    with _professional_client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["fixed_star_ids"] = ["not_a_catalog_star"]
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 422
    assert "unsupported ids" in response.json()["fields"]["subject.time_spec"]


def test_unknown_birth_time_never_runs_as_midnight() -> None:
    with _client() as client:
        saved = client.post(
            "/api/v1/subjects",
            json=_birth_payload(precision="date", local_value="2000-01-01"),
        ).json()
        response = client.post(
            "/api/v1/calculations",
            json=_calculation_payload(saved["version"]["id"]),
        )

    assert response.status_code == 201
    snapshot = response.json()
    assert snapshot["status"] == "partial"
    assert snapshot["result"]["houses"] == []
    assert snapshot["result"]["aspects"] == []
    assert snapshot["result"]["lots"] == []
    assert snapshot["result"]["dignities"] == []
    assert all(point["house"] is None for point in snapshot["result"]["points"])
    assert all(
        "date_range.reference_position_not_birth_time" in point["status_refs"]
        for point in snapshot["result"]["points"]
    )
    uncertainty = snapshot["result"]["astronomical_context"]["uncertainty"]
    assert uncertainty["reference_position_is_birth_time"] is False
    assert uncertainty["interval_start_utc"] == "1999-12-31T16:00:00Z"
    assert uncertainty["interval_end_utc"] == "2000-01-01T16:00:00Z"
    assert uncertainty["reference_utc"] == "2000-01-01T04:00:00Z"
    assert (
        snapshot["normalized_input"]["subject_version"]["time_spec"]["selected_utc"]
        is None
    )
    warning_codes = {warning["code"] for warning in snapshot["warnings"]}
    assert "BIRTH_TIME_UNKNOWN_DATE_RANGE" in warning_codes
    assert "TIME_DEPENDENT_NATAL_OUTPUTS_BLOCKED" in warning_codes
    manifests = {
        item["calculation_id"]: item for item in snapshot["result"]["output_manifest"]
    }
    assert manifests["astronomy.ephemeris_core"]["status"] == "degraded"
    assert manifests["astronomy.houses_angles"]["status"] == "blocked"
    assert manifests["natal.standard_chart"]["status"] == "blocked"


def test_m2_accepts_topocentric_natal_and_rejects_heliocentric_chart_semantics() -> (
    None
):
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["center"] = "topocentric"
        topocentric = client.post("/api/v1/calculations", json=payload)
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["center"] = "heliocentric"
        response = client.post("/api/v1/calculations", json=payload)

    assert topocentric.status_code == 201, topocentric.text
    assert (
        topocentric.json()["result"]["astronomical_context"]["coordinate_settings"]["center"]
        == "topocentric"
    )
    assert all(
        point["position"]["center"] == "topocentric"
        for point in topocentric.json()["result"]["points"]
    )
    assert response.status_code == 422
    assert "separate Earth/Sun-origin" in response.json()["fields"]["settings.center"]


def test_process_adapter_rejects_snapshot_overwrite() -> None:
    store = WorkflowStore()
    snapshot = {"id": "calculation-immutable", "value": 1}
    store.put_snapshot(snapshot)
    snapshot["value"] = 2
    assert store.get_snapshot("calculation-immutable")["value"] == 1
    with pytest.raises(WorkflowRecordConflict, match="already exists"):
        store.put_snapshot({"id": "calculation-immutable", "value": 3})


def test_m3_point_projection_is_explicit_and_distribution_degrades() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["included_points"] = ["sun", "moon", "saturn"]
        response = client.post("/api/v1/calculations", json=payload)

    assert response.status_code == 201, response.text
    snapshot = response.json()
    assert snapshot["status"] == "partial"
    assert [point["point_id"] for point in snapshot["result"]["points"]] == [
        "sun",
        "moon",
        "saturn",
    ]
    assert all(
        distribution["availability"] == "unavailable"
        for distribution in snapshot["result"]["distributions"]
    )
    assert "DISTRIBUTION_INPUT_INCOMPLETE" in {
        warning["code"] for warning in snapshot["warnings"]
    }


def test_m3_rejects_unknown_house_or_rule_profile_instead_of_ignoring_it() -> None:
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=_birth_payload()).json()
        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["house_system"] = "invented_house_system"
        house_response = client.post("/api/v1/calculations", json=payload)

        payload = _calculation_payload(saved["version"]["id"])
        payload["settings"]["orb_profile_id"] = "invented.orb.profile"
        orb_response = client.post("/api/v1/calculations", json=payload)

    assert house_response.status_code == 422
    assert (
        "unsupported house system"
        in house_response.json()["fields"]["subject.time_spec"]
    )
    assert orb_response.status_code == 422
    assert (
        "official.orbs.standard.v1"
        in orb_response.json()["fields"]["subject.time_spec"]
    )


def test_m3_high_latitude_fallback_is_never_silent() -> None:
    birth = _birth_payload(local_value="2000-01-01T12:00")
    birth["version"]["time_spec"]["timezone_id"] = "Europe/Oslo"
    birth["version"]["location"].update(
        {
            "name": "Svalbard",
            "latitude": 80.0,
            "longitude": 18.9553,
            "timezone_id": "Europe/Oslo",
        }
    )
    with _client() as client:
        saved = client.post("/api/v1/subjects", json=birth).json()
        base = _calculation_payload(saved["version"]["id"])
        unavailable = client.post("/api/v1/calculations", json=base)

        fallback = _calculation_payload(saved["version"]["id"])
        fallback["settings"]["custom_parameters"] = {
            "allow_house_fallback_whole_sign": True
        }
        degraded = client.post("/api/v1/calculations", json=fallback)

    assert unavailable.status_code == 201
    assert unavailable.json()["status"] == "partial"
    assert unavailable.json()["result"]["charts"][0]["house_set"] is None
    assert "HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE" in {
        warning["code"] for warning in unavailable.json()["warnings"]
    }

    assert degraded.status_code == 201
    degraded_snapshot = degraded.json()
    assert degraded_snapshot["status"] == "partial"
    assert degraded_snapshot["result"]["charts"][0]["house_set"]["system"] == (
        "whole_sign"
    )
    house_manifest = next(
        item
        for item in degraded_snapshot["result"]["output_manifest"]
        if item["calculation_id"] == "astronomy.houses_angles"
    )
    assert house_manifest["status"] == "degraded"
