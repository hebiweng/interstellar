from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App"


def test_relationship_service_is_dedicated_and_renderer_ready():
    path = APP / "AppRelationshipChartCalculationService.swift"
    assert path.exists(), "Themes relationship calculations need a dedicated app adapter"
    source = path.read_text(encoding="utf-8")
    assert "struct AppRelationshipChartRequest" in source
    assert "final class AppRelationshipChartCalculationService" in source
    assert "-> RelationshipChartArtifact" in source
    assert "calculator.calculateRelationshipChart" in source
    assert "RelationshipPersonInput" in source
    assert "unsupportedPreset" in source


def test_relationship_techniques_do_not_expand_public_chart_kind_or_discovery():
    models = (APP / "Models.swift").read_text(encoding="utf-8")
    chart_definition = (APP / "ChartDefinition.swift").read_text(encoding="utf-8")
    chart_kind_block = re.search(
        r"enum ChartKind:.*?\n}\n",
        models,
        flags=re.DOTALL,
    )
    assert chart_kind_block, "ChartKind enum not found"
    public_chart_kind = chart_kind_block.group(0)
    hidden_ids = [
        "compositeTransit",
        "compositeSecondary",
        "compositeTertiary",
        "davison",
        "marksA",
        "marksB",
        "marksSecondary",
        "marksTertiary",
    ]
    for token in hidden_ids:
        assert token not in public_chart_kind
        assert token not in chart_definition


def test_relationship_techniques_are_reachable_through_bonds_without_expanding_chart_kind():
    app_model = (APP / "AppModel.swift").read_text(encoding="utf-8")
    charts = (APP / "ChartsView.swift").read_text(encoding="utf-8")
    models = (APP / "Models.swift").read_text(encoding="utf-8")

    assert "AppRelationshipChartCalculationService" in app_model
    assert "ensureRelationshipChartCalculated" in app_model
    assert "relationshipArtifacts" in app_model
    assert "enum ChartsSpace" in charts
    assert "case bonds" in charts
    assert "relationshipChartContent" in charts
    assert "relationshipChartsSection" in charts
    assert "extension RelationshipChartKind" in models


def test_bonds_routes_only_synastry_to_the_existing_interpretation_cards_without_placeholders():
    charts = (APP / "ChartsView.swift").read_text(encoding="utf-8")

    assert "selectedRelationshipChart.isSynastry" in charts
    assert "model.insightCards(for: .synastry)" in charts
    assert "relationship.calculated-only" not in charts


def test_all_relationship_techniques_are_report_targets_with_stable_scopes():
    reports = (APP / "ReportsView.swift").read_text(encoding="utf-8")
    models = (APP / "Models.swift").read_text(encoding="utf-8")

    assert "relationshipReportTargets" in reports
    assert "RelationshipChartKind.allCases" in reports
    assert '"relationship.\\(rawValue)"' in models
