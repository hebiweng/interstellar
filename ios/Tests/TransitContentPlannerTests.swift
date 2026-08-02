import AstroCore
import XCTest
@testable import Interstellar

final class TransitContentPlannerTests: XCTestCase {
    func testTenFixturesProduceTheFrozenSixCardContract() {
        let fixtures = makeFixtures()

        XCTAssertEqual(fixtures.count, 10)
        for fixture in fixtures {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            XCTAssertEqual(plan.cards.map(\.cardID), TransitContentPlan.cardIDs, fixture.name)
            XCTAssertEqual(
                plan.cards.map(\.copySlot),
                [.integratedStory, .cycleChapter, nil, .planetPathShort, .lifeAreaShort, .activeTransitShort],
                fixture.name
            )
            XCTAssertTrue(plan.cards.allSatisfy { $0.scopeID == fixture.bundle.scopeID }, fixture.name)
        }
    }

    func testAllFixturesAreDeterministicAcrossInputOrder() {
        for fixture in makeFixtures() {
            let bundle = fixture.bundle
            let reversed = TransitFactBundle(
                scopeID: bundle.scopeID,
                anchorDate: bundle.anchorDate,
                timeZoneIdentifier: bundle.timeZoneIdentifier,
                rangeDays: bundle.rangeDays,
                preset: bundle.preset,
                crossAspects: Array(bundle.crossAspects.reversed()),
                transitWindows: Array(bundle.transitWindows.reversed()),
                aspectWindowFactIDs: bundle.aspectWindowFactIDs,
                planetEvents: Array(bundle.planetEvents.reversed()),
                planetPlacements: Array(bundle.planetPlacements.reversed()),
                lifeAreaScores: Array(bundle.lifeAreaScores.reversed()),
                transitCalendar: Array(bundle.transitCalendar.reversed())
            )

            XCTAssertEqual(
                TransitContentPlanner.plan(bundle),
                TransitContentPlanner.plan(reversed),
                fixture.name
            )
        }
    }

    func testFullExplanationIsClaimedAtMostOnce() {
        for fixture in makeFixtures() {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            let fullClaims = plan.cards.flatMap(\.evidence).filter { $0.claimMode == .full }
            XCTAssertLessThanOrEqual(fullClaims.count, 1, fixture.name)
            if let fullClaim = fullClaims.first {
                XCTAssertEqual(fullClaim.role, .primary, fixture.name)
                XCTAssertEqual(plan.card("current-story")?.primaryFactID, fullClaim.fact.factID, fixture.name)
            }
        }
    }

    func testStoryIntegratedThemesAndSignalRolesAreStable() {
        let cases: [(String, [TransitAspectFact], TransitIntegratedThemeID, [TransitStorySignalRoleID])] = [
            ("mixed", [saturnAspect(), jupiterAspect()], .expansionStructure, [.structuring, .expanding]),
            ("supportive", [jupiterAspect()], .focusedExpansion, [.expanding]),
            ("challenging", [saturnAspect()], .durableStructure, [.structuring]),
            ("neutral", [mercuryAspect()], .steadyRealignment, [.supporting]),
        ]

        for item in cases {
            let plan = TransitContentPlanner.plan(makeBundle(scopeID: item.0, aspects: item.1))
            let story = plan.card("current-story")!
            XCTAssertEqual(story.integratedThemeID, item.2, item.0)
            XCTAssertEqual(story.signalRoles.map(\.signalRole), item.3, item.0)
            XCTAssertTrue(story.signalRoles.allSatisfy {
                Set($0.sourceFactIDs).isSubset(of: Set(story.sourceFactIDs))
                    && !$0.movingID.isEmpty
                    && $0.lifeAreas.allSatisfy { (1 ... 12).contains($0) }
            }, item.0)
        }
    }

    func testEachCardOwnsOnlyItsContractedFactKinds() {
        let plan = TransitContentPlanner.plan(makeBundle())

        XCTAssertTrue(plan.card("transit-timeline")!.evidence.allSatisfy { if case .window = $0.fact { true } else { false } })
        XCTAssertTrue(plan.card("planet-paths")!.evidence.allSatisfy { if case .placement = $0.fact { true } else { false } })
        XCTAssertTrue(plan.card("life-areas")!.evidence.allSatisfy { if case .lifeArea = $0.fact { true } else { false } })
        XCTAssertTrue(plan.card("current-cycles")!.evidence.allSatisfy { $0.claimMode == .aggregate })

        let active = plan.card("active-transits")!.evidence
        XCTAssertTrue(active.allSatisfy { evidence in
            switch evidence.fact {
            case .aspect, .planetEvent:
                evidence.claimMode == .short
            case .window:
                evidence.claimMode == .technical
            default:
                false
            }
        })
    }

