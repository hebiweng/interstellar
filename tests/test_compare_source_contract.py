from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "ios/App/CompareModels.swift"
FACTS = ROOT / "ios/App/CompareFactBuilder.swift"
COORDINATOR = ROOT / "ios/App/CompareCalculationCoordinator.swift"
AI = ROOT / "ios/App/CompareAIService.swift"
MANAGER = ROOT / "ios/App/CompareAnalysisManager.swift"
VIEW = ROOT / "ios/App/CompareView.swift"
ROOT_VIEW = ROOT / "ios/App/RootView.swift"


def read(path: Path) -> str:
    assert path.exists(), f"missing {path.name}"
    return path.read_text()


def test_compare_models_match_four_mode_contract_and_reuse_core_validator():
    s = read(MODELS)
    assert "struct CompareRequest" in s
    assert "CompareType" in s
    assert "CompareValidator.validate" in s
    for token in ["subjectA", "subjectB", "dateA", "dateB", "placeA", "placeB", "relationshipContext", "focus"]:
        assert f"let {token}" in s
    assert "maximumSelectionCount" in s


def test_compare_ai_payload_has_no_raw_profile_location_or_birth_fields():
    s = read(MODELS)
    start = s.index("struct CompareAIRequest")
    end = s.index("struct CompareCalculationBundle", start) if "struct CompareCalculationBundle" in s[start:] else len(s)
    block = s[start:end]
    for forbidden in ["UserProfile", "latitude", "longitude", "timezoneID", "birthDateUTC", "avatarData"]:
        assert forbidden not in block
    for required in ["compareType", "focus", "facts", "diff", "labels"]:
        assert f"let {required}" in block


def test_fact_builder_uses_stable_core_identity_and_keeps_house_sign_motion_as_state():
    s = read(FACTS)
    assert "DeterministicFactIdentity(" in s
    assert "CompareFactState(" in s
    assert "house:" in s
    assert "sign:" in s
    assert "motion:" in s
    assert "timeIntervalSince1970" not in s


def test_coordinator_implements_all_four_real_calculation_recipes():
    s = read(COORDINATOR)
    for token in ["case .meOverTime", "case .twoPeople", "case .twoPlaces", "case .relationshipOverTime"]:
        assert token in s
    for token in [".natal", ".transit", ".secondary", ".solarArc", ".relocation"]:
        assert token in s
    for token in [".synastryA", ".composite", ".compositeTransit", ".compositeSecondaryCompare"]:
        assert token in s
    assert "AppChartCalculationService" in s
    assert "AppAdvancedChartCalculationService" in s
    assert "AppRelationshipChartCalculationService" in s


def test_compare_relay_uses_existing_generate_status_fetch_ack_flow():
    s = read(AI)
    assert '"mode": "compare"' in s
    assert 'appendingPathComponent("v1/generate")' in s
    assert '"v1/reports/status"' in s
    assert '"v1/reports/fetch"' in s
    manager = read(MANAGER)
    assert "acknowledgeReport(requestID:" in manager
    assert manager.index("store.upsert(current)") < manager.index("acknowledgeReport(requestID:")
    assert '"creditCost"' not in s, "Relay must derive trusted cost; client must not create a second ledger"


def test_compare_home_has_exactly_four_entry_types_and_final_five_tab_ia():
    s = read(VIEW)
    for identifier in [
        "compare-card-me-over-time",
        "compare-card-two-people",
        "compare-card-two-places",
        "compare-card-relationship-over-time",
    ]:
        assert s.count(identifier) == 1
    rv = read(ROOT_VIEW)
    for tab in ["case ask", "case themes", "case compare", "case charts", "case profile"]:
        assert tab in rv
    assert "case today" not in rv
    assert rv.index("AskView()") < rv.index("ThemesView()") < rv.index("CompareView()") < rv.index("ChartsView(") < rv.index("ProfileView(")


def test_two_people_relationship_facts_include_both_house_overlays_and_angle_aspects():
    s = read(FACTS)
    assert 'factType: "house_overlay"' in s
    assert 'factType: "angle_aspect"' in s
    assert "artifact.reference" in s
    c = read(COORDINATOR)
    assert "kind: .synastryA" in c
    assert "kind: .synastryB" in c


def test_onboarding_initial_profile_setup_finishes_on_charts_not_profile():
    rv = read(ROOT_VIEW)
    assert "onInitialSetupComplete" in rv
    assert "selection = .charts" in rv
    assert "selection = .profile" in rv, "profile tab may host the required first-run editor before completion"


def test_compare_sources_and_localization_are_registered_in_checked_in_xcode_project():
    project_yml = read(ROOT / "ios/project.yml")
    pbx = read(ROOT / "ios/Interstellar.xcodeproj/project.pbxproj")
    assert "$(SRCROOT)/Localization/UI/compare.json" in project_yml
    for filename in [
        "CompareModels.swift",
        "CompareFactBuilder.swift",
        "CompareCalculationCoordinator.swift",
        "CompareAIService.swift",
        "CompareAnalysisStore.swift",
        "CompareAnalysisManager.swift",
        "CompareView.swift",
    ]:
        assert filename in pbx
        assert f"{filename} in Sources" in pbx


