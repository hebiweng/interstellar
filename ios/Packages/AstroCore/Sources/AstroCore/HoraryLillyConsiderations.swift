import CSwissEphemeris
import Foundation

public enum HoraryConsiderationKind: String, Sendable, Equatable, Codable, CaseIterable {
    case planetaryHourDiscordant
    case earlyAscendant
    case lateAscendant
    case moonLateDegrees
    case moonViaCombusta
    case moonVoidOfCourse
    case saturnInAscendant
    case saturnInSeventh
    case ascendantLordCombust
    case seventhLordRetrograde
    case seventhLordInFall
    case seventhCuspAfflicted
    case seventhLordUnfortunate
    case seventhLordInMaleficTerm
    case saturnInTenthUnfortunate
    case marsInTenthUnfortunate
    case southNodeInTenth
}

public enum HoraryConsiderationSeverity: String, Sendable, Equatable, Codable {
    case advisory
    case strongCaution
}

public struct HoraryConsiderationFlag: Sendable, Equatable, Codable, Identifiable {
    public let kind: HoraryConsiderationKind
    public let severity: HoraryConsiderationSeverity
    public let evidenceID: String
    public let values: [String: String]?

    public var id: String { evidenceID }

    public init(
        kind: HoraryConsiderationKind,
        severity: HoraryConsiderationSeverity,
        values: [String: String]? = nil
    ) {
        self.kind = kind
        self.severity = severity
        self.evidenceID = "lilly.consideration.\(kind.rawValue)"
        self.values = values
    }
}

/// Consumer-facing synthesis of Lilly's considerations before judgement.
/// This never invalidates a chart by itself: the original flags remain available
/// so professional views can show the exact reason for caution.
public enum HoraryJudgmentReliability: String, Sendable, Equatable, Codable {
    case high
    case moderate
    case caution
}

public enum HoraryRadicalityStatus: String, Sendable, Equatable, Codable {
    case supported
    case notEstablished
    case unavailable
}

public struct HoraryRadicalityAssessment: Sendable, Equatable, Codable {
    public let status: HoraryRadicalityStatus
    public let evidenceID: String
    public let agreement: HoraryHourAscendantAgreement

    public init(status: HoraryRadicalityStatus, agreement: HoraryHourAscendantAgreement) {
        self.status = status
        self.agreement = agreement
        self.evidenceID = "lilly.radicality.\(status.rawValue)"
    }
}

public enum HoraryPlanetaryHourAvailability: String, Sendable, Equatable, Codable {
    case resolved
    case unavailable
}

public enum HoraryHourAscendantAgreement: String, Sendable, Equatable, Codable {
    case samePlanet
    case sameTriplicity
    case sameNature
    case none
    case unavailable
}

public struct HoraryPlanetaryHourAssessment: Sendable, Equatable, Codable {
    public let availability: HoraryPlanetaryHourAvailability
    public let dayRuler: CelestialBody?
    public let hourRuler: CelestialBody?
    /// 1...12 are daytime planetary hours; 13...24 are the following nighttime hours.
    public let hourNumber: Int?
    public let isDayHour: Bool?
    public let interval: DateInterval?
    public let agreement: HoraryHourAscendantAgreement

    public init(
        availability: HoraryPlanetaryHourAvailability,
        dayRuler: CelestialBody? = nil,
        hourRuler: CelestialBody? = nil,
        hourNumber: Int? = nil,
        isDayHour: Bool? = nil,
        interval: DateInterval? = nil,
        agreement: HoraryHourAscendantAgreement = .unavailable
    ) {
        self.availability = availability
        self.dayRuler = dayRuler
        self.hourRuler = hourRuler
        self.hourNumber = hourNumber
        self.isDayHour = isDayHour
        self.interval = interval
        self.agreement = agreement
    }

    public static let unavailable = HoraryPlanetaryHourAssessment(availability: .unavailable)
}

public enum HoraryConsiderationPolicy {
    public static func reliability(
        flags: [HoraryConsiderationFlag],
        radicality: HoraryRadicalityAssessment?
    ) -> HoraryJudgmentReliability {
        if flags.contains(where: { $0.severity == .strongCaution }) {
            // Consumer synthesis only: this surfaces Lilly's strongest warnings
            // without turning them into a modern hard "chart invalid" gate.
            return .caution
        }
        if !flags.isEmpty || radicality?.status == .notEstablished || radicality?.status == .unavailable {
            // Missing/discordant technical radicality is a reservation, not a failed chart.
            return .moderate
        }
        return .high
    }
}

