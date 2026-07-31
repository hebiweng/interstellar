import AstroCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: RootTab
    @State private var showReports = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        topBar
                        dateLine

                        if model.isCalculating || model.currentSky == nil {
                            loadingCard
                        } else {
                            transitsSection
                            moonSection
                            timelineSection
                            upcomingSection
                            retrogradesSection
                            skyLinkCard
                        }

                        if let message = model.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.coral)
                                .cardSurface()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
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
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Interstellar")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(AppTheme.violet)
                Text(localized("Today", "今日", language: model.language))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
            Spacer()
            Button {
                if !model.aiConsentGranted {
                    // The Reports screen shows its own consent prompt before generating.
                }
                showReports = true
            } label: {
                Label(localized("Reports", "报告", language: model.language), systemImage: "doc.text.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.violet.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var dateLine: some View {
        HStack(spacing: 6) {
            Text(formattedDate(Date()))
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
            Text("·")
                .foregroundStyle(AppTheme.muted)
            Text(model.profile.placeName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
            Text("·")
                .foregroundStyle(AppTheme.muted)
            Text(model.profile.name)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
        }
    }

    // MARK: - Your Transits

    private var transitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead(localized("Your Transits", "你的近期变化", language: model.language), link: localized("View all", "查看全部", language: model.language))
            chapterHero
            VStack(spacing: 9) {
                ForEach(Array(model.todaySignals.prefix(2).enumerated()), id: \.offset) { index, signal in
                    transitRow(signal, isFirst: index == 0)
                }
            }
        }
    }

    private var chapterHero: some View {
        let strongest = model.transitAspects.first
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("CURRENT CHAPTER", "当前章节", language: model.language))
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.violet)
                    Text(strongest.map { aspectTitle($0, language: model.language) } ?? localized("A quieter stretch", "相对平稳的一段时间", language: model.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(strongest.map {
                        "\(phaseLabel($0.phase, language: model.language)) · \(ConsumerCopy.intensity($0.strength, language: model.language))"
                    } ?? localized("Nothing is exact today, but a few themes are slowly developing.", "今天没有精确到点的变化，但有几个主题正在慢慢发展。", language: model.language))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(localized("Long-term", "长期", language: model.language))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.violet.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 7) {
                Text(localized("Home & inner life", "家庭与内在生活", language: model.language))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                Text(localized("Exact again soon", "近期会再次精确", language: model.language))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.top, 2)
        }
        .padding(15)
        .cardSurface()
    }

    private func transitRow(_ signal: DailySignal, isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(signal.source.symbol)
                .font(.title3)
                .foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 4) {
                Text(isFirst ? localized("ACTIVE TODAY", "今天活跃", language: model.language) : localized("COMING NEXT", "接下来", language: model.language))
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(isFirst ? AppTheme.amber : AppTheme.mint)
                Text(signal.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signal.subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(13)
        .cardSurface()
    }

    // MARK: - Moon Today

    private var moonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead(localized("Moon Today", "今日月亮", language: model.language), sub: localized("Changes quickly", "变化很快", language: model.language))
            if let moon = model.currentSky?.point(.moon) {
                let house = model.currentSky?.house(containing: moon.longitudeDegrees) ?? 0
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                        Circle().trim(from: 0, to: max(0.02, illumination))
                            .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("☽").font(.title3).foregroundStyle(AppTheme.text)
                    }
                    .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(Int(illumination * 100))% \(localized("illuminated", "照亮", language: model.language))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                        Text("\(localized("Moon in", "月亮在", language: model.language)) \(Zodiac.name(index: moon.signIndex, language: model.language))")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("\(moonPhaseName) · \(localized("Moving through your", "正经过你的", language: model.language)) \(ConsumerCopy.lifeArea(house, language: model.language))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                        HStack(spacing: 6) {
                            Text(Zodiac.position(moon, language: model.language))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.muted)
                            Text(localized("Next sign change soon", "即将换座", language: model.language))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                }
                .padding(15)
                .cardSurface()
            }
        }
    }

    private var moonPhaseAngle: Double {
        guard let sky = model.currentSky,
              let sun = sky.point(.sun), let moon = sky.point(.moon)
        else { return 0 }
        let raw = (moon.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    private var illumination: Double {
        (1 - cos(moonPhaseAngle * .pi / 180)) / 2
    }

    private var moonPhaseName: String {
        switch moonPhaseAngle {
        case 0 ..< 90: localized("Waxing gibbous", "盈凸月", language: model.language)
        case 90 ..< 180: localized("First quarter", "上弦月", language: model.language)
        case 180 ..< 270: localized("Full Moon phase", "满月阶段", language: model.language)
        default: localized("Last quarter", "下弦月", language: model.language)
        }
    }

    // MARK: - Today Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead(localized("Today Timeline", "今日时间线", language: model.language), sub: localized("Local time", "本地时间", language: model.language))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.todaySignals.prefix(3).enumerated()), id: \.offset) { index, signal in
                    HStack(alignment: .top, spacing: 11) {
                        Text(timeOf(signal.eventDate))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 44, alignment: .leading)
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == 0 ? AppTheme.mint : AppTheme.line)
                                .frame(width: 9, height: 9)
                            if index < min(3, model.todaySignals.count) - 1 {
                                Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 22)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signal.title).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                            Text(signal.subtitle).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 6)
                }
                if model.todaySignals.isEmpty {
                    Text(localized("No exact events today. A quieter day.", "今天没有精确事件，相对平静。", language: model.language))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(15)
            .cardSurface()
        }
    }

    private func timeOf(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Upcoming Sky Events

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead(localized("Upcoming Sky Events", "未来七天天象", language: model.language), sub: localized("Next 7 days", "接下来 7 天", language: model.language))
            VStack(spacing: 9) {
                ForEach(Array(model.weeklyForecast.days.prefix(3).enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 11) {
                        VStack(spacing: 0) {
                            Text(monthAbbreviation(day.date)).font(.caption2).foregroundStyle(AppTheme.muted)
                            Text(dayNumber(day.date)).font(.headline.monospacedDigit()).foregroundStyle(AppTheme.text)
                        }
                        .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                            Text(day.situation).font(.caption2).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Circle()
                            .fill(AppTheme.tone(day.tone))
                            .frame(width: 8, height: 8)
                    }
                    .padding(12)
                    .cardSurface()
                }
            }
        }
    }

    private func monthAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    // MARK: - Retrogrades

    private var retrogradesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead(localized("Retrogrades", "回顾调整", language: model.language), link: localized("Details", "详情", language: model.language))
            let retrogrades = model.currentSky?.points.filter(\.retrograde) ?? []
            VStack(alignment: .leading, spacing: 10) {
                Text("\(retrogrades.count) \(localized("planets in review", "颗行星处于回顾调整", language: model.language))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                ForEach(retrogrades.prefix(3), id: \.body) { point in
                    HStack(spacing: 10) {
                        Text(point.body.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.coral)
                        Text(bodyName(point.body, language: model.language))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(localized("Reviewing", "回顾调整中", language: model.language))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                if retrogrades.isEmpty {
                    Text(localized("No planets are in review right now.", "目前没有行星处于回顾调整。", language: model.language))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(15)
            .cardSurface()
        }
    }

    // MARK: - Current Sky link

    private var skyLinkCard: some View {
        Button {
            selectedTab = .charts
            model.selectChart(.currentSky)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid")
                    .font(.title3)
                    .foregroundStyle(AppTheme.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("View Current Sky Chart", "查看当前天象", language: model.language))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized("Planet positions · Aspects · Houses · Motion", "行星位置 · 连接 · 宫位 · 运动", language: model.language))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
            }
            .contentShape(Rectangle())
            .padding(15)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(AppTheme.violet)
            Text(localized("Calculating locally…", "正在本机计算…", language: model.language))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .cardSurface()
    }

    private func sectionHead(_ title: String, sub: String? = nil, link: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(AppTheme.text)
            if let sub {
                Text(sub).font(.caption).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            if let link {
                Text(link).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.violet)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter.string(from: date)
    }
}

extension DailySignal.Source {
    var symbol: String {
        switch self {
        case .sky: "◉"
        case .transit: "◎"
        case .secondary: "◐"
        }
    }
}
