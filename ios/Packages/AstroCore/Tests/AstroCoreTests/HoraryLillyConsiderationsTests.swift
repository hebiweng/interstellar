import AstroCore
import Foundation
import Testing

@Suite("Lilly considerations and planetary hour")
struct HoraryLillyConsiderationsTests {
    @Test("Planetary hour radicality follows same ruler triplicity or nature")
    func planetaryHourAgreement() {
        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .mars,
            ascendantRuler: .mars,
            ascendantSignIndex: 0,
            isDayChart: true
        ) == .samePlanet)

        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .mars,
            ascendantRuler: .moon,
            ascendantSignIndex: 3,
            isDayChart: true
        ) == .sameTriplicity)

        // Lilly CA p.121 explicitly gives a Mars hour with Pisces rising as
        // radical because Mars belongs to the watery triplicity, even though
        // Jupiter is the domicile ruler of Pisces.
        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .mars,
            ascendantRuler: .jupiter,
            ascendantSignIndex: 11,
            isDayChart: true
        ) == .sameTriplicity)

        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .mars,
            ascendantRuler: .sun,
            ascendantSignIndex: 4,
            isDayChart: true
        ) == .sameNature)

        // Lilly's hour-agreement examples use the day/night triplicity lords,
        // not the Dorothean participating ruler. Mars participating in Earth
        // therefore does not make a Taurus Ascendant radical by triplicity.
        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .mars,
            ascendantRuler: .venus,
            ascendantSignIndex: 1,
            isDayChart: true
        ) == .none)

        #expect(HoraryPlanetaryHourPolicy.agreement(
            hourRuler: .saturn,
            ascendantRuler: .venus,
            ascendantSignIndex: 1,
            isDayChart: true
        ) == .none)
    }

    @Test("Late Moon and void-of-course exception signs preserve Lilly cautions")
    func moonConsiderations() throws {
        let lateGemini = try syntheticSnapshot(points: [
            .init(.sun, 130, 1.0),
            .init(.moon, 88, 13.2),
            .init(.mercury, 10, 1.1),
            .init(.venus, 40, 1.0),
            .init(.mars, 70, 0.5),
            .init(.jupiter, 160, 0.1),
            .init(.saturn, 220, 0.03),
        ])
        let lateAssessment = HoraryEngine.considerations(in: lateGemini, targetHouse: 10)
        let lateFlag = try #require(lateAssessment.flags.first { $0.kind == .moonLateDegrees })
        #expect(lateFlag.severity == .strongCaution)
        #expect(lateAssessment.reliability == .caution)
        let vocFlag = try #require(lateAssessment.flags.first { $0.kind == .moonVoidOfCourse })
        #expect(vocFlag.severity == .strongCaution)

        let vocTaurus = try syntheticSnapshot(points: [
            .init(.sun, 130, 1.0),
            .init(.moon, 59.9, 13.2),
            .init(.mercury, 10, 1.1),
            .init(.venus, 80, 1.0),
            .init(.mars, 110, 0.5),
            .init(.jupiter, 160, 0.1),
            .init(.saturn, 220, 0.03),
        ])
        let taurusAssessment = HoraryEngine.considerations(in: vocTaurus, targetHouse: 10)
        let taurusVOC = try #require(taurusAssessment.flags.first { $0.kind == .moonVoidOfCourse })
        #expect(taurusVOC.severity == .advisory)
    }

    @Test("Seventh-house artist warnings are suppressed when the question itself belongs to the seventh")
    func seventhHouseException() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 130, 1.0),
            .init(.moon, 45, 13.2),
            .init(.mercury, 10, 1.1),
            .init(.venus, 185, -0.2), // Libra cusp ruler, retrograde
            .init(.mars, 70, 0.5),
            .init(.jupiter, 160, 0.1),
            .init(.saturn, 220, 0.03),
        ])
        let otherMatter = HoraryEngine.considerations(in: snapshot, targetHouse: 10)
        #expect(otherMatter.flags.contains { $0.kind == .seventhLordRetrograde })

        let seventhMatter = HoraryEngine.considerations(in: snapshot, targetHouse: 7)
        #expect(!seventhMatter.flags.contains { $0.kind == .seventhLordRetrograde })
        #expect(!seventhMatter.flags.contains { $0.kind == .seventhLordInFall })
        #expect(!seventhMatter.flags.contains { $0.kind == .seventhLordInMaleficTerm })
    }


    @Test("An unfortunate seventh lord is derived from Lilly fortitude rather than the legacy weighted score")
    func seventhLordUnfortunate() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 10, 1.0),
            .init(.moon, 45, 13.2),
            .init(.mercury, 80, 1.1),
            .init(.venus, 150, -0.2), // Venus in fall, cadent and retrograde
            .init(.mars, 260, 0.5),
            .init(.jupiter, 300, 0.1),
            .init(.saturn, 330, 0.03),
        ])
        let assessment = HoraryEngine.considerations(in: snapshot, targetHouse: 10)
        let flag = try #require(assessment.flags.first { $0.kind.rawValue == "seventhLordUnfortunate" })
        #expect(Int(flag.values?["lilly_fortitude_total"] ?? "0") ?? 0 < 0)
    }

    @Test("Seventh cusp affliction is a conservative malefic hard-aspect warning outside seventh-house matters")
    func seventhCuspAffliction() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 130, 1.0),
            .init(.moon, 45, 13.2),
            .init(.mercury, 10, 1.1),
            .init(.venus, 80, 1.0),
            .init(.mars, 90, 0.5), // square the 180° Descendant
            .init(.jupiter, 160, 0.1),
            .init(.saturn, 240, 0.03),
        ])
        let otherMatter = HoraryEngine.considerations(in: snapshot, targetHouse: 10)
        #expect(otherMatter.flags.contains { $0.kind == .seventhCuspAfflicted })

        let seventhMatter = HoraryEngine.considerations(in: snapshot, targetHouse: 7)
        #expect(!seventhMatter.flags.contains { $0.kind == .seventhCuspAfflicted })
    }

    @Test("A normal latitude resolves a planetary hour and contains the question moment")
    func resolvedPlanetaryHour() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let result = await calculator.resolveHoraryPlanetaryHour(
            snapshot: snapshot,
            timeZone: TimeZone(identifier: "Asia/Shanghai")
        )
        #expect(result.availability == .resolved)
        // Independent PySwissEphemeris reference for 2026-04-01 07:33:20
        // Asia/Shanghai at this location: sunrise 06:23:12, so the question
        // falls in the second unequal hour of Wednesday (Mercury -> Moon).
        #expect(result.dayRuler == .mercury)
        #expect(result.hourRuler == .moon)
        #expect(result.hourNumber == 2)
        if let interval = result.interval {
            #expect(interval.contains(snapshot.utcDate))
        } else {
            Issue.record("Resolved planetary hour must carry its local hour interval")
        }
    }

    @Test("Resolved horary judgement carries the planetary-hour radicality assessment")
    func judgedAnalysisCarriesPlanetaryHour() async throws {
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
            calculator: calculator,
            timeZone: TimeZone(identifier: "Asia/Shanghai")
        )
        #expect(analysis.judgment?.considerations?.planetaryHour?.availability == .resolved)
    }

    @Test("Polar sunrise or sunset failure degrades to unavailable instead of throwing")
    func polarFallback() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 12)))
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: date,
                location: GeographicLocation(latitudeDegrees: 89.0, longitudeDegrees: 0)
            ),
            configuration: .horary
        )
        let result = await calculator.resolveHoraryPlanetaryHour(
            snapshot: snapshot,
            timeZone: TimeZone(secondsFromGMT: 0)
        )
        #expect(result.availability == .unavailable)
        #expect(result.hourRuler == nil)
    }

    @Test("Radicality is explicit and unavailable planetary hours degrade without invalidating judgement")
    func explicitRadicality() throws {
        let snapshot = try syntheticSnapshot(points: [
            .init(.sun, 130, 1.0),
            .init(.moon, 45, 13.2),
            .init(.mercury, 10, 1.1),
            .init(.venus, 80, 1.0),
            .init(.mars, 110, 0.5),
            .init(.jupiter, 160, 0.1),
            .init(.saturn, 220, 0.03),
        ])

        let supportedHour = HoraryPlanetaryHourAssessment(
            availability: .resolved,
            dayRuler: .sun,
            hourRuler: .mars,
            hourNumber: 1,
            isDayHour: true,
            agreement: .sameNature
        )
        let supported = HoraryEngine.considerations(
            in: snapshot,
            targetHouse: 10,
            planetaryHour: supportedHour
        )
        #expect(supported.radicality?.status == .supported)

        let discordantHour = HoraryPlanetaryHourAssessment(
            availability: .resolved,
            dayRuler: .sun,
            hourRuler: .saturn,
            hourNumber: 1,
            isDayHour: true,
            agreement: .none
        )
        let discordant = HoraryEngine.considerations(
            in: snapshot,
            targetHouse: 10,
            planetaryHour: discordantHour
        )
        #expect(discordant.radicality?.status == .notEstablished)
        #expect(discordant.flags.contains { $0.kind == .planetaryHourDiscordant })

        let unavailable = HoraryEngine.considerations(
            in: snapshot,
            targetHouse: 10,
            planetaryHour: .unavailable
        )
        #expect(unavailable.radicality?.status == .unavailable)
        #expect(!unavailable.flags.contains { $0.kind == .planetaryHourDiscordant })
    }

    @Test("Polar planetary-hour failure does not prevent a resolved horary judgement")
    func polarJudgedAnalysisFallback() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 12)))
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: date,
                location: GeographicLocation(latitudeDegrees: 89.0, longitudeDegrees: 0)
            ),
            configuration: .horary
        )
        let analysis = try await HoraryEngine.judgedAnalysis(
            snapshot: snapshot,
            targetHouse: 10,
            calculator: calculator,
            timeZone: TimeZone(secondsFromGMT: 0)
        )
        #expect(analysis.judgment != nil)
        #expect(analysis.judgment?.considerations?.planetaryHour?.availability == .unavailable)
        #expect(analysis.judgment?.considerations?.radicality?.status == .unavailable)
    }

    @Test("Consumer reliability treats strong Lilly warnings as caution and radicality gaps as reservations")
    func reliabilitySynthesis() {
        let supported = HoraryRadicalityAssessment(status: .supported, agreement: .samePlanet)
        let unsupported = HoraryRadicalityAssessment(status: .notEstablished, agreement: .none)
        let unavailable = HoraryRadicalityAssessment(status: .unavailable, agreement: .unavailable)
        #expect(HoraryConsiderationPolicy.reliability(flags: [], radicality: supported) == .high)
        #expect(HoraryConsiderationPolicy.reliability(flags: [], radicality: unsupported) == .moderate)
        #expect(HoraryConsiderationPolicy.reliability(flags: [], radicality: unavailable) == .moderate)
        #expect(HoraryConsiderationPolicy.reliability(
            flags: [.init(kind: .earlyAscendant, severity: .strongCaution)],
            radicality: supported
        ) == .caution)
        #expect(HoraryConsiderationPolicy.reliability(
            flags: [.init(kind: .planetaryHourDiscordant, severity: .advisory)],
            radicality: unsupported
        ) == .moderate)
    }

    @Test("Legacy consideration JSON without radicality still decodes")
    func legacyConsiderationDecoding() throws {
        let json = #"{"reliability":"moderate","flags":[],"planetaryHour":null}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HoraryConsiderationAssessment.self, from: json)
        #expect(decoded.reliability == .moderate)
        #expect(decoded.radicality == nil)
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

    private var ephemerisDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }
}