public struct HoraryConsiderationAssessment: Sendable, Equatable, Codable {
    public let reliability: HoraryJudgmentReliability
    public let flags: [HoraryConsiderationFlag]
    public let planetaryHour: HoraryPlanetaryHourAssessment?
    /// Technical radicality per Lilly CA p.121. This is calibration evidence,
    /// not a hard validity gate for the chart.
    public let radicality: HoraryRadicalityAssessment?

    public init(
        reliability: HoraryJudgmentReliability,
        flags: [HoraryConsiderationFlag],
        planetaryHour: HoraryPlanetaryHourAssessment? = nil,
        radicality: HoraryRadicalityAssessment? = nil
    ) {
        self.reliability = reliability
        self.flags = flags
        self.planetaryHour = planetaryHour
        self.radicality = radicality
    }
}

/// Lilly CA p.121: a question is radical when the hour lord and Ascendant lord
/// are the same planet, belong to the Ascendant's triplicity, or share the same nature.
public enum HoraryPlanetaryHourPolicy {
    public static func radicality(
        for assessment: HoraryPlanetaryHourAssessment?
    ) -> HoraryRadicalityAssessment? {
        guard let assessment else { return nil }
        switch assessment.availability {
        case .unavailable:
            return HoraryRadicalityAssessment(status: .unavailable, agreement: .unavailable)
        case .resolved:
            switch assessment.agreement {
            case .samePlanet, .sameTriplicity, .sameNature:
                return HoraryRadicalityAssessment(status: .supported, agreement: assessment.agreement)
            case .none:
                return HoraryRadicalityAssessment(status: .notEstablished, agreement: .none)
            case .unavailable:
                return HoraryRadicalityAssessment(status: .unavailable, agreement: .unavailable)
            }
        }
    }

    public static func agreement(
        hourRuler: CelestialBody,
        ascendantRuler: CelestialBody,
        ascendantSignIndex: Int,
        isDayChart: Bool
    ) -> HoraryHourAscendantAgreement {
        if hourRuler == ascendantRuler { return .samePlanet }

        // Lilly's examples on CA p.121 test whether the hour ruler is one
        // of the day/night lords of the triplicity of the rising sign. The
        // participating Dorothean ruler is not used for this radicality test.
        let triplicity = HoraryEngine.triplicityRulers(
            ofSign: ascendantSignIndex,
            isDayChart: isDayChart
        )
        if triplicity.prefix(2).contains(hourRuler) {
            return .sameTriplicity
        }

        if let first = temperament(hourRuler), let second = temperament(ascendantRuler), first == second {
            return .sameNature
        }
        return .none
    }

    private enum Temperament: Equatable {
        case hotDry
        case hotMoist
        case coldDry
        case coldMoist
    }

    /// Stable planetary natures used for Lilly's p.121 radicality comparison.
    /// Mercury is intentionally omitted: Lilly treats its nature as mutable rather
    /// than giving it one fixed pair that can safely satisfy this test.
    private static func temperament(_ body: CelestialBody) -> Temperament? {
        switch body {
        case .sun, .mars: .hotDry
        case .jupiter: .hotMoist
        case .saturn: .coldDry
        case .venus, .moon: .coldMoist
        case .mercury: nil
        default: nil
        }
    }
}

extension HoraryEngine {
    /// Lilly, Christian Astrology pp.121-123: last 15° Libra through first 15° Scorpio.
    public static func isViaCombusta(longitudeDegrees: Double) -> Bool {
        let longitude = normalizeForLilly(longitudeDegrees)
        return longitude >= 195 && longitude < 225
    }

