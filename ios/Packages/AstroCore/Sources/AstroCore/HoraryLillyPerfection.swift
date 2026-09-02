import Foundation

public struct HoraryDirectPerfectionEligibility: Sendable, Equatable, Codable {
    public let isEligible: Bool
    public let evidenceIDs: [String]

    public init(isEligible: Bool, evidenceIDs: [String]) {
        self.isEligible = isEligible
        self.evidenceIDs = evidenceIDs
    }
}

/// Pure Lilly policy used by the ephemeris resolver. Keeping the admissibility rules
/// separate from event search makes each traditional condition explicit and testable.
public enum HoraryLillyPerfectionPolicy {
    public static func directEligibility(
        aspectKind: AspectKind,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody,
        snapshot: ChartSnapshot,
        moonSeparatedFromTarget: Bool
    ) -> HoraryDirectPerfectionEligibility {
        switch aspectKind {
        case .conjunction:
            return .init(
                isEligible: true,
                evidenceIDs: ["lilly.perfection.conjunction.application"]
            )

        case .sextile, .trine:
            let goodHouses = areInGoodHouses(querentRuler, targetRuler, snapshot: snapshot)
            let dignified = bothEssentiallyDignified(querentRuler, targetRuler, snapshot: snapshot)
            return .init(
                isEligible: goodHouses && dignified,
                evidenceIDs: [
                    goodHouses ? "lilly.perfection.soft-aspect.good-houses" : "lilly.perfection.soft-aspect.bad-houses",
                    dignified ? "lilly.perfection.soft-aspect.essential-dignity" : "lilly.perfection.soft-aspect.missing-essential-dignity",
                ]
            )

        case .square:
            let goodHouses = areInGoodHouses(querentRuler, targetRuler, snapshot: snapshot)
            let dignified = bothEssentiallyDignified(querentRuler, targetRuler, snapshot: snapshot)
            return .init(
                isEligible: goodHouses && dignified,
                evidenceIDs: [
                    goodHouses ? "lilly.perfection.square.good-houses" : "lilly.perfection.square.bad-houses",
                    dignified ? "lilly.perfection.square.essential-dignity" : "lilly.perfection.square.missing-essential-dignity",
                ]
            )

        case .opposition:
            let mutualHouse = mutualReceptionByHouse(querentRuler, targetRuler, snapshot: snapshot)
            let friendlyHouses = areInGoodHouses(querentRuler, targetRuler, snapshot: snapshot)
            let eligible = mutualHouse && friendlyHouses && moonSeparatedFromTarget
            return .init(
                isEligible: eligible,
                evidenceIDs: [
                    mutualHouse ? "lilly.perfection.opposition.mutual-reception-house" : "lilly.perfection.opposition.no-mutual-reception-house",
                    friendlyHouses ? "lilly.perfection.opposition.friendly-houses" : "lilly.perfection.opposition.unfriendly-houses",
                    moonSeparatedFromTarget ? "lilly.perfection.opposition.moon-separated-quesited" : "lilly.perfection.opposition.moon-not-separated-quesited",
                ]
            )
        }
    }

    public static func translationReceptionIsEligible(
        translator: CelestialBody,
        separatedFrom: CelestialBody,
        appliesTo _: CelestialBody,
        snapshot: ChartSnapshot
    ) -> Bool {
        let reception = HoraryEngine.reception(from: translator, to: separatedFrom, in: snapshot)
        return reception.dignities.contains(.domicile)
            || reception.dignities.contains(.triplicity)
            || reception.dignities.contains(.term)
    }

    public static func collectionReceptionIsEligible(
        collector: CelestialBody,
        firstSignificator: CelestialBody,
        secondSignificator: CelestialBody,
        snapshot: ChartSnapshot
    ) -> Bool {
        // Lilly p.145: both principal significators "receive him" (the collector)
        // in some of their essential dignities.
        let firstReceivesCollector = HoraryEngine.reception(
            from: collector,
            to: firstSignificator,
            in: snapshot
        ).isPresent
        let secondReceivesCollector = HoraryEngine.reception(
            from: collector,
            to: secondSignificator,
            in: snapshot
        ).isPresent
        return firstReceivesCollector && secondReceivesCollector
    }

