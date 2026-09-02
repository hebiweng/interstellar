# iOS Offline Global Locations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing iOS location picker search and select global locations offline when public MapKit returns no usable overseas result.

**Architecture:** Generate a versioned read-only SQLite resource containing every GeoNames city and a deduplicated IANA timezone table. Use Timezone Boundary Builder only at build time to backfill missing city timezones, then merge city search and nearest-city map fallback into the existing MapKit UI.

**Tech Stack:** Swift 6, SwiftUI, MapKit, CoreLocation, SQLite3, Python 3 standard library, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-23-ios-offline-global-locations-design.md`

## Global Constraints

- Keep one existing search field and one map selection sheet.
- Never apply a nearby city's timezone to an arbitrary coordinate; an offline map fallback selects the nearby real city and its coordinate.
- Do not send location queries or coordinates to Relay or third parties.
- Keep GeoNames CC BY 4.0 and Timezone Boundary Builder/OSM ODbL attribution in the app bundle.
- Support iOS 17+, iPhone 12 mini, four app languages, Dynamic Type, dark/light mode, and VoiceOver.
- Build number is 12; create an Archive but do not upload it.

---

### Task 1: Deterministic Offline Database Builder

**Files:**
- Create: `scripts/build-ios-offline-locations.py`
- Create: `tests/data/test_build_ios_offline_locations.py`
- Restore: `vendor/timezone-boundary-builder/timezones-2026b.geojson.zip`
- Create: `ios/App/Resources/OfflineLocationData-LICENSES.txt`
- Create: `ios/App/Resources/OfflineLocations.sqlite3`

**Interfaces:**
- Consumes the three locked dataset entries from `data-manifests/locks/natal-location-data-2026-07-19.json`.
- Produces a SQLite schema with `metadata`, `places`, contentless `place_search`, and deduplicated `timezones`; timezone polygons are build-only.

- [x] Write fixture-driven tests that invoke the builder, assert deterministic metadata and hashes, query multilingual aliases, and verify deduplicated timezone indexes.
- [ ] Run `PYTHONPATH=python python3 -m pytest tests/data/test_build_ios_offline_locations.py -q` and verify failure because the builder does not exist.
- [x] Implement locked-hash validation, GeoNames ZIP parsing, contentless FTS5 rows, build-time timezone backfill, deterministic pragmas, and license output.
- [ ] Run the targeted test and verify it passes.
- [x] Restore the verified timezone archive from Git object history, build the production SQLite resource, and verify integrity, counts, timezone coverage, and representative searches.

### Task 2: Swift Offline Location Store

**Files:**
- Create: `ios/App/OfflineLocationStore.swift`
- Create: `ios/Tests/OfflineLocationStoreTests.swift`
- Modify: `ios/project.yml`
- Modify: `ios/Interstellar.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces `OfflinePlace`, `OfflineCoordinateResolution`, and `OfflineLocationStore.search(query:limit:)` / `resolve(latitude:longitude:)`.
- Reads `OfflineLocations.sqlite3` read-only and returns either a searched city or a nearby known city with its own timezone.

- [x] Add tests for prefix/non-Latin search, build-time antimeridian backfill, nearby-city selection, and unmatched ocean points.
- [ ] Run the targeted iPhone 12 mini simulator tests and verify failure because the Swift store does not exist.
- [x] Add SQLite3 linkage and implement the minimal read-only store, statement binding, search, nearby-city lookup, and error types.
- [ ] Run the targeted tests and verify they pass without warnings.

### Task 3: Existing Search Field Integration

**Files:**
- Modify: `ios/App/LocationPicker.swift`
- Modify: `ios/Tests/OfflineLocationStoreTests.swift`

**Interfaces:**
- `LocationSearchResult` represents Apple and offline results in one published list.
- `LocationSearchService.resolve(_ result:)` returns the existing `LocationSelection`.

- [ ] Add failing tests showing `Paris, France` remains selectable when Apple completions are empty or irrelevant, while exact Apple and offline duplicates are removed.
- [ ] Run the targeted tests and verify the expected failure.
- [ ] Implement cancellable offline search, deterministic result merge/ranking, and selection of offline city results in the current list.
- [ ] Run the targeted tests and verify they pass.

### Task 4: Existing Map-Tap Integration

**Files:**
- Modify: `ios/App/LocationPicker.swift`
- Modify: `ios/Tests/OfflineLocationStoreTests.swift`

**Interfaces:**
- `LocationSearchService.resolve(_ coordinate:)` first uses Apple and falls back to `OfflineLocationStore.resolve` only for no-result errors.

- [ ] Add failing tests for Paris fallback success, Shenzhen Apple-first behavior, throttling/cancellation not being masked, timezone ambiguity, and ocean/unmatched coordinates remaining unavailable.
- [ ] Run the targeted tests and verify the expected failures.
- [x] Implement the minimal fallback policy and return the selected nearby city's coordinate rather than guessing for the tapped coordinate.
- [ ] Run targeted tests and verify they pass.

### Task 5: Product, License, and Accessibility Validation

**Files:**
- Modify: `ios/App/LocationPicker.swift`
- Modify: `ios/Localization/ui-translations.json` only if a new visible error/source label is required.
- Regenerate: `ios/App/Localizable.xcstrings` only if translations changed.

**Interfaces:**
- Existing location picker remains the sole UI; offline rows expose stable accessibility labels and actions.

- [ ] Add or update UI assertions for one search field, a Paris result, timezone display, Done enablement, and no coordinate editor.
- [ ] Run targeted UI tests on iPhone 12 mini.
- [ ] Validate long labels, Dynamic Type, four languages, dark/light mode, and VoiceOver identifiers without introducing consumer explanation copy.

### Task 6: Full Verification and Build 12 Archive

**Files:**
- Modify: `ios/project.yml`
- Regenerate: `ios/Interstellar.xcodeproj/project.pbxproj`
- Modify: `docs/ios-product-backlog.md`
- Modify: `docs/ios-release-readiness.md`
- Modify: `docs/agent-handoff.md`

**Interfaces:**
- Build 12 is the new App Store candidate generated from the verified workspace; it is not uploaded.

- [ ] Change `CURRENT_PROJECT_VERSION` from 11 to 12 in the authoritative project definition and regenerate the Xcode project.
- [ ] Run the offline builder reproducibility check and SQLite integrity check.
- [ ] Run targeted location tests, the applicable iOS unit suite, AstroCore, ContentKit, localization/copy/card/architecture/lint/private-content gates, and `git diff --check`.
- [ ] Install the Debug build on iPhone 12 mini and verify Paris search plus Paris map tap return `Europe/Paris`; verify Shenzhen still returns `Asia/Shanghai`.
- [ ] Run a generic iPhoneOS no-signing build.
- [ ] Generate a Build 12 Archive and verify version, bundle, Team, production App Attest, entitlements, privacy manifest, bundled offline database integrity, resource licenses, and arm64 UUID.
- [ ] Record evidence and remaining TestFlight/App Store steps in backlog, release readiness, and handoff without overwriting unrelated user edits.