    /// Synchronous consideration pass used by instant UI and compatibility paths.
    /// The resolved judgement path supplies the planetary-hour and supplemental
    /// ephemeris facts via the optional arguments below.
    public static func considerations(
        in snapshot: ChartSnapshot,
        targetHouse: Int? = nil,
        planetaryHour: HoraryPlanetaryHourAssessment? = nil,
        supplemental: HoraryLillySupplemental = HoraryLillySupplemental()
    ) -> HoraryConsiderationAssessment {
        var flags: [HoraryConsiderationFlag] = []

        if let planetaryHour,
           planetaryHour.availability == .resolved,
           planetaryHour.agreement == .none
        {
            flags.append(.init(
                kind: .planetaryHourDiscordant,
                severity: .advisory,
                values: planetaryHour.hourRuler.map { ["hour_ruler": $0.rawValue] }
            ))
        }

        let ascendant = normalizeForLilly(snapshot.angles.ascendantDegrees)
        let ascDegree = ascendant.truncatingRemainder(dividingBy: 30)
        if ascDegree < 3 {
            flags.append(.init(kind: .earlyAscendant, severity: .strongCaution))
        } else if ascDegree >= 27 {
            flags.append(.init(kind: .lateAscendant, severity: .strongCaution))
        }

        if let moon = snapshot.point(.moon) {
            if moon.degreeInSign >= 27 {
                let especiallyCautious = [2, 7, 9].contains(moon.signIndex) // Gemini, Scorpio, Capricorn
                flags.append(.init(
                    kind: .moonLateDegrees,
                    severity: especiallyCautious ? .strongCaution : .advisory,
                    values: [
                        "sign_index": String(moon.signIndex),
                        "degree": String(moon.degreeInSign),
                    ]
                ))
            }
            if isViaCombusta(longitudeDegrees: moon.longitudeDegrees) {
                flags.append(.init(kind: .moonViaCombusta, severity: .strongCaution))
            }
            if moonCondition(in: snapshot).isVoidOfCourse {
                // Lilly explicitly softens the VOC warning in Taurus, Cancer,
                // Sagittarius and Pisces (CA p.122 / aphorism 9).
                let exceptionSign = [1, 3, 8, 11].contains(moon.signIndex)
                flags.append(.init(
                    kind: .moonVoidOfCourse,
                    severity: exceptionSign ? .advisory : .strongCaution,
                    values: exceptionSign ? ["lilly_exception_sign": "true"] : nil
                ))
            }
        }

        if let saturn = snapshot.point(.saturn) {
            let house = snapshot.house(containing: saturn.longitudeDegrees)
            if house == 1 {
                let retrograde = saturn.position.longitudeSpeedDegreesPerDay < 0
                flags.append(.init(
                    kind: .saturnInAscendant,
                    severity: .strongCaution,
                    values: retrograde ? ["retrograde": "true"] : nil
                ))
            }
            if house == 7 {
                flags.append(.init(kind: .saturnInSeventh, severity: .strongCaution))
            }
        }

        let ascLord = ruler(ofHouse: 1, in: snapshot)
        if assess(ascLord, in: snapshot).conditions.contains(.combust) {
            flags.append(.init(kind: .ascendantLordCombust, severity: .strongCaution))
        }

        // Lilly's seventh-house warning is specifically suspended when the
        // matter itself concerns the seventh house (CA p.122).
        if targetHouse != 7 {
            if isSeventhCuspAfflicted(in: snapshot) {
                flags.append(.init(kind: .seventhCuspAfflicted, severity: .advisory))
            }
            let seventhLord = ruler(ofHouse: 7, in: snapshot)
            let seventhAssessment = assess(seventhLord, in: snapshot)
            let seventhFortitude = HoraryLillyFortitudeEngine.assess(
                seventhLord,
                in: snapshot,
                supplemental: supplemental
            )
            if seventhFortitude.total < 0 {
                flags.append(.init(
                    kind: .seventhLordUnfortunate,
                    severity: .advisory,
                    values: ["lilly_fortitude_total": String(seventhFortitude.total)]
                ))
            }
            if seventhAssessment.conditions.contains(.retrograde) {
                flags.append(.init(kind: .seventhLordRetrograde, severity: .advisory))
            }
            if seventhAssessment.conditions.contains(.fall) {
                flags.append(.init(kind: .seventhLordInFall, severity: .advisory))
            }
            if let seventhPoint = snapshot.point(seventhLord) {
                let term = termRuler(ofSign: seventhPoint.signIndex, degreeInSign: seventhPoint.degreeInSign)
                if term == .saturn || term == .mars {
                    flags.append(.init(kind: .seventhLordInMaleficTerm, severity: .advisory))
                }
            }
        }

        // Lilly later repeats his cautions in CA pp.298-302: an unfortunate
        // Mars or Saturn in the 10th, or the South Node there, harms the artist's credit.
        for malefic in [CelestialBody.saturn, .mars] {
            guard let point = snapshot.point(malefic), snapshot.house(containing: point.longitudeDegrees) == 10 else { continue }
            let fortitude = HoraryLillyFortitudeEngine.assess(malefic, in: snapshot, supplemental: supplemental)
            let peregrine = fortitude.factors.contains { $0.rule == .peregrine }
            if peregrine || fortitude.total < 0 {
                flags.append(.init(
                    kind: malefic == .saturn ? .saturnInTenthUnfortunate : .marsInTenthUnfortunate,
                    severity: .advisory,
                    values: ["lilly_fortitude_total": String(fortitude.total)]
                ))
            }
        }
        if let north = supplemental.northNodeLongitude {
            let south = normalizeForLilly(north + 180)
            if snapshot.house(containing: south) == 10 {
                flags.append(.init(kind: .southNodeInTenth, severity: .advisory))
            }
        }

        let radicality = HoraryPlanetaryHourPolicy.radicality(for: planetaryHour)
        let reliability = HoraryConsiderationPolicy.reliability(
            flags: flags,
            radicality: radicality
        )
        return HoraryConsiderationAssessment(
            reliability: reliability,
            flags: flags,
            planetaryHour: planetaryHour,
            radicality: radicality
        )
    }

