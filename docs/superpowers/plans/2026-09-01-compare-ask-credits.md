# Compare + Ask Deep Analysis + Credits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the four-mode Compare product, make Ask's deterministic analysis free with a paid 1-credit Deep Analysis layer, update onboarding/navigation, and align client-facing credit policy to 5 first-period / 2 free-monthly / 15 Pro-monthly without inventing Relay-side ledger behavior.

**Architecture:** Reuse AstroCore calculation services and app Profile/Bond/ChartRenderer/Commerce systems. Add a stable deterministic fact identity and pure Diff engine in AstroCore, then an app-level Compare orchestration/UI/AI contract that maps existing chart artifacts into those facts. AI only receives deterministic facts/diffs; local calculations remain authoritative. Credits reuse existing report reservation/ack semantics; Relay grant amounts remain server-owned and are represented client-side only as product policy/copy until Relay is separately updated.

**Tech Stack:** Swift 6, SwiftUI, AstroCore SwiftPM, XcodeGen project.yml, existing CommerceRelay/App Attest pipeline, JSON localization catalog.

**Spec:** `/mnt/data/Interstellar_Compare_开发规格_v1.0.md`

## Global Constraints

- All astrology calculations are local and deterministic.
- No wheel screenshots, exact coordinates, timezone IDs, or unnecessary birth profile data go to AI.
- Compare and Ask AI responses are strict JSON, never regex-extracted Markdown.
- Evidence IDs must resolve to provided facts; all-invalid evidence invalidates the response.
- Compare costs 1 Credit and uses existing reservation/ack/refund semantics; Evidence/View Charts cost 0.
- Ask base analysis is free; Deep Analysis costs 1 Credit.
- First free period product copy: 5 Credits total, not 5+2; later free months: 2/month; Pro: 15/month. Relay remains ledger source of truth.
- Compare final primary IA: Ask / Themes / Compare / Charts / Profile.
- Onboarding completion lands on Charts.
- Missing calculation capabilities must be implemented properly in the established core; no placeholders or AI-computed substitutes.
- All new UI strings enter the existing localization pipeline and wrap without horizontal overflow.

---

### Task 1: Stable Fact Identity and Diff Core

**Files:**
- Create: `ios/Packages/AstroCore/Sources/AstroCore/CompareCore.swift`
- Create: `ios/Packages/AstroCore/Tests/AstroCoreTests/CompareCoreTests.swift`
- Modify: `ios/App/ThemesFeature.swift`

**Interfaces:**
- Produces `DeterministicFactIdentity`, `CompareFactState`, `CompareFact`, `CompareFactChange`, `CompareDiff`, `CompareDiffEngine`.
- Themes activation fact IDs use `DeterministicFactIdentity.key` and keep sampling time as state only.

- [ ] RED tests for stable IDs and Added/Removed/Strengthened/Weakened/Structural/Stable.
- [ ] Verify RED with `swift test --package-path ios/Packages/AstroCore`.
- [ ] Implement minimal Compare core.
- [ ] Switch Themes activation IDs to stable identity.
- [ ] Verify GREEN and all AstroCore tests.
- [ ] Commit and emit checkpoint archive/patch.

### Task 2: Compare App Models, Validation, Evidence and Cache

**Files:**
- Create: `ios/App/CompareModels.swift`
- Create: `ios/App/CompareCache.swift`
- Create: `ios/Tests/CompareContractTests.swift`

**Interfaces:**
- Produces `CompareType`, `CompareRequest`, `CompareFocus`, `CompareCalculationBundle`, `CompareAIRequest`, `CompareAIResponse`, `CompareResponseValidator`, `CompareCacheStore`.

- [ ] RED tests for same-date/place/person validation, focus max 3, AI schema and evidence rejection.
- [ ] Implement models/validation/cache/strict decoder.
- [ ] Verify tests where executable; run source contract tests on Linux for app-only Swift contracts.

### Task 3: Compare Deterministic Calculation Coordinator

**Files:**
- Create: `ios/App/CompareCalculationCoordinator.swift`
- Create: `ios/App/CompareFactBuilder.swift`

