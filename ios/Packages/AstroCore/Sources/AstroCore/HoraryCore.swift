import Foundation

public enum HoraryQuestionMode: String, Sendable, Codable {
    case yesNo
    case choice
    case timing
    /// Electional search for a favorable future action window. This is intentionally
    /// distinct from `.timing`, which derives timing from one horary question chart.
    case bestTime
}

public enum TraditionalCondition: String, Sendable, Codable, CaseIterable {
    case domicile
    case exaltation
    case triplicity
    case term
    case face
    case peregrine
    case detriment
    case fall
    case angular
    case succedent
    case cadent
    case retrograde
    case cazimi
    case combust
    case underBeams
}

public struct HoraryScoreComponent: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let value: Double

    public init(id: String, value: Double) {
        self.id = id
        self.value = value
    }
}

public struct HoraryPlanetAssessment: Sendable, Equatable, Identifiable, Codable {
    public let body: CelestialBody
    public let house: Int
    public let signIndex: Int
    public let score: Double
    public let conditions: [TraditionalCondition]

    public var id: String { body.id }
}

public enum EssentialDignityKind: String, Sendable, Equatable, Codable, CaseIterable {
    case domicile
    case exaltation
    case triplicity
    case term
    case face

    public var traditionalWeight: Int {
        switch self {
        case .domicile: 5
        case .exaltation: 4
        case .triplicity: 3
        case .term: 2
        case .face: 1
        }
    }
}

public struct HoraryReception: Sendable, Equatable, Codable {
    public let from: CelestialBody
    public let to: CelestialBody
    public let byDomicile: Bool
    public let byExaltation: Bool
    public let dignities: [EssentialDignityKind]
    public let strength: Int
    public let isMutual: Bool

    public var isPresent: Bool { !dignities.isEmpty }

    public init(
        from: CelestialBody,
        to: CelestialBody,
        byDomicile: Bool,
        byExaltation: Bool,
        dignities: [EssentialDignityKind]? = nil,
        strength: Int? = nil,
        isMutual: Bool = false
    ) {
        self.from = from
        self.to = to
        self.byDomicile = byDomicile
        self.byExaltation = byExaltation
        let resolved = dignities ?? [
            byDomicile ? EssentialDignityKind.domicile : nil,
            byExaltation ? EssentialDignityKind.exaltation : nil,
        ].compactMap { $0 }
        self.dignities = resolved
        self.strength = strength ?? resolved.reduce(0) { $0 + $1.traditionalWeight }
        self.isMutual = isMutual
    }

    private enum CodingKeys: String, CodingKey {
        case from, to, byDomicile, byExaltation, dignities, strength, isMutual
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decode(CelestialBody.self, forKey: .from)
        to = try container.decode(CelestialBody.self, forKey: .to)
        byDomicile = try container.decode(Bool.self, forKey: .byDomicile)
        byExaltation = try container.decode(Bool.self, forKey: .byExaltation)
        let legacy: [EssentialDignityKind] = [
            byDomicile ? .domicile : nil,
            byExaltation ? .exaltation : nil,
        ].compactMap { $0 }
        dignities = try container.decodeIfPresent([EssentialDignityKind].self, forKey: .dignities) ?? legacy
        strength = try container.decodeIfPresent(Int.self, forKey: .strength)
            ?? dignities.reduce(0) { $0 + $1.traditionalWeight }
        isMutual = try container.decodeIfPresent(Bool.self, forKey: .isMutual) ?? false
    }
}

public struct HoraryMoonAspectEvent: Sendable, Equatable, Codable {
    public let aspect: ChartAspect
    public let hoursFromQuestion: Double

    public init(aspect: ChartAspect, hoursFromQuestion: Double) {
        self.aspect = aspect
        self.hoursFromQuestion = hoursFromQuestion
    }
}

public struct HoraryMoonCondition: Sendable, Equatable, Codable {
    public let isVoidOfCourse: Bool
    public let nextAspect: ChartAspect?
    public let hoursUntilNextAspect: Double?
    public let previousAspect: HoraryMoonAspectEvent?
    public let upcomingAspects: [HoraryMoonAspectEvent]
    public let hoursUntilSignExit: Double?
    public let isViaCombusta: Bool

    public init(
        isVoidOfCourse: Bool,
        nextAspect: ChartAspect?,
        hoursUntilNextAspect: Double?,
        previousAspect: HoraryMoonAspectEvent? = nil,
        upcomingAspects: [HoraryMoonAspectEvent] = [],
        hoursUntilSignExit: Double? = nil,
        isViaCombusta: Bool = false
    ) {
        self.isVoidOfCourse = isVoidOfCourse
        self.nextAspect = nextAspect
        self.hoursUntilNextAspect = hoursUntilNextAspect
        self.previousAspect = previousAspect
        self.upcomingAspects = upcomingAspects
        self.hoursUntilSignExit = hoursUntilSignExit
        self.isViaCombusta = isViaCombusta
    }

