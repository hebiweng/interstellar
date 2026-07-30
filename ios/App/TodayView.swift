import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: RootTab
    @State private var selectedWeekday = 0
    @State private var selectedDomain: TodayLifeDomain?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ScreenTitle(
                            eyebrow: localized("YOUR SKY", "你的天空", language: model.language),
                            title: localized("Today", "今日", language: model.language),
                            subtitle: "\(formattedDate(Date())) · \(model.profile.placeName)"
                        )

                        if model.isCalculating || model.todayDashboardModel == nil {
                            loadingCard
                        } else if let dashboard = model.todayDashboardModel {
                            heroCard(dashboard)
                            lifeAreasSection(dashboard)
                            rhythmSection(dashboard)
                            weekTimeline(model.weeklyForecast)
                            selectedDayCard(model.weeklyForecast)
                        }

                        if let message = model.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.coral)
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func weekTimeline(_ forecast: WeeklyForecastModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: localized("SEVEN DAYS", "未来七天", language: model.language),
                title: localized("How the week develops", "本周如何进展", language: model.language),
                trailing: localized("Tap a day", "点击日期", language: model.language)
            )

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(forecast.days.enumerated()), id: \.element.id) { index, day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedWeekday = index
                        }
                    } label: {
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottom) {
                                Capsule()
                                    .fill(AppTheme.line.opacity(0.62))
                                    .frame(width: 16, height: 70)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.tone(day.tone).opacity(0.58),
                                                AppTheme.tone(day.tone),
                                            ],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(
                                        width: 16,
                                        height: max(10, 70 * max(0.08, day.intensity))
                                    )
                            }
                            Text(shortWeekday(day.date))
                                .font(.footnote.weight(.bold))
                            Circle()
                                .fill(
                                    selectedWeekday == index
                                        ? AppTheme.violet
                                        : Color.clear
                                )
                                .frame(width: 5, height: 5)
                        }
                        .foregroundStyle(
                            selectedWeekday == index ? AppTheme.text : AppTheme.muted
                        )
                        .frame(maxWidth: .infinity, minHeight: 112)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(weekday(day.date)), \(Int(day.intensity * 100))"
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppTheme.line))
        }
    }

    private func selectedDayCard(_ forecast: WeeklyForecastModel) -> some View {
        guard !forecast.days.isEmpty else {
            return AnyView(EmptyView())
        }
        let index = min(max(0, selectedWeekday), forecast.days.count - 1)
        let day = forecast.days[index]
        return AnyView(
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekday(day.date).uppercased())
                            .font(.footnote.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.tone(day.tone))
                        Text(day.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                    }
                    Spacer()
                    Text("\(Int(day.intensity * 100))")
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(AppTheme.tone(day.tone))
                }
                Text(day.situation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 9) {
                    Image(systemName: day.peakIcon)
                        .foregroundStyle(AppTheme.tone(day.tone))
                    Text(day.peakStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(
                    AppTheme.tone(day.tone).opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 12)
                )

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: day.nextFocusIcon)
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("Next focus", "接下来重点", language: model.language))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(day.next)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .cardSurface()
        )
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter.string(from: date)
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func heroCard(_ dashboard: TodayDashboardModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("TODAY'S FOCUS", "今日主线", language: model.language))
                        .font(.footnote.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.violet)
                    Text(dashboard.headline)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(dashboard.summary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(
                        localized(
                            "Most focused in the \(dashboard.peakLabel.lowercased())",
                            "\(dashboard.peakLabel)最集中",
                            language: model.language
                        ),
                        systemImage: "clock"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TodayPulseGauge(
                    value: dashboard.focusIntensity,
                    tone: dashboard.focusTone,
                    language: model.language
                )
                .frame(width: 92, height: 82)
            }

            RhythmWaveView(values: dashboard.rhythm, tone: dashboard.focusTone)
                .frame(height: 58)

            HStack {
                ForEach(Array(dashboard.rhythmLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .frame(
                            maxWidth: .infinity,
                            alignment: index == 0 ? .leading : index == 2 ? .trailing : .center
                        )
                }
            }
        }
        .cardSurface()
    }

    private func lifeAreasSection(_ dashboard: TodayDashboardModel) -> some View {
        let activeDomain = selectedDomain
            .flatMap { target in dashboard.domains.first { $0.domain == target } }
            ?? dashboard.domains.max(by: { $0.intensity < $1.intensity })
            ?? dashboard.domains[0]

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: localized("LIFE AREAS", "生活领域", language: model.language),
                title: localized(
                    "What matters most today",
                    "今天与你最相关的领域",
                    language: model.language
                ),
                trailing: localized("Tap to explore", "点击切换", language: model.language)
            )

            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        LifeAreaRadar(
                            domains: dashboard.domains,
                            selected: activeDomain.domain,
                            language: model.language
                        )
                        .frame(width: 148, height: 148)
                        domainButtons(dashboard.domains, selected: activeDomain.domain)
                    }

                    VStack(spacing: 14) {
                        LifeAreaRadar(
                            domains: dashboard.domains,
                            selected: activeDomain.domain,
                            language: model.language
                        )
                        .frame(width: 178, height: 178)
                        domainButtons(dashboard.domains, selected: activeDomain.domain)
                    }
                }

                Divider().overlay(AppTheme.line)

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(activeDomain.domain.title(language: model.language).uppercased())
                            .font(.footnote.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.tone(activeDomain.tone))
                        Text(activeDomain.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                    }
                    Spacer()
                    MiniDomainTrend(
                        value: activeDomain.intensity,
                        tone: activeDomain.tone
                    )
                    .frame(width: 84, height: 30)
                }
                Text(activeDomain.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardSurface()
        }
    }

    private func domainButtons(
        _ domains: [TodayDomainSummary],
        selected: TodayLifeDomain
    ) -> some View {
        VStack(spacing: 7) {
            ForEach(domains) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDomain = item.domain
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.domain.icon)
                            .font(.caption.weight(.semibold))
                            .frame(width: 18)
                        Text(item.domain.title(language: model.language))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.state)
                            .font(.footnote)
                            .foregroundStyle(
                                selected == item.domain
                                    ? AppTheme.text.opacity(0.78)
                                    : AppTheme.muted
                            )
                    }
                    .foregroundStyle(
                        selected == item.domain
                            ? AppTheme.text
                            : AppTheme.muted
                    )
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(
                        selected == item.domain
                            ? AppTheme.violet.opacity(0.18)
                            : AppTheme.panelRaised.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(
                                selected == item.domain
                                    ? AppTheme.violet.opacity(0.45)
                                    : AppTheme.line
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityValue(item.state)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func rhythmSection(_ dashboard: TodayDashboardModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: localized("RHYTHM", "节奏", language: model.language),
                title: localized("What comes next", "接下来的节奏", language: model.language)
            )

            if dashboard.nextMoments.isEmpty {
                Text(
                    localized(
                        "The day is relatively quiet. Keep your own pace.",
                        "今天整体比较平静，按自己的节奏安排就好。",
                        language: model.language
                    )
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(Array(dashboard.nextMoments.enumerated()), id: \.element.id) { index, moment in
                            VStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.tone(moment.tone).opacity(0.16))
                                        .frame(width: 30, height: 30)
                                    Circle()
                                        .fill(AppTheme.tone(moment.tone))
                                        .frame(width: 10, height: 10)
                                }
                                Text(moment.stage)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity)

                            if index < dashboard.nextMoments.count - 1 {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.tone(moment.tone),
                                                AppTheme.line,
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 3)
                                    .padding(.horizontal, -9)
                                    .offset(y: -10)
                            }
                        }
                    }

                    ForEach(dashboard.nextMoments) { moment in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppTheme.tone(moment.tone))
                                .frame(width: 6, height: 58)

                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(moment.source.uppercased())
                                        .font(.footnote.weight(.bold))
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.tone(moment.tone))
                                    Spacer()
                                    Text("\(Int(moment.intensity * 100))")
                                        .font(.footnote.monospacedDigit().weight(.bold))
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Text(moment.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Text(moment.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(
                            AppTheme.tone(moment.tone).opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                    }
                }
                .padding(16)
                .background(
                    AppTheme.panel,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppTheme.line))
            }
        }
    }

    private func sectionTitle(
        eyebrow: String,
        title: String,
        trailing: String? = nil
    ) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(.footnote.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.violet)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func timeLabel(_ signal: DailySignal) -> String {
        guard let date = signal.eventDate else {
            return localized("Now", "现在", language: model.language)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter.string(from: date)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(AppTheme.violet)
            Text(localized("Preparing today…", "正在准备今日内容…", language: model.language))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

private struct TodayPulseGauge: View {
    let value: Double
    let tone: InsightTone
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .bottom) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.78)
                let radius = min(size.width * 0.42, size.height * 0.56)
                let start = Angle.degrees(190)
                let end = Angle.degrees(350)
                let activeEnd = Angle.degrees(190 + 160 * min(1, max(0, value)))
                let track = Path { path in
                    path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                }
                let active = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: start,
                        endAngle: activeEnd,
                        clockwise: false
                    )
                }
                context.stroke(track, with: .color(AppTheme.line), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                context.stroke(
                    active,
                    with: .color(AppTheme.tone(tone)),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )

                let needleAngle = activeEnd.radians
                var needle = Path()
                needle.move(to: center)
                needle.addLine(
                    to: CGPoint(
                        x: center.x + cos(needleAngle) * radius * 0.72,
                        y: center.y + sin(needleAngle) * radius * 0.72
                    )
                )
                context.stroke(
                    needle,
                    with: .color(AppTheme.tone(tone)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(AppTheme.tone(tone))
                )
            }

            Text(
                value < 0.2
                    ? localized("Steady", "平稳", language: language)
                    : localized("Active", "活跃", language: language)
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.muted)
        }
        .accessibilityLabel(localized("Today's rhythm", "今日节奏", language: language))
        .accessibilityValue("\(Int(value * 100))%")
    }
}