    /// Conservative, deterministic reading of Lilly's "cusp of the seventh afflicted".
    /// Lilly does not spell out a bespoke orb in the consideration itself. We therefore
    /// use only the traditional infortunes (Mars/Saturn), only conjunction/square/opposition,
    /// and the traditional cusp-aspect allowance: 5° cusp orb plus the planet's moiety.
    private static func isSeventhCuspAfflicted(in snapshot: ChartSnapshot) -> Bool {
        guard let cusp = snapshot.houses.first(where: { $0.number == 7 })?.cuspDegrees else { return false }
        let hardAngles = [0.0, 90.0, 180.0]
        for body in [CelestialBody.mars, .saturn] {
            guard let point = snapshot.point(body) else { continue }
            let separation = abs(shortSignedSeparationForLilly(cusp, point.longitudeDegrees))
            let distance = hardAngles.map { abs(separation - $0) }.min() ?? 180
            let planetOrb = body == .mars ? 8.0 : 9.0
            let allowed = 5.0 + planetOrb / 2.0
            if distance <= allowed { return true }
        }
        return false
    }

    private static func shortSignedSeparationForLilly(_ first: Double, _ second: Double) -> Double {
        var value = normalizeForLilly(second) - normalizeForLilly(first)
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }

    private static func normalizeForLilly(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }
}

public extension SwissEphemerisCalculator {
    /// Resolves the traditional planetary hour from the local sunrise/sunset
    /// cycle. If a daily solar rise/set cycle cannot be resolved (for example
    /// during polar day/night), this returns `.unavailable` rather than failing
    /// the horary judgement.
    func resolveHoraryPlanetaryHour(
        snapshot: ChartSnapshot,
        timeZone: TimeZone? = nil
    ) -> HoraryPlanetaryHourAssessment {
        let jd = snapshot.julianDayUT
        guard let previousRise = previousSolarEvent(before: jd, location: snapshot.location, event: Int32(SE_CALC_RISE)),
              let previousSet = previousSolarEvent(before: jd, location: snapshot.location, event: Int32(SE_CALC_SET)),
              let nextRise = nextSolarEvent(after: jd, location: snapshot.location, event: Int32(SE_CALC_RISE)),
              let nextSet = nextSolarEvent(after: jd, location: snapshot.location, event: Int32(SE_CALC_SET)),
              abs(jd - previousRise) <= 2.1,
              abs(jd - previousSet) <= 2.1,
              abs(nextRise - jd) <= 2.1,
              abs(nextSet - jd) <= 2.1
        else {
            return .unavailable
        }

        let isDayHour = previousRise > previousSet
        let periodStart = isDayHour ? previousRise : previousSet
        let periodEnd = isDayHour ? nextSet : nextRise
        guard periodEnd > periodStart else { return .unavailable }

        let planetaryHourDays = (periodEnd - periodStart) / 12
        guard planetaryHourDays > 0 else { return .unavailable }
        let indexWithinHalf = min(11, max(0, Int(floor((jd - periodStart) / planetaryHourDays))))
        let hourOffset = (isDayHour ? 0 : 12) + indexWithinHalf
        let hourNumber = hourOffset + 1

        let daySunrise = previousRise
        let dayRuler = planetaryDayRuler(
            sunrise: date(fromJulianDay: daySunrise),
            location: snapshot.location,
            timeZone: timeZone
        )
        guard let dayRuler else { return .unavailable }
        let hourRuler = planetaryHourRuler(dayRuler: dayRuler, offset: hourOffset)
        let ascendantSign = Int(normalizeLongitude(snapshot.angles.ascendantDegrees) / 30)
        let ascendantRuler = HoraryEngine.ruler(ofHouse: 1, in: snapshot)
        let agreement = HoraryPlanetaryHourPolicy.agreement(
            hourRuler: hourRuler,
            ascendantRuler: ascendantRuler,
            ascendantSignIndex: ascendantSign,
            isDayChart: HoraryEngine.isDayChart(snapshot)
        )

        let interval = DateInterval(
            start: date(fromJulianDay: periodStart + Double(indexWithinHalf) * planetaryHourDays),
            end: date(fromJulianDay: periodStart + Double(indexWithinHalf + 1) * planetaryHourDays)
        )
        return HoraryPlanetaryHourAssessment(
            availability: .resolved,
            dayRuler: dayRuler,
            hourRuler: hourRuler,
            hourNumber: hourNumber,
            isDayHour: isDayHour,
            interval: interval,
            agreement: agreement
        )
    }