    private enum CodingKeys: String, CodingKey {
        case isVoidOfCourse, nextAspect, hoursUntilNextAspect
        case previousAspect, upcomingAspects, hoursUntilSignExit, isViaCombusta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isVoidOfCourse = try container.decode(Bool.self, forKey: .isVoidOfCourse)
        nextAspect = try container.decodeIfPresent(ChartAspect.self, forKey: .nextAspect)
        hoursUntilNextAspect = try container.decodeIfPresent(Double.self, forKey: .hoursUntilNextAspect)
        previousAspect = try container.decodeIfPresent(HoraryMoonAspectEvent.self, forKey: .previousAspect)
        upcomingAspects = try container.decodeIfPresent([HoraryMoonAspectEvent].self, forKey: .upcomingAspects) ?? []
        hoursUntilSignExit = try container.decodeIfPresent(Double.self, forKey: .hoursUntilSignExit)
        isViaCombusta = try container.decodeIfPresent(Bool.self, forKey: .isViaCombusta) ?? false
    }
}

public enum HoraryPerfectionKind: String, Sendable, Equatable, Codable {
    case direct
    case translation
    case collection
}

public enum HoraryPerfectionStatus: String, Sendable, Equatable, Codable {
    case completes
    case prevented
    case delayed
    case none
    case ambiguous
}

public enum HoraryInterruptionKind: String, Sendable, Equatable, Codable {
    case signChange
    case refranation
    case prohibition
    case frustration
}

public struct HoraryPerfectionPath: Sendable, Equatable, Codable {
    public let kind: HoraryPerfectionKind
    public let exactDate: Date
    public let aspectKind: AspectKind
    public let distanceDegrees: Double
    public let mediator: CelestialBody?
    /// The body carrying the application for this resolved path. Added in schema v3; nil when decoding legacy history.
    public let applyingBody: CelestialBody?
    /// The body receiving the application for this resolved path. Added in schema v3; nil when decoding legacy history.
    public let receivingBody: CelestialBody?
    /// Stable Lilly rule evidence for why this path is admissible. Legacy history decodes to an empty array.
    public let evidenceIDs: [String]

    public init(
        kind: HoraryPerfectionKind,
        exactDate: Date,
        aspectKind: AspectKind,
        distanceDegrees: Double,
        mediator: CelestialBody?,
        applyingBody: CelestialBody? = nil,
        receivingBody: CelestialBody? = nil,
        evidenceIDs: [String] = []
    ) {
        self.kind = kind
        self.exactDate = exactDate
        self.aspectKind = aspectKind
        self.distanceDegrees = distanceDegrees
        self.mediator = mediator
        self.applyingBody = applyingBody
        self.receivingBody = receivingBody
        self.evidenceIDs = evidenceIDs
    }

    private enum CodingKeys: String, CodingKey {
        case kind, exactDate, aspectKind, distanceDegrees, mediator, applyingBody, receivingBody, evidenceIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(HoraryPerfectionKind.self, forKey: .kind)
        exactDate = try container.decode(Date.self, forKey: .exactDate)
        aspectKind = try container.decode(AspectKind.self, forKey: .aspectKind)
        distanceDegrees = try container.decode(Double.self, forKey: .distanceDegrees)
        mediator = try container.decodeIfPresent(CelestialBody.self, forKey: .mediator)
        applyingBody = try container.decodeIfPresent(CelestialBody.self, forKey: .applyingBody)
        receivingBody = try container.decodeIfPresent(CelestialBody.self, forKey: .receivingBody)
        evidenceIDs = try container.decodeIfPresent([String].self, forKey: .evidenceIDs) ?? []
    }
}

public struct HoraryPerfectionInterruption: Sendable, Equatable, Codable {
    public let kind: HoraryInterruptionKind
    public let date: Date
    public let body: CelestialBody
}

public struct HoraryPerfectionAssessment: Sendable, Equatable, Codable {
    public let status: HoraryPerfectionStatus
    public let primaryPath: HoraryPerfectionPath?
    public let interruptions: [HoraryPerfectionInterruption]

    public init(
        status: HoraryPerfectionStatus,
        primaryPath: HoraryPerfectionPath?,
        interruptions: [HoraryPerfectionInterruption]
    ) {
        self.status = status
        self.primaryPath = primaryPath
        self.interruptions = interruptions
    }

    public static let none = HoraryPerfectionAssessment(
        status: .none,
        primaryPath: nil,
        interruptions: []
    )
}

public enum HoraryJudgmentVerdict: String, Sendable, Equatable, Codable {
    case yes
    case no
    case noClearJudgment
}

public struct HoraryJudgment: Sendable, Equatable, Codable {
    public let verdict: HoraryJudgmentVerdict
    public let perfection: HoraryPerfectionAssessment
    public let considerations: HoraryConsiderationAssessment?

    public init(
        verdict: HoraryJudgmentVerdict,
        perfection: HoraryPerfectionAssessment,
        considerations: HoraryConsiderationAssessment? = nil
    ) {
        self.verdict = verdict
        self.perfection = perfection
        self.considerations = considerations
    }

    private enum CodingKeys: String, CodingKey {
        case verdict, perfection, considerations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        verdict = try container.decode(HoraryJudgmentVerdict.self, forKey: .verdict)
        perfection = try container.decode(HoraryPerfectionAssessment.self, forKey: .perfection)
        considerations = try container.decodeIfPresent(HoraryConsiderationAssessment.self, forKey: .considerations)
    }
}

