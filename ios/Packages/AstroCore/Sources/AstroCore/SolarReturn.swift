import CSwissEphemeris
import Foundation

/// Result of a two-person (synastry) comparison: both natal snapshots plus the
/// cross-chart aspects between them, all produced from one immutable pass.
public struct SynastryComparison: Sendable, Equatable, Codable {
    public let first: ChartSnapshot
    public let second: ChartSnapshot
    public let crossAspects: [ChartAspect]

    public init(
        first: ChartSnapshot,
        second: ChartSnapshot,
        crossAspects: [ChartAspect]
    ) {
        self.first = first
        self.second = second
        self.crossAspects = crossAspects
    }
}

/// Orb families from the Obsidian parameter research for the return and
/// comparison charts. Existing natal / sky / transit / secondary charts keep
/// their current uniform orbs and are unaffected.
public enum ChartOrbProfile {
    /// Solar-return single chart, A family: conjunction 7°, other majors 6°.
    public static let solarReturnSingle: [AspectKind: Double] = [
        .conjunction: 7,
        .sextile: 6,
        .square: 6,
        .trine: 6,
        .opposition: 6,
    ]

    /// Dual-chart comparisons (solar return vs natal, synastry), B family:
    /// conjunction 2°, other majors 1°.
    public static let comparisonB: [AspectKind: Double] = [
        .conjunction: 2,
        .sextile: 1,
        .square: 1,
        .trine: 1,
        .opposition: 1,
    ]

    /// Classical starlight orbs: the effective orb for a pair is the smaller
    /// of the two bodies' orbs.
    public static let classicalStarlight: [CelestialBody: Double] = [
        .sun: 15,
        .moon: 12,
        .mercury: 7,
        .venus: 7,
        .mars: 8,
        .jupiter: 9,
        .saturn: 9,
        .uranus: 5,
        .neptune: 5,
        .pluto: 5,
        .trueNode: 5,
    ]
}

extension SwissEphemerisCalculator {
    /// The next moment at or after `anchorDate` when the Sun returns to its
    /// natal longitude — the solar return moment that opens the next solar year.
    public func solarReturnMoment(
        birthDate: Date,
        after anchorDate: Date
    ) throws -> Date {
        let natalSun = try sunPosition(julianDayUT: julianDay(for: birthDate)).longitude
        return try nextSolarReturnMoment(targetLongitude: natalSun, after: anchorDate)
    }

    /// Full solar return snapshot for the solar year that opens at the next
    /// return moment, using the selected consumer preset and its Obsidian orb
    /// family (modern: A family; classical: starlight per-body orbs).
    public func calculateSolarReturn(
        birthDate: Date,
        after anchorDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern,
        aspectOrbDegrees: Double? = nil
    ) throws -> ChartSnapshot {
        let moment = try solarReturnMoment(birthDate: birthDate, after: anchorDate)
        return try calculateSnapshot(
            NatalInput(utcDate: moment, location: location),
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: aspectOrbDegrees ?? preset.defaultOrbDegrees,
                orbsByKind: preset == .classical ? nil : ChartOrbProfile.solarReturnSingle,
                orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
            )
        )
    }

    /// Cross-chart aspects between a solar return chart and the natal chart,
    /// using the tight B-family orbs for the return dual wheel.
    public nonisolated static func solarReturnNatalAspects(
        solarReturn: ChartSnapshot,
        natal: ChartSnapshot
    ) -> [ChartAspect] {
        compare(
            moving: solarReturn,
            reference: natal,
            orbsByKind: ChartOrbProfile.comparisonB
        )
    }

    /// Synastry comparison between two natal charts under the same preset.
    /// Modern uses the tight B-family orbs; classical uses starlight per-body
    /// orbs, matching the Obsidian comparison-chart parameters.
    public func calculateSynastry(
        first: NatalInput,
        second: NatalInput,
        preset: CalculationPreset = .modern,
        aspectOrbDegrees: Double? = nil
    ) throws -> SynastryComparison {
        let firstSnapshot = try calculateSnapshot(
            first,
            preset: preset,
            aspectOrbDegrees: aspectOrbDegrees
        )
        let secondSnapshot = try calculateSnapshot(
            second,
            preset: preset,
            aspectOrbDegrees: aspectOrbDegrees
        )
        let crossAspects: [ChartAspect]
        if preset == .classical {
            crossAspects = Self.compare(
                moving: firstSnapshot,
                reference: secondSnapshot,
                orbsByBody: ChartOrbProfile.classicalStarlight
            )
        } else {
            crossAspects = Self.compare(
                moving: firstSnapshot,
                reference: secondSnapshot,
                orbsByKind: ChartOrbProfile.comparisonB
            )
        }
        return SynastryComparison(
            first: firstSnapshot,
            second: secondSnapshot,
            crossAspects: crossAspects
        )
    }

    // MARK: - Solar return moment search

    private struct SunPosition {
        let longitude: Double
        let speedDegreesPerDay: Double
    }

    private func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private func sunPosition(julianDayUT: Double) throws -> SunPosition {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        var values = [Double](repeating: 0, count: 6)
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let returnedFlags = values.withUnsafeMutableBufferPointer { valuesBuffer in
            errorBuffer.withUnsafeMutableBufferPointer { errorBufferPointer in
                swe_calc_ut(
                    julianDayUT,
                    Int32(SE_SUN),
                    Self.swissFlags,
                    valuesBuffer.baseAddress,
                    errorBufferPointer.baseAddress
                )
            }
        }
        guard returnedFlags >= 0 else {
            let message = String(
                decoding: errorBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
            throw AstroCoreError.calculationFailed(body: "Sun", message: message)
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: "Sun", flags: returnedFlags)
        }
        return SunPosition(
            longitude: normalize360(values[0]),
            speedDegreesPerDay: values[3]
        )
    }

    private func nextSolarReturnMoment(
        targetLongitude: Double,
        after anchorDate: Date
    ) throws -> Date {
        let startJD = julianDay(for: anchorDate)
        let startPosition = try sunPosition(julianDayUT: startJD)

        // Angular distance the Sun must travel to reach the target, in [0, 360).
        var distance = (targetLongitude - startPosition.longitude)
            .truncatingRemainder(dividingBy: 360)
        if distance < 0 { distance += 360 }
        if distance < 0.000_001 {
            // Anchor sits exactly on a return moment; move to the next year.
            distance += 365.242_189 * 0.985_647_36
        }

        // Mean tropical motion of the Sun is about 0.98564736 degrees per day.
        let meanMotion = 0.985_647_36
        var guessJD = startJD + distance / meanMotion

        // Newton refinement using the instantaneous longitude and speed.
        for _ in 0 ..< 8 {
            let position = try sunPosition(julianDayUT: guessJD)
            var error = (position.longitude - targetLongitude)
                .truncatingRemainder(dividingBy: 360)
            if error > 180 { error -= 360 }
            if error < -180 { error += 360 }
            guard abs(position.speedDegreesPerDay) > 1e-9 else { break }
            let correction = error / position.speedDegreesPerDay
            guard correction.isFinite, abs(correction) < 30 else { break }
            guessJD -= correction
        }

        // Safety: the refined moment must not drift before the anchor date.
        while guessJD < startJD - 0.25 {
            guessJD += 365.242_189
        }
        return Date(timeIntervalSince1970: (guessJD - 2_440_587.5) * 86_400)
    }
}

private func normalize360(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value >= 0 ? value : value + 360
}