def test_onboarding_and_storekit_describe_new_credit_policy_and_final_features():
    import json
    onboarding = read(ROOT / "ios/App/OnboardingView.swift")
    assert 'featureRow("sparkle.magnifyingglass", "onboarding.ask")' in onboarding
    assert 'featureRow("square.grid.2x2", "onboarding.themes")' in onboarding
    assert 'featureRow("arrow.left.arrow.right", "onboarding.compare")' in onboarding
    assert 'featureRow("circle.hexagongrid", "onboarding.charts")' in onboarding
    assert 'featureRow("person.crop.circle", "onboarding.profile")' in onboarding
    assert '"onboarding.today"' not in onboarding

    copy = json.loads(read(ROOT / "ios/Localization/UI/commerce-onboarding.json"))
    assert copy["onboarding.free-credits"]["en"] == "5 Credits in your first Free month; 2 Credits each month after"
    assert copy["onboarding.premium-credits"]["en"] == "15 Pro Credits each month"
    assert "15 Pro Credits" in copy["premium.pro-description"]["en"]
    assert "10 extra Pro Credits" not in read(ROOT / "ios/App/Interstellar.storekit")

ASK_DEEP = ROOT / "ios/App/AskDeepAnalysis.swift"
ASK_VIEW = ROOT / "ios/App/Ask/AskView.swift"
ASK_RESULT_VIEW = ROOT / "ios/App/Ask/AskResultView.swift"


def test_ask_base_is_free_and_result_offers_one_credit_deep_analysis():
    s = read(ASK_VIEW) + read(ASK_RESULT_VIEW)
    assert 'ask.limited-free' not in s
    assert 'credits.one-credit' not in s
    assert 'AskDeepAnalysisSection(session: session)' in s
    deep = read(ASK_DEEP)
    assert 'ask.deep-analysis-credit' in deep
    assert 'commerce.totalCredits >= 1' in deep


def test_ask_deep_payload_is_structured_deterministic_and_privacy_minimized():
    s = read(ASK_DEEP)
    for required in [
        'HoraryPerfectionAssessment', 'receptionFromQuerent', 'receptionFromTarget',
        'isVoidOfCourse', 'nextAspect', 'timingCandidates', 'significators',
        'evidenceFactIDs', 'DeterministicFactIdentity(',
    ]:
        assert required in s
    payload_start = s.index('struct AskDeepAIRequest')
    payload_end = s.index('struct AskDeepNarrativeSection', payload_start)
    payload = s[payload_start:payload_end]
    for forbidden in ['ChartSnapshot', 'UserProfile', 'latitude', 'longitude', 'timezoneID', 'locationName', 'avatarData']:
        assert forbidden not in payload


def test_ask_deep_uses_existing_relay_reservation_and_ack_flow():
    s = read(ASK_DEEP)
    assert '"mode": "ask_deep"' in s
    assert 'appendingPathComponent("v1/generate")' in s
    assert '"v1/reports/status"' in s
    assert '"v1/reports/fetch"' in s
    assert 'acknowledgeReport(requestID:' in s
    assert '"creditCost"' not in s
    assert 'let requestID = record.id' in s, 'retry must reuse the same idempotency/reservation key'
    assert s.index('guard store.upsert(record)') < s.index('acknowledgeReport(requestID:')


def test_ask_deep_source_and_localization_fragment_are_registered():
    pbx = read(ROOT / "ios/Interstellar.xcodeproj/project.pbxproj")
    assert "AskDeepAnalysis.swift" in pbx
    assert "AskDeepAnalysis.swift in Sources" in pbx


def test_two_people_uses_relationship_comparison_not_time_diff_semantics():
    s = read(COORDINATOR)
    start = s.index("private func calculateTwoPeople")
    end = s.index("private func calculateTwoPlaces", start)
    block = s[start:end]
    assert "diff: CompareDiff()" in block
    assert "CompareDiffEngine.diff(from: factsA, to: factsB)" not in block


def test_compare_ai_payload_reducer_omits_bulk_stable_diff_and_validates_only_sent_facts():
    models = read(MODELS)
    ai = read(AI)
    assert "enum CompareAIPayloadReducer" in models
    assert "stable: []" in models
    assert "let validFactIDs: Set<String>" in ai
    assert "validFactIDs: identity.validFactIDs" in ai
    assert "validFactIDs: bundle.validFactIDs" not in ai
    assert "estimatedTokenCount" in ai
    assert "outboundFactCount" in ai


def test_compare_manager_exposes_truthful_three_stage_progress_without_percentage():
    manager = read(ROOT / "ios/App/CompareAnalysisManager.swift")
    coordinator = read(COORDINATOR)
    view = read(VIEW)
    for token in ["calculatingCharts", "comparingChanges", "preparingAnalysis"]:
        assert token in manager or token in coordinator
    assert "onStage" in coordinator
    assert "manager.stage" in view
    assert "compare.stage." in view
    assert "progressPercent" not in manager
    assert "progressPercent" not in view