public struct HoraryAnalysis: Sendable, Equatable, Codable {
    public let querentHouse: Int
    public let targetHouse: Int
    public let querentRuler: CelestialBody
    public let targetRuler: CelestialBody
    public let querent: HoraryPlanetAssessment
    public let target: HoraryPlanetAssessment
    public let relationship: ChartAspect?
    public let receptionFromQuerent: HoraryReception
    public let receptionFromTarget: HoraryReception
    public let moon: HoraryMoonCondition
    public let score: Double
    public let components: [HoraryScoreComponent]
    public let judgment: HoraryJudgment?
    public let querentFortitude: HoraryFortitudeAssessment?
    public let targetFortitude: HoraryFortitudeAssessment?

    public init(
        querentHouse: Int,
        targetHouse: Int,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody,
        querent: HoraryPlanetAssessment,
        target: HoraryPlanetAssessment,
        relationship: ChartAspect?,
        receptionFromQuerent: HoraryReception,
        receptionFromTarget: HoraryReception,
        moon: HoraryMoonCondition,
        score: Double,
        components: [HoraryScoreComponent],
        judgment: HoraryJudgment? = nil,
        querentFortitude: HoraryFortitudeAssessment? = nil,
        targetFortitude: HoraryFortitudeAssessment? = nil
    ) {
        self.querentHouse = querentHouse
        self.targetHouse = targetHouse
        self.querentRuler = querentRuler
        self.targetRuler = targetRuler
        self.querent = querent
        self.target = target
        self.relationship = relationship
        self.receptionFromQuerent = receptionFromQuerent
        self.receptionFromTarget = receptionFromTarget
        self.moon = moon
        self.score = score
        self.components = components
        self.judgment = judgment
        self.querentFortitude = querentFortitude
        self.targetFortitude = targetFortitude
    }
}

public struct HoraryChoiceCandidate: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let label: String
    public let house: Int
    public let relatedHouses: [Int]
    public let originalIndex: Int

    public init(
        id: UUID = UUID(),
        label: String,
        house: Int,
        relatedHouses: [Int] = [],
        originalIndex: Int = 0
    ) {
        self.id = id
        self.label = label
        self.house = house
        self.relatedHouses = relatedHouses.filter { $0 != house }
        self.originalIndex = originalIndex
    }
}

public struct HoraryChoiceResult: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let label: String
    public let house: Int
    public let relatedHouses: [Int]
    public let ruler: CelestialBody
    public let supportScore: Double
    public let analysis: HoraryAnalysis
    public let originalIndex: Int
    public let isTiedForLead: Bool

    public init(
        id: UUID,
        label: String,
        house: Int,
        relatedHouses: [Int],
        ruler: CelestialBody,
        supportScore: Double,
        analysis: HoraryAnalysis,
        originalIndex: Int,
        isTiedForLead: Bool = false
    ) {
        self.id = id
        self.label = label
        self.house = house
        self.relatedHouses = relatedHouses
        self.ruler = ruler
        self.supportScore = supportScore
        self.analysis = analysis
        self.originalIndex = originalIndex
        self.isTiedForLead = isTiedForLead
    }
}

public enum HoraryChoiceSignificatorMode: Sendable, Equatable {
    case sharedPrimary(house: Int)
    case independentPrimary
}

public enum HoraryEngine {
    public static let traditionalPlanets: [CelestialBody] = [
        .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn,
    ]

    public static func ruler(ofSign signIndex: Int) -> CelestialBody {
        switch normalizedSign(signIndex) {
        case 0: .mars
        case 1: .venus
        case 2: .mercury
        case 3: .moon
        case 4: .sun
        case 5: .mercury
        case 6: .venus
        case 7: .mars
        case 8: .jupiter
        case 9: .saturn
        case 10: .saturn
        default: .jupiter
        }
    }

    public static func ruler(ofHouse house: Int, in snapshot: ChartSnapshot) -> CelestialBody {
        guard let cusp = snapshot.houses.first(where: { $0.number == house }) else {
            return .mars
        }
        return ruler(ofSign: Int(normalizeDegrees(cusp.cuspDegrees) / 30))
    }

    public static func assess(
        _ body: CelestialBody,
        in snapshot: ChartSnapshot
    ) -> HoraryPlanetAssessment {
        guard let point = snapshot.point(body) else {
            return HoraryPlanetAssessment(
                body: body,
                house: 0,
                signIndex: 0,
                score: 0,
                conditions: []
            )
        }
        let sign = point.signIndex
        let house = snapshot.house(containing: point.longitudeDegrees)
        var score = 0.0
        var conditions: [TraditionalCondition] = []

        if ruler(ofSign: sign) == body {
            score += 15
            conditions.append(.domicile)
        } else if ruler(ofSign: oppositeSign(sign)) == body {
            score -= 12
            conditions.append(.detriment)
        }
        if exaltationRuler(ofSign: sign) == body {
            score += 12
            conditions.append(.exaltation)
        } else if exaltationRuler(ofSign: oppositeSign(sign)) == body {
            score -= 15
            conditions.append(.fall)
        }

        if triplicityRuler(ofSign: sign, isDayChart: isDayChart(snapshot)) == body {
            score += 8
            conditions.append(.triplicity)
        }
        if termRuler(ofSign: sign, degreeInSign: point.degreeInSign) == body {
            score += 5
            conditions.append(.term)
        }
        if faceRuler(ofSign: sign, degreeInSign: point.degreeInSign) == body {
            score += 3
            conditions.append(.face)
        }
        if !conditions.contains(.domicile),
           !conditions.contains(.exaltation),
           !conditions.contains(.triplicity),
           !conditions.contains(.term),
           !conditions.contains(.face)
        {
            score -= 5
            conditions.append(.peregrine)
        }

        if [1, 4, 7, 10].contains(house) {
            score += 10
            conditions.append(.angular)
        } else if [2, 5, 8, 11].contains(house) {
            score += 5
            conditions.append(.succedent)
        } else {
            score -= 5
            conditions.append(.cadent)
        }

        if point.retrograde {
            score -= 8
            conditions.append(.retrograde)
        }

        if body != .sun, let sun = snapshot.point(.sun) {
            let distance = angularDistance(point.longitudeDegrees, sun.longitudeDegrees)
            if distance <= 17.0 / 60.0 {
                score += 12
                conditions.append(.cazimi)
            } else if distance <= 8.5 {
                score -= 15
                conditions.append(.combust)
            } else if distance <= 17 {
                score -= 8
                conditions.append(.underBeams)
            }
        }

        return HoraryPlanetAssessment(
            body: body,
            house: house,
            signIndex: sign,
            score: score,
            conditions: conditions
        )
    }

