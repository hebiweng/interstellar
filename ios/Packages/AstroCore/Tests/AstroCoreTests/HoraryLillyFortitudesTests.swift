import AstroCore
import Foundation
import Testing

@Suite("Lilly fortitudes and debilities")
struct HoraryLillyFortitudesTests {
    @Test("Lilly p115 rule points remain exact")
    func rulePoints() {
        let expected: [HoraryFortitudeRule: Int] = [
            .ownHouseOrMutualReceptionByHouse: 5,
            .exaltationOrMutualReceptionByExaltation: 4,
            .triplicity: 3,
            .term: 2,
            .face: 1,
            .detriment: -5,
            .fall: -4,
            .peregrine: -5,
            .houseTenOrOne: 5,
            .houseSevenFourOrEleven: 4,
            .houseTwoOrFive: 3,
            .houseNine: 2,
            .houseThree: 1,
            .houseTwelve: -5,
            .houseEightOrSix: -2,
            .direct: 4,
            .retrograde: -5,
            .swift: 2,
            .slow: -2,
            .superiorOriental: 2,
            .superiorOccidental: -2,
            .inferiorOccidental: 2,
            .inferiorOriental: -2,
            .moonIncreasingOrOccidental: 2,
            .moonDecreasing: -2,
            .freeFromSunBeams: 5,
            .cazimi: 5,
            .combust: -5,
            .underSunBeams: -4,
            .partileConjunctBenefic: 5,
            .partileConjunctNorthNode: 4,
            .partileTrineBenefic: 4,
            .partileSextileBenefic: 3,
            .partileConjunctMalefic: -5,
            .partileConjunctSouthNode: -4,
            .besiegedByMalefics: -4,
            .partileOppositionMalefic: -4,
            .partileSquareMalefic: -4,
            .conjunctRegulus: 6,
            .conjunctSpica: 5,
            .nearAlgol: -4,
        ]
        #expect(Set(expected.keys) == Set(HoraryFortitudeRule.allCases))
        for (rule, points) in expected {
            #expect(rule.points == points)
        }
    }

