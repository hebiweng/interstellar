import AstroCore
import Foundation

enum SynastryLegacyCardFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.synastryCards(
            context.snapshot,
            second: context.natal,
            aspects: context.aspects,
            language: context.language
        )
    }
}

extension InsightFactory {
    static func synastryCards(
        _ snapshot: ChartSnapshot,
        second: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let top = Array(aspects.prefix(6))
        let moonAspects = aspects.filter { $0.firstID == CelestialBody.moon.rawValue || $0.secondID == CelestialBody.moon.rawValue }
        let mercuryAspects = aspects.filter { $0.firstID == CelestialBody.mercury.rawValue || $0.secondID == CelestialBody.mercury.rawValue }
        let venusMarsAspects = aspects.filter {
            let ids = [CelestialBody.venus.rawValue, CelestialBody.mars.rawValue, CelestialBody.pluto.rawValue]
            return ids.contains($0.firstID) || ids.contains($0.secondID)
        }
        let commitmentAspects = aspects.filter {
            let ids = [CelestialBody.saturn.rawValue, CelestialBody.jupiter.rawValue]
            return ids.contains($0.firstID) || ids.contains($0.secondID)
        }
        let overlayFacts = houseOverlayFacts(snapshot, second: second, language: language)

        return [
            card( id: "relationship-overview",
                title: localized("Relationship overview", "关系总览", language: language),
                icon: "∞", visual: .bondOrbit,
                facts: top.prefix(3).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "perspectives",
                title: localized("How you experience each other", "彼此的体验", language: language),
                icon: "◐", visual: .perspectiveTabs,
                facts: top.prefix(3).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: bodyPair($0, language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "emotional-connection",
                title: localized("Emotional connection", "情感连接", language: language),
                icon: "☽", visual: .connectionGrid,
                facts: emotionalFacts(moonAspects, language: language),
                language: language
            ),
            card( id: "communication",
                title: localized("Communication", "沟通", language: language),
                icon: "☿", visual: .pathFlow,
                facts: emotionalFacts(mercuryAspects, language: language),
                language: language
            ),
            card( id: "chemistry",
                title: localized("Attraction & chemistry", "吸引与化学反应", language: language),
                icon: "♀", visual: .dualInsight(
                    opening: venusMarsAspects.first(where: { $0.kind.supportive }).map { aspectTitle($0, language: language) } ?? "",
                    demand: venusMarsAspects.first(where: { $0.kind.challenging }).map { aspectTitle($0, language: language) } ?? "",
                    openingLabel: localized("ATTRACTION", "吸引", language: language),
                    demandLabel: localized("INTENSITY", "强度", language: language)
                ),
                facts: emotionalFacts(venusMarsAspects, language: language),
                language: language
            ),
            card( id: "commitment",
                title: localized("Commitment & longevity", "承诺与长久", language: language),
                icon: "♄", visual: .connectionGrid,
                facts: emotionalFacts(commitmentAspects, language: language),
                language: language
            ),
            card( id: "house-overlays",
                title: localized("House overlays", "落宫叠加", language: language),
                icon: "⌂", visual: .houseOverlayRows,
                facts: overlayFacts,
                language: language
            ),
            card( id: "key-inter-aspects",
                title: localized("Key inter-aspects", "主要相互连接", language: language),
                icon: "⌗", visual: .aspectList,
                facts: top.map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
        ]
    }

    // MARK: - Shared helpers

    static func bodyPair(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let first = CelestialBody(rawValue: aspect.firstID).map { bodyName($0, language: language) } ?? aspect.firstID
        let second = CelestialBody(rawValue: aspect.secondID).map { bodyName($0, language: language) } ?? aspect.secondID
        return "\(first) → \(second)"
    }

    static func emotionalFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let sample = Array(aspects.prefix(4))
        guard !sample.isEmpty else { return [] }
        return sample.map { aspect in
            fact(
                aspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                progress: aspect.strength
            )
        }
    }

    static func houseOverlayFacts(
        _ first: ChartSnapshot,
        second: ChartSnapshot?,
        language: AppLanguage
    ) -> [InsightFact] {
        guard let second else { return [] }
        return first.points.prefix(6).map { point in
            let house = second.house(containing: point.longitudeDegrees)
            return fact(
                bodyName(point.body, language: language),
                ConsumerCopy.lifeArea(house, language: language),
                .transition,
                note: "\(Zodiac.name(index: point.signIndex, language: language)) \(Zodiac.formatDegree(point.degreeInSign))",
                symbol: point.body.symbol
            )
        }
    }
}
