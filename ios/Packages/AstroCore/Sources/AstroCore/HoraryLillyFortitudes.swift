import CSwissEphemeris
import Foundation

public enum HoraryFortitudeCategory: String, Sendable, Equatable, Codable {
    case essentialFortitude
    case essentialDebility
    case accidentalFortitude
    case accidentalDebility
}

/// William Lilly, Christian Astrology, p.115 — the table of essential and accidental
/// fortitudes and debilities. Points are deliberately kept as Lilly's table values;
/// this is not a probability model.
public enum HoraryFortitudeRule: String, CaseIterable, Sendable, Equatable, Codable {
    case ownHouseOrMutualReceptionByHouse
    case exaltationOrMutualReceptionByExaltation
    case triplicity
    case term
    case face
    case detriment
    case fall
    case peregrine

    case houseTenOrOne
    case houseSevenFourOrEleven
    case houseTwoOrFive
    case houseNine
    case houseThree
    case houseTwelve
    case houseEightOrSix

    case direct
    case retrograde
    case swift
    case slow
    case superiorOriental
    case superiorOccidental
    case inferiorOccidental
    case inferiorOriental
    case moonIncreasingOrOccidental
    case moonDecreasing

    case freeFromSunBeams
    case cazimi
    case combust
    case underSunBeams

    case partileConjunctBenefic
    case partileConjunctNorthNode
    case partileTrineBenefic
    case partileSextileBenefic
    case partileConjunctMalefic
    case partileConjunctSouthNode
    case besiegedByMalefics
    case partileOppositionMalefic
    case partileSquareMalefic

    case conjunctRegulus
    case conjunctSpica
    case nearAlgol

    public var points: Int {
        switch self {
        case .ownHouseOrMutualReceptionByHouse: 5
        case .exaltationOrMutualReceptionByExaltation: 4
        case .triplicity: 3
        case .term: 2
        case .face: 1
        case .detriment: -5
        case .fall: -4
        case .peregrine: -5
        case .houseTenOrOne: 5
        case .houseSevenFourOrEleven: 4
        case .houseTwoOrFive: 3
        case .houseNine: 2
        case .houseThree: 1
        case .houseTwelve: -5
        case .houseEightOrSix: -2
        case .direct: 4
        case .retrograde: -5
        case .swift: 2
        case .slow: -2
        case .superiorOriental: 2
        case .superiorOccidental: -2
        case .inferiorOccidental: 2
        case .inferiorOriental: -2
        case .moonIncreasingOrOccidental: 2
        case .moonDecreasing: -2
        case .freeFromSunBeams: 5
        case .cazimi: 5
        case .combust: -5
        case .underSunBeams: -4
        case .partileConjunctBenefic: 5
        case .partileConjunctNorthNode: 4
        case .partileTrineBenefic: 4
        case .partileSextileBenefic: 3
        case .partileConjunctMalefic: -5
        case .partileConjunctSouthNode: -4
        case .besiegedByMalefics: -4
        case .partileOppositionMalefic: -4
        case .partileSquareMalefic: -4
        case .conjunctRegulus: 6
        case .conjunctSpica: 5
        case .nearAlgol: -4
        }
    }

    public var category: HoraryFortitudeCategory {
        switch self {
        case .ownHouseOrMutualReceptionByHouse, .exaltationOrMutualReceptionByExaltation, .triplicity, .term, .face:
            .essentialFortitude
        case .detriment, .fall, .peregrine:
            .essentialDebility
        case .houseTenOrOne, .houseSevenFourOrEleven, .houseTwoOrFive, .houseNine, .houseThree,
             .direct, .swift, .superiorOriental, .inferiorOccidental, .moonIncreasingOrOccidental,
             .freeFromSunBeams, .cazimi, .partileConjunctBenefic, .partileConjunctNorthNode,
             .partileTrineBenefic, .partileSextileBenefic, .conjunctRegulus, .conjunctSpica:
            .accidentalFortitude
        case .houseTwelve, .houseEightOrSix, .retrograde, .slow, .superiorOccidental,
             .inferiorOriental, .moonDecreasing, .combust, .underSunBeams,
             .partileConjunctMalefic, .partileConjunctSouthNode, .besiegedByMalefics,
             .partileOppositionMalefic, .partileSquareMalefic, .nearAlgol:
            .accidentalDebility
        }
    }
}

