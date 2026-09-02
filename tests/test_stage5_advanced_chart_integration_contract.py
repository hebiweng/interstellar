from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = (ROOT / 'ios/App/ReportsView.swift').read_text()
PROFILE = (ROOT / 'ios/App/ProfileView.swift').read_text()


def test_report_library_surfaces_relevant_advanced_chart_reports():
    assert 'ChartKind.advancedCases.filter' in REPORTS
    assert 'model.currentSavedReport(for: chart) != nil' in REPORTS
    assert 'model.snapshot(for: chart) != nil' in REPORTS
    assert 'chart == initialChart' in REPORTS


def test_report_library_keeps_core_charts_always_visible():
    assert 'ChartKind.coreCases + visibleAdvancedCharts' in REPORTS


def test_profile_interpretation_defaults_cover_all_chart_kinds():
    section = PROFILE.split('private struct InterpretationDefaultsSettingsView', 1)[1].split('private struct LanguageSettingsView', 1)[0]
    assert 'ForEach(ChartKind.allCases)' in section


def test_profile_clear_by_chart_type_covers_all_chart_kinds():
    section = PROFILE.split('private struct LocalDataSettingsView', 1)[1]
    assert 'ForEach(ChartKind.allCases)' in section