    public static func isRefranation(
        applyingBody: CelestialBody,
        stationBody: CelestialBody,
        stationDate: Date,
        retrogradeAfter: Bool,
        deadline: Date
    ) -> Bool {
        applyingBody == stationBody && retrogradeAfter && stationDate < deadline
    }

    public static func isProhibitionSequence(
        thirdSpeed: Double,
        applyingSpeed: Double,
        firstContact: Date,
        secondContact: Date,
        deadline: Date
    ) -> Bool {
        thirdSpeed > applyingSpeed
            && firstContact < secondContact
            && secondContact < deadline
    }

    public static func goodHouse(_ house: Int) -> Bool {
        [1, 2, 3, 4, 5, 7, 9, 10, 11].contains(house)
    }

    private static func areInGoodHouses(
        _ first: CelestialBody,
        _ second: CelestialBody,
        snapshot: ChartSnapshot
    ) -> Bool {
        guard let firstPoint = snapshot.point(first), let secondPoint = snapshot.point(second) else { return false }
        return goodHouse(snapshot.house(containing: firstPoint.longitudeDegrees))
            && goodHouse(snapshot.house(containing: secondPoint.longitudeDegrees))
    }

    private static func bothEssentiallyDignified(
        _ first: CelestialBody,
        _ second: CelestialBody,
        snapshot: ChartSnapshot
    ) -> Bool {
        guard let firstPoint = snapshot.point(first), let secondPoint = snapshot.point(second) else { return false }
        let day = HoraryEngine.isDayChart(snapshot)
        return !HoraryEngine.essentialDignitiesHeld(
            by: first,
            atSign: firstPoint.signIndex,
            degreeInSign: firstPoint.degreeInSign,
            isDayChart: day
        ).isEmpty
            && !HoraryEngine.essentialDignitiesHeld(
                by: second,
                atSign: secondPoint.signIndex,
                degreeInSign: secondPoint.degreeInSign,
                isDayChart: day
            ).isEmpty
    }

    private static func mutualReceptionByHouse(
        _ first: CelestialBody,
        _ second: CelestialBody,
        snapshot: ChartSnapshot
    ) -> Bool {
        HoraryEngine.reception(from: first, to: second, in: snapshot).byDomicile
            && HoraryEngine.reception(from: second, to: first, in: snapshot).byDomicile
    }
}

public extension SwissEphemerisCalculator {
    func resolveHoraryPerfection(
        snapshot: ChartSnapshot,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody
    ) throws -> HoraryPerfectionAssessment {
        let effectiveQuerent = querentRuler == targetRuler ? CelestialBody.moon : querentRuler
        if effectiveQuerent == targetRuler {
            return HoraryPerfectionAssessment(status: .ambiguous, primaryPath: nil, interruptions: [])
        }

        let aspects = HoraryEngine.validTraditionalAspects(in: snapshot)
        let direct = aspect(between: effectiveQuerent, and: targetRuler, in: aspects).flatMap {
            ($0.phase == .applying || $0.phase == .exact) ? $0 : nil
        }

        var directPath: HoraryPerfectionPath?
        var directInterruptions: [HoraryPerfectionInterruption] = []
        if let direct {
            let exactMoon = direct.kind == .opposition
                ? try resolveHoraryMoonTestimony(snapshot: snapshot)
                : nil
            let moonSeparatedFromTarget = exactMoon?.previousAspect.map {
                [$0.aspect.firstID, $0.aspect.secondID].contains(targetRuler.id)
            } ?? false
            let eligibility = HoraryLillyPerfectionPolicy.directEligibility(
                aspectKind: direct.kind,
                querentRuler: effectiveQuerent,
                targetRuler: targetRuler,
                snapshot: snapshot,
                moonSeparatedFromTarget: moonSeparatedFromTarget
            )
            if eligibility.isEligible {
                let pair = applyingPair(effectiveQuerent, targetRuler, snapshot: snapshot)
                directPath = try perfectionPath(
                    kind: .direct,
                    aspect: direct,
                    moving: pair.applying,
                    reference: pair.receiving,
                    mediator: nil,
                    evidenceIDs: eligibility.evidenceIDs,
                    after: snapshot.utcDate
                )
                if let path = directPath {
                    directInterruptions = try strictInterruptions(
                        path: path,
                        originalAspect: direct,
                        snapshot: snapshot,
                        principalBodies: [effectiveQuerent, targetRuler]
                    )
                    if directInterruptions.isEmpty {
                        return HoraryPerfectionAssessment(status: .completes, primaryPath: path, interruptions: [])
                    }
                }
            }
        }

        let alternatives = try alternativePerfections(
            snapshot: snapshot,
            querentRuler: effectiveQuerent,
            targetRuler: targetRuler,
            aspects: aspects
        )
        if let alternative = alternatives.min(by: { $0.exactDate < $1.exactDate }) {
            return HoraryPerfectionAssessment(
                status: .completes,
                primaryPath: alternative,
                interruptions: directInterruptions
            )
        }

        if let directPath {
            let onlyProhibition = !directInterruptions.isEmpty
                && directInterruptions.allSatisfy { $0.kind == .prohibition }
            return HoraryPerfectionAssessment(
                status: onlyProhibition ? .delayed : .prevented,
                primaryPath: directPath,
                interruptions: directInterruptions
            )
        }
        return .none
    }

