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


def test_chart_wheel_motion_is_layered_and_reduce_motion_aware():
    source = text(RENDERER)
    assert "@Environment(\\.accessibilityReduceMotion)" in source
    assert "@State private var revealProgress" in source
    assert "structureOpacity" in source
    assert "pointOpacity" in source
    assert "aspectOpacity" in source
    assert ".task(id: motionTaskID)" in source
    assert "accessibilityReduceMotion" in source


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
    assert "presentation == .ask ? 0.15 : 0.11" in source
    assert "horaryOverlay?.highlightedHouses" in source
    assert "horaryOverlay?.keyAspectIDs" in source


def test_compare_wheel_strengthens_real_cross_chart_connections():
    source = text(RENDERER)
    assert "presentation == .compare ? 0.32 : 0.25" in source
    assert "comparisonAspects" in source
