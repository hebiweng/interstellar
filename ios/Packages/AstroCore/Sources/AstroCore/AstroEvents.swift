import CSwissEphemeris
import Foundation

/// Event search over the ephemeris: sign ingresses, exact aspects, and
/// progression windows. All results are derived deterministically from the
/// bundled Swiss Ephemeris data — nothing is invented.
public struct AstroEvent: Sendable, Equatable {
    public let body: CelestialBody
    public let date: Date
    public let kind: Kind

    public enum Kind: String, Sendable, Equatable {
        case signIngress
        case exactAspect
    }
}

extension SwissEphemerisCalculator {

    // MARK: - Sign ingress

    /// The next moment at or after `after` when `body` crosses a sign boundary
    /// (longitude a multiple of 30°).
    public func nextSignIngress(
        for body: CelestialBody,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let position = try bodyPosition(body, julianDayUT: start)
        let nextBoundary = Double((Int(position.longitude / 30) + 1) * 30)
        var target = nextBoundary.truncatingRemainder(dividingBy: 360)
        if target == 0 { target = 360 }
        // The body may be retrograde; find the first crossing of the target.
        let meanSpeed = position.speed
        let step = abs(meanSpeed) < 0.000_000_1 ? 0.5 : 1.0
        var guess = start + (target - position.longitude) / (meanSpeed == 0 ? 1 : meanSpeed)
        if guess < start { guess += 365.25 }
        // Bracket then bisect on the unwrapped error.
        var lower = guess - 1.0
        var upper = guess + 1.0
        for _ in 0 ..< 12 {
            let mid = (lower + upper) / 2
            let midPos = try bodyPosition(body, julianDayUT: mid)
            let err = signedDelta(target, midPos.longitude)
            let lowerErr = try signedDelta(target, bodyPosition(body, julianDayUT: lower).longitude)
            if (lowerErr >= 0) != (err >= 0) {
                upper = mid
            } else {
                lower = mid
            }
        }
        return Date(timeIntervalSince1970: ((lower + upper) / 2 - 2_440_587.5) * 86_400)
    }

    // MARK: - Exact aspect

