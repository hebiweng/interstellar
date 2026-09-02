from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = (ROOT / 'ios/App/Models.swift').read_text()
APP_MODEL = (ROOT / 'ios/App/AppModel.swift').read_text()


def test_chartkind_has_six_advanced_cases():
    for case in [
        'case tertiary',
        'case lunarReturn',
        'case solarArc',
        'case relocation',
        'case twelfthHarmonic',
        'case thirteenthHarmonic',
    ]:
        assert case in MODELS


def test_charttarget_has_six_advanced_targets():
    for case in [
        'case tertiary(',
        'case lunarReturn(',
        'case solarArc(',
        'case relocation(',
        'case twelfthHarmonic',
        'case thirteenthHarmonic',
    ]:
        assert case in MODELS


def test_generic_advanced_result_contract_exists():
    text = (ROOT / 'ios/App/AdvancedChartModels.swift').read_text()
    assert 'struct ChartDisplayResult' in text
    assert 'enum ChartTechniqueMetadata' in text
    assert 'let snapshot: ChartSnapshot' in text
    assert 'let reference: ChartSnapshot?' in text
    assert 'let comparisonAspects: [ChartAspect]' in text
    assert 'let techniqueMetadata: ChartTechniqueMetadata' in text


def test_advanced_calculation_service_is_separate_from_core_refresh():
    text = (ROOT / 'ios/App/AppAdvancedChartCalculationService.swift').read_text()
    assert 'final class AppAdvancedChartCalculationService' in text
    assert 'func calculate(' in text
    assert 'ChartDisplayResult' in text
    # The existing eager service must stay limited to the original six charts.
    eager = (ROOT / 'ios/App/AppChartCalculationService.swift').read_text()
    assert 'calculateTertiaryProgression' not in eager
    assert 'calculateLunarReturn' not in eager
    assert 'calculateSolarArc' not in eager
    assert 'calculateRelocation' not in eager
    assert 'harmonicSnapshot' not in eager


def test_advanced_cache_is_separate_from_existing_snapshot_cache():
    text = (ROOT / 'ios/App/AdvancedChartCache.swift').read_text()
    assert 'final class AdvancedChartCacheStore' in text
    assert 'AdvancedChartCacheEntry' in text
    existing = (ROOT / 'ios/App/SnapshotCache.swift').read_text()
    assert 'AdvancedChartCacheEntry' not in existing


def test_appmodel_exposes_on_demand_advanced_state():
    for token in [
        'advancedChartResults',
        'advancedChartLoadStates',
        'ensureAdvancedChartCalculated',
        'advancedChartFingerprint',
    ]:
        assert token in APP_MODEL

