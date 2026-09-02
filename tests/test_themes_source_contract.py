from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "ios/App/ThemesFeature.swift"
ROOT_VIEW = ROOT / "ios/App/RootView.swift"


def source():
    assert THEMES.exists(), "ThemesFeature.swift has not been created"
    return THEMES.read_text()


def test_exact_eight_theme_catalog_and_shared_horizons():
    s = source()
    for case in [
        "loveRelationships", "careerPurpose", "moneyGrowth", "familyHome",
        "selfWellbeing", "creativityExpression", "learningExploration", "lifeDirection",
    ]:
        assert f"case {case}" in s
    assert "case now" in s
    assert "case threeMonths" in s
    assert "case sixMonths" in s
    assert "case oneYear" in s


def test_planner_encodes_relationship_and_family_recipe_boundaries():
    s = source()
    assert "ThemePlanner" in s
    assert "RelationshipChartKind.synastryA" in s
    assert "RelationshipChartKind.synastryB" in s
    assert "RelationshipChartKind.composite" in s
    assert "RelationshipChartKind.compositeTransit" in s
    assert "RelationshipChartKind.compositeSecondaryCompare" in s
    assert "RelationshipChartKind.compositeTertiaryCompare" in s
    assert "maxFamilyMembers = 3" in s
    assert "includeInAIFacts: false" in s, "dependency artifacts must be able to stay out of AI facts"
    assert "memberRelationship" in s


def test_theme_payload_separates_context_evidence_and_omits_raw_birth_fields():
    s = source()
    assert "struct ThemeAIPayload" in s
    assert "let analysis:" in s
    assert "let people:" in s
    assert "let userContext:" in s
    assert "let evidence:" in s
    assert "let requestedOutput:" in s
    payload_section = s[s.index("struct ThemeAIPayload"):s.index("struct ThemeReportResponse")]
    for forbidden in ["birthDateUTC", "latitude", "longitude", "timezoneID"]:
        assert forbidden not in payload_section
    assert "mergedSynastry" in s
    assert "ThemeEvidenceSelector" in s


def test_theme_relay_contract_is_idempotent_and_two_credit_server_contract():
    s = source()
    assert '"mode": "theme"' in s
    assert '"semanticFingerprint": semanticFingerprint' in s
    assert '"factsHash": factsHash' in s
    assert '"generationSchemaVersion":' in s
    assert "GeneratedChartArtifact.schemaVersion" in s
    assert '"creditCost"' not in s, "the Relay derives the two-credit cost from the trusted theme scope"
    assert "store.upsert(completed)" in s
    assert "acknowledgeReport(requestID: delivery.requestID)" in s
    assert s.index("store.upsert(completed)") < s.index("acknowledgeReport(requestID: delivery.requestID)")
    assert 'path: "v1/generate"' in s


def test_theme_facts_are_merged_once_bounded_and_raw_context_is_not_sent():
    s = source()
    assert "flattenedEvidenceFacts" in s
    assert "limit: 112" in s
    assert s.count("limit: 64") >= 2
    assert '"evidenceFacts": evidenceFacts' in s
    assert "userContext: nil" in s
    assert '"payload"' not in s[s.index("private func requestBody"):s.index("private func validate", s.index("private func requestBody"))]


def test_themes_are_a_root_tab_and_have_recent_analyses_and_single_wheel_result():
    rv = ROOT_VIEW.read_text()
    s = source()
    assert "case themes" in rv
    assert ".tag(RootTab.themes)" in rv
    assert "ThemesView" in rv
    assert "ThemeHistorySection" in s
    assert "Recent" in s or "themes.recent" in s
    assert "ChartWheelView(" in s
    assert "Analyze · 2 Credits" not in s, "UI copy must be localized, not hard-coded"
    assert 'localized("themes.analyze"' in s


def test_relationship_now_uses_short_term_09_without_secondary_08():
    s = source()
    start = s.index("private func relationshipRecipe")
    end = s.index("private func chartTask", start)
    planner = s[start:end]
    # 08 is only scheduled for horizons beyond Now; 09 is allowed for Now/3M.
    secondary_guard = planner.index("if input.horizon != .now")
    secondary = planner.index("RelationshipChartKind.compositeSecondaryCompare", secondary_guard)
    tertiary_guard = planner.index("if input.horizon == .now || input.horizon == .threeMonths")
    assert secondary_guard < secondary < tertiary_guard
    assert "} else {" not in planner[secondary_guard:tertiary_guard]


def test_one_year_return_uses_period_end_as_target():
    s = source()
    marker = "kind: .solarReturn" if "kind: .solarReturn" in s else ".solarReturn,"
    idx = s.index(marker)
    window = s[idx:idx + 350]
    assert "targetDate: input.period.end" in window


def test_theme_credit_preflight_does_not_block_before_account_sync():
    s = source()
    assert "commerce.account != nil && commerce.totalCredits < 2" in s