    /// The next moment at or after `after` when the separation between the two
    /// bodies equals the exact aspect angle.
    public func nextExactAspectDate(
        moving: CelestialBody,
        reference: CelestialBody,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let targets = exactAspectTargets(kind)
        let step = 0.25
        let maxDays = 365.25 * 3

        func relativeAngle(at jd: Double) throws -> Double {
            let m = try bodyPosition(moving, julianDayUT: jd).longitude
            let r = try bodyPosition(reference, julianDayUT: jd).longitude
            return norm360(m - r)
        }

        var lower = start
        var lowerAngle = try relativeAngle(at: lower)
        var upper = lower + step
        while upper < start + maxDays {
            let upperAngle = try relativeAngle(at: upper)
            for target in targets where crossesTarget(lowerAngle, upperAngle, target) {
                var lo = lower
                var hi = upper
                var loAngle = lowerAngle
                for _ in 0 ..< 24 {
                    let mid = (lo + hi) / 2
                    let midAngle = try relativeAngle(at: mid)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                return Date(timeIntervalSince1970: ((lo + hi) / 2 - 2_440_587.5) * 86_400)
            }
            lower = upper
            lowerAngle = upperAngle
            upper += step
        }
        throw AstroCoreError.eventNotFound(
            "No exact \(kind.rawValue) between \(moving.displayName) and \(reference.displayName) within the search window."
        )
    }

    // MARK: - Progression windows

    /// The current sign of a progressed point and the window until its next
    /// sign change, in days.
    public func progressionWindow(
        moving body: CelestialBody,
        at progressedDate: Date,
        signLabel: String
    ) throws -> (ingressDate: Date, daysInSign: Double) {
        let ingress = try nextSignIngress(for: body, after: progressedDate)
        // Days since the body entered the current sign.
        let previousIngress = try nextSignIngressBackward(for: body, before: progressedDate)
        let daysIn = progressedDate.timeIntervalSince(previousIngress) / 86_400
        return (ingress, daysIn)
    }

    // MARK: - Internal helpers

    private func bodyPosition(
        _ body: CelestialBody,
        julianDayUT: Double
    ) throws -> (longitude: Double, speed: Double) {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        var values = [Double](repeating: 0, count: 6)
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let returnedFlags = values.withUnsafeMutableBufferPointer { valuesBuffer in
            errorBuffer.withUnsafeMutableBufferPointer { errorBufferPointer in
                swe_calc_ut(
                    julianDayUT,
                    body.swissID,
                    Self.swissFlags,
                    valuesBuffer.baseAddress,
                    errorBufferPointer.baseAddress
                )
            }
        }
        guard returnedFlags >= 0 else {
            throw AstroCoreError.calculationFailed(body: body.displayName, message: String(decoding: errorBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: body.displayName, flags: returnedFlags)
        }
        return (norm360(values[0]), values[3])
    }

    private func nextSignIngressBackward(
        for body: CelestialBody,
        before date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let position = try bodyPosition(body, julianDayUT: start)
        let currentBoundary = Double(Int(position.longitude / 30) * 30)
        var target = currentBoundary
        if target == 0 { target = 360 }
        let meanSpeed = position.speed
        let guess = start - (position.longitude - target) / (meanSpeed == 0 ? 1 : meanSpeed)
        var lower = min(start, guess) - 2.0
        var upper = max(start, guess) + 2.0
        for _ in 0 ..< 14 {
            let mid = (lower + upper) / 2
            let midPos = try bodyPosition(body, julianDayUT: mid)
            let err = signedDelta(target, midPos.longitude)
            let upperErr = try signedDelta(target, bodyPosition(body, julianDayUT: upper).longitude)
            if (err >= 0) != (upperErr >= 0) {
                lower = mid
            } else {
                upper = mid
            }
        }
        return Date(timeIntervalSince1970: ((lower + upper) / 2 - 2_440_587.5) * 86_400)
    }

    private func signedDelta(_ target: Double, _ value: Double) -> Double {
        var d = (value - target).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    /// The target relative angles (in degrees) for an aspect kind. Conjunctions
    /// and oppositions have a single target; the other aspects occur at both the
    /// forward and the complementary angle.
    private func exactAspectTargets(_ kind: AspectKind) -> [Double] {
        let target = kind.angleDegrees
        return target == 180 ? [180] : [target, 360 - target]
    }

    /// True when the circular relative angle crosses `target` between `from` and
    /// `to` (valid while the swept arc is smaller than 180°).
    private func crossesTarget(_ from: Double, _ to: Double, _ target: Double) -> Bool {
        let sweep = signedDelta(from, to)
        guard sweep != 0 else { return false }
        let toTarget = signedDelta(from, target)
        return toTarget != 0
            && (toTarget > 0) == (sweep > 0)
            && abs(toTarget) <= abs(sweep)
    }

    private func shortestSeparation(_ first: Double, _ second: Double) -> Double {
        let s = abs(norm360(first) - norm360(second))
        return min(s, 360 - s)
    }

    private func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private func norm360(_ degrees: Double) -> Double {
        let v = degrees.truncatingRemainder(dividingBy: 360)
        return v >= 0 ? v : v + 360
    }
}

extension SwissEphemerisCalculator {
    /// Next exact aspect in the sky between two ephemeris bodies.
    public func nextSkyExactDate(
        moving: CelestialBody,
        reference: CelestialBody,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        try nextExactAspectDate(moving: moving, reference: reference, kind: kind, after: date)
    }

    /// Next exact aspect between a transit body (moving at the searched date)
    /// and a fixed natal longitude.
    public func nextTransitNatalExactDate(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let targets = exactAspectTargets(kind)

        func relativeAngle(at jd: Double) throws -> Double {
            let m = try bodyPosition(moving, julianDayUT: jd).longitude
            return norm360(m - natalReferenceLongitude)
        }

        // The step adapts to the transit body's current motion so the whole
        // circle is swept with a bounded number of samples (about 1 degree of
        // motion per sample; the Moon needs a fraction of a day, Saturn months).
        let position = try bodyPosition(moving, julianDayUT: start)
        let speed = max(abs(position.speed), 0.01)
        let step = max(0.05, 1.0 / speed)
        let maxDays = 365.25 * 8

        var lower = start
        var lowerAngle = try relativeAngle(at: lower)
        var upper = lower + step
        while upper < start + maxDays {
            let upperAngle = try relativeAngle(at: upper)
            for target in targets where crossesTarget(lowerAngle, upperAngle, target) {
                var lo = lower
                var hi = upper
                var loAngle = lowerAngle
                for _ in 0 ..< 24 {
                    let mid = (lo + hi) / 2
                    let midAngle = try relativeAngle(at: mid)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                return Date(timeIntervalSince1970: ((lo + hi) / 2 - 2_440_587.5) * 86_400)
            }
            lower = upper
            lowerAngle = upperAngle
            upper += step
        }
        throw AstroCoreError.eventNotFound(
            "No exact \(kind.rawValue) from transiting \(moving.displayName) to the natal longitude within the search window."
        )
    }

    /// Next exact aspect between a progressed body (birth date + N days) and a
    /// fixed natal longitude, searching up to `maxYears` real years ahead.
    /// The returned date is a real calendar date.
    public func nextProgressedNatalExactDate(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        birthDate: Date,
        after targetDate: Date,
        maxYears: Int = 10
    ) throws -> Date? {
        let targets = exactAspectTargets(kind)
        let startYear = max(0, Int(targetDate.timeIntervalSince(birthDate) / (365.2425 * 86_400)))
        for year in startYear ..< (startYear + maxYears) {
            let progressedDate = birthDate.addingTimeInterval(Double(year) * 86_400)
            let nextProgressed = birthDate.addingTimeInterval(Double(year + 1) * 86_400)
            let p1 = try bodyPosition(moving, julianDayUT: julianDay(for: progressedDate)).longitude
            let p2 = try bodyPosition(moving, julianDayUT: julianDay(for: nextProgressed)).longitude
            let r1 = norm360(p1 - natalReferenceLongitude)
            let r2 = norm360(p2 - natalReferenceLongitude)
            for target in targets where crossesTarget(r1, r2, target) {
                var lo = Double(year)
                var hi = Double(year + 1)
                var loAngle = r1
                for _ in 0 ..< 28 {
                    let mid = (lo + hi) / 2
                    let midProgressed = birthDate.addingTimeInterval(mid * 86_400)
                    let midLon = try bodyPosition(moving, julianDayUT: julianDay(for: midProgressed)).longitude
                    let midAngle = norm360(midLon - natalReferenceLongitude)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                let exactRealDate = birthDate.addingTimeInterval(((lo + hi) / 2) * 365.2425 * 86_400)
                if exactRealDate >= targetDate {
                    return exactRealDate
                }
            }
        }
        return nil
    }
}
