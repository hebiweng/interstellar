import SwiftUI

struct InsightCardView: View {
    let card: InsightCardModel
    let language: AppLanguage
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
            .accessibilityHint(localized(
                "Shows or hides the full interpretation",
                "展开或收起完整解读",
                language: language
            ))

            if expanded {
                Text(card.detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(AppTheme.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
            case .natalCore:
                natalCore
            case .rankedThemes:
                rankedThemes
            case let .strengthOrbit(supportive, challenging, neutral):
                strengthOrbit(supportive: supportive, challenging: challenging, neutral: neutral)
            case .blindSpot:
                blindSpot
            case .growthPath:
                growthPath
            case let .skyOverview(phase, activity, cycles):
                skyOverview(phase: phase, activity: activity, cycles: cycles)
            case .themeCards:
                themeCards
            case .eventTimeline:
                verticalTimeline
            case let .structureMap(supportive, challenging, neutral):
                structureMap(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .domainBars(values):
                domainBars(values)
            case .observation:
                observation
            case .evolution:
                evolution
            case .planetTable:
                planetTable
            case let .activityGauge(value, supportive, adjustment):
                activityGauge(value: value, supportive: supportive, adjustment: adjustment)
            case let .transitOverview(intensity, rhythm):
                transitOverview(intensity: intensity, rhythm: rhythm)
            case .gantt:
                gantt
            case let .balanceRing(supportive, challenging, neutral):
                balanceRing(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .houseRadar(values):
                houseRadar(values)
            case .actionGuidance:
                actionGuidance
            case .arcTimeline:
                arcTimeline
            case .doubleRing:
                doubleRing
            case let .calendar(values):
                calendar(values)
            case let .progressedStage(phase, moonProgress, sunProgress):
                progressedStage(phase: phase, moonProgress: moonProgress, sunProgress: sunProgress)
            case let .progressedThemes(supportive, challenging, neutral):
                VStack(spacing: 13) {
                    balanceStrip(supportive: supportive, challenging: challenging, neutral: neutral)
                    themeCards
                }
            case .turningTimeline:
                verticalTimeline
            case .comparison:
                comparison
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var natalCore: some View {
        HStack(spacing: 12) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.element.id) { index, fact in
                VStack(spacing: 7) {
                    Text(fact.symbol ?? ["☉", "☽", "ASC"][index])
                        .font(.title2)
                        .foregroundStyle(index == 0 ? AppTheme.coral : index == 1 ? AppTheme.blue : AppTheme.violet)
                    Text(fact.label).font(.footnote).foregroundStyle(AppTheme.muted)
                    Text(fact.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 95)
                .padding(.vertical, 9)
                .background(AppTheme.line.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var rankedThemes: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                HStack(alignment: .center, spacing: 11) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.tone(fact.emphasis), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                            Spacer()
                            Text(fact.value).font(.footnote).foregroundStyle(AppTheme.muted)
                        }
                        progressBar(fact.progress ?? max(0.28, 0.92 - Double(index) * 0.19), tone: fact.emphasis)
                        if let note = fact.note {
                            Text(note).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func strengthOrbit(supportive: Int, challenging: Int, neutral: Int) -> some View {
        HStack(spacing: 17) {
            ring(supportive: supportive, challenging: challenging, neutral: neutral, size: 102)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(facts) { fact in factRow(fact) }
            }
        }
    }

    private var blindSpot: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundStyle(AppTheme.coral)
                Text(localized("Primary tension", "主要张力", language: language))
                    .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.coral)
            }
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 4) {
                    factRow(fact)
                    if let note = fact.note {
                        Text(note).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(AppTheme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var growthPath: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                    VStack(spacing: 7) {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.tone(fact.emphasis), in: Circle())
                        Text(fact.label).font(.footnote).foregroundStyle(AppTheme.muted)
                        Text(fact.value)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    if index < facts.count - 1 {
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(AppTheme.violet)
                    }
                }
            }
        }
    }

    private func skyOverview(phase: Double, activity: Int, cycles: [Double]) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                phaseDisc(phase, size: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("Sky activity", "天空活跃度", language: language))
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                    Text("\(activity)")
                        .font(.title.monospacedDigit().bold()).foregroundStyle(AppTheme.text)
                    Text(activityLabel(activity)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.violet)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    ForEach(facts.dropFirst(3)) { fact in
                        Text("\(fact.label)  \(fact.value)")
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            ForEach(Array(facts.prefix(3).enumerated()), id: \.element.id) { index, fact in
                VStack(spacing: 5) {
                    factRow(fact)
                    progressBar(cycles.indices.contains(index) ? cycles[index] : 0, tone: fact.emphasis)
                }
            }
        }
    }

    private var themeCards: some View {
        VStack(spacing: 9) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(fact.symbol ?? "✦").foregroundStyle(AppTheme.tone(fact.emphasis))
                        Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.footnote).foregroundStyle(AppTheme.muted)
                    }
                    progressBar(fact.progress ?? 0.5, tone: fact.emphasis)
                    if let note = fact.note {
                        Text(note).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(11)
                .background(AppTheme.tone(fact.emphasis).opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private var verticalTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                HStack(alignment: .top, spacing: 11) {
                    VStack(spacing: 0) {
                        Circle().fill(AppTheme.tone(fact.emphasis)).frame(width: 10, height: 10)
                        if index < facts.count - 1 {
                            Rectangle().fill(AppTheme.line).frame(width: 1, height: fact.note == nil ? 38 : 52)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(fact.label).font(.footnote).foregroundStyle(AppTheme.muted)
                            Spacer()
                            if let progress = fact.progress {
                                Text("\(Int(progress * 100))%").font(.footnote.monospacedDigit()).foregroundStyle(AppTheme.muted)
                            }
                        }
                        Text(fact.value).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text).fixedSize(horizontal: false, vertical: true)
                        if let note = fact.note {
                            Text(note).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func structureMap(supportive: Int, challenging: Int, neutral: Int) -> some View {
        VStack(spacing: 13) {
            balanceStrip(supportive: supportive, challenging: challenging, neutral: neutral)
            HStack(spacing: 18) {
                Canvas { context, size in
                    let points = radialPoints(count: max(4, min(8, facts.count)), size: size)
                    for index in points.indices {
                        for second in points.indices where second > index && (index + second).isMultiple(of: 3) {
                            var path = Path()
                            path.move(to: points[index])
                            path.addLine(to: points[second])
                            context.stroke(path, with: .color(index.isMultiple(of: 2) ? AppTheme.mint : AppTheme.coral), lineWidth: 0.8)
                        }
                        context.fill(Path(ellipseIn: CGRect(x: points[index].x - 4, y: points[index].y - 4, width: 8, height: 8)), with: .color(AppTheme.violet))
                    }
                }
                .frame(width: 112, height: 88)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(facts.prefix(3)) { fact in factRow(fact) }
                }
            }
        }
    }

    private func domainBars(_ values: [Double]) -> some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                VStack(spacing: 4) {
                    factRow(fact)
                    progressBar(values.indices.contains(index) ? values[index] : fact.progress ?? 0, tone: fact.emphasis)
                    if let note = fact.note {
                        Text(note).font(.footnote).foregroundStyle(AppTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var observation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("ACTIVE FOCUS", "当前重点", language: language))
                .font(.footnote.bold())
                .foregroundStyle(AppTheme.violet)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(AppTheme.violet.opacity(0.12), in: Capsule())
            ForEach(facts) { fact in
                HStack(alignment: .top, spacing: 9) {
                    Circle().fill(AppTheme.tone(fact.emphasis)).frame(width: 7, height: 7).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Text(fact.value).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var evolution: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                VStack(spacing: 6) {
                    Text(fact.label.uppercased()).font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                    Text(fact.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                if index < facts.count - 1 {
                    Image(systemName: "arrow.right").font(.footnote).foregroundStyle(AppTheme.violet).padding(.top, 24)
                }
            }
        }
    }

    private var planetTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text(localized("Body", "星体", language: language)).frame(maxWidth: .infinity, alignment: .leading)
                Text(localized("Position", "位置", language: language)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.muted)
            .padding(.bottom, 6)

            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(fact.symbol ?? "") \(fact.label)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(fact.value)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(fact.note ?? "—")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                Divider().overlay(AppTheme.line)
            }
        }
    }

    private func activityGauge(value: Int, supportive: Int, adjustment: Int) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                semicirclePath
                    .stroke(AppTheme.line, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                semicirclePath
                    .trim(from: 0, to: CGFloat(max(0, min(100, value))) / 100)
                    .stroke(LinearGradient(colors: [AppTheme.blue, AppTheme.violet, AppTheme.coral], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                VStack(spacing: 1) {
                    Text("\(value)").font(.largeTitle.monospacedDigit().bold()).foregroundStyle(AppTheme.text)
                    Text(activityLabel(value)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.violet)
                }
                .offset(y: 4)
            }
            .frame(height: 86)

            HStack(spacing: 10) {
                metric(localized("Supportive", "推动", language: language), supportive, .supportive)
                metric(localized("Adjustment", "调整", language: language), adjustment, .challenging)
                metric(localized("Trend", "趋势", language: language), nil, .neutral)
            }
            ForEach(facts) { fact in factRow(fact) }
        }
    }

    private func transitOverview(intensity: Int, rhythm: [Double]) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Current intensity", "当前强度", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
                    Text("\(intensity)").font(.title.bold().monospacedDigit()).foregroundStyle(AppTheme.text)
                }
                Spacer()
                rhythmWave(rhythm)
                    .frame(width: 155, height: 50)
            }
            ForEach(facts) { fact in
                VStack(spacing: 4) {
                    factRow(fact)
                    progressBar(fact.progress ?? 0.5, tone: fact.emphasis)
                }
            }
        }
    }