    public static func reception(
        from: CelestialBody,
        to: CelestialBody,
        in snapshot: ChartSnapshot
    ) -> HoraryReception {
        let fromPoint = snapshot.point(from)
        let toPoint = snapshot.point(to)
        let sign = fromPoint?.signIndex ?? 0
        let degree = fromPoint?.degreeInSign ?? 0
        let day = isDayChart(snapshot)
        let dignities = essentialDignitiesHeld(
            by: to,
            atSign: sign,
            degreeInSign: degree,
            isDayChart: day
        )
        let reverseDignities: [EssentialDignityKind]
        if let toPoint {
            reverseDignities = essentialDignitiesHeld(
                by: from,
                atSign: toPoint.signIndex,
                degreeInSign: toPoint.degreeInSign,
                isDayChart: day
            )
        } else {
            reverseDignities = []
        }
        return HoraryReception(
            from: from,
            to: to,
            byDomicile: dignities.contains(.domicile),
            byExaltation: dignities.contains(.exaltation),
            dignities: dignities,
            isMutual: !dignities.isEmpty && !reverseDignities.isEmpty
        )
    }

    public static func reception(
        from: CelestialBody,
        to: CelestialBody,
        fromSignIndex: Int,
        degreeInSign: Double = 0,
        isDayChart: Bool = true
    ) -> HoraryReception {
        let dignities = essentialDignitiesHeld(
            by: to,
            atSign: fromSignIndex,
            degreeInSign: degreeInSign,
            isDayChart: isDayChart
        )
        return HoraryReception(
            from: from,
            to: to,
            byDomicile: dignities.contains(.domicile),
            byExaltation: dignities.contains(.exaltation),
            dignities: dignities
        )
    }

    public static func analyze(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        targetRuler override: CelestialBody? = nil,
        relatedHouses: [Int] = []
    ) -> HoraryAnalysis {
        let querentRuler = ruler(ofHouse: 1, in: snapshot)
        let targetRuler = override ?? ruler(ofHouse: targetHouse, in: snapshot)
        let querent = assess(querentRuler, in: snapshot)
        let target = assess(targetRuler, in: snapshot)
        let relationship = validTraditionalAspects(in: snapshot).first {
            Set([$0.firstID, $0.secondID]) == Set([querentRuler.id, targetRuler.id])
        }
        let fromQuerent = reception(from: querentRuler, to: targetRuler, in: snapshot)
        let fromTarget = reception(from: targetRuler, to: querentRuler, in: snapshot)
        let moon = moonCondition(in: snapshot)

        var components: [HoraryScoreComponent] = []
        let relationshipScore = querentRuler == targetRuler
            ? 30
            : scoreRelationship(relationship)
        components.append(.init(id: "significator-relationship", value: relationshipScore))

        let receptionScore: Double
        if fromQuerent.isPresent, fromTarget.isPresent {
            receptionScore = 20
        } else if fromQuerent.isPresent || fromTarget.isPresent {
            receptionScore = 10
        } else {
            receptionScore = 0
        }
        components.append(.init(id: "reception", value: receptionScore))

        var moonScore = moon.isVoidOfCourse ? -15.0 : 5.0
        if let next = moon.nextAspect {
            if [querentRuler.id, targetRuler.id].contains(next.firstID)
                || [querentRuler.id, targetRuler.id].contains(next.secondID)
            {
                moonScore += next.kind.supportive || next.kind == .conjunction ? 10 : -5
            }
        }
        components.append(.init(id: "moon", value: moonScore))

        let strengthScore = clamp((querent.score + target.score) / 4, lower: -10, upper: 10)
        components.append(.init(id: "strength", value: strengthScore))

        let relatedRulers = Set(relatedHouses.filter { $0 != targetHouse }.map {
            ruler(ofHouse: $0, in: snapshot)
        })
        if !relatedRulers.isEmpty {
            let average = relatedRulers
                .map { assess($0, in: snapshot).score }
                .reduce(0, +) / Double(relatedRulers.count)
            components.append(
                .init(id: "related-area-support", value: clamp(average / 6, lower: -5, upper: 5))
            )
        }

        let raw = 50 + components.reduce(0) { $0 + $1.value }
        return HoraryAnalysis(
            querentHouse: 1,
            targetHouse: targetHouse,
            querentRuler: querentRuler,
            targetRuler: targetRuler,
            querent: querent,
            target: target,
            relationship: relationship,
            receptionFromQuerent: fromQuerent,
            receptionFromTarget: fromTarget,
            moon: moon,
            score: clamp(raw, lower: 0, upper: 100),
            components: components
        )
    }

