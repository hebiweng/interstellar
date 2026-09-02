import Foundation

/// Consumer-facing precision for electional search windows. Horary "When" does not use this type.
public enum TimingPrecision: String, Sendable, Codable, CaseIterable {
    case day
    case week
    case month
}

public struct ElectionTimingRequest: Sendable, Equatable {
    public let targetHouse: Int
    public let relatedHouses: [Int]
    public let startDate: Date
    public let endDate: Date
    public let location: GeographicLocation
    public let timeZone: TimeZone
    public let calendarIdentifier: Calendar.Identifier
    public let precision: TimingPrecision

    public init(
        targetHouse: Int,
        relatedHouses: [Int] = [],
        startDate: Date,
        endDate: Date,
        location: GeographicLocation,
        timeZone: TimeZone,
        calendarIdentifier: Calendar.Identifier = .gregorian,
        precision: TimingPrecision
    ) {
        self.targetHouse = targetHouse
        self.relatedHouses = relatedHouses.filter { $0 != targetHouse }
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.timeZone = timeZone
        self.calendarIdentifier = calendarIdentifier
        self.precision = precision
    }
}

/// One deterministic contribution to an electional suitability assessment.
/// A contribution is not a probability; it exists only to rank candidate action windows.
public struct ElectionalFactor: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let contribution: Double
    public let values: [String: String]

    public init(id: String, contribution: Double, values: [String: String] = [:]) {
        self.id = id
        self.contribution = contribution
        self.values = values
    }
}

/// Electional assessment is deliberately separate from HoraryAnalysis.
/// `suitabilityScore` ranks future action windows; it must never be presented as event probability.
public struct ElectionalAssessment: Sendable, Equatable, Codable {
    public let suitabilityScore: Double
    public let factors: [ElectionalFactor]
    public let targetHouse: Int?
    public let targetRuler: CelestialBody?
    public let moonIsVoidOfCourse: Bool?

    public init(
        suitabilityScore: Double,
        factors: [ElectionalFactor],
        targetHouse: Int? = nil,
        targetRuler: CelestialBody? = nil,
        moonIsVoidOfCourse: Bool? = nil
    ) {
        self.suitabilityScore = max(0, min(100, suitabilityScore))
        self.factors = factors
        self.targetHouse = targetHouse
        self.targetRuler = targetRuler
        self.moonIsVoidOfCourse = moonIsVoidOfCourse
    }

    static func legacy(from analysis: HoraryAnalysis, score: Double) -> ElectionalAssessment {
        ElectionalAssessment(
            suitabilityScore: score,
            factors: [
                ElectionalFactor(
                    id: "legacy-horary-assessment",
                    contribution: score,
                    values: ["migration": "schema-v1-v3"]
                )
            ],
            targetHouse: analysis.targetHouse,
            targetRuler: analysis.targetRuler,
            moonIsVoidOfCourse: analysis.moon.isVoidOfCourse
        )
    }
}

public struct ElectionalAssessmentEngine {
    /// Preserve the existing Best Time ranking behavior while removing the false Horary domain model.
    /// Electional rule depth can evolve independently from Lilly horary judgment after this boundary is established.
    public static func assess(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        relatedHouses: [Int] = []
    ) -> ElectionalAssessment {
        let targetRuler = HoraryEngine.ruler(ofHouse: targetHouse, in: snapshot)
        let target = HoraryEngine.assess(targetRuler, in: snapshot)
        let ascendantRuler = HoraryEngine.ruler(ofHouse: 1, in: snapshot)
        let ascendant = HoraryEngine.assess(ascendantRuler, in: snapshot)
        let moon = HoraryEngine.moonCondition(in: snapshot)
        let aspects = HoraryEngine.validTraditionalAspects(in: snapshot)
        let querentRuler = ascendantRuler

        let relationship = aspects.first {
            Set([$0.firstID, $0.secondID]) == Set([querentRuler.id, targetRuler.id])
        }
        let beneficSupport = aspects.filter { aspect in
            guard aspect.phase != .separating else { return false }
            let ids = Set([aspect.firstID, aspect.secondID])
            return ids.contains(targetRuler.id)
                && (ids.contains(CelestialBody.jupiter.id) || ids.contains(CelestialBody.venus.id))
                && (aspect.kind.supportive || aspect.kind == .conjunction)
        }

        var factors = [
            ElectionalFactor(
                id: "target-condition",
                contribution: scale(target.score, from: -30 ... 37, to: 0 ... 30),
                values: ["ruler": targetRuler.id, "house": String(target.house)]
            ),
            ElectionalFactor(
                id: "moon-condition",
                contribution: moon.isVoidOfCourse ? 3 : (moon.nextAspect == nil ? 10 : 25),
                values: ["void_of_course": String(moon.isVoidOfCourse)]
            ),
            ElectionalFactor(
                id: "ascendant-condition",
                contribution: scale(ascendant.score, from: -30 ... 37, to: 0 ... 15),
                values: ["ruler": ascendantRuler.id, "house": String(ascendant.house)]
            ),
            ElectionalFactor(
                id: "benefic-support",
                contribution: min(15, Double(beneficSupport.count) * 7.5),
                values: ["count": String(beneficSupport.count)]
            ),
            ElectionalFactor(
                id: "querent-target-application",
                contribution: relationship?.phase == .separating || relationship == nil ? 0 : 15,
                values: ["aspect": relationship?.kind.rawValue ?? "none"]
            ),
        ]

        if !relatedHouses.isEmpty {
            let rulers = Set(relatedHouses.filter { $0 != targetHouse }.map {
                HoraryEngine.ruler(ofHouse: $0, in: snapshot)
            })
            if !rulers.isEmpty {
                let average = rulers.map { HoraryEngine.assess($0, in: snapshot).score }.reduce(0, +)
                    / Double(rulers.count)
                factors.append(
                    ElectionalFactor(
                        id: "related-area-support",
                        contribution: clamp(average / 6, lower: -5, upper: 5),
                        values: ["ruler_count": String(rulers.count)]
                    )
                )
            }
        }

        var risk = 0.0
        if target.conditions.contains(.retrograde) { risk -= 8 }
        if target.conditions.contains(.combust) { risk -= 12 }
        if moon.isVoidOfCourse { risk -= 10 }
        if relationship?.kind.challenging == true { risk -= 8 }
        factors.append(
            ElectionalFactor(
                id: "risk",
                contribution: max(-30, risk),
                values: ["target": targetRuler.id]
            )
        )

        return ElectionalAssessment(
            suitabilityScore: clamp(factors.reduce(0) { $0 + $1.contribution }, lower: 0, upper: 100),
            factors: factors,
            targetHouse: targetHouse,
            targetRuler: targetRuler,
            moonIsVoidOfCourse: moon.isVoidOfCourse
        )
    }

