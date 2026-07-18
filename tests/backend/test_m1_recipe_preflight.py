from __future__ import annotations

from datetime import UTC, datetime, timedelta

from interstellar_core.application.recipe_preflight import (
    canonical_hash,
    create_noncomputing_snapshot,
    resolve_analysis_recipe,
)


NOW = datetime(2026, 7, 18, 4, 0, tzinfo=UTC)
DATASETS = [
    {
        "id": "iana-tzdb",
        "version": "2026a",
        "checksum": "sha256:test",
        "license": "public-domain",
        "source_uri": "https://www.iana.org/time-zones",
    }
]
PRESET = {
    "id": "natal.modern.v1",
    "rule_pack_id": "official.natal.modern.v1",
    "required_components": ["natal.standard_chart", "natal.patterns_distributions"],
    "optional_components": [],
    "primary_outputs": ["wheel.natal", "table.planet_positions"],
    "secondary_outputs": ["grid.aspects"],
    "report_profile_id": "report.technique_analysis.v1",
    "defaults": {"minimum_time_precision": "date"},
}


def _recipe(*, available: set[str], precision: str = "minute") -> dict:
    return resolve_analysis_recipe(
        recipe_id="recipe-1",
        source_draft_id="draft-1",
        source_draft_revision=1,
        entry_point_id="entry.model",
        subject_roles=[{"role": "primary", "subject_version_id": "subject-version-1"}],
        model_preset=PRESET,
        available_components=available,
        time_precision=precision,
        has_exact_location=True,
        datasets=DATASETS,
        now=NOW,
        expires_at=NOW + timedelta(hours=1),
    )


def test_recipe_preflight_is_deterministic_and_does_not_execute() -> None:
    recipe = _recipe(available={"natal.standard_chart", "natal.patterns_distributions"})

    assert recipe["status"] == "resolved"
    assert recipe["resource_estimate"]["duration_ms_p50"] == 0
    assert recipe["content_hash"].startswith("sha256:")
    assert [node["calculation_id"] for node in recipe["nodes"]] == [
        "natal.standard_chart",
        "natal.patterns_distributions",
    ]
    assert all(node["selected"] and node["locked"] for node in recipe["nodes"])
    assert recipe == _recipe(
        available={"natal.standard_chart", "natal.patterns_distributions"}
    )


def test_unimplemented_required_component_remains_visible_and_blocked() -> None:
    recipe = _recipe(available={"natal.standard_chart"})

    blocked = recipe["nodes"][1]
    assert blocked["tier"] == "blocked"
    assert blocked["selected"] is True
    assert blocked["availability"] == "blocked"
    assert blocked["blocking_reasons"][0]["code"] == "COMPONENT_NOT_IMPLEMENTED"


def test_noncomputing_snapshot_never_claims_astrology_output() -> None:
    recipe = _recipe(available={"natal.standard_chart", "natal.patterns_distributions"})
    normalized_input = {
        "subject_version_id": "subject-version-1",
        "time_spec": {"precision": "minute", "selected_utc": "1990-01-01T04:00:00Z"},
    }

    snapshot = create_noncomputing_snapshot(
        snapshot_id="snapshot-1",
        recipe=recipe,
        normalized_input=normalized_input,
        datasets=DATASETS,
        now=NOW,
        engine_version="0.1.0",
    )

    assert snapshot["status"] == "partial"
    assert snapshot["maturity"] == "experimental"
    assert snapshot["result"]["charts"] == []
    assert snapshot["result"]["points"] == []
    assert {
        item["status"] for item in snapshot["result"]["output_manifest"]
    } == {"not_requested"}
    assert snapshot["warnings"][0]["code"] == "M1_CALCULATION_NOT_EXECUTED"
    assert snapshot["input_fingerprint"] == canonical_hash(normalized_input)