    public static func judgedAnalysis(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        targetRuler override: CelestialBody? = nil,
        relatedHouses: [Int] = [],
        calculator: SwissEphemerisCalculator,
        timeZone: TimeZone? = nil
    ) async throws -> HoraryAnalysis {
        let base = analyze(
            snapshot: snapshot,
            targetHouse: targetHouse,
            targetRuler: override,
            relatedHouses: relatedHouses
        )
        async let perfectionTask = calculator.resolveHoraryPerfection(
            snapshot: snapshot,
            querentRuler: base.querentRuler,
            targetRuler: base.targetRuler
        )
        async let moonTask = calculator.resolveHoraryMoonTestimony(snapshot: snapshot)
        async let supplementalTask = calculator.resolveLillySupplemental(snapshot: snapshot)
        let perfection = try await perfectionTask
        let resolvedMoon = try await moonTask
        let supplemental = try await supplementalTask
        let planetaryHour = await calculator.resolveHoraryPlanetaryHour(
            snapshot: snapshot,
            timeZone: timeZone
        )
        let querentFortitude = HoraryLillyFortitudeEngine.assess(
            base.querentRuler,
            in: snapshot,
            counterpart: base.targetRuler,
            supplemental: supplemental
        )
        let targetFortitude = HoraryLillyFortitudeEngine.assess(
            base.targetRuler,
            in: snapshot,
            counterpart: base.querentRuler,
            supplemental: supplemental
        )
        let considerations = HoraryEngine.considerations(
            in: snapshot,
            targetHouse: targetHouse,
            planetaryHour: planetaryHour,
            supplemental: supplemental
        )
        let verdict: HoraryJudgmentVerdict
        switch perfection.status {
        case .completes: verdict = .yes
        case .prevented: verdict = .no
        case .delayed, .none, .ambiguous: verdict = .noClearJudgment
        }
        return HoraryAnalysis(
            querentHouse: base.querentHouse,
            targetHouse: base.targetHouse,
            querentRuler: base.querentRuler,
            targetRuler: base.targetRuler,
            querent: base.querent,
            target: base.target,
            relationship: base.relationship,
            receptionFromQuerent: base.receptionFromQuerent,
            receptionFromTarget: base.receptionFromTarget,
            moon: resolvedMoon,
            score: base.score,
            components: base.components,
            judgment: HoraryJudgment(
                verdict: verdict,
                perfection: perfection,
                considerations: considerations
            ),
            querentFortitude: querentFortitude,
            targetFortitude: targetFortitude
        )
    }

