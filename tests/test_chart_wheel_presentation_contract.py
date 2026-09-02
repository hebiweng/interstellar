from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDERER = ROOT / "ios/App/ChartRenderer.swift"
ASK = ROOT / "ios/App/Ask/AskResultView.swift"
ASK_PRO = ROOT / "ios/App/Ask/AskProfessionalView.swift"
THEMES = ROOT / "ios/App/ThemesFeature.swift"
COMPARE = ROOT / "ios/App/CompareView.swift"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_chart_wheel_has_one_parameterized_presentation_layer():
    source = text(RENDERER)
    assert "enum ChartWheelPresentation" in source
    assert "case standard" in source
    assert "case ask" in source
    assert "case theme" in source
    assert "case compare" in source
    assert "let presentation: ChartWheelPresentation" in source
    assert "presentation: ChartWheelPresentation = .standard" in source


def test_chart_wheel_is_static_and_uses_shared_display_architecture():
    source = text(RENDERER)
    for forbidden in [
        "revealProgress", "accessibilityReduceMotion", ".scaleEffect(",
        "withAnimation(", ".animation(", ".onTapGesture", "selectedPlanet",
        "selectedHouse",
    ]:
        assert forbidden not in source
    for required in [
        "ChartDisplayMode", "ChartDisplayConfig", "ChartGeometry",
        "ChartVisualTokens", "displayMode: ChartDisplayMode = .simple",
    ]:
        assert required in source


def test_chart_wheel_presentation_has_distinct_center_language():
    source = text(RENDERER)
    assert 'case .ask:' in source and '"✦"' in source
    assert 'case .theme:' in source and '"✦"' in source
    assert 'case .compare:' in source and '"⇄"' in source


def test_ask_uses_ask_wheel_presentation_everywhere():
    combined = text(ASK) + "\n" + text(ASK_PRO)
    assert combined.count("presentation: .ask") >= 2


def test_themes_uses_theme_wheel_presentation():
    assert "presentation: .theme" in text(THEMES)


def test_compare_uses_compare_wheel_presentation():
    assert "presentation: .compare" in text(COMPARE)


def test_ask_wheel_strengthens_existing_horary_highlights_without_new_data():
    source = text(RENDERER)
    assert "presentation == .ask ? 0.13 : 0.08" in source
    assert "horaryOverlay?.highlightedHouses" in source
    assert "horaryOverlay?.keyAspectIDs" in source


def test_compare_wheel_strengthens_real_cross_chart_connections():
    source = text(RENDERER)
    assert "private func drawComparisonAspects" in source
    assert "geometry.comparisonOuterAspectRadius" in source
    assert "geometry.comparisonInnerAspectRadius" in source
    assert "(displayMode == .simple ? 0.22 : 0.28)" in source
    assert "comparisonAspects" in source
