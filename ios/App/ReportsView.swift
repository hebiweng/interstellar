import SwiftUI

struct ReportsView: View {
    let initialChart: ChartKind?
    @EnvironmentObject private var model: AppModel
    @State private var selectedReport: SavedReport?
    @State private var showConsent = false
    @State private var generatingScope: ReportScope?
    @State private var pendingChart: ChartKind?
    @State private var pendingForceRegenerate = false
    @State private var pendingScope: ReportScope?

    init(initialChart: ChartKind? = nil) {
        self.initialChart = initialChart
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(
                        eyebrow: localized("LIBRARY", "报告库", language: model.language),
                        title: localized("Reports", "报告", language: model.language),
                        subtitle: localized("Generated once. Kept permanently.", "生成一次，永久保留。", language: model.language)
                    )

                    Text(localized("Each completed report is stored on device. Read it again without regenerating the same chart or period.", "每份完成的报告都保存在本机，随时可重读，无需重新生成。", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .cardSurface()

                    sectionTitle(
                        localized("Chart Reports", "星盘报告", language: model.language),
                        sub: localized("Generated only when you ask", "仅在你点击后生成", language: model.language)
                    )
                    ForEach(orderedCharts) { chart in
                        chartReportRow(chart)
                    }

                    sectionTitle(localized("Period Reports", "周期报告", language: model.language), sub: localized("Generate when ready", "到日子即可生成", language: model.language))
                    ForEach(model.availableReports) { report in
                        availableRow(report)
                    }

                    sectionTitle(localized("Saved", "已保存", language: model.language), sub: localized("Stored on device", "保存在本机", language: model.language))
                    if model.savedReports.isEmpty {
                        Text(localized("No reports yet. Choose a chart above and generate its report when you are ready.", "暂无报告。请在上方选择一个星盘，并在需要时生成报告。", language: model.language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .cardSurface()
                    } else {
                        ForEach(model.savedReports) { report in
                            savedRow(report)
                        }
                    }
                }
                .padding(.horizontal, 17)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert(localized("ai.network-consent.title", default: "Allow network generation?", chinese: "允许联网生成？", language: model.language), isPresented: $showConsent) {
            Button(localized("Allow", "允许", language: model.language)) {
                model.grantAIConsent()
                if let chart = pendingChart {
                    model.generateAIReport(for: chart, forceRegenerate: pendingForceRegenerate)
                } else if let scope = pendingScope {
                    generate(scope)
                }
                pendingChart = nil
                pendingForceRegenerate = false
                pendingScope = nil
            }
            Button(localized("Not now", "暂不", language: model.language), role: .cancel) {
                pendingChart = nil
                pendingForceRegenerate = false
                pendingScope = nil
            }
        } message: {
            Text(localized(
                "Interstellar sends the selected chart's calculated facts to the configured AI service only after you tap Generate. The relay may keep an encrypted idempotency result for up to 24 hours; your device keeps the long-term report until you delete it in Settings. You can revoke future network generation at any time.",
                "只有在你点击生成后，Interstellar 才会把所选星盘的计算事实发送给配置的 AI 服务。中继服务最多保留 24 小时的加密幂等结果；长期报告只保存在本机，直到你在设置中删除。你可以随时撤回后续联网生成授权。",
                language: model.language
            ))
        }
        .task {
            model.refreshAIReportStates()
            await model.refreshAvailableReports()
            if let initialChart, let saved = model.currentSavedReport(for: initialChart) {
                selectedReport = saved
            }
        }
        .fullScreenCover(item: $selectedReport) { report in
            ReportReaderView(
                report: report,
                language: model.language,
                onRegenerate: regenerationAction(for: report)
            )
        }
    }

    private var orderedCharts: [ChartKind] {
        guard let initialChart else { return ChartKind.allCases }
        return [initialChart] + ChartKind.allCases.filter { $0 != initialChart }
    }

    private func sectionTitle(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(AppTheme.text)
            Text(sub).font(.caption).foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 4)
    }

    private func availableRow(_ report: AvailableReport) -> some View {
        let unlocked = report.isUnlocked
        return HStack(spacing: 12) {
            Text(symbol(report.scope))
                .font(.title2)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 40, height: 40)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(report.scope.title(language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(report.scope.subtitle(language: model.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Text(statusText(report))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(unlocked ? AppTheme.mint : AppTheme.amber)
            }
            Spacer()
            if unlocked {
                Button {
                    if !model.aiConsentGranted {
                        pendingChart = nil
                        pendingScope = report.scope
                        showConsent = true
                    } else {
                        generate(report.scope)
                    }
                } label: {
                    if generatingScope == report.scope {
                        ProgressView().controlSize(.small).tint(.white)
                            .frame(width: 76, height: 32)
                    } else {
                        Text(localized("Generate", "生成", language: model.language))
                            .font(.caption.weight(.semibold))
                            .frame(width: 76, height: 32)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.violet)
                .disabled(!model.isOnline || generatingScope != nil)
            } else {
                Text(localized("Locked", "未到日期", language: model.language))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .cardSurface()
        .opacity(unlocked ? 1 : 0.7)
    }

    @ViewBuilder
    private func chartReportRow(_ chart: ChartKind) -> some View {
        let hasSnapshot = model.snapshot(for: chart) != nil
        let saved = model.currentSavedReport(for: chart)
        let status = model.aiReportStatus(for: chart)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(savedReportScopeSymbol("chart.\(chart.contentPrefix)"))
                    .font(.title2)
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(savedReportScopeTitle("chart.\(chart.contentPrefix)", language: model.language))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(chartStatusText(status, hasSnapshot: hasSnapshot, hasSavedReport: saved != nil))
                        .font(.caption)
                        .foregroundStyle(chartStatusColor(status, hasSnapshot: hasSnapshot))
                }
                Spacer()
            }

            if case .generating = status {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small).tint(AppTheme.violet)
                    Text(localized(
                        "This may take a little while. You can leave this page and come back later.",
                        "生成可能需要一点时间，你可以先离开，稍后再回来查看。",
                        language: model.language
                    ))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                }
            }

            if case let .failed(message) = status {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if let saved {
                    Button(localized("View Report", "查看报告", language: model.language)) {
                        selectedReport = saved
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)

                    Button(localized("Regenerate", "重新生成", language: model.language)) {
                        requestChartGeneration(chart, force: true)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.violet)
                    .disabled(status == .generating || !hasSnapshot || !model.isOnline)
                } else {
                    Button(localized("Generate Report", "生成报告", language: model.language)) {
                        requestChartGeneration(chart, force: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)
                    .disabled(status == .generating || !hasSnapshot || !model.isOnline)
                }
            }
        }
        .cardSurface()
        .overlay {
            if initialChart == chart {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.violet.opacity(0.35), lineWidth: 1)
            }
        }
        .opacity(hasSnapshot ? 1 : 0.65)
    }

    private func chartStatusText(
        _ status: AIReportGenerationStatus,
        hasSnapshot: Bool,
        hasSavedReport: Bool
    ) -> String {
        guard hasSnapshot else {
            return localized("Calculate this chart first", "请先完成该盘计算", language: model.language)
        }
        switch status {
        case .idle:
            return localized("Ready to generate", "可以生成", language: model.language)
        case .generating:
            return localized("Generating…", "正在生成…", language: model.language)
        case .ready:
            return localized("Saved on this device", "已保存在本机", language: model.language)
        case .failed:
            return hasSavedReport
                ? localized("Regeneration failed; your saved report is unchanged", "重新生成失败；原报告仍保留", language: model.language)
                : localized("Generation failed. You can try again.", "生成失败，可以重试。", language: model.language)
        }
    }

    private func chartStatusColor(_ status: AIReportGenerationStatus, hasSnapshot: Bool) -> Color {
        guard hasSnapshot else { return AppTheme.muted }
        return switch status {
        case .ready: AppTheme.mint
        case .failed: AppTheme.coral
        case .generating: AppTheme.violet
        case .idle: AppTheme.muted
        }
    }

    private func requestChartGeneration(_ chart: ChartKind, force: Bool) {
        guard model.aiConsentGranted else {
            pendingChart = chart
            pendingForceRegenerate = force
            pendingScope = nil
            showConsent = true
            return
        }
        model.generateAIReport(for: chart, forceRegenerate: force)
    }

    private func regenerationAction(for report: SavedReport) -> (() -> Void)? {
        guard let chart = ChartKind.allCases.first(where: {
            report.scope == "chart.\($0.contentPrefix)" && model.currentSavedReport(for: $0)?.id == report.id
        }) else { return nil }
        return {
            selectedReport = nil
            requestChartGeneration(chart, force: true)
        }
    }

    private func savedRow(_ report: SavedReport) -> some View {
        Button {
            selectedReport = report
        } label: {
            HStack(spacing: 12) {
                Text(savedReportScopeSymbol(report.scope))
                    .font(.title2)
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(savedReportScopeTitle(report.scope, language: model.language)).font(.headline).foregroundStyle(AppTheme.text)
                    Text(report.subtitle).font(.caption).foregroundStyle(AppTheme.muted)
                    Text(shortDate(report.generatedAt))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
    }

    private func symbol(_ scope: ReportScope) -> String {
        switch scope {
        case .daily: "☾"
        case .monthly: "◐"
        case .solarReturn: "☉"
        }
    }

    private func statusText(_ report: AvailableReport) -> String {
        if report.isUnlocked {
            return localized("Ready to generate", "可以生成", language: model.language)
        }
        let timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        return report.countdown(language: model.language, timeZone: timeZone)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func generate(_ scope: ReportScope) {
        generatingScope = scope
        Task {
            await model.generatePeriodReport(scope)
            generatingScope = nil
        }
    }
}

struct ReportReaderView: View {
    let report: SavedReport
    let language: AppLanguage
    let onRegenerate: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var sectionIndex = 0
    @State private var scrollID: Int? = 0

    init(report: SavedReport, language: AppLanguage, onRegenerate: (() -> Void)? = nil) {
        self.report = report
        self.language = language
        self.onRegenerate = onRegenerate
    }

    private var readProgress: Double {
        let count = max(1, report.report.sections.count)
        if let scrollID, scrollID >= 0 {
            return min(1, Double(scrollID + 1) / Double(count))
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 16) {
                            // Cover
                            VStack(alignment: .leading, spacing: 8) {
                                Text(savedReportScopeTitle(report.scope, language: language).uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(1.4)
                                    .foregroundStyle(AppTheme.violet)
                                Text(report.report.title)
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                Text(report.report.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                // Reading progress (RR-01): width equals actual reading position
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 5)
                                        Capsule()
                                            .fill(LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: proxy.size.width * readProgress, height: 5)
                                    }
                                }
                                .frame(height: 5)
                                .padding(.top, 10)
                                HStack {
                                    Text("\(savedReportScopeTitle(report.scope, language: language)) · \(report.generatedAt.shortEventDate(language: language))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                    Spacer()
                                    Text("\(Int(readProgress * 100))% read")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.violet)
                                }
                                .padding(.top, 6)
                            }
                            .id(-1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .cardSurface()

                            // Contents (RR-02): numbered rows with estimated reading time, tap jumps to section
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localized("Contents", "目录", language: language))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                                    Button {
                                        sectionIndex = index
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            proxy.scrollTo(index, anchor: .top)
                                        }
                                    } label: {
                                        HStack {
                                            Text("\(index + 1) · \(section.title)")
                                                .font(.footnote.weight(.medium))
                                                .foregroundStyle(index == sectionIndex ? AppTheme.violet : AppTheme.text)
                                            Spacer()
                                            Text(readingTime(section.body))
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().overlay(AppTheme.line.opacity(0.5))
                                }
                            }
                            .padding(16)
                            .cardSurface()

                            // Sections
                            ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                                sectionCard(index: index, section: section)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 30)
                    }
                }
                .scrollPosition(id: $scrollID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left").foregroundStyle(AppTheme.text)
                    }
                    .accessibilityLabel(localized("Back", "返回", language: language))
                }
                if let onRegenerate {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(localized("Regenerate", "重新生成", language: language)) {
                            onRegenerate()
                        }
                        .foregroundStyle(AppTheme.violet)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func readingTime(_ body: String) -> String {
        let words = max(1, body.split(whereSeparator: { $0.isWhitespace }).count)
        let minutes = max(1, Int((Double(words) / 200.0).rounded()))
        return LocalizedFormatters.readingMinutes(minutes, language: language)
    }

    private func sectionCard(index: Int, section: AIReportSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%02d · %@", index + 1, section.title.uppercased()))
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.violet)
            Text(section.body)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .lineSpacing(5)
            if let callout = section.callout, !callout.isEmpty {
                Text(callout)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.violet)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .cardSurface()
    }
}