private struct RhythmWaveView: View {
    let values: [Double]
    let tone: InsightTone

    var body: some View {
        Canvas { context, size in
            let baseline = size.height * 0.76
            var guide = Path()
            guide.move(to: CGPoint(x: 0, y: baseline))
            guide.addLine(to: CGPoint(x: size.width, y: baseline))
            context.stroke(guide, with: .color(AppTheme.line), lineWidth: 1)

            guard !values.isEmpty else { return }
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: values.count == 1
                        ? size.width / 2
                        : Double(index) / Double(values.count - 1) * size.width,
                    y: baseline - max(0, min(1, value)) * size.height * 0.62
                )
            }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(AppTheme.tone(tone)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            if let peak = points.enumerated().max(by: {
                values[$0.offset] < values[$1.offset]
            })?.element {
                context.fill(
                    Path(ellipseIn: CGRect(x: peak.x - 4, y: peak.y - 4, width: 8, height: 8)),
                    with: .color(AppTheme.panel)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: peak.x - 4, y: peak.y - 4, width: 8, height: 8)),
                    with: .color(AppTheme.tone(tone)),
                    lineWidth: 2
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LifeAreaRadar: View {
    let domains: [TodayDomainSummary]
    let selected: TodayLifeDomain
    let language: AppLanguage

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.34
            let order: [TodayLifeDomain] = [.work, .love, .energy, .money]
            let angles = [-Double.pi / 2, 0, Double.pi / 2, Double.pi]

            for level in [1.0 / 3, 2.0 / 3, 1.0] {
                var grid = Path()
                for (index, angle) in angles.enumerated() {
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius * level,
                        y: center.y + sin(angle) * radius * level
                    )
                    index == 0 ? grid.move(to: point) : grid.addLine(to: point)
                }
                grid.closeSubpath()
                context.stroke(grid, with: .color(AppTheme.line), lineWidth: 1)
            }

            for angle in angles {
                var axis = Path()
                axis.move(to: center)
                axis.addLine(
                    to: CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                )
                context.stroke(axis, with: .color(AppTheme.line), lineWidth: 1)
            }

            var area = Path()
            var dataPoints: [CGPoint] = []
            for (index, domain) in order.enumerated() {
                let value = domains.first { $0.domain == domain }?.intensity ?? 0
                let point = CGPoint(
                    x: center.x + cos(angles[index]) * radius * value,
                    y: center.y + sin(angles[index]) * radius * value
                )
                dataPoints.append(point)
                index == 0 ? area.move(to: point) : area.addLine(to: point)
            }
            area.closeSubpath()
            context.fill(area, with: .color(AppTheme.violet.opacity(0.2)))
            context.stroke(area, with: .color(AppTheme.violet), lineWidth: 2)

            for (index, point) in dataPoints.enumerated() {
                let isSelected = order[index] == selected
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: point.x - (isSelected ? 4 : 3),
                            y: point.y - (isSelected ? 4 : 3),
                            width: isSelected ? 8 : 6,
                            height: isSelected ? 8 : 6
                        )
                    ),
                    with: .color(isSelected ? AppTheme.violet : AppTheme.panelRaised)
                )
            }

            let labels = order.map { shortDomainTitle($0, language: language) }
            let labelPoints = [
                CGPoint(x: center.x, y: 8),
                CGPoint(x: size.width - 5, y: center.y),
                CGPoint(x: center.x, y: size.height - 8),
                CGPoint(x: 5, y: center.y),
            ]
            let anchors: [UnitPoint] = [.center, .trailing, .center, .leading]
            for index in labels.indices {
                context.draw(
                    Text(labels[index])
                        .font(.system(size: 12, weight: order[index] == selected ? .bold : .regular))
                        .foregroundStyle(order[index] == selected ? AppTheme.text : AppTheme.muted),
                    at: labelPoints[index],
                    anchor: anchors[index]
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            localized(
                "Activity across work, relationships, wellbeing, and money",
                "事业、感情、状态与财富的活跃程度",
                language: language
            )
        )
    }

    private func shortDomainTitle(_ domain: TodayLifeDomain, language: AppLanguage) -> String {
        switch domain {
        case .love: localized("Love", "感情", language: language)
        case .work: localized("Work", "事业", language: language)
        case .money: localized("Money", "财富", language: language)
        case .energy: localized("Energy", "状态", language: language)
        }
    }
}

private struct MiniDomainTrend: View {
    let value: Double
    let tone: InsightTone

    var body: some View {
        Canvas { context, size in
            let safeValue = max(0, min(1, value))
            let points = [
                CGPoint(x: 1, y: size.height * 0.76),
                CGPoint(x: size.width * 0.28, y: size.height * (0.7 - safeValue * 0.22)),
                CGPoint(x: size.width * 0.55, y: size.height * (0.74 - safeValue * 0.48)),
                CGPoint(x: size.width - 1, y: size.height * (0.68 - safeValue * 0.34)),
            ]
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(AppTheme.tone(tone)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
