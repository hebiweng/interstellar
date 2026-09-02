from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'ios/App'
INSIGHTS = APP / 'Insights'


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_all_twelve_charts_are_declared_in_one_definition_registry():
    text = read('ios/App/ChartDefinition.swift')
    for case in [
        '.natal:', '.currentSky:', '.transit:', '.synastry:', '.solarReturn:', '.secondary:',
        '.tertiary:', '.lunarReturn:', '.solarArc:', '.relocation:', '.twelfthHarmonic:', '.thirteenthHarmonic:',
    ]:
        assert case in text
    for token in [
        'enum ChartParameterField',
        'enum ChartInsightMode',
        'enum ChartCalculationMode',
        'struct ChartDefinition',
        'enum ChartDefinitionRegistry',
        'let parameterFields:',
        'let insightMode:',
        'let usesReferenceWheel:',
        'let usesReferenceAspects:',
    ]:
        assert token in text


def test_advanced_parameter_contract_is_explicit_in_registry():
    text = read('ios/App/ChartDefinition.swift')
    expected = {
        '.tertiary:': ['.targetDate'],
        '.lunarReturn:': ['.targetDate', '.location'],
        '.solarArc:': ['.targetDate'],
        '.relocation:': ['.location'],
        '.twelfthHarmonic:': [],
        '.thirteenthHarmonic:': [],
    }
    for chart, fields in expected.items():
        start = text.index(chart)
        block = text[start:start + 900]
        for field in fields:
            assert field in block
        if chart in {'.twelfthHarmonic:', '.thirteenthHarmonic:'}:
            assert 'parameterFields: []' in block


def test_chartkind_capabilities_delegate_to_definition_registry():
    text = read('ios/App/Models.swift')
    for token in [
        'var definition: ChartDefinition',
        'definition.isAdvanced',
        'definition.insightMode',
        'definition.usesReferenceWheel',
        'definition.usesReferenceAspects',
    ]:
        assert token in text


def test_four_remaining_core_charts_have_planning_layers():
    for chart in ['Natal', 'CurrentSky', 'Secondary', 'SolarReturn']:
        path = INSIGHTS / chart / 'Planning' / f'{chart}ContentPlanning.swift'
        assert path.exists(), f'missing {path}'
        text = path.read_text()
        assert f'struct {chart}FactBundle' in text
        assert f'struct {chart}ContentPlan' in text
        assert f'enum {chart}FactBundleBuilder' in text
        assert f'enum {chart}ContentPlanner' in text
        assert 'scopeID' in text
        assert 'evidenceFactIDs' in text


def test_four_core_factories_use_plans_not_legacy_factories():
    for chart in ['Natal', 'CurrentSky', 'Secondary', 'SolarReturn']:
        path = INSIGHTS / chart / 'Factory' / f'{chart}ChartCardFactory.swift'
        text = path.read_text()
        assert f'{chart}ContentPlanner.plan' in text
        assert f'{chart}FactBundleBuilder.build' in text
        assert f'{chart}LegacyCardFactory' not in text


def test_no_legacy_directory_remains_for_four_migrated_charts():
    for chart in ['Natal', 'CurrentSky', 'Secondary', 'SolarReturn']:
        assert not (INSIGHTS / chart / 'Legacy').exists()


def test_all_local_card_plans_share_common_protocol():
    text = read('ios/App/Insights/Shared/Planning/ChartContentPlan.swift')
    for token in [
        'protocol ChartContentPlanProtocol',
        'struct PlannedCardEvidence',
        'var scopeID: String',
        'var orderedCardIDs: [String]',
        'func evidenceFactIDs(for cardID: String)',
    ]:
        assert token in text
    transit = read('ios/App/Insights/Transit/Planning/TransitContentPlanning.swift')
    synastry = read('ios/App/Insights/Synastry/Legacy/SynastryLegacyCardFactory.swift')
    assert 'extension TransitContentPlan: ChartContentPlanProtocol' in transit
    assert 'extension SynastryContentPlan: ChartContentPlanProtocol' in synastry


def test_card_contract_manifest_describes_all_twelve_charts():
    payload = json.loads(read('ios/ContentSchema/card-contracts.json'))
    assert payload['schemaVersion'] >= 4
    assert set(payload['cards']) == {
        'natal', 'current-sky', 'transit', 'secondary', 'solar-return', 'synastry',
        'tertiary', 'lunar-return', 'solar-arc', 'relocation', 'twelfth-harmonic', 'thirteenth-harmonic'
    }
    for chart in ['tertiary', 'lunar-return', 'solar-arc', 'relocation', 'twelfth-harmonic', 'thirteenth-harmonic']:
        assert payload['cards'][chart] == []


def test_content_design_documents_copy_and_evidence_contracts_for_four_migrations():
    path = ROOT / 'ios/ContentSchema/core-chart-planned-copy-design.json'
    payload = json.loads(path.read_text())
    assert payload['schemaVersion'] == 1
    techniques = payload['techniques']
    for key in ['natal', 'current-sky', 'secondary', 'solar-return']:
        assert key in techniques
        assert techniques[key]['cards']
        for card in techniques[key]['cards']:
            assert card['cardID']
            assert card['copySlot']
            assert card['evidence']


def test_four_migrated_copy_matchers_consume_planned_copy_slots():
    planned = read('ios/App/Insights/Shared/Copy/CopyCatalogMatcher+Planned.swift')
    assert 'plan.copySlot' not in planned  # dispatch is delegated to technique matchers
    for chart in ['Natal', 'CurrentSky', 'Secondary', 'SolarReturn']:
        text = read(f'ios/App/Insights/{chart}/Copy/CopyCatalogMatcher+{chart}.swift')
        assert 'PlannedCopySelection' in text
        assert 'switch plan.copySlot' in text
        assert 'sourceFactIDs: plan.evidenceFactIDs' in text


def test_advanced_charts_stay_ai_only_in_unified_registry():
    text = read('ios/App/ChartDefinition.swift')
    for chart in ['.tertiary:', '.lunarReturn:', '.solarArc:', '.relocation:', '.twelfthHarmonic:', '.thirteenthHarmonic:']:
        start = text.index(chart)
        block = text[start:start + 900]
        assert 'insightMode: .aiReportOnly' in block


def test_parameter_ui_is_driven_by_reusable_parameter_presentations():
    definitions = read('ios/App/ChartDefinition.swift')
    charts = read('ios/App/ChartsView.swift')
    assert 'enum ChartParameterPresentation' in definitions
    assert 'let parameterPresentation:' in definitions
    assert 'switch model.selectedChart.definition.parameterPresentation' in charts


def test_parameter_ui_still_exposes_all_six_advanced_chart_controls():
    definitions = read('ios/App/ChartDefinition.swift')
    charts = read('ios/App/ChartsView.swift')
    expected = {
        '.tertiary:': '.targetDateBirthLocation',
        '.lunarReturn:': '.targetDateLocation',
        '.solarArc:': '.targetDateDerivedNatal',
        '.relocation:': '.location',
        '.twelfthHarmonic:': '.derivedNatal',
        '.thirteenthHarmonic:': '.derivedNatal',
    }
    for chart, presentation in expected.items():
        block = definitions[definitions.index(chart):definitions.index(chart) + 1000]
        assert f'parameterPresentation: {presentation}' in block
    assert 'targetDateParameterBinding(for:' in charts
    assert 'advancedTargetDateBinding(for:' in charts
    assert 'advancedLocationName(for:' in charts