public struct HoraryFortitudeFactor: Sendable, Equatable, Codable, Identifiable {
    public let rule: HoraryFortitudeRule
    public let points: Int
    public let values: [String: String]

    public var id: String { rule.rawValue }

    public init(
        rule: HoraryFortitudeRule,
        points: Int? = nil,
        values: [String: String] = [:]
    ) {
        self.rule = rule
        self.points = points ?? rule.points
        self.values = values
    }
}

public struct HoraryFortitudeAssessment: Sendable, Equatable, Codable {
    public let body: CelestialBody
    public let factors: [HoraryFortitudeFactor]

    public init(body: CelestialBody, factors: [HoraryFortitudeFactor]) {
        self.body = body
        self.factors = factors
    }

    public var total: Int { factors.reduce(0) { $0 + $1.points } }
    public var essentialFortitudes: [HoraryFortitudeFactor] { factors.filter { $0.rule.category == .essentialFortitude } }
    public var essentialDebilities: [HoraryFortitudeFactor] { factors.filter { $0.rule.category == .essentialDebility } }
    public var accidentalFortitudes: [HoraryFortitudeFactor] { factors.filter { $0.rule.category == .accidentalFortitude } }
    public var accidentalDebilities: [HoraryFortitudeFactor] { factors.filter { $0.rule.category == .accidentalDebility } }
}

/// Ephemeris facts Lilly's p.115 table uses but that intentionally do not belong in
/// the seven-planet horary wheel itself.
public struct HoraryLillySupplemental: Sendable, Equatable, Codable {
    public let northNodeLongitude: Double?
    public let regulusLongitude: Double?
    public let spicaLongitude: Double?
    public let algolLongitude: Double?

    public init(
        northNodeLongitude: Double? = nil,
        regulusLongitude: Double? = nil,
        spicaLongitude: Double? = nil,
        algolLongitude: Double? = nil
    ) {
        self.northNodeLongitude = northNodeLongitude
        self.regulusLongitude = regulusLongitude
        self.spicaLongitude = spicaLongitude
        self.algolLongitude = algolLongitude
    }
}

public enum HoraryLillyFortitudeEngine {
    /// A one-arc-minute numerical tolerance is used for Lilly's partile requirement.
    /// It deliberately does not broaden the rule to the modern shorthand "within 1°".
    public static let partileToleranceDegrees = 1.0 / 60.0

    public static func assess(
        _ body: CelestialBody,
        in snapshot: ChartSnapshot,
        counterpart: CelestialBody? = nil,
        supplemental: HoraryLillySupplemental = HoraryLillySupplemental()
    ) -> HoraryFortitudeAssessment {
        guard HoraryEngine.traditionalPlanets.contains(body), let point = snapshot.point(body) else {
            return HoraryFortitudeAssessment(body: body, factors: [])
        }

        var factors: [HoraryFortitudeFactor] = []
        let sign = point.signIndex
        let degree = point.degreeInSign
        let day = HoraryEngine.isDayChart(snapshot)
        let held = HoraryEngine.essentialDignitiesHeld(
            by: body,
            atSign: sign,
            degreeInSign: degree,
            isDayChart: day
        )

        let mutualHouse = counterpart.map {
            mutualReception(body, $0, in: snapshot, dignity: .domicile)
        } ?? false
        if held.contains(.domicile) || mutualHouse {
            factors.append(.init(
                rule: .ownHouseOrMutualReceptionByHouse,
                values: mutualHouse && !held.contains(.domicile) ? ["via": "mutual_reception"] : [:]
            ))
        }

        let mutualExaltation = counterpart.map {
            mutualReception(body, $0, in: snapshot, dignity: .exaltation)
        } ?? false
        if held.contains(.exaltation) || mutualExaltation {
            factors.append(.init(
                rule: .exaltationOrMutualReceptionByExaltation,
                values: mutualExaltation && !held.contains(.exaltation) ? ["via": "mutual_reception"] : [:]
            ))
        }
        if held.contains(.triplicity) { factors.append(.init(rule: .triplicity)) }
        if held.contains(.term) { factors.append(.init(rule: .term)) }
        if held.contains(.face) { factors.append(.init(rule: .face)) }

        if HoraryEngine.ruler(ofSign: oppositeSign(sign)) == body {
            factors.append(.init(rule: .detriment))
        }
        if exaltationRuler(ofSign: oppositeSign(sign)) == body {
            factors.append(.init(rule: .fall))
        }
        if held.isEmpty {
            factors.append(.init(rule: .peregrine))
        }

        appendHouseFactor(snapshot.house(containing: point.longitudeDegrees), to: &factors)
        appendMotionFactors(body: body, point: point, to: &factors)
        appendOrientationFactor(body: body, snapshot: snapshot, to: &factors)
        appendSolarFactor(body: body, snapshot: snapshot, to: &factors)
        appendPlanetaryAspectFactors(body: body, snapshot: snapshot, to: &factors)
        appendBesiegingFactor(body: body, snapshot: snapshot, to: &factors)
        appendSupplementalFactors(body: body, point: point, supplemental: supplemental, to: &factors)

        return HoraryFortitudeAssessment(body: body, factors: factors)
    }

