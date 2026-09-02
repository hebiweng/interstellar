import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "ios/App/Ask/AskResultView.swift"
COMPOSER = ROOT / "ios/App/Ask/AskContentComposer.swift"
ACTIONS = ROOT / "ios/App/Ask/AskActions.swift"
DEEP = ROOT / "ios/App/AskDeepAnalysis.swift"
CONSUMER = ROOT / "ios/App/Ask/AskConsumerJudgmentView.swift"
LOCALIZATION = ROOT / "ios/Localization/UI/today-ask.json"
CORE = ROOT / "ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_yes_no_and_choice_consumer_ui_has_no_probability_style_support_percentages():
    result = read(RESULT)
    assert "judgmentResultHero(session" in result
    assert "choiceResultHero(session" in result
    assert "bestTimeSuitabilityHero(session" in result
    assert "scoreResultHero" not in result
    assert 'Text("\\(Int(item.supportScore.rounded()))%")' not in result
    assert "ProgressView(value: item.supportScore" not in result
    assert "primaryScore(" not in result


def test_choice_ranking_uses_lilly_hierarchy_labels_instead_of_support_score_bars():
    result = read(RESULT)
    consumer = read(CONSUMER)
    choice = consumer[consumer.index("func choiceRanking"):consumer.index("func timingRanking")]
    assert 'localized("ask.leading"' in choice
    assert 'localized("ask.close-call"' in choice
    assert 'Text("#\\(index + 1)")' in choice
    assert "supportScore" not in choice
    assert "ProgressView" not in choice


def test_best_time_keeps_explicit_suitability_not_probability_wording():
    result = read(RESULT)
    consumer = read(CONSUMER)
    best = consumer[consumer.index("func bestTimeSuitabilityHero"):consumer.index("func legacyTimingHero")]
    assert 'localized("ask.best-time-suitability"' in best
    assert 'Text("\\(Int(score.rounded())) / 100")' in best
    ranking = consumer[consumer.index("func electionTimingRanking"):consumer.index("func primaryLabel")]
    assert "candidate.assessment.suitabilityScore" in ranking
    assert 'localized("ask.best-time-suitability"' in ranking
    assert "%" not in ranking


def test_history_entries_do_not_persist_support_percentages_for_horary_judgments():
    actions = read(ACTIONS)
    history = actions[actions.index("func historyEntry"):actions.index("func openHistoryEntry")]
    assert "analysis.score.rounded" not in history
    assert "first.supportScore.rounded" not in history
    assert 'localized("ask.leading"' in history
    assert 'localized("ask.judgment-clarity"' in history


def test_consumer_result_cards_do_not_interpolate_old_horary_scores():
    composer = read(COMPOSER)
    yes_no = composer[composer.index("case .yesNo:"):composer.index("case .choice:")]
    choice = composer[composer.index("case .choice:"):composer.index("case .timing:")]
    assert "analysis.score" not in yes_no
    assert 'variables: ["score"' not in yes_no
    assert "first.supportScore" not in choice
    assert '"score"' not in choice


def test_deep_analysis_exposes_strict_horary_facts_without_legacy_support_scores():
    deep = read(DEEP)
    assert '"support_score"' not in deep
    assert 'factType: "support_score"' not in deep
    assert 'factType: "score_component"' not in deep
    assert '"suitability_score"' in deep
    assert 'factType: "lilly_fortitude_total"' in deep
    assert '"rank": String(index + 1)' in deep
    assert '"verdict": choice.analysis.judgment?.verdict.rawValue ?? ""' in deep


def test_deep_analysis_significator_facts_do_not_send_arbitrary_legacy_scores():
    deep = read(DEEP)
    named_start = deep.index('factType: "named_significator"')
    named_end = deep.index("return deduplicated", named_start)
    assert '"score": formatted(significator.score)' not in deep[named_start:named_end]
    planet_start = deep.index("private func planetFact")
    planet_end = deep.index("private func receptionFact", planet_start)
    assert '"score": formatted(assessment.score)' not in deep[planet_start:planet_end]


def test_r5_consumer_labels_are_complete_for_all_nine_locales():
    data = json.loads(read(LOCALIZATION))
    locales = {"en", "zh", "es", "fr", "tr", "de", "it", "ko", "pt-BR"}
    for key in ["ask.mixed", "ask.leading"]:
        assert key in data, key
        assert set(data[key]) == locales, key
        assert all(str(data[key][locale]).strip() for locale in locales), key


def test_consumer_judgment_view_is_included_in_xcode_sources():
    project = read(ROOT / "ios/Interstellar.xcodeproj/project.pbxproj")
    assert "AskConsumerJudgmentView.swift" in project
    assert "AskConsumerJudgmentView.swift in Sources" in project


def test_legacy_when_consumer_fallback_does_not_restore_score_language():
    composer = read(COMPOSER)
    timing = composer[composer.index("case .timing:"):composer.index("case .bestTime:")]
    assert "first.score" not in timing
    assert 'variables: ["score"' not in timing
    assert 'localized("ask.recommended-window"' in timing


def test_choice_hierarchy_uses_lilly_fortitude_not_legacy_planet_score():
    core = read(CORE)
    section = core[core.index("private static func choicePrecedes"):core.index("private static func judgmentRank")]
    assert "targetFortitude?.total" in section
    assert "analysis.target.score" not in section