    private func alternativePerfections(
        snapshot: ChartSnapshot,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody,
        aspects: [ChartAspect]
    ) throws -> [HoraryPerfectionPath] {
        var paths: [HoraryPerfectionPath] = []
        let principalsBehold = aspect(between: querentRuler, and: targetRuler, in: aspects) != nil

        for mediator in HoraryEngine.traditionalPlanets where mediator != querentRuler && mediator != targetRuler {
            guard let withQuerent = aspect(between: mediator, and: querentRuler, in: aspects),
                  let withTarget = aspect(between: mediator, and: targetRuler, in: aspects)
            else { continue }

            let mediatorSpeed = abs(snapshot.point(mediator)?.position.longitudeSpeedDegreesPerDay ?? 0)
            let querentSpeed = abs(snapshot.point(querentRuler)?.position.longitudeSpeedDegreesPerDay ?? 0)
            let targetSpeed = abs(snapshot.point(targetRuler)?.position.longitudeSpeedDegreesPerDay ?? 0)

            let translation: (separated: ChartAspect, applying: ChartAspect, separatedFrom: CelestialBody, appliesTo: CelestialBody)?
            if withQuerent.phase == .separating, withTarget.phase == .applying {
                translation = (withQuerent, withTarget, querentRuler, targetRuler)
            } else if withTarget.phase == .separating, withQuerent.phase == .applying {
                translation = (withTarget, withQuerent, targetRuler, querentRuler)
            } else {
                translation = nil
            }

            if let translation,
               mediatorSpeed > querentSpeed,
               mediatorSpeed > targetSpeed,
               HoraryLillyPerfectionPolicy.translationReceptionIsEligible(
                   translator: mediator,
                   separatedFrom: translation.separatedFrom,
                   appliesTo: translation.appliesTo,
                   snapshot: snapshot
               ),
               let path = try perfectionPath(
                   kind: .translation,
                   aspect: translation.applying,
                   moving: mediator,
                   reference: translation.appliesTo,
                   mediator: mediator,
                   evidenceIDs: [
                       "lilly.perfection.translation.separates-and-applies",
                       "lilly.perfection.translation.reception-house-triplicity-term",
                       "lilly.perfection.translation.translator-faster",
                   ],
                   after: snapshot.utcDate
               ),
               try translationIsUninterrupted(
                   translator: mediator,
                   appliesTo: translation.appliesTo,
                   separatedFrom: translation.separatedFrom,
                   deadline: path.exactDate,
                   start: snapshot.utcDate
               )
            {
                paths.append(path)
            }

            if !principalsBehold,
               withQuerent.phase == .applying,
               withTarget.phase == .applying,
               mediatorSpeed < querentSpeed,
               mediatorSpeed < targetSpeed,
               HoraryLillyPerfectionPolicy.collectionReceptionIsEligible(
                   collector: mediator,
                   firstSignificator: querentRuler,
                   secondSignificator: targetRuler,
                   snapshot: snapshot
               ),
               let firstPath = try perfectionPath(
                   kind: .collection,
                   aspect: withQuerent,
                   moving: querentRuler,
                   reference: mediator,
                   mediator: mediator,
                   evidenceIDs: [
                       "lilly.perfection.collection.more-weighty-collector",
                       "lilly.perfection.collection.significators-receive-collector",
                   ],
                   after: snapshot.utcDate
               ),
               let secondPath = try perfectionPath(
                   kind: .collection,
                   aspect: withTarget,
                   moving: targetRuler,
                   reference: mediator,
                   mediator: mediator,
                   evidenceIDs: [
                       "lilly.perfection.collection.more-weighty-collector",
                       "lilly.perfection.collection.significators-receive-collector",
                   ],
                   after: snapshot.utcDate
               )
            {
                let completion = firstPath.exactDate > secondPath.exactDate ? firstPath : secondPath
                let signChanges = try signChangeInterruptions(
                    bodies: [querentRuler, targetRuler, mediator],
                    before: completion.exactDate,
                    after: snapshot.utcDate
                )
                let firstRefranation = try refranation(
                    applyingBody: querentRuler,
                    before: firstPath.exactDate,
                    after: snapshot.utcDate
                )
                let secondRefranation = try refranation(
                    applyingBody: targetRuler,
                    before: secondPath.exactDate,
                    after: snapshot.utcDate
                )
                if signChanges.isEmpty, firstRefranation == nil, secondRefranation == nil {
                    paths.append(completion)
                }
            }
        }
        return paths
    }

