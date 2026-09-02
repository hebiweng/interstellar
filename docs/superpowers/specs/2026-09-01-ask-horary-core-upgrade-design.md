# Ask Horary Core Upgrade Design

## Goal
Upgrade Ask's deterministic horary engine so Yes/No, When, A/B/C and paid Deep Analysis consume richer, internally consistent traditional-horary facts without delegating calculation to AI.

## Architecture
- Keep `HoraryEngine` as the deterministic domain entry point.
- Add a dedicated `HoraryTimingEngine` for question-chart timing. Keep `ElectionTimingEngine` for future electional/best-time use and legacy history only.
- Expand dignity/reception, Moon testimony and considerations as deterministic fact models.
- Keep judgment hierarchy rule-first: perfection/interruption/reception/Moon/condition. Existing 0–100 score remains secondary UI/ranking support.
- Preserve old Ask history decoding. New Codable fields must be optional/defaulted and legacy `timingCandidates` remains readable.

## Timing
New Ask When computes from the question chart and resolved perfection path, not by sampling future horary charts.
Output includes perfection path, degrees to perfection, moving significator, sign modality, house strength, symbolic time scale, date range and exact ephemeris perfection date when available.
The exact ephemeris date is evidence about aspect perfection, not a claim that the real-world event must happen at that exact instant.

## Essential Dignity and Reception
Use traditional seven planets, Dorothean triplicity rulers, Egyptian terms/bounds, and Chaldean faces. Planet condition records domicile, exaltation, triplicity, term, face, peregrine, detriment and fall plus existing accidental conditions.
Reception records all five essential dignity channels with relative strength and mutual reception state rather than only domicile/exaltation booleans.

## Considerations
Add caution-level `HoraryConsiderationAssessment`, not a hard validity gate. Initial deterministic flags:
- Ascendant earlier than 3°
- Ascendant later than 27°
- Moon void of course
- Moon via combusta (15° Libra through 15° Scorpio)
- Saturn in the 7th house
- Ascendant ruler combust
Reliability is high/moderate/caution based on flag severity/count. These flags inform interpretation but never automatically invalidate a chart.

## Moon Testimony
Extend Moon facts with previous separating aspect, next applying aspect, a short sequence of upcoming lunar aspects before sign exit, hours until sign exit and via-combusta status. Existing `nextAspect` fields remain for compatibility.

## Perfection
Keep direct perfection, translation, collection, sign-change interruption, refranation and prohibition. Add frustration as a first-class interruption when a significator perfects with another planet before the intended perfection. Do not invent speculative perfection types without deterministic ephemeris evidence.

## App Integration
- `HorarySession` gets optional `timingResult` and keeps legacy `timingCandidates`.
- New Ask When creates one question-time snapshot and calls `HoraryTimingEngine`; it no longer calls `ElectionTimingEngine`.
- Result UI and Deep Analysis facts read `timingResult` first, falling back to legacy `timingCandidates` for old history.
- No precise coordinates, timezone, profile data or chart image are added to AI payloads.

## Compatibility
- Existing history with old `HoraryReception`, `HoraryMoonCondition`, `HoraryAnalysis`, and timing candidates must decode.
- Public APIs used by classical synastry reception remain source-compatible where possible.
- `ElectionTimingEngine` remains intact and tested.

## Testing
TDD for timing, dignity tables, reception, considerations, Moon sequence, history migration, Deep Analysis payload and app source contract. Run complete AstroCore and Python contract suites before each checkpoint.

## Addendum: Best Time is Electional, not Horary Timing

Ask now exposes four consumer paths:

1. Yes / No — horary judgment from one question chart.
2. When — symbolic timing derived from that same question chart's perfection chain.
3. A / B / C — horary comparison of named options.
4. Best Time — electional search across a future date window.

`When` and `Best Time` MUST NOT share a result type or calculation path. `HoraryTimingResult` belongs only to `When`. `ElectionTimingCandidate` belongs only to `Best Time` for new sessions; legacy timing history may still decode older candidate arrays.

Best Time is consumer-facing and should ask only for the action/question, life area, search window, and location. It must not expose engine precision jargon. The engine remains deterministic and local.
