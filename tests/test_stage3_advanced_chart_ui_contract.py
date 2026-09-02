import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARTS = (ROOT / 'ios/App/ChartsView.swift').read_text()
MODELS = (ROOT / 'ios/App/Models.swift').read_text()

def merged_ui_translations():
    merged = {}
    for path in sorted((ROOT / 'ios/Localization/UI').glob('*.json')):
        fragment = json.loads(path.read_text())
        overlap = set(merged) & set(fragment)
        assert not overlap, f'duplicate localization keys: {sorted(overlap)[:5]}'
        merged.update(fragment)
    return merged

TRANSLATIONS = merged_ui_translations()


def test_more_entry_is_fixed_outside_core_scroll():
    assert '@State private var showAllCharts = false' in CHARTS
    assert 'ForEach(ChartKind.coreCases)' in CHARTS
    assert 'localized("charts.more"' in CHARTS
    assert 'showAllCharts = true' in CHARTS
    assert '.sheet(isPresented: $showAllCharts)' in CHARTS


def test_all_charts_sheet_groups_advanced_charts():
    for token in [
        'charts.all-charts',
        'charts.progressions-directions',
        'charts.returns',
        'charts.derived-location',
        'ChartDefinitionRegistry.charts(in: .progressionsDirections)',
        'ChartDefinitionRegistry.charts(in: .returns)',
        'ChartDefinitionRegistry.charts(in: .derivedLocation)',
    ]:
        assert token in CHARTS or token in MODELS


def test_advanced_parameter_controls_exist():
    assert 'switch model.selectedChart.definition.parameterPresentation' in CHARTS
    assert 'targetDateParameterBinding(for:' in CHARTS
    assert 'advancedTargetDateBinding(for:' in CHARTS
    assert 'advancedLocationName(for:' in CHARTS
    for token in [
        'case targetDateBirthLocation',
        'case targetDateLocation',
        'case targetDateDerivedNatal',
        'case location',
        'case derivedNatal',
    ]:
        assert token in MODELS or token in (ROOT / 'ios/App/ChartDefinition.swift').read_text()


def test_advanced_chart_content_uses_local_load_state():
    assert 'advancedChartLoadState(for: model.selectedChart)' in CHARTS
    assert 'case .loading' in CHARTS
    assert 'case let .failed(message)' in CHARTS
    assert 'charts.calculating-advanced-chart-locally' in CHARTS


def test_aspect_view_uses_reference_aspect_capability_not_wheel_capability():
    assert 'model.selectedChart.usesReferenceAspects' in CHARTS
    assert 'comparison: model.selectedChart.usesReferenceAspects' in CHARTS


def test_advanced_chart_report_button_is_stage_aware():
    # Stage 4 enables reports after the advanced chart has a calculated snapshot.
    assert 'reportButtonAvailable' in CHARTS


def test_stage3_localization_keys_exist_in_authoritative_source():
    for key in [
        'charts.more',
        'charts.all-charts',
        'charts.progressions-directions',
        'charts.returns',
        'charts.derived-location',
        'charts.derived-from-natal',
        'charts.use-birth-location',
        'charts.calculating-advanced-chart-locally',
    ]:
        assert key in TRANSLATIONS