    private static func scale(
        _ value: Double,
        from source: ClosedRange<Double>,
        to destination: ClosedRange<Double>
    ) -> Double {
        guard source.upperBound > source.lowerBound else { return destination.lowerBound }
        let normalized = (value - source.lowerBound) / (source.upperBound - source.lowerBound)
        return destination.lowerBound
            + max(0, min(1, normalized)) * (destination.upperBound - destination.lowerBound)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public struct ElectionTimingCandidate: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let interval: DateInterval
    public let peakDate: Date
    public let snapshot: ChartSnapshot
    public let assessment: ElectionalAssessment
    /// Present only when decoding historical schema v1-v3 candidates.
    /// New Best Time candidates never populate or encode this property.
    public let legacyHoraryAnalysis: HoraryAnalysis?

    /// Compatibility accessor for existing UI while consumer copy migrates to "suitability".
    public var score: Double { assessment.suitabilityScore }

    public init(
        id: String,
        interval: DateInterval,
        peakDate: Date,
        snapshot: ChartSnapshot,
        assessment: ElectionalAssessment
    ) {
        self.id = id
        self.interval = interval
        self.peakDate = peakDate
        self.snapshot = snapshot
        self.assessment = assessment
        self.legacyHoraryAnalysis = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, interval, peakDate, snapshot, assessment
        case legacyScore = "score"
        case legacyAnalysis = "analysis"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        interval = try container.decode(DateInterval.self, forKey: .interval)
        peakDate = try container.decode(Date.self, forKey: .peakDate)
        snapshot = try container.decode(ChartSnapshot.self, forKey: .snapshot)
        if let decoded = try container.decodeIfPresent(ElectionalAssessment.self, forKey: .assessment) {
            assessment = decoded
            legacyHoraryAnalysis = nil
        } else {
            let legacy = try container.decode(HoraryAnalysis.self, forKey: .legacyAnalysis)
            let legacyScore = try container.decodeIfPresent(Double.self, forKey: .legacyScore) ?? legacy.score
            assessment = ElectionalAssessment.legacy(from: legacy, score: legacyScore)
            legacyHoraryAnalysis = legacy
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(interval, forKey: .interval)
        try container.encode(peakDate, forKey: .peakDate)
        try container.encode(snapshot, forKey: .snapshot)
        try container.encode(assessment, forKey: .assessment)
    }
}

public enum ElectionTimingError: Error, Sendable, Equatable, LocalizedError {
    case invalidRange
    case rangeTooLong
    case noCandidates

    public var errorDescription: String? {
        switch self {
        case .invalidRange: "The timing search range is invalid."
        case .rangeTooLong: "The timing search range exceeds the supported limit."
        case .noCandidates: "No timing candidates could be calculated."
        }
    }
}

public struct ElectionTimingEngine: Sendable {
    private let calculator: SwissEphemerisCalculator

    public init(calculator: SwissEphemerisCalculator) {
        self.calculator = calculator
    }

    public func search(
        _ request: ElectionTimingRequest,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> [ElectionTimingCandidate] {
        guard request.endDate > request.startDate else {
            throw ElectionTimingError.invalidRange
        }
        let maximum: TimeInterval = switch request.precision {
        case .day: 90 * 86_400
        case .week: 184 * 86_400
        case .month: 367 * 86_400
        }
        guard request.endDate.timeIntervalSince(request.startDate) <= maximum + 86_400 else {
            throw ElectionTimingError.rangeTooLong
        }

        var calendar = Calendar(identifier: request.calendarIdentifier)
        calendar.timeZone = request.timeZone
        var samples: [(Date, ChartSnapshot, ElectionalAssessment)] = []
        let step: TimeInterval = 6 * 3_600
        let count = max(1, Int(ceil(request.endDate.timeIntervalSince(request.startDate) / step)))
        samples.reserveCapacity(count)
        for index in 0 ... count {
            try Task.checkCancellation()
            let date = min(request.endDate, request.startDate.addingTimeInterval(Double(index) * step))
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: request.location),
                configuration: .horary
            )
            let assessment = ElectionalAssessmentEngine.assess(
                snapshot: snapshot,
                targetHouse: request.targetHouse,
                relatedHouses: request.relatedHouses
            )
            samples.append((date, snapshot, assessment))
            progress(Double(index + 1) / Double(count + 1) * 0.78)
            if date >= request.endDate { break }
        }
        guard !samples.isEmpty else { throw ElectionTimingError.noCandidates }

        let dailyBest = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.0) }
            .compactMapValues { values in
                values.max { $0.2.suitabilityScore < $1.2.suitabilityScore }
            }
        let peakDays = dailyBest.values
            .sorted { $0.2.suitabilityScore > $1.2.suitabilityScore }
            .prefix(12)
        var refined = dailyBest
        for (index, value) in peakDays.enumerated() {
            try Task.checkCancellation()
            let start = max(request.startDate, value.0.addingTimeInterval(-6 * 3_600))
            let end = min(request.endDate, value.0.addingTimeInterval(6 * 3_600))
            var cursor = start
            while cursor <= end {
                let snapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: cursor, location: request.location),
                    configuration: .horary
                )
                let assessment = ElectionalAssessmentEngine.assess(
                    snapshot: snapshot,
                    targetHouse: request.targetHouse,
                    relatedHouses: request.relatedHouses
                )
                let day = calendar.startOfDay(for: cursor)
                if refined[day] == nil
                    || assessment.suitabilityScore > refined[day]!.2.suitabilityScore
                {
                    refined[day] = (cursor, snapshot, assessment)
                }
                cursor = calendar.date(byAdding: .hour, value: 1, to: cursor)
                    ?? cursor.addingTimeInterval(3_600)
            }
            progress(0.78 + Double(index + 1) / Double(max(1, peakDays.count)) * 0.2)
        }

        let grouped = groupedCandidates(dailyBest: refined, request: request, calendar: calendar)
        progress(1)
        return Array(grouped.sorted {
            $0.assessment.suitabilityScore > $1.assessment.suitabilityScore
        }.prefix(3))
    }

    private func groupedCandidates(
        dailyBest: [Date: (Date, ChartSnapshot, ElectionalAssessment)],
        request: ElectionTimingRequest,
        calendar: Calendar
    ) -> [ElectionTimingCandidate] {
        switch request.precision {
        case .day:
            return dailyBest.map { day, value in
                let end = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
                return ElectionTimingCandidate(
                    id: "day-\(day.timeIntervalSince1970)",
                    interval: DateInterval(start: max(day, request.startDate), end: min(end, request.endDate)),
                    peakDate: value.0,
                    snapshot: value.1,
                    assessment: value.2
                )
            }
        case .week, .month:
            let groups = Dictionary(grouping: dailyBest) { day, _ in
                periodStart(for: day, precision: request.precision, calendar: calendar)
            }
            return groups.compactMap { period, values in
                guard let best = values.max(by: {
                    $0.value.2.suitabilityScore < $1.value.2.suitabilityScore
                }) else { return nil }
                let component: Calendar.Component = request.precision == .week ? .weekOfYear : .month
                let rawEnd = calendar.date(byAdding: component, value: 1, to: period)
                    ?? period.addingTimeInterval(request.precision == .week ? 7 * 86_400 : 31 * 86_400)
                let scores = values.map(\.value.2.suitabilityScore).sorted(by: >)
                let robustCount = min(3, scores.count)
                let robustScore = scores.prefix(robustCount).reduce(0, +) / Double(max(1, robustCount))
                let robustAssessment = ElectionalAssessment(
                    suitabilityScore: robustScore,
                    factors: best.value.2.factors,
                    targetHouse: best.value.2.targetHouse,
                    targetRuler: best.value.2.targetRuler,
                    moonIsVoidOfCourse: best.value.2.moonIsVoidOfCourse
                )
                return ElectionTimingCandidate(
                    id: "\(request.precision.rawValue)-\(period.timeIntervalSince1970)",
                    interval: DateInterval(start: max(period, request.startDate), end: min(rawEnd, request.endDate)),
                    peakDate: best.value.0,
                    snapshot: best.value.1,
                    assessment: robustAssessment
                )
            }
        }
    }

    private func periodStart(for date: Date, precision: TimingPrecision, calendar: Calendar) -> Date {
        switch precision {
        case .day:
            calendar.startOfDay(for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month:
            calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }
}
