import AstroCore
import Foundation

enum CurrentSkyLegacyCardFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.skyCards(
            context.snapshot,
            events: context.events,
            language: context.language,
            timeZone: context.timeZone
        )
    }
}

extension InsightFactory {
    static func skyCards(
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

    static func counts(_ aspects: [ChartAspect]) -> (supportive: Int, challenging: Int, neutral: Int) {
        let supportive = aspects.filter { $0.kind.supportive }.count
        let challenging = aspects.filter { $0.kind.challenging }.count
        return (supportive, challenging, max(0, aspects.count - supportive - challenging))
    }

    static func activityLabel(_ value: Int, language: AppLanguage) -> String {
        switch value {
        case 0 ... 20: localized("Low", "低", language: language)
        case 21 ... 45: localized("Moderate", "中等", language: language)
        case 46 ... 70: localized("High", "高", language: language)
        default: localized("Very high", "极高", language: language)
        }
    }

    static func signalDensity(_ aspects: [ChartAspect], limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        let total = aspects.prefix(limit).reduce(0) { $0 + $1.strength }
        return Int(min(1, total / Double(limit)) * 100)
    }

    static func motionFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
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

    static func cycleLeaders(_ aspects: [ChartAspect]) -> [ChartAspect?] {
        let long = aspects.first { $0.firstID == CelestialBody.saturn.rawValue || $0.firstID == CelestialBody.uranus.rawValue || $0.firstID == CelestialBody.neptune.rawValue || $0.firstID == CelestialBody.pluto.rawValue }
        let current = aspects.first { $0.firstID == CelestialBody.jupiter.rawValue }
        let daily = aspects.first { $0.firstID == CelestialBody.moon.rawValue || $0.firstID == CelestialBody.mercury.rawValue }
        return [long ?? aspects.first, current, daily ?? aspects.first]
    }

    static func moonIllumination(_ snapshot: ChartSnapshot) -> Double {
        let phase = phaseAngle(snapshot)
        return (1 - cos(phase * .pi / 180)) / 2
    }

    static func skyIngressFacts(
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

    static func skyUpcomingFacts(
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

    static func skyExactEventTitle(
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
}
