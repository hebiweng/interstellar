import SwiftUI

// MARK: - Card container (prototype .card surface)

struct InsightCardView: View {
    let card: InsightCardModel
    let language: AppLanguage
    var prototypeTransitStyle = false
    var externalHeaderStyle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !externalHeaderStyle,
               (!isPrototypeTransitCard || card.id == "current-story"),
               let kicker = cardKicker(card.id, language: language),
               !kicker.isEmpty
            {
                Text(kicker.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.violet)
            }
            if !externalHeaderStyle {
                Text(card.title.isEmpty ? card.summary : card.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsGenericCopy, let text = card.text {
                if let headline = text.headline, !headline.isEmpty, headline != card.title {
                    Text(headline)
                        .font(.system(size: card.id == "current-story" ? 21 : 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = text.body, !body.isEmpty, body != text.headline {
                    Text(body)
                        .font(.system(size: card.id == "current-story" ? 11 : 11.5, weight: .medium))
                        .foregroundStyle(card.id == "current-story" ? AppTheme.muted : AppTheme.text.opacity(0.95))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.id != "current-story",
                   let secondary = text.secondaryBody,
                   !secondary.isEmpty
                {
                    Text(secondary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if showsGenericCopy,
                      !card.facts.isEmpty,
                      !card.summary.isEmpty,
                      card.summary != card.title
            {
                Text(card.summary)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.95))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if card.id == "current-story",
               let roleTexts = card.text?.roleTexts,
               !roleTexts.isEmpty
            {
                storyRoleWeave(roleTexts, result: card.text?.secondaryBody)
            } else {
                InsightVisualView(visual: card.visual, facts: card.facts, text: card.text, language: language)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [AppTheme.panelRaised, AppTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }

    private var isPrototypeTransitCard: Bool {
        prototypeTransitStyle && TransitContentPlan.cardIDs.contains(card.id)
    }

    private var showsGenericCopy: Bool {
        !isPrototypeTransitCard || card.id == "current-story"
    }

    private func storyRoleWeave(_ roleTexts: [CardRoleText], result: String?) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(roleTexts.enumerated()), id: \.offset) { index, roleText in
                if index > 0 {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                }
                HStack(alignment: .top, spacing: 10) {
                    Text(storyRoleLabel(roleText.roleID))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.tone(storyRoleTone(roleText.roleID)))
                    Text(roleText.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                }
                .padding(12)
                .background(
                    AppTheme.tone(storyRoleTone(roleText.roleID)).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            if let result, !result.isEmpty {
                Text(result)
                    .font(.system(size: 10.5))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text.opacity(0.95))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func storyRoleLabel(_ roleID: String) -> String {
        switch roleID {
        case TransitStorySignalRoleID.expanding.rawValue:
            localized("EXPANDING", "扩展", language: language)
        case TransitStorySignalRoleID.structuring.rawValue:
            localized("STRUCTURING", "构建", language: language)
        case TransitStorySignalRoleID.disrupting.rawValue:
            localized("DISRUPTING", "重塑", language: language)
        case TransitStorySignalRoleID.stabilizing.rawValue:
            localized("STABILIZING", "稳固", language: language)
        default:
            localized("SUPPORTING", "助力", language: language)
        }
    }

    private func storyRoleTone(_ roleID: String) -> InsightTone {
        switch roleID {
        case TransitStorySignalRoleID.disrupting.rawValue:
            .challenging
        case TransitStorySignalRoleID.structuring.rawValue,
             TransitStorySignalRoleID.stabilizing.rawValue:
            .transition
        default:
            .supportive
        }
    }
}

func cardKicker(_ id: String, language: AppLanguage) -> String? {
    switch id {
    case "sky-overview": return localized("card.sky-overview.eyebrow", default: "SKY NOW", chinese: "当前天空", language: language)
    case "moon-now": return localized("MOON NOW", "此刻月亮", language: language)
    case "aspect-pattern": return localized("ASPECT PATTERN", "连接结构", language: language)
    case "planetary-motion": return localized("PLANETARY MOTION", "行星运动", language: language)
    case "sign-changes": return localized("SIGN CHANGES", "换座", language: language)
    case "element-climate": return localized("ELEMENT CLIMATE", "元素气候", language: language)
    case "upcoming-7-days": return localized("UPCOMING 7 DAYS", "未来七天", language: language)
    case "natal-interpretation": return localized("CORE PERSONALITY", "核心性格", language: language)
    case "emotional-needs": return localized("EMOTIONAL NEEDS", "情绪需要", language: language)
    case "love-connection": return localized("LOVE & CONNECTION", "爱与连接", language: language)
    case "career-direction": return localized("PUBLIC DIRECTION", "公共方向", language: language)
    case "strengths-growth": return localized("YOUR EDGES", "你的优势与成长面", language: language)
    case "element-balance": return localized("TEMPERAMENT", "气质", language: language)
    case "house-emphasis": return localized("CONCENTRATION", "侧重", language: language)
    case "chart-signature": return localized("SIGNATURE", "签名", language: language)
    case "planet-placements": return localized("PLACEMENTS", "落座", language: language)
    case "key-aspects": return localized("KEY ASPECTS", "关键连接", language: language)
    case "current-story": return localized("THE BIG PICTURE", "大局", language: language)
    case "current-cycles": return localized("CYCLES", "周期", language: language)
    case "transit-timeline": return localized("TIMELINE", "时间线", language: language)
    case "planet-paths": return localized("PLANET PATHS", "行星路径", language: language)
    case "life-areas": return localized("LIFE AREAS", "生活领域", language: language)
    case "active-transits": return localized("ACTIVE TRANSITS", "进行中的变化", language: language)
    case "developmental-chapter": return localized("CURRENT DEVELOPMENT", "当前发展", language: language)
    case "progressed-moon": return localized("PROGRESSED MOON", "长期月亮", language: language)
    case "identity-development": return localized("IDENTITY", "身份", language: language)
    case "turning-points": return localized("TURNING POINTS", "转折点", language: language)
    case "areas-maturing": return localized("MATURING", "成熟领域", language: language)
    case "timeline": return localized("24-MONTH TIMELINE", "长期时间线", language: language)
    case "year-theme": return localized("YEAR THEME", "年度主题", language: language)
    case "year-anchors": return localized("YEAR ANCHORS", "年度锚点", language: language)
    case "priority-areas": return localized("PRIORITY AREAS", "优先领域", language: language)
    case "year-dynamics": return localized("YEAR DYNAMICS", "年度动态", language: language)
    case "year-timeline": return localized("YEAR TIMELINE", "年度时间线", language: language)
    case "natal-overlay": return localized("NATAL OVERLAY", "与本命叠加", language: language)
    case "year-aspects": return localized("YEAR ASPECTS", "年度连接", language: language)
    case "relationship-overview": return localized("THE BOND", "这段关系", language: language)
    case "perspectives": return localized("PERSPECTIVES", "彼此的体验", language: language)
    case "emotional-connection": return localized("EMOTIONAL CONNECTION", "情感连接", language: language)
    case "communication": return localized("COMMUNICATION", "沟通", language: language)
    case "chemistry": return localized("CHEMISTRY", "化学反应", language: language)
    case "commitment": return localized("COMMITMENT", "承诺", language: language)
    case "house-overlays": return localized("HOUSE OVERLAYS", "落宫叠加", language: language)
    case "key-inter-aspects": return localized("KEY INTER-ASPECTS", "主要相互连接", language: language)
    default: return nil
    }
}

// MARK: - Shared prototype primitives

private struct Kicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(AppTheme.violet)
    }
}

enum InsightBadgeTone {
    case purple
    case warm
    case good
}

struct InsightBadge: View {
    let text: String
    var tone: InsightBadgeTone = .purple

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch tone {
        case .purple: Color(red: 0.85, green: 0.82, blue: 1.0)
        case .warm: AppTheme.amber
        case .good: AppTheme.mint
        }
    }

    private var background: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.13)
        case .warm: AppTheme.amber.opacity(0.11)
        case .good: AppTheme.mint.opacity(0.11)
        }
    }

    private var border: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.22)
        case .warm: AppTheme.amber.opacity(0.18)
        case .good: AppTheme.mint.opacity(0.18)
        }
    }
}

struct TagChip: View {
    let text: String
    var tone: InsightTone = .neutral
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.tone(tone).opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.tone(tone).opacity(0.25), lineWidth: 1))
            .foregroundStyle(AppTheme.tone(tone).mix(with: AppTheme.text, by: 0.35))
    }
}

private extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let lhs = UIColor(self)
        let rhs = UIColor(other)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return Color(
            red: Double(lr * (1 - amount) + rr * amount),
            green: Double(lg * (1 - amount) + rg * amount),
            blue: Double(lb * (1 - amount) + rb * amount),
            opacity: Double(la * (1 - amount) + ra * amount)
        )
    }
}

private struct SectionSub: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.muted)
    }
}

// MARK: - Visual renderer

private enum TransitDetailDrawer: Identifiable {
    case planetPaths([TransitPlanetPathRow])
    case activeTransit(TransitActiveRow)

    var id: String {
        switch self {
        case .planetPaths: "planet-paths"
        case let .activeTransit(row): "active-\(row.id)"
        }
    }
}

private struct InsightVisualView: View {
    let visual: InsightVisual
    let facts: [InsightFact]
    let text: CardTextModel?
    let language: AppLanguage
    @State private var showAllAreas = false
    @State private var showAllActiveTransits = false
    @State private var transitFilter: String? = nil
    @State private var selectedCycleIndex = 0
    @State private var transitDetailDrawer: TransitDetailDrawer?

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
            case .bondOrbit: bondOrbit
            case .perspectiveTabs: perspectiveTabs
            case .connectionGrid: connectionGrid
            case .pathFlow: pathFlow(title: localized("How it flows", "流动方式", language: language))
                case .houseOverlayRows: houseOverlayRows
                }
            }
        }
        .sheet(item: $transitDetailDrawer) { drawer in
            transitDrawer(drawer)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.panel)
        }
    }

    private var emptyState: some View {
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

    private var orbitCircle: some View {
        let items = facts.prefix(3)
        let symbols = ["☉", "☽", "↑"]
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.3), lineWidth: 1).frame(width: 96, height: 96)
                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    let angle = Double(index) / 3 * 2 * Double.pi - Double.pi / 2
                    let radius = 44.0
                    Text(symbols[min(index, 2)])
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.tone(items[index].emphasis))
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
                Circle().fill(AppTheme.violet.opacity(0.12)).frame(width: 34, height: 34)
                Text("✶").font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, fact in
                    HStack(spacing: 6) {
                        Text(fact.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 40, alignment: .leading)
                        Text(fact.value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero-like structures

    private func factGrid(columns: Int) -> some View {
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

    private var factRows: some View {
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

    private var rankedThemes: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.violet)
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                    if let note = fact.note {
                        Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }

    private func ringMetric(supportive: Int, challenging: Int, neutral: Int) -> some View {
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

    private func metric(_ value: String, _ title: String, _ tone: InsightTone) -> some View {
        HStack {
            Text(value).font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.tone(tone))
            Text(title).font(.system(size: 11)).foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func skyOverview(phase: Double, activity: Int, cycles: [Double]) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10 + Double(activity) / 400))
                    .frame(width: 74, height: 74)
                    .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, phase / 360))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(phase))°").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.text)
                    Text(localized("phase", "月相", language: language)).font(.system(size: 9)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(activity)%", localized("Activity", "活跃度", language: language), .transition)
                metric("\(Int((cycles.first ?? 0) * 100))%", localized("Long cycle", "长期周期", language: language), .supportive)
                metric("\(Int((cycles.last ?? 0) * 100))%", localized("Short cycle", "短期周期", language: language), .neutral)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var themeCards: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "✦").foregroundStyle(AppTheme.tone(fact.emphasis))
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                    if let note = fact.note {
                        Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(12)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    // MARK: - Timeline / event list (prototype .time-event + rail + now-line)

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                HStack(alignment: .top, spacing: 12) {
                    Text(fact.label)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 42, alignment: .leading)
                    VStack(spacing: 0) {
                        Circle()
                            .fill(AppTheme.tone(fact.emphasis))
                            .frame(width: 8, height: 8)
                        if index < min(4, facts.count) - 1 {
                            Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 24)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.value).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var dateEventList: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 12) {
                    let parts = dateParts(fact.label)
                    VStack(spacing: 1) {
                        Text(parts.0)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.muted)
                        Text(parts.1)
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(width: 54)
                    .padding(.vertical, 8)
                    .background(AppTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fact.value)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = fact.note {
                            Text(note)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(AppTheme.violet)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 4))
                }
                .padding(14)
                .cardSurface()
            }
        }
    }

    private func dateParts(_ label: String) -> (String, String) {
        let parts = label.split(separator: " ")
        if parts.count == 2 {
            return (String(parts[0]).uppercased(), String(parts[1]))
        }
        if let monthEnd = label.range(of: "月"), let dayStart = label.range(of: "日") {
            let month = String(label[..<monthEnd.upperBound])
            let day = String(label[monthEnd.upperBound..<dayStart.lowerBound])
            return (month, day + "日")
        }
        return (label, "")
    }

    // MARK: - Domain bars

    private func domainBars(_ values: [Double]) -> some View {
        let labels = language == .english
            ? ["Information", "Relationships", "Action", "Institutions", "Technology", "Resources", "Public mood", "Culture"]
            : ["信息传播", "关系合作", "行动竞争", "制度结构", "技术创新", "资源经济", "公共情绪", "文化价值"]
        return VStack(spacing: 8) {
            ForEach(Array(zip(labels, values).enumerated()), id: \.offset) { index, item in
                HStack(spacing: 9) {
                    Text(item.0).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted).frame(width: 76, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6))
                            Capsule().fill(AppTheme.violet.opacity(0.85))
                                .frame(width: proxy.size.width * max(0.02, min(1, item.1)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(Int(item.1 * 100))%").font(.system(size: 10).monospacedDigit()).foregroundStyle(AppTheme.muted)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    private var evolution: some View {
        factRows
    }

    private var planetTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(10).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 9) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 24)
                    Text(fact.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text)
                    Spacer()
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                    if let note = fact.note {
                        Text(note).font(.system(size: 9.5)).foregroundStyle(AppTheme.muted.opacity(0.8))
                            .frame(width: 84, alignment: .trailing)
                    }
                }
                .padding(.vertical, 7)
                Divider().overlay(AppTheme.line.opacity(0.6))
            }
        }
    }

    private func activityGauge(value: Int, supportive: Int, adjustment: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Path { path in
                    path.addArc(center: CGPoint(x: 110, y: 78), radius: 62, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(AppTheme.panelRaised, lineWidth: 12)
                Path { path in
                    path.addArc(center: CGPoint(x: 110, y: 78), radius: 62, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * Double(value) / 100), clockwise: false)
                }
                .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(180), anchor: .center)
                VStack(spacing: 2) {
                    Text("\(value)").font(.system(size: 22, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("activity", "活跃度", language: language)).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                }
                .offset(y: 8)
            }
            .frame(height: 96)
            HStack(spacing: 12) {
                metric("\(supportive)", localized("Push", "推动", language: language), .supportive)
                metric("\(adjustment)", localized("Adjust", "调整", language: language), .challenging)
            }
        }
    }

    private func transitOverview(intensity: Int, rhythm: [Double]) -> some View {
        VStack(spacing: 10) {
            metric("\(intensity)%", localized("Intensity", "强度", language: language), .transition)
            rhythmWave(rhythm)
        }
    }

    private func rhythmWave(_ values: [Double]) -> some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            var path = Path()
            for index in values.indices {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - max(0, min(1, values[index])))
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .linearGradient(Gradient(colors: [AppTheme.blue, AppTheme.violet]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 54)
    }

    // MARK: - Gantt (prototype .gantt-row: head + track with bar/marker)

    private var gantt: some View {
        VStack(spacing: 12) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(fact.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0.12, min(0.88, fact.progress ?? 0.5)), height: 6)
                            // Main exact point (white + violet ring)
                            Circle()
                                .fill(Color.white)
                                .overlay(Circle().stroke(AppTheme.violet, lineWidth: 2.5))
                                .frame(width: 9, height: 9)
                                .offset(x: proxy.size.width * max(0.12, min(0.88, fact.progress ?? 0.5)) - 4.5)
                            // Repeating exact points (dark + violet ring)
                            ForEach(Array((fact.markers ?? []).enumerated()), id: \.offset) { _, marker in
                                if marker != (fact.progress ?? 0.5) {
                                    Circle()
                                        .fill(AppTheme.panel)
                                        .overlay(Circle().stroke(AppTheme.violet, lineWidth: 2))
                                        .frame(width: 7, height: 7)
                                        .offset(x: proxy.size.width * max(0.12, min(0.88, marker)) - 3.5)
                                }
                            }
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
    }

    private func houseRadar(_ values: [Double]) -> some View {
        Canvas { context, size in
            let count = values.count
            guard count > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.4
            for level in 1 ... 3 {
                context.stroke(polygon(center: center, radius: radius * Double(level) / 3, count: count), with: .color(AppTheme.line), lineWidth: 0.8)
            }
            var data = Path()
            for index in 0 ..< count {
                let value = max(0, min(1, values[index]))
                let point = polygonPoint(center: center, radius: radius * value, index: index, count: count)
                index == 0 ? data.move(to: point) : data.addLine(to: point)
            }
            data.closeSubpath()
            context.fill(data, with: .color(AppTheme.violet.opacity(0.2)))
            context.stroke(data, with: .color(AppTheme.violet), lineWidth: 1.4)
        }
        .frame(height: 150)
        .overlay(alignment: .bottom) {
            HStack {
                ForEach(Array(values.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - 7-day calendar (prototype heat grid)

    private func calendar(_ values: [Int]) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 3) {
                        Text(shortDay(index + 1)).font(.system(size: 9.5)).foregroundStyle(AppTheme.muted)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.tone(value > 66 ? .challenging : value > 35 ? .transition : .neutral).opacity(0.16 + Double(value) / 100 * 0.7))
                            .frame(height: 46)
                            .overlay(
                                Text("\(value)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(localized("This week's intensity", "本周变化强度", language: language))
                .font(.system(size: 9.5))
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func shortDay(_ index: Int) -> String {
        let days = language == .english ? ["M", "T", "W", "T", "F", "S", "S"] : ["一", "二", "三", "四", "五", "六", "日"]
        return days[min(max(0, index - 1), 6)]
    }

    private func progressedStage(phase: Double, moonProgress: Double, sunProgress: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, phase / 360))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(progressedPhaseName(phase)).font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.text)
                    Text("\(Int(phase))°").font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 108, height: 108)
            progressTrack(label: localized("Moon", "月亮", language: language), value: moonProgress, tone: .transition)
            progressTrack(label: localized("Sun", "太阳", language: language), value: sunProgress, tone: .supportive)
        }
    }

    private func progressTrack(label: String, value: Double, tone: InsightTone) -> some View {
        HStack(spacing: 9) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(AppTheme.muted).frame(width: 44, alignment: .leading)
            ProgressView(value: max(0, min(1, value))).tint(AppTheme.tone(tone))
            Text("\(Int(value * 30))°/30").font(.system(size: 10).monospacedDigit()).foregroundStyle(AppTheme.muted).frame(width: 52, alignment: .trailing)
        }
    }

    private func progressedPhaseName(_ angle: Double) -> String {
        switch angle {
        case 0 ..< 90: localized("New phase", "新月阶段", language: language)
        case 90 ..< 180: localized("Building phase", "上弦阶段", language: language)
        case 180 ..< 270: localized("Review phase", "满月阶段", language: language)
        default: localized("Integration phase", "下弦阶段", language: language)
        }
    }

    // MARK: - Signature trio / placements / aspects

    private func metricTrio(ruler: String, dominant: String, orientation: String) -> some View {
        HStack(spacing: 9) {
            trioCell(label: localized("Chart ruler", "命主星", language: language), value: ruler)
            trioCell(label: localized("Dominant", "主导星体", language: language), value: dominant)
            trioCell(label: localized("Orientation", "总体取向", language: language), value: orientation)
        }
    }

    private func trioCell(label: String, value: String) -> some View {
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
    private var placementRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(8).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    if let category = fact.category {
                        Text(category)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(AppTheme.violet)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.violet.opacity(0.1), in: Capsule())
                    }
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                }
                .padding(.vertical, 8)
                Divider().overlay(AppTheme.line.opacity(0.6))
            }
        }
    }

    private var positionRows: some View {
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

    private func transitPlanetPaths(_ rows: [TransitPlanetPathRow]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("Transiting houses & motion", "行运宫位与运动状态", language: language))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized(
                        "This separates planetary location from aspect interpretation.",
                        "这里将行星位置与相位解读分开呈现。",
                        language: language
                    ))
                    .font(.system(size: 9.5))
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 8)
                Button {
                    transitDetailDrawer = .planetPaths(rows)
                } label: {
                    Text(localized("How it works", "原理说明", language: language))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(minHeight: 44, alignment: .topTrailing)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-planet-paths-how-it-works")
            }
            .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(AppTheme.line)
                }
                HStack(spacing: 10) {
                    Text(row.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(row.detail)
                            .font(.system(size: 9))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(transitPathStateLabel(row.state))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.text.opacity(0.86))
                        Text(row.timing)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(minWidth: 52, alignment: .trailing)
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transit-path-\(row.id)")
            }
        }
    }

    private func transitLifeAreas(_ rows: [TransitLifeAreaRow]) -> some View {
        let shown = showAllAreas ? rows : Array(rows.prefix(4))
        return VStack(spacing: 0) {
            Text(localized(
                "Activity reflects transiting houses, activated natal planets and overlapping exact contacts. It is not a fortune or success score.",
                "活动度反映行运行星落宫、被触发的本命星体与重叠的精确接触；它不是运气或成功评分。",
                language: language
            ))
            .font(.system(size: 9.5))
            .lineSpacing(3)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
            .padding(.bottom, 12)

            ForEach(shown) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(transitTriggerSummary(row))
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.background.opacity(0.78))
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0, min(1, row.progress)))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.bottom, 12)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transit-life-area-\(row.id)")
            }

            if rows.count > 4 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllAreas.toggle() }
                } label: {
                    Text(showAllAreas
                         ? localized("Show fewer areas", "收起部分领域", language: language)
                         : LocalizedFormatters.viewAllAreas(rows.count, language: language))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-life-areas-toggle")
            }
        }
    }

    private func transitActiveRows(_ rows: [TransitActiveRow]) -> some View {
        let filtered = transitFilter == nil ? rows : rows.filter { $0.category == transitFilter }
        let prioritized = filtered.sorted(by: transitActivePriority)
        let shown = showAllActiveTransits ? prioritized : Array(prioritized.prefix(5))
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                aspectFilterChip(nil, localized("All", "全部", language: language))
                aspectFilterChip("long-term", localized("Long-term", "长期", language: language))
                aspectFilterChip("current", localized("Current", "当前", language: language))
                aspectFilterChip("daily", localized("Daily", "每日", language: language))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 1)

            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(AppTheme.line)
                }
                Button {
                    transitDetailDrawer = .activeTransit(row)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(row.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.violet.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if !row.detail.isEmpty {
                                Text(row.detail)
                                    .font(.system(size: 9))
                                    .lineSpacing(2)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(transitActiveStatusLabel(row.status))
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppTheme.background.opacity(0.65), in: Capsule())
                                .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                            Text(row.technicalValue)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(AppTheme.muted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppTheme.background.opacity(0.45), in: Capsule())
                        }
                        .multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-active-\(row.id)")
            }
            if prioritized.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllActiveTransits.toggle()
                    }
                } label: {
                    Text(showAllActiveTransits
                         ? localized("Show key transits", "只看重点行运", language: language)
                         : localized("View all active transits", "查看全部进行中行运", language: language))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    private func transitActivePriority(_ lhs: TransitActiveRow, _ rhs: TransitActiveRow) -> Bool {
        let lhsRank = transitActiveStatusRank(lhs.status)
        let rhsRank = transitActiveStatusRank(rhs.status)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        let categoryOrder = ["long-term": 0, "current": 1, "daily": 2]
        let lhsCategory = categoryOrder[lhs.category] ?? 3
        let rhsCategory = categoryOrder[rhs.category] ?? 3
        if lhsCategory != rhsCategory { return lhsCategory < rhsCategory }
        return lhs.id < rhs.id
    }

    private func transitActiveStatusRank(_ status: TransitActiveStatus) -> Int {
        switch status {
        case .exact: 0
        case .returning: 1
        case .applying: 2
        case .ingress: 3
        case .retrograde, .direct: 4
        case .separating: 5
        }
    }

    @ViewBuilder
    private func transitDrawer(_ drawer: TransitDetailDrawer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch drawer {
                case let .planetPaths(rows):
                    Text(localized("Planet Paths", "行星路径", language: language))
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized(
                        "This module shows each transiting planet's sign, natal house, direction and next calculated ingress or station.",
                        "这里显示每颗行运行星的星座、本命宫位、运动方向，以及下一次已计算的换座、换宫或转向。",
                        language: language
                    ))
                    .font(.system(size: 11))
                    .lineSpacing(4)
                    .foregroundStyle(AppTheme.muted)
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                        spacing: 9
                    ) {
                        ForEach(rows.prefix(4)) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(bodyName(row.body, language: language))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.muted)
                                Text(transitDrawerHouse(row.house))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                        }
                    }
                    transitDrawerSection(
                        title: localized("Why separate it", "为什么单独呈现", language: language),
                        body: localized(
                            "A planet can matter because of the house it occupies even when no exact natal aspect is active.",
                            "即使没有正在生效的精确本命相位，行星也会因所处宫位而具有明确的领域重点。",
                            language: language
                        )
                    )
                    transitDrawerSection(
                        title: localized("Difference from Active Transits", "与进行中的变化有何不同", language: language),
                        body: localized(
                            "Planet Paths shows location and motion. Active Transits shows exact relationships to natal planets and points.",
                            "行星路径显示位置与运动；进行中的变化显示行运行星与本命星体或点位之间的精确关系。",
                            language: language
                        )
                    )
                case let .activeTransit(row):
                    Text(row.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if !row.detail.isEmpty {
                        Text(row.detail)
                            .font(.system(size: 11))
                            .lineSpacing(4)
                            .foregroundStyle(AppTheme.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                        ForEach(row.fields) { field in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(field.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.muted)
                                Text(field.value)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                        }
                    }
                    transitDrawerSection(
                        title: localized("Technical basis", "技术依据", language: language),
                        body: localized(
                            "Timing, orb, house and motion are calculated for the selected chart moment and time zone.",
                            "时间、容许度、宫位和运动状态均按当前选择的星盘时刻与时区计算。",
                            language: language
                        )
                    )
                }
                Button {
                    transitDetailDrawer = nil
                } label: {
                    Text(localized("Done", "完成", language: language))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 19)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(AppTheme.panel)
    }

    private func transitDrawerSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider().overlay(AppTheme.line)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .padding(.top, 8)
            Text(body)
                .font(.system(size: 10))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func transitDrawerHouse(_ house: Int) -> String {
        guard (1 ... 12).contains(house) else { return localized("Unknown house", "宫位未知", language: language) }
        return localized("\(ordinalLabel(house)) house", "第\(house)宫", language: language)
    }

    private func ordinalLabel(_ value: Int) -> String {
        let remainder = value % 100
        if (11 ... 13).contains(remainder) { return "\(value)th" }
        return switch value % 10 {
        case 1: "\(value)st"
        case 2: "\(value)nd"
        case 3: "\(value)rd"
        default: "\(value)th"
        }
    }

    private func transitPathStateLabel(_ state: TransitPathState) -> String {
        switch state {
        case .direct: localized("Direct", "顺行", language: language)
        case .retrograde: localized("Retrograde", "逆行", language: language)
        case .next: localized("Next", "接下来", language: language)
        }
    }

    private func transitActiveStatusLabel(_ status: TransitActiveStatus) -> String {
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

    private func transitTriggerSummary(_ row: TransitLifeAreaRow) -> String {
        if row.triggerCount == 0 {
            return localized("\(row.activity) · no exact hit", "\(row.activity) · 无精确触发", language: language)
        }
        return localized(
            "\(row.activity) · \(row.triggerCount) \(row.triggerCount == 1 ? "trigger" : "triggers")",
            "\(row.activity) · \(row.triggerCount) 个触发",
            language: language
        )
    }

    private func aspectFilterChip(_ category: String?, _ label: String) -> some View {
        let selected = transitFilter == category
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                transitFilter = category
                showAllActiveTransits = false
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selected ? Color.white : AppTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? AppTheme.violet : AppTheme.background.opacity(0.4), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var aspectRows: some View {
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

    private var areaRows: some View {
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

    private var elementRows: some View {
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

    private func phaseDial(phase: Double, illumination: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, illumination))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("☽").font(.system(size: 22)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(Int(illumination * 100))%", localized("illuminated", "照亮", language: language), .transition)
                metric(progressedPhaseName(phase), localized("phase", "月相", language: language), .neutral)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func moonProgressRing(progress: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(AppTheme.line.opacity(0.7), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("☽").font(.system(size: 24, weight: .semibold)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 88, height: 88)
            factGrid(columns: 3)
        }
    }

    // MARK: - Compare strip (prototype .compare-strip)

    private func compareStrip(natal: String, progressed: String) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text(localized("Natal", "本命", language: language)).font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.muted)
                Text(natal).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(AppTheme.muted)
            VStack(spacing: 4) {
                Text(localized("Now", "现在", language: language)).font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.muted)
                Text(progressed).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Story weave (prototype .story-weave)

    private func storyWeave(expanding: String, structuring: String, result: String) -> some View {
        VStack(spacing: 8) {
            storyThread(label: localized("EXPANDING", "展开", language: language), value: expanding, tone: .supportive)
            Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.muted)
            storyThread(label: localized("STRUCTURING", "定型", language: language), value: structuring, tone: .challenging)
            Text(result)
                .font(.system(size: 10.5))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.text.opacity(0.95))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func storyThread(label: String, value: String, tone: InsightTone) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.tone(tone))
            Text(value).font(.system(size: 11.5, weight: .medium)).foregroundStyle(AppTheme.text)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.tone(tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    // MARK: - Cycle tabs (prototype .cycle-tabs)

    private func cycleTabs(
        long: TransitCyclePresentation?,
        current: TransitCyclePresentation?,
        daily: TransitCyclePresentation?
    ) -> some View {
        let options = [
            (
                localized("Long-term", "长期", language: language),
                localized("LONG-TERM CHAPTER", "长期篇章", language: language),
                long,
                InsightTone.supportive
            ),
            (
                localized("Current", "当前", language: language),
                localized("CURRENT PERIOD", "当前阶段", language: language),
                current,
                InsightTone.transition
            ),
            (
                localized("Daily", "每日", language: language),
                localized("DAILY MOVEMENT", "每日变化", language: language),
                daily,
                InsightTone.neutral
            ),
        ]
        let selected = options[selectedCycleIndex]
        return VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(options.indices, id: \.self) { index in
                    cycleTabChip(options[index].0, index: index)
                }
            }
            cycleRow(kicker: selected.1, presentation: selected.2, tone: selected.3)
        }
    }

    private func cycleTabChip(_ label: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedCycleIndex = index }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selectedCycleIndex == index ? Color.white : AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    selectedCycleIndex == index ? AppTheme.violet : AppTheme.background.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
    }

    private func cycleRow(
        kicker: String,
        presentation: TransitCyclePresentation?,
        tone: InsightTone
    ) -> some View {
        let copy = presentation.flatMap { item in
            text?.cycleTexts?.first(where: { $0.roleID == item.roleID })
        }
        return VStack(alignment: .leading, spacing: 7) {
            Text(kicker.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tone(tone))
            if let presentation {
                Text(copy?.headline ?? presentation.fallbackTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let body = copy?.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 10))
                        .lineSpacing(3)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(presentation.tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.text.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
                .padding(.top, 2)
            } else {
                Text(localized("No active cycle at this time scale.", "当前没有这个时间尺度的生效周期。", language: language))
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stage flow (prototype .stage-flow)

    private func stageFlow(old: String, transition: String, emerging: String) -> some View {
        HStack(spacing: 6) {
            stageNode(label: localized("OLD", "过去", language: language), value: old, active: false)
            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("TRANSITION", "转变", language: language), value: transition, active: true)
            Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("EMERGING", "浮现", language: language), value: emerging, active: false)
        }
    }

    private func stageNode(label: String, value: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 8.5, weight: .bold)).foregroundStyle(active ? AppTheme.violet : AppTheme.muted)
            Text(value).font(.system(size: 10, weight: .medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(active ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Solar return orbit with lines (prototype .year-orbit)

    private var yearOrbit: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.35), lineWidth: 1).frame(width: 118, height: 118)
                Circle().stroke(AppTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(width: 88, height: 88)
                Circle().fill(AppTheme.violet.opacity(0.12)).frame(width: 40, height: 40)
                Text("☉").font(.system(size: 18, weight: .bold)).foregroundStyle(AppTheme.text)
                Text("↑").font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.mint)
                    .offset(x: 0, y: -64)
                Text("♄").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.amber)
                    .offset(x: 55, y: 26)
                Text("♃").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.blue)
                    .offset(x: -52, y: 34)
            }
            .frame(width: 128, height: 128)
            HStack(spacing: 9) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    trioCell(label: fact.label, value: fact.value)
                }
            }
        }
    }

    // MARK: - Dual insight (prototype .dual-insight)

    private func dualInsight(opening: String, demand: String, openingLabel: String, demandLabel: String) -> some View {
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

    private func edgeDual(opening: String, demand: String) -> some View {
        VStack(spacing: 10) {
            dualInsight(opening: opening, demand: demand, openingLabel: localized("CORE STRENGTH", "核心优势", language: language), demandLabel: localized("GROWTH EDGE", "成长面", language: language))
            ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(indexMark(fact.emphasis)).font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func indexMark(_ tone: InsightTone) -> String {
        tone == .supportive ? "+" : "↗"
    }

    // MARK: - Quarter tabs (prototype .quarter-tabs)

    private var quarterTabs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(index == 0 ? AppTheme.violet : AppTheme.muted)
                        Text(fact.value)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(index == 0 ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
                }
            }
            if let opening = facts.first, !opening.value.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(opening.value)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    if let note = opening.note {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private func natalOverlay(firstLabel: String, firstValue: String, secondLabel: String, secondValue: String) -> some View {
        HStack(spacing: 8) {
            compareNode(label: firstLabel, value: firstValue, tone: .supportive)
            Text("↔").font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.muted)
            compareNode(label: secondLabel, value: secondValue, tone: .challenging)
        }
    }

    private func compareNode(label: String, value: String, tone: InsightTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tone(tone))
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.tone(tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    private var needsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("☽")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 40, height: 40)
                .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                    Text(fact.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Transit timeline (prototype TR-03: range + timeline/calendar)

    private struct TransitTimelineView: View {
        let entries: [TransitTimelineEntry]
        let calendarFacts: [TransitCalendarFact]
        let anchorDate: Date
        let timeZoneIdentifier: String
        let language: AppLanguage
        @State private var selectedDays: Int
        @State private var showCalendar = false
        @State private var displayedMonth: Date
        private var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

        init(
            entries: [TransitTimelineEntry],
            calendarFacts: [TransitCalendarFact],
            anchorDate: Date,
            initialRangeDays: Int,
            timeZoneIdentifier: String,
            language: AppLanguage
        ) {
            self.entries = entries
            self.calendarFacts = calendarFacts
            self.anchorDate = anchorDate
            self.timeZoneIdentifier = timeZoneIdentifier
            self.language = language
            let normalizedRange = TransitTimelineContract.rangeDays.contains(initialRangeDays)
                ? initialRangeDays
                : TransitTimelineContract.defaultRangeDays
            _selectedDays = State(initialValue: normalizedRange)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
            _displayedMonth = State(
                initialValue: calendar.date(
                    from: calendar.dateComponents([.year, .month], from: anchorDate)
                ) ?? anchorDate
            )
        }

        private var axisStart: Date { anchorDate }
        private var axisEnd: Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(byAdding: .day, value: selectedDays, to: anchorDate)
                ?? anchorDate.addingTimeInterval(Double(selectedDays) * 86_400)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 6) {
                    rangeButton(30, localized("30 days", "30 天", language: language))
                    rangeButton(7, localized("7 days", "7 天", language: language))
                    rangeButton(365, localized("12 months", "12 个月", language: language))
                    Spacer()
                }
                HStack(spacing: 6) {
                    viewButton(false, localized("Timeline", "时间线", language: language))
                    viewButton(true, localized("Calendar", "日历", language: language))
                    Spacer()
                }
                if showCalendar {
                    calendarGrid
                } else {
                    timelineRows
                }
            }
        }

        private func rangeButton(_ days: Int, _ label: String) -> some View {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedDays = days
                    displayedMonth = monthStart(anchorDate)
                }
            } label: {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedDays == days ? Color.white : AppTheme.muted)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(selectedDays == days ? AppTheme.violet : AppTheme.background.opacity(0.4), in: Capsule())
            }
            .buttonStyle(.plain)
        }

        private func viewButton(_ calendar: Bool, _ label: String) -> some View {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showCalendar = calendar }
            } label: {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(showCalendar == calendar ? AppTheme.violet : AppTheme.muted)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(AppTheme.background.opacity(0.4), in: Capsule())
                    .overlay(Capsule().stroke(showCalendar == calendar ? AppTheme.violet.opacity(0.5) : AppTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        private var timelineRows: some View {
            let visible = entries.filter {
                ($0.end ?? $0.start) >= axisStart && $0.start <= axisEnd
            }
            if visible.isEmpty {
                return AnyView(
                    Text(localized("No transits enter this window.", "这个时间范围内没有新的行运进入。", language: language))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 8)
                )
            }
            return AnyView(
                VStack(spacing: 11) {
                    markerLegend
                    ForEach(Array(visible.prefix(8)), id: \.id) { entry in
                        timelineRow(entry)
                    }
                }
            )
        }

        private var markerLegend: some View {
            HStack(spacing: 4) {
                markerLegendItem(localized("Start", "开始", language: language), color: AppTheme.blue)
                markerLegendItem(localized("Exact", "精确", language: language), color: AppTheme.violet)
                markerLegendItem(localized("Return", "回返", language: language), color: AppTheme.amber)
                markerLegendItem(localized("End", "结束", language: language), color: AppTheme.muted)
            }
        }

        private func markerLegendItem(_ label: String, color: Color) -> some View {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label).font(.system(size: 8.5, weight: .medium)).foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity)
        }

        private func timelineRow(_ entry: TransitTimelineEntry) -> some View {
            let total = max(1, axisEnd.timeIntervalSince(axisStart))
            let startRatio = ratio(entry.start, total: total)
            let endRatio = entry.end.map { ratio($0, total: total) }
            return VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entryTitle(entry))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    Text(entryDateRange(entry))
                        .font(.system(size: 9.5))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.trailing)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 5)
                        if let endRatio {
                            Capsule()
                                .fill(AppTheme.blue.opacity(0.5))
                                .frame(
                                    width: proxy.size.width * max(0.025, endRatio - startRatio),
                                    height: 5
                                )
                                .offset(x: proxy.size.width * startRatio)
                        }
                        timelineMarker(ratio: startRatio, color: AppTheme.blue, filled: true, width: proxy.size.width)
                        ForEach(Array(entry.exactDates.enumerated()), id: \.offset) { index, date in
                            timelineMarker(
                                ratio: ratio(date, total: total),
                                color: index == 0 ? AppTheme.violet : AppTheme.amber,
                                filled: index == 0,
                                width: proxy.size.width
                            )
                        }
                        if let endRatio {
                            timelineMarker(ratio: endRatio, color: AppTheme.muted, filled: false, width: proxy.size.width)
                        }
                    }
                }
                .frame(height: 11)
            }
        }

        private func timelineMarker(ratio: Double, color: Color, filled: Bool, width: CGFloat) -> some View {
            Circle()
                .fill(filled ? color : AppTheme.panel)
                .overlay(Circle().stroke(color, lineWidth: 1.5))
                .frame(width: 9, height: 9)
                .offset(x: width * ratio - 4.5)
        }

        private func ratio(_ date: Date, total: TimeInterval) -> Double {
            min(1, max(0, date.timeIntervalSince(axisStart) / total))
        }

        private func entryTitle(_ entry: TransitTimelineEntry) -> String {
            let body = bodyName(entry.movingBody, language: language)
            switch entry.kind {
            case let .aspect(kind):
                let reference = entry.referenceBody.map { bodyName($0, language: language) } ?? ""
                return "\(body) \(kind.symbol) \(reference)"
            case let .houseResidence(house):
                return localized("\(body) crosses \(ordinal(house)) house", "\(body) 进入第\(house)宫", language: language)
            case let .signIngress(sign):
                return localized(
                    "\(body) enters \(Zodiac.name(index: sign, language: language))",
                    "\(body) 进入\(Zodiac.name(index: sign, language: language))",
                    language: language
                )
            case .stationRetrograde:
                return localized("\(body) stations retrograde", "\(body) 转逆", language: language)
            case .stationDirect:
                return localized("\(body) stations direct", "\(body) 转顺", language: language)
            }
        }

        private func entryDateRange(_ entry: TransitTimelineEntry) -> String {
            guard let end = entry.end else {
                return entry.start.shortEventDate(language: language, timeZone: timeZone)
            }
            return entry.start.shortEventRange(to: end, language: language, timeZone: timeZone)
        }

        private func ordinal(_ value: Int) -> String {
            let remainder = value % 100
            if (11 ... 13).contains(remainder) { return "\(value)th" }
            return switch value % 10 {
            case 1: "\(value)st"
            case 2: "\(value)nd"
            case 3: "\(value)rd"
            default: "\(value)th"
            }
        }

        private var calendarGrid: some View {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let today = calendar.startOfDay(for: anchorDate)
            let first = monthStart(displayedMonth)
            let firstWeekday = calendar.component(.weekday, from: first)
            let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
            let leading = (firstWeekday + 5) % 7
            let weekdayLabels = language == .english ? ["M", "T", "W", "T", "F", "S", "S"] : ["一", "二", "三", "四", "五", "六", "日"]
            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
            let factsByDay = Dictionary(
                uniqueKeysWithValues: calendarFacts.map { (calendar.startOfDay(for: $0.date), $0) }
            )
            let eventKindsByDay = Dictionary(
                grouping: entries.flatMap { entry in
                    ([entry.start] + entry.exactDates + [entry.end].compactMap { $0 }).map {
                        (calendar.startOfDay(for: $0), entry.kind)
                    }
                },
                by: { $0.0 }
            ).mapValues { $0.map { $0.1 } }
            return VStack(spacing: 6) {
                HStack {
                    monthButton(systemName: "chevron.left", delta: -1, enabled: canMoveMonth(-1))
                    Spacer()
                    Text(displayedMonth.shortEventMonthYear(language: language, timeZone: timeZone))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    monthButton(systemName: "chevron.right", delta: 1, enabled: canMoveMonth(1))
                }
                HStack(spacing: 5) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label).font(.system(size: 9)).foregroundStyle(AppTheme.muted).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(0 ..< leading, id: \.self) { _ in
                        Color.clear.frame(height: 30)
                    }
                    ForEach(1 ... daysInMonth, id: \.self) { day in
                        let date = calendar.date(byAdding: .day, value: day - 1, to: first) ?? today
                        let fact = factsByDay[date]
                        let kinds = eventKindsByDay[date] ?? []
                        let inRange = date >= today && date <= calendar.startOfDay(for: axisEnd)
                        VStack(spacing: 3) {
                            HStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.system(size: 10, weight: fact == nil ? .medium : .bold))
                                if let fact, !fact.sourceFactIDs.isEmpty {
                                    Text("\(fact.sourceFactIDs.count)")
                                        .font(.system(size: 7.5, weight: .bold))
                                        .foregroundStyle(AppTheme.violet)
                                }
                            }
                            HStack(spacing: 2) {
                                ForEach(Array(calendarColors(for: kinds).prefix(3).enumerated()), id: \.offset) { _, color in
                                    Circle().fill(color).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                            .foregroundStyle(inRange ? AppTheme.text : AppTheme.muted.opacity(0.45))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(
                                calendarCellBackground(score: inRange ? fact?.score : nil),
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                    }
                }
            }
        }

        private func monthStart(_ date: Date) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }

        private func canMoveMonth(_ delta: Int) -> Bool {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            guard let target = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return false }
            return monthStart(target) >= monthStart(anchorDate) && monthStart(target) <= monthStart(axisEnd)
        }

        private func monthButton(systemName: String, delta: Int, enabled: Bool) -> some View {
            Button {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(enabled ? AppTheme.violet : AppTheme.muted.opacity(0.35))
            .disabled(!enabled)
        }

        private func calendarCellBackground(score: Int?) -> Color {
            guard let score else { return AppTheme.background.opacity(0.4) }
            return AppTheme.violet.opacity(0.08 + 0.18 * min(1, Double(score) / 100))
        }

        private func calendarColors(for kinds: [TransitTimelineEntryKind]) -> [Color] {
            var colors: [Color] = []
            if kinds.contains(where: { if case .aspect = $0 { true } else { false } }) {
                colors.append(AppTheme.violet)
            }
            if kinds.contains(where: {
                if case .houseResidence = $0 { return true }
                if case .signIngress = $0 { return true }
                return false
            }) {
                colors.append(AppTheme.blue)
            }
            if kinds.contains(where: { $0 == .stationRetrograde || $0 == .stationDirect }) {
                colors.append(AppTheme.amber)
            }
            return colors
        }
    }

    // MARK: - Bond orbit (prototype .bond-orbit)

    private var bondOrbit: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.4), lineWidth: 1).frame(width: 104, height: 104)
                Circle().fill(AppTheme.violet.opacity(0.16)).frame(width: 52, height: 52)
                    .offset(x: -24)
                Circle().fill(AppTheme.blue.opacity(0.16)).frame(width: 52, height: 52)
                    .offset(x: 24)
                Text("∞").font(.system(size: 18, weight: .bold)).foregroundStyle(AppTheme.violet)
            }
            .frame(width: 112, height: 96)
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    TagChip(text: fact.label, tone: fact.emphasis)
                }
            }
        }
    }

    // MARK: - Perspective tabs (prototype .perspective-tabs)

    private var perspectiveTabs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { index, fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(index == 0 ? AppTheme.violet : AppTheme.muted)
                        Text(fact.value)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(index == 0 ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
    }

    // MARK: - Connection grid (prototype .connection-grid)

    private var connectionGrid: some View {
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

    private func pathFlow(title: String) -> some View {
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

    private var houseOverlayRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func technicalTag(_ tone: InsightTone) -> String {
        switch tone {
        case .supportive: localized("Supportive pattern", "支持性结构", language: language)
        case .challenging: localized("Core tension", "核心张力", language: language)
        case .transition, .neutral: localized("Relational pattern", "关系结构", language: language)
        }
    }

    private func polygon(center: CGPoint, radius: Double, count: Int) -> Path {
        var path = Path()
        for index in 0 ..< count {
            let point = polygonPoint(center: center, radius: radius, index: index, count: count)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func polygonPoint(center: CGPoint, radius: Double, index: Int, count: Int) -> CGPoint {
        let angle = Double(index) / Double(count) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