**Interfaces:**
- Reuses `AppChartCalculationService`, `AppAdvancedChartCalculationService`, `AppRelationshipChartCalculationService`.
- Supports Me Over Time: Natal + Transit + Secondary + Solar Arc.
- Supports Two People: Natal A/B + Synastry.
- Supports Two Places: Natal + Relocation A/B.
- Supports Relationship Over Time: Synastry + Composite + Composite Transit A/B + Composite Secondary Compare A/B.

- [ ] Build deterministic facts from snapshots/aspects/angles/houses/motion.
- [ ] Ensure no raw coordinates/profile fields appear in AI payload DTO.
- [ ] Add deterministic source contract tests for technique coverage and privacy keys.

### Task 4: Compare AI + Billing Pipeline

**Files:**
- Create: `ios/App/CompareAIService.swift`
- Modify: `ios/App/Commerce.swift` only to generalize acknowledgement helpers if needed; no second ledger.

**Interfaces:**
- Uses existing Relay base URL/App Attest/auth transport and report reservation semantics.
- Endpoint contract isolated so Relay can be implemented/tested separately.

- [ ] Strict request/response DTOs with evidence validation.
- [ ] 1-credit analyze flow, retry without duplicate final charge, local calc retained on AI failure.
- [ ] Cache successful request/facts/diff/result/chart models.

### Task 5: Compare UI and Navigation

**Files:**
- Create: `ios/App/CompareView.swift`
- Modify: `ios/App/RootView.swift`
- Modify: `ios/App/ChartsView.swift` only where chart deep links need reuse.

**Interfaces:**
- Home contains exactly four fixed cards.
- Unified Input → Focus → Review → Analyze → Result flow.
- Evidence bottom sheet and View Charts use cached local artifacts.

- [ ] Implement all four modes with existing Profile/Location components.
- [ ] Loading stages: Calculating charts / Comparing changes / Preparing analysis.
- [ ] Final IA Ask / Themes / Compare / Charts / Profile.
- [ ] Onboarding completion selects Charts.

### Task 6: Ask Free Base + Deep Analysis

**Files:**
- Create: `ios/App/AskDeepAnalysis.swift`
- Modify: `ios/App/SynastryView.swift`
- Modify: `ios/App/AskHistory.swift` only if cached deep-analysis persistence is needed.

**Interfaces:**
- `AskDeepAnalysisPayloadBuilder` transforms `HorarySession` into privacy-minimized deterministic facts.
- Deep Analysis button costs 1 Credit; base deterministic result never checks Credits.

- [ ] Remove one-credit/limited-free badge from Ask home.
- [ ] Add Deep Analysis result action and strict result view.
- [ ] Payload includes mode/question, significators/houses, planetary condition, receptions, relationship aspect, perfection/interruption, Moon next aspect/VOC, choices/timing candidates and deterministic scores where present.
- [ ] Exclude exact coordinates/timezone/birth profile/wheel.
- [ ] AI failure preserves local Ask result and supports no-duplicate-charge retry.

### Task 7: Credit Policy Copy and Localization

**Files:**
- Modify: `ios/App/OnboardingView.swift` if needed.
- Modify: `ios/Localization/UI/commerce-onboarding.json`
- Modify: `ios/Localization/UI/today-ask.json`
- Create/Modify: `ios/Localization/UI/compare.json`
- Modify: `ios/project.yml` localization validation inputs.
- Regenerate/validate `ios/App/Localizable.xcstrings` using existing scripts.

**Interfaces:**
- Client policy constants: first free period 5, recurring free 2, Pro 15; server account remains authoritative.

- [ ] Update all shipping languages EN/FR/ES/DE/IT/PT-BR/TR/KO using concise UI-safe wording.
- [ ] Keep zh-Hans catalog structurally valid if present but do not expand product scope.
- [ ] Ensure no stale “Ask limited free” or “10 Pro Credits” copy remains.

### Task 8: Project Generation, Regression Verification and Delivery

**Files:**
- Regenerate `ios/Interstellar.xcodeproj` with XcodeGen if available; otherwise update generated project deterministically using project.yml workflow.
- Update tests/contracts as required.

- [ ] Run `swift test --package-path ios/Packages/AstroCore`.
- [ ] Run root Python contract tests.
- [ ] Run localization validation/build scripts.
- [ ] Run `xcodegen`/project consistency checks available on Linux.
- [ ] Search for privacy regressions, placeholders, stale limited-free and stale credit copy.
- [ ] Produce final diff, modified-file manifest, SHA-256 and complete ZIP.