    private func perfectionPath(
        kind: HoraryPerfectionKind,
        aspect: ChartAspect,
        moving: CelestialBody,
        reference: CelestialBody,
        mediator: CelestialBody?,
        evidenceIDs: [String],
        after date: Date
    ) throws -> HoraryPerfectionPath? {
        guard aspect.phase == .applying || aspect.phase == .exact else { return nil }
        let exactDate = aspect.phase == .exact
            ? date
            : try nextExactAspectDate(moving: moving, reference: reference, kind: aspect.kind, after: date)
        return HoraryPerfectionPath(
            kind: kind,
            exactDate: exactDate,
            aspectKind: aspect.kind,
            distanceDegrees: aspect.orbDegrees,
            mediator: mediator,
            applyingBody: moving,
            receivingBody: reference,
            evidenceIDs: evidenceIDs
        )
    }

    private func strictInterruptions(
        path: HoraryPerfectionPath,
        originalAspect: ChartAspect,
        snapshot: ChartSnapshot,
        principalBodies: [CelestialBody]
    ) throws -> [HoraryPerfectionInterruption] {
        guard let applying = path.applyingBody, let receiving = path.receivingBody else { return [] }
        var result = try signChangeInterruptions(
            bodies: principalBodies,
            before: path.exactDate,
            after: snapshot.utcDate
        )
        if let refranation = try refranation(
            applyingBody: applying,
            before: path.exactDate,
            after: snapshot.utcDate
        ) {
            result.append(refranation)
        }
        if originalAspect.kind == .conjunction,
           let frustration = try frustration(
               applying: applying,
               receiving: receiving,
               before: path.exactDate,
               after: snapshot.utcDate
           )
        {
            result.append(frustration)
        }
        if let prohibition = try prohibition(
            applying: applying,
            receiving: receiving,
            before: path.exactDate,
            excluding: Set(principalBodies),
            snapshot: snapshot,
            after: snapshot.utcDate
        ) {
            result.append(prohibition)
        }
        return result.sorted { $0.date < $1.date }
    }

    private func signChangeInterruptions(
        bodies: [CelestialBody],
        before deadline: Date,
        after start: Date
    ) throws -> [HoraryPerfectionInterruption] {
        var result: [HoraryPerfectionInterruption] = []
        for body in Set(bodies) {
            if let ingress = try nextSignIngress(for: body, after: start, before: deadline) {
                result.append(.init(kind: .signChange, date: ingress, body: body))
            }
        }
        return result
    }

    private func refranation(
        applyingBody: CelestialBody,
        before deadline: Date,
        after start: Date
    ) throws -> HoraryPerfectionInterruption? {
        guard let station = try nextStation(for: applyingBody, after: start, before: deadline),
              HoraryLillyPerfectionPolicy.isRefranation(
                  applyingBody: applyingBody,
                  stationBody: applyingBody,
                  stationDate: station.date,
                  retrogradeAfter: station.retrogradeAfter,
                  deadline: deadline
              )
        else { return nil }
        return .init(kind: .refranation, date: station.date, body: applyingBody)
    }