    public static func analyzeChoices(
        snapshot: ChartSnapshot,
        candidates: [HoraryChoiceCandidate],
        mode: HoraryChoiceSignificatorMode = .independentPrimary
    ) -> [HoraryChoiceResult] {
        let analyses = candidates.map { candidate in
            let assignedRuler: CelestialBody?
            if case let .sharedPrimary(house) = mode,
               let cusp = snapshot.houses.first(where: { $0.number == house })
            {
                let signIndex = Int(normalizeDegrees(cusp.cuspDegrees) / 30)
                let rulers = triplicityRulers(ofSign: signIndex, isDayChart: isDayChart(snapshot))
                assignedRuler = candidate.originalIndex < rulers.count
                    ? rulers[candidate.originalIndex]
                    : nil
            } else {
                assignedRuler = nil
            }
            return (
                candidate,
                analyze(
                    snapshot: snapshot,
                    targetHouse: candidate.house,
                    targetRuler: assignedRuler,
                    relatedHouses: candidate.relatedHouses
                )
            )
        }
        return analyses.map { item in
            let candidate = item.0
            let analysis = item.1
            return HoraryChoiceResult(
                id: candidate.id,
                label: candidate.label,
                house: candidate.house,
                relatedHouses: candidate.relatedHouses,
                ruler: analysis.targetRuler,
                supportScore: analysis.score,
                analysis: analysis,
                originalIndex: candidate.originalIndex
            )
        }
        .sorted {
            if abs($0.supportScore - $1.supportScore) > 0.000_001 {
                return $0.supportScore > $1.supportScore
            }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    public static func judgedChoices(
        snapshot: ChartSnapshot,
        candidates: [HoraryChoiceCandidate],
        mode: HoraryChoiceSignificatorMode,
        calculator: SwissEphemerisCalculator,
        timeZone: TimeZone? = nil
    ) async throws -> [HoraryChoiceResult] {
        let assigned = analyzeChoices(snapshot: snapshot, candidates: candidates, mode: mode)
        var judged: [HoraryChoiceResult] = []
        for result in assigned {
            let analysis = try await judgedAnalysis(
                snapshot: snapshot,
                targetHouse: result.house,
                targetRuler: result.ruler,
                relatedHouses: result.relatedHouses,
                calculator: calculator,
                timeZone: timeZone
            )
            judged.append(
                HoraryChoiceResult(
                    id: result.id,
                    label: result.label,
                    house: result.house,
                    relatedHouses: result.relatedHouses,
                    ruler: result.ruler,
                    supportScore: analysis.score,
                    analysis: analysis,
                    originalIndex: result.originalIndex
                )
            )
        }
        let sorted = judged.sorted(by: choicePrecedes)
        guard sorted.count > 1 else { return sorted }
        let leader = sorted[0]
        return sorted.map { result in
            let tiedWithLeader = result.id != leader.id
                && !choicePrecedes(leader, result)
                && !choicePrecedes(result, leader)
            return HoraryChoiceResult(
                id: result.id,
                label: result.label,
                house: result.house,
                relatedHouses: result.relatedHouses,
                ruler: result.ruler,
                supportScore: result.supportScore,
                analysis: result.analysis,
                originalIndex: result.originalIndex,
                isTiedForLead: tiedWithLeader
                    || (result.id == leader.id && sorted.dropFirst().contains {
                        !choicePrecedes(leader, $0) && !choicePrecedes($0, leader)
                    })
            )
        }
    }

    private static func choicePrecedes(_ lhs: HoraryChoiceResult, _ rhs: HoraryChoiceResult) -> Bool {
        let lhsJudgment = lhs.analysis.judgment
        let rhsJudgment = rhs.analysis.judgment
        let lhsRank = judgmentRank(lhsJudgment?.verdict)
        let rhsRank = judgmentRank(rhsJudgment?.verdict)
        if lhsRank != rhsRank { return lhsRank > rhsRank }

        let lhsPath = lhsJudgment?.perfection.primaryPath
        let rhsPath = rhsJudgment?.perfection.primaryPath
        if let lhsPath, let rhsPath {
            let lhsConjunction = lhsPath.aspectKind == .conjunction
            let rhsConjunction = rhsPath.aspectKind == .conjunction
            if lhsConjunction != rhsConjunction { return lhsConjunction }
            if abs(lhsPath.exactDate.timeIntervalSince(rhsPath.exactDate)) > 60 {
                return lhsPath.exactDate < rhsPath.exactDate
            }
        } else if lhsPath != nil || rhsPath != nil {
            return lhsPath != nil
        }

        let lhsReception = receptionRank(lhs.analysis)
        let rhsReception = receptionRank(rhs.analysis)
        if lhsReception != rhsReception { return lhsReception > rhsReception }
        if let lhsFortitude = lhs.analysis.targetFortitude?.total,
           let rhsFortitude = rhs.analysis.targetFortitude?.total,
           lhsFortitude != rhsFortitude
        {
            return lhsFortitude > rhsFortitude
        }
        let lhsMoon = moonTestimonyRank(lhs.analysis)
        let rhsMoon = moonTestimonyRank(rhs.analysis)
        if lhsMoon != rhsMoon { return lhsMoon > rhsMoon }
        return false
    }

    private static func judgmentRank(_ verdict: HoraryJudgmentVerdict?) -> Int {
        switch verdict {
        case .yes: 2
        case .noClearJudgment: 1
        case .no: 0
        case nil: -1
        }
    }

    private static func receptionRank(_ analysis: HoraryAnalysis) -> Int {
        if analysis.receptionFromQuerent.isPresent, analysis.receptionFromTarget.isPresent { return 2 }
        return analysis.receptionFromQuerent.isPresent || analysis.receptionFromTarget.isPresent ? 1 : 0
    }

    private static func moonTestimonyRank(_ analysis: HoraryAnalysis) -> Int {
        guard !analysis.moon.isVoidOfCourse else { return 0 }
        guard let next = analysis.moon.nextAspect else { return 1 }
        let ids = [next.firstID, next.secondID]
        return ids.contains(analysis.targetRuler.id) ? 3 : 2
    }

    public static func triplicityRuler(
        ofSign signIndex: Int,
        isDayChart: Bool
    ) -> CelestialBody {
        triplicityRulers(ofSign: signIndex, isDayChart: isDayChart)[0]
    }

    public static func termRuler(
        ofSign signIndex: Int,
        degreeInSign: Double
    ) -> CelestialBody {
        let degree = min(29.999_999, max(0, degreeInSign))
        let terms: [(Double, CelestialBody)]
        switch normalizedSign(signIndex) {
        case 0: terms = [(6, .jupiter), (12, .venus), (20, .mercury), (25, .mars), (30, .saturn)]
        case 1: terms = [(8, .venus), (14, .mercury), (22, .jupiter), (27, .saturn), (30, .mars)]
        case 2: terms = [(6, .mercury), (12, .jupiter), (17, .venus), (24, .mars), (30, .saturn)]
        case 3: terms = [(7, .mars), (13, .venus), (19, .mercury), (26, .jupiter), (30, .saturn)]
        case 4: terms = [(6, .jupiter), (11, .venus), (18, .saturn), (24, .mercury), (30, .mars)]
        case 5: terms = [(7, .mercury), (17, .venus), (21, .jupiter), (28, .mars), (30, .saturn)]
        case 6: terms = [(6, .saturn), (14, .mercury), (21, .jupiter), (28, .venus), (30, .mars)]
        case 7: terms = [(7, .mars), (11, .venus), (19, .mercury), (24, .jupiter), (30, .saturn)]
        case 8: terms = [(12, .jupiter), (17, .venus), (21, .mercury), (26, .saturn), (30, .mars)]
        case 9: terms = [(7, .mercury), (14, .jupiter), (22, .venus), (26, .saturn), (30, .mars)]
        case 10: terms = [(7, .mercury), (13, .venus), (20, .jupiter), (25, .mars), (30, .saturn)]
        default: terms = [(12, .venus), (16, .jupiter), (19, .mercury), (28, .mars), (30, .saturn)]
        }
        return terms.first(where: { degree < $0.0 })?.1 ?? terms.last!.1
    }

    public static func faceRuler(
        ofSign signIndex: Int,
        degreeInSign: Double
    ) -> CelestialBody {
        let degree = min(29.999_999, max(0, degreeInSign))
        let chaldean: [CelestialBody] = [.mars, .sun, .venus, .mercury, .moon, .saturn, .jupiter]
        let decanIndex = normalizedSign(signIndex) * 3 + Int(degree / 10)
        return chaldean[decanIndex % chaldean.count]
    }

    public static func essentialDignitiesHeld(
        by body: CelestialBody,
        atSign signIndex: Int,
        degreeInSign: Double,
        isDayChart: Bool
    ) -> [EssentialDignityKind] {
        var result: [EssentialDignityKind] = []
        if ruler(ofSign: signIndex) == body { result.append(.domicile) }
        if exaltationRuler(ofSign: signIndex) == body { result.append(.exaltation) }
        if triplicityRuler(ofSign: signIndex, isDayChart: isDayChart) == body { result.append(.triplicity) }
        if termRuler(ofSign: signIndex, degreeInSign: degreeInSign) == body { result.append(.term) }
        if faceRuler(ofSign: signIndex, degreeInSign: degreeInSign) == body { result.append(.face) }
        return result
    }

    /// Traditional Dorothean triplicity rulers, ordered for the chart sect.
    /// The third value is the participating ruler used for a third same-area option.
    public static func triplicityRulers(
        ofSign signIndex: Int,
        isDayChart: Bool
    ) -> [CelestialBody] {
        let rulers: (day: CelestialBody, night: CelestialBody, participating: CelestialBody)
        switch normalizedSign(signIndex) % 4 {
        case 0: rulers = (.sun, .jupiter, .saturn)       // Fire
        case 1: rulers = (.venus, .moon, .mars)          // Earth
        case 2: rulers = (.saturn, .mercury, .jupiter)   // Air
        default: rulers = (.venus, .mars, .moon)         // Water
        }
        return isDayChart
            ? [rulers.day, rulers.night, rulers.participating]
            : [rulers.night, rulers.day, rulers.participating]
    }

    public static func isDayChart(_ snapshot: ChartSnapshot) -> Bool {
        guard let sun = snapshot.point(.sun) else { return true }
        return (7 ... 12).contains(snapshot.house(containing: sun.longitudeDegrees))
    }

    public static func validTraditionalAspects(in snapshot: ChartSnapshot) -> [ChartAspect] {
        snapshot.aspects.filter { aspect in
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID),
                  traditionalPlanets.contains(first),
                  traditionalPlanets.contains(second)
            else {
                return false
            }
            return aspect.orbDegrees <= (traditionalOrb(first) + traditionalOrb(second)) / 2
        }
    }

    public static func moonCondition(in snapshot: ChartSnapshot) -> HoraryMoonCondition {
        guard let moon = snapshot.point(.moon) else {
            return HoraryMoonCondition(
                isVoidOfCourse: true,
                nextAspect: nil,
                hoursUntilNextAspect: nil
            )
        }
        let speed = max(0.01, moon.position.longitudeSpeedDegreesPerDay)
        let degreesRemaining = 30 - moon.degreeInSign
        let daysUntilSignExit = degreesRemaining / speed
        let hoursUntilSignExit = daysUntilSignExit * 24
        var candidates: [(ChartAspect, Double)] = []

        for body in traditionalPlanets where body != .moon {
            guard let other = snapshot.point(body) else { continue }
            let start = signedSeparation(
                moon.longitudeDegrees,
                other.longitudeDegrees
            )
            let end = signedSeparation(
                moon.longitudeDegrees + moon.position.longitudeSpeedDegreesPerDay * daysUntilSignExit,
                other.longitudeDegrees + other.position.longitudeSpeedDegreesPerDay * daysUntilSignExit
            )
            for kind in AspectKind.allCases {
                guard let fraction = AspectEventInterpolation.exactCrossingFraction(
                    from: start,
                    to: end,
                    aspectAngleDegrees: kind.angleDegrees
                ) else {
                    continue
                }
                let hours = fraction * hoursUntilSignExit
                guard hours > 0.001 else { continue }
                let firstLongitude = normalizeDegrees(
                    moon.longitudeDegrees + moon.position.longitudeSpeedDegreesPerDay * daysUntilSignExit * fraction
                )
                let secondLongitude = normalizeDegrees(
                    other.longitudeDegrees + other.position.longitudeSpeedDegreesPerDay * daysUntilSignExit * fraction
                )
                candidates.append(
                    (
                        ChartAspect(
                            firstID: CelestialBody.moon.id,
                            secondID: body.id,
                            kind: kind,
                            orbDegrees: 0,
                            phase: .applying,
                            strength: 1,
                            firstLongitude: firstLongitude,
                            secondLongitude: secondLongitude
                        ),
                        hours
                    )
                )
            }
        }

        let upcoming = candidates
            .sorted { $0.1 < $1.1 }
            .map { HoraryMoonAspectEvent(aspect: $0.0, hoursFromQuestion: $0.1) }

        let separating = validTraditionalAspects(in: snapshot)
            .filter { aspect in
                aspect.phase == .separating
                    && (aspect.firstID == CelestialBody.moon.id || aspect.secondID == CelestialBody.moon.id)
            }
            .compactMap { aspect -> HoraryMoonAspectEvent? in
                guard let otherID = [aspect.firstID, aspect.secondID].first(where: { $0 != CelestialBody.moon.id }),
                      let other = CelestialBody(rawValue: otherID),
                      let otherPoint = snapshot.point(other)
                else { return nil }
                let relativeSpeed = abs(
                    moon.position.longitudeSpeedDegreesPerDay
                        - otherPoint.position.longitudeSpeedDegreesPerDay
                )
                guard relativeSpeed > 0.000_1 else { return nil }
                return HoraryMoonAspectEvent(
                    aspect: aspect,
                    hoursFromQuestion: -(aspect.orbDegrees / relativeSpeed * 24)
                )
            }
            .sorted { $0.hoursFromQuestion > $1.hoursFromQuestion }

        let next = upcoming.first
        return HoraryMoonCondition(
            isVoidOfCourse: next == nil,
            nextAspect: next?.aspect,
            hoursUntilNextAspect: next?.hoursFromQuestion,
            previousAspect: separating.first,
            upcomingAspects: upcoming,
            hoursUntilSignExit: hoursUntilSignExit,
            isViaCombusta: isViaCombusta(longitudeDegrees: moon.longitudeDegrees)
        )
    }

    private static func scoreRelationship(_ aspect: ChartAspect?) -> Double {
        guard let aspect else { return 0 }
        guard aspect.phase != .separating else { return 0 }
        let base: Double
        switch aspect.kind {
        case .conjunction: base = 20
        case .trine: base = 15
        case .sextile: base = 12
        case .square: base = 6
        case .opposition: base = 2
        }
        return base
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

    private static func oppositeSign(_ sign: Int) -> Int {
        normalizedSign(sign + 6)
    }

    private static func normalizedSign(_ sign: Int) -> Int {
        ((sign % 12) + 12) % 12
    }

    private static func traditionalOrb(_ body: CelestialBody) -> Double {
        switch body {
        case .sun: 15
        case .moon: 12
        case .mercury, .venus: 7
        case .mars: 8
        case .jupiter, .saturn: 9
        default: 0
        }
    }

    private static func angularDistance(_ first: Double, _ second: Double) -> Double {
        abs(signedSeparation(first, second))
    }

    private static func signedSeparation(_ first: Double, _ second: Double) -> Double {
        var value = normalizeDegrees(second) - normalizeDegrees(first)
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }

    private static func normalizeDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    private static func scale(
        _ value: Double,
        from source: ClosedRange<Double>,
        to destination: ClosedRange<Double>
    ) -> Double {
        let progress = clamp(
            (value - source.lowerBound) / (source.upperBound - source.lowerBound),
            lower: 0,
            upper: 1
        )
        return destination.lowerBound
            + progress * (destination.upperBound - destination.lowerBound)
    }
}

// MARK: - Significators (assigning named elements of a question to houses)

/// A named element of the question bound to the house that represents it.
/// Example: "我" → house 1, "吃饭" → house 5, "家" → house 4, "单位" → house 6.
public struct HorarySignificator: Sendable, Equatable {
    public let label: String
    public let house: Int

    public init(label: String, house: Int) {
        self.label = label
        self.house = house
    }
}

/// Per-element assessment: the house ruler, its condition, and how it relates
/// to the querent's ruler at the question moment.
public struct HorarySignificatorAssessment: Sendable, Equatable, Identifiable, Codable {
    public let label: String
    public let house: Int
    public let ruler: CelestialBody
    public let planet: HoraryPlanetAssessment
    public let relationship: ChartAspect?
    public let score: Double

    public var id: String { "\(label)-\(house)" }

    public init(
        label: String,
        house: Int,
        ruler: CelestialBody,
        planet: HoraryPlanetAssessment,
        relationship: ChartAspect?,
        score: Double
    ) {
        self.label = label
        self.house = house
        self.ruler = ruler
        self.planet = planet
        self.relationship = relationship
        self.score = score
    }
}

extension HoraryEngine {
    /// Assesses each named element of the question. The querent's house
    /// defaults to the first house, matching the fixed significator of "me".
    public static func assessSignificators(
        _ significators: [HorarySignificator],
        snapshot: ChartSnapshot,
        querentHouse: Int = 1
    ) -> [HorarySignificatorAssessment] {
        let querentRuler = ruler(ofHouse: querentHouse, in: snapshot)
        return significators.map { element in
            let ruler = ruler(ofHouse: element.house, in: snapshot)
            let planet = assess(ruler, in: snapshot)
            let relationship = snapshot.aspects.first { aspect in
                Set([aspect.firstID, aspect.secondID]) == Set([querentRuler.id, ruler.id])
            }
            var score = planet.score
            if let relationship {
                score += relationship.kind.supportive ? 6 : relationship.kind.challenging ? -6 : 0
                score += relationship.strength * 4
            }
            return HorarySignificatorAssessment(
                label: element.label,
                house: element.house,
                ruler: ruler,
                planet: planet,
                relationship: relationship,
                score: score
            )
        }
    }
}
