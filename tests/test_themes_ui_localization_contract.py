from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "ios/App/ThemesFeature.swift"
ROOT_VIEW = ROOT / "ios/App/RootView.swift"
LOCALIZATION = ROOT / "ios/Localization/UI/themes.json"
PBX = ROOT / "ios/Interstellar.xcodeproj/project.pbxproj"


def test_theme_ui_shells_and_setup_flow_exist():
    source = THEMES.read_text()
    for token in [
        "struct ThemesView", "struct ThemeSetupView", "struct ThemeResultView",
        "struct ThemeHistorySection", "struct ThemeChartSelector", "LocationSearchView",
        "ThemeAnalysisManager.shared", 'localized("themes.analyze"',
    ]:
        assert token in source


def test_themes_root_tab_follows_ask_and_precedes_compare_in_final_ia():
    source = ROOT_VIEW.read_text()
    assert "case themes" in source
    ask = source.index("AskView()")
    themes = source.index("ThemesView()")
    compare = source.index("CompareView()")
    charts = source.index("ChartsView(selectedTab: $selection)")
    profile = source.index("ProfileView(")
    assert ask < themes < compare < charts < profile
    assert '.tag(RootTab.themes)' in source
    assert 'localized("navigation.themes"' in source


def test_theme_localization_covers_all_supported_locales_and_core_keys():
    data = json.loads(LOCALIZATION.read_text())
    locales = {"en", "zh", "es", "fr", "tr", "de", "it", "pt-BR", "ko"}
    required = [
        "navigation.themes", "themes.title", "themes.subtitle", "themes.recent",
        "themes.analyze", "themes.optional-context", "themes.current-location",
        "themes.love-relationships", "themes.career-purpose", "themes.money-growth",
        "themes.family-home", "themes.self-wellbeing", "themes.creativity-expression",
        "themes.learning-exploration", "themes.life-direction",
        "themes.report.preparing", "themes.report.retry", "themes.chart.view-details",
        "themes.ai-consent.message",
    ]
    for key in required:
        assert key in data, key
        assert set(data[key]) == locales, key
        assert all(isinstance(v, str) and v.strip() for v in data[key].values()), key
    assert "2" in data["themes.analyze"]["en"]


def test_theme_source_is_in_xcode_project():
    source = PBX.read_text()
    assert "ThemesFeature.swift" in source
    assert "ThemesFeature.swift in Sources" in source


def test_theme_relay_uses_server_prompt_key_and_direct_generate_endpoint():
    source = THEMES.read_text()
    assert 'appendingPathComponent("v1/generate")' in source
    assert '"reportPromptKey": "theme.\\(payload.analysis.theme)"' in source
    assert '"semanticFingerprint": semanticFingerprint' in source
    assert '"factsHash": factsHash' in source


def test_theme_chart_visuals_render_inline_and_detail_is_retained():
    source = THEMES.read_text()
    selector = source[source.index("struct ThemeChartSelector"):source.index("private struct ThemeChartDetailView")]
    detail = source[source.index("private struct ThemeChartDetailView"):source.index("struct ThemeResultView")]
    assert "ChartWheelView(" in selector
    assert "AspectChartView(" not in selector
    assert 'accessibilityIdentifier("theme-result-wheel")' in selector
    assert 'accessibilityIdentifier("theme-view-chart-details")' in selector
    assert "@State private var viewMode: ChartViewMode = .wheel" in detail
    assert '.pickerStyle(.segmented)' in detail
    assert "ChartWheelView(" in detail
    assert "AspectChartView(" in detail


def test_theme_consent_is_prompted_before_analysis_and_not_saved_as_generation_error():
    source = THEMES.read_text()
    assert "private func requestAnalysis()" in source
    assert "guard model.aiConsentGranted else" in source
    assert "showsAIConsentReminder = true" in source
    assert 'Text(localized("themes.ai-consent.message"' in source
    consent_guard = source[source.index("guard model.aiConsentGranted else", source.index("private func beginReportGeneration")):]
    assert "analysis.generationError = nil" in consent_guard[:500]
    assert 'accessibilityIdentifier("theme-report-preparing-card")' in source


def test_theme_localization_is_an_xcode_build_dependency_and_result_has_disclaimer():
    data = json.loads(LOCALIZATION.read_text())
    locales = {"en", "zh", "es", "fr", "tr", "de", "it", "pt-BR", "ko"}
    assert "themes.disclaimer" in data
    assert set(data["themes.disclaimer"]) == locales
    project_yml = (ROOT / "ios/project.yml").read_text()
    assert "$(SRCROOT)/Localization/UI/themes.json" in project_yml
    project = PBX.read_text()
    assert '"$(SRCROOT)/Localization/UI/themes.json"' in project
    source = THEMES.read_text()
    assert 'localized("themes.disclaimer"' in source


def test_themes_home_uses_world_hero_and_asymmetric_eight_theme_layout():
    source = THEMES.read_text()
    home = source[source.index("struct ThemesView"):source.index("struct ThemeHistorySection")]
    for token in [
        'ThemeConstellationHero()',
        'localized("themes.hero.question"',
        'themeHeroCard(.loveRelationships)',
        'themeHalfCard(.careerPurpose)',
        'themeHalfCard(.selfWellbeing)',
        'themeWideCard(.familyHome)',
        'themeHalfCard(.moneyGrowth)',
        'themeHalfCard(.creativityExpression)',
        'themeCompactRow(.learningExploration)',
        'themeCompactRow(.lifeDirection)',
    ]:
        assert token in home, token
    assert "LazyVGrid" not in home
    assert "ForEach(ThemeKind.allCases" not in home


def test_themes_home_keeps_all_eight_existing_theme_kinds_without_fake_categories():
    source = THEMES.read_text()
    home = source[source.index("struct ThemesView"):source.index("struct ThemeHistorySection")]
    required = [
        ".loveRelationships", ".careerPurpose", ".moneyGrowth", ".familyHome",
        ".selfWellbeing", ".creativityExpression", ".learningExploration", ".lifeDirection",
    ]
    for token in required:
        assert token in home


def test_themes_home_card_copy_uses_readable_text_sizes_and_wraps_instead_of_shrinking():
    source = THEMES.read_text()
    half = source[source.index("private func themeHalfCard"):source.index("private func themeWideCard")]
    assert ".font(.subheadline)" in half
    assert ".font(.footnote)" not in half
    compact = source[source.index("private func themeCompactRow"):source.index("private var themeChevron")]
    assert ".font(.headline)" in compact
    assert ".font(.subheadline)" in compact
    assert ".font(.caption)" not in compact
    assert ".minimumScaleFactor" not in half
    assert ".minimumScaleFactor" not in compact


def test_themes_hero_uses_native_constellation_motion_and_cards_have_press_feedback():
    source = THEMES.read_text()
    hero = source[source.index("private struct ThemeConstellationHero"):source.index("private enum ThemeMotifDensity")]
    assert "TimelineView(.animation" in hero
    assert "accessibilityReduceMotion" in hero
    assert "sin(" in hero
    assert "ThemeCardPressStyle" in source
    assert "Lottie" not in hero
