import Foundation

/// William Lilly's broad timing scale in Christian Astrology, pp. 267–268.
/// These are symbolic units inferred from sign/house quality; they are not calendar promises.
public enum HoraryTimingScale: String, Sendable, Equatable, Codable, CaseIterable {
    case days
    case weeksOrMonths
    case monthsOrYears
}

public enum HorarySignQuality: String, Sendable, Equatable, Codable {
    case moveable
    case common
    case fixed
}

public enum HoraryHouseQuality: String, Sendable, Equatable, Codable {
    case angular
    case succedent
    case cadent
}

public enum HoraryTimingStatus: String, Sendable, Equatable, Codable {
    case indicated
    case prevented
    case notIndicated
    case ambiguous
}

/// Keeps Lilly's individual testimonies visible instead of collapsing them into a fabricated exact date.
public enum HoraryTimingTestimonyRole: String, Sendable, Equatable, Codable {
    case applyingSign
    case applyingHouse
    case receivingSign
    case receivingHouse
    case moonSign
    case moonHouse
}

public struct HoraryTimingTestimony: Sendable, Equatable, Codable, Identifiable {
    public let role: HoraryTimingTestimonyRole
    public let body: CelestialBody
    public let scale: HoraryTimingScale
    public let signQuality: HorarySignQuality?
    public let houseQuality: HoraryHouseQuality?

    public var id: String { "lilly.timing.\(role.rawValue).\(body.id).\(scale.rawValue)" }

    public init(
        role: HoraryTimingTestimonyRole,
        body: CelestialBody,
        scale: HoraryTimingScale,
        signQuality: HorarySignQuality? = nil,
        houseQuality: HoraryHouseQuality? = nil
    ) {
        self.role = role
        self.body = body
        self.scale = scale
        self.signQuality = signQuality
        self.houseQuality = houseQuality
    }
}

public struct HoraryTimingResult: Sendable, Equatable, Codable {
    public let status: HoraryTimingStatus
    /// Degrees still required for the resolved perfection at the question moment.
    /// Lilly uses this as the symbolic number of timing units.
    public let symbolicUnits: Double?
    public let applyingBody: CelestialBody?
    public let receivingBody: CelestialBody?
    public let testimonies: [HoraryTimingTestimony]
    /// Unique scales represented by the testimonies, ordered from faster to slower.
    public let scales: [HoraryTimingScale]
    /// Ephemeris moment of the astrological perfection. This is technical evidence only,
    /// not an asserted real-world event timestamp.
    public let exactPerfectionDate: Date?
    public let evidenceIDs: [String]

    public var isMixed: Bool { scales.count > 1 }

    public init(
        status: HoraryTimingStatus,
        symbolicUnits: Double? = nil,
        applyingBody: CelestialBody? = nil,
        receivingBody: CelestialBody? = nil,
        testimonies: [HoraryTimingTestimony] = [],
        scales: [HoraryTimingScale] = [],
        exactPerfectionDate: Date? = nil,
        evidenceIDs: [String] = []
    ) {
        self.status = status
        self.symbolicUnits = symbolicUnits
        self.applyingBody = applyingBody
        self.receivingBody = receivingBody
        self.testimonies = testimonies
        self.scales = scales
        self.exactPerfectionDate = exactPerfectionDate
        self.evidenceIDs = evidenceIDs
    }
}

public enum HoraryTimingEngine {
    public static func signQuality(signIndex: Int) -> HorarySignQuality {
        switch ((signIndex % 12) + 12) % 12 {
        case 0, 3, 6, 9: .moveable
        case 2, 5, 8, 11: .common
        default: .fixed
        }
    }

    public static func houseQuality(house: Int) -> HoraryHouseQuality {
        switch house {
        case 1, 4, 7, 10: .angular
        case 2, 5, 8, 11: .succedent
        default: .cadent
        }
    }

    public static func scale(for quality: HorarySignQuality) -> HoraryTimingScale {
        switch quality {
        case .moveable: .days
        case .common: .weeksOrMonths
        case .fixed: .monthsOrYears
        }
    }

    public static func scale(for quality: HoraryHouseQuality) -> HoraryTimingScale {
        switch quality {
        case .angular: .days
        case .succedent: .weeksOrMonths
        case .cadent: .monthsOrYears
        }
    }

    public static func interpret(
        perfection: HoraryPerfectionAssessment,
        snapshot: ChartSnapshot
    ) -> HoraryTimingResult {
        switch perfection.status {
        case .prevented:
            return HoraryTimingResult(
                status: .prevented,
                evidenceIDs: ["lilly.timing.perfection-prevented"]
            )
        case .none:
            return HoraryTimingResult(
                status: .notIndicated,
                evidenceIDs: ["lilly.timing.no-perfection"]
            )
        case .delayed, .ambiguous:
            return HoraryTimingResult(
                status: .ambiguous,
                evidenceIDs: ["lilly.timing.perfection-ambiguous"]
            )
        case .completes:
            break
        }

        guard let path = perfection.primaryPath,
              let applying = path.applyingBody,
              let receiving = path.receivingBody,
              snapshot.point(applying) != nil,
              snapshot.point(receiving) != nil
        else {
            return HoraryTimingResult(
                status: .ambiguous,
                evidenceIDs: ["lilly.timing.missing-path-bodies"]
            )
        }

        var testimonies: [HoraryTimingTestimony] = []
        testimonies.append(contentsOf: bodyTestimonies(
            body: applying,
            signRole: .applyingSign,
            houseRole: .applyingHouse,
            snapshot: snapshot
        ))
        testimonies.append(contentsOf: bodyTestimonies(
            body: receiving,
            signRole: .receivingSign,
            houseRole: .receivingHouse,
            snapshot: snapshot
        ))
        if snapshot.point(.moon) != nil {
            testimonies.append(contentsOf: bodyTestimonies(
                body: .moon,
                signRole: .moonSign,
                houseRole: .moonHouse,
                snapshot: snapshot
            ))
        }

        let order: [HoraryTimingScale: Int] = [
            .days: 0,
            .weeksOrMonths: 1,
            .monthsOrYears: 2,
        ]
        let scales = Array(Set(testimonies.map(\.scale))).sorted {
            (order[$0] ?? 99) < (order[$1] ?? 99)
        }
        var evidence = ["lilly.timing.degrees-to-perfection"]
        evidence.append(contentsOf: testimonies.map(\.id))
        if scales.count > 1 {
            evidence.append("lilly.timing.mixed-testimony")
        }

        return HoraryTimingResult(
            status: .indicated,
            symbolicUnits: max(0, path.distanceDegrees),
            applyingBody: applying,
            receivingBody: receiving,
            testimonies: testimonies,
            scales: scales,
            exactPerfectionDate: path.exactDate,
            evidenceIDs: evidence
        )
    }

    private static func bodyTestimonies(
        body: CelestialBody,
        signRole: HoraryTimingTestimonyRole,
        houseRole: HoraryTimingTestimonyRole,
        snapshot: ChartSnapshot
    ) -> [HoraryTimingTestimony] {
        guard let point = snapshot.point(body) else { return [] }
        let sign = signQuality(signIndex: point.signIndex)
        let house = houseQuality(house: snapshot.house(containing: point.longitudeDegrees))
        return [
            HoraryTimingTestimony(
                role: signRole,
                body: body,
                scale: scale(for: sign),
                signQuality: sign
            ),
            HoraryTimingTestimony(
                role: houseRole,
                body: body,
                scale: scale(for: house),
                houseQuality: house
            ),
        ]
    }
}
