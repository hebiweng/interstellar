import AstroCore
import Foundation

enum InsightFactoryError: LocalizedError {
    case invalidCardContract(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCardContract(message):
            "Insight card contract failed: \(message)"
        }
    }
}

enum InsightFactory {
    static func make(
        chart: ChartKind,
        snapshot: ChartSnapshot?,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        content: CorpusContentProvider,
        language: AppLanguage,
        transitCalendar: [Int]
    ) throws -> [InsightCardModel] {
        guard let snapshot else { return [] }
        let cards = switch chart {
        case .natal:
            natalCards(snapshot, language: language)
        case .currentSky:
            skyCards(snapshot, language: language)
        case .transit:
            transitCards(
                snapshot,
                natal: natal,
                aspects: aspects,
                calendar: transitCalendar, language: language
            )
        case .secondary:
            secondaryCards(snapshot, natal: natal, aspects: aspects, language: language)
        }
        let renderedCards = try cards.map { draft in
            let context = InterpretationContextFactory.make(
                chart: chart,
                cardID: draft.id,
                snapshot: snapshot,
                natal: natal,
                aspects: aspects,
                language: language,
                transitCalendar: transitCalendar
            )
            let interpretation = try content.interpret(context)
            return InsightCardModel(
                id: draft.id,
                title: draft.title,
                icon: draft.icon,
                visual: draft.visual,
                facts: draft.facts,
                summary: interpretation.summary,
                detail: interpretation.detail
            )
        }
        try validate(renderedCards, for: chart)
        return renderedCards
    }

