import AstroCore
import SwiftUI

struct ChartsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        let insightState = model.insightCards(for: model.selectedChart)
                        ScreenTitle(
                            eyebrow: model.selectedChart.eyebrow(language: model.language),
                            title: model.selectedChart.title(language: model.language),
                            subtitle: chartSubtitle
                        )

                        if model.focusedChart == model.selectedChart,
                           let date = model.focusedChartDate
                        {
                            eventTimeContext(date)
                        }

                        chartSelector
                        presetSelector
                        viewSelector
                        chartContent

                        if !insightState.cards.isEmpty {
                            Text(localized("Insights", "解读", language: model.language))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .padding(.top, 2)

                            ForEach(insightState.cards) { card in
                                InsightCardView(card: card, language: model.language)
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
        }
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
            Button(localized("Back to now", "返回现在", language: model.language)) {
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
