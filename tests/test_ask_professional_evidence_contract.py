import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFESSIONAL = ROOT / "ios/App/Ask/AskProfessionalView.swift"
EVIDENCE = ROOT / "ios/App/Ask/AskProfessionalEvidenceView.swift"
PROJECT = ROOT / "ios/Interstellar.xcodeproj/project.pbxproj"
LOCALIZATION = ROOT / "ios/Localization/UI/today-ask.json"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_current_judged_sessions_do_not_render_legacy_score_components():
    source = read(PROFESSIONAL)
    legacy_start = source.index("if analysis.judgment == nil")
    legacy_end = source.index("if analysis.judgment != nil", legacy_start)
    legacy = source[legacy_start:legacy_end]
    assert "analysis.components" in legacy
    assert "analysis.score" in legacy

    current = source[source.index("if analysis.judgment != nil", legacy_start):source.index("private func professionalRow")]
    assert "analysis.components" not in current
    assert "analysis.score" not in current


def test_professional_view_renders_lilly_evidence_in_a_separate_component_for_judged_sessions():
    source = read(PROFESSIONAL)
    assert "HoraryProfessionalEvidenceView(" in source
    assert "analysis: analysis" in source
    assert "session: session" in source
    assert EVIDENCE.exists()
    evidence = read(EVIDENCE)
    assert "fortitudeEvidence(" in evidence
    assert "perfectionInterruptionEvidence(" in evidence
    assert "analysis.querentFortitude" in evidence
    assert "analysis.targetFortitude" in evidence
    assert "judgment.perfection.interruptions" in evidence


def test_professional_evidence_component_is_registered_in_xcode_sources():
    project = read(PROJECT)
    assert "AskProfessionalEvidenceView.swift" in project
    assert "AskProfessionalEvidenceView.swift in Sources" in project


def test_professional_fortitude_evidence_shows_totals_categories_and_individual_rules():
    source = read(EVIDENCE)
    section = source[source.index("private func fortitudeEvidence"):source.index("private func perfectionInterruptionEvidence")]
    assert "assessment.total" in section
    assert "assessment.essentialFortitudes" in section
    assert "assessment.essentialDebilities" in section
    assert "assessment.accidentalFortitudes" in section
    assert "assessment.accidentalDebilities" in section
    assert "factor.rule.rawValue" in section
    assert "factor.points" in section


def test_professional_interruption_evidence_shows_kind_body_and_date():
    source = read(EVIDENCE)
    section = source[source.index("private func perfectionInterruptionEvidence"):source.index("private func interruptionLabel")]
    assert "interruption.kind" in section
    assert "interruption.body" in section
    assert "interruption.date" in section
    for case in ["signChange", "refranation", "prohibition", "frustration"]:
        assert f"case .{case}:" in source


def test_professional_evidence_labels_exist_for_all_nine_locales():
    data = json.loads(read(LOCALIZATION))
    locales = {"en", "zh", "es", "fr", "tr", "de", "it", "ko", "pt-BR"}
    keys = [
        "ask.professional.lilly-fortitude",
        "ask.professional.querent-fortitude",
        "ask.professional.target-fortitude",
        "ask.professional.essential-fortitudes",
        "ask.professional.essential-debilities",
        "ask.professional.accidental-fortitudes",
        "ask.professional.accidental-debilities",
        "ask.professional.interruptions",
        "ask.professional.interruption.sign-change",
        "ask.professional.interruption.refranation",
        "ask.professional.interruption.prohibition",
        "ask.professional.interruption.frustration",
    ]
    for key in keys:
        assert key in data, key
        assert set(data[key]) == locales, key
        assert all(str(data[key][locale]).strip() for locale in locales), key