    private static func mutualReception(
        _ first: CelestialBody,
        _ second: CelestialBody,
        in snapshot: ChartSnapshot,
        dignity: EssentialDignityKind
    ) -> Bool {
        let firstReceivedBySecond = HoraryEngine.reception(from: first, to: second, in: snapshot)
        let secondReceivedByFirst = HoraryEngine.reception(from: second, to: first, in: snapshot)
        return firstReceivedBySecond.dignities.contains(dignity)
            && secondReceivedByFirst.dignities.contains(dignity)
    }

    private static func appendHouseFactor(_ house: Int, to factors: inout [HoraryFortitudeFactor]) {
        let rule: HoraryFortitudeRule?
        switch house {
        case 10, 1: rule = .houseTenOrOne
        case 7, 4, 11: rule = .houseSevenFourOrEleven
        case 2, 5: rule = .houseTwoOrFive
        case 9: rule = .houseNine
        case 3: rule = .houseThree
        case 12: rule = .houseTwelve
        case 8, 6: rule = .houseEightOrSix
        default: rule = nil
        }
        if let rule { factors.append(.init(rule: rule, values: ["house": String(house)])) }
    }

    private static func appendMotionFactors(
        body: CelestialBody,
        point: ChartPoint,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        let speed = point.position.longitudeSpeedDegreesPerDay
        if body != .sun, body != .moon {
            factors.append(.init(rule: speed < 0 ? .retrograde : .direct))
        }
        if let mean = meanDailyMotion(body) {
            let actual = abs(speed)
            if actual > mean + 0.000_001 {
                factors.append(.init(rule: .swift, values: ["speed": String(actual), "mean": String(mean)]))
            } else if actual < mean - 0.000_001 {
                factors.append(.init(rule: .slow, values: ["speed": String(actual), "mean": String(mean)]))
            }
        }
    }

    private static func appendOrientationFactor(
        body: CelestialBody,
        snapshot: ChartSnapshot,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        guard let point = snapshot.point(body), let sun = snapshot.point(.sun), body != .sun else { return }
        let bodyFromSun = normalize(point.longitudeDegrees - sun.longitudeDegrees)
        switch body {
        case .saturn, .jupiter, .mars:
            factors.append(.init(rule: bodyFromSun > 0 && bodyFromSun < 180 ? .superiorOriental : .superiorOccidental))
        case .mercury, .venus:
            // Inferiors preceding the Sun in zodiacal order are oriental; following are occidental.
            factors.append(.init(rule: bodyFromSun > 180 ? .inferiorOriental : .inferiorOccidental))
        case .moon:
            factors.append(.init(rule: bodyFromSun > 0 && bodyFromSun < 180 ? .moonIncreasingOrOccidental : .moonDecreasing))
        default:
            break
        }
    }

