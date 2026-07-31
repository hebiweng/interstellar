import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedReport: SavedReport?
    @State private var showConsent = false
    @State private var generatingScope: ReportScope?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
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

                    sectionTitle(localized("Available", "可生成", language: model.language), sub: localized("Generate when ready", "到日子即可生成", language: model.language))
                    ForEach(model.availableReports) { report in
                        availableRow(report)
                    }

                    sectionTitle(localized("Saved", "已保存", language: model.language), sub: localized("Stored on device", "保存在本机", language: model.language))
                    if model.savedReports.isEmpty {
                        Text(localized("No reports yet. Chart reports are generated automatically once available.", "暂无报告。星盘报告会在就绪后自动生成。", language: model.language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .cardSurface()
                    } else {
                        ForEach(model.savedReports) { report in
                            savedRow(report)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(AppTheme.text)
                }
                .accessibilityLabel(localized("Back", "返回", language: model.language))
            }
        }
        .alert(localized("Allow network generation?", "允许联网生成？", language: model.language), isPresented: $showConsent) {
            Button(localized("Allow", "允许", language: model.language)) {
                model.grantAIConsent()
            }
            Button(localized("Not now", "暂不", language: model.language), role: .cancel) {}
        } message: {
            Text(localized(
                "Generating reports sends calculated chart data to the configured server. Results are cached on this device.",
                "生成报告会把计算好的星盘数据发送至配置的服务器。结果保存在本机。",
                language: model.language
            ))
        }
        .task {
            await model.refreshAvailableReports()
        }
        .fullScreenCover(item: $selectedReport) { report in
            ReportReaderView(report: report, language: model.language)
        }
    }

    @Environment(\.dismiss) private var dismiss

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
    @Environment(\.dismiss) private var dismiss
    @State private var sectionIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .cardSurface()

                        // Contents
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localized("Contents", "目录", language: language))
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                                Button {
                                    sectionIndex = index
                                } label: {
                                    HStack {
                                        Text("\(index + 1) · \(section.title)")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(index == sectionIndex ? AppTheme.violet : AppTheme.text)
                                        Spacer()
                                        Image(systemName: index == sectionIndex ? "arrow.down.circle.fill" : "circle")
                                            .font(.caption)
                                            .foregroundStyle(index == sectionIndex ? AppTheme.violet : AppTheme.muted)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .cardSurface()

                        // Sections
                        ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                            sectionCard(index: index, section: section)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
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
            }
            .navigationBarTitleDisplayMode(.inline)
        }
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
