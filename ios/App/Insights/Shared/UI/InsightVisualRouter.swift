import SwiftUI

struct InsightVisualView: View {
    let visual: InsightVisual
    let facts: [InsightFact]
    let text: CardTextModel?
    let language: AppLanguage
    @State var showAllAreas = false
    @State var showAllActiveTransits = false
    @State var transitFilter: String? = nil
    @State var selectedCycleIndex = 0
    @State var transitDetailDrawer: TransitDetailDrawer?
    @State var selectedSynastryPerspective = 0
    @State var synastryFactDrawer: InsightFact?

    var body: some View {
        Group {
            if facts.isEmpty {
                emptyState
            } else {
                switch visual {
            case .natalCore: orbitCircle
            case .rankedThemes: rankedThemes
            case let .strengthOrbit(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .blindSpot: factGrid(columns: 2)
            case .growthPath: pathFlow(title: localized("Growth path", "成长路径", language: language))
            case let .skyOverview(phase, activity, cycles): skyOverview(phase: phase, activity: activity, cycles: cycles)
            case .themeCards: themeCards
            case .needsCard: needsCard
            case .eventTimeline: eventList
            case .dateEvents: dateEventList
            case let .structureMap(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .domainBars(values): domainBars(values)
            case .observation: factRows
            case .evolution: evolution
            case .planetTable: planetTable
            case let .activityGauge(value, supportive, adjustment):
                activityGauge(value: value, supportive: supportive, adjustment: adjustment)
            case let .transitOverview(intensity, rhythm):
                transitOverview(intensity: intensity, rhythm: rhythm)
            case .gantt: gantt
            case let .transitTimeline(entries, calendar, anchorDate, initialRangeDays, timeZoneIdentifier):
                TransitTimelineView(
                    entries: entries,
                    calendarFacts: calendar,
                    anchorDate: anchorDate,
                    initialRangeDays: initialRangeDays,
                    timeZoneIdentifier: timeZoneIdentifier,
                    language: language
                )
            case let .balanceRing(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .houseRadar(values): houseRadar(values)
            case .actionGuidance: factRows
            case .arcTimeline: factRows
            case .doubleRing: placementRows
            case let .calendar(values): calendar(values)
            case let .progressedStage(phase, moonProgress, sunProgress):
                progressedStage(phase: phase, moonProgress: moonProgress, sunProgress: sunProgress)
            case let .progressedThemes(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .turningTimeline: factRows
            case .comparison: factRows
            case let .signatureTrio(ruler, dominant, orientation):
                metricTrio(ruler: ruler, dominant: dominant, orientation: orientation)
            case .placementList: placementRows
            case .aspectList: aspectRows
            case let .storyWeave(expanding, structuring, result): storyWeave(expanding: expanding, structuring: structuring, result: result)
            case let .cycleTabs(long, current, daily): cycleTabs(long: long, current: current, daily: daily)
            case let .transitPlanetPaths(rows): transitPlanetPaths(rows)
            case let .transitLifeAreas(rows): transitLifeAreas(rows)
            case let .transitActiveRows(rows): transitActiveRows(rows)
            case .positionRows: positionRows
            case .areaRows: areaRows
            case let .phaseDial(phase, illumination): phaseDial(phase: phase, illumination: illumination)
            case .motionList: positionRows
            case .elementRows: elementRows
            case let .stageFlow(old, transition, emerging):
                stageFlow(old: old, transition: transition, emerging: emerging)
            case let .moonProgress(progress): moonProgressRing(progress: progress)
            case let .identityCompare(natal, progressed):
                compareStrip(natal: natal, progressed: progressed)
            case .turningRows: factRows
            case .yearOrbit: yearOrbit
            case .anchorGrid: factGrid(columns: 2)
            case let .dualInsight(opening, demand, openingLabel, demandLabel): dualInsight(opening: opening, demand: demand, openingLabel: openingLabel, demandLabel: demandLabel)
            case let .edgeDual(opening, demand): edgeDual(opening: opening, demand: demand)
            case .quarterTabs: quarterTabs
            case .overlayCompare: compareStrip(natal: localized("Natal", "本命", language: language), progressed: localized("This year", "今年", language: language))
            case let .natalOverlay(firstLabel, firstValue, secondLabel, secondValue):
                natalOverlay(firstLabel: firstLabel, firstValue: firstValue, secondLabel: secondLabel, secondValue: secondValue)
            case let .bondOrbit(presentation): bondOrbit(presentation)
            case let .perspectiveTabs(presentation): perspectiveTabs(presentation)
            case .connectionGrid: connectionGrid
            case .pathFlow: pathFlow(title: localized("How it flows", "流动方式", language: language))
            case let .synastryConnectionGrid(kind): synastryConnectionGrid(kind)
            case .synastryPathFlow: synastryPathFlow
            case .synastryChemistry: synastryChemistry
            case let .synastryHouseOverlayRows(pair): synastryHouseOverlayRows(pair)
            case let .synastryInterAspectRows(pair): synastryInterAspectRows(pair)
                }
            }
        }
        .sheet(item: $transitDetailDrawer) { drawer in
            transitDrawer(drawer)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.panel)
        }
        .sheet(item: $synastryFactDrawer) { fact in
            SynastryFactDetailSheet(fact: fact, language: language)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.panel)
        }
    }


    var emptyState: some View {
        Label(
            localized(
                "Not enough calculated facts for this card",
                "当前计算事实不足，暂不展示这张卡片的内容",
                language: language
            ),
            systemImage: "circle.dashed"
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppTheme.muted)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(AppTheme.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    func factGrid(columns: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columns))
        return LazyVGrid(columns: grid, spacing: 10) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        if let symbol = fact.symbol {
                            Text(symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                        }
                        Text(fact.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Text(fact.value)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    var factRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: 10) {
                    if let symbol = fact.symbol {
                        Text(symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 26, height: 26)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.muted)
                        Text(fact.value).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    if let progress = fact.progress {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func ringMetric(supportive: Int, challenging: Int, neutral: Int) -> some View {
        let total = max(1, supportive + challenging + neutral)
        let support = Double(supportive) / Double(total)
        let challenge = Double(challenging) / Double(total)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppTheme.panelRaised, lineWidth: 12)
                Circle().trim(from: 0, to: support)
                    .stroke(AppTheme.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().trim(from: support, to: support + challenge)
                    .stroke(AppTheme.coral, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(total)").font(.system(size: 20, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("contacts", "连接", language: language)).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(supportive)", localized("Support", "支持", language: language), .supportive)
                metric("\(challenging)", localized("Pressure", "压力", language: language), .challenging)
                metric("\(neutral)", localized("Neutral", "中性", language: language), .transition)
            }
            .frame(maxWidth: .infinity)
        }
    }

    func metric(_ value: String, _ title: String, _ tone: InsightTone) -> some View {
        HStack {
            Text(value).font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.tone(tone))
            Text(title).font(.system(size: 11)).foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    func trioCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9)).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // prototype .position-row: glyph + title + desc + state chip

    var positionRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(fact.value).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note, !note.isEmpty {
                            Text(note).font(.system(size: 9)).foregroundStyle(AppTheme.muted)
                        }
                    }
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var aspectRows: some View {
        let hasCategories = facts.contains { $0.category != nil }
        let filtered = transitFilter == nil ? facts : facts.filter { $0.category == transitFilter }
        return VStack(spacing: 9) {
            if hasCategories {
                HStack(spacing: 6) {
                    aspectFilterChip(nil, localized("All", "全部", language: language))
                    aspectFilterChip("long-term", localized("Long-term", "长期", language: language))
                    aspectFilterChip("current", localized("Current", "当前", language: language))
                    aspectFilterChip("daily", localized("Daily", "每日", language: language))
                    Spacer()
                }
            }
            ForEach(Array(filtered.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "⌗")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 26, height: 26)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(technicalTag(fact.emphasis)).font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(AppTheme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Area / element rows (prototype .area-row with % bar)

    var areaRows: some View {
        let shown = showAllAreas ? Array(facts.prefix(12)) : Array(facts.prefix(4))
        return VStack(spacing: 11) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.line.opacity(0.6))
                                Capsule()
                                    .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.85), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * max(0.02, min(1, progress)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            if facts.count > 4 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllAreas.toggle()
                    }
                } label: {
                    Text(showAllAreas
                         ? localized("Show fewer areas", "收起领域", language: language)
                         : LocalizedFormatters.viewAllAreas(facts.count, language: language))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
            Text(localized("Activity reflects the current signals, not a fortune score.", "这里反映当前的活跃程度，不是运势分数。", language: language))
                .font(.system(size: 9.5))
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 2)
        }
    }

    var elementRows: some View {
        VStack(spacing: 11) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 9) {
                    Text(fact.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text).frame(width: 44, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6))
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.85), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0.02, min(1, fact.progress ?? 0)))
                        }
                    }
                    .frame(height: 6)
                    Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted).frame(width: 44, alignment: .trailing)
                }
            }
            if facts.count > 4 {
                HStack(spacing: 6) {
                    ForEach(Array(facts.dropFirst(4).prefix(3).enumerated()), id: \.offset) { _, fact in
                        Text("\(fact.label)：\(fact.value)")
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.violet.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
                            .foregroundStyle(AppTheme.text.opacity(0.9))
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Moon dial (prototype .progress-moon)

    func dualInsight(opening: String, demand: String, openingLabel: String, demandLabel: String) -> some View {
        HStack(spacing: 9) {
            VStack(spacing: 5) {
                Text(openingLabel).font(.system(size: 8, weight: .bold)).foregroundStyle(AppTheme.mint)
                Text(opening).font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 5) {
                Text(demandLabel).font(.system(size: 8, weight: .bold)).foregroundStyle(AppTheme.coral)
                Text(demand).font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    var connectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.label).font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.muted)
                    Text(fact.value).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(.system(size: 9.5)).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func pathFlow(title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(AppTheme.muted)
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                    VStack(spacing: 4) {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: Circle())
                        Text(fact.label).font(.system(size: 9.5, weight: .medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    if index < min(3, facts.count) - 1 {
                        Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
    }

    func technicalTag(_ tone: InsightTone) -> String {
        switch tone {
        case .supportive: localized("Supportive pattern", "支持性结构", language: language)
        case .challenging: localized("Core tension", "核心张力", language: language)
        case .transition, .neutral: localized("Relational pattern", "关系结构", language: language)
        }
    }
}