    private static func appendSolarFactor(
        body: CelestialBody,
        snapshot: ChartSnapshot,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        guard body != .sun, let point = snapshot.point(body), let sun = snapshot.point(.sun) else { return }
        let distance = angularDistance(point.longitudeDegrees, sun.longitudeDegrees)
        if distance <= 17.0 / 60.0 {
            factors.append(.init(rule: .cazimi, values: ["distance_degrees": String(distance)]))
        } else if distance <= 8.5 {
            factors.append(.init(rule: .combust, values: ["distance_degrees": String(distance)]))
        } else if distance <= 17 {
            factors.append(.init(rule: .underSunBeams, values: ["distance_degrees": String(distance)]))
        } else {
            factors.append(.init(rule: .freeFromSunBeams, values: ["distance_degrees": String(distance)]))
        }
    }

    private static func appendPlanetaryAspectFactors(
        body: CelestialBody,
        snapshot: ChartSnapshot,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        guard let point = snapshot.point(body) else { return }
        for benefic in [CelestialBody.jupiter, .venus] where benefic != body {
            guard let other = snapshot.point(benefic) else { continue }
            if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .conjunction) {
                factors.append(.init(rule: .partileConjunctBenefic, values: ["other": benefic.rawValue]))
            } else if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .trine) {
                factors.append(.init(rule: .partileTrineBenefic, values: ["other": benefic.rawValue]))
            } else if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .sextile) {
                factors.append(.init(rule: .partileSextileBenefic, values: ["other": benefic.rawValue]))
            }
        }
        for malefic in [CelestialBody.saturn, .mars] where malefic != body {
            guard let other = snapshot.point(malefic) else { continue }
            if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .conjunction) {
                factors.append(.init(rule: .partileConjunctMalefic, values: ["other": malefic.rawValue]))
            } else if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .opposition) {
                factors.append(.init(rule: .partileOppositionMalefic, values: ["other": malefic.rawValue]))
            } else if isPartile(point.longitudeDegrees, other.longitudeDegrees, kind: .square) {
                factors.append(.init(rule: .partileSquareMalefic, values: ["other": malefic.rawValue]))
            }
        }
    }

    private static func appendBesiegingFactor(
        body: CelestialBody,
        snapshot: ChartSnapshot,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        guard body != .saturn, body != .mars,
              let point = snapshot.point(body),
              let saturn = snapshot.point(.saturn),
              let mars = snapshot.point(.mars),
              point.signIndex == saturn.signIndex,
              point.signIndex == mars.signIndex
        else { return }
        let lower = min(saturn.degreeInSign, mars.degreeInSign)
        let upper = max(saturn.degreeInSign, mars.degreeInSign)
        if point.degreeInSign > lower, point.degreeInSign < upper {
            factors.append(.init(rule: .besiegedByMalefics))
        }
    }

    private static func appendSupplementalFactors(
        body: CelestialBody,
        point: ChartPoint,
        supplemental: HoraryLillySupplemental,
        to factors: inout [HoraryFortitudeFactor]
    ) {
        if let north = supplemental.northNodeLongitude {
            if isPartile(point.longitudeDegrees, north, kind: .conjunction) {
                factors.append(.init(rule: .partileConjunctNorthNode))
            }
            let south = normalize(north + 180)
            if isPartile(point.longitudeDegrees, south, kind: .conjunction) {
                factors.append(.init(rule: .partileConjunctSouthNode))
            }
        }
        if let regulus = supplemental.regulusLongitude,
           isPartile(point.longitudeDegrees, regulus, kind: .conjunction)
        {
            factors.append(.init(rule: .conjunctRegulus))
        }
        if let spica = supplemental.spicaLongitude,
           isPartile(point.longitudeDegrees, spica, kind: .conjunction)
        {
            factors.append(.init(rule: .conjunctSpica))
        }
        if let algol = supplemental.algolLongitude,
           angularDistance(point.longitudeDegrees, algol) <= 5
        {
            factors.append(.init(rule: .nearAlgol, values: ["distance_degrees": String(angularDistance(point.longitudeDegrees, algol))]))
        }
    }

    private static func isPartile(_ first: Double, _ second: Double, kind: AspectKind) -> Bool {
        abs(angularDistance(first, second) - kind.angleDegrees) <= partileToleranceDegrees
    }

    private static func meanDailyMotion(_ body: CelestialBody) -> Double? {
        switch body {
        case .saturn: 2.0 / 60.0 + 1.0 / 3_600.0
        case .jupiter: 4.0 / 60.0 + 59.0 / 3_600.0
        case .mars: 31.0 / 60.0 + 27.0 / 3_600.0
        case .sun, .mercury, .venus: 59.0 / 60.0 + 8.0 / 3_600.0
        case .moon: 13 + 10.0 / 60.0 + 36.0 / 3_600.0
        default: nil
        }
    }

    private static func exaltationRuler(ofSign signIndex: Int) -> CelestialBody? {
        switch normalizedSign(signIndex) {
        case 0: .sun
        case 1: .moon
        case 3: .jupiter
        case 5: .mercury
        case 6: .saturn
        case 9: .mars
        case 11: .venus
        default: nil
        }
    }

    private static func oppositeSign(_ sign: Int) -> Int { normalizedSign(sign + 6) }
    private static func normalizedSign(_ sign: Int) -> Int { ((sign % 12) + 12) % 12 }
    private static func normalize(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }
    private static func angularDistance(_ first: Double, _ second: Double) -> Double {
        let distance = abs(normalize(first) - normalize(second))
        return min(distance, 360 - distance)
    }
}

