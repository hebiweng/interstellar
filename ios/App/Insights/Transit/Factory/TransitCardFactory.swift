import AstroCore
import Foundation

enum TransitCardFactory {
    static func make(
        plan: TransitContentPlan,
        language: AppLanguage,
        initialRangeDays: Int
    ) -> [InsightCardModel] {
        InsightFactory.transitCards(
            plan: plan,
            language: language,
            initialRangeDays: initialRangeDays
        )
    }
}

extension InsightFactory {
    static func transitCards(
        plan: TransitContentPlan,
        language: AppLanguage,
        initialRangeDays: Int
    ) -> [InsightCardModel] {
        let timeZone = TimeZone(identifier: plan.timeZoneIdentifier) ?? .current
        let storyPlan = plan.card("current-story")!
        let cyclePlan = plan.card("current-cycles")!
        let timelinePlan = plan.card("transit-timeline")!
        let pathPlan = plan.card("planet-paths")!
        let areaPlan = plan.card("life-areas")!
        let activePlan = plan.card("active-transits")!

        let storyAspects = storyPlan.evidence.compactMap { evidence -> TransitAspectFact? in
            guard case let .aspect(fact) = evidence.fact else { return nil }
            return fact
        }
        let expanding = storyAspects.first(where: { $0.kind.supportive })
            .map { transitAspectTitle($0, language: language) } ?? ""
        let structuring = storyAspects.first(where: { $0.kind.challenging })
            .map { transitAspectTitle($0, language: language) } ?? ""

        let longCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .longCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let currentCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .currentCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let dailyCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .dailyCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let timelineCalendar = timelinePlan.evidence.compactMap { evidence -> TransitCalendarFact? in
            guard case let .calendar(fact) = evidence.fact else { return nil }
            return fact
        }
        let pathRows = transitPlanetPathRows(
            pathPlan,
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let lifeAreaRows = transitLifeAreaRows(areaPlan, language: language)
        let activeRows = transitActiveRows(
            activePlan,
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )

        return [
            card(
                id: "current-story",
                title: localized("Current story", "当前主线", language: language),
                icon: "◎",
                visual: .storyWeave(
                    expanding: expanding,
                    structuring: structuring,
                    result: localized(
                        "\(storyAspects.count) planned cross-chart aspects",
                        "\(storyAspects.count) 个已规划的跨盘相位",
                        language: language
                    )
                ),
                facts: plannedAspectFacts(storyPlan, language: language, timeZone: timeZone),
                language: language
            ),
            card(
                id: "current-cycles",
                title: localized("Current cycles", "当前周期", language: language),
                icon: "◔",
                visual: .cycleTabs(
                    long: longCycle,
                    current: currentCycle,
                    daily: dailyCycle
                ),
                facts: cyclePlan.evidence
                    .filter { $0.role != .cycleCalendar }
                    .compactMap {
                        transitInsightFact(
                            $0,
                            anchorDate: plan.anchorDate,
                            language: language,
                            timeZone: timeZone
                        )
                    },
                language: language
            ),
            card(
                id: "transit-timeline",
                title: localized("Transit timeline", "变化时间线", language: language),
                icon: "⇢",
                visual: .transitTimeline(
                    entries: TransitTimelineProjection.entries(from: timelinePlan.evidence),
                    calendar: timelineCalendar,
                    anchorDate: plan.anchorDate,
                    initialRangeDays: initialRangeDays,
                    timeZoneIdentifier: plan.timeZoneIdentifier
                ),
                facts: timelinePlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "planet-paths",
                title: localized("Planet paths", "行星路径", language: language),
                icon: "⊛",
                visual: .transitPlanetPaths(pathRows),
                facts: pathPlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "life-areas",
                title: localized("Life areas", "生活领域", language: language),
                icon: "⌂",
                visual: .transitLifeAreas(lifeAreaRows),
                facts: areaPlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "active-transits",
                title: localized("Active transits", "进行中的变化", language: language),
                icon: "⌗",
                visual: .transitActiveRows(activeRows),
                facts: plannedActiveFacts(
                    activePlan,
                    anchorDate: plan.anchorDate,
                    language: language,
                    timeZone: timeZone
                ),
                language: language
            ),
        ]
    }

    static func transitInsightFact(
        _ evidence: TransitPlannedEvidence,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> InsightFact? {
        switch evidence.fact {
        case let .aspect(aspect):
            return fact(
                transitAspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                stableID: aspect.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: ConsumerCopy.lifeArea(aspect.natalHouse, language: language),
                progress: aspect.strength,
                symbol: aspect.kind.symbol,
                category: cycleCategory(aspect.cycleBand)
            )
        case let .window(window):
            let total = max(1, window.end.timeIntervalSince(window.start))
            let progress = min(1, max(0, anchorDate.timeIntervalSince(window.start) / total))
            let exactDates = window.exactDates.map {
                $0.shortEventDate(language: language, timeZone: timeZone)
            }
            return fact(
                transitWindowTitle(window, language: language),
                exactDates.joined(separator: " · "),
                tone(window.kind),
                stableID: window.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: window.start.shortEventRange(to: window.end, language: language, timeZone: timeZone),
                progress: progress,
                symbol: window.kind.symbol,
                category: cycleCategory(window.cycleBand)
            )
        case let .planetEvent(event):
            return fact(
                bodyName(event.body, language: language),
                planetEventValue(event, language: language),
                event.kind == .stationRetrograde ? .challenging : .transition,
                stableID: event.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: event.timestamp.shortEventDate(language: language, timeZone: timeZone),
                symbol: event.body.symbol,
                category: evidence.role.rawValue
            )
        case let .placement(placement):
            let position = [
                "\(Zodiac.name(index: placement.signIndex, language: language)) \(Zodiac.formatDegree(placement.degreeInSign))",
                (1 ... 12).contains(placement.natalHouse)
                    ? ConsumerCopy.lifeArea(placement.natalHouse, language: language)
                    : nil,
            ].compactMap { $0 }.joined(separator: " · ")
            return fact(
                bodyName(placement.body, language: language),
                position,
                placement.retrograde ? .challenging : .neutral,
                stableID: placement.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: "\(motionLabel(retrograde: placement.retrograde, language: language)) · \(String(format: "%+.4f°/d", placement.longitudeSpeedDegreesPerDay))",
                symbol: placement.body.symbol
            )
        case let .lifeArea(area):
            let percent = Int((area.normalizedScore * 100).rounded())
            return fact(
                ConsumerCopy.lifeArea(area.house, language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                stableID: area.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                progress: area.normalizedScore,
                symbol: "\(area.house)"
            )
        case .calendar:
            return nil
        }
    }

    static func plannedActiveFacts(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let aspectFacts = plannedAspectFacts(plan, language: language, timeZone: timeZone)
        let eventFacts = plan.evidence.compactMap { evidence -> InsightFact? in
            guard case .planetEvent = evidence.fact else { return nil }
            return transitInsightFact(
                evidence,
                anchorDate: anchorDate,
                language: language,
                timeZone: timeZone
            )
        }
        return aspectFacts + eventFacts
    }

    static func transitPlanetPathRows(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [TransitPlanetPathRow] {
        let events = plan.evidence.compactMap { evidence -> TransitPlanetEventFact? in
            guard evidence.role == .pathEvent, case let .planetEvent(event) = evidence.fact else { return nil }
            return event
        }
        return plan.evidence.compactMap { evidence -> TransitPlanetPathRow? in
            guard evidence.role == .path, case let .placement(placement) = evidence.fact else { return nil }
            let bodyEvents = events
                .filter { $0.body == placement.body && $0.timestamp >= anchorDate }
                .sorted { $0.timestamp == $1.timestamp ? $0.factID < $1.factID : $0.timestamp < $1.timestamp }
            let nextHouseIngress = bodyEvents.first { $0.kind == .houseIngress }
            let nextDirectStation = bodyEvents.first { $0.kind == .stationDirect }
            let imminentHouseIngress = nextHouseIngress.flatMap { event in
                event.timestamp.timeIntervalSince(anchorDate) <= 30 * 86_400 ? event : nil
            }
            let title: String
            let detail: String
            let state: TransitPathState
            let timing: String
            let linkedEvent: TransitPlanetEventFact?
            let displayHouse: Int

            if let ingress = imminentHouseIngress, let house = ingress.toIndex, (1 ... 12).contains(house) {
                title = transitEnteringHouseTitle(placement.body, house: house, language: language)
                detail = localized(
                    "\(ConsumerCopy.lifeArea(house, language: .english)) · ingress \(ingress.timestamp.shortEventDate(language: .english, timeZone: timeZone))",
                    "\(ConsumerCopy.lifeArea(house, language: .simplifiedChinese)) · \(ingress.timestamp.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))进入",
                    language: language
                )
                state = .next
                timing = relativeTransitTime(from: anchorDate, to: ingress.timestamp, language: language, includesPrefix: true)
                linkedEvent = ingress
                displayHouse = house
            } else {
                title = transitInHouseTitle(placement.body, house: placement.natalHouse, language: language)
                detail = localized(
                    "\(ConsumerCopy.lifeArea(placement.natalHouse, language: .english)) · \(Zodiac.name(index: placement.signIndex, language: .english)) \(Zodiac.formatDegree(placement.degreeInSign))",
                    "\(ConsumerCopy.lifeArea(placement.natalHouse, language: .simplifiedChinese)) · \(Zodiac.name(index: placement.signIndex, language: .simplifiedChinese)) \(Zodiac.formatDegree(placement.degreeInSign))",
                    language: language
                )
                state = placement.retrograde ? .retrograde : .direct
                if placement.retrograde, let station = nextDirectStation {
                    timing = transitUntilMonth(station.timestamp, language: language, timeZone: timeZone)
                    linkedEvent = station
                } else if let nextEvent = bodyEvents.first {
                    timing = relativeTransitTime(from: anchorDate, to: nextEvent.timestamp, language: language, includesPrefix: false)
                    linkedEvent = nextEvent
                } else {
                    timing = localized("long-term", "长期", language: language)
                    linkedEvent = nil
                }
                displayHouse = placement.natalHouse
            }
            return TransitPlanetPathRow(
                id: placement.factID,
                sourceFactIDs: Array(Set(evidence.fact.sourceFactIDs + [linkedEvent?.factID].compactMap { $0 })).sorted(),
                body: placement.body,
                house: displayHouse,
                symbol: placement.body.symbol,
                title: title,
                detail: detail,
                state: state,
                timing: timing
            )
        }
    }

    static func transitLifeAreaRows(
        _ plan: CardEvidencePlan,
        language: AppLanguage
    ) -> [TransitLifeAreaRow] {
        plan.evidence.compactMap { evidence in
            guard case let .lifeArea(area) = evidence.fact else { return nil }
            let percent = Int((area.normalizedScore * 100).rounded())
            return TransitLifeAreaRow(
                id: area.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                title: area.house == 1
                    ? localized("Personal focus", "个人重心", language: language)
                    : ConsumerCopy.lifeArea(area.house, language: language),
                activity: activityLabel(percent, language: language),
                triggerCount: Set(area.contributingFactIDs).count,
                progress: area.normalizedScore
            )
        }
    }

    static func transitActiveRows(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [TransitActiveRow] {
        let windows = plan.evidence.compactMap { evidence -> TransitWindowFact? in
            guard case let .window(window) = evidence.fact else { return nil }
            return window
        }
        let aspectRows = plan.evidence.compactMap { evidence -> TransitActiveRow? in
            guard case let .aspect(aspect) = evidence.fact else { return nil }
            let linkedWindows = windows.filter { $0.sourceAspectFactID == aspect.factID }
            let primaryWindow = linkedWindows.min {
                abs($0.exact.timeIntervalSince(anchorDate)) < abs($1.exact.timeIntervalSince(anchorDate))
            }
            let status: TransitActiveStatus
            if primaryWindow?.returning == true {
                status = .returning
            } else {
                status = switch aspect.phase {
                case .applying: .applying
                case .exact: .exact
                case .separating: .separating
                }
            }
            let sourceFactIDs = Array(Set(
                evidence.fact.sourceFactIDs + linkedWindows.flatMap { TransitFact.window($0).sourceFactIDs }
            )).sorted()
            let detailParts = [
                (1 ... 12).contains(aspect.natalHouse)
                    ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                    : nil,
                activeAspectTiming(status: status, window: primaryWindow, anchorDate: anchorDate, language: language, timeZone: timeZone),
            ].compactMap { $0 }
            var fields = [
                TransitTechnicalField(id: "stage", label: localized("Stage", "阶段", language: language), value: activeStatusLabel(status, language: language)),
                TransitTechnicalField(id: "orb", label: localized("Orb", "容许度", language: language), value: formatOrb(aspect.orbDegrees)),
                TransitTechnicalField(id: "house", label: localized("House", "宫位", language: language), value: transitHouseLabel(aspect.natalHouse, language: language)),
            ]
            if let primaryWindow {
                fields.append(
                    TransitTechnicalField(
                        id: "window",
                        label: localized("Active window", "生效窗口", language: language),
                        value: primaryWindow.start.shortEventRange(to: primaryWindow.end, language: language, timeZone: timeZone)
                    )
                )
            }
            return TransitActiveRow(
                id: aspect.factID,
                sourceFactIDs: sourceFactIDs,
                symbol: CelestialBody(rawValue: aspect.movingID)?.symbol ?? aspect.kind.symbol,
                title: transitActiveAspectTitle(aspect, language: language),
                detail: detailParts.joined(separator: " · "),
                category: cycleCategory(aspect.cycleBand),
                status: status,
                technicalValue: formatOrb(aspect.orbDegrees),
                fields: fields
            )
        }
        let eventRows = plan.evidence.compactMap { evidence -> TransitActiveRow? in
            guard case let .planetEvent(event) = evidence.fact else { return nil }
            let status: TransitActiveStatus = switch event.kind {
            case .signIngress, .houseIngress: .ingress
            case .stationRetrograde: .retrograde
            case .stationDirect: .direct
            }
            let detailParts = [
                event.kind == .houseIngress
                    ? ConsumerCopy.lifeArea(event.toIndex, language: language)
                    : nil,
                event.timestamp.shortEventDate(language: language, timeZone: timeZone),
            ].compactMap { $0 }
            let fields = [
                TransitTechnicalField(id: "event", label: localized("Event", "事件", language: language), value: activeStatusLabel(status, language: language)),
                TransitTechnicalField(id: "time", label: localized("Time", "时间", language: language), value: transitTimestamp(event.timestamp, language: language, timeZone: timeZone)),
                TransitTechnicalField(id: "target", label: localized("Target", "目标位置", language: language), value: planetEventValue(event, language: language)),
            ]
            return TransitActiveRow(
                id: event.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                symbol: event.body.symbol,
                title: transitActiveEventTitle(event, language: language),
                detail: detailParts.joined(separator: " · "),
                category: cycleCategory(TransitCycleBand(movingID: event.body.rawValue)),
                status: status,
                technicalValue: relativeTransitTime(from: anchorDate, to: event.timestamp, language: language, includesPrefix: false),
                fields: fields
            )
        }
        return aspectRows + eventRows
    }

    static func transitInHouseTitle(_ body: CelestialBody, house: Int, language: AppLanguage) -> String {
        localized(
            "\(bodyName(body, language: .english)) in your \(ordinal(house)) house",
            "\(bodyName(body, language: .simplifiedChinese))落在你的第\(house)宫",
            language: language
        )
    }

    static func transitEnteringHouseTitle(_ body: CelestialBody, house: Int, language: AppLanguage) -> String {
        localized(
            "\(bodyName(body, language: .english)) entering your \(ordinal(house)) house",
            "\(bodyName(body, language: .simplifiedChinese))即将进入你的第\(house)宫",
            language: language
        )
    }

    static func transitActiveAspectTitle(_ aspect: TransitAspectFact, language: AppLanguage) -> String {
        let moving = CelestialBody(rawValue: aspect.movingID).map { bodyName($0, language: language) } ?? aspect.movingID
        let reference = CelestialBody(rawValue: aspect.referenceID).map { bodyName($0, language: language) } ?? aspect.referenceID
        return localized(
            "\(moving) \(aspect.kind.symbol) natal \(reference)",
            "\(moving) \(aspect.kind.symbol) 本命\(reference)",
            language: language
        )
    }

    static func transitActiveEventTitle(_ event: TransitPlanetEventFact, language: AppLanguage) -> String {
        let body = bodyName(event.body, language: language)
        switch event.kind {
        case .signIngress:
            guard let sign = event.toIndex else { return body }
            return localized(
                "\(body) enters \(Zodiac.name(index: sign, language: .english))",
                "\(body)进入\(Zodiac.name(index: sign, language: .simplifiedChinese))",
                language: language
            )
        case .houseIngress:
            guard let house = event.toIndex else { return body }
            return transitEnteringHouseTitle(event.body, house: house, language: language)
        case .stationRetrograde:
            return localized("\(body) stations retrograde", "\(body)开始逆行", language: language)
        case .stationDirect:
            return localized("\(body) stations direct", "\(body)恢复顺行", language: language)
        }
    }

    static func activeAspectTiming(
        status: TransitActiveStatus,
        window: TransitWindowFact?,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String? {
        guard let window else { return nil }
        switch status {
        case .returning:
            let next = window.exactDates.first { $0 >= anchorDate } ?? window.exact
            return localized(
                "Exact again \(next.shortEventDate(language: .english, timeZone: timeZone))",
                "\(next.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))再次精确",
                language: language
            )
        case .separating:
            return localized(
                "Ends \(relativeTransitTime(from: anchorDate, to: window.end, language: .english, includesPrefix: true))",
                "\(relativeTransitTime(from: anchorDate, to: window.end, language: .simplifiedChinese, includesPrefix: true))结束",
                language: language
            )
        case .applying, .exact:
            return localized(
                "Exact \(transitTimestamp(window.exact, language: .english, timeZone: timeZone))",
                "\(transitTimestamp(window.exact, language: .simplifiedChinese, timeZone: timeZone))精确",
                language: language
            )
        case .ingress, .retrograde, .direct:
            return nil
        }
    }

    static func activeStatusLabel(_ status: TransitActiveStatus, language: AppLanguage) -> String {
        switch status {
        case .applying: localized("Applying", "入相", language: language)
        case .returning: localized("Returning", "回返中", language: language)
        case .ingress: localized("Ingress", "进入", language: language)
        case .separating: localized("Separating", "离相", language: language)
        case .exact: localized("Exact", "精确", language: language)
        case .retrograde: localized("Retrograde", "逆行", language: language)
        case .direct: localized("Direct", "顺行", language: language)
        }
    }

    static func transitHouseLabel(_ house: Int, language: AppLanguage) -> String {
        guard (1 ... 12).contains(house) else { return localized("Unknown", "未知", language: language) }
        return localized("\(ordinal(house)) house", "第\(house)宫", language: language)
    }

    static func transitTimestamp(_ date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func transitUntilMonth(_ date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        let month = formatter.string(from: date)
        return localized("until \(month)", "至\(month)", language: language)
    }

    static func relativeTransitTime(
        from start: Date,
        to end: Date,
        language: AppLanguage,
        includesPrefix: Bool
    ) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        let hours = max(1, Int(ceil(seconds / 3_600)))
        let value: String
        if hours < 24 {
            value = localized("\(hours) hours", "\(hours)小时", language: language)
        } else {
            let days = max(1, Int(ceil(seconds / 86_400)))
            if days < 60 {
                value = localized("\(days) days", "\(days)天", language: language)
            } else {
                let months = max(1, Int((Double(days) / 30).rounded()))
                value = localized("\(months) months", "\(months)个月", language: language)
            }
        }
        guard includesPrefix else { return value }
        return localized("in \(value)", "还有\(value)", language: language)
    }

    static func planetEventValue(
        _ event: TransitPlanetEventFact,
        language: AppLanguage
    ) -> String {
        switch event.kind {
        case .signIngress:
            guard let from = event.fromIndex, let to = event.toIndex else { return event.kind.rawValue }
            return "\(Zodiac.name(index: from, language: language)) → \(Zodiac.name(index: to, language: language))"
        case .houseIngress:
            guard let to = event.toIndex else { return event.kind.rawValue }
            return ConsumerCopy.lifeArea(to, language: language)
        case .stationRetrograde:
            return motionLabel(retrograde: true, language: language)
        case .stationDirect:
            return motionLabel(retrograde: false, language: language)
        }
    }

    static func plannedAspectFacts(
        _ plan: CardEvidencePlan,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let windows = plan.evidence.compactMap { evidence -> TransitWindowFact? in
            guard case let .window(window) = evidence.fact else { return nil }
            return window
        }
        return plan.evidence.compactMap { evidence -> InsightFact? in
            guard case let .aspect(aspect) = evidence.fact else { return nil }
            let linkedWindows = windows.filter { $0.sourceAspectFactID == aspect.factID }
            let sourceFactIDs = Array(Set(
                evidence.fact.sourceFactIDs + linkedWindows.flatMap {
                    [$0.factID] + [$0.sourceAspectFactID].compactMap { $0 }
                }
            )).sorted()
            let exactDates = linkedWindows
                .flatMap(\.exactDates)
                .sorted()
                .map { $0.shortEventDate(language: language, timeZone: timeZone) }
            let notes = [
                (1 ... 12).contains(aspect.natalHouse)
                    ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                    : nil,
                exactDates.isEmpty ? nil : exactDates.joined(separator: " · "),
            ].compactMap { $0 }
            return fact(
                transitAspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                stableID: aspect.factID,
                sourceFactIDs: sourceFactIDs,
                note: notes.isEmpty ? nil : notes.joined(separator: " · "),
                progress: aspect.strength,
                symbol: aspect.kind.symbol,
                category: cycleCategory(aspect.cycleBand)
            )
        }
    }

    static func transitAspectTitle(
        _ aspect: TransitAspectFact,
        language: AppLanguage
    ) -> String {
        let moving = CelestialBody(rawValue: aspect.movingID)
            .map { bodyName($0, language: language) } ?? aspect.movingID
        let reference = CelestialBody(rawValue: aspect.referenceID)
            .map { bodyName($0, language: language) } ?? aspect.referenceID
        return "\(moving) \(aspect.kind.symbol) \(reference)"
    }

    static func transitWindowTitle(
        _ window: TransitWindowFact,
        language: AppLanguage
    ) -> String {
        let moving = CelestialBody(rawValue: window.movingID)
            .map { bodyName($0, language: language) } ?? window.movingID
        let reference = CelestialBody(rawValue: window.referenceID)
            .map { bodyName($0, language: language) } ?? window.referenceID
        return "\(moving) \(window.kind.symbol) \(reference)"
    }

    static func cycleDisplay(
        _ evidence: TransitPlannedEvidence?,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> TransitCyclePresentation? {
        guard let evidence else { return nil }
        switch evidence.fact {
        case let .window(window):
            return TransitCyclePresentation(
                roleID: evidence.role.rawValue,
                fallbackTitle: transitWindowTitle(window, language: language),
                tags: cycleWindowTags(
                    window,
                    role: evidence.role,
                    anchorDate: anchorDate,
                    language: language,
                    timeZone: timeZone
                ),
                sourceFactIDs: evidence.fact.sourceFactIDs
            )
        case let .aspect(aspect):
            return TransitCyclePresentation(
                roleID: evidence.role.rawValue,
                fallbackTitle: transitAspectTitle(aspect, language: language),
                tags: [
                    phaseLabel(aspect.phase, language: language),
                    (1 ... 12).contains(aspect.natalHouse)
                        ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                        : nil,
                ].compactMap { $0 },
                sourceFactIDs: evidence.fact.sourceFactIDs
            )
        default:
            return nil
        }
    }

    static func cycleWindowTags(
        _ window: TransitWindowFact,
        role: TransitEvidenceRole,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [String] {
        let area = (1 ... 12).contains(window.natalHouse)
            ? ConsumerCopy.lifeArea(window.natalHouse, language: language)
            : nil
        switch role {
        case .longCycle:
            let futureExact = window.exactDates.first { $0 >= anchorDate }
            let exactLabel = futureExact.map { date in
                if window.returning || window.passIndex > 1 {
                    return localized(
                        "Exact again \(date.shortEventDate(language: .english, timeZone: timeZone))",
                        "\(date.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))再次精确",
                        language: language
                    )
                }
                return localized(
                    "Exact \(date.shortEventDate(language: .english, timeZone: timeZone))",
                    "\(date.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))精确",
                    language: language
                )
            }
            return [
                cycleDateRange(window.start, window.end, anchorDate: anchorDate, language: language, timeZone: timeZone),
                exactLabel,
                area,
            ].compactMap { $0 }
        case .currentCycle:
            return [
                cycleDuration(window.start, window.end, language: language),
                phaseLabel(cyclePhase(window, anchorDate: anchorDate), language: language),
                area,
            ].compactMap { $0 }
        case .dailyCycle:
            return [
                cyclePeak(window, anchorDate: anchorDate, language: language, timeZone: timeZone),
                cycleEnd(window.end, anchorDate: anchorDate, language: language, timeZone: timeZone),
                area,
            ].compactMap { $0 }
        default:
            return [area].compactMap { $0 }
        }
    }

    static func cyclePhase(_ window: TransitWindowFact, anchorDate: Date) -> AspectPhase {
        let closestExact = window.exactDates.min {
            abs($0.timeIntervalSince(anchorDate)) < abs($1.timeIntervalSince(anchorDate))
        } ?? window.exact
        if abs(closestExact.timeIntervalSince(anchorDate)) < 3_600 { return .exact }
        return closestExact > anchorDate ? .applying : .separating
    }

    static func cycleDuration(_ start: Date, _ end: Date, language: AppLanguage) -> String {
        let days = max(1, Int(ceil(end.timeIntervalSince(start) / 86_400)))
        if days < 14 {
            return localized("\(days) days", "\(days)天", language: language)
        }
        if days < 60 {
            let weeks = max(1, Int((Double(days) / 7).rounded()))
            return localized("\(weeks) weeks", "\(weeks)周", language: language)
        }
        let months = max(2, Int((Double(days) / 30).rounded()))
        return localized("\(months) months", "\(months)个月", language: language)
    }

    static func cyclePeak(
        _ window: TransitWindowFact,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        let peak = window.exactDates.min {
            abs($0.timeIntervalSince(anchorDate)) < abs($1.timeIntervalSince(anchorDate))
        } ?? window.exact
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: peak)
        return localized("Peaks \(time)", "\(time)达到峰值", language: language)
    }

    static func cycleEnd(
        _ end: Date,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let endDay = calendar.startOfDay(for: end)
        let dayDistance = calendar.dateComponents([.day], from: anchorDay, to: endDay).day ?? 0
        if dayDistance == 0 {
            return localized("Ends today", "今天结束", language: language)
        }
        if dayDistance == 1 {
            return localized("Ends tomorrow", "明天结束", language: language)
        }
        return localized(
            "Ends \(end.shortEventDate(language: .english, timeZone: timeZone))",
            "\(end.shortEventDate(language: .simplifiedChinese, timeZone: timeZone))结束",
            language: language
        )
    }

    static func cycleDateRange(
        _ start: Date,
        _ end: Date,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let anchorYear = calendar.component(.year, from: anchorDate)
        let includesOtherYear = calendar.component(.year, from: start) != anchorYear
            || calendar.component(.year, from: end) != anchorYear
        guard includesOtherYear else {
            return start.shortEventRange(to: end, language: language, timeZone: timeZone)
        }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }

    static func cycleCategory(_ band: TransitCycleBand) -> String {
        switch band {
        case .longTerm: "long-term"
        case .current: "current"
        case .daily: "daily"
        }
    }

    // MARK: - Secondary (6)
}
