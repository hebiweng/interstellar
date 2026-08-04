import AstroCore
import Foundation

enum NatalLegacyCardFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.natalCards(context.snapshot, language: context.language)
    }
}

extension InsightFactory {
    static func natalCards(
        _ snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let moon = snapshot.point(.moon)
        let venus = snapshot.point(.venus)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let mcSignIndex = Int(snapshot.angles.midheavenDegrees / 30) % 12
        let mcRuler = ruler(ofSign: mcSignIndex)
        let mcRulerPoint = snapshot.point(mcRuler)
        let mcRulerHouse = mcRulerPoint.map { snapshot.house(containing: $0.longitudeDegrees) }
        let top = Array(snapshot.aspects.prefix(4))
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let elementScores = elementBalance(snapshot)
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let dominant = dominantBodies(snapshot.aspects, language: language)
        let orientation = elementOrientation(elementScores, language: language)
        let coreFacts: [InsightFact] = [
            sun.map { fact(localized("Sun", "太阳", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
            moon.map { fact(localized("Moon", "月亮", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            fact(localized("Rising", "上升", language: language), ascSign, .transition, symbol: "ASC"),
        ].compactMap { $0 }
        let loveFacts: [InsightFact] = [
            venus.map { fact(localized("You give", "你给予", language: language), Zodiac.position($0, language: language), .supportive, symbol: "♀") },
            moon.map { fact(localized("You need", "你需要", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
        ].compactMap { $0 }
        let edgeFacts: [InsightFact] = [
            strongestSupport.map { fact(localized("Core strength", "核心优势", language: language), aspectTitle($0, language: language), .supportive) },
            strongestChallenge.map { fact(localized("Growth edge", "成长面", language: language), aspectTitle($0, language: language), .challenging) },
        ].compactMap { $0 }
        let signatureFacts: [InsightFact] = [
            fact(localized("Chart ruler", "命主星", language: language), bodyName(mcRuler, language: language), .supportive, symbol: mcRuler.symbol),
            dominant.map { fact(localized("Dominant", "主导星体", language: language), $0, .transition) },
            fact(localized("Orientation", "总体取向", language: language), orientation, .neutral),
        ].compactMap { $0 }

        return [
            card( id: "natal-interpretation",
                title: localized("Natal interpretation", "本命解读", language: language),
                icon: "✦", visual: .natalCore,
                facts: coreFacts,
                language: language
            ),
            card( id: "emotional-needs",
                title: localized("Emotional needs", "情绪需要", language: language),
                icon: "☽", visual: .needsCard,
                facts: emotionalNeedsFacts(snapshot, language: language),
                language: language
            ),
            card( id: "love-connection",
                title: localized("Love & Connection", "爱与连接", language: language),
                icon: "♡", visual: .dualInsight(
                    opening: venus.map { Zodiac.position($0, language: language) } ?? "",
                    demand: moon.map { Zodiac.position($0, language: language) } ?? "",
                    openingLabel: localized("YOU GIVE", "你给予", language: language),
                    demandLabel: localized("YOU NEED", "你需要", language: language)
                ),
                facts: loveFacts,
                language: language
            ),
            card( id: "career-direction",
                title: localized("Career & direction", "事业与方向", language: language),
                icon: "↗", visual: .growthPath,
                facts: careerDirectionFacts(
                    snapshot: snapshot,
                    mcSignIndex: mcSignIndex,
                    ruler: mcRuler,
                    rulerPoint: mcRulerPoint,
                    rulerHouse: mcRulerHouse,
                    language: language
                ),
                language: language
            ),
            card( id: "strengths-growth",
                title: localized("Strengths & growth edges", "优势与成长面", language: language),
                icon: "✚", visual: .edgeDual(
                    opening: strongestSupport.map { aspectTitle($0, language: language) } ?? "",
                    demand: strongestChallenge.map { aspectTitle($0, language: language) } ?? ""
                ),
                facts: edgeFacts,
                language: language
            ),
            card( id: "element-balance",
                title: localized("Element & mode balance", "元素与模式", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, orientation: elementOrientation(elementScores, language: language), language: language),
                language: language
            ),
            card( id: "house-emphasis",
                title: localized("House emphasis", "宫位侧重", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "chart-signature",
                title: localized("Chart signature", "星盘签名", language: language),
                icon: "✶", visual: .signatureTrio(
                    ruler: mcRuler.symbol,
                    dominant: dominant ?? "",
                    orientation: orientation
                ),
                facts: signatureFacts,
                language: language
            ),
            card( id: "planet-placements",
                title: localized("Planet placements", "行星落座", language: language),
                icon: "⊛", visual: .placementList,
                facts: snapshot.points.map { point in
                    let house = snapshot.house(containing: point.longitudeDegrees)
                    let houseLabel = house > 0
                        ? AstroTerms.house(house, language: language)
                        : ""
                    return fact(
                        bodyName(point.body, language: language),
                        Zodiac.position(point, language: language),
                        point.retrograde ? .challenging : .neutral,
                        note: houseLabel.isEmpty
                            ? ConsumerCopy.lifeArea(house, language: language)
                            : "\(houseLabel) · \(ConsumerCopy.lifeArea(house, language: language))",
                        symbol: point.body.symbol,
                        category: semanticCategory(point.body, language: language)
                    )
                },
                language: language
            ),
            card( id: "key-aspects",
                title: localized("Key aspects", "关键连接", language: language),
                icon: "⌗", visual: .aspectList,
                facts: top.map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(snapshot.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
        ]
    }

    // MARK: - Current Sky (7)

    static func emotionalNeedsFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
        guard let moon = snapshot.point(.moon) else { return [] }
        let house = snapshot.house(containing: moon.longitudeDegrees)
        guard house > 0 else { return [] }
        let technical = localized(
            "Moon in \(Zodiac.englishNames[moon.signIndex]) · House \(house) · \(ConsumerCopy.lifeArea(house, language: .english))",
            "月亮在\(Zodiac.chineseNames[moon.signIndex]) · 第\(house)宫 · \(ConsumerCopy.lifeArea(house, language: .simplifiedChinese))",
            language: language
        )
        return [
            fact(
                localized("Calculated pattern", "计算结果", language: language),
                technical,
                .neutral,
                stableID: "natal.emotional-needs.moon",
                interpretationKey: "natal.emotional-needs.moon-sign-\(moon.signIndex).house-\(house)",
                sourceFactIDs: ["point.moon"],
                symbol: "☽"
            ),
        ]
    }

    static func careerDirectionFacts(
        snapshot: ChartSnapshot,
        mcSignIndex: Int,
        ruler: CelestialBody,
        rulerPoint: ChartPoint?,
        rulerHouse: Int?,
        language: AppLanguage
    ) -> [InsightFact] {
        var facts = [
            fact(
                localized("Public style", "公众风格", language: language),
                Zodiac.name(index: mcSignIndex, language: language),
                .neutral,
                stableID: "natal.career-direction.midheaven",
                interpretationKey: "natal.career-direction.midheaven-sign-\(mcSignIndex)",
                sourceFactIDs: ["angle.midheaven"],
                symbol: "MC"
            ),
        ]
        if let rulerPoint, let rulerHouse, rulerHouse > 0 {
            facts.append(
                fact(
                    localized("Direction ruler", "方向主星", language: language),
                    "\(bodyName(ruler, language: language)) · \(Zodiac.position(rulerPoint, language: language))",
                    .transition,
                    stableID: "natal.career-direction.ruler",
                    interpretationKey: "natal.career-direction.ruler-\(ruler.rawValue).house-\(rulerHouse)",
                    sourceFactIDs: ["point.\(ruler.rawValue)"],
                    symbol: ruler.symbol
                )
            )
            facts.append(
                fact(
                    localized("Contribution arena", "贡献领域", language: language),
                    ConsumerCopy.lifeArea(rulerHouse, language: language),
                    .supportive,
                    stableID: "natal.career-direction.ruler-house",
                    interpretationKey: "natal.career-direction.house-\(rulerHouse)",
                    sourceFactIDs: ["point.\(ruler.rawValue)"],
                    symbol: "\(rulerHouse)"
                )
            )
        }
        return facts
    }

    // MARK: - Solar return anchors (prototype .connection-grid / .compare-strip)

    static func semanticCategory(_ body: CelestialBody, language: AppLanguage) -> String {
        switch language {
        case .english, .spanish, .french:
            return switch body {
            case .sun, .moon: "Core/self"
            case .mercury: "Mind/voice"
            case .venus: "Heart/values"
            case .mars: "Drive/action"
            case .jupiter: "Growth/belief"
            case .saturn: "Structure/limits"
            case .uranus: "Change/innovation"
            case .neptune: "Vision/intuition"
            case .pluto: "Transformation/power"
            case .trueNode: "Direction/fate"
            }
        case .simplifiedChinese:
            return switch body {
            case .sun, .moon: "核心/自我"
            case .mercury: "思维/表达"
            case .venus: "情感/价值"
            case .mars: "行动/驱动"
            case .jupiter: "成长/信念"
            case .saturn: "结构/边界"
            case .uranus: "改变/创新"
            case .neptune: "想象/直觉"
            case .pluto: "转化/力量"
            case .trueNode: "方向/命运"
            }
        }
    }

    // MARK: - Transit timeline helpers (TR-02/TR-04)
}
