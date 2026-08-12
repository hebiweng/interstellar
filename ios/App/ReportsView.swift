import SwiftUI
import AstroCore

struct ReportsView: View {
   let initialChart: ChartKind?
   @Binding var selectedTab: RootTab
   @EnvironmentObject private var model: AppModel
   @State private var selectedReport: SavedReport?
   @State private var showConsent = false
   @State private var generatingScope: ReportScope?
   @State private var pendingChart: ChartKind?
   @State private var pendingForceRegenerate = false
   @State private var pendingScope: ReportScope?
   @State private var hasHandledInitialChart = false
    @State private var generationSheetChart: ChartKind?
    @State private var generationWillReplace = false

    init(initialChart: ChartKind? = nil, selectedTab: Binding<RootTab>) {
        self.initialChart = initialChart
        _selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(
                        eyebrow: localized("reports.library", language: model.language),
                        title: localized("charts.reports", language: model.language),
                        subtitle: localized("reports.generated-once-kept-permanently", language: model.language)
                    )

                    Text(localized("reports.each-completed-report-is-stored-on-device-read-it-again-without-regenera", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .cardSurface()

                   sectionTitle(
                       localized("reports.chart-reports", language: model.language),
                       sub: localized("reports.generated-only-when-you-ask", language: model.language)
                   )
                   ForEach(orderedCharts) { chart in
                       chartReportRow(chart)
                   }

                   sectionTitle(localized("reports.saved", language: model.language), sub: localized("reports.stored-on-device", language: model.language))
                    if model.savedReports.isEmpty {
                        Text(localized("reports.no-reports-yet-choose-a-chart-above-and-generate-its-report-when-you-are", language: model.language))
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
        .alert(localized("ai.network-consent.title", language: model.language), isPresented: $showConsent) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                if let chart = pendingChart {
                    Task {
                        await model.generateAIReport(
                            for: chart,
                            forceRegenerate: pendingForceRegenerate
                        )
                    }
                } else if let scope = pendingScope {
                    generate(scope)
                }
                pendingChart = nil
                pendingForceRegenerate = false
                pendingScope = nil
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {
                pendingChart = nil
                pendingForceRegenerate = false
                pendingScope = nil
            }
        } message: {
            Text(localized("ai.network-consent.chart-message", language: model.language))
        }
       .task {
           model.refreshAIReportStates()
           if !hasHandledInitialChart, let initialChart, let saved = model.currentSavedReport(for: initialChart) {
               selectedReport = saved
               hasHandledInitialChart = true
           }
       }
        .sheet(item: $generationSheetChart) { chart in
            ReportGenerationSheet(
                chart: chart,
                replacesExisting: generationWillReplace,
                onGenerate: {
                    generationSheetChart = nil
                    requestChartGeneration(chart, force: generationWillReplace)
                },
                onEdit: {
                    generationSheetChart = nil
                    model.requestChartParameterEditing(chart)
                    selectedTab = .charts
                },
                onCancel: {
                    generationSheetChart = nil
                }
            )
        }
       .navigationDestination(
            isPresented: Binding(
                get: { selectedReport != nil },
                set: { if !$0 { selectedReport = nil } }
            )
        ) {
            if let report = selectedReport {
                ReportReaderView(
                    report: report,
                    language: model.language,
                    onRegenerate: regenerationAction(for: report)
                )
            }
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
                        Text(localized("reports.generate", language: model.language))
                            .font(.caption.weight(.semibold))
                            .frame(width: 76, height: 32)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.violet)
                .disabled(!model.isOnline || generatingScope != nil)
            } else {
                Text(localized("reports.locked", language: model.language))
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
                    Text(localized("reports.this-may-take-a-little-while-you-can-leave-this-page-and-come-back-later", language: model.language))
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
                   Button(localized("reports.view-report", language: model.language)) {
                       selectedReport = saved
                   }
                   .buttonStyle(.borderedProminent)
                   .tint(AppTheme.violet)

                   Button(localized("reports.regenerate", language: model.language)) {
                        openGenerationSheet(for: chart, replacing: true)
                   }
                   .buttonStyle(.bordered)
                   .tint(AppTheme.violet)
                   .disabled(status == .generating || !hasSnapshot || !model.isOnline)
               } else {
                   Button(localized("reports.generate-report", language: model.language)) {
                        openGenerationSheet(for: chart, replacing: false)
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
            return localized("reports.calculate-this-chart-first", language: model.language)
        }
        switch status {
        case .idle:
            return localized("reports.ready-to-generate", language: model.language)
        case .generating:
            return localized("reports.generating", language: model.language)
        case .ready:
            return localized("reports.saved-on-this-device", language: model.language)
        case .failed:
            return hasSavedReport
                ? localized("reports.regeneration-failed-your-saved-report-is-unchanged", language: model.language)
                : localized("reports.generation-failed-you-can-try-again", language: model.language)
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

   private func requestChartGeneration(
       _ chart: ChartKind,
       force: Bool
   ) {
       guard model.aiConsentGranted else {
           pendingChart = chart
           pendingForceRegenerate = force
           pendingScope = nil
           showConsent = true
           return
       }
       Task {
           await model.generateAIReport(
               for: chart,
               forceRegenerate: force
           )
       }
   }

    private func openGenerationSheet(for chart: ChartKind, replacing: Bool) {
        generationWillReplace = replacing
        generationSheetChart = chart
    }

    private func regenerationAction(for report: SavedReport) -> (() -> Void)? {
        guard let chart = ChartKind.allCases.first(where: {
            report.scope == "chart.\($0.contentPrefix)" && model.currentSavedReport(for: $0)?.id == report.id
        }) else { return nil }
        return {
            selectedReport = nil
            openGenerationSheet(for: chart, replacing: true)
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
            return localized("reports.ready-to-generate", language: model.language)
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
    @State private var sectionIndex = 0

    init(report: SavedReport, language: AppLanguage, onRegenerate: (() -> Void)? = nil) {
        self.report = report
        self.language = language
        self.onRegenerate = onRegenerate
    }

    var body: some View {
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
                                HStack {
                                    Text("\(savedReportScopeTitle(report.scope, language: language)) · \(report.generatedAt.shortEventDate(language: language))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                .padding(.top, 6)
                            }
                            .id(-1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .cardSurface()

                            // Contents (RR-02): numbered rows that jump to each section
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localized("reports.contents", language: language))
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
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if onRegenerate != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("reports.regenerate", language: language)) {
                        onRegenerate?()
                    }
                    .foregroundStyle(AppTheme.violet)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Report generation sheet

struct ReportGenerationSheet: View {
    let chart: ChartKind
    let replacesExisting: Bool
    let onGenerate: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(localized("reports.generate-report", language: model.language))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(replacesExisting
                         ? localized("reports.current-information-will-replace", language: model.language)
                         : localized("reports.current-information-confirmation", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        ForEach(Array(contextRows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Divider().overlay(AppTheme.line) }
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(row.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                                    .frame(width: 86, alignment: .leading)
                                Text(row.value)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .cardSurface()

                    HStack(spacing: 12) {
                        Button(localized("reports.edit", language: model.language)) {
                            onEdit()
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.muted)

                        Button(localized("reports.generate", language: model.language)) {
                            onGenerate()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.violet)
                    }
                }
                .padding(17)
                .padding(.top, 8)
            }
            .background(AppTheme.background)
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(localized("reports.generate-report", language: model.language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("location.cancel", language: model.language)) { onCancel() }
                }
            }
        }
    }

    private var contextRows: [(label: String, value: String)] {
        var rows: [(String, String)] = [
            (localized("reports.chart", language: model.language), chart.title(language: model.language))
        ]
        if chart == .synastry {
            if let people = model.synastryReportPeople {
                rows.append((localized("charts.people", language: model.language), "\(people.first) ↔ \(people.second)"))
            }
        } else if chart != .currentSky {
            rows.append((localized("charts.person", language: model.language), model.chartSubjectProfile.name))
        }
        switch model.chartContext(for: chart).target {
        case .natal:
            rows.append((localized("charts.date-time", language: model.language), formatted(model.chartSubjectProfile.birthDateUTC, timeZoneID: model.chartSubjectProfile.timezoneID)))
            rows.append((localized("charts.reference-location", language: model.language), model.chartSubjectProfile.placeName))
        case let .currentSky(instant, location, _):
            rows.append((localized("charts.date-time", language: model.language), formatted(instant, timeZoneID: location.timezoneID)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case let .transit(instant, location, rangeDays, _):
            rows.append((localized("charts.target-time", language: model.language), formatted(instant, timeZoneID: location.timezoneID)))
            rows.append((localized("charts.range", language: model.language), rangeLabel(rangeDays)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case let .secondary(targetDate, _):
            rows.append((localized("charts.target-date", language: model.language), formatted(targetDate, timeZoneID: model.chartSubjectProfile.timezoneID, dateOnly: true)))
        case let .solarReturn(year, location):
            rows.append((localized("charts.return-year", language: model.language), String(year)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case .synastry:
            break
        }
        rows.append((localized("reports.preset", language: model.language), model.preset(for: chart).title(language: model.language)))
        return rows
    }

    private func formatted(_ date: Date, timeZoneID: String, dateOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = dateOnly ? .none : .short
        return formatter.string(from: date)
    }

    private func rangeLabel(_ days: Int) -> String {
        switch days {
        case 7: localized("charts.7-days", language: model.language)
        case 365: localized("charts.12-months", language: model.language)
        default: localized("charts.30-days", language: model.language)
        }
    }
}
