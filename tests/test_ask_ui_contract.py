from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASK_DIR = ROOT / "ios/App/Ask"
ASK_VIEW = ASK_DIR / "AskView.swift"
ASK_HOME = ASK_DIR / "AskHomeView.swift"
ASK_CONFIG = ASK_DIR / "AskConfigurationView.swift"
ASK_RESULT = ASK_DIR / "AskResultView.swift"
ASK_COMPOSER = ASK_DIR / "AskContentComposer.swift"
ASK_PRO = ASK_DIR / "AskProfessionalView.swift"
ASK_ACTIONS = ASK_DIR / "AskActions.swift"
ASK_LIFE = ASK_DIR / "AskLifeAreaViews.swift"
ASK_HISTORY = ASK_DIR / "AskHistoryView.swift"
ASK_TYPES = ASK_DIR / "AskSupportingTypes.swift"
LEGACY = ROOT / "ios/App/SynastryView.swift"
PBX = ROOT / "ios/Interstellar.xcodeproj/project.pbxproj"


def read(path: Path) -> str:
    return path.read_text()


def test_ask_is_split_into_a_real_feature_module():
    expected = [
        ASK_VIEW,
        ASK_HOME,
        ASK_CONFIG,
        ASK_RESULT,
        ASK_COMPOSER,
        ASK_PRO,
        ASK_ACTIONS,
        ASK_LIFE,
        ASK_HISTORY,
        ASK_TYPES,
    ]
    assert all(path.exists() for path in expected)
    assert not LEGACY.exists()
    assert read(ASK_VIEW).count("\n") < 350
    assert read(ASK_CONFIG).count("\n") < 650
    assert read(ASK_RESULT).count("\n") < 450
    assert read(ASK_COMPOSER).count("\n") < 250
    assert read(ASK_PRO).count("\n") < 300


def test_legacy_when_history_uses_explicit_compatibility_analysis_only():
    source = read(ASK_COMPOSER)
    timing = source[source.index("case .timing:"):source.index("case .bestTime:")]
    assert "first.legacyHoraryAnalysis" in timing
    assert "first.analysis" not in timing


def test_ask_module_is_registered_in_committed_xcode_project():
    pbx = read(PBX)
    assert "SynastryView.swift" not in pbx
    for name in [
        "AskView.swift",
        "AskHomeView.swift",
        "AskConfigurationView.swift",
        "AskResultView.swift",
        "AskContentComposer.swift",
        "AskProfessionalView.swift",
        "AskActions.swift",
        "AskLifeAreaViews.swift",
        "AskHistoryView.swift",
        "AskSupportingTypes.swift",
    ]:
        assert name in pbx, name
        assert f"{name} in Sources" in pbx, name


def test_ask_home_uses_one_question_three_paths_hierarchy():
    source = read(ASK_HOME)
    for token in [
        "AskPathHero()",
        "askPrimaryModeCard(",
        "mode: .yesNo",
        "askCompactModeCard(",
        "mode: .timing",
        "mode: .choice",
    ]:
        assert token in source, token
    assert source.index("mode: .yesNo") < source.index("mode: .timing") < source.index("mode: .choice")
    assert "askModeCard(" not in source


def test_ask_home_hides_recent_section_completely_when_empty():
    source = read(ASK_HOME)
    assert "if !askHistory.isEmpty" in source
    assert "recentQuestionsSection" in source
    assert "ask.no-saved-questions-yet" not in source
    assert "Try asking" not in source


def test_ask_home_recent_questions_use_real_history_only():
    source = read(ASK_HOME)
    assert "askHistory.prefix(3)" in source
    assert "entry.question" in source
    assert "openHistoryEntry(entry)" in source
    assert "showAskHistory = true" in source


def test_ask_configuration_has_mode_specific_visual_header_without_focus_feature():
    source = read(ASK_CONFIG)
    assert "AskConfigurationHero(" in source
    assert "mode: mode" in source
    assert "ScreenTitle(" not in source
    assert "Focus" not in source
    assert "localized(\"ask.focus" not in source.lower()
    assert "text(\"focus\")" not in source.lower()


def test_ask_home_cards_keep_readable_type_and_do_not_shrink_long_localizations():
    source = read(ASK_HOME)
    primary = source[source.index("func askPrimaryModeCard"):source.index("func askCompactModeCard")]
    compact = source[source.index("func askCompactModeCard"):]
    assert ".font(.title3" in primary or ".font(.title2" in primary
    assert ".font(.headline" in compact
    assert ".font(.subheadline" in compact
    assert ".minimumScaleFactor" not in source
    assert ".fixedSize(horizontal: false, vertical: true)" in primary
    assert ".fixedSize(horizontal: false, vertical: true)" in compact