    @Test("Mutual reception uses the same Lilly row as own house and does not double count")
    func mutualReceptionByHouse() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 210, 1),
            .init(.mars, 185, 0.6),     // Mars in Libra (Venus domicile)
            .init(.venus, 5, 1.0),      // Venus in Aries (Mars domicile)
            .init(.moon, 80, 13.5),
            .init(.mercury, 120, 1.2),
            .init(.jupiter, 250, 0.1),
            .init(.saturn, 300, 0.03),
        ])

        let assessment = HoraryLillyFortitudeEngine.assess(
            .mars,
            in: snapshot,
            counterpart: .venus
        )
        let houseRows = assessment.factors.filter { $0.rule == .ownHouseOrMutualReceptionByHouse }
        #expect(houseRows.count == 1)
        #expect(houseRows.first?.points == 5)
        #expect(assessment.factors.contains { $0.rule == .detriment })
    }

    @Test("House strength directness and motion follow Lilly values")
    func houseMotion() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 210, 1),
            .init(.jupiter, 5, 0.2),    // 1st house, direct and swift relative to Lilly mean
            .init(.saturn, 155, -0.03), // 6th house, retrograde
            .init(.moon, 80, 13.5),
            .init(.mercury, 120, 1.2),
            .init(.venus, 150, 1.1),
            .init(.mars, 180, 0.5),
        ])
        let jupiter = HoraryLillyFortitudeEngine.assess(.jupiter, in: snapshot)
        #expect(jupiter.factors.contains { $0.rule == .houseTenOrOne && $0.points == 5 })
        #expect(jupiter.factors.contains { $0.rule == .direct && $0.points == 4 })
        #expect(jupiter.factors.contains { $0.rule == .swift && $0.points == 2 })

        let saturn = HoraryLillyFortitudeEngine.assess(.saturn, in: snapshot)
        #expect(saturn.factors.contains { $0.rule == .houseEightOrSix && $0.points == -2 })
        #expect(saturn.factors.contains { $0.rule == .retrograde && $0.points == -5 })
    }

    @Test("Oriental occidental and lunar light rules follow Lilly definitions")
    func orientationAndMoonLight() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 100, 1),
            .init(.mars, 130, 0.5),      // superior: within Sun->opposition arc = oriental
            .init(.saturn, 310, 0.03),   // superior: opposition->Sun arc = occidental
            .init(.venus, 80, 1.1),      // preceding Sun = oriental (debilitated in Lilly table)
            .init(.mercury, 120, 1.2),   // following Sun = occidental (fortified)
            .init(.moon, 160, 13.5),     // conjunction->opposition = increasing/occidental
            .init(.jupiter, 250, 0.1),
        ])
        #expect(HoraryLillyFortitudeEngine.assess(.mars, in: snapshot).factors.contains { $0.rule == .superiorOriental })
        #expect(HoraryLillyFortitudeEngine.assess(.saturn, in: snapshot).factors.contains { $0.rule == .superiorOccidental })
        #expect(HoraryLillyFortitudeEngine.assess(.venus, in: snapshot).factors.contains { $0.rule == .inferiorOriental })
        #expect(HoraryLillyFortitudeEngine.assess(.mercury, in: snapshot).factors.contains { $0.rule == .inferiorOccidental })
        #expect(HoraryLillyFortitudeEngine.assess(.moon, in: snapshot).factors.contains { $0.rule == .moonIncreasingOrOccidental })
    }

    @Test("Solar conditions are mutually exclusive Lilly factors")
    func solarConditions() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 100, 1),
            .init(.mercury, 100.1, 1.2), // cazimi (<17')
            .init(.venus, 105, 1.1),     // combust
            .init(.mars, 115, 0.5),      // under beams
            .init(.jupiter, 140, 0.1),   // free from beams
            .init(.moon, 220, 13),
            .init(.saturn, 280, 0.03),
        ])
        let mercury = HoraryLillyFortitudeEngine.assess(.mercury, in: snapshot)
        #expect(mercury.factors.contains { $0.rule == .cazimi })
        #expect(!mercury.factors.contains { $0.rule == .freeFromSunBeams })
        #expect(HoraryLillyFortitudeEngine.assess(.venus, in: snapshot).factors.contains { $0.rule == .combust })
        #expect(HoraryLillyFortitudeEngine.assess(.mars, in: snapshot).factors.contains { $0.rule == .underSunBeams })
        #expect(HoraryLillyFortitudeEngine.assess(.jupiter, in: snapshot).factors.contains { $0.rule == .freeFromSunBeams })
    }

    @Test("Partile aspects use exact degree-minute tolerance rather than a modern one-degree orb")
    func strictPartile() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 250, 1),
            .init(.venus, 10, 1.0),
            .init(.jupiter, 130.01, 0.1), // trine Venus within 0.01°
            .init(.mars, 100, 0.5),       // square Venus exact
            .init(.saturn, 190.5, 0.03),  // opposition is 0.5° off: must NOT count partile
            .init(.moon, 60, 13),
            .init(.mercury, 300, 1.2),
        ])
        let venus = HoraryLillyFortitudeEngine.assess(.venus, in: snapshot)
        #expect(venus.factors.contains { $0.rule == .partileTrineBenefic })
        #expect(venus.factors.contains { $0.rule == .partileSquareMalefic })
        #expect(!venus.factors.contains { $0.rule == .partileOppositionMalefic })
    }

    @Test("Lilly besieging requires the body to lie physically between Saturn and Mars in one sign")
    func strictBesieging() throws {
        let besieged = try syntheticSnapshot(points: [
            .init(.sun, 220, 1),
            .init(.saturn, 10, 0.03),
            .init(.venus, 13, 1.0),
            .init(.mars, 15, 0.5),
            .init(.moon, 60, 13),
            .init(.mercury, 120, 1.2),
            .init(.jupiter, 250, 0.1),
        ])
        #expect(HoraryLillyFortitudeEngine.assess(.venus, in: besieged).factors.contains { $0.rule == .besiegedByMalefics })

        let differentSign = try syntheticSnapshot(points: [
            .init(.sun, 220, 1),
            .init(.saturn, 29, 0.03),
            .init(.venus, 30.5, 1.0),
            .init(.mars, 32, 0.5),
            .init(.moon, 60, 13),
            .init(.mercury, 120, 1.2),
            .init(.jupiter, 250, 0.1),
        ])
        #expect(!HoraryLillyFortitudeEngine.assess(.venus, in: differentSign).factors.contains { $0.rule == .besiegedByMalefics })
    }

    @Test("Supplemental node and fixed-star testimonies are separate deterministic factors")
    func supplementalFactors() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 220, 1),
            .init(.venus, 100, 1.0),
            .init(.moon, 60, 13),
            .init(.mercury, 120, 1.2),
            .init(.mars, 180, 0.5),
            .init(.jupiter, 250, 0.1),
            .init(.saturn, 300, 0.03),
        ])
        let supplemental = HoraryLillySupplemental(
            northNodeLongitude: 100.01,
            regulusLongitude: 100.01,
            spicaLongitude: 150,
            algolLongitude: 102
        )
        let assessment = HoraryLillyFortitudeEngine.assess(.venus, in: snapshot, supplemental: supplemental)
        #expect(assessment.factors.contains { $0.rule == .partileConjunctNorthNode })
        #expect(assessment.factors.contains { $0.rule == .conjunctRegulus })
        #expect(assessment.factors.contains { $0.rule == .nearAlgol })
        #expect(!assessment.factors.contains { $0.rule == .conjunctSpica })
    }

    @Test("Swiss Ephemeris resolves Lilly node and fixed-star supplemental data")
    func resolvedSupplemental() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let supplemental = try await calculator.resolveLillySupplemental(snapshot: snapshot)
        #expect((0..<360).contains(supplemental.northNodeLongitude ?? -1))
        #expect((0..<360).contains(supplemental.regulusLongitude ?? -1))
        #expect((0..<360).contains(supplemental.spicaLongitude ?? -1))
        #expect((0..<360).contains(supplemental.algolLongitude ?? -1))
    }

    @Test("Resolved horary judgment carries Lilly fortitudes and round-trips older analysis")
    func judgedAnalysisIncludesFortitudes() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let analysis = try await HoraryEngine.judgedAnalysis(
            snapshot: snapshot,
            targetHouse: 10,
            calculator: calculator
        )
        #expect(analysis.querentFortitude?.body == analysis.querentRuler)
        #expect(analysis.targetFortitude?.body == analysis.targetRuler)
        #expect(!(analysis.querentFortitude?.factors.isEmpty ?? true))

        let data = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(HoraryAnalysis.self, from: data)
        #expect(decoded.querentFortitude == analysis.querentFortitude)
        #expect(decoded.targetFortitude == analysis.targetFortitude)
    }

    @Test("Fortitude assessment round-trips through JSON")
    func codableRoundTrip() throws {
        let assessment = HoraryFortitudeAssessment(
            body: .mars,
            factors: [
                HoraryFortitudeFactor(rule: .detriment),
                HoraryFortitudeFactor(rule: .retrograde),
            ]
        )
        let data = try JSONEncoder().encode(assessment)
        #expect(try JSONDecoder().decode(HoraryFortitudeAssessment.self, from: data) == assessment)
    }

    private var ephemerisDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
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
    private struct PositionFixture: Encodable {
        let longitudeDegrees: Double
        let latitudeDegrees: Double
        let distanceAU: Double
        let longitudeSpeedDegreesPerDay: Double
    }
    private struct PointFixture: Encodable { let body: CelestialBody; let position: PositionFixture }
    private struct HouseFixture: Encodable { let number: Int; let cuspDegrees: Double }
    private struct AnglesFixture: Encodable { let ascendantDegrees: Double; let midheavenDegrees: Double }

    private func syntheticSnapshot(points: [PointSpec]) throws -> ChartSnapshot {
        let fixture = SnapshotFixture(
            utcDate: Date(timeIntervalSince1970: 1_775_000_000),
            location: .init(latitudeDegrees: 0, longitudeDegrees: 0),
            julianDayUT: 2_460_000,
            points: points.map {
                .init(
                    body: $0.body,
                    position: .init(
                        longitudeDegrees: $0.longitude,
                        latitudeDegrees: 0,
                        distanceAU: 1,
                        longitudeSpeedDegreesPerDay: $0.speed
                    )
                )
            },
            houses: (1...12).map { .init(number: $0, cuspDegrees: Double($0 - 1) * 30) },
            angles: .init(ascendantDegrees: 0, midheavenDegrees: 270),
            aspects: []
        )
        let data = try JSONEncoder().encode(fixture)
        return try JSONDecoder().decode(ChartSnapshot.self, from: data)
    }
}