    private func prohibition(
        applying: CelestialBody,
        receiving: CelestialBody,
        before deadline: Date,
        excluding: Set<CelestialBody>,
        snapshot: ChartSnapshot,
        after start: Date
    ) throws -> HoraryPerfectionInterruption? {
        let applyingSpeed = abs(snapshot.point(applying)?.position.longitudeSpeedDegreesPerDay ?? 0)
        var candidates: [HoraryPerfectionInterruption] = []
        for body in HoraryEngine.traditionalPlanets where !excluding.contains(body) {
            let thirdSpeed = abs(snapshot.point(body)?.position.longitudeSpeedDegreesPerDay ?? 0)
            guard thirdSpeed > applyingSpeed,
                  let firstContact = firstMajorAspectDate(between: body, and: applying, after: start, before: deadline),
                  let secondContact = firstMajorAspectDate(between: body, and: receiving, after: firstContact, before: deadline),
                  HoraryLillyPerfectionPolicy.isProhibitionSequence(
                      thirdSpeed: thirdSpeed,
                      applyingSpeed: applyingSpeed,
                      firstContact: firstContact,
                      secondContact: secondContact,
                      deadline: deadline
                  )
            else { continue }
            candidates.append(.init(kind: .prohibition, date: secondContact, body: body))
        }
        return candidates.min { $0.date < $1.date }
    }

    private func frustration(
        applying: CelestialBody,
        receiving: CelestialBody,
        before deadline: Date,
        after start: Date
    ) throws -> HoraryPerfectionInterruption? {
        var candidates: [HoraryPerfectionInterruption] = []
        for third in HoraryEngine.traditionalPlanets where third != applying && third != receiving {
            guard let date = firstExactDate(
                moving: receiving,
                reference: third,
                kind: .conjunction,
                after: start,
                before: deadline
            ) else { continue }
            candidates.append(.init(kind: .frustration, date: date, body: third))
        }
        return candidates.min { $0.date < $1.date }
    }

    private func translationIsUninterrupted(
        translator: CelestialBody,
        appliesTo: CelestialBody,
        separatedFrom: CelestialBody,
        deadline: Date,
        start: Date
    ) throws -> Bool {
        if !(try signChangeInterruptions(
            bodies: [translator, appliesTo],
            before: deadline,
            after: start
        ).isEmpty) { return false }
        if try refranation(applyingBody: translator, before: deadline, after: start) != nil { return false }
        for other in HoraryEngine.traditionalPlanets
            where other != translator && other != appliesTo && other != separatedFrom
        {
            if firstMajorAspectDate(between: translator, and: other, after: start, before: deadline) != nil {
                return false
            }
        }
        return true
    }

    private func firstMajorAspectDate(
        between first: CelestialBody,
        and second: CelestialBody,
        after start: Date,
        before deadline: Date
    ) -> Date? {
        AspectKind.allCases.compactMap { kind in
            firstExactDate(moving: first, reference: second, kind: kind, after: start, before: deadline)
        }.min()
    }

    private func firstExactDate(
        moving: CelestialBody,
        reference: CelestialBody,
        kind: AspectKind,
        after start: Date,
        before deadline: Date
    ) -> Date? {
        guard let date = try? nextExactAspectDate(moving: moving, reference: reference, kind: kind, after: start),
              date < deadline
        else { return nil }
        return date
    }

    private func applyingPair(
        _ first: CelestialBody,
        _ second: CelestialBody,
        snapshot: ChartSnapshot
    ) -> (applying: CelestialBody, receiving: CelestialBody) {
        let firstSpeed = abs(snapshot.point(first)?.position.longitudeSpeedDegreesPerDay ?? 0)
        let secondSpeed = abs(snapshot.point(second)?.position.longitudeSpeedDegreesPerDay ?? 0)
        return firstSpeed >= secondSpeed ? (first, second) : (second, first)
    }

    private func aspect(
        between first: CelestialBody,
        and second: CelestialBody,
        in aspects: [ChartAspect]
    ) -> ChartAspect? {
        aspects.first { Set([$0.firstID, $0.secondID]) == Set([first.id, second.id]) }
    }
}
