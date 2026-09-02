import AstroCore
import Foundation
import Testing

@Suite("Lilly perfection policy")
struct HoraryLillyPerfectionTests {
    @Test("Conjunction can perfect from any house while sextile trine and square require good houses and essential dignity")
    func directAspectEligibility() throws {
        let strong = try syntheticSnapshot(points: [
            .init(.sun, 125, 1.0),      // Sun in Leo, house 5, domicile
            .init(.jupiter, 245, 0.1),  // Jupiter in Sagittarius, house 9, domicile, trine Sun
            .init(.moon, 95, 13.2),
            .init(.mercury, 30, 1.1),
            .init(.venus, 60, 1.0),
            .init(.mars, 5, 0.5),
            .init(.saturn, 300, 0.03),
        ])
        #expect(HoraryLillyPerfectionPolicy.directEligibility(
            aspectKind: .trine,
            querentRuler: .sun,
            targetRuler: .jupiter,
            snapshot: strong,
            moonSeparatedFromTarget: false
        ).isEligible)

        let weak = try syntheticSnapshot(points: [
            .init(.sun, 262, 1.0),      // Sun in Sagittarius, day chart, fire triplicity dignity
            .init(.jupiter, 142, 0.1),  // Jupiter at 22 Leo: no essential dignity in a day chart
            .init(.moon, 95, 13.2),
            .init(.mercury, 30, 1.1),
            .init(.venus, 60, 1.0),
            .init(.mars, 180, 0.5),
            .init(.saturn, 300, 0.03),
        ])
        #expect(!HoraryLillyPerfectionPolicy.directEligibility(
            aspectKind: .trine,
            querentRuler: .sun,
            targetRuler: .jupiter,
            snapshot: weak,
            moonSeparatedFromTarget: false
        ).isEligible)

        #expect(HoraryLillyPerfectionPolicy.directEligibility(
            aspectKind: .conjunction,
            querentRuler: .sun,
            targetRuler: .jupiter,
            snapshot: weak,
            moonSeparatedFromTarget: false
        ).isEligible)
    }

    @Test("Opposition requires mutual reception by house friendly houses and Moon separation from the quesited")
    func oppositionEligibility() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 250, 1.0),
            .init(.mars, 185, 0.5), // Mars received by Venus by house
            .init(.venus, 5, 1.0),  // Venus received by Mars by house
            .init(.moon, 80, 13.2),
            .init(.mercury, 120, 1.1),
            .init(.jupiter, 270, 0.1),
            .init(.saturn, 300, 0.03),
        ])
        let eligible = HoraryLillyPerfectionPolicy.directEligibility(
            aspectKind: .opposition,
            querentRuler: .mars,
            targetRuler: .venus,
            snapshot: snapshot,
            moonSeparatedFromTarget: true
        )
        #expect(eligible.isEligible)
        #expect(eligible.evidenceIDs.contains("lilly.perfection.opposition.mutual-reception-house"))

        #expect(!HoraryLillyPerfectionPolicy.directEligibility(
            aspectKind: .opposition,
            querentRuler: .mars,
            targetRuler: .venus,
            snapshot: snapshot,
            moonSeparatedFromTarget: false
        ).isEligible)
    }

    @Test("Translation requires the separated significator to receive the translator by house triplicity or term")
    func translationReception() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 250, 1.0),
            .init(.mars, 5, 0.5),
            .init(.moon, 2, 13.2),  // Moon in Aries: Mars receives Moon by house
            .init(.venus, 90, 1.0),
            .init(.mercury, 120, 1.1),
            .init(.jupiter, 270, 0.1),
            .init(.saturn, 300, 0.03),
        ])
        #expect(HoraryLillyPerfectionPolicy.translationReceptionIsEligible(
            translator: .moon,
            separatedFrom: .mars,
            appliesTo: .venus,
            snapshot: snapshot
        ))
        #expect(!HoraryLillyPerfectionPolicy.translationReceptionIsEligible(
            translator: .mercury,
            separatedFrom: .mars,
            appliesTo: .venus,
            snapshot: snapshot
        ))
    }

    @Test("Collection reception direction is significators receiving the collector")
    func collectionReceptionDirection() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 245, 1.0),      // Sun in 9th keeps this a day chart
            .init(.mars, 100, 0.5),
            .init(.saturn, 2, 0.03), // Saturn in Aries: Mars receives by house, Sun by day triplicity
            .init(.moon, 80, 13.2),
            .init(.mercury, 120, 1.1),
            .init(.venus, 180, 1.0),
            .init(.jupiter, 270, 0.1),
        ])
        #expect(HoraryLillyPerfectionPolicy.collectionReceptionIsEligible(
            collector: .saturn,
            firstSignificator: .mars,
            secondSignificator: .sun,
            snapshot: snapshot
        ))
        #expect(!HoraryLillyPerfectionPolicy.collectionReceptionIsEligible(
            collector: .mars,
            firstSignificator: .saturn,
            secondSignificator: .sun,
            snapshot: snapshot
        ))
    }

    @Test("Refranation only occurs when the applying planet turns retrograde before perfection")
    func refranationSequence() {
        let start = Date(timeIntervalSince1970: 1000)
        let deadline = start.addingTimeInterval(10_000)
        #expect(HoraryLillyPerfectionPolicy.isRefranation(
            applyingBody: .mars,
            stationBody: .mars,
            stationDate: start.addingTimeInterval(100),
            retrogradeAfter: true,
            deadline: deadline
        ))
        #expect(!HoraryLillyPerfectionPolicy.isRefranation(
            applyingBody: .mars,
            stationBody: .saturn,
            stationDate: start.addingTimeInterval(100),
            retrogradeAfter: true,
            deadline: deadline
        ))
        #expect(!HoraryLillyPerfectionPolicy.isRefranation(
            applyingBody: .mars,
            stationBody: .mars,
            stationDate: start.addingTimeInterval(100),
            retrogradeAfter: false,
            deadline: deadline
        ))
    }

    @Test("Prohibition requires a faster third planet to contact applying then receiving before perfection")
    func prohibitionSequence() {
        let start = Date(timeIntervalSince1970: 1000)
        let deadline = start.addingTimeInterval(1000)
        #expect(HoraryLillyPerfectionPolicy.isProhibitionSequence(
            thirdSpeed: 1.0,
            applyingSpeed: 0.5,
            firstContact: start.addingTimeInterval(100),
            secondContact: start.addingTimeInterval(200),
            deadline: deadline
        ))
        #expect(!HoraryLillyPerfectionPolicy.isProhibitionSequence(
            thirdSpeed: 0.2,
            applyingSpeed: 0.5,
            firstContact: start.addingTimeInterval(100),
            secondContact: start.addingTimeInterval(200),
            deadline: deadline
        ))
        #expect(!HoraryLillyPerfectionPolicy.isProhibitionSequence(
            thirdSpeed: 1.0,
            applyingSpeed: 0.5,
            firstContact: start.addingTimeInterval(300),
            secondContact: start.addingTimeInterval(200),
            deadline: deadline
        ))
    }

    @Test("Frustration remains a distinct interruption from prohibition and refranation")
    func frustrationKind() {
        #expect(HoraryInterruptionKind.frustration.rawValue == "frustration")
    }

    private struct PointSpec {
        let body: CelestialBody
        let longitude: Double
        let speed: Double
        init(_ body: CelestialBody, _ longitude: Double, _ speed: Double) {
            self.body = body; self.longitude = longitude; self.speed = speed
        }
    }
    private struct SnapshotFixture: Encodable {
        let utcDate: Date
        let location: LocationFixture
        let julianDayUT: Double
        let points: [PointFixture]
        let houses: [HouseFixture]
        let angles: AnglesFixture
        let aspects: [String]
    }
    private struct LocationFixture: Encodable { let latitudeDegrees: Double; let longitudeDegrees: Double }
    private struct PositionFixture: Encodable { let longitudeDegrees: Double; let latitudeDegrees: Double; let distanceAU: Double; let longitudeSpeedDegreesPerDay: Double }
    private struct PointFixture: Encodable { let body: CelestialBody; let position: PositionFixture }
    private struct HouseFixture: Encodable { let number: Int; let cuspDegrees: Double }
    private struct AnglesFixture: Encodable { let ascendantDegrees: Double; let midheavenDegrees: Double }

    private func syntheticSnapshot(points: [PointSpec]) throws -> ChartSnapshot {
        let fixture = SnapshotFixture(
            utcDate: Date(timeIntervalSince1970: 1_775_000_000),
            location: .init(latitudeDegrees: 0, longitudeDegrees: 0),
            julianDayUT: 2_460_000,
            points: points.map { .init(body: $0.body, position: .init(longitudeDegrees: $0.longitude, latitudeDegrees: 0, distanceAU: 1, longitudeSpeedDegreesPerDay: $0.speed)) },
            houses: (1...12).map { .init(number: $0, cuspDegrees: Double($0 - 1) * 30) },
            angles: .init(ascendantDegrees: 0, midheavenDegrees: 270),
            aspects: []
        )
        return try JSONDecoder().decode(ChartSnapshot.self, from: JSONEncoder().encode(fixture))
    }
}