def test_money_selector_does_not_promote_pluto_just_because_theme_says_growth():
    s = source()
    start = s.index("case .moneyGrowth:", s.index("private func selectedBodies"))
    end = s.index("case .familyHome:", start)
    money = s[start:end]
    assert '"venus"' in money and '"jupiter"' in money and '"saturn"' in money
    assert '"pluto"' not in money


def test_family_member_section_ids_reuse_member_refs_without_double_prefix():
    s = source()
    assert 'sections += input.familyMembers.map(\\.ref)' in s
    assert '"member_\\($0.ref)"' not in s


def test_foundation_artifacts_are_always_normalized_as_structure_not_activation():
    s = source()
    start = s.index("private func normalizedGroup")
    end = s.index("private func structuralFacts", start)
    block = s[start:end]
    assert "if artifact.task.evidenceRole == .foundation {" in block
    foundation = block[block.index("if artifact.task.evidenceRole == .foundation {"):]
    assert "facts += structuralFacts" in foundation
    first_else = foundation.index("} else {")
    assert "activationFacts" not in foundation[:first_else]


def test_analysis_context_uses_explicit_snake_case_theme_fields_not_metadata_envelope():
    s = source()
    start = s.index("struct ThemeAIAnalysisContext")
    end = s.index("struct ThemeAIPerson", start)
    block = s[start:end]
    for field in ["relationshipType", "relationshipStatus", "careerStage", "focus"]:
        assert f"let {field}: String?" in block
    for wire_key in ["relationship_type", "relationship_status", "career_stage"]:
        assert f'"{wire_key}"' in block
    assert "let metadata:" not in block


def test_theme_report_service_is_main_actor_isolated_for_commerce_identity_access():
    s = source()
    assert "@MainActor\nstruct ThemeReportService: Sendable" in s


def test_theme_facts_builder_has_no_unused_formatter_state():
    s = source()
    start = s.index("struct ThemeFactsBuilder")
    end = s.index("// MARK: - Persistence and Relay", start)
    block = s[start:end]
    assert "ISO8601DateFormatter" not in block


def test_theme_history_is_cleared_with_reports_and_account_deletion():
    app_model = (ROOT / "ios/App/AppModel.swift").read_text()
    clear_reports = app_model[app_model.index("func clearReports()"):app_model.index("func clearAskHistory()")]
    deletion = app_model[app_model.index("func erasePersonalDataForAccountDeletion()"):]
    assert "ThemeAnalysisStore.shared.clearAll()" in clear_reports
    assert "ThemeAnalysisStore.shared.clearAll()" in deletion


def test_interrupted_theme_generation_stays_pending_and_resumes_with_same_request():
    s = source()
    load_start = s.index("private func load()")
    load_end = s.index("private func persist()", load_start)
    load = s[load_start:load_end]
    assert "decoded[index].status = .chartsReady" not in load
    assert "decoded[index].status = .reportFailed" not in load
    assert "func resumePendingReport(" in s
    resume_start = s.index("func resumePendingReport(")
    resume_end = s.index("private func beginReportGeneration", resume_start)
    resume = s[resume_start:resume_end]
    assert "reportService.recover(" in resume
    assert "reportService.generate(" not in resume
    resume_cancel_start = resume.index("catch is CancellationError")
    resume_cancel_end = resume.index("} catch is URLError", resume_cancel_start)
    resume_cancel = resume[resume_cancel_start:resume_cancel_end]
    assert "status = .chartsReady" not in resume_cancel
    assert "status = .reportFailed" not in resume_cancel

    generation = s[resume_end:]
    cancel_start = generation.index("catch is CancellationError")
    cancel_end = generation.index("} catch is URLError", cancel_start)
    cancel = generation[cancel_start:cancel_end]
    assert "current.status = .generatingReport" in cancel
    assert "current.status = .reportFailed" not in cancel
    result_start = s.index("struct ThemeResultView")
    result = s[result_start:]
    assert "@Environment(\\.scenePhase) private var scenePhase" in result
    assert ".onChange(of: scenePhase)" in result
    assert "ThemeAnalysisManager.shared.resumePendingReport" in result


def test_theme_ai_period_dates_are_formatted_in_selected_location_timezone():
    s = source()
    build_start = s.index("func build(", s.index("struct ThemeFactsBuilder"))
    build_end = s.index("private func buildEvidence", build_start)
    build = s[build_start:build_end]
    assert "let analysisTimeZone = TimeZone(identifier: input.location.timezoneID)" in build
    assert "dayString(input.analysisDate, timeZone: analysisTimeZone)" in build
    assert "dayString(period.start, timeZone: analysisTimeZone)" in build
    assert "dayString(period.end, timeZone: analysisTimeZone)" in build


def test_activation_fact_identity_is_stable_across_sample_times():
    s = source()
    start = s.index("private func activationFacts")
    end = s.index("/// Merges 02/03", start)
    block = s[start:end]
    assert "DeterministicFactIdentity(" in block
    assert "frame.sampledAt.timeIntervalSince1970" not in block
    assert "sampledAt: dayString(frame.sampledAt)" in block
