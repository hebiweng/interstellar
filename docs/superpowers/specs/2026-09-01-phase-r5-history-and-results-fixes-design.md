# Phase R5 History and Results Fixes Design

## Goal

Make Compare, Ask Deep Analysis, and Themes truthful and durable while AI work is in flight, correct Compare's local result presentation, restore direct Theme chart visibility, and make production capable of serving the Phase R5 AI scopes.

## Confirmed root causes

- Production still runs `interstellar-relay:v6-20260830-build21-themes-focus`; it does not contain `compare.*` or `ask.deep_analysis`, so those requests are rejected before a report reservation is recorded.
- Two People intentionally has relationship facts and an empty time diff, but the result page renders only `diff.allChanges`.
- Compare home filters history to completed AI reports, hiding charts-ready, generating, and failed local analyses.
- Compare displays the full diff count while rendering `prefix(8)`.
- Compare evidence uses two independent sheet state mutations, allowing the sheet to render before the new fact IDs arrive.
- Compare preset buttons mutate `dateA`; the unconditional `onChange` immediately changes the selected preset to Custom.
- Ask Deep records are stored separately from Ask history and their work is owned by a result view.
- Theme history has no visible report status, and the result selector currently renders charts only after navigation to details.

## Architecture

Keep the three existing local stores as the durable source of truth. Generation tasks are owned by feature-level managers, not result/setup views. History rows render directly from persisted status and update in place. No shared generic job engine is introduced.

Production Relay receives the already implemented Phase R5 scopes, schemas, evidence validation, prompts, and retry behavior. Deployment must back up the database, rebuild only Relay, preserve Edge/Caddy, and verify health and prompt scope registration.

## Compare

- `CompareAnalysisManager` owns in-flight report tasks by analysis ID and exposes start/resume without tying work to a view.
- History displays recent analyses regardless of AI state. Generating rows show a spinner and “Analyzing”; failed/local-only rows remain openable and retryable.
- Temporal/place/relationship-over-time results show `Primary Changes`. Two People shows `Primary Comparisons` sourced from deterministic relationship facts instead of the empty temporal diff.
- A pure `ComparePrimaryResultSelector` returns at most eight items. Priority is exact/peaked, structural, added/removed, then strengthened/weakened; aspect/angle evidence outranks general placement/house emphasis; stronger and tighter facts outrank weaker/wider facts; stable ID is the final deterministic tie-break. The displayed count is the selected count.
- Evidence presentation uses one identifiable selection containing the fact IDs, so local evidence is available on the sheet's first render.
- The date picker uses a custom Binding. Preset buttons update the date directly while preserving their selection; only direct picker edits select Custom.
- Cached charts are classified into shared, A, and B groups. Shared baselines render once. A/B use a segmented picker and render only the selected side.

## Ask

- Add an observable Deep Analysis store and manager-owned task registry.
- Ask history derives Deep status by the session fingerprint already used by the Deep Analysis contract.
- Pending rows show “Analyzing”; completed and failed states update in place. Opening a history entry continues to show the locally calculated base answer even if Deep Analysis is unfinished.
- Local save remains before Relay ACK.

## Themes

- Existing manager-owned report tasks remain authoritative.
- History rows show analyzing, completed, or retry status from `ThemeAnalysis.status`.
- `ThemeChartSelector` renders the selected wheel inline, followed by the retained View Chart Details navigation. Detail continues to switch between Wheel and Aspects.

## Safety and verification

- UI never calculates or invents astrology facts; selectors only rank/filter existing deterministic facts.
- No report is ACKed before atomic local persistence.
- Add focused AstroCore/Swift or contract tests before production changes and observe each new test fail first.
- Run Relay tests/vet, AstroCore, ContentKit, Phase R5 UI contracts, signed iPhoneOS build, project gates, production backup/deploy/health checks, and reinstall on the connected iPhone 12 mini.
- Do not automatically trigger a paid production report.
