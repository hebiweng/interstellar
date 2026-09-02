from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASK_DEEP = ROOT / "ios/App/AskDeepAnalysis.swift"


def test_deep_analysis_sends_lilly_fortitudes_as_explicit_evidence():
    source = ASK_DEEP.read_text()
    assert 'factType: "lilly_fortitude_total"' in source
    assert 'factType: "lilly_fortitude_factor"' in source
    assert 'values["rule"] = factor.rule.rawValue' in source
    assert 'values["points"] = String(factor.points)' in source
    assert 'values["category"] = factor.rule.category.rawValue' in source


def test_fortitude_evidence_is_scoped_to_querent_and_target():
    source = ASK_DEEP.read_text()
    assert 'fortitudeFacts(querentFortitude, role: "querent", scope: scope)' in source
    assert 'fortitudeFacts(targetFortitude, role: "target", scope: scope)' in source