    private var gantt: some View {
        VStack(spacing: 9) {
            HStack {
                Text(localized("Now", "当前", language: language))
                Spacer()
                Text(localized("Building", "增强", language: language))
                Spacer()
                Text(localized("Easing", "缓和", language: language))
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.muted)
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.value).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text).fixedSize(horizontal: false, vertical: true)
                    GeometryReader { proxy in
                        let width = proxy.size.width * max(0.18, min(0.86, fact.progress ?? 0.5))
                        Capsule()
                            .fill(AppTheme.tone(fact.emphasis))
                            .frame(width: width)
                            .offset(x: proxy.size.width * CGFloat(index % 3) * 0.07)
                    }
                    .frame(height: 7)
                    Text(fact.label).font(.footnote).foregroundStyle(AppTheme.muted)
                }
            }
        }
    }

    private func balanceRing(supportive: Int, challenging: Int, neutral: Int) -> some View {
        HStack(spacing: 17) {
            ring(supportive: supportive, challenging: challenging, neutral: neutral, size: 108)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(facts) { fact in factRow(fact) }
            }
        }
    }

    private func houseRadar(_ values: [Double]) -> some View {
        HStack(spacing: 14) {
            radar(values).frame(width: 132, height: 132)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(facts.prefix(4)) { fact in factRow(fact) }
            }
        }
    }

    private var actionGuidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let first = facts.first {
                Text(first.value)
                    .font(.caption.bold()).foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppTheme.violet.opacity(0.12), in: Capsule())
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(facts.dropFirst().prefix(3)) { fact in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                        Text(fact.value).font(.footnote).foregroundStyle(AppTheme.text).fixedSize(horizontal: false, vertical: true)
                        if let note = fact.note {
                            Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(9)
                    .background(AppTheme.tone(fact.emphasis).opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var arcTimeline: some View {
        HStack(spacing: 6) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                VStack(spacing: 7) {
                    ZStack {
                        Circle().stroke(AppTheme.line, lineWidth: 5)
                        Circle().trim(from: 0, to: fact.progress ?? 0.5)
                            .stroke(AppTheme.tone(fact.emphasis), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(fact.symbol ?? "•").font(.caption.bold()).foregroundStyle(AppTheme.text)
                    }
                    .frame(width: 50, height: 50)
                    Text(fact.label).font(.footnote).foregroundStyle(AppTheme.muted)
                    Text(fact.value).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                if index < facts.count - 1 {
                    Image(systemName: "arrow.right").font(.footnote).foregroundStyle(AppTheme.violet)
                }
            }
        }
    }

    private var doubleRing: some View {
        VStack(spacing: 13) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(AppTheme.line, lineWidth: 1)
                    Circle().stroke(AppTheme.violet.opacity(0.6), style: StrokeStyle(lineWidth: 6, dash: [8, 5]))
                        .padding(10)
                    Circle().stroke(AppTheme.blue.opacity(0.55), style: StrokeStyle(lineWidth: 5, dash: [5, 8]))
                        .padding(23)
                    Text(localized("Natal", "本命", language: language)).font(.footnote.bold()).foregroundStyle(AppTheme.text)
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(facts.prefix(4)) { fact in factRow(fact) }
                }
            }
            planetTable
        }
    }

    private func calendar(_ values: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0 ..< 7, id: \.self) { index in
                    let value = values.indices.contains(index) ? values[index] : 0
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: index == 0 ? .bold : .medium, design: .rounded))
                        .foregroundStyle(value > 65 ? Color.white : AppTheme.muted)
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(
                            value == 0 ? AppTheme.line : AppTheme.violet.opacity(0.15 + Double(value) / 120),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .overlay(index == 0 ? RoundedRectangle(cornerRadius: 5).stroke(AppTheme.coral, lineWidth: 1.5) : nil)
                }
            }
            ForEach(facts) { fact in factRow(fact) }
        }
    }

    private func progressedStage(phase: Double, moonProgress: Double, sunProgress: Double) -> some View {
        HStack(spacing: 16) {
            phaseDisc(phase, size: 82)
            VStack(spacing: 10) {
                if let moon = facts.first {
                    labeledProgress(moon, value: moonProgress)
                }
                if facts.count > 1 {
                    labeledProgress(facts[1], value: sunProgress)
                }
                ForEach(facts.dropFirst(2)) { fact in factRow(fact) }
            }
        }
    }

    private var comparison: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                comparisonColumn(
                    title: localized("Strengthened", "正在强化", language: language),
                    facts: facts.filter { $0.emphasis == .supportive },
                    tone: .supportive
                )
                comparisonColumn(
                    title: localized("Challenged", "正在挑战", language: language),
                    facts: facts.filter { $0.emphasis == .challenging },
                    tone: .challenging
                )
            }
            ForEach(facts.filter { $0.emphasis == .transition }) { fact in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fact.label).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                        Text(fact.value).font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(AppTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func comparisonColumn(title: String, facts: [InsightFact], tone: InsightTone) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.tone(tone))
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                    Text(fact.value).font(AppTypography.supporting).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(10)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func factRow(_ fact: InsightFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle().fill(AppTheme.tone(fact.emphasis)).frame(width: 5, height: 5)
            Text(fact.label).font(.caption).foregroundStyle(AppTheme.muted)
            Spacer(minLength: 5)
            Text(fact.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeledProgress(_ fact: InsightFact, value: Double) -> some View {
        VStack(spacing: 4) {
            factRow(fact)
            progressBar(value, tone: fact.emphasis)
        }
    }

    private func progressBar(_ value: Double, tone: InsightTone) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.line)
                Capsule()
                    .fill(AppTheme.tone(tone))
                    .frame(width: proxy.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 6)
    }

    private func balanceStrip(supportive: Int, challenging: Int, neutral: Int) -> some View {
        GeometryReader { proxy in
            let total = max(1, supportive + challenging + neutral)
            HStack(spacing: 2) {
                Capsule().fill(AppTheme.mint).frame(width: proxy.size.width * CGFloat(supportive) / CGFloat(total))
                Capsule().fill(AppTheme.coral).frame(width: proxy.size.width * CGFloat(challenging) / CGFloat(total))
                Capsule().fill(AppTheme.blue.opacity(0.75))
            }
        }
        .frame(height: 9)
    }

    private func ring(supportive: Int, challenging: Int, neutral: Int, size: CGFloat) -> some View {
        let total = max(1, supportive + challenging + neutral)
        let supportEnd = Double(supportive) / Double(total)
        let challengeEnd = supportEnd + Double(challenging) / Double(total)
        return ZStack {
            Circle().stroke(AppTheme.line, lineWidth: 10)
            Circle().trim(from: 0, to: supportEnd).stroke(AppTheme.mint, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().trim(from: supportEnd, to: challengeEnd).stroke(AppTheme.coral, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            Circle().trim(from: challengeEnd, to: 1).stroke(AppTheme.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(total)").font(.title3.bold().monospacedDigit()).foregroundStyle(AppTheme.text)
                Text(localized("aspects", "相位", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
            }
        }
        .frame(width: size, height: size)
    }

    private func phaseDisc(_ phase: Double, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
            Circle().trim(from: 0, to: phase / 360)
                .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(phase))°").font(.caption.bold()).foregroundStyle(AppTheme.text)
                Text(localized("phase", "月相", language: language)).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
            }
        }
        .frame(width: size, height: size)
    }

    private func metric(_ title: String, _ value: Int?, _ tone: InsightTone) -> some View {
        VStack(spacing: 3) {
            Text(value.map(String.init) ?? "—").font(.headline.monospacedDigit()).foregroundStyle(AppTheme.tone(tone))
            Text(title).font(.footnote).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }

    private func activityLabel(_ value: Int) -> String {
        switch value {
        case 0 ... 20: localized("Low", "低", language: language)
        case 21 ... 45: localized("Moderate", "中等", language: language)
        case 46 ... 70: localized("High", "高", language: language)
        default: localized("Very high", "极高", language: language)
        }
    }

    private var semicirclePath: Path {
        var path = Path()
        path.addArc(center: CGPoint(x: 145, y: 78), radius: 62, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        return path
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
    }

    private func radar(_ values: [Double]) -> some View {
        Canvas { context, size in
            let count = max(3, values.count)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.43
            for level in 1 ... 3 {
                context.stroke(polygon(center: center, radius: radius * Double(level) / 3, count: count), with: .color(AppTheme.line), lineWidth: 0.8)
            }
            var data = Path()
            for index in 0 ..< count {
                let value = values.indices.contains(index) ? max(0, min(1, values[index])) : 0
                let point = polygonPoint(center: center, radius: radius * value, index: index, count: count)
                index == 0 ? data.move(to: point) : data.addLine(to: point)
            }
            data.closeSubpath()
            context.fill(data, with: .color(AppTheme.violet.opacity(0.2)))
            context.stroke(data, with: .color(AppTheme.violet), lineWidth: 1.4)
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

    private func radialPoints(count: Int, size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.4
        return (0 ..< count).map { polygonPoint(center: center, radius: radius, index: $0, count: count) }
    }
}
