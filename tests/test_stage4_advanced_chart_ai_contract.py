from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AI_SERVICE = (ROOT / 'ios/App/AppAIReportService.swift').read_text()
AI_GEN = (ROOT / 'ios/App/AIGeneration.swift').read_text()
APP_MODEL = (ROOT / 'ios/App/AppModel.swift').read_text()
ADVANCED = (ROOT / 'ios/App/AdvancedChartModels.swift').read_text()
CHARTS = (ROOT / 'ios/App/ChartsView.swift').read_text()
REPORTS = (ROOT / 'ios/App/Reports.swift').read_text()


def test_advanced_technique_metadata_has_provider_document():
    assert 'var aiDocument: [String: Any]' in ADVANCED
    for token in [
        '"tertiary-progression"',
        '"lunar-return"',
        '"solar-arc"',
        '"relocation"',
        '"twelfth-harmonic"',
        '"thirteenth-harmonic"',
        '"positionSemantics"',
        '"houseFrame"',
    ]:
        assert token in ADVANCED
    assert 'document["progressedDate"]' not in ADVANCED


def test_ai_facts_input_carries_optional_technique_metadata():
    assert 'let techniqueMetadata: ChartTechniqueMetadata?' in AI_SERVICE
    assert 'techniqueMetadata: input.techniqueMetadata' in AI_SERVICE


def test_ai_facts_builder_emits_technique_and_uses_metadata_house_frame():
    assert 'techniqueMetadata: ChartTechniqueMetadata? = nil' in AI_GEN
    assert 'document["technique"] = techniqueMetadata.aiDocument' in AI_GEN
    assert 'techniqueMetadata?.houseFrame == .natalReference' in AI_GEN


def test_advanced_reference_facts_are_included_for_ai_reports():
    assert 'chart.isAdvancedChart && chart.usesReferenceAspects' in AI_GEN



def test_synthetic_techniques_do_not_emit_misleading_generic_signals():
    assert 'let includeInternalAspects = chart != .solarArc' in AI_GEN
    assert 'includeAspects: includeInternalAspects' in AI_GEN
    assert 'if !comparisonAspects.isEmpty, chart != .solarArc' in AI_GEN
    assert 'let includeLunarPhase' in AI_GEN
    assert '.physical || semantics == .progressed' in AI_GEN

def test_appmodel_no_longer_blocks_advanced_ai_generation():
    assert 'guard !chart.isAdvancedChart else { return }' not in APP_MODEL
    assert 'await ensureAdvancedChartCalculated(chart)' in APP_MODEL
    assert 'advancedChartResults[chart]?.techniqueMetadata' in APP_MODEL


def test_advanced_ai_state_is_refreshed_when_local_calculation_becomes_ready():
    assert 'refreshAIReportState(for: chart)' in APP_MODEL
    assert 'for chart in ChartKind.allCases' in APP_MODEL


def test_charts_report_button_can_be_exposed_for_ready_advanced_chart():
    assert 'if !model.selectedChart.isAdvancedChart' not in CHARTS
    assert 'reportButtonAvailable' in CHARTS


def test_saved_report_library_has_advanced_scope_labels():
    for scope in [
        'chart.tertiary',
        'chart.lunar-return',
        'chart.solar-arc',
        'chart.relocation',
        'chart.twelfth-harmonic',
        'chart.thirteenth-harmonic',
    ]:
        assert f'"{scope}"' in REPORTS