def test_ask_secondary_pages_preserve_existing_fields_and_free_generation_flow():
    source = read(ASK_CONFIG)
    for token in [
        "yesNoFields",
        "choiceFields",
        "timingFields",
        "locationAndTime(mode)",
        "generate(mode)",
        "canGenerate(mode)",
    ]:
        assert token in source, token
    assert "1 Credit" not in source
    assert "Deep Analysis" not in source


def test_ask_backend_files_stay_outside_ui_module_and_keep_existing_paths():
    assert (ROOT / "ios/App/AskDeepAnalysis.swift").exists()
    assert (ROOT / "ios/App/AskHistory.swift").exists()
    assert (ROOT / "ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift").exists()


def test_ask_hero_uses_native_ambient_motion_and_respects_reduce_motion():
    source = read(ASK_HOME)
    hero = source[source.index("struct AskPathHero"):]
    assert "TimelineView(.animation" in hero
    assert "accessibilityReduceMotion" in hero
    assert "sin(" in hero
    assert "Canvas" in hero
    assert "AskCardPressStyle" in source



def test_ask_mode_cards_use_structural_mini_visuals_not_only_sf_symbols():
    source = read(ASK_HOME)
    assert "AskModeMiniVisual(mode: mode" in source
    assert "private struct AskModeMiniVisual" in source
    assert "case .yesNo" in source
    assert "case .timing" in source
    assert "case .choice" in source


ASK_HISTORY_MODEL = ROOT / "ios/App/AskHistory.swift"
ASK_DEEP = ROOT / "ios/App/AskDeepAnalysis.swift"


def test_ask_deep_job_is_manager_owned_and_history_observes_durable_status():
    deep = ASK_DEEP.read_text()
    view = (ROOT / "ios/App/Ask/AskView.swift").read_text()
    home = (ROOT / "ios/App/Ask/AskHomeView.swift").read_text()
    history = (ROOT / "ios/App/Ask/AskHistoryView.swift").read_text()
    assert "final class AskDeepAnalysisManager" in deep
    assert "private var tasks" in deep
    assert "@Published private(set) var records" in deep
    assert "deepAnalysisStore = AskDeepAnalysisStore.shared" in view
    assert "deepAnalysisStatus" in home
    assert "deepAnalysisStatus" in history


def test_ask_failure_is_only_retried_by_user_and_recovers_server_result_first():
    deep = ASK_DEEP.read_text()
    manager = deep[deep.index("final class AskDeepAnalysisManager"):]
    assert ".onAppear" not in manager
    assert "recoverFirst: isRetry" in manager
    assert "statusIfExists" in deep
    generate = deep[deep.index("func generate("):deep.index("private func waitForResult")]
    assert generate.index("recover(") < generate.index("client.createTask")
    section = deep[deep.index("struct AskDeepAnalysisSection"):]
    assert ".task { manager.reconcile(" in section
    assert ".task { manager.begin(" not in section


def test_ask_reconciliation_persists_context_and_never_creates_ai_task():
    deep = ASK_DEEP.read_text()
    assert "var session: HorarySession?" in deep
    assert "var language: AppLanguage?" in deep
    manager = deep[deep.index("final class AskDeepAnalysisManager"):deep.index("struct AskDeepAnalysisSection")]
    assert "func reconcilePendingReports" in manager
    assert "service.recover" in manager
    recover = deep[deep.index("func recover("):deep.index("func generate(")]
    assert "client.createTask" not in recover


def test_app_foreground_reconciles_ask_and_compare_without_new_generation():
    app = (ROOT / "ios/App/InterstellarApp.swift").read_text()
    assert "AskDeepAnalysisManager.shared.reconcilePendingReports()" in app
    assert "CompareAnalysisManager.shared.reconcilePendingReports(model: model)" in app
APP_MODEL = ROOT / "ios/App/AppModel.swift"


def test_when_uses_single_horary_chart_instead_of_election_search():
    actions = read(ASK_ACTIONS)
    timing_case = actions[actions.index("case .timing:"):actions.index("try Task.checkCancellation()")]
    assert "ElectionTimingRequest" not in timing_case
    assert "searchElectionTiming" not in timing_case
    assert "calculateHorarySnapshot" in timing_case
    assert "calculateHoraryJudgment" in timing_case
    assert "calculateHoraryTiming" in timing_case
    assert "timingResult:" in timing_case


def test_when_configuration_no_longer_exposes_election_precision_or_search_range():
    source = read(ASK_CONFIG)
    timing_fields = source[source.index("var timingFields"):source.index("func locationAndTime")]
    assert 'localized("ask.precision"' not in timing_fields
    assert 'localized("ask.search-within"' not in timing_fields
    assert 'localized("ask.end-date"' not in timing_fields
    assert "TimingRangeSelection" not in timing_fields
    assert "timingPrecision" not in timing_fields
    assert "customEndDate" not in timing_fields
    assert "primaryHouse != nil" in source
    assert "selectedEndDate > startDate" not in source


