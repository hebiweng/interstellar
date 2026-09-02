from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "ios/App/ChartsView.swift").read_text()


def test_chart_shortcuts_use_fixed_non_equal_proportions():
    match = re.search(r"static let widthFractions: \[CGFloat\] = \[([^\]]+)\]", SOURCE)
    assert match, "ChartsShortcutLayout.widthFractions is missing"
    values = [float(v.strip()) for v in match.group(1).split(",")]
    assert len(values) == 4
    assert abs(sum(values) - 1.0) < 1e-6
    assert len(set(values)) > 1, "shortcuts must not be four equal columns"
    assert values[2] == max(values), "the third slot must reserve the most width for Progressions/İlerletilmiş"


def test_chart_shortcuts_fill_the_row_and_allow_two_line_labels():
    assert "GeometryReader" in SOURCE
    assert "ChartsShortcutLayout.widthFractions" in SOURCE
    assert ".lineLimit(2)" in SOURCE
    assert ".multilineTextAlignment(.center)" in SOURCE
    assert ".frame(width: slotWidth" in SOURCE


def test_chart_shortcut_widths_reserve_hstack_spacing_before_allocating_slots():
    assert "let totalSpacing = ChartsShortcutLayout.spacing * 3" in SOURCE
    assert "let usableWidth = max(0, proxy.size.width - totalSpacing)" in SOURCE