def test_two_places_keeps_real_a_b_location_diff():
    s = read(COORDINATOR)
    start = s.index("private func calculateTwoPlaces")
    end = s.index("private func calculateRelationshipOverTime", start)
    block = s[start:end]
    assert "CompareDiffEngine.diff(from: factsA, to: factsB)" in block


def test_relationship_over_time_keeps_real_a_b_dynamic_diff():
    s = read(COORDINATOR)
    start = s.index("private func calculateRelationshipOverTime")
    end = s.index("private func timeSnapshot", start)
    block = s[start:end]
    assert "CompareDiffEngine.diff(from: factsA, to: factsB)" in block


def test_client_credit_policy_constants_match_product_rules_without_overriding_server_balance():
    commerce = read(ROOT / "ios/App/Commerce.swift")
    assert "enum CreditPolicy" in commerce
    assert "static let firstFreePeriodCredits = 5" in commerce
    assert "static let recurringFreeMonthlyCredits = 2" in commerce
    assert "static let proMonthlyCredits = 15" in commerce
    assert "var totalCredits: Int { account?.credits.availableTotal ?? 0 }" in commerce


def test_ask_deep_state_is_published_by_the_durable_store():
    s = read(ASK_DEEP)
    assert "record = current" not in s
    assert "@Published private(set) var records" in s
    assert "@ObservedObject private var store" in s


def test_two_people_natal_fact_ids_are_scoped_per_person_for_unambiguous_evidence():
    facts = read(FACTS)
    coordinator = read(COORDINATOR)
    assert "identityScope: String? = nil" in facts
    assert 'identityScope: "person_a"' in coordinator
    assert 'identityScope: "person_b"' in coordinator


def test_compare_user_visible_failures_are_localized_not_raw_internal_errors():
    view = read(VIEW)
    assert 'localized("compare.error.calculation-failed"' in view
    assert 'localized("compare.error.ai-failed"' in view
    assert 'return error.localizedDescription' not in view
    assert 'retryError = error.localizedDescription' not in view


def test_compare_home_uses_ab_hero_and_asymmetric_card_hierarchy():
    source = read(VIEW)
    for token in [
        'CompareHeroGraphic()',
        'localized("compare.hero.question"',
        'localized("compare.hero.categories"',
        'comparePrimaryCard(.meOverTime)',
        'compareCompactCard(.twoPeople)',
        'compareCompactCard(.twoPlaces)',
        'compareRelationshipCard()',
        'accessibilityIdentifier("compare-card-me-over-time")',
        'accessibilityIdentifier("compare-card-two-people")',
        'accessibilityIdentifier("compare-card-two-places")',
        'accessibilityIdentifier("compare-card-relationship-over-time")',
    ]:
        assert token in source, token
    assert 'ForEach(CompareType.allCases' not in source


def test_compare_home_visuals_do_not_use_fake_people_or_city_examples():
    source = read(VIEW)
    home = source[:source.index("private enum CompareNewPersonTarget")]
    for fake in ["Tokyo", "London", "Alex", "3 months ago"]:
        assert fake not in home


def test_compare_home_copy_uses_readable_text_sizes_without_tiny_card_descriptions():
    s = read(VIEW)
    compact = s[s.index("private func compareCompactCard"):s.index("private func compareRelationshipCard")]
    assert ".font(.subheadline)" in compact
    assert ".font(.footnote)" not in compact
    hero = s[s.index("struct CompareView"):s.index("private func comparePrimaryCard")]
    assert '.font(.subheadline.weight(.semibold))' in hero
    assert '.font(.caption.weight(.semibold))' not in hero


def test_compare_hero_uses_native_ab_motion_and_cards_have_press_feedback():
    source = read(VIEW)
    hero = source[source.index("private struct CompareHeroGraphic"):source.index("private struct CompareOrbitalNode")]
    assert "TimelineView(.animation" in hero
    assert "accessibilityReduceMotion" in hero
    assert "dashPhase" in hero
    assert "CompareCardPressStyle" in source
    assert "Lottie" not in hero


def test_compare_results_use_primary_selection_immediate_evidence_and_chart_tabs():
    source = read(VIEW)
    assert "ComparePrimaryResultSelector.changes" in source
    assert "ComparePrimaryResultSelector.comparisons" in source
    assert 'localized("compare.primary-changes"' in source
    assert 'localized("compare.primary-comparisons"' in source
    assert ".sheet(item: $evidenceSelection)" in source
    assert 'accessibilityIdentifier("compare-chart-side-picker")' in source
    assert "datePreset = .custom" in source


def test_compare_report_generation_is_manager_owned_and_history_includes_pending_jobs():
    manager = read(ROOT / "ios/App/CompareAnalysisManager.swift")
    view = read(VIEW)
    assert "private var reportTasks" in manager
    assert "func beginReportGeneration" in manager
    assert "func reconcilePendingReports" in manager
    assert "store.recentAnalyses" in view
    assert "manager.beginReportGeneration(analysisID: local.id" in view
