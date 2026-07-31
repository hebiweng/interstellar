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
        transitCalendar: [Int],
        preset: String? = nil
    ) throws -> [InsightCardModel] {
        guard let snapshot else { return [] }
        let cards = switch chart {
        case .natal:
            natalCards(snapshot, language: language)
        case .currentSky:
            skyCards(snapshot, language: language)
        case .transit:
            transitCards(snapshot, natal: natal, aspects: aspects, calendar: transitCalendar, language: language)
        case .secondary:
            secondaryCards(snapshot, natal: natal, aspects: aspects, language: language)
        case .solarReturn:
            solarCards(snapshot, natal: natal, aspects: aspects, language: language)
        case .synastry:
            synastryCards(snapshot, second: natal, aspects: aspects, language: language)
        }
        let renderedCards = try cards.map { draft in
            let cardAspects: [ChartAspect]
            let aspectsAreCross: Bool
            switch chart {
            case .solarReturn:
                aspectsAreCross = draft.id == "natal-overlay"
                cardAspects = aspectsAreCross ? aspects : snapshot.aspects
            case .transit, .secondary, .synastry:
                aspectsAreCross = true
                cardAspects = aspects
            case .natal, .currentSky:
                aspectsAreCross = false
                cardAspects = snapshot.aspects
            }
            let context = InterpretationContextFactory.make(
                chart: chart,
                cardID: draft.id,
                snapshot: snapshot,
                natal: natal,
                aspects: cardAspects,
                language: language,
                transitCalendar: transitCalendar,
                preset: preset,
                aspectsAreCross: aspectsAreCross
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

    // MARK: - Natal (8)

    private static func natalCards(
        _ snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let moon = snapshot.point(.moon)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let mcSignIndex = Int(snapshot.angles.midheavenDegrees / 30) % 12
        let mcSign = Zodiac.name(index: mcSignIndex, language: language)
        let mcRuler = ruler(ofSign: mcSignIndex)
        let top = Array(snapshot.aspects.prefix(4))
        let balance = counts(snapshot.aspects)
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let elementScores = elementBalance(snapshot)
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let dominant = dominantBodies(snapshot.aspects, language: language)
        let orientation = elementOrientation(elementScores, language: language)

        return [
            card( id: "natal-interpretation",
                title: localized("Natal interpretation", "本命解读", language: language),
                icon: "✦", visual: .natalCore,
                facts: [
                    fact(localized("Sun", "太阳", language: language), sun.map { Zodiac.position($0, language: language) } ?? "—", .supportive, symbol: "☉"),
                    fact(localized("Moon", "月亮", language: language), moon.map { Zodiac.position($0, language: language) } ?? "—", .neutral, symbol: "☽"),
                    fact(localized("Rising", "上升", language: language), ascSign, .transition, symbol: "ASC"),
                ],
                language: language
            ),
            card( id: "career-direction",
                title: localized("Career & direction", "事业与方向", language: language),
                icon: "↗", visual: .growthPath,
                facts: [
                    fact(localized("Public direction", "公共方向", language: language), mcSign, .transition, symbol: "MC"),
                    fact(localized("Career anchor", "事业锚点", language: language), snapshot.point(mcRuler).map { Zodiac.position($0, language: language) } ?? "—", .supportive, symbol: mcRuler.symbol),
                    fact(localized("House focus", "重点领域", language: language), sun.map { ConsumerCopy.lifeArea(snapshot.house(containing: $0.longitudeDegrees), language: language) } ?? "—", .neutral),
                ],
                language: language
            ),
            card( id: "strengths-growth",
                title: localized("Strengths & growth edges", "优势与成长面", language: language),
                icon: "✚", visual: .strengthOrbit(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: [
                    fact(localized("Core strength", "核心优势", language: language), strongestSupport.map { aspectTitle($0, language: language) } ?? "—", .supportive),
                    fact(localized("Growth edge", "成长面", language: language), strongestChallenge.map { aspectTitle($0, language: language) } ?? "—", .challenging),
                ],
                language: language
            ),
            card( id: "element-balance",
                title: localized("Element & mode balance", "元素与模式", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, language: language),
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
                    dominant: dominant,
                    orientation: orientation
                ),
                facts: [
                    fact(localized("Chart ruler", "命主星", language: language), mcRuler.symbol, .supportive),
                    fact(localized("Dominant", "主导星体", language: language), dominant, .transition),
                    fact(localized("Orientation", "总体取向", language: language), orientation, .neutral),
                ],
                language: language
            ),
            card( id: "planet-placements",
                title: localized("Planet placements", "行星落座", language: language),
                icon: "⊛", visual: .placementList,
                facts: snapshot.points.map {
                    fact(
                        bodyName($0.body, language: language),
                        Zodiac.position($0, language: language),
                        $0.retrograde ? .challenging : .neutral,
                        note: ConsumerCopy.lifeArea(snapshot.house(containing: $0.longitudeDegrees), language: language),
                        symbol: $0.body.symbol
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
        let elementScores = elementBalance(snapshot)
        let fullCalendar = Array(([Int](repeating: 0, count: 7)).prefix(7))
        let moon = snapshot.point(.moon)
        let moonHouse = snapshot.house(containing: moon?.longitudeDegrees ?? 0)

        return [
            card( id: "sky-overview",
                title: localized("Sky at a glance", "当前天空总览", language: language),
                icon: "◉", visual: .skyOverview(
                    phase: phase,
                    activity: activity,
                    cycles: cycleAspects.map { $0?.strength ?? 0 }
                ),
                facts: [
                    fact(localized("Dominant pattern", "主导结构", language: language), top.first.map { aspectTitle($0, language: language) } ?? "—", top.first.map { tone($0.kind) } ?? .neutral),
                    fact(localized("Review cycles", "回顾调整中的主题", language: language), "\(retrogrades.count)", .transition),
                    fact(localized("Atmosphere", "整体氛围", language: language), activityLabel(activity, language: language)),
                ],
                language: language
            ),
            card( id: "moon-now",
                title: localized("Moon now", "此刻的月亮", language: language),
                icon: "☽", visual: .phaseDial(phase: phase, illumination: moonIllumination(snapshot)),
                facts: [
                    fact(localized("Moon sign", "月亮落座", language: language), moon.map { Zodiac.position($0, language: language) } ?? "—", .neutral, symbol: "☽"),
                    fact(localized("Moon area", "月亮领域", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition),
                    fact(localized("Lunar phase", "月相", language: language), progressedPhaseName(phase, language: language)),
                ],
                language: language
            ),
            card( id: "aspect-pattern",
                title: localized("Major aspect pattern", "主要连接结构", language: language),
                icon: "◇", visual: .structureMap(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: [
                    fact(localized("Support", "支持", language: language), "\(balance.supportive)", .supportive),
                    fact(localized("Pressure", "压力", language: language), "\(balance.challenging)", .challenging),
                    fact(localized("Focus", "焦点", language: language), dominantBodies(snapshot.aspects, language: language), .transition),
                ],
                language: language
            ),
            card( id: "planetary-motion",
                title: localized("Planetary motion", "行星运动", language: language),
                icon: "↺", visual: .motionList,
                facts: motionFacts(snapshot, language: language),
                language: language
            ),
            card( id: "sign-changes",
                title: localized("Sign changes", "换座信号", language: language),
                icon: "⇢", visual: .eventTimeline,
                facts: timelineFacts(top, language: language),
                language: language
            ),
            card( id: "element-climate",
                title: localized("Element & mode climate", "元素与模式气质", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, language: language),
                language: language
            ),
            card( id: "upcoming-7-days",
                title: localized("Upcoming 7 days", "未来七天", language: language),
                icon: "▦", visual: .calendar(fullCalendar),
                facts: calendarFacts(fullCalendar, language: language),
                language: language
            ),
        ]
    }

    // MARK: - Transits (6)

    private static func transitCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        calendar: [Int],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let top = Array(aspects.prefix(6))
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let movingFacts = snapshot.points.map { point in
            let house = natal?.house(containing: point.longitudeDegrees) ?? 0
            return fact(
                bodyName(point.body, language: language),
                "\(Zodiac.name(index: point.signIndex, language: language)) · \(ConsumerCopy.lifeArea(house, language: language))",
                point.retrograde ? .challenging : .neutral,
                note: motionLabel(point, language: language),
                symbol: point.body.symbol
            )
        }
        let expanding: String
        if let support = aspects.first(where: { $0.kind.supportive }) {
            expanding = aspectTitle(support, language: language)
        } else {
            expanding = "—"
        }
        let structuring: String
        if let structure = aspects.first(where: { $0.kind.challenging }) {
            structuring = aspectTitle(structure, language: language)
        } else {
            structuring = "—"
        }

        return [
            card( id: "current-story",
                title: localized("Current story", "当前主线", language: language),
                icon: "◎", visual: .storyWeave(expanding: expanding, structuring: structuring),
                facts: top.prefix(3).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(natal?.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "current-cycles",
                title: localized("Current cycles", "当前周期", language: language),
                icon: "◔", visual: .cycleTabs(long: expanding, current: top.first.map { aspectTitle($0, language: language) } ?? "—", daily: structuring),
                facts: top.prefix(3).map {
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
            card( id: "transit-timeline",
                title: localized("Transit timeline", "变化时间线", language: language),
                icon: "⇢", visual: .gantt,
                facts: top.prefix(4).map {
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
            card( id: "planet-paths",
                title: localized("Planet paths", "行星路径", language: language),
                icon: "⊛", visual: .positionRows,
                facts: Array(movingFacts.prefix(8)),
                language: language
            ),
            card( id: "life-areas",
                title: localized("Life areas", "生活领域", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(6)),
                language: language
            ),
            card( id: "active-transits",
                title: localized("Active transits", "进行中的变化", language: language),
                icon: "⌗", visual: .aspectList,
                facts: top.prefix(6).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(natal?.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
        ]
    }

    // MARK: - Secondary (6)

    private static func secondaryCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let moon = snapshot.point(.moon)
        let sun = snapshot.point(.sun)
        let natalSun = natal?.point(.sun)
        let top = Array(aspects.prefix(6))
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let phase = phaseAngle(snapshot)
        let moonHouse = natal?.house(containing: moon?.longitudeDegrees ?? 0) ?? 0

        return [
            card( id: "developmental-chapter",
                title: localized("Developmental chapter", "发展阶段", language: language),
                icon: "◐", visual: .stageFlow(
                    old: "Observe quietly",
                    transition: "Claim direction",
                    emerging: "Act visibly"
                ),
                facts: [
                    fact(localized("Stage", "阶段", language: language), progressedPhaseName(phase, language: language), .transition),
                    fact(localized("Emotional thread", "情绪线索", language: language), moon.map { ConsumerCopy.style(signIndex: $0.signIndex, language: language) } ?? "—", .neutral, symbol: "☽"),
                    fact(localized("Identity thread", "身份线索", language: language), sun.map { ConsumerCopy.style(signIndex: $0.signIndex, language: language) } ?? "—", .supportive, symbol: "☉"),
                ],
                language: language
            ),
            card( id: "progressed-moon",
                title: localized("Progressed moon", "长期月亮", language: language),
                icon: "☽", visual: .moonProgress,
                facts: [
                    fact(localized("Moon sign", "月亮落座", language: language), moon.map { Zodiac.position($0, language: language) } ?? "—", .neutral, symbol: "☽"),
                    fact(localized("Moon area", "月亮领域", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition),
                    fact(localized("Phase", "月相", language: language), progressedPhaseName(phase, language: language)),
                ],
                language: language
            ),
            card( id: "identity-development",
                title: localized("Identity development", "身份发展", language: language),
                icon: "☉", visual: .identityCompare(
                    natal: natalSun.map { Zodiac.position($0, language: language) } ?? "—",
                    progressed: sun.map { Zodiac.position($0, language: language) } ?? "—"
                ),
                facts: [
                    fact(localized("Natal sun", "本命太阳", language: language), natalSun.map { Zodiac.position($0, language: language) } ?? "—", .neutral, symbol: "☉"),
                    fact(localized("Progressed sun", "长期太阳", language: language), sun.map { Zodiac.position($0, language: language) } ?? "—", .supportive, symbol: "☉"),
                ],
                language: language
            ),
            card( id: "turning-points",
                title: localized("Turning points", "转折点", language: language),
                icon: "⟐", visual: .turningRows,
                facts: top.prefix(3).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(natal?.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "areas-maturing",
                title: localized("Areas maturing", "成熟领域", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "timeline",
                title: localized("24-month timeline", "长期时间线", language: language),
                icon: "⇢", visual: .gantt,
                facts: top.prefix(4).map {
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
        ]
    }

    // MARK: - Solar return (7)

    private static func solarCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let ruler = ruler(ofSign: Int(snapshot.angles.ascendantDegrees / 30) % 12)
        let top = Array(snapshot.aspects.prefix(4))
        let crossTop = Array(aspects.prefix(4))
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first

        return [
            card( id: "year-theme",
                title: localized("Your birthday year", "你的生日年", language: language),
                icon: "☉", visual: .yearOrbit,
                facts: [
                    fact(localized("Return ascendant", "返照上升", language: language), ascSign, .transition, symbol: "ASC"),
                    fact(localized("Chart ruler", "命主星", language: language), ruler.symbol, .supportive, symbol: ruler.symbol),
                    fact(localized("Sun house", "太阳落宫", language: language), ConsumerCopy.lifeArea(snapshot.house(containing: sun?.longitudeDegrees ?? 0), language: language), .neutral, symbol: "☉"),
                ],
                language: language
            ),
            card( id: "year-anchors",
                title: localized("Year anchors", "年度锚点", language: language),
                icon: "⚓", visual: .anchorGrid,
                facts: top.prefix(4).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(snapshot.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "priority-areas",
                title: localized("Priority areas", "优先领域", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "year-dynamics",
                title: localized("Year dynamics", "年度动态", language: language),
                icon: "◈", visual: .dualInsight(
                    opening: strongestSupport.map { aspectTitle($0, language: language) } ?? "—",
                    demand: strongestChallenge.map { aspectTitle($0, language: language) } ?? "—"
                ),
                facts: [
                    fact(localized("Opening", "展开", language: language), strongestSupport.map { aspectTitle($0, language: language) } ?? "—", .supportive),
                    fact(localized("Demand", "要求", language: language), strongestChallenge.map { aspectTitle($0, language: language) } ?? "—", .challenging),
                ],
                language: language
            ),
            card( id: "year-timeline",
                title: localized("Year timeline", "年度时间线", language: language),
                icon: "⇢", visual: .quarterTabs,
                facts: top.prefix(4).map {
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
            card( id: "natal-overlay",
                title: localized("Natal overlay", "与本命叠加", language: language),
                icon: "∞", visual: .overlayCompare,
                facts: crossTop.prefix(4).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(natal?.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength
                    )
                },
                language: language
            ),
            card( id: "year-aspects",
                title: localized("Year aspects", "年度连接", language: language),
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

    // MARK: - Synastry (8)

    private static func synastryCards(
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
                    opening: venusMarsAspects.first(where: { $0.kind.supportive }).map { aspectTitle($0, language: language) } ?? "—",
                    demand: venusMarsAspects.first(where: { $0.kind.challenging }).map { aspectTitle($0, language: language) } ?? "—"
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
            "natal-interpretation": 3, "career-direction": 3, "strengths-growth": 2, "element-balance": 4,
            "house-emphasis": 3, "chart-signature": 3, "planet-placements": 10, "key-aspects": 3,
            "sky-overview": 3, "moon-now": 3, "aspect-pattern": 3, "planetary-motion": 3,
            "sign-changes": 3, "element-climate": 4, "upcoming-7-days": 2,
            "current-story": 3, "current-cycles": 3, "transit-timeline": 3, "planet-paths": 3,
            "life-areas": 3, "active-transits": 3,
            "developmental-chapter": 3, "progressed-moon": 3, "identity-development": 2, "turning-points": 3,
            "areas-maturing": 3, "timeline": 3,
            "year-theme": 3, "year-anchors": 3, "priority-areas": 3, "year-dynamics": 2,
            "year-timeline": 3, "natal-overlay": 3, "year-aspects": 3,
            "relationship-overview": 3, "perspectives": 3, "emotional-connection": 3, "communication": 3,
            "chemistry": 3, "commitment": 3, "house-overlays": 3, "key-inter-aspects": 3,
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

    private static func dominantBodies(_ aspects: [ChartAspect], language: AppLanguage) -> String {
        var scores: [String: Double] = [:]
        for aspect in aspects {
            scores[aspect.firstID, default: 0] += aspect.strength
            scores[aspect.secondID, default: 0] += aspect.strength * 0.6
        }
        let names = scores
            .sorted { $0.value > $1.value }
            .prefix(2)
            .compactMap { CelestialBody(rawValue: $0.key).map { bodyName($0, language: language) } }
        return names.isEmpty ? "—" : names.joined(separator: " · ")
    }

    private static func motionLabel(_ point: ChartPoint, language: AppLanguage) -> String {
        point.retrograde
            ? localized("Reviewing", "回顾调整中", language: language)
            : localized("Moving forward", "稳定向前", language: language)
    }

    private static func motionFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
        snapshot.points.map { point in
            fact(
                bodyName(point.body, language: language),
                Zodiac.position(point, language: language),
                point.retrograde ? .challenging : .neutral,
                note: motionLabel(point, language: language),
                symbol: point.body.symbol
            )
        }
    }

    private static func bodyPair(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let first = CelestialBody(rawValue: aspect.firstID).map { bodyName($0, language: language) } ?? aspect.firstID
        let second = CelestialBody(rawValue: aspect.secondID).map { bodyName($0, language: language) } ?? aspect.secondID
        return "\(first) → \(second)"
    }

    private static func elementBalance(_ snapshot: ChartSnapshot) -> [Double] {
        let elementBySign: [String: Int] = [
            "aries": 0, "leo": 0, "sagittarius": 0,
            "taurus": 1, "virgo": 1, "capricorn": 1,
            "gemini": 2, "libra": 2, "aquarius": 2,
            "cancer": 3, "scorpio": 3, "pisces": 3,
        ]
        var counts = [Double](repeating: 0, count: 4)
        for point in snapshot.points {
            let sign = Zodiac.englishNames[point.signIndex].lowercased()
            counts[elementBySign[sign] ?? 0] += 1
        }
        guard let maximum = counts.max(), maximum > 0 else {
            return [Double](repeating: 0, count: 4)
        }
        return counts.map { $0 / maximum }
    }

    private static func elementFacts(_ scores: [Double], language: AppLanguage) -> [InsightFact] {
        let labels = language == .english
            ? ["Fire", "Earth", "Air", "Water"]
            : ["火", "土", "风", "水"]
        return zip(labels, scores).map { label, score in
            let percent = Int(score * 100)
            return fact(
                label,
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: score
            )
        }
    }

    private static func elementOrientation(_ scores: [Double], language: AppLanguage) -> String {
        guard let maximum = scores.max(), maximum > 0 else {
            return localized("Balanced", "均衡", language: language)
        }
        let index = scores.firstIndex(of: maximum) ?? 0
        return [
            localized("Fire emphasis", "火象主导", language: language),
            localized("Earth emphasis", "土象主导", language: language),
            localized("Air emphasis", "风象主导", language: language),
            localized("Water emphasis", "水象主导", language: language),
        ][index]
    }

    private static func houseValues(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> [Double] {
        var values = [Double](repeating: 0, count: 12)
        for point in snapshot.points {
            let house = (natal?.house(containing: point.longitudeDegrees) ?? snapshot.house(containing: point.longitudeDegrees))
            let index = max(0, min(11, house - 1))
            values[index] += point.retrograde ? 0.75 : 0.5
        }
        for aspect in aspects {
            let house = natal?.house(containing: aspect.firstLongitude) ?? snapshot.house(containing: aspect.firstLongitude)
            let index = max(0, min(11, house - 1))
            values[index] += max(0.1, aspect.strength)
        }
        guard let maximum = values.max(), maximum > 0 else { return values }
        return values.map { $0 / maximum }
    }

    private static func activeHouseFacts(_ values: [Double], language: AppLanguage) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .sorted { $0.element > $1.element }
            .prefix(6)
        return ranked.map { index, value in
            let percent = Int(value * 100)
            return fact(
                ConsumerCopy.lifeArea(index + 1, language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: value,
                symbol: "\(index + 1)"
            )
        }
    }

    private static func emotionalFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let sample = Array(aspects.prefix(4))
        guard !sample.isEmpty else {
            return [
                fact(
                    localized("No close signal", "暂无紧密信号", language: language),
                    localized("Nothing close enough to display", "当前没有达到显示范围的紧密联系", language: language),
                    .neutral
                ),
            ]
        }
        return sample.map { aspect in
            fact(
                aspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                progress: aspect.strength
            )
        }
    }


    private static func houseOverlayFacts(
        _ first: ChartSnapshot,
        second: ChartSnapshot?,
        language: AppLanguage
    ) -> [InsightFact] {
        guard let second else {
            return [
                fact(
                    localized("No partner chart", "暂无对方星盘", language: language),
                    localized("Add a person to compare", "添加一位人物即可比较", language: language),
                    .neutral
                ),
            ]
        }
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

    private static func calendarFacts(_ values: [Int], language: AppLanguage) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .sorted { $0.element > $1.element }
            .prefix(3)
        return ranked.map { index, value in
            let percent = value
            return fact(
                localized("Day \(index + 1)", "第\(index + 1)天", language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: Double(percent) / 100
            )
        }
    }

    private static func timelineFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let separating = aspects.first { $0.phase == .separating }
        let current = aspects.first { $0.phase == .exact } ?? aspects.first
        let applying = aspects.first { $0.phase == .applying }
        return [
            fact(
                localized("Just passed", "刚刚经过", language: language),
                separating.map { aspectTitle($0, language: language) } ?? "—",
                separating.map { tone($0.kind) } ?? .neutral,
                progress: separating?.strength ?? 0,
                symbol: "✓"
            ),
            fact(
                localized("Current", "当前", language: language),
                current.map { aspectTitle($0, language: language) } ?? "—",
                .transition,
                progress: current?.strength ?? 0,
                symbol: "●"
            ),
            fact(
                localized("Next", "接下来", language: language),
                applying.map { aspectTitle($0, language: language) } ?? "—",
                applying.map { tone($0.kind) } ?? .neutral,
                progress: applying?.strength ?? 0,
                symbol: "→"
            ),
        ]
    }

    private static func cycleLeaders(_ aspects: [ChartAspect]) -> [ChartAspect?] {
        let long = aspects.first { $0.firstID == CelestialBody.saturn.rawValue || $0.firstID == CelestialBody.uranus.rawValue || $0.firstID == CelestialBody.neptune.rawValue || $0.firstID == CelestialBody.pluto.rawValue }
        let current = aspects.first { $0.firstID == CelestialBody.jupiter.rawValue }
        let daily = aspects.first { $0.firstID == CelestialBody.moon.rawValue || $0.firstID == CelestialBody.mercury.rawValue }
        return [long ?? aspects.first, current, daily ?? aspects.first]
    }

    private static func progressedPhaseName(_ angle: Double, language: AppLanguage) -> String {
        switch angle {
        case 0 ..< 90: localized("New phase", "新月阶段", language: language)
        case 90 ..< 180: localized("Building phase", "上弦阶段", language: language)
        case 180 ..< 270: localized("Review phase", "满月阶段", language: language)
        default: localized("Integration phase", "下弦阶段", language: language)
        }
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

    private static func moonIllumination(_ snapshot: ChartSnapshot) -> Double {
        let phase = phaseAngle(snapshot)
        return (1 - cos(phase * .pi / 180)) / 2
    }


    private static func validate(_ cards: [InsightCardModel], for chart: ChartKind) throws {
        #if DEBUG
        let expected: [ChartKind: [String]] = [
            .natal: ["natal-interpretation", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"],
            .currentSky: ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"],
            .transit: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"],
            .secondary: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"],
            .solarReturn: ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"],
            .synastry: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"],
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
        }
        #endif
    }
}