def test_horary_session_persists_new_timing_result_while_keeping_legacy_candidates_readable():
    source = read(ASK_HISTORY_MODEL)
    assert "let timingResult: HoraryTimingResult?" in source
    assert "timingCandidates: [ElectionTimingCandidate]" in source
    assert "let electionCandidates: [ElectionTimingCandidate]" in source
    assert "decodeIfPresent(HoraryTimingResult.self" in source
    assert "forKey: .timingCandidates" in source
    assert "forKey: .electionCandidates" in source
    assert "currentSchemaVersion = 4" in source


def test_when_result_prefers_lilly_timing_and_only_falls_back_for_legacy_history():
    result = read(ASK_RESULT)
    composer = read(ASK_COMPOSER)
    assert "session.timingResult" in result
    assert "lillyTiming" in result
    assert "session.timingCandidates" in result  # legacy rendering remains
    assert "session.timingResult" in composer
    assert "timingCandidates.first" in composer  # legacy content fallback remains


def test_ask_deep_analysis_sends_lilly_timing_facts_and_legacy_candidates_only_as_fallback():
    source = read(ASK_DEEP)
    assert "session.timingResult" in source
    assert 'factType: "horary_timing"' in source
    assert '"symbolic_units"' in source
    assert '"timing_scales"' in source
    assert "else" in source[source.index("session.timingResult"):source.index("for (index, significator)")]


def test_ask_exposes_four_distinct_modes_including_best_time():
    core = read(ROOT / "ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift")
    home = read(ASK_HOME)
    assert "case bestTime" in core
    assert "mode: .bestTime" in home
    assert 'localized("ask.find-the-best-time"' in home


def test_best_time_uses_election_search_but_when_does_not():
    actions = read(ASK_ACTIONS)
    timing_case = actions[actions.index("case .timing:"):actions.index("try Task.checkCancellation()")]
    assert "searchElectionTiming" not in timing_case
    assert "ElectionTimingRequest" not in timing_case
    assert "case .bestTime:" in actions
    best_case = actions[actions.index("case .bestTime:"):actions.index("try Task.checkCancellation()", actions.index("case .bestTime:"))]
    assert "ElectionTimingRequest" in best_case
    assert "searchElectionTiming" in best_case
    assert "timingResult:" not in best_case
    assert "electionCandidates:" in best_case
    assert "timingCandidates: candidates" not in best_case


def test_best_time_configuration_is_consumer_facing_and_hides_engine_precision():
    source = read(ASK_CONFIG)
    assert "bestTimeFields" in source
    assert "BestTimeSearchWindow" in source
    assert "TimingPrecision" not in source[source.index("bestTimeFields"):source.index("func locationAndTime")]
    assert 'localized("ask.best-time-window"' in source


def test_best_time_and_when_have_distinct_result_paths():
    result = read(ASK_RESULT)
    composer = read(ASK_COMPOSER)
    assert "case .bestTime" in result
    assert "case .bestTime" in composer
    assert "timingRanking(session.timingCandidates)" in result
    assert "session.timingResult" in result


def test_best_time_history_is_physically_separate_from_legacy_when_candidates():
    history = read(ASK_HISTORY_MODEL)
    assert "let electionCandidates: [ElectionTimingCandidate]" in history
    assert "currentSchemaVersion = 4" in history
    assert "case choices, timingResult, timingCandidates, electionCandidates, significators" in history
    assert "mode == .bestTime" in history
    assert "decodedLegacyTimingCandidates" in history


def test_best_time_consumers_use_election_candidates_not_legacy_when_storage():
    actions = read(ASK_ACTIONS)
    result = read(ASK_RESULT)
    composer = read(ASK_COMPOSER)
    deep = read(ASK_DEEP)
    best_actions = actions[actions.index("case .bestTime:"):actions.index("try Task.checkCancellation()", actions.index("case .bestTime:"))]
    assert "electionCandidates:" in best_actions
    assert "timingCandidates: candidates" not in best_actions
    assert "analysis: nil" in best_actions
    assert "first.analysis" not in best_actions
    for source in (result, composer, deep):
        best = source[source.index(".bestTime"):]
        assert "electionCandidates" in best


def test_electional_core_is_not_implemented_as_horary_timing_analysis():
    core = read(ROOT / "ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift")
    election = ROOT / "ios/Packages/AstroCore/Sources/AstroCore/ElectionalCore.swift"
    assert election.exists()
    source = read(election)
    assert "struct ElectionalAssessment" in source
    assert "struct ElectionalAssessmentEngine" in source
    assert "HoraryEngine.timingAnalysis" not in source
    assert "public struct ElectionTimingEngine" in source
    assert "public struct ElectionTimingEngine" not in core
