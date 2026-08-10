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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        topBar
                        dateLine

                        if model.currentSky == nil {
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
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.coral)
                                .padding(14)
                                .cardSurface()
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 8)
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
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .today {
                    showReports = false
                }
            }
        }
    }

    // MARK: - Top bar / date line (prototype .topbar / .date-line)

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INTERSTELLAR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.muted)
                Text(localized("Today", "今日", language: model.language))
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(AppTheme.text)
            }
            Spacer()
            Button {
                showReports = true
            } label: {
                Label(localized("Reports", "报告", language: model.language), systemImage: "doc.text.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.violet.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    private var dateLine: some View {
        HStack(spacing: 5) {
            Text(formattedDate(Date()))
            Text("·")
            Text(model.profile.placeName)
            Text("·")
            Text(model.profile.name)
        }
        .font(.system(size: 13))
        .foregroundStyle(AppTheme.muted)
        .padding(.top, 2)
        .padding(.bottom, 17)
    }

    // MARK: - Your Transits (prototype chapter hero + transit stack)

    private var transitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(
                localized("Current Chapter", "当前章节", language: model.language),
                link: localized("View all", "查看全部", language: model.language)
            ) {
                selectedTab = .charts
                model.selectChart(.transit)
            }
            chapterHero
            VStack(spacing: 9) {
                if let signal = activeTodaySignal {
                    transitRow(signal, cardID: "active-today", badge: localized("ACTIVE TODAY", "今天活跃", language: model.language), tone: .warm)
                }
                if let signal = comingNextSignal {
                    transitRow(signal, cardID: "coming-next", badge: localized("COMING NEXT", "接下来", language: model.language), tone: .good)
                }
            }
            .padding(.top, 11)
        }
    }

    private var activeTodaySignal: DailySignal? {
        let calendar = Calendar.current
        return model.todaySignals
            .filter { signal in
                guard let date = signal.eventDate else { return signal.category == .activeNow }
                return calendar.isDateInToday(date) || signal.category == .activeNow
            }
            .sorted { ($0.eventDate ?? .distantPast) < ($1.eventDate ?? .distantPast) }
            .first
    }

    private var comingNextSignal: DailySignal? {
        let now = Date()
        return model.todaySignals
            .filter { signal in
                guard signal.id != activeTodaySignal?.id, let date = signal.eventDate else { return false }
                return date > now
            }
            .sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
            .first
    }

    private var chapterHero: some View {
        let window = longChapterWindow
        let house = window.map { natalHouse(for: $0.firstLongitude) } ?? 0
        let area = ConsumerCopy.lifeArea(house, language: model.language)
        let copy = model.todayCardText("current-chapter")
        let title = copy?.headline
            ?? localized("Content unavailable", "内容暂不可用", language: model.language)
        let summaryText = copy?.body
            ?? localized(
                "The required reviewed content is missing.",
                "缺少对应的已审核内容。",
                language: model.language
            )
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(localized("CURRENT CHAPTER", "当前章节", language: model.language))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.violet)
                Spacer(minLength: 8)
                InsightBadge(text: localized("Long-term", "长期", language: model.language), tone: .purple)
            }
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .kerning(-0.6)
                .lineSpacing(2)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
            Text(summaryText)
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            HStack(spacing: 6) {
                TagChip(text: area, tone: .neutral)
                if let next = window?.nextExact, next >= Date() {
                    TagChip(
                        text: LocalizedFormatters.exactAgain(shortDate(next), language: model.language),
                        tone: .transition
                    )
                } else if let window {
                    TagChip(
                        text: window.start.shortEventRange(to: window.end, language: model.language, timeZone: TimeZone(identifier: model.profile.timezoneID) ?? .current),
                        tone: .transition
                    )
                }
            }
            .padding(.top, 10)
            chapterLine(window)
        }
        .padding(16)
        .cardSurface()
    }

    /// The longest active slow-planet transit window, used as the current chapter.
    private var longChapterWindow: ChartEventData.TransitWindow? {
        let windows = model.chartEvents.transitWindows
        guard !windows.isEmpty else { return nil }
        let slow: Set<CelestialBody> = [.saturn, .uranus, .neptune, .pluto]
        let now = Date()
        let active = windows.filter { $0.start <= now && $0.end >= now }
        guard !active.isEmpty else { return nil }
        let slowWindows = active.filter { slow.contains($0.first) }
        let pool = slowWindows.isEmpty ? active : slowWindows
        return pool.max {
            $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start)
        }
    }

    private func chapterLine(_ window: ChartEventData.TransitWindow?) -> some View {
        let now = Date()
        let start = window?.start ?? now.addingTimeInterval(-7 * 86_400)
        let end = window?.end ?? now.addingTimeInterval(7 * 86_400)
        let total = max(1, end.timeIntervalSince(start))
        let progress = min(1, max(0, now.timeIntervalSince(start) / total))
        return HStack(spacing: 8) {
            Text(shortDate(start))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress, height: 6)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(AppTheme.violet, lineWidth: 3))
                        .frame(width: 10, height: 10)
                        .offset(x: proxy.size.width * progress - 5)
                }
            }
            .frame(height: 10)
            Text(shortDate(end))
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(AppTheme.muted)
        .padding(.top, 14)
    }

    private func transitRow(_ signal: DailySignal, cardID: String, badge: String, tone: InsightBadgeTone) -> some View {
        let copy = model.todayCardText(cardID)
        return Button {
            selectedTab = .charts
            model.openSignal(signal)
        } label: {
            HStack(alignment: .top, spacing: 12) {
            Text(signal.source.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 42, height: 42)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.violet.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 0) {
                InsightBadge(
                    text: badge,
                    tone: tone
                )
                Text(copy?.headline ?? signal.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 2)
                Text(copy?.body ?? signal.subtitle)
                    .font(.system(size: 11))
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.top, 3)
                HStack(spacing: 6) {
                    if let eventDate = signal.eventDate {
                        TagChip(
                            text: "\(localized("Peaks", "峰值", language: model.language)) \(timeOf(eventDate))",
                            tone: .transition
                        )
                    }
                    TagChip(text: todaySourceTitle(signal.source), tone: .transition)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(14)
        .cardSurface()
    }

    // MARK: - Moon Today (prototype .moon-card)

    private var moonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("Moon Today", "今日月亮", language: model.language), sub: localized("Changes quickly", "变化很快", language: model.language))
            if let moon = model.currentSky?.point(.moon) {
                let copy = model.todayCardText("moon-today")
                let house = model.natal?.house(containing: moon.longitudeDegrees) ?? 0
                HStack(spacing: 15) {
                    moonVisual(phase: moonPhaseAngle, illumination: illumination)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(illumination * 100))% \(localized("illuminated", "照亮", language: model.language))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.violet.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.violet.opacity(0.22), lineWidth: 1))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(localized("Moon in", "月亮在", language: model.language)) \(Zodiac.name(index: moon.signIndex, language: model.language))")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.top, 7)
                        Text("\(moonPhaseName) · \(localized("Moving through your", "正经过你的", language: model.language)) \(ConsumerCopy.lifeArea(house, language: model.language))")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.top, 4)
                        if let interpretation = copy?.body {
                            Text(interpretation)
                                .font(.system(size: 11))
                                .lineSpacing(2)
                                .foregroundStyle(AppTheme.text.opacity(0.86))
                                .padding(.top, 6)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * CGFloat(moon.degreeInSign / 30), height: 6)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 9)
                        HStack {
                            Text(Zodiac.position(moon, language: model.language))
                            Spacer()
                            Text("\(Zodiac.name(index: (moon.signIndex + 1) % 12, language: model.language)) · \(nextSignIn(moon))")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.top, 6)
                    }
                    Spacer(minLength: 0)
                }
                .padding(17)
                .cardSurface()
            }
        }
    }

    private func moonVisual(phase: Double, illumination: Double) -> some View {
        // Terminator offset follows the phase: waxing light grows from the right,
        // waning light shrinks back from the right.
        let waxing = phase < 180
        let lit = CGFloat(min(1, max(0.06, illumination)))
        let lightEnd = 0.42 * lit
        let darkStart = lightEnd + 0.015
        let centerX: CGFloat = waxing ? 0.31 : 0.69
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.988, green: 0.976, blue: 0.91), location: 0.0),
                            .init(color: Color(red: 0.988, green: 0.976, blue: 0.91), location: lightEnd),
                            .init(color: Color(red: 0.192, green: 0.22, blue: 0.30), location: darkStart),
                            .init(color: Color(red: 0.192, green: 0.22, blue: 0.30), location: 1.0),
                        ],
                        center: UnitPoint(x: centerX, y: 0.36),
                        startRadius: 2,
                        endRadius: 40
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.35)],
                        center: UnitPoint(x: centerX, y: 0.36),
                        startRadius: 30,
                        endRadius: 42
                    )
                )
            Circle().stroke(AppTheme.line, lineWidth: 1)
        }
        .frame(width: 78, height: 78)
        .shadow(color: Color(red: 0.95, green: 0.93, blue: 0.82).opacity(0.12), radius: 12, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 2, y: 3)
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
        case 0 ..< 22.5, 337.5 ..< 360: localized("New Moon", "新月", language: model.language)
        case 22.5 ..< 67.5: localized("Waxing crescent", "娥眉月", language: model.language)
        case 67.5 ..< 112.5: localized("First quarter", "上弦月", language: model.language)
        case 112.5 ..< 157.5: localized("Waxing gibbous", "盈凸月", language: model.language)
        case 157.5 ..< 202.5: localized("Full Moon", "满月", language: model.language)
        case 202.5 ..< 247.5: localized("Waning gibbous", "亏凸月", language: model.language)
        case 247.5 ..< 292.5: localized("Last quarter", "下弦月", language: model.language)
        default: localized("Waning crescent", "残月", language: model.language)
        }
    }

    private func nextSignIn(_ moon: ChartPoint) -> String {
        guard let ingress = model.chartEvents.skyIngresses
            .filter({ $0.body == .moon && $0.date > Date() })
            .min(by: { $0.date < $1.date })
        else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: ingress.date, relativeTo: Date())
    }

    // MARK: - Today Timeline (prototype .time-event + now-line)

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("Today Timeline", "今日时间线", language: model.language), sub: localized("Local time", "本地时间", language: model.language))
            let events = Array(model.todaySignals.prefix(3))
            VStack(alignment: .leading, spacing: 0) {
                if let interpretation = model.todayCardText("today-timeline")?.body {
                    Text(interpretation)
                        .font(.system(size: 11))
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.bottom, 12)
                }
                ForEach(Array(events.enumerated()), id: \.offset) { index, signal in
                    timeEvent(signal, index: index, total: events.count)
                }
                if model.todaySignals.isEmpty {
                    Text(localized("No exact events today. A quieter day.", "今天没有精确事件，相对平静。", language: model.language))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 10)
                }
            }
            .padding(16)
            .cardSurface()
        }
    }

    private func timeEvent(_ signal: DailySignal, index: Int, total: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeOf(signal.eventDate))
                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(AppTheme.muted)
                .frame(width: 42, alignment: .leading)
            VStack(spacing: 0) {
                let isPast = signal.eventDate.map { $0 < Date() } ?? false
                Circle()
                    .fill(isPast ? AppTheme.violet : Color.clear)
                    .overlay(Circle().stroke(AppTheme.violet, lineWidth: isPast ? 0 : 1.6))
                    .frame(width: 8, height: 8)
                if index < total - 1 {
                    Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                Text(signal.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
        .padding(.bottom, 6)
    }

    // MARK: - Upcoming Sky Events (prototype .event-card)

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("Upcoming Sky Events", "未来七天天象", language: model.language), sub: localized("Next 7 days", "接下来 7 天", language: model.language))
            VStack(spacing: 9) {
                if let interpretation = model.todayCardText("upcoming-sky-events")?.body {
                    Text(interpretation)
                        .font(.system(size: 11))
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                ForEach(Array(upcomingSkyRows.prefix(3).enumerated()), id: \.element.id) { _, event in
                    Button {
                        selectedTab = .charts
                        model.selectChart(.currentSky)
                        model.setTargetDate(event.date, for: .currentSky)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(spacing: 0) {
                                Text(monthAbbreviation(event.date)).font(.system(size: 9, weight: .semibold)).foregroundStyle(AppTheme.muted)
                                Text(dayNumber(event.date)).font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                            }
                            .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(event.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(13)
                        .cardSurface()
                    }
                    .buttonStyle(.plain)
                }
                if upcomingSkyRows.isEmpty {
                    Text(localized("No calculated sky events in the next seven days.", "未来七天没有进入显示范围的已计算天象事件。", language: model.language))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface()
                }
            }
            .padding(.top, 11)
        }
    }

    private var upcomingSkyRows: [(id: String, date: Date, title: String, subtitle: String)] {
        let ingressRows = model.chartEvents.skyIngresses.map { event in
            (
                id: "ingress-\(event.body.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: "\(bodyName(event.body, language: model.language)) → \(Zodiac.name(index: event.signIndex, language: model.language))",
                subtitle: localized("Sign change", "换座", language: model.language)
            )
        }
        let exactRows = model.chartEvents.skyExactEvents.map { event in
            (
                id: "exact-\(event.first.rawValue)-\(event.second.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: "\(bodyName(event.first, language: model.language)) · \(bodyName(event.second, language: model.language))",
                subtitle: aspectKindName(event.kind, language: model.language)
            )
        }
        let stationRows = model.chartEvents.skyStations.map { event in
            (
                id: "station-\(event.body.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: bodyName(event.body, language: model.language),
                subtitle: event.retrogradeAfter
                    ? localized("Stations retrograde", "开始逆行", language: model.language)
                    : localized("Stations direct", "恢复顺行", language: model.language)
            )
        }
        let horizon = Date().addingTimeInterval(7 * 86_400)
        return (ingressRows + exactRows + stationRows)
            .filter { $0.date >= Date() && $0.date <= horizon }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Retrogrades (prototype .retro-card)

    private var retrogradesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(
                localized("Retrogrades", "回顾调整", language: model.language),
                link: localized("common.details", default: "Details", chinese: "详情", language: model.language)
            ) {
                selectedTab = .charts
                model.selectChart(.currentSky)
            }
            let retrogrades = model.currentSky?.points.filter(\.retrograde) ?? []
            VStack(alignment: .leading, spacing: 0) {
                if let interpretation = model.todayCardText("retrogrades")?.body {
                    Text(interpretation)
                        .font(.system(size: 11))
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.bottom, 10)
                }
                HStack {
                    Text(LocalizedFormatters.retrogradePlanets(retrogrades.count, language: model.language))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    TagChip(text: localized("Review window", "回顾窗口", language: model.language), tone: .transition)
                }
                .padding(.bottom, 6)
                ForEach(retrogrades.prefix(3), id: \.body) { point in
                    HStack(spacing: 10) {
                        Text(point.body.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.coral)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(bodyName(point.body, language: model.language))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(Zodiac.name(index: point.signIndex, language: model.language)) · \(localized("reviewing", "回顾调整中", language: model.language))")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        TagChip(text: stationDeadline(for: point.body), tone: .transition)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(AppTheme.line.opacity(0.6))
                }
                if retrogrades.isEmpty {
                    Text(localized("No planets are in review right now.", "目前没有行星处于回顾调整。", language: model.language))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .cardSurface()
        }
    }

    private func stationDeadline(for body: CelestialBody) -> String {
        guard let station = model.chartEvents.skyStations.first(where: { $0.body == body }) else {
            return localized("today.reviewing.status", default: "Reviewing", chinese: "回顾中", language: model.language)
        }
        return localized(
            "Direct \(shortDate(station.date))",
            "\(shortDate(station.date)) 转顺",
            language: model.language
        )
    }

    // MARK: - Current Sky link (prototype .sky-link)

    private var skyLinkCard: some View {
        Button {
            selectedTab = .charts
            model.selectChart(.currentSky)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("View Current Sky Chart", "查看当前天象", language: model.language))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized("Planet positions · Aspects · Houses · Motion", "行星位置 · 连接 · 宫位 · 运动", language: model.language))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(AppTheme.muted)
            }
            .contentShape(Rectangle())
            .padding(15)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .padding(.top, 18)
    }

    // MARK: - Shared

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(AppTheme.violet)
            Text(localized("Calculating locally…", "正在本机计算…", language: model.language))
                .font(AppTypography.summary)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .cardSurface()
    }

    private func sectionHead(
        _ title: String,
        sub: String? = nil,
        link: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 18, weight: .bold)).kerning(-0.3).foregroundStyle(AppTheme.text)
            if let sub {
                Text(sub).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            if let link {
                if let action {
                    Button(link, action: action)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .buttonStyle(.plain)
                } else {
                    Text(link).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppTheme.violet)
                }
            }
        }
        .padding(.top, 25)
        .padding(.bottom, 11)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter.string(from: date)
    }

    private var weekWindowLabel: String {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        return "\(LocalizedFormatters.shortDate(start, language: model.language, timeZone: timeZone)) – \(LocalizedFormatters.shortDate(end, language: model.language, timeZone: timeZone))"
    }

    private func natalHouse(for longitude: Double) -> Int {
        model.natal?.house(containing: longitude) ?? 0
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func timeOf(_ date: Date?) -> String {
        guard let date else { return "—" }
        let timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        return LocalizedFormatters.time(date, language: model.language, timeZone: timeZone)
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

    private func todaySourceTitle(_ source: DailySignal.Source) -> String {
        switch source {
        case .sky: localized("today.source.current-sky", default: "Current Sky", chinese: "当前天象", language: model.language)
        case .transit: localized("Personal timing", "个人节奏", language: model.language)
        case .secondary: localized("Long-term shift", "长期变化", language: model.language)
        }
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