    func testTimelineKeepsOnlyInRangeTimestampedWindowsAndRepeatedPasses() {
        let anchor = testAnchor
        let aspect = saturnAspect()
        let returning = window(
            aspect: aspect,
            exactOffsetDays: 2,
            repeatOffsetDays: 12,
            nextOffsetDays: 24,
            passCount: 3
        )
        let outside = window(aspect: aspect, exactOffsetDays: 40)
        let plan = TransitContentPlanner.plan(
            makeBundle(scopeID: "returning", aspects: [aspect], windows: [outside, returning], rangeDays: 30)
        )
        let timeline = plan.card("transit-timeline")!

        XCTAssertNil(timeline.copySlot)
        XCTAssertEqual(timeline.evidence.count, 1)
        guard case let .window(value) = timeline.evidence[0].fact else {
            return XCTFail("Timeline must contain a transit window")
        }
        XCTAssertEqual(value.exact, anchor.addingTimeInterval(2 * day))
        XCTAssertEqual(value.repeatExact, anchor.addingTimeInterval(12 * day))
        XCTAssertEqual(value.nextExact, anchor.addingTimeInterval(24 * day))
        XCTAssertEqual(value.passIndex, 1)
        XCTAssertEqual(value.passCount, 3)
        XCTAssertTrue(value.returning)
        XCTAssertEqual(value.timeZoneIdentifier, testTimeZone)
    }

    func testPlanetPathsAndLifeAreasKeepCompleteCollections() {
        let plan = TransitContentPlanner.plan(makeBundle())
        let paths = plan.card("planet-paths")!
        let areas = plan.card("life-areas")!

        XCTAssertEqual(paths.evidence.count, CelestialBody.allCases.count)
        XCTAssertEqual(
            Set(paths.factIDs),
            Set(makePlacements().map {
                $0.factID.replacingOccurrences(of: "transit.template.", with: "transit.scope.")
            })
        )
        XCTAssertEqual(areas.evidence.count, 12)
        XCTAssertEqual(Set(areas.evidence.compactMap { evidence -> Int? in
            guard case let .lifeArea(area) = evidence.fact else { return nil }
            return area.house
        }), Set(1 ... 12))
    }

    func testActiveTransitsSupportAllFourPlanetEventKinds() {
        let plan = TransitContentPlanner.plan(
            makeBundle(scopeID: "events-only", aspects: [], windows: [], events: makePlanetEvents())
        )
        let active = plan.card("active-transits")!

        XCTAssertEqual(Set(active.evidence.compactMap { evidence -> TransitPlanetEventKind? in
            guard case let .planetEvent(event) = evidence.fact else { return nil }
            return event.kind
        }), Set(TransitPlanetEventKind.allCases))
        XCTAssertEqual(
            Set(active.evidence.map(\.role)),
            Set([
                .activeSignIngress,
                .activeHouseIngress,
                .activeStationRetrograde,
                .activeStationDirect,
            ])
        )
    }