public extension SwissEphemerisCalculator {
    func resolveLillySupplemental(snapshot: ChartSnapshot) throws -> HoraryLillySupplemental {
        // The node remains supplemental so the horary wheel itself stays the traditional seven planets.
        let nodeSnapshot = try calculateSnapshot(
            NatalInput(utcDate: snapshot.utcDate, location: snapshot.location),
            configuration: ChartCalculationConfiguration(
                pointIDs: [.trueNode],
                houseSystemCode: "R",
                aspectOrbDegrees: 0
            )
        )
        let northNode = nodeSnapshot.point(.trueNode)?.longitudeDegrees

        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        return HoraryLillySupplemental(
            northNodeLongitude: northNode,
            regulusLongitude: try fixedStarLongitude(name: "Regulus", julianDayUT: snapshot.julianDayUT),
            spicaLongitude: try fixedStarLongitude(name: "Spica", julianDayUT: snapshot.julianDayUT),
            algolLongitude: try fixedStarLongitude(name: "Algol", julianDayUT: snapshot.julianDayUT)
        )
    }

    private func fixedStarLongitude(name: String, julianDayUT: Double) throws -> Double {
        // Swiss Ephemeris rewrites `star` with a canonical name and requires room for
        // twice SE_MAX_STNAME (256). A tight UTF-8 buffer corrupts the heap.
        var star = [CChar](repeating: 0, count: 512)
        for (index, byte) in name.utf8.enumerated() where index < star.count - 1 {
            star[index] = CChar(bitPattern: byte)
        }
        var values = [Double](repeating: 0, count: 6)
        var error = [CChar](repeating: 0, count: 256)
        let flags = Int32(SEFLG_SWIEPH)
        let result = star.withUnsafeMutableBufferPointer { starBuffer in
            values.withUnsafeMutableBufferPointer { valueBuffer in
                error.withUnsafeMutableBufferPointer { errorBuffer in
                    swe_fixstar_ut(
                        starBuffer.baseAddress,
                        julianDayUT,
                        flags,
                        valueBuffer.baseAddress,
                        errorBuffer.baseAddress
                    )
                }
            }
        }
        guard result >= 0 else {
            let message = error.withUnsafeBufferPointer { buffer -> String in
                guard let base = buffer.baseAddress else { return "unknown Swiss Ephemeris error" }
                return String(cString: base)
            }
            throw AstroCoreError.calculationFailed(body: name, message: message)
        }
        var longitude = values[0].truncatingRemainder(dividingBy: 360)
        if longitude < 0 { longitude += 360 }
        return longitude
    }
}