    private func solarEvent(
        after julianDay: Double,
        location: GeographicLocation,
        event: Int32
    ) -> Double? {
        var geopos = [location.longitudeDegrees, location.latitudeDegrees, 0.0]
        var resultJD = 0.0
        var error = [CChar](repeating: 0, count: 256)
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        let status = geopos.withUnsafeMutableBufferPointer { geoBuffer in
            error.withUnsafeMutableBufferPointer { errorBuffer in
                swe_rise_trans(
                    julianDay,
                    Int32(SE_SUN),
                    nil,
                    Int32(SEFLG_SWIEPH),
                    event,
                    geoBuffer.baseAddress,
                    0,
                    0,
                    &resultJD,
                    errorBuffer.baseAddress
                )
            }
        }
        guard status >= 0, resultJD.isFinite else { return nil }
        return resultJD
    }

    private func nextSolarEvent(
        after julianDay: Double,
        location: GeographicLocation,
        event: Int32
    ) -> Double? {
        solarEvent(after: julianDay + 1.0 / 86_400.0, location: location, event: event)
    }

    private func previousSolarEvent(
        before julianDay: Double,
        location: GeographicLocation,
        event: Int32
    ) -> Double? {
        var cursor = julianDay - 2.1
        var latest: Double?
        for _ in 0 ..< 5 {
            guard let candidate = solarEvent(after: cursor, location: location, event: event) else { return latest }
            if candidate > julianDay { break }
            latest = candidate
            cursor = candidate + 1.0 / 1_440.0 // one minute past the event
        }
        return latest
    }

    private func planetaryDayRuler(
        sunrise: Date,
        location: GeographicLocation,
        timeZone: TimeZone?
    ) -> CelestialBody? {
        let resolvedTimeZone = timeZone ?? TimeZone(
            secondsFromGMT: Int((location.longitudeDegrees * 240).rounded())
        )
        guard let resolvedTimeZone else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = resolvedTimeZone
        switch calendar.component(.weekday, from: sunrise) {
        case 1: return .sun
        case 2: return .moon
        case 3: return .mars
        case 4: return .mercury
        case 5: return .jupiter
        case 6: return .venus
        case 7: return .saturn
        default: return nil
        }
    }

    private func planetaryHourRuler(dayRuler: CelestialBody, offset: Int) -> CelestialBody {
        let chaldean: [CelestialBody] = [.saturn, .jupiter, .mars, .sun, .venus, .mercury, .moon]
        guard let start = chaldean.firstIndex(of: dayRuler) else { return dayRuler }
        return chaldean[(start + offset) % chaldean.count]
    }

    private func date(fromJulianDay julianDay: Double) -> Date {
        Date(timeIntervalSince1970: (julianDay - 2_440_587.5) * 86_400)
    }

    private func normalizeLongitude(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }
}