    func testEveryPlannedSignalAndTimeFactUsesTheSameScope() {
        for fixture in makeFixtures() {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            XCTAssertEqual(plan.timeZoneIdentifier, fixture.bundle.timeZoneIdentifier, fixture.name)
            for card in plan.cards {
                let plannedSourceIDs = Set(card.sourceFactIDs)
                XCTAssertTrue(card.themeInputs.allSatisfy {
                    Set($0.sourceFactIDs).isSubset(of: plannedSourceIDs)
                        && $0.signalID.hasPrefix("transit.signal.")
                }, fixture.name)
                XCTAssertTrue(card.signalRoles.allSatisfy {
                    Set($0.sourceFactIDs).isSubset(of: plannedSourceIDs)
                }, fixture.name)
                for evidence in card.evidence {
                    XCTAssertTrue(evidence.fact.factID.hasPrefix("transit.\(plan.scopeID)."), fixture.name)
                    switch evidence.fact {
                    case let .window(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    case let .planetEvent(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    case let .calendar(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    default:
                        break
                    }
                }
            }
        }
    }

    func testEmptyEvidenceUsesTheFrozenEmptyStateWithoutCrossCardFallback() {
        let plan = TransitContentPlanner.plan(
            makeBundle(
                scopeID: "empty",
                aspects: [],
                windows: [],
                events: [],
                placements: [],
                lifeAreas: [],
                calendar: []
            )
        )

        XCTAssertTrue(plan.cards.allSatisfy { $0.evidence.isEmpty })
        XCTAssertTrue(plan.cards.allSatisfy { $0.primaryFactID == nil })
        XCTAssertTrue(plan.cards.allSatisfy { $0.emptyState == .showInsufficientFacts })
        XCTAssertNil(plan.card("current-story")?.integratedThemeID)
    }

    func testFrozenThemeAndRoleRegistriesRemainFinite() {
        XCTAssertEqual(TransitIntegratedThemeID.allCases.count, 4)
        XCTAssertEqual(TransitStorySignalRoleID.allCases.count, 5)
        XCTAssertEqual(TransitThemeID.allCases.count, 38)
        XCTAssertEqual(TransitCopySlot.allCases.count, 6)
        XCTAssertEqual(Set(TransitThemeID.allCases.map(\.rawValue)).count, TransitThemeID.allCases.count)
    }

    private struct Fixture {
        let name: String
        let bundle: TransitFactBundle
    }

    private let testAnchor = Date(timeIntervalSince1970: 1_775_232_000)
    private let testTimeZone = "Asia/Shanghai"
    private let day: TimeInterval = 86_400

    private func makeFixtures() -> [Fixture] {
        let saturn = saturnAspect()
        return [
            Fixture(name: "mixed-complete", bundle: makeBundle()),
            Fixture(name: "supportive-only", bundle: makeBundle(scopeID: "supportive", aspects: [jupiterAspect()])),
            Fixture(name: "challenging-only", bundle: makeBundle(scopeID: "challenging", aspects: [saturn])),
            Fixture(name: "neutral-only", bundle: makeBundle(scopeID: "neutral", aspects: [mercuryAspect()])),
            Fixture(name: "empty", bundle: makeBundle(scopeID: "empty-fixture", aspects: [], windows: [], events: [], placements: [], lifeAreas: [], calendar: [])),
            Fixture(name: "windows-only", bundle: makeBundle(scopeID: "windows", aspects: [], windows: [window(aspect: nil, exactOffsetDays: 2)], events: [])),
            Fixture(name: "events-only", bundle: makeBundle(scopeID: "events", aspects: [], windows: [], events: makePlanetEvents())),
            Fixture(name: "returning-pass", bundle: makeBundle(scopeID: "repeat", aspects: [saturn], windows: [window(aspect: saturn, exactOffsetDays: 2, repeatOffsetDays: 12, nextOffsetDays: 24, passCount: 3)], rangeDays: 30)),
            Fixture(name: "complete-paths-areas", bundle: makeBundle(scopeID: "collections", aspects: [], windows: [], events: [], placements: makePlacements(), lifeAreas: makeLifeAreas())),
            Fixture(name: "range-filter", bundle: makeBundle(scopeID: "range", aspects: [saturn], windows: [window(aspect: saturn, exactOffsetDays: 40)], events: [planetEvent(kind: .signIngress, offsetDays: 40)], rangeDays: 7)),
        ]
    }

    private func makeBundle(
        scopeID: String = "scope",
        aspects: [TransitAspectFact]? = nil,
        windows: [TransitWindowFact]? = nil,
        events: [TransitPlanetEventFact]? = nil,
        placements: [TransitPlanetPlacementFact]? = nil,
        lifeAreas: [TransitLifeAreaFact]? = nil,
        calendar: [TransitCalendarFact]? = nil,
        rangeDays: Int = 30
    ) -> TransitFactBundle {
        let resolvedAspects = aspects ?? [marsAspect(), saturnAspect(), jupiterAspect()]
        let resolvedWindows = windows ?? [
            window(aspect: saturnAspect(), exactOffsetDays: 2),
            window(aspect: marsAspect(), exactOffsetDays: 3),
        ]
        let scopedAspects = resolvedAspects.map { scoped($0, scopeID: scopeID) }
        let aspectIDsByKey = Dictionary(uniqueKeysWithValues: scopedAspects.map {
            ("\($0.movingID).\($0.kind.rawValue).\($0.referenceID)", $0.factID)
        })
        let scopedWindows = resolvedWindows.map { value in
            let key = "\(value.movingID).\(value.kind.rawValue).\(value.referenceID)"
            return scoped(value, scopeID: scopeID, sourceAspectFactID: aspectIDsByKey[key])
        }
        let links = Dictionary(
            grouping: scopedWindows.compactMap { value -> (String, String)? in
                value.sourceAspectFactID.map { ($0, value.factID) }
            },
            by: \.0
        ).mapValues { $0.map(\.1).sorted() }

        return TransitFactBundle(
            scopeID: scopeID,
            anchorDate: testAnchor,
            timeZoneIdentifier: testTimeZone,
            rangeDays: rangeDays,
            preset: "modern",
            crossAspects: scopedAspects,
            transitWindows: scopedWindows,
            aspectWindowFactIDs: links,
            planetEvents: (events ?? makePlanetEvents()).map { scoped($0, scopeID: scopeID) },
            planetPlacements: (placements ?? makePlacements()).map { scoped($0, scopeID: scopeID) },
            lifeAreaScores: (lifeAreas ?? makeLifeAreas()).map { scoped($0, scopeID: scopeID) },
            transitCalendar: (calendar ?? makeCalendar()).map { scoped($0, scopeID: scopeID) }
        )
    }

    private func saturnAspect() -> TransitAspectFact {
        aspect(movingID: "saturn", referenceID: "sun", kind: .square, phase: .applying, strength: 0.92, house: 10, band: .longTerm)
    }

    private func jupiterAspect() -> TransitAspectFact {
        aspect(movingID: "jupiter", referenceID: "moon", kind: .trine, phase: .separating, strength: 0.80, house: 2, band: .current)
    }

    private func marsAspect() -> TransitAspectFact {
        aspect(movingID: "mars", referenceID: "venus", kind: .opposition, phase: .exact, strength: 0.72, house: 7, band: .daily)
    }

    private func mercuryAspect() -> TransitAspectFact {
        aspect(movingID: "mercury", referenceID: "mercury", kind: .conjunction, phase: .applying, strength: 0.81, house: 3, band: .daily)
    }

    private func aspect(
        movingID: String,
        referenceID: String,
        kind: AspectKind,
        phase: AspectPhase,
        strength: Double,
        house: Int,
        band: TransitCycleBand
    ) -> TransitAspectFact {
        TransitAspectFact(
            factID: "transit.template.aspect.\(movingID).\(kind.rawValue).\(referenceID)",
            movingID: movingID,
            referenceID: referenceID,
            kind: kind,
            orbDegrees: max(0.1, 2 - strength),
            phase: phase,
            strength: strength,
            movingLongitude: Double(house * 30 - 15),
            referenceLongitude: Double((house + 3) * 30 - 15),
            natalHouse: house,
            cycleBand: band
        )
    }

    private func window(
        aspect: TransitAspectFact?,
        exactOffsetDays: Double,
        repeatOffsetDays: Double? = nil,
        nextOffsetDays: Double? = nil,
        passCount: Int = 1
    ) -> TransitWindowFact {
        let movingID = aspect?.movingID ?? "jupiter"
        let referenceID = aspect?.referenceID ?? "sun"
        let kind = aspect?.kind ?? .trine
        let exact = testAnchor.addingTimeInterval(exactOffsetDays * day)
        return TransitWindowFact(
            factID: "transit.template.window.\(movingID).\(kind.rawValue).\(referenceID).\(Int(exact.timeIntervalSince1970))",
            sourceAspectFactID: aspect?.factID,
            movingID: movingID,
            referenceID: referenceID,
            kind: kind,
            movingLongitude: aspect?.movingLongitude ?? 75,
            natalHouse: aspect?.natalHouse ?? 5,
            start: exact.addingTimeInterval(-day),
            exact: exact,
            end: exact.addingTimeInterval(day),
            repeatExact: repeatOffsetDays.map { testAnchor.addingTimeInterval($0 * day) },
            nextExact: nextOffsetDays.map { testAnchor.addingTimeInterval($0 * day) },
            passIndex: 1,
            passCount: passCount,
            returning: passCount > 1,
            timeZoneIdentifier: testTimeZone,
            cycleBand: aspect?.cycleBand ?? .current
        )
    }

    private func makePlanetEvents() -> [TransitPlanetEventFact] {
        [
            planetEvent(kind: .signIngress, offsetDays: 1),
            planetEvent(kind: .houseIngress, offsetDays: 2),
            planetEvent(kind: .stationRetrograde, offsetDays: 3),
            planetEvent(kind: .stationDirect, offsetDays: 4),
        ]
    }

    private func planetEvent(kind: TransitPlanetEventKind, offsetDays: Double) -> TransitPlanetEventFact {
        let timestamp = testAnchor.addingTimeInterval(offsetDays * day)
        return TransitPlanetEventFact(
            factID: "transit.template.planet-event.mercury.\(kind.rawValue).\(Int(timestamp.timeIntervalSince1970))",
            body: .mercury,
            kind: kind,
            timestamp: timestamp,
            timeZoneIdentifier: testTimeZone,
            fromIndex: kind == .signIngress || kind == .houseIngress ? 2 : nil,
            toIndex: kind == .signIngress || kind == .houseIngress ? 3 : nil
        )
    }

    private func makePlacements() -> [TransitPlanetPlacementFact] {
        CelestialBody.allCases.enumerated().map { index, body in
            TransitPlanetPlacementFact(
                factID: "transit.template.placement.\(body.rawValue)",
                body: body,
                longitudeDegrees: Double(index * 27),
                signIndex: index % 12,
                degreeInSign: Double((index * 7) % 30),
                natalHouse: (index % 12) + 1,
                retrograde: index.isMultiple(of: 3) && body != .sun && body != .moon,
                longitudeSpeedDegreesPerDay: index.isMultiple(of: 3) ? -0.1 : 0.3
            )
        }
    }

    private func makeLifeAreas() -> [TransitLifeAreaFact] {
        (1 ... 12).map { house in
            TransitLifeAreaFact(
                factID: "transit.template.life-area.\(house)",
                house: house,
                normalizedScore: Double(13 - house) / 12,
                contributingFactIDs: ["transit.template.placement.\(CelestialBody.allCases[(house - 1) % CelestialBody.allCases.count].rawValue)"]
            )
        }
    }

    private func makeCalendar() -> [TransitCalendarFact] {
        (0 ..< 7).map { offset in
            TransitCalendarFact(
                factID: "transit.template.calendar.day-\(offset)",
                date: testAnchor.addingTimeInterval(Double(offset) * day),
                score: 40 + offset,
                sourceFactIDs: ["transit.template.calendar-source.day-\(offset)"],
                timeZoneIdentifier: testTimeZone
            )
        }
    }

    private func scoped(_ value: TransitAspectFact, scopeID: String) -> TransitAspectFact {
        TransitAspectFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            movingID: value.movingID,
            referenceID: value.referenceID,
            kind: value.kind,
            orbDegrees: value.orbDegrees,
            phase: value.phase,
            strength: value.strength,
            movingLongitude: value.movingLongitude,
            referenceLongitude: value.referenceLongitude,
            natalHouse: value.natalHouse,
            cycleBand: value.cycleBand
        )
    }

    private func scoped(
        _ value: TransitWindowFact,
        scopeID: String,
        sourceAspectFactID: String?
    ) -> TransitWindowFact {
        TransitWindowFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            sourceAspectFactID: sourceAspectFactID,
            movingID: value.movingID,
            referenceID: value.referenceID,
            kind: value.kind,
            movingLongitude: value.movingLongitude,
            natalHouse: value.natalHouse,
            start: value.start,
            exact: value.exact,
            end: value.end,
            repeatExact: value.repeatExact,
            nextExact: value.nextExact,
            passIndex: value.passIndex,
            passCount: value.passCount,
            returning: value.returning,
            timeZoneIdentifier: value.timeZoneIdentifier,
            cycleBand: value.cycleBand
        )
    }

    private func scoped(_ value: TransitPlanetEventFact, scopeID: String) -> TransitPlanetEventFact {
        TransitPlanetEventFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            body: value.body,
            kind: value.kind,
            timestamp: value.timestamp,
            timeZoneIdentifier: value.timeZoneIdentifier,
            fromIndex: value.fromIndex,
            toIndex: value.toIndex
        )
    }

    private func scoped(_ value: TransitPlanetPlacementFact, scopeID: String) -> TransitPlanetPlacementFact {
        TransitPlanetPlacementFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            body: value.body,
            longitudeDegrees: value.longitudeDegrees,
            signIndex: value.signIndex,
            degreeInSign: value.degreeInSign,
            natalHouse: value.natalHouse,
            retrograde: value.retrograde,
            longitudeSpeedDegreesPerDay: value.longitudeSpeedDegreesPerDay
        )
    }

    private func scoped(_ value: TransitLifeAreaFact, scopeID: String) -> TransitLifeAreaFact {
        TransitLifeAreaFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            house: value.house,
            normalizedScore: value.normalizedScore,
            contributingFactIDs: value.contributingFactIDs.map {
                $0.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID).")
            }
        )
    }

    private func scoped(_ value: TransitCalendarFact, scopeID: String) -> TransitCalendarFact {
        TransitCalendarFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            date: value.date,
            score: value.score,
            sourceFactIDs: value.sourceFactIDs.map {
                $0.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID).")
            },
            timeZoneIdentifier: value.timeZoneIdentifier
        )
    }
}
