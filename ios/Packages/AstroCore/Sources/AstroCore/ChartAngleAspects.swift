import Foundation

public enum ChartAngle: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case ascendant
    case midheaven
}

public struct ChartAngleAspect: Codable, Equatable, Identifiable, Sendable {
    public let bodyID: String
    public let angle: ChartAngle
    public let kind: AspectKind
    public let orbDegrees: Double
    public let strength: Double
    public let bodyLongitude: Double
    public let angleLongitude: Double

    public var id: String { "\(bodyID)-\(kind.rawValue)-\(angle.rawValue)" }

    public init(
        bodyID: String,
        angle: ChartAngle,
        kind: AspectKind,
        orbDegrees: Double,
        strength: Double,
        bodyLongitude: Double,
        angleLongitude: Double
    ) {
        self.bodyID = bodyID
        self.angle = angle
        self.kind = kind
        self.orbDegrees = orbDegrees
        self.strength = strength
        self.bodyLongitude = bodyLongitude
        self.angleLongitude = angleLongitude
    }
}

/// Pure geometry for deterministic major aspects between chart points and the
/// two local angles currently represented by `NatalAngles` (ASC and MC).
/// No interpretation is performed here.
public enum ChartAngleAspectCalculator {
    public static func aspects(
        in snapshot: ChartSnapshot,
        orbDegrees: Double = 3
    ) -> [ChartAngleAspect] {
        snapshot.points.flatMap { point in
            matches(
                bodyID: point.body.rawValue,
                bodyLongitude: point.longitudeDegrees,
                ascendantLongitude: snapshot.angles.ascendantDegrees,
                midheavenLongitude: snapshot.angles.midheavenDegrees,
                orbDegrees: orbDegrees
            )
        }
        .sorted {
            if $0.bodyID != $1.bodyID { return $0.bodyID < $1.bodyID }
            if $0.angle.rawValue != $1.angle.rawValue { return $0.angle.rawValue < $1.angle.rawValue }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    public static func matches(
        bodyID: String,
        bodyLongitude: Double,
        ascendantLongitude: Double,
        midheavenLongitude: Double,
        orbDegrees: Double
    ) -> [ChartAngleAspect] {
        guard orbDegrees >= 0 else { return [] }
        return [
            (ChartAngle.ascendant, ascendantLongitude),
            (ChartAngle.midheaven, midheavenLongitude),
        ].flatMap { angle, longitude in
            AspectKind.allCases.compactMap { kind in
                let separation = shortestSeparation(bodyLongitude, longitude)
                let orb = abs(separation - kind.angleDegrees)
                guard orb <= orbDegrees else { return nil }
                let strength: Double
                if orbDegrees == 0 {
                    strength = orb == 0 ? 1 : 0
                } else {
                    strength = max(0, min(1, 1 - orb / orbDegrees))
                }
                return ChartAngleAspect(
                    bodyID: bodyID,
                    angle: angle,
                    kind: kind,
                    orbDegrees: orb,
                    strength: strength,
                    bodyLongitude: normalized(bodyLongitude),
                    angleLongitude: normalized(longitude)
                )
            }
        }
    }

    private static func shortestSeparation(_ lhs: Double, _ rhs: Double) -> Double {
        let raw = abs(normalized(lhs) - normalized(rhs))
        return min(raw, 360 - raw)
    }

    private static func normalized(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }
}
