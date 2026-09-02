# Ask Horary Core Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ask When's future-chart scoring with deterministic horary timing and enrich the shared horary evidence model used by Yes/No, A/B/C and Deep Analysis.

**Architecture:** Keep one deterministic AstroCore horary domain. Add a dedicated timing engine and richer fact models while preserving legacy Codable history. App code consumes new results first and retains legacy election candidates only as migration fallback.

**Tech Stack:** Swift 6, Swift Testing, Swiss Ephemeris, SwiftUI app integration, Python source-contract tests.

**Spec:** `docs/superpowers/specs/2026-09-01-ask-horary-core-upgrade-design.md`

## Global Constraints
- No AI-side astrology calculation.
- No fabricated timing precision.
- Existing Ask history must decode.
- `ElectionTimingEngine` remains available but new Ask When must not call it.
- Rule hierarchy remains primary; 0–100 score is secondary support.
- All new deterministic facts can be supplied to Deep Analysis with evidence IDs.

---

### Task 1: Traditional Dignity and Reception Model
**Files:**
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Test: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Produces `EssentialDignityKind`, richer `HoraryReception`, dignity helpers and expanded `TraditionalCondition`.

- [ ] Add failing table tests for triplicity, Egyptian term and Chaldean face rulers plus peregrine detection.
- [ ] Run targeted AstroCore tests and confirm RED.
- [ ] Implement deterministic dignity tables and scoring.
- [ ] Expand reception while preserving `byDomicile`, `byExaltation`, `isPresent` compatibility.
- [ ] Run targeted and full AstroCore tests GREEN.
- [ ] Commit and checkpoint.

### Task 2: Moon Testimony and Considerations
**Files:**
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Test: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Produces richer `HoraryMoonCondition` and optional `HoraryConsiderationAssessment` on analysis.

- [ ] Add failing tests for via combusta, previous/next Moon testimony, upcoming sequence and consideration flags.
- [ ] Verify RED.
- [ ] Implement deterministic testimony/consideration helpers with backward-compatible Codable fields.
- [ ] Run targeted/full tests GREEN.
- [ ] Commit and checkpoint.

### Task 3: Horary Timing Engine
**Files:**
- Create: `ios/Packages/AstroCore/Sources/AstroCore/HoraryTiming.swift`
- Modify: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Produces `HoraryTimingResult` and `HoraryTimingEngine.resolve(snapshot:targetHouse:relatedHouses:calculator:)`.

- [ ] Add failing tests showing timing derives from one question chart/perfection path and exposes degrees, scale, range and exact aspect date.
- [ ] Verify RED.
- [ ] Implement timing scale from applying significator sign modality + house class, plus bounded date-range mapping.
- [ ] Run targeted/full tests GREEN.
- [ ] Commit and checkpoint.

### Task 4: Ask App Migration to Horary Timing
**Files:**
- Modify: `ios/App/AskHistory.swift`
- Modify: `ios/App/AppModel.swift`
- Modify: `ios/App/Ask/AskActions.swift`
- Modify: `ios/App/Ask/AskResultView.swift`
- Modify: `ios/App/Ask/AskContentComposer.swift`
- Modify: `ios/App/AskDeepAnalysis.swift`
- Test: Python source-contract tests under `tests/`

**Interfaces:**
- New sessions write `timingResult`; old sessions still read `timingCandidates`.

- [ ] Add failing source/history tests that new Ask timing no longer calls `ElectionTimingEngine` and old history still decodes.
- [ ] Verify RED.
- [ ] Add optional timing result to history and app service.
- [ ] Switch Ask timing generation/results/AI facts to new result, preserving legacy fallback.
- [ ] Run Python + AstroCore GREEN.
- [ ] Commit and checkpoint.

### Task 5: Perfection Frustration and Final Rule Hierarchy
**Files:**
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Test: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Adds `.frustration` interruption with ephemeris-backed earlier perfection evidence.

- [ ] Add failing deterministic frustration test/fixture.
- [ ] Verify RED.
- [ ] Implement frustration without changing existing direct/translation/collection behavior.
- [ ] Verify judgment maps interruption state correctly.
- [ ] Run full suites GREEN.
- [ ] Commit and create final archive with verification record.

### Task 6: Lilly Fortitude Engine
**Files:**
- Create: `ios/Packages/AstroCore/Sources/AstroCore/HoraryLillyFortitudes.swift`
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Test: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Produces `HoraryFortitudeAssessment` with named Lilly factors and exact p.115 point values.
- `HoraryEngine.assess` becomes a compatibility facade over the Lilly assessment rather than maintaining a separate modern weight table.

- [ ] Add failing tests for exact essential/accidental point values, house scores, motion, oriental/occidental, combustion/beams/cazimi, and partile benefic/malefic contacts.
- [ ] Verify RED.
- [ ] Implement Lilly table factors and mean-motion thresholds.
- [ ] Route legacy `HoraryPlanetAssessment.score` through the new engine.
- [ ] Run targeted/full tests GREEN.
- [ ] Commit and checkpoint.

### Task 7: Lilly Perfection and Impediments
**Files:**
- Create: `ios/Packages/AstroCore/Sources/AstroCore/HoraryLillyPerfection.swift`
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Test: `ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift`

**Interfaces:**
- Strictly enforces Lilly's direct perfection, translation reception requirement, collection reception requirement, prohibition, refranation and frustration.

- [ ] Add failing fixtures for square/opposition reception requirements, translation received by house/triplicity/term, collection to a heavier planet received by both, and frustration.
- [ ] Verify RED.
- [ ] Implement the rule hierarchy with ephemeris-backed event ordering.
- [ ] Run full suites GREEN.
- [ ] Commit and checkpoint.

### Task 8: Best Time as a Fourth Ask Mode
**Files:**
- Modify: `ios/Packages/AstroCore/Sources/AstroCore/HoraryCore.swift`
- Modify: `ios/App/AskHistory.swift`
- Modify: `ios/App/Ask/AskView.swift`
- Modify: `ios/App/Ask/AskHomeView.swift`
- Modify: `ios/App/Ask/AskConfigurationView.swift`
- Modify: `ios/App/Ask/AskActions.swift`
- Modify: `ios/App/Ask/AskResultView.swift`
- Modify: `ios/App/Ask/AskContentComposer.swift`
- Modify: `ios/App/AskDeepAnalysis.swift`
- Modify: `ios/Localization/UI/today-ask.json`
- Test: `tests/test_ask_ui_contract.py`

**Interfaces:**
- Adds `HoraryQuestionMode.bestTime` for history/UI compatibility while keeping its computation electional.
- New Best Time sessions populate `timingCandidates` and leave `timingResult` nil.
- New When sessions populate `timingResult` and leave `timingCandidates` empty.

- [ ] Add failing UI/source tests proving four modes and strict When/Best-Time separation.
- [ ] Verify RED.
- [ ] Add consumer search-window presets (7 / 30 / 90 days) without exposing `TimingPrecision`.
- [ ] Wire Best Time to `searchElectionTiming` only.
- [ ] Add distinct result/history/AI-fact labels and localization.
- [ ] Run Python/AstroCore/localization tests GREEN.
- [ ] Commit and checkpoint.
