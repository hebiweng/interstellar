# Phase R5 History and Results Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Phase R5 AI availability, durable in-flight history, Compare result truthfulness, A/B chart navigation, date highlighting, evidence timing, and inline Theme charts.

**Architecture:** Preserve per-feature stores and move view-owned AI work to feature managers. Add pure deterministic Compare selection/grouping helpers and render persisted status consistently. Deploy only the Relay after local verification.

**Tech Stack:** Swift 6, SwiftUI, AstroCore, Python contract tests, Go Relay, SQLite, Docker.

**Spec:** `docs/superpowers/specs/2026-09-01-phase-r5-history-and-results-fixes-design.md`

## Global Constraints

- ZIP Phase R5 remains the product baseline.
- Display code may rank/filter existing facts but may not calculate astrology.
- Atomic local save precedes ACK.
- Production deployment backs up the Relay database and does not rebuild Edge/Caddy.
- No automatic paid AI smoke request.

---

### Task 1: Compare primary result selection

**Files:**
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/CompareCore.swift`
- Modify: `ios/Packages/AstroCore/Tests/AstroCoreTests/CompareCoreTests.swift`
- Modify: `ios/App/CompareView.swift`
- Modify: `ios/Localization/UI/compare.json`

**Interfaces:**
- Produces: `ComparePrimaryResultSelector.changes(from:limit:)` and `comparisons(from:limit:)`.

- [ ] Add tests with literal fixtures proving an input of more than eight changes returns the expected eight in deterministic priority order and Two People returns relationship facts rather than an empty result.
- [ ] Run the focused AstroCore test and confirm it fails because the selector does not exist.
- [ ] Implement the pure selector without new astrology calculations.
- [ ] Render `Primary Changes` / `Primary Comparisons` using only selected results and the selected count.
- [ ] Run focused and full AstroCore tests.

### Task 2: Compare evidence, date preset, history, and A/B charts

**Files:**
- Modify: `ios/App/CompareAnalysisStore.swift`
- Modify: `ios/App/CompareAnalysisManager.swift`
- Modify: `ios/App/CompareView.swift`
- Modify: `ios/Localization/UI/compare.json`
- Modify: `tests/test_compare_persistence_contract.py`
- Modify: `tests/test_compare_manager_contract.py`
- Modify: `tests/test_compare_source_contract.py`

**Interfaces:**
- Produces: all-status recent history, manager-owned report tasks, identifiable evidence selection, and shared/A/B chart groups.

- [ ] Add failing contract tests for all-status history, manager-owned tasks, item-based evidence, preset-safe picker binding, and segmented A/B chart rendering.
- [ ] Run the focused Python tests and confirm expected failures.
- [ ] Implement all-status bounded history and status rows.
- [ ] Move report generation into manager-owned tasks while retaining retry and save-before-ACK.
- [ ] Replace evidence Boolean/ID state with one identifiable selection.
- [ ] Replace the unconditional date `onChange` with a DatePicker-specific Binding.
- [ ] Classify cached charts and render shared charts once plus A/B segmented content.
- [ ] Run focused Python contracts and signed simulator build.

### Task 3: Durable Ask Deep Analysis history

**Files:**
- Modify: `ios/App/AskDeepAnalysis.swift`
- Modify: `ios/App/Ask/AskHomeView.swift`
- Modify: `ios/App/Ask/AskHistoryView.swift`
- Modify: `ios/App/Ask/AskView.swift`
- Modify: `ios/Localization/UI/today-ask.json`
- Modify: `tests/test_ask_ui_contract.py`
- Modify: `tests/test_compare_source_contract.py`

**Interfaces:**
- Produces: observable `AskDeepAnalysisStore`, manager-owned Deep tasks, and session-fingerprint status lookup.

- [ ] Add failing contracts for an observable Deep store, manager-owned task registry, history status rendering, and save-before-ACK.
- [ ] Run focused Ask contracts and confirm expected failures.
- [ ] Implement the manager and store publication.
- [ ] Update the result section to request through the manager and observe the record.
- [ ] Show analyzing/completed/retry status in recent and full Ask history using the existing session fingerprint.
- [ ] Run focused Ask contracts and simulator build.

### Task 4: Theme history status and inline chart

**Files:**
- Modify: `ios/App/ThemesFeature.swift`
- Modify: `ios/Localization/UI/themes.json`
- Modify: `tests/test_themes_ui_localization_contract.py`

**Interfaces:**
- Produces: visible history state and inline selected wheel with retained detail navigation.

- [ ] Replace the old detail-only contract with failing tests for inline wheel, retained detail navigation, and history status.
- [ ] Run the focused Theme test and confirm expected failure.
- [ ] Render status in `ThemeHistorySection`.
- [ ] Render the selected `ChartWheelView` inside `ThemeChartSelector`, then retain View Chart Details.
- [ ] Run focused Theme contracts and simulator build.

### Task 5: Relay verification and deployment

**Files:**
- Verify: `relay/handlers.go`, `relay/prompts.go`, `relay/phase_r5_generation.go`, `relay/commerce.go`
- Modify: `docs/agent-handoff.md`

**Interfaces:**
- Production accepts four `compare.*` scopes and `ask.deep_analysis` with strict evidence-bound schemas.

- [ ] Run Relay full tests and `go vet`.
- [ ] Build the `linux/amd64` Relay image locally.
- [ ] Read current production health/image and create a timestamped SQLite backup using the established backup workflow.
- [ ] Transfer and load the image, update only Relay, and verify database integrity, container health, public health, prompt scopes, and unchanged Edge/Caddy.
- [ ] Do not initiate a paid report.

### Task 6: Final verification and device install

**Files:**
- Modify: `docs/agent-handoff.md`

- [ ] Run AstroCore, ContentKit, Relay, focused Phase R5 Python contracts, card/private-content/copy/localization/architecture/lint gates, and `git diff --check`.
- [ ] Build a signed Release iPhoneOS app with production App Attest.
- [ ] Cover-install on `HUAWEI PURA 70` without uninstalling and launch it.
- [ ] Confirm the installed version and running process; record evidence and any unverified paid flows in handoff.
