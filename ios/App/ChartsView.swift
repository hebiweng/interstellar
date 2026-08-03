import AstroCore
import SwiftUI

struct ChartsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAIConsent = false
    @State private var showLocationPicker = false
    @State private var showReports = false
    @State private var showParameters = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        let insightState = model.insightCards(for: model.selectedChart)
                        topBar
                        chartSelector

                        if model.focusedChart == model.selectedChart,
                           let date = model.focusedChartDate
                        {
                            eventTimeContext(date)
                        }

                        chartControlBar
                        chartContent

                        if !insightState.cards.isEmpty {
                            ForEach(insightState.cards) { card in
                                VStack(alignment: .leading, spacing: 10) {
                                    cardSectionHeader(card)
                                    InsightCardView(
                                        card: card,
                                        language: model.language,
                                        prototypeTransitStyle: isModernTransitCard(card.id),
                                        externalHeaderStyle: true
                                    )
                                }
                            }
                        } else if let message = insightState.errorMessage,
                                  model.snapshot(for: model.selectedChart) != nil
                        {
                            Label(message, systemImage: "doc.text.magnifyingglass")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardSurface()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await model.refresh()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReports) {
                ReportsView()
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationSearchView(language: model.language) { selection in
                    model.setReferenceLocation(selection, for: model.selectedChart)
                    showLocationPicker = false
                }
            }
            .sheet(isPresented: $showParameters) {
                NavigationStack {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            chartParameters
                            presetSelector
                        }
                        .padding(18)
                    }
                    .background(ScreenBackground())
                    .navigationTitle(localized("charts.parameters.sheet-title", default: "Parameters", chinese: "参数设置", language: model.language))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(localized("Done", "完成", language: model.language)) {
                                showParameters = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .task(id: model.selectedChart) {
                if !model.aiConsentGranted, model.isOnline, model.snapshot(for: model.selectedChart) != nil {
                    showAIConsent = true
                } else {
                    model.ensureAIGeneration(for: model.selectedChart)
                }
            }
            .alert(
                localized("charts.ai.network-consent.title", default: "Allow network generation?", chinese: "允许联网生成解读？", language: model.language),
                isPresented: $showAIConsent
            ) {
                Button(localized("Allow", "允许", language: model.language)) {
                    model.grantAIConsent()
                    model.ensureAIGeneration(for: model.selectedChart)
                }
                Button(localized("Not now", "暂不", language: model.language), role: .cancel) {}
            } message: {
                Text(localized(
                    "Interstellar sends only this chart's calculated facts and requested card IDs to the configured AI service. The relay may keep an encrypted idempotency result for up to 24 hours; your device keeps the long-term report until you delete it in Settings. You can revoke future network generation at any time.",
                    "Interstellar 只会把本盘的计算事实和所需卡片 ID 发送给配置的 AI 服务。中继服务最多保留 24 小时的加密幂等结果；长期报告只保存在本机，直到你在设置中删除。你可以随时撤回后续联网生成授权。",
                    language: model.language
                ))
            }
        }
    }

    private func cardSectionHeader(_ card: InsightCardModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(cardSectionTitle(card))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(cardSectionSubtitle(card))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.top, 7)
    }

    private func isModernTransitCard(_ cardID: String) -> Bool {
        model.selectedChart == .transit
            && model.preset(for: .transit) == .modern
            && TransitContentPlan.cardIDs.contains(cardID)
    }

    private func cardSectionTitle(_ card: InsightCardModel) -> String {
        isModernTransitCard(card.id) ? transitSectionTitle(card.id) : card.title
    }

    private func cardSectionSubtitle(_ card: InsightCardModel) -> String {
        if isModernTransitCard(card.id) {
            return transitSectionSubtitle(card.id)
        }
        return cardKicker(card.id, language: model.language) ?? ""
    }

    private func transitSectionTitle(_ cardID: String) -> String {
        switch cardID {
        case "current-story": localized("Current Story", "当前主线", language: model.language)
        case "current-cycles": localized("Current Cycles", "当前周期", language: model.language)
        case "transit-timeline": localized("Transit Timeline", "行运时间线", language: model.language)
        case "planet-paths": localized("Planet Paths", "行星路径", language: model.language)
        case "life-areas": localized("Life Areas", "生活领域", language: model.language)
        case "active-transits": localized("Active Transits", "进行中的行运", language: model.language)
        default: cardID
        }
    }

    private func transitSectionSubtitle(_ cardID: String) -> String {
        switch cardID {
        case "current-story": localized("How the strongest cycles combine", "最强周期如何共同作用", language: model.language)
        case "current-cycles": localized("One theme per time scale", "每个时间尺度一个主题", language: model.language)
        case "transit-timeline": localized("Start · Exact · Return · End", "开始 · 精确 · 回返 · 结束", language: model.language)
        case "planet-paths": localized("Where the current planets are moving", "当前行星正在经过哪里", language: model.language)
        case "life-areas": localized("Activity, not fortune", "活跃度，不是运气", language: model.language)
        case "active-transits": localized("Complete filtered list", "完整筛选列表", language: model.language)
        default: ""
        }
    }

    private var topBar: some View {
        HStack {
            Text(localized("Charts", "星盘", language: model.language))
                .font(.system(size: 30, weight: .bold))
                .kerning(-1)
                .foregroundStyle(AppTheme.text)
            Spacer()
            Button { showReports = true } label: {
                Label(localized("Reports", "报告", language: model.language), systemImage: "doc.text.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.violet.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var chartControlBar: some View {
        HStack(spacing: 10) {
            viewSelector
            Button { showParameters = true } label: {
                Label(localized("charts.parameters.button", default: "Parameters", chinese: "参数", language: model.language), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.violet.opacity(0.22)))
            }
            .buttonStyle(.plain)
        }
    }

    private var profileStrip: some View {
        HStack(spacing: 12) {
            Text(String(model.profile.name.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 38, height: 38)
                .background(AppTheme.violet.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.profile.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                Text(birthInfo)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            TagChip(
                text: model.preset(for: model.selectedChart).title(language: model.language),
                tone: .neutral
            )
        }
        .padding(15)
        .cardSurface()
    }

    private var birthInfo: String {
        let subject = model.chartSubjectProfile
        let timeZone = TimeZone(identifier: subject.timezoneID) ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy · HH:mm"
        let date = formatter.string(from: subject.birthDateUTC)
        return "\(date) · \(subject.placeName)"
    }

    private var chartSubtitle: String {
        switch model.selectedChart {
        case .natal:
            return "\(model.profile.name) · \(model.profile.placeName)"
        case .currentSky:
            return localized("Live sky at the saved location", "保存地点的当前天空", language: model.language)
        case .transit:
            return localized("Current sky compared with the natal chart", "当前天空与本命盘的比较", language: model.language)
        case .secondary:
            return localized("Day-for-a-year secondary progressions", "一日一年法次限推运", language: model.language)
        case .solarReturn:
            return localized("The year that begins at your next solar return", "下一个日返时刻开启的年度盘", language: model.language)
        case .synastry:
            return localized("How two natal charts meet", "两张本命盘如何相遇", language: model.language)
        }
    }

    private var chartSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(ChartKind.allCases) { chart in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.selectChart(chart)
                        }
                    } label: {
                        Text(chart.title(language: model.language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.selectedChart == chart ? Color.white : AppTheme.muted)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(
                                model.selectedChart == chart ? AppTheme.violet.opacity(0.92) : AppTheme.panel,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    model.selectedChart == chart ? AppTheme.violet.opacity(0.7) : AppTheme.line
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var chartParameters: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.selectedChart != .currentSky {
                Text(localized("Person", "人物", language: model.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Picker(localized("Person", "人物", language: model.language), selection: $model.chartSubjectID) {
                    Text(model.profile.name).tag("self")
                    ForEach(model.savedPeople) { person in
                        Text(person.profile.name).tag(person.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
            }
        }

        switch model.selectedChart {
        case .natal:
            parameterSummary(
                title: localized("Birth data", "出生资料", language: model.language),
                value: birthInfo,
                systemImage: "person.text.rectangle"
            )
        case .currentSky:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.parameters.back-to-now", default: "Back to now", chinese: "回到现在", language: model.language))
                DatePicker(
                    localized("Date & time", "日期与时间", language: model.language),
                    selection: targetDateBinding(for: .currentSky)
                )
                .datePickerStyle(.compact)
                locationButton(model.currentSkyLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()
        case .transit:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("Use current defaults", "恢复当前默认值", language: model.language))
                DatePicker(
                    localized("Target time", "目标时间", language: model.language),
                    selection: targetDateBinding(for: .transit)
                )
                .datePickerStyle(.compact)
                Picker(localized("Range", "范围", language: model.language), selection: transitRangeBinding) {
                    Text(localized("30 days", "30 天", language: model.language)).tag(30)
                    Text(localized("7 days", "7 天", language: model.language)).tag(7)
                    Text(localized("12 months", "12 个月", language: model.language)).tag(365)
                }
                .pickerStyle(.segmented)
                locationButton(model.transitLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()
        case .secondary:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("Back to today", "回到今天", language: model.language))
                DatePicker(
                    localized("Target date", "目标日期", language: model.language),
                    selection: targetDateBinding(for: .secondary),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                Text(localized(
                    "Secondary progressions use the birth place and do not relocate in this version.",
                    "本版次限盘沿用出生地点，不提供独立迁移地点。",
                    language: model.language
                ))
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            }
            .cardSurface()
        case .solarReturn:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("Current return year", "当前日返年度", language: model.language))
                Stepper(value: solarYearBinding, in: 1900 ... 2200) {
                    parameterSummary(
                        title: localized("Return year", "日返年度", language: model.language),
                        value: String(model.solarReturnYear),
                        systemImage: "calendar"
                    )
                }
                locationButton(model.solarReturnLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()
        case .synastry:
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("Compare with", "另一位人物", language: model.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Picker(localized("Person", "人物", language: model.language), selection: $model.synastryPartnerID) {
                    Text(localized("Choose a saved person", "选择已保存人物", language: model.language)).tag(String?.none)
                    if model.chartSubjectID != "self" {
                        Text(model.profile.name).tag(String?.some("self"))
                    }
                    ForEach(model.savedPeople) { person in
                        if person.id.uuidString != model.chartSubjectID {
                            Text(person.profile.name).tag(String?.some(person.id.uuidString))
                        }
                    }
                }
                .pickerStyle(.menu)
            }
            .cardSurface()
        }
    }

    private func parameterHeader(resetTitle: String) -> some View {
        HStack {
            Text(localized("Chart parameters", "星盘参数", language: model.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Button(resetTitle) { model.resetTarget(for: model.selectedChart) }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
        }
    }

    private func parameterSummary(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                Text(value).font(.footnote).foregroundStyle(AppTheme.muted).lineLimit(2)
            }
            Spacer()
        }
    }

    private func locationButton(_ placeName: String) -> some View {
        Button { showLocationPicker = true } label: {
            parameterSummary(
                title: localized("Reference location", "参考地点", language: model.language),
                value: placeName,
                systemImage: "mappin.and.ellipse"
            )
        }
        .buttonStyle(.plain)
    }

    private func targetDateBinding(for chart: ChartKind) -> Binding<Date> {
        Binding(
            get: {
                switch chart {
                case .currentSky: model.currentSkyUsesLiveDefault ? Date() : model.currentSkyTargetDate
                case .transit: model.transitUsesLiveDefault ? Date() : model.transitTargetDate
                case .secondary: model.secondaryUsesLiveDefault ? Date() : model.secondaryTargetDate
                default: Date()
                }
            },
            set: { model.setTargetDate($0, for: chart) }
        )
    }

    private var transitRangeBinding: Binding<Int> {
        Binding(get: { model.transitRangeDays }, set: { model.setTransitRangeDays($0) })
    }

    private var solarYearBinding: Binding<Int> {
        Binding(
            get: { model.solarReturnYear },
            set: { year in
                var components = DateComponents()
                components.year = year
                components.month = 1
                components.day = 1
                model.setTargetDate(Calendar.current.date(from: components) ?? Date(), for: .solarReturn)
            }
        )
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(localized("Preset", "参数预设", language: model.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 8) {
                ForEach(CalculationPreset.consumerCases) { preset in
                    let selected = model.preset(for: model.selectedChart) == preset
                    Button {
                        model.setPreset(preset, for: model.selectedChart)
                    } label: {
                        VStack(spacing: 3) {
                            Text(preset.title(language: model.language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selected ? Color.white : AppTheme.text)
                            Text(preset.subtitle(language: model.language))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(selected ? Color.white.opacity(0.82) : AppTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected ? AppTheme.violet.opacity(0.92) : AppTheme.panel,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(selected ? AppTheme.violet.opacity(0.65) : AppTheme.line)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var viewSelector: some View {
        HStack(spacing: 6) {
            modeButton(.wheel, icon: "circle.hexagongrid")
            modeButton(.aspects, icon: "square.grid.3x3")
        }
        .padding(4)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private func modeButton(_ mode: ChartViewMode, icon: String) -> some View {
        let selected = model.viewMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.viewMode = mode
            }
        } label: {
            Label(
                mode == .wheel
                    ? localized("Wheel", "轮盘", language: model.language)
                    : localized("Aspects", "相位矩阵", language: model.language),
                systemImage: icon
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? Color.white : AppTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? AppTheme.violet.opacity(0.92) : .clear, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chartContent: some View {
        if (model.isCalculating || model.isCalculatingFocus),
           model.snapshot(for: model.selectedChart) == nil
        {
            HStack(spacing: 12) {
                ProgressView().tint(AppTheme.violet)
                Text(localized("Calculating chart locally…", "正在本机计算星盘…", language: model.language))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .cardSurface()
        } else if let snapshot = model.snapshot(for: model.selectedChart) {
            if model.viewMode == .wheel {
                ChartWheelView(
                    snapshot: snapshot,
                    reference: model.referenceSnapshot(for: model.selectedChart),
                    comparisonAspects: model.selectedChart.isComparison
                        ? model.comparisonAspects(for: model.selectedChart)
                        : [],
                    language: model.language
                )
                .padding(12)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
            } else {
                AspectChartView(
                    aspects: model.comparisonAspects(for: model.selectedChart),
                    movingPoints: snapshot.points,
                    referencePoints: model.selectedChart.isComparison
                        ? model.referenceSnapshot(for: model.selectedChart)?.points ?? []
                        : [],
                    language: model.language,
                    comparison: model.selectedChart.isComparison
                )
            }
        } else if let message = model.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity, minHeight: 180)
                .cardSurface()
        }
    }

    private func eventTimeContext(_ date: Date) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 3) {
                Text(localized("Event-time chart", "事件时刻星盘", language: model.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(formattedEventDate(date))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button(localized("charts.event.back-to-now", default: "Back to now", chinese: "返回现在", language: model.language)) {
                model.clearChartFocus()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.violet)
        }
        .cardSurface()
    }

    private func formattedEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
