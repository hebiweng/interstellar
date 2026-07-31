import SwiftUI

struct InsightCardView: View {
    let card: InsightCardModel
    let language: AppLanguage
    var aiDetail: String? = nil
    var aiStatus: AIDetailStatus = .hidden
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 11) {
                Text(card.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
            }

            InsightVisualView(visual: card.visual, facts: card.facts, language: language)

            Divider().overlay(AppTheme.line)

            Text(card.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            if let detail = aiDetail, !detail.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(expanded
                             ? localized("Hide details", "收起详情", language: language)
                             : localized("Read details", "查看详情", language: language))
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(AppTheme.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else if aiStatus == .generating {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(AppTheme.violet)
                    Text(localized("Generating…", "正在生成…", language: language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            }
        }
        .cardSurface()
    }
}

private struct InsightVisualView: View {
    let visual: InsightVisual
    let facts: [InsightFact]
    let language: AppLanguage

    var body: some View {
        Group {
            switch visual {
            case .natalCore: factGrid(columns: 3)
            case .rankedThemes: rankedThemes
            case let .strengthOrbit(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .blindSpot: factGrid(columns: 2)
            case .growthPath: pathFlow(title: localized("Growth path", "成长路径", language: language))
            case let .skyOverview(phase, activity, cycles): skyOverview(phase: phase, activity: activity, cycles: cycles)
            case .themeCards: themeCards
            case .eventTimeline: verticalTimeline
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
            case let .balanceRing(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .houseRadar(values): houseRadar(values)
            case .actionGuidance: factRows
            case .arcTimeline: factRows
            case .doubleRing: doubleRing
            case let .calendar(values): calendar(values)
            case let .progressedStage(phase, moonProgress, sunProgress):
                progressedStage(phase: phase, moonProgress: moonProgress, sunProgress: sunProgress)
            case let .progressedThemes(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .turningTimeline: factRows
            case .comparison: factRows
            case let .signatureTrio(ruler, dominant, orientation):
                metricTrio(ruler: ruler, dominant: dominant, orientation: orientation)
            case .placementList: positionList
            case .aspectList: aspectList
            case let .storyWeave(expanding, structuring): storyWeave(expanding: expanding, structuring: structuring)
            case let .cycleTabs(long, current, daily): cycleTabs(long: long, current: current, daily: daily)
            case .positionRows: positionList
            case .areaRows: areaRows
            case let .phaseDial(phase, illumination): phaseDial(phase: phase, illumination: illumination)
            case .motionList: positionList
            case .elementRows: areaRows
            case let .stageFlow(old, transition, emerging):
                stageFlow(old: old, transition: transition, emerging: emerging)
            case .moonProgress: moonProgress
            case let .identityCompare(natal, progressed):
                compareStrip(natal: natal, progressed: progressed)
            case .turningRows: factRows
            case .yearOrbit: yearOrbit
            case .anchorGrid: factGrid(columns: 2)
            case let .dualInsight(opening, demand): dualInsight(opening: opening, demand: demand)
            case .quarterTabs: factRows
            case .overlayCompare: compareStrip(natal: localized("Natal", "本命", language: language), progressed: localized("This year", "今年", language: language))
            case .bondOrbit: bondOrbit
            case .perspectiveTabs: factRows
            case .connectionGrid: factGrid(columns: 2)
            case .pathFlow: pathFlow(title: localized("How it flows", "流动方式", language: language))
            case .houseOverlayRows: positionList
            }
        }
    }

    // MARK: - Shared building blocks

    private func factGrid(columns: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columns))
        return LazyVGrid(columns: grid, spacing: 10) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        if let symbol = fact.symbol {
                            Text(symbol).font(.caption.bold()).foregroundStyle(AppTheme.tone(fact.emphasis))
                        }
                        Text(fact.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Text(fact.value)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private var factRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: 10) {
                    if let symbol = fact.symbol {
                        Text(symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 24, height: 24)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
                        Text(fact.value).font(.footnote.weight(.medium)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    if let progress = fact.progress {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var rankedThemes: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.violet)
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.caption2).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                    if let note = fact.note {
                        Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
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
                    Text("\(total)").font(.title3.bold().monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("contacts", "连接", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
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
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(AppTheme.tone(tone))
            Text(title).font(.footnote).foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func skyOverview(phase: Double, activity: Int, cycles: [Double]) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                    Circle().trim(from: 0, to: max(0.01, phase / 360))
                        .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(phase))°").font(.caption.bold()).foregroundStyle(AppTheme.text)
                        Text(localized("phase", "月相", language: language)).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
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
    }

    private var themeCards: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "✦").foregroundStyle(AppTheme.tone(fact.emphasis))
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.caption2).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                    if let note = fact.note {
                        Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private var verticalTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(AppTheme.tone(fact.emphasis))
                            .frame(width: 9, height: 9)
                        if index < min(4, facts.count) - 1 {
                            Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 26)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    if let progress = fact.progress {
                        Text("\(Int(progress * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }

    private func domainBars(_ values: [Double]) -> some View {
        let labels = language == .english
            ? ["Information", "Relationships", "Action", "Institutions", "Technology", "Resources", "Public mood", "Culture"]
            : ["信息传播", "关系合作", "行动竞争", "制度结构", "技术创新", "资源经济", "公共情绪", "文化价值"]
        return VStack(spacing: 8) {
            ForEach(Array(zip(labels, values).enumerated()), id: \.offset) { index, item in
                HStack(spacing: 9) {
                    Text(item.0).font(.caption).foregroundStyle(AppTheme.muted).frame(width: 76, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6))
                            Capsule().fill(AppTheme.violet.opacity(0.85))
                                .frame(width: proxy.size.width * max(0.02, min(1, item.1)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(Int(item.1 * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(AppTheme.muted)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 24)
                    Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                    Spacer()
                    Text(fact.value).font(.caption).foregroundStyle(AppTheme.muted)
                    if let note = fact.note {
                        Text(note).font(.caption2).foregroundStyle(AppTheme.muted.opacity(0.8))
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
                    Text("\(value)").font(.title2.bold().monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("activity", "活跃度", language: language)).font(.caption).foregroundStyle(AppTheme.muted)
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

    private var gantt: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        .frame(width: 84, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.tone(fact.emphasis).opacity(0.18))
                            Capsule().fill(AppTheme.tone(fact.emphasis))
                                .frame(width: proxy.size.width * max(0.08, min(0.92, fact.progress ?? 0.5)))
                        }
                    }
                    .frame(height: 8)
                    if let note = fact.note {
                        Text(note).font(.caption2).foregroundStyle(AppTheme.muted).frame(width: 64, alignment: .trailing)
                    }
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
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Text("\(index + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func calendar(_ values: [Int]) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 3) {
                        Text(shortDay(index + 1)).font(.caption2).foregroundStyle(AppTheme.muted)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.tone(value > 66 ? .challenging : value > 35 ? .transition : .neutral).opacity(0.16 + Double(value) / 100 * 0.7))
                            .frame(height: 44)
                            .overlay(
                                Text("\(value)")
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(localized("This week's intensity", "本周变化强度", language: language))
                .font(.caption2)
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
                    Text(progressedPhaseName(phase)).font(.caption.bold()).foregroundStyle(AppTheme.text)
                    Text("\(Int(phase))°").font(.caption2).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 108, height: 108)
            progressTrack(label: localized("Moon", "月亮", language: language), value: moonProgress, tone: .transition)
            progressTrack(label: localized("Sun", "太阳", language: language), value: sunProgress, tone: .supportive)
        }
    }

    private func progressTrack(label: String, value: Double, tone: InsightTone) -> some View {
        HStack(spacing: 9) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted).frame(width: 44, alignment: .leading)
            ProgressView(value: max(0, min(1, value))).tint(AppTheme.tone(tone))
            Text("\(Int(value * 30))°/30").font(.caption2.monospacedDigit()).foregroundStyle(AppTheme.muted).frame(width: 52, alignment: .trailing)
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

    private func pathFlow(title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                    VStack(spacing: 4) {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: Circle())
                        Text(fact.label).font(.caption2.weight(.medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    if index < min(3, facts.count) - 1 {
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
        .padding(11)
        .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
    }

    private func metricTrio(ruler: String, dominant: String, orientation: String) -> some View {
        HStack(spacing: 9) {
            trioCell(label: localized("Chart ruler", "命主星", language: language), value: ruler)
            trioCell(label: localized("Dominant", "主导星体", language: language), value: dominant)
            trioCell(label: localized("Orientation", "总体取向", language: language), value: orientation)
        }
    }

    private func trioCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
            Text(value).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var positionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(8).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 26, height: 26)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(fact.value).font(.caption).foregroundStyle(AppTheme.muted)
                }
                .padding(.vertical, 8)
                Divider().overlay(AppTheme.line.opacity(0.6))
            }
        }
    }

    private var aspectList: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "⌗")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 26, height: 26)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(fact.value).font(.caption2).foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.trailing)
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var areaRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.caption2).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.line.opacity(0.6))
                                Capsule().fill(AppTheme.tone(fact.emphasis))
                                    .frame(width: proxy.size.width * max(0.02, min(1, progress)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private func phaseDial(phase: Double, illumination: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, illumination))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("☽").font(.title3).foregroundStyle(AppTheme.text)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(Int(illumination * 100))%", localized("illuminated", "照亮", language: language), .transition)
                metric(progressedPhaseName(phase), localized("phase", "月相", language: language), .neutral)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var moonProgress: some View {
        factGrid(columns: 3)
    }

    private func compareStrip(natal: String, progressed: String) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text(localized("Natal", "本命", language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                Text(natal).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppTheme.muted)
            VStack(spacing: 4) {
                Text(localized("Now", "现在", language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                Text(progressed).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func storyWeave(expanding: String, structuring: String) -> some View {
        VStack(spacing: 10) {
            storyThread(label: localized("EXPANDING", "展开", language: language), value: expanding, tone: .supportive)
            Image(systemName: "plus").font(.caption).foregroundStyle(AppTheme.muted)
            storyThread(label: localized("STRUCTURING", "定型", language: language), value: structuring, tone: .challenging)
        }
    }

    private func storyThread(label: String, value: String, tone: InsightTone) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.caption2.bold()).foregroundStyle(AppTheme.tone(tone))
            Text(value).font(.footnote.weight(.medium)).foregroundStyle(AppTheme.text)
            Spacer()
        }
        .padding(11)
        .background(AppTheme.tone(tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func cycleTabs(long: String, current: String, daily: String) -> some View {
        VStack(spacing: 10) {
            cycleRow(label: localized("Long-term", "长期", language: language), value: long, tone: .supportive)
            cycleRow(label: localized("Current", "当前", language: language), value: current, tone: .transition)
            cycleRow(label: localized("Daily", "每日", language: language), value: daily, tone: .neutral)
        }
    }

    private func cycleRow(label: String, value: String, tone: InsightTone) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.caption2.bold()).foregroundStyle(AppTheme.tone(tone))
                .frame(width: 60, alignment: .leading)
            Text(value).font(.footnote.weight(.medium)).foregroundStyle(AppTheme.text)
            Spacer()
        }
        .padding(10)
        .background(AppTheme.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stageFlow(old: String, transition: String, emerging: String) -> some View {
        HStack(spacing: 6) {
            stageNode(label: localized("OLD", "过去", language: language), value: old, active: false)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("TRANSITION", "转变", language: language), value: transition, active: true)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("EMERGING", "浮现", language: language), value: emerging, active: false)
        }
    }

    private func stageNode(label: String, value: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundStyle(active ? AppTheme.violet : AppTheme.muted)
            Text(value).font(.caption2.weight(.medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(active ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var yearOrbit: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.violet.opacity(0.12)).frame(width: 86, height: 86)
                Circle().stroke(AppTheme.violet.opacity(0.35), lineWidth: 1).frame(width: 66, height: 66)
                Text("☉").font(.title2).foregroundStyle(AppTheme.text)
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    HStack(spacing: 8) {
                        Text(fact.label).font(.caption).foregroundStyle(AppTheme.muted)
                        Text(fact.value).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                    }
                }
            }
            Spacer()
        }
    }

    private func dualInsight(opening: String, demand: String) -> some View {
        HStack(spacing: 9) {
            VStack(spacing: 5) {
                Text(localized("OPENING", "展开", language: language)).font(.caption2.bold()).foregroundStyle(AppTheme.mint)
                Text(opening).font(.footnote.weight(.medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 5) {
                Text(localized("DEMAND", "要求", language: language)).font(.caption2.bold()).foregroundStyle(AppTheme.coral)
                Text(demand).font(.footnote.weight(.medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var bondOrbit: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.violet.opacity(0.14)).frame(width: 78, height: 78)
                Circle().fill(AppTheme.blue.opacity(0.14)).frame(width: 78, height: 78).offset(x: 26)
                Text("∞").font(.title3.bold()).foregroundStyle(AppTheme.violet)
            }
            .frame(width: 96, height: 88)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                }
            }
            Spacer()
        }
    }

    private var doubleRing: some View {
        positionList
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