    private static func natalCards(
        _ snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let moon = snapshot.point(.moon)
        let venus = snapshot.point(.venus)
        let mars = snapshot.point(.mars)
        let top = Array(snapshot.aspects.prefix(3))
        let balance = counts(snapshot.aspects)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let mcSignIndex = Int(snapshot.angles.midheavenDegrees / 30) % 12
        let mcSign = Zodiac.name(index: mcSignIndex, language: language)
        let mcRuler = ruler(ofSign: mcSignIndex)
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first

        return [
            card( id: "core-structure",
                title: localized("Core structure", "核心结构", language: language),
                icon: "✦",
                visual: .natalCore,
                facts: [
                    fact(localized("Sun", "太阳", language: language), sun.map { Zodiac.position($0, language: language) } ?? "—", symbol: "☉"),
                    fact(localized("Moon", "月亮", language: language), moon.map { Zodiac.position($0, language: language) } ?? "—", symbol: "☽"),
                    fact(localized("Rising", "上升", language: language), ascSign, symbol: "ASC"),
                ],
                language: language
            ),
            card( id: "strongest-themes",
                title: localized("Your strongest themes", "最突出的三项主题", language: language),
                icon: "①",
                visual: .rankedThemes,
                facts: top.enumerated().map { index, aspect in
                    fact(
                        aspectTitle(aspect, language: language),
                        ConsumerCopy.intensity(aspect.strength, language: language),
                        tone(aspect.kind),
                        note: phaseLabel(aspect.phase, language: language),
                        progress: max(0.16, aspect.strength),
                        symbol: "\(index + 1)"
                    )
                },
                language: language
            ),
            card( id: "core-strengths",
                title: localized("Core strengths", "核心优势", language: language),
                icon: "✦",
                visual: .strengthOrbit(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: [
                    fact(localized("Natural support", "自然优势", language: language), strongestSupport.map { aspectTitle($0, language: language) } ?? "—", .supportive),
                    fact(localized("Relationship style", "关系方式", language: language), venus.map { Zodiac.position($0, language: language) } ?? "—", .supportive),
                    fact(localized("Action style", "行动方式", language: language), mars.map { Zodiac.position($0, language: language) } ?? "—", .transition),
                ],
                language: language
            ),
            card( id: "blind-spot",
                title: localized("Primary blind spot", "主要盲点", language: language),
                icon: "◎",
                visual: .blindSpot,
                facts: [
                    fact(
                        localized("Repeated tension", "反复出现的张力", language: language),
                        strongestChallenge.map { aspectTitle($0, language: language) } ?? "—",
                        .challenging,
                        note: strongestChallenge.map {
                            "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))"
                        }
                    ),
                    fact(
                        localized("Emotional reflex", "情绪惯性", language: language),
                        moon.map { Zodiac.position($0, language: language) } ?? "—",
                        .transition
                    ),
                ],
                language: language
            ),
            card( id: "growth-direction",
                title: localized("Growth direction", "成长方向", language: language),
                icon: "→",
                visual: .growthPath,
                facts: [
                    fact(
                        localized("Build", "建立", language: language),
                        moon.map { Zodiac.position($0, language: language) } ?? "—",
                        .transition,
                        symbol: "1"
                    ),
                    fact(
                        localized("Practice", "练习", language: language),
                        strongestChallenge.map { aspectTitle($0, language: language) } ?? "—",
                        .challenging,
                        symbol: "2"
                    ),
                    fact(
                        localized("Express", "发挥", language: language),
                        "\(mcSign) · \(snapshot.point(mcRuler).map { Zodiac.position($0, language: language) } ?? "—")",
                        .supportive,
                        symbol: "3"
                    ),
                ],
                language: language
            ),
        ]
    }

    private static func skyCards(
        _ snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> [InsightCardModel] {
        let top = Array(snapshot.aspects.prefix(3))
        let balance = counts(snapshot.aspects)
        let retrogrades = snapshot.points.filter(\.retrograde)
        let phase = phaseAngle(snapshot)
        let activity = signalDensity(snapshot.aspects, limit: 8)
        let cycleAspects = cycleLeaders(snapshot.aspects)
        let planetFacts = snapshot.points.map {
            fact(
                bodyName($0.body, language: language),
                Zodiac.position($0, language: language),
                $0.retrograde ? .challenging : .neutral,
                note: motionLabel($0, language: language),
                symbol: $0.body.symbol
            )
        }
        let domainScores = domainValues(snapshot)
        return [
            card( id: "sky-overview",
                title: localized("Current sky overview", "当前天空总览", language: language),
                icon: "◉", visual: .skyOverview(
                    phase: phase,
                    activity: activity,
                    cycles: cycleAspects.map { $0?.strength ?? 0 }
                ),
                facts: [
                    fact(localized("Long cycle", "长期周期", language: language), cycleAspects[0].map { aspectTitle($0, language: language) } ?? "—", cycleAspects[0].map { tone($0.kind) } ?? .neutral),
                    fact(localized("Middle cycle", "中期周期", language: language), cycleAspects[1].map { aspectTitle($0, language: language) } ?? "—", cycleAspects[1].map { tone($0.kind) } ?? .neutral),
                    fact(localized("Short cycle", "短期周期", language: language), cycleAspects[2].map { aspectTitle($0, language: language) } ?? "—", cycleAspects[2].map { tone($0.kind) } ?? .neutral),
                    fact(
                        localized("Current cycle", "当前周期", language: language),
                        ConsumerCopy.cycleStage(angle: phase, language: language)
                    ),
                    fact(
                        localized("Review cycles", "回顾调整中的主题", language: language),
                        "\(retrogrades.count)"
                    ),
                    fact(localized("Dominant bodies", "主导星体", language: language), dominantBodies(snapshot.aspects, language: language)),
                    fact(localized("Atmosphere", "整体氛围", language: language), activityLabel(activity, language: language)),
                ],
                language: language
            ),
            card( id: "core-themes",
                title: localized("Core sky themes", "核心天象主题", language: language),
                icon: "✦", visual: .themeCards,
                facts: top.map {
                    fact(
                        aspectTitle($0, language: language),
                        activityLabel(Int($0.strength * 100), language: language),
                        tone($0.kind),
                        note: "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
            card( id: "key-events",
                title: localized("Key sky events", "关键天象事件", language: language),
                icon: "⟐", visual: .eventTimeline,
                facts: top.map {
                    fact(
                        phaseLabel($0.phase, language: language),
                        aspectTitle($0, language: language),
                        tone($0.kind),
                        note: ConsumerCopy.intensity($0.strength, language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "structure-tension",
                title: localized("Sky structure & tension", "天空结构与张力", language: language),
                icon: "◇", visual: .structureMap(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: [
                    fact(localized("Support", "支持", language: language), "\(balance.supportive)", .supportive),
                    fact(localized("Pressure", "压力", language: language), "\(balance.challenging)", .challenging),
                    fact(localized("Focus", "焦点", language: language), dominantBodies(snapshot.aspects, language: language), .transition),
                    fact(localized("Activity", "活跃度", language: language), activityLabel(activity, language: language)),
                ],
                language: language
            ),
            card( id: "collective-domains",
                title: localized("Collective domains", "集体领域影响", language: language),
                icon: "▦", visual: .domainBars(domainScores),
                facts: domainFacts(snapshot, language: language),
                language: language
            ),
            card( id: "observation-focus",
                title: localized("Observation focus", "观察重点与个人联动", language: language),
                icon: "◎", visual: .observation,
                facts: top.map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind)
                    )
                },
                language: language
            ),
            card( id: "sky-evolution",
                title: localized("Sky evolution", "天象演进", language: language),
                icon: "⇢", visual: .evolution,
                facts: timelineFacts(top, language: language),
                language: language
            ),
            card( id: "planet-overview",
                title: localized("Planet overview", "行星速览", language: language),
                icon: "⊛", visual: .planetTable,
                facts: planetFacts,
                language: language
            ),
        ]
    }

    private static func transitCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        calendar: [Int],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let top = Array(aspects.prefix(4))
        let balance = counts(aspects)
        let activity = signalDensity(aspects, limit: 12)
        let fullCalendar = Array((calendar + [Int](repeating: 0, count: 7)).prefix(7))
        let aspectCount = balance.supportive + balance.challenging + balance.neutral
        let supportShare = aspectCount > 0
            ? Int(Double(balance.supportive) / Double(aspectCount) * 100)
            : 0
        let movingFacts = snapshot.points.map { point in
            let house = natal?.house(containing: point.longitudeDegrees) ?? 0
            let strongestTrigger = aspects.first { $0.firstID == point.body.rawValue }
            return fact(
                ConsumerCopy.bodyTheme(point.body, language: language),
                "\(ConsumerCopy.style(signIndex: point.signIndex, language: language)) · \(ConsumerCopy.lifeArea(house, language: language))",
                point.retrograde ? .challenging : .neutral,
                note: "\(motionLabel(point, language: language)) · \(strongestTrigger.map { aspectTitle($0, language: language) } ?? localized("No close trigger", "暂无紧密触发", language: language))",
                symbol: point.body.symbol
            )
        }
        let rhythm = calendar.isEmpty ? top.map(\.strength) : fullCalendar.prefix(10).map { Double($0) / 100 }
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let houseFacts = activeHouseFacts(houseScores, language: language)
        return [
            card( id: "daily-activity",
                title: localized("Daily activity", "日活跃度指数", language: language),
                icon: "◒", visual: .activityGauge(
                    value: activity,
                    supportive: balance.supportive,
                    adjustment: balance.challenging
                ),
                facts: [
                    fact(localized("Active contacts", "活跃联系", language: language), "\(aspectCount)"),
                    fact(localized("Support share", "推动占比", language: language), "\(supportShare)%", .supportive),
                ],
                language: language
            ),
            card( id: "transit-overview",
                title: localized("Current transit overview", "当前行运总览", language: language),
                icon: "◎", visual: .transitOverview(intensity: activity, rhythm: Array(rhythm)),
                facts: top.prefix(3).map {
                    fact(
                        timeLayer($0, language: language),
                        aspectTitle($0, prefix: localized("Transit ", "行运", language: language), language: language),
                        tone($0.kind),
                        note: "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "trigger-themes",
                title: localized("Core trigger themes", "核心触发主题", language: language),
                icon: "◈", visual: .themeCards,
                facts: top.prefix(3).map {
                    let house = natal?.house(containing: $0.firstLongitude) ?? 0
                    return fact(
                        ConsumerCopy.lifeArea(house, language: language),
                        activityLabel(Int($0.strength * 100), language: language),
                        tone($0.kind),
                        note: aspectTitle($0, prefix: localized("Transit ", "行运", language: language), language: language),
                        progress: $0.strength,
                        symbol: houseSymbol(house)
                    )
                },
                language: language
            ),
            card( id: "key-events",
                title: localized("Key transit events", "关键行运事件", language: language),
                icon: "⟐", visual: .gantt,
                facts: top.map {
                    fact(
                        phaseLabel($0.phase, language: language),
                        aspectTitle($0, prefix: localized("Transit ", "行运", language: language), language: language),
                        tone($0.kind),
                        note: ConsumerCopy.intensity($0.strength, language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "support-pressure",
                title: localized("Support & pressure", "支持与压力", language: language),
                icon: "◇", visual: .balanceRing(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: [
                    fact(localized("Support", "支持", language: language), top.first(where: { $0.kind.supportive }).map { aspectTitle($0, language: language) } ?? "—", .supportive),
                    fact(localized("Pressure", "压力", language: language), top.first(where: { $0.kind.challenging }).map { aspectTitle($0, language: language) } ?? "—", .challenging),
                    fact(localized("Outlet", "出口", language: language), top.first.map { bodyPair($0, language: language) } ?? "—", .transition),
                ],
                language: language
            ),
            card( id: "life-domains",
                title: localized("Life domains", "生活领域影响", language: language),
                icon: "⌂", visual: .houseRadar(houseScores),
                facts: houseFacts,
                language: language
            ),
            card( id: "action-guidance",
                title: localized("Action guidance", "行动建议", language: language),
                icon: "→", visual: .actionGuidance,
                facts: actionFacts(balance, top: top, language: language),
                language: language
            ),
            card( id: "transit-timeline",
                title: localized("How changes develop", "变化如何发展", language: language),
                icon: "⇢", visual: .arcTimeline,
                facts: timelineFacts(top, language: language),
                language: language
            ),
            card( id: "planet-overview",
                title: localized("What is moving now", "当前正在变化的主题", language: language),
                icon: "⊛", visual: .doubleRing,
                facts: movingFacts,
                language: language
            ),
            card( id: "intensity-calendar",
                title: localized("This week's intensity", "本周变化强度", language: language),
                icon: "▦", visual: .calendar(fullCalendar),
                facts: calendarFacts(fullCalendar, language: language),
                language: language
            ),
        ]
    }

    private static func secondaryCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let moon = snapshot.point(.moon)
        let sun = snapshot.point(.sun)
        let top = Array(aspects.prefix(4))
        let balance = counts(aspects)
        return [
            card( id: "current-stage",
                title: localized("Current life stage", "当前人生阶段", language: language),
                icon: "◐", visual: .progressedStage(
                    phase: phaseAngle(snapshot),
                    moonProgress: normalized(moon?.degreeInSign),
                    sunProgress: normalized(sun?.degreeInSign)
                ),
                facts: [
                    fact(
                        localized("Emotional development", "情绪与安全感的发展", language: language),
                        moon.map {
                            ConsumerCopy.style(signIndex: $0.signIndex, language: language)
                        } ?? "—",
                        .transition,
                        symbol: "☽"
                    ),
                    fact(
                        localized("Long-term direction", "长期方向的发展", language: language),
                        sun.map {
                            ConsumerCopy.style(signIndex: $0.signIndex, language: language)
                        } ?? "—",
                        .supportive,
                        symbol: "☉"
                    ),
                    fact(localized("Stage", "阶段", language: language), progressedPhaseName(phaseAngle(snapshot), language: language)),
                ],
                language: language
            ),
            card( id: "change-themes",
                title: localized("Long-term change themes", "长期变化主题", language: language),
                icon: "◈", visual: .progressedThemes(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: top.prefix(3).map {
                    fact(
                        aspectTitle($0, prefix: localized("Progressed ", "次限", language: language), language: language),
                        activityLabel(Int($0.strength * 100), language: language),
                        tone($0.kind),
                        note: "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "turning-points",
                title: localized("Core turning points", "核心转折点", language: language),
                icon: "⟐", visual: .turningTimeline,
                facts: turningFacts(snapshot, aspects: top, language: language),
                language: language
            ),
            card( id: "stage-advice",
                title: localized("Stage guidance", "当前阶段建议", language: language),
                icon: "→", visual: .actionGuidance,
                facts: actionFacts(balance, top: top, language: language),
                language: language
            ),
            card( id: "natal-link",
                title: localized("Relationship to natal", "与本命盘的关系", language: language),
                icon: "∞", visual: .comparison,
                facts: natalLinkFacts(top, language: language),
                language: language
            ),
        ]
    }

    private static func card(
        id: String,
        title: String,
        icon: String,
        visual: InsightVisual,
        facts: [InsightFact],
        language: AppLanguage
    ) -> InsightCardModel {
        let completedFacts = paddedFacts(
            facts,
            to: minimumFactCount(for: id),
            language: language
        )
        return InsightCardModel(
            id: id,
            title: title,
            icon: icon,
            visual: visual,
            facts: completedFacts,
            summary: "",
            detail: ""
        )
    }

    private static func paddedFacts(
        _ facts: [InsightFact],
        to minimum: Int,
        language: AppLanguage
    ) -> [InsightFact] {
        guard facts.count < minimum else { return facts }
        let placeholders = (facts.count ..< minimum).map { _ in
            fact(
                localized("No close signal", "暂无紧密信号", language: language),
                localized("Nothing close enough to display", "当前没有达到显示范围的紧密联系", language: language),
                .neutral
            )
        }
        return facts + placeholders
    }

    private static func minimumFactCount(for id: String) -> Int {
        [
            "core-structure": 3, "strongest-themes": 3, "core-strengths": 3, "blind-spot": 2, "growth-direction": 3,
            "sky-overview": 7, "core-themes": 3, "key-events": 3, "structure-tension": 4,
            "collective-domains": 8, "observation-focus": 3, "sky-evolution": 3,
            "daily-activity": 2, "transit-overview": 3, "trigger-themes": 3, "support-pressure": 3,
            "life-domains": 4, "action-guidance": 4, "transit-timeline": 3, "intensity-calendar": 2,
            "current-stage": 3, "change-themes": 3, "turning-points": 3, "stage-advice": 4, "natal-link": 3,
        ][id, default: 1]
    }

    private static func fact(
        _ label: String,
        _ value: String,
        _ emphasis: InsightTone = .neutral,
        note: String? = nil,
        progress: Double? = nil,
        symbol: String? = nil
    ) -> InsightFact {
        InsightFact(
            label: label,
            value: value,
            emphasis: emphasis,
            note: note,
            progress: progress,
            symbol: symbol
        )
    }

    private static func normalized(_ degree: Double?) -> Double {
        (degree ?? 0) / 30
    }

    private static func counts(_ aspects: [ChartAspect]) -> (supportive: Int, challenging: Int, neutral: Int) {
        let supportive = aspects.filter { $0.kind.supportive }.count
        let challenging = aspects.filter { $0.kind.challenging }.count
        return (supportive, challenging, max(0, aspects.count - supportive - challenging))
    }

    private static func phaseAngle(_ snapshot: ChartSnapshot) -> Double {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return 0 }
        let raw = (moon.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    private static func activityLabel(_ value: Int, language: AppLanguage) -> String {
        switch value {
        case 0 ... 20: localized("Low", "低", language: language)
        case 21 ... 45: localized("Moderate", "中等", language: language)
        case 46 ... 70: localized("High", "高", language: language)
        default: localized("Very high", "极高", language: language)
        }
    }

    private static func signalDensity(_ aspects: [ChartAspect], limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        let total = aspects.prefix(limit).reduce(0) { $0 + $1.strength }
        return Int(min(1, total / Double(limit)) * 100)
    }

    private static func domainValues(_ snapshot: ChartSnapshot) -> [Double] {
        let domains: [[CelestialBody]] = [
            [.mercury, .uranus],
            [.venus, .moon],
            [.sun, .mars],
            [.jupiter, .saturn, .pluto],
            [.jupiter, .uranus],
            [.saturn, .pluto],
            [.moon, .neptune],
            [.venus, .jupiter],
        ]
        var participation: [CelestialBody: Double] = [:]
        for aspect in snapshot.aspects {
            if let first = CelestialBody(rawValue: aspect.firstID) {
                participation[first, default: 0] += aspect.strength
            }
            if let second = CelestialBody(rawValue: aspect.secondID) {
                participation[second, default: 0] += aspect.strength
            }
        }
        let totals = domains.map { bodies in
            bodies.reduce(0) { $0 + participation[$1, default: 0] } / Double(bodies.count)
        }
        guard let maximum = totals.max(), maximum > 0 else {
            return [Double](repeating: 0, count: domains.count)
        }
        return totals.map { $0 / maximum }
    }

    private static func domainFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
        let labels = language == .english
            ? ["Information", "Relationships", "Action", "Institutions", "Technology", "Resources", "Public mood", "Culture"]
            : ["信息传播", "关系合作", "行动竞争", "制度结构", "技术创新", "资源经济", "公共情绪", "文化价值"]
        return zip(labels, domainValues(snapshot)).map {
            let score = Int($0.1 * 100)
            return fact(
                $0.0,
                activityLabel(score, language: language),
                score > 66 ? .challenging : score > 35 ? .transition : .neutral,
                progress: $0.1
            )
        }
    }

    private static func houseValues(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> [Double] {
        var values = [Double](repeating: 0, count: 12)
        for point in snapshot.points {
            let index = max(0, min(11, (natal?.house(containing: point.longitudeDegrees) ?? 1) - 1))
            values[index] += point.retrograde ? 0.75 : 0.5
        }
        for aspect in aspects {
            let index = max(0, min(11, (natal?.house(containing: aspect.firstLongitude) ?? 1) - 1))
            values[index] += max(0.1, aspect.strength)
        }
        guard let maximum = values.max(), maximum > 0 else { return values }
        return values.map { $0 / maximum }
    }

    private static func timelineFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let separating = aspects.first { $0.phase == .separating }
        let current = aspects.first { $0.phase == .exact } ?? aspects.first
        let applying = aspects.first { $0.phase == .applying }
        return [
            fact(
                localized("Just finished", "刚刚经过", language: language),
                separating.map { aspectTitle($0, language: language) } ?? "—",
                separating.map { tone($0.kind) } ?? .neutral,
                note: separating.map {
                    ConsumerCopy.intensity($0.strength, language: language)
                },
                progress: separating?.strength ?? 0,
                symbol: "✓"
            ),
            fact(
                localized("Current", "当前", language: language),
                current.map { aspectTitle($0, language: language) } ?? "—",
                .transition,
                note: current.map {
                    ConsumerCopy.intensity($0.strength, language: language)
                },
                progress: current?.strength ?? 0,
                symbol: "●"
            ),
            fact(
                localized("Next", "接下来", language: language),
                applying.map { aspectTitle($0, language: language) } ?? "—",
                applying.map { tone($0.kind) } ?? .neutral,
                note: applying.map {
                    ConsumerCopy.intensity($0.strength, language: language)
                },
                progress: applying?.strength ?? 0,
                symbol: "→"
            ),
        ]
    }

    private static func cycleLeaders(_ aspects: [ChartAspect]) -> [ChartAspect?] {
        let slow: Set<CelestialBody> = [.jupiter, .saturn, .uranus, .neptune, .pluto]
        let middle: Set<CelestialBody> = [.sun, .mercury, .venus, .mars]
        func bodies(_ aspect: ChartAspect) -> [CelestialBody] {
            [CelestialBody(rawValue: aspect.firstID), CelestialBody(rawValue: aspect.secondID)].compactMap { $0 }
        }
        let long = aspects.first { aspect in
            let pair = bodies(aspect)
            return !pair.isEmpty && pair.allSatisfy { slow.contains($0) }
        }
        let mid = aspects.first { aspect in
            let pair = bodies(aspect)
            return pair.contains(where: { middle.contains($0) }) && !pair.contains(.moon)
        }
        let short = aspects.first { bodies($0).contains(.moon) }
        return [
            long ?? aspects.first,
            mid ?? aspects.dropFirst().first ?? aspects.first,
            short ?? aspects.dropFirst(2).first ?? aspects.first,
        ]
    }

    private static func dominantBodies(_ aspects: [ChartAspect], language: AppLanguage) -> String {
        var scores: [CelestialBody: Double] = [:]
        for aspect in aspects {
            if let body = CelestialBody(rawValue: aspect.firstID) {
                scores[body, default: 0] += aspect.strength
            }
            if let body = CelestialBody(rawValue: aspect.secondID) {
                scores[body, default: 0] += aspect.strength
            }
        }
        let names = scores.sorted { $0.value > $1.value }.prefix(3).map {
            "\($0.key.symbol) \(bodyName($0.key, language: language))"
        }
        return names.isEmpty ? "—" : names.joined(separator: " · ")
    }

    private static func motionLabel(_ point: ChartPoint, language: AppLanguage) -> String {
        ConsumerCopy.motion(isRetrograde: point.retrograde, language: language)
    }

    private static func timeLayer(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let slow: Set<String> = [
            CelestialBody.jupiter.rawValue,
            CelestialBody.saturn.rawValue,
            CelestialBody.uranus.rawValue,
            CelestialBody.neptune.rawValue,
            CelestialBody.pluto.rawValue,
        ]
        if slow.contains(aspect.firstID) {
            return localized("Long-term layer", "长期层", language: language)
        }
        if aspect.firstID == CelestialBody.moon.rawValue {
            return localized("Daily layer", "短期层", language: language)
        }
        return localized("Current layer", "当前层", language: language)
    }

    private static func bodyPair(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let first = CelestialBody(rawValue: aspect.firstID)
        let second = CelestialBody(rawValue: aspect.secondID)
        let firstTheme = ConsumerCopy.bodyTheme(first, language: language)
        let secondTheme = ConsumerCopy.bodyTheme(second, language: language)
        return localized(
            "\(firstTheme) and \(secondTheme)",
            "\(firstTheme)与\(secondTheme)",
            language: language
        )
    }

    private static func houseSymbol(_ house: Int) -> String {
        house > 0 ? "\(house)" : "•"
    }

    private static func activeHouseFacts(_ values: [Double], language: AppLanguage) -> [InsightFact] {
        values.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(4)
            .map { index, value in
                fact(
                    ConsumerCopy.lifeArea(index + 1, language: language),
                    activityLabel(Int(value * 100), language: language),
                    value > 0.66 ? .challenging : value > 0.35 ? .transition : .neutral,
                    progress: value,
                    symbol: "\(index + 1)"
                )
            }
    }

    private static func actionFacts(
        _ balance: (supportive: Int, challenging: Int, neutral: Int),
        top: [ChartAspect],
        language: AppLanguage
    ) -> [InsightFact] {
        let direction = balance.challenging > balance.supportive
            ? localized("Simplify before accelerating", "先简化，再加速", language: language)
            : localized("Use the available momentum", "顺势推进重点事项", language: language)
        let main = top.first.map { bodyPair($0, language: language) } ?? "—"
        return [
            fact(
                localized("Direction", "行动方向", language: language),
                direction,
                .transition
            ),
            fact(
                localized("Advance", "适合推进", language: language),
                localized("One clear priority", "一个明确的重点", language: language),
                .supportive,
                note: localized("Move when the next step is concrete.", "下一步足够具体时就行动。", language: language)
            ),
            fact(
                localized("Adjust", "需要调整", language: language),
                main,
                .challenging,
                note: localized("Reduce avoidable friction first.", "先减少可以避免的消耗。", language: language)
            ),
            fact(
                localized("Pause", "暂缓决定", language: language),
                localized("Irreversible choices", "难以撤回的决定", language: language),
                .neutral,
                note: localized("Wait when the facts are still changing.", "信息仍在变化时先等待。", language: language)
            ),
        ]
    }

    private static func calendarFacts(_ values: [Int], language: AppLanguage) -> [InsightFact] {
        guard !values.isEmpty else {
            return [fact(localized("This week", "本周", language: language), localized("No notable changes", "暂无明显变化", language: language))]
        }
        let peak = values.enumerated().max { $0.element < $1.element }
        let quiet = values.enumerated().min { $0.element < $1.element }
        return [
            fact(
                localized("Highest day", "最高日", language: language),
                peak.map { localized("Day \($0.offset + 1) · \($0.element)", "第 \($0.offset + 1) 天 · \($0.element)", language: language) } ?? "—",
                .challenging
            ),
            fact(
                localized("Quietest day", "平缓日", language: language),
                quiet.map { localized("Day \($0.offset + 1) · \($0.element)", "第 \($0.offset + 1) 天 · \($0.element)", language: language) } ?? "—",
                .supportive
            ),
        ]
    }

    private static func progressedPhaseName(_ angle: Double, language: AppLanguage) -> String {
        switch angle {
        case 0 ..< 45: localized("New beginning", "新阶段开启", language: language)
        case 45 ..< 90: localized("Building momentum", "逐渐积累", language: language)
        case 90 ..< 135: localized("Active development", "主动发展", language: language)
        case 135 ..< 180: localized("Refining direction", "调整方向", language: language)
        case 180 ..< 225: localized("Full visibility", "成果显现", language: language)
        case 225 ..< 270: localized("Reassessment", "重新评估", language: language)
        case 270 ..< 315: localized("Integration", "整合经验", language: language)
        default: localized("Release and reset", "收尾与更新", language: language)
        }
    }

    private static func natalLinkFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let support = aspects.first { $0.kind.supportive }
        let challenge = aspects.first { $0.kind.challenging }
        let newPattern = aspects.first { !$0.kind.supportive && !$0.kind.challenging } ?? aspects.first
        return [
            fact(
                localized("Strengthened", "正在强化", language: language),
                support.map { aspectTitle($0, prefix: localized("Progressed ", "次限", language: language), language: language) } ?? "—",
                .supportive
            ),
            fact(
                localized("Challenged", "正在挑战", language: language),
                challenge.map { aspectTitle($0, prefix: localized("Progressed ", "次限", language: language), language: language) } ?? "—",
                .challenging
            ),
            fact(
                localized("New possibility", "新的可能", language: language),
                newPattern.map { bodyPair($0, language: language) } ?? "—",
                .transition
            ),
        ]
    }

    private static func ruler(ofSign sign: Int) -> CelestialBody {
        switch sign {
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

    private static func turningFacts(
        _ snapshot: ChartSnapshot,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InsightFact] {
        let moon = snapshot.point(.moon)
        let nearBoundary = (moon?.degreeInSign ?? 15) < 3 || (moon?.degreeInSign ?? 15) > 27
        return [
            fact(
                localized("Most concentrated change", "当前最集中的变化", language: language),
                aspects.first.map { aspectTitle($0, language: language) } ?? "—",
                aspects.first.map { tone($0.kind) } ?? .neutral,
                note: aspects.first.map {
                    "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))"
                },
                progress: aspects.first?.strength ?? 0
            ),
            fact(
                localized("Changing approach", "方式正在变化", language: language),
                nearBoundary
                    ? localized("A new approach is close", "新的处理方式即将开始", language: language)
                    : localized("The current approach is still developing", "当前处理方式仍在发展", language: language),
                .transition,
                note: moon.map {
                    ConsumerCopy.style(signIndex: $0.signIndex, language: language)
                },
                progress: nearBoundary ? 0.9 : normalized(moon?.degreeInSign)
            ),
            fact(
                localized("Long-term stage", "长期发展阶段", language: language),
                progressedPhaseName(phaseAngle(snapshot), language: language),
                .supportive,
                note: ConsumerCopy.cycleStage(
                    angle: phaseAngle(snapshot),
                    language: language
                ),
                progress: phaseAngle(snapshot) / 360
            ),
        ]
    }

    private static func validate(_ cards: [InsightCardModel], for chart: ChartKind) throws {
        #if DEBUG
        let expected: [ChartKind: [String]] = [
            .natal: ["core-structure", "strongest-themes", "core-strengths", "blind-spot", "growth-direction"],
            .currentSky: ["sky-overview", "core-themes", "key-events", "structure-tension", "collective-domains", "observation-focus", "sky-evolution", "planet-overview"],
            .transit: ["daily-activity", "transit-overview", "trigger-themes", "key-events", "support-pressure", "life-domains", "action-guidance", "transit-timeline", "planet-overview", "intensity-calendar"],
            .secondary: ["current-stage", "change-themes", "turning-points", "stage-advice", "natal-link"],
        ]
        let expectedIDs = expected[chart] ?? []
        guard cards.map(\.id) == expectedIDs else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) card set is incomplete")
        }
        guard cards.allSatisfy({ !$0.title.isEmpty && !$0.summary.isEmpty && !$0.detail.isEmpty }) else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) contains empty card copy")
        }
        guard cards.allSatisfy({ !$0.facts.isEmpty }) else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) contains an empty card visual")
        }
        for card in cards {
            guard card.facts.count >= minimumFactCount(for: card.id) else {
                throw InsightFactoryError.invalidCardContract("\(chart.rawValue).\(card.id) is missing visual content")
            }
            switch card.visual {
            case let .skyOverview(_, _, cycles):
                guard cycles.count == 3 else {
                    throw InsightFactoryError.invalidCardContract("sky overview must contain three cycles")
                }
            case let .domainBars(values):
                guard values.count == 8 else {
                    throw InsightFactoryError.invalidCardContract("sky domain chart must contain eight domains")
                }
            case .planetTable, .doubleRing:
                guard card.facts.count >= 10 else {
                    throw InsightFactoryError.invalidCardContract("\(card.id) must contain the complete planet table")
                }
            case let .houseRadar(values):
                guard values.count == 12 else {
                    throw InsightFactoryError.invalidCardContract("transit house radar must contain all twelve houses")
                }
            case let .calendar(values):
                guard values.count == 7 else {
                    throw InsightFactoryError.invalidCardContract("transit intensity calendar must contain seven days")
                }
            default:
                break
            }
        }
        #endif
    }
}
