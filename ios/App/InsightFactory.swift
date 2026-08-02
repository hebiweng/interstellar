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
        content: CorpusContentProvider?,
        copyCatalog: CopyCatalogProvider?,
        language: AppLanguage,
        transitCalendar: [Int],
        preset: String? = nil,
        events: ChartEventData = .empty,
        timeZone: TimeZone = .current
    ) throws -> [InsightCardModel] {
        guard let snapshot else { return [] }
        let cards = switch chart {
        case .natal:
            natalCards(snapshot, language: language)
        case .currentSky:
            skyCards(snapshot, events: events, language: language, timeZone: timeZone)
        case .transit:
            transitCards(snapshot, natal: natal, aspects: aspects, calendar: transitCalendar, events: events, language: language, timeZone: timeZone)
        case .secondary:
            secondaryCards(snapshot, natal: natal, aspects: aspects, events: events, language: language, timeZone: timeZone)
        case .solarReturn:
            solarCards(snapshot, natal: natal, aspects: aspects, events: events, language: language, timeZone: timeZone)
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
                aspectsAreCross: aspectsAreCross,
                events: events
            )
            let interpretation = try? content?.interpret(context)
            let cardText = copyCatalog?.cardText(
               chart: chart,
               cardID: draft.id,
               snapshot: snapshot,
               natal: natal,
                aspects: cardAspects,
                preset: preset
            )
            if copyCatalog != nil, cardText == nil,
               copyCatalog?.copyRequired(chart: chart, cardID: draft.id) == true {
                throw InsightFactoryError.invalidCardContract(
                    "\(chart.rawValue).\(draft.id) has no valid approved copy selection"
                )
            }
            let conclusion = cardText?.headline ?? cardText?.body ?? interpretation?.summary ?? localized(
                "Reviewed interpretation unavailable",
                "已审核解读暂不可用",
                language: language
            )
            return InsightCardModel(
                id: draft.id,
                title: draft.title,
                icon: draft.icon,
                visual: draft.visual,
                facts: draft.facts.map { fact in
                    guard draft.id == "emotional-needs", fact.interpretation == nil else { return fact }
                    return InsightFact(
                        id: fact.id,
                        metricLabel: fact.metricLabel,
                        calculatedValue: fact.calculatedValue,
                        interpretationKey: fact.interpretationKey,
                        interpretationVariables: fact.interpretationVariables,
                        sourceFactIDs: fact.sourceFactIDs,
                        visualRole: fact.visualRole,
                        interpretation: conclusion,
                        emphasis: fact.emphasis,
                        progress: fact.progress,
                        symbol: fact.symbol,
                        category: fact.category,
                        markers: fact.markers
                    )
                },
                conclusionKey: "\(chart.contentPrefix).\(draft.id)",
                conclusion: conclusion,
                text: cardText
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

    private static func skyCards(
        _ snapshot: ChartSnapshot,
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let top = Array(snapshot.aspects.prefix(3))
        let balance = counts(snapshot.aspects)
        let retrogrades = snapshot.points.filter(\.retrograde)
        let phase = phaseAngle(snapshot)
        let activity = signalDensity(snapshot.aspects, limit: 8)
        let cycleAspects = cycleLeaders(snapshot.aspects)
        let elementScores = elementBalance(snapshot)
        let moon = snapshot.point(.moon)
        let moonHouse = snapshot.house(containing: moon?.longitudeDegrees ?? 0)
        let overviewFacts: [InsightFact] = [
            top.first.map { fact(localized("Dominant pattern", "主导结构", language: language), aspectTitle($0, language: language), tone($0.kind)) },
            fact(localized("Review cycles", "回顾调整中的主题", language: language), "\(retrogrades.count)", .transition),
            fact(localized("Atmosphere", "整体氛围", language: language), activityLabel(activity, language: language)),
        ].compactMap { $0 }
        let moonFacts: [InsightFact] = [
            moon.map { fact(localized("Moon sign", "月亮落座", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            moonHouse > 0 ? fact(localized("Moon area", "月亮领域", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition) : nil,
            fact(localized("Lunar phase", "月相", language: language), progressedPhaseName(phase, language: language)),
        ].compactMap { $0 }
        let patternFacts: [InsightFact] = [
            fact(localized("Support", "支持", language: language), "\(balance.supportive)", .supportive),
            fact(localized("Pressure", "压力", language: language), "\(balance.challenging)", .challenging),
            dominantBodies(snapshot.aspects, language: language).map { fact(localized("Focus", "焦点", language: language), $0, .transition) },
        ].compactMap { $0 }

        return [
            card( id: "sky-overview",
                title: localized("Sky at a glance", "当前天空总览", language: language),
                icon: "◉", visual: .skyOverview(
                    phase: phase,
                    activity: activity,
                    cycles: cycleAspects.map { $0?.strength ?? 0 }
                ),
                facts: overviewFacts,
                language: language
            ),
            card( id: "moon-now",
                title: localized("Moon now", "此刻的月亮", language: language),
                icon: "☽", visual: .phaseDial(phase: phase, illumination: moonIllumination(snapshot)),
                facts: moonFacts,
                language: language
            ),
            card( id: "aspect-pattern",
                title: localized("Major aspect pattern", "主要连接结构", language: language),
                icon: "◇", visual: .structureMap(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: patternFacts,
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
                facts: skyIngressFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
            card( id: "element-climate",
                title: localized("Element & mode climate", "元素与模式气质", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, orientation: elementOrientation(elementScores, language: language), language: language),
                language: language
            ),
            card( id: "upcoming-7-days",
                title: localized("Upcoming 7 days", "未来七天", language: language),
                icon: "▦", visual: .dateEvents,
                facts: skyUpcomingFacts(events, fallback: top, language: language, timeZone: timeZone),
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
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let top = Array(aspects.prefix(6))
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let movingFacts = snapshot.points
            .sorted { planetPathPriority($0) > planetPathPriority($1) }
            .map { point in
            let house = natal?.house(containing: point.longitudeDegrees) ?? 0
            return fact(
                bodyName(point.body, language: language),
                "\(Zodiac.name(index: point.signIndex, language: language)) · \(ConsumerCopy.lifeArea(house, language: language))",
                point.retrograde ? .challenging : .neutral,
                note: motionLabel(point, language: language),
                symbol: point.body.symbol
            )
        }
        let expanding = aspects.first(where: { $0.kind.supportive }).map { aspectTitle($0, language: language) } ?? ""
        let structuring = aspects.first(where: { $0.kind.challenging }).map { aspectTitle($0, language: language) } ?? ""
        let cycleLong = cycleEntry(
            in: events,
            bodies: [.saturn, .uranus, .neptune, .pluto],
            fallback: expanding,
            language: language,
            timeZone: timeZone
        )
        let cycleCurrent = cycleEntry(
            in: events,
            bodies: [.jupiter],
            fallback: top.first.map { aspectTitle($0, language: language) } ?? "",
            language: language,
            timeZone: timeZone
        )
        let cycleDaily = cycleEntry(
            in: events,
            bodies: [.moon, .mercury, .venus, .mars, .sun],
            fallback: structuring,
            language: language,
            timeZone: timeZone
        )

        return [
            card( id: "current-story",
                title: localized("Current story", "当前主线", language: language),
                icon: "◎", visual: .storyWeave(
                    expanding: expanding,
                    structuring: structuring,
                    result: localized(
                        "\(top.count) active cross-chart aspects",
                        "\(top.count) 个进行中的跨盘相位",
                        language: language
                    )
                ),
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
                icon: "◔", visual: .cycleTabs(
                    long: cycleLong.title,
                    longMeta: cycleLong.meta,
                    current: cycleCurrent.title,
                    currentMeta: cycleCurrent.meta,
                    daily: cycleDaily.title,
                    dailyMeta: cycleDaily.meta
                ),
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
                icon: "⇢", visual: .transitTimeline(events.transitWindows),
                facts: transitWindowFacts(events, fallback: top, language: language, timeZone: timeZone),
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
                facts: Array(activeHouses.prefix(12)),
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
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○",
                        category: transitCategory($0)
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
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let moon = snapshot.point(.moon)
        let sun = snapshot.point(.sun)
        let natalSun = natal?.point(.sun)
        let top = Array(aspects.prefix(6))
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let phase = phaseAngle(snapshot)
        let moonHouse = natal?.house(containing: moon?.longitudeDegrees ?? 0) ?? 0
        let phaseSequence = progressedPhaseSequence(phase, language: language)
        let chapterFacts: [InsightFact] = [
            fact(localized("Stage", "阶段", language: language), progressedPhaseName(phase, language: language), .transition),
            moon.map { fact(localized("insight.progressed-moon.fact", default: "Progressed moon", chinese: "次限月亮", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            sun.map { fact(localized("Progressed sun", "次限太阳", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
        ].compactMap { $0 }
        let identityFacts: [InsightFact] = [
            natalSun.map { fact(localized("Natal sun", "本命太阳", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☉") },
            sun.map { fact(localized("Progressed sun", "次限太阳", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
        ].compactMap { $0 }

        return [
            card( id: "developmental-chapter",
                title: localized("Developmental chapter", "发展阶段", language: language),
                icon: "◐", visual: .stageFlow(
                    old: phaseSequence.previous,
                    transition: phaseSequence.current,
                    emerging: phaseSequence.next
                ),
                facts: chapterFacts,
                language: language
            ),
            card( id: "progressed-moon",
                title: localized("insight.progressed-moon.title", default: "Progressed moon", chinese: "长期月亮", language: language),
                icon: "☽", visual: .moonProgress(progress: phase / 360),
                facts: progressedMoonFacts(
                    events,
                    moon: moon,
                    moonHouse: moonHouse,
                    phase: phase,
                    language: language,
                    timeZone: timeZone
                ),
                language: language
            ),
            card( id: "identity-development",
                title: localized("Identity development", "身份发展", language: language),
                icon: "☉", visual: .identityCompare(
                    natal: natalSun.map { Zodiac.position($0, language: language) } ?? "",
                    progressed: sun.map { Zodiac.position($0, language: language) } ?? ""
                ),
                facts: identityFacts,
                language: language
            ),
            card( id: "turning-points",
                title: localized("Turning points", "转折点", language: language),
                icon: "⟐", visual: .turningRows,
                facts: turningPointFacts(events, fallback: top, language: language, timeZone: timeZone),
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
                facts: secondaryTimelineFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
        ]
    }

    // MARK: - Solar return (7)

    private static func solarCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let ruler = ruler(ofSign: Int(snapshot.angles.ascendantDegrees / 30) % 12)
        let top = Array(snapshot.aspects.prefix(4))
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let overlayAnchors = natalOverlayAnchors(snapshot: snapshot, natal: natal, language: language)
        let yearThemeFacts: [InsightFact] = [
            fact(localized("Return ascendant", "返照上升", language: language), ascSign, .transition, symbol: "ASC"),
            fact(localized("Chart ruler", "命主星", language: language), bodyName(ruler, language: language), .supportive, symbol: ruler.symbol),
            sunHouseLabel(sun, snapshot: snapshot, language: language).map {
                fact(localized("Sun house", "太阳落宫", language: language), $0, .neutral, symbol: "☉")
            },
        ].compactMap { $0 }
        let dynamicFacts: [InsightFact] = [
            strongestSupport.map { fact(localized("Supportive aspect", "支持相位", language: language), aspectTitle($0, language: language), .supportive) },
            strongestChallenge.map { fact(localized("Challenging aspect", "张力相位", language: language), aspectTitle($0, language: language), .challenging) },
        ].compactMap { $0 }
        let firstOverlay = overlayAnchors.first
        let secondOverlay = overlayAnchors.dropFirst().first

        return [
            card( id: "year-theme",
                title: localized("Your birthday year", "你的生日年", language: language),
                icon: "☉", visual: .yearOrbit,
                facts: yearThemeFacts,
                language: language
            ),
            card( id: "year-anchors",
                title: localized("Year anchors", "年度锚点", language: language),
                icon: "⚓", visual: .connectionGrid,
                facts: yearAnchorFacts(snapshot: snapshot, sun: sun, ruler: ruler, language: language),
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
                    opening: strongestSupport.map { aspectTitle($0, language: language) } ?? "",
                    demand: strongestChallenge.map { aspectTitle($0, language: language) } ?? "",
                    openingLabel: localized("OPENING", "展开", language: language),
                    demandLabel: localized("DEMAND", "要求", language: language)
                ),
                facts: dynamicFacts,
                language: language
            ),
            card( id: "year-timeline",
                title: localized("Year timeline", "年度时间线", language: language),
                icon: "⇢", visual: .quarterTabs,
                facts: solarSeasonFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
            card( id: "natal-overlay",
                title: localized("Natal overlay", "与本命叠加", language: language),
                icon: "∞", visual: .natalOverlay(
                    firstLabel: firstOverlay?.label ?? "",
                    firstValue: firstOverlay?.value ?? "",
                    secondLabel: secondOverlay?.label ?? "",
                    secondValue: secondOverlay?.value ?? ""
                ),
                facts: overlayAnchors,
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

    private static func card(
        id: String,
        title: String,
        icon: String,
        visual: InsightVisual,
        facts: [InsightFact],
        language: AppLanguage
    ) -> InsightCardModel {
        return InsightCardModel(
            id: id,
            title: title,
            icon: icon,
            visual: visual,
            facts: facts,
            conclusionKey: nil,
            conclusion: ""
        )
    }

    private static func fact(
        _ label: String,
        _ value: String,
        _ emphasis: InsightTone = .neutral,
        stableID: String? = nil,
        interpretationKey: String? = nil,
        sourceFactIDs: [String] = [],
        note: String? = nil,
        progress: Double? = nil,
        symbol: String? = nil,
        category: String? = nil,
        markers: [Double]? = nil
    ) -> InsightFact {
        let rawID = [label, value, symbol ?? "", category ?? ""].joined(separator: "|")
        let resolvedID = stableID ?? "fact." + String(SHA256Digest.hash(Data(rawID.utf8)).hex.prefix(20))
        return InsightFact(
            id: resolvedID,
            metricLabel: label,
            calculatedValue: value,
            interpretationKey: interpretationKey ?? "insight.\(resolvedID)",
            interpretationVariables: ["metric": label, "value": value],
            sourceFactIDs: sourceFactIDs.isEmpty ? [resolvedID] : sourceFactIDs,
            visualRole: category,
            interpretation: note,
            emphasis: emphasis,
            progress: progress,
            symbol: symbol,
            category: category,
            markers: markers
        )
    }

    private static func transitCategory(_ aspect: ChartAspect) -> String {
        guard let first = CelestialBody(rawValue: aspect.firstID) else { return "current" }
        switch first {
        case .saturn, .uranus, .neptune, .pluto: return "long-term"
        case .moon, .mercury, .venus, .mars, .sun: return "daily"
        default: return "current"
        }
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

    private static func dominantBodies(_ aspects: [ChartAspect], language: AppLanguage) -> String? {
        var scores: [String: Double] = [:]
        for aspect in aspects {
            scores[aspect.firstID, default: 0] += aspect.strength
            scores[aspect.secondID, default: 0] += aspect.strength * 0.6
        }
        let names = scores
            .sorted { $0.value > $1.value }
            .prefix(2)
            .compactMap { CelestialBody(rawValue: $0.key).map { bodyName($0, language: language) } }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    private static func motionLabel(_ point: ChartPoint, language: AppLanguage) -> String {
        point.retrograde
            ? localized("insight.reviewing.status", default: "Reviewing", chinese: "回顾调整中", language: language)
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

    private static func elementFacts(_ scores: [Double], orientation: String, language: AppLanguage) -> [InsightFact] {
        // Prototype order: Air, Earth, Fire, Water. scores = [fire, earth, air, water].
        let order = [2, 1, 0, 3]
        let labels = language == .english
            ? ["Air", "Earth", "Fire", "Water"]
            : ["风", "土", "火", "水"]
        return order.enumerated().map { index, sourceIndex in
            let score = scores[min(max(0, sourceIndex), scores.count - 1)]
            let percent = Int(score * 100)
            let value: String
            if percent > 66 {
                value = language == .english ? "High" : "高"
            } else if percent > 35 {
                value = language == .english ? "Strong" : "强"
            } else {
                value = language == .english ? "Light" : "轻"
            }
            return fact(
                labels[index],
                value,
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: score
            )
        } + [
            fact(localized("Emphasis", "主导", language: language), orientation, .transition)
        ]
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

    private static func activeHouseFacts(_ values: [Double], language: AppLanguage, limit: Int = 12) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .filter { $0.element > 0.001 }
            .sorted { $0.element > $1.element }
            .prefix(limit)
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


    private static func houseOverlayFacts(
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

    private static func calendarFacts(_ values: [Int], language: AppLanguage) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .sorted { $0.element > $1.element }
            .prefix(3)
        return ranked.map { index, value in
            let percent = value
            return fact(
                LocalizedFormatters.day(index + 1, language: language),
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
            separating.map { aspect in fact(
                localized("Just passed", "刚刚经过", language: language),
                aspectTitle(aspect, language: language),
                tone(aspect.kind),
                progress: aspect.strength,
                symbol: "✓"
            ) },
            current.map { aspect in fact(
                localized("Current", "当前", language: language),
                aspectTitle(aspect, language: language),
                .transition,
                progress: aspect.strength,
                symbol: "●"
            ) },
            applying.map { aspect in fact(
                localized("Next", "接下来", language: language),
                aspectTitle(aspect, language: language),
                tone(aspect.kind),
                progress: aspect.strength,
                symbol: "→"
            ) },
        ].compactMap { $0 }
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

    private static func progressedPhaseSequence(
        _ angle: Double,
        language: AppLanguage
    ) -> (previous: String, current: String, next: String) {
        let labels = [
            localized("New phase", "新月阶段", language: language),
            localized("Building phase", "上弦阶段", language: language),
            localized("Review phase", "满月阶段", language: language),
            localized("Integration phase", "下弦阶段", language: language),
        ]
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let index = min(3, max(0, Int(normalized / 90)))
        return (
            labels[(index + labels.count - 1) % labels.count],
            labels[index],
            labels[(index + 1) % labels.count]
        )
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

    private static func sunHouseLabel(_ sun: ChartPoint?, snapshot: ChartSnapshot, language: AppLanguage) -> String? {
        guard let sun else { return nil }
        let house = snapshot.house(containing: sun.longitudeDegrees)
        guard house > 0 else { return nil }
        return language == .english ? ordinal(house) : "第\(house)宫"
    }

    private static func moonIllumination(_ snapshot: ChartSnapshot) -> Double {
        let phase = phaseAngle(snapshot)
        return (1 - cos(phase * .pi / 180)) / 2
    }



    private static func emotionalNeedsFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
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

    private static func careerDirectionFacts(
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

    private static func yearAnchorFacts(
        snapshot: ChartSnapshot,
        sun: ChartPoint?,
        ruler: CelestialBody,
        language: AppLanguage
    ) -> [InsightFact] {
        let ascIndex = Int(snapshot.angles.ascendantDegrees / 30) % 12
        let ascValue = localized(
            "\(Zodiac.englishNames[ascIndex]) rising",
            "\(Zodiac.chineseNames[ascIndex])上升",
            language: language
        )
        let rulerPoint = snapshot.point(ruler)
        let rulerHouse = rulerPoint.map { snapshot.house(containing: $0.longitudeDegrees) }
        let sunHouse = sun.map { snapshot.house(containing: $0.longitudeDegrees) }
        var facts: [InsightFact] = [
            fact(
                localized("Return ascendant", "返照上升", language: language),
                ascValue,
                .transition
            ),
        ]
        if let rulerPoint, let rulerHouse, rulerHouse > 0 {
            facts.append(
                fact(
                    localized("Chart ruler", "命主星", language: language),
                    localized(
                        "\(bodyName(ruler, language: .english)) · \(Zodiac.position(rulerPoint, language: .english)) · \(ordinal(rulerHouse)) house",
                        "\(bodyName(ruler, language: .simplifiedChinese)) · \(Zodiac.position(rulerPoint, language: .simplifiedChinese)) · 第\(rulerHouse)宫",
                        language: language
                    ),
                    .supportive
                )
            )
        }
        if let sun, let sunHouse, sunHouse > 0 {
            facts.append(
                fact(
                    localized("Solar return sun", "返照太阳", language: language),
                    localized(
                        "\(Zodiac.position(sun, language: .english)) · \(ordinal(sunHouse)) house",
                        "\(Zodiac.position(sun, language: .simplifiedChinese)) · 第\(sunHouse)宫",
                        language: language
                    ),
                    .neutral
                )
            )
        }
        if let angular = angularPlanetInfo(snapshot), angular.distance <= 5 {
            facts.append(
                fact(
                    localized("Angular planet", "角宫行星", language: language),
                    localized(
                        "\(bodyName(angular.body, language: .english)) · \(angular.axis) · \(Zodiac.formatDegree(angular.distance)) orb",
                        "\(bodyName(angular.body, language: .simplifiedChinese)) · \(angular.axis) · 容许度 \(Zodiac.formatDegree(angular.distance))",
                        language: language
                    ),
                    .transition
                )
            )
        }
        return facts
    }

    private static func natalOverlayAnchors(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        language: AppLanguage
    ) -> [InsightFact] {
        guard let natal else { return [] }
        let asc = natal.angles.ascendantDegrees
        let mc = natal.angles.midheavenDegrees
        let axes: [(axis: String, longitude: Double)] = [
            ("MC", mc),
            ("IC", (mc + 180).truncatingRemainder(dividingBy: 360)),
            ("ASC", asc),
            ("DSC", (asc + 180).truncatingRemainder(dividingBy: 360)),
        ]
        var candidates: [(body: CelestialBody, axis: String, distance: Double)] = []
        for point in snapshot.points {
            for axis in axes {
                candidates.append((point.body, axis.axis, angularDistance(point.longitudeDegrees, axis.longitude)))
            }
        }
        candidates.sort { $0.distance < $1.distance }
        var usedBodies = Set<String>()
        var chosen: [(body: CelestialBody, axis: String, distance: Double)] = []
        for item in candidates where item.distance <= 5 && !usedBodies.contains(item.body.rawValue) {
            usedBodies.insert(item.body.rawValue)
            chosen.append(item)
            if chosen.count == 2 { break }
        }
        return chosen.map { overlayAnchorFact($0, language: language) }
    }

    private static func overlayAnchorFact(
        _ item: (body: CelestialBody, axis: String, distance: Double),
        language: AppLanguage
    ) -> InsightFact {
        let value: String
        switch item.axis {
        case "MC":
            value = localized("Near natal MC", "靠近本命天顶", language: language)
        case "IC":
            value = localized("At natal IC", "落在本命天底", language: language)
        case "ASC":
            value = localized("Near natal ASC", "靠近本命上升", language: language)
        default:
            value = localized("Near natal DSC", "靠近本命下降", language: language)
        }
        let label = localized(
            "Return \(bodyName(item.body, language: .english))",
            "返照\(bodyName(item.body, language: .simplifiedChinese))",
            language: language
        )
        return fact(
            label,
            "\(value) · \(Zodiac.formatDegree(item.distance))",
            item.axis == "MC" || item.axis == "ASC" ? .supportive : .challenging
        )
    }

    private static func angularPlanetInfo(_ snapshot: ChartSnapshot) -> (body: CelestialBody, axis: String, distance: Double)? {
        let asc = snapshot.angles.ascendantDegrees
        let mc = snapshot.angles.midheavenDegrees
        let axes: [(axis: String, longitude: Double)] = [
            ("MC", mc),
            ("IC", (mc + 180).truncatingRemainder(dividingBy: 360)),
            ("ASC", asc),
            ("DSC", (asc + 180).truncatingRemainder(dividingBy: 360)),
        ]
        var best: (body: CelestialBody, axis: String, distance: Double)?
        for point in snapshot.points {
            for axis in axes {
                let distance = angularDistance(point.longitudeDegrees, axis.longitude)
                if distance < (best?.distance ?? .infinity) {
                    best = (point.body, axis.axis, distance)
                }
            }
        }
        return best
    }

    private static func angularDistance(_ first: Double, _ second: Double) -> Double {
        let diff = abs(first - second).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    private static func ordinal(_ value: Int) -> String {
        guard value > 0 else { return "1st" }
        let ones = value % 10
        let tens = value % 100
        if tens >= 11, tens <= 13 {
            return "\(value)th"
        }
        switch ones {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }

    private static func semanticCategory(_ body: CelestialBody, language: AppLanguage) -> String {
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

    private static func cycleEntry(
        in events: ChartEventData,
        bodies: Set<CelestialBody>,
        fallback: String,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> (title: String, meta: String) {
        let window = events.transitWindows.first { bodies.contains($0.first) }
        if let window {
            let title = "\(bodyName(window.first, language: language)) \(window.kind.symbol) \(bodyName(window.second, language: language))"
            let meta = window.start.shortEventRange(to: window.end, language: language, timeZone: timeZone)
            return (title, meta)
        }
        return (fallback, "")
    }

    private static func planetPathPriority(_ point: ChartPoint) -> Int {
        var score = 0
        switch point.body {
        case .saturn, .uranus, .neptune, .pluto: score += 50
        default: break
        }
        if point.body == .moon { score -= 30 }
        if point.degreeInSign > 27 { score += 20 }
        if point.retrograde { score += 10 }
        return score
    }

    // MARK: - Event-driven facts (real ephemeris dates)

    private static func skyIngressFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let rows = events.skyIngresses.prefix(4)
        guard !rows.isEmpty else {
            return timelineFacts(fallback, language: language)
        }
        return rows.map { ingress in
            let title = localized(
                "\(bodyName(ingress.body, language: .english)) enters \(Zodiac.englishNames[ingress.signIndex])",
                "\(bodyName(ingress.body, language: .simplifiedChinese))进入\(Zodiac.chineseNames[ingress.signIndex])",
                language: language
            )
            let note = ingress.nextDate.map {
                localized(
                    "Until \($0.shortEventDate(language: .english, timeZone: timeZone))",
                    "持续到\($0.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))",
                    language: language
                )
            }
            return fact(
                ingress.date.shortEventDate(language: language, timeZone: timeZone),
                title,
                .transition,
                note: note
            )
        }
    }

    private static func skyUpcomingFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        var rows: [(date: Date, title: String, note: String?)] = []
        for ingress in events.skyIngresses {
            let interval = ingress.date.timeIntervalSinceNow
            guard interval >= 0, interval <= 7 * 86_400 else { continue }
            rows.append((
                ingress.date,
                localized(
                    "\(bodyName(ingress.body, language: .english)) enters \(Zodiac.englishNames[ingress.signIndex])",
                    "\(bodyName(ingress.body, language: .simplifiedChinese))进入\(Zodiac.chineseNames[ingress.signIndex])",
                    language: language
                ),
                nil
            ))
        }
        for exact in events.skyExactEvents {
            let interval = exact.date.timeIntervalSinceNow
            guard interval >= 0, interval <= 7 * 86_400 else { continue }
            rows.append((exact.date, skyExactEventTitle(exact, language: language), nil))
        }
        rows.sort { $0.date < $1.date }
        let topRows = rows.prefix(3)
        guard !topRows.isEmpty else {
            return timelineFacts(fallback, language: language)
        }
        return topRows.map { row in
            fact(
                row.date.shortEventDate(language: language, timeZone: timeZone),
                row.title,
                .transition,
                note: row.note
            )
        }
    }

    private static func skyExactEventTitle(
        _ event: ChartEventData.SkyExactEvent,
        language: AppLanguage
    ) -> String {
        let sunMoonPair = (event.first == .sun && event.second == .moon)
            || (event.first == .moon && event.second == .sun)
        if sunMoonPair {
            if event.kind == .opposition {
                return localized("Full Moon", "满月", language: language)
            }
            if event.kind == .conjunction {
                return localized("New Moon", "新月", language: language)
            }
        }
        return "\(bodyName(event.first, language: language)) \(event.kind.symbol) \(bodyName(event.second, language: language))"
    }

    private static func transitWindowFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let rows = events.transitWindows.prefix(4)
        guard !rows.isEmpty else {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        return rows.map { window in
            let title = "\(bodyName(window.first, language: language)) \(window.kind.symbol) \(bodyName(window.second, language: language))"
            let now = Date()
            let total = max(1, window.end.timeIntervalSince(window.start))
            let progress = min(1, max(0, now.timeIntervalSince(window.start) / total))
            return fact(
                title,
                window.exact.shortEventDate(language: language, timeZone: timeZone),
                tone(window.kind),
                note: window.start.shortEventRange(to: window.end, language: language, timeZone: timeZone),
                progress: progress
            )
        }
    }

    private static func progressedMoonFacts(
        _ events: ChartEventData,
        moon: ChartPoint?,
        moonHouse: Int,
        phase: Double,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        var facts: [InsightFact] = [
            moon.map { fact(localized("Moon sign", "月亮落座", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            moonHouse > 0 ? fact(localized("Moon area", "月亮领域", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition) : nil,
            fact(localized("Phase", "月相", language: language), progressedPhaseName(phase, language: language)),
        ].compactMap { $0 }
        if let window = events.progressedMoon {
            let months = max(0, Int((Double(window.daysInSign) / 30.44).rounded()))
            facts.append(
                fact(
                    localized("In sign", "在座时长", language: language),
                    localized(
                        "\(months) months",
                        "\(months)个月",
                        language: language
                    ),
                    .supportive
                )
            )
            facts.append(
                fact(
                    localized("Ingress", "下次换座", language: language),
                    window.nextIngress.shortEventMonthYear(language: language, timeZone: timeZone),
                    .transition
                )
            )
        }
        return facts
    }

    private static func turningPointFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let rows = events.progressedTurningPoints.prefix(3)
        guard !rows.isEmpty else {
            return fallback.prefix(3).map {
                fact(
                    aspectTitle($0, language: language),
                    "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                    tone($0.kind),
                    note: nil,
                    progress: $0.strength
                )
            }
        }
        return rows.map { point in
            let title = "\(bodyName(point.first, language: language)) \(point.kind.symbol) \(bodyName(point.second, language: language))"
            if let date = point.exactDate {
                return fact(
                    localized("Exact", "精确", language: language),
                    title,
                    tone(point.kind),
                    note: date.shortEventMonthYear(language: language, timeZone: timeZone),
                    symbol: point.first.symbol
                )
            }
            return fact(
                localized("Building", "形成中", language: language),
                title,
                .transition,
                note: Zodiac.formatDegree(point.separationDegrees),
                symbol: point.first.symbol
            )
        }
    }

    private static func secondaryTimelineFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        guard let moon = events.progressedMoon else {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        let now = Date()
        var rows: [InsightFact] = []
        let moonTitle = localized(
            "Moon through \(Zodiac.englishNames[moon.signIndex])",
            "月亮行经\(Zodiac.chineseNames[moon.signIndex])",
            language: language
        )
        rows.append(
            fact(
                moonTitle,
                localized("Now", "现在", language: language),
                .transition,
                note: now.shortEventRange(to: moon.nextIngress, language: language, timeZone: timeZone),
                progress: 0
            )
        )
        for point in events.progressedTurningPoints.prefix(2) {
            guard let exactDate = point.exactDate else { continue }
            let start = exactDate.addingTimeInterval(-30 * 86_400)
            let end = exactDate.addingTimeInterval(30 * 86_400)
            let total = max(1, end.timeIntervalSince(start))
            let progress = min(1, max(0, now.timeIntervalSince(start) / total))
            rows.append(
                fact(
                    "\(bodyName(point.first, language: language)) \(point.kind.symbol) \(bodyName(point.second, language: language))",
                    exactDate.shortEventMonthYear(language: language, timeZone: timeZone),
                    tone(point.kind),
                    note: start.shortEventRange(to: end, language: language, timeZone: timeZone),
                    progress: progress,
                    markers: [progress]
                )
            )
        }
        if rows.isEmpty {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        return rows
    }

    private static func solarSeasonFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let seasons = events.solarSeasons.prefix(4)
        guard !seasons.isEmpty else {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        return seasons.map { season in
            return fact(
                LocalizedFormatters.quarter(season.index + 1, language: language),
                season.start.shortEventRange(to: season.end, language: language, timeZone: timeZone),
                season.index == 0 ? .transition : .neutral,
                note: nil
            )
        }
    }

    private static func validate(_ cards: [InsightCardModel], for chart: ChartKind) throws {
        #if DEBUG
        let expected: [ChartKind: [String]] = [
            .natal: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"],
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
        guard cards.allSatisfy({ !$0.title.isEmpty && !$0.summary.isEmpty }) else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) contains empty card copy")
        }
        #endif
    }
}
