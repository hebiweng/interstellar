import AstroCore
import SwiftUI

private struct AskOptionDraft: Identifiable, Equatable {
    let id: UUID
    var label: String
    var house: Int?

    init(id: UUID = UUID(), label: String = "", house: Int? = nil) {
        self.id = id
        self.label = label
        self.house = house
    }
}

private enum TimingRangeSelection: String, CaseIterable, Identifiable {
    case short
    case medium
    case long
    case custom

    var id: String { rawValue }
}

private struct AskResultCard: Identifiable {
    let id: String
    let icon: String
    let summary: String
    let detail: String
}

struct AskView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: HoraryQuestionMode?
    @State private var question = ""
    @State private var targetHouse = 10
    @State private var options = [AskOptionDraft(), AskOptionDraft()]
    @State private var timingPrecision: TimingPrecision = .day
    @State private var timingRange: TimingRangeSelection = .medium
    @State private var startDate = Date()
    @State private var customEndDate = Date().addingTimeInterval(30 * 86_400)
    @State private var chartDate = Date()
    @State private var location: LocationSelection?
    @State private var showsLocationPicker = false
    @State private var session: HorarySession?
    @State private var isCalculating = false
    @State private var progress = 0.0
    @State private var errorMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var askHistory: [AskHistoryEntry] = []
    @State private var showAskHistory = false
    @FocusState private var focusedInputID: String?
    private let askHistoryStore = AskHistoryStore()

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if let session {
                            resultView(session)
                        } else if let mode {
                            configurationView(mode)
                        } else {
                            modeSelection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsLocationPicker) {
                LocationSearchView(language: model.language) {
                    location = $0
                }
            }
            .onAppear {
                if location == nil {
                    location = profileLocation
                }
                askHistory = askHistoryStore.load()
            }
            .onChange(of: startDate) { _, _ in
                customEndDate = min(max(customEndDate, startDate), maximumEndDate)
            }
            .onDisappear {
                calculationTask?.cancel()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showAskHistory) {
                AskHistoryView(entries: askHistory, language: model.language)
            }
        }
    }

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenTitle(
                eyebrow: localized("ASK THE CHART", "问事盘", language: model.language),
                title: localized("What do you want to ask?", "你想问什么？", language: model.language),
                subtitle: localized(
                    "Choose one path. Your question is calculated privately on this device.",
                    "选择一种方式，问题会在这台设备上完成计算。",
                    language: model.language
                )
            )

            askModeCard(
                mode: .yesNo,
                icon: "questionmark.circle",
                title: localized("Will It Happen?", "会发生吗？", language: model.language),
                detail: localized(
                    "Ask about one specific outcome.",
                    "询问一个具体结果是否更有可能发生。",
                    language: model.language
                )
            )
            askModeCard(
                mode: .choice,
                icon: "arrow.triangle.branch",
                title: localized("Which One?", "选哪个？", language: model.language),
                detail: localized(
                    "Compare two to five real options.",
                    "比较两个到五个实际选项。",
                    language: model.language
                )
            )
            askModeCard(
                mode: .timing,
                icon: "calendar.badge.clock",
                title: localized("Find the Best Time", "什么时候做最好？", language: model.language),
                detail: localized(
                    "Search by day, week, or month.",
                    "按天、周或月寻找更合适的行动时间。",
                    language: model.language
                )
            )

            historySection
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showAskHistory = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("History", "历史", language: model.language))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(askHistory.isEmpty
                             ? localized("No saved questions yet", "还没有保存的问题", language: model.language)
                             : LocalizedFormatters.savedQuestions(askHistory.count, language: model.language))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
                .cardSurface()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("History", "历史", language: model.language))

            ForEach(askHistory.prefix(3)) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.question).font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.text)
                    Text(entry.answerTitle).font(.caption2).foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .cardSurface()
            }
        }
    }

    private func askModeCard(
        mode: HoraryQuestionMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            select(mode)
        } label: {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.violet.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(detail)
                        .font(AppTypography.summary)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func configurationView(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            backHeader(
                title: modeTitle(mode),
                subtitle: modeSubtitle(mode)
            )

            switch mode {
            case .yesNo:
                yesNoFields
            case .choice:
                choiceFields
            case .timing:
                timingFields
            }

            locationAndTime(mode)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            }

            if isCalculating {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: mode == .timing ? progress : nil)
                        .tint(AppTheme.violet)
                    HStack {
                        Text(
                            mode == .timing
                                ? localized("Searching the selected range…", "正在扫描所选时间范围…", language: model.language)
                                : localized("Calculating the horary chart…", "正在计算问事盘…", language: model.language)
                        )
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Button(localized("Cancel", "取消", language: model.language)) {
                            calculationTask?.cancel()
                        }
                        .font(AppTypography.label)
                    }
                }
                .cardSurface()
            } else {
                Button {
                    generate(mode)
                } label: {
                    Label(
                        mode == .timing
                            ? localized("Find the best time", "开始择时", language: model.language)
                            : localized("Ask the chart", "生成问事盘", language: model.language),
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        canGenerate(mode) ? AppTheme.violet : AppTheme.muted.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate(mode))
            }
        }
    }

    private var yesNoFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldTitle(localized("Your question", "你的问题", language: model.language))
            TextField(
                localized(
                    "For example: Will this application move forward?",
                    "例如：这次申请会顺利推进吗？",
                    language: model.language
                ),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(14)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15))

            housePicker(selection: $targetHouse, excluding: [])
        }
        .cardSurface()
    }

    private var choiceFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldTitle(localized("Name each option", "填写每个选项", language: model.language))

            ForEach($options) { $option in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(
                            localized("Option", "选项", language: model.language)
                                + " \(optionLetter(option.id))"
                        )
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                        Spacer()
                        if options.count > 2 {
                            Button {
                                options.removeAll { $0.id == option.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.coral)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField(
                        localized("What is this option?", "这个选项是什么？", language: model.language),
                        text: $option.label
                    )
                    .focused($focusedInputID, equals: option.id.uuidString)
                    .submitLabel(.done)
                    .onSubmit { focusedInputID = nil }
                    .textFieldStyle(.plain)
                    .padding(13)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))

                    housePicker(
                        selection: Binding(
                            get: { option.house ?? 0 },
                            set: { option.house = $0 == 0 ? nil : $0 }
                        ),
                        excluding: selectedHouses(except: option.id),
                        includesPrompt: true
                    )
                }
                .padding(13)
                .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            }

            if options.count < 5 {
                Button {
                    options.append(AskOptionDraft())
                } label: {
                    Label(
                        localized("Add another option", "增加一个选项", language: model.language),
                        systemImage: "plus.circle.fill"
                    )
                    .font(AppTypography.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.violet)
            }
        }
        .cardSurface()
    }

    private var timingFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle(localized("What are you planning?", "你准备做什么？", language: model.language))
            TextField(
                localized("Optional description", "行动名称（可选）", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(13)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))

            housePicker(selection: $targetHouse, excluding: [])

            fieldTitle(localized("Precision", "精度", language: model.language))
            Picker(
                localized("Precision", "精度", language: model.language),
                selection: $timingPrecision
            ) {
                Text(localized("Day", "天", language: model.language)).tag(TimingPrecision.day)
                Text(localized("Week", "周", language: model.language)).tag(TimingPrecision.week)
                Text(localized("Month", "月", language: model.language)).tag(TimingPrecision.month)
            }
            .pickerStyle(.segmented)
            .onChange(of: timingPrecision) { _, _ in
                timingRange = .medium
                customEndDate = defaultEndDate
            }

            fieldTitle(localized("Search within", "搜索范围", language: model.language))
            Picker(
                localized("Search range", "搜索范围", language: model.language),
                selection: $timingRange
            ) {
                ForEach(TimingRangeSelection.allCases) { range in
                    Text(rangeTitle(range)).tag(range)
                }
            }
            .pickerStyle(.navigationLink)

            if timingRange == .custom {
                DatePicker(
                    localized("End date", "结束日期", language: model.language),
                    selection: $customEndDate,
                    in: startDate ... maximumEndDate,
                    displayedComponents: [.date]
                )
            }
        }
        .cardSurface()
    }

    private func locationAndTime(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            fieldTitle(
                mode == .timing
                    ? localized("Search starts", "搜索开始时间", language: model.language)
                    : localized("Chart moment", "起盘时间", language: model.language)
            )
            DatePicker(
                "",
                selection: mode == .timing ? $startDate : $chartDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            fieldTitle(localized("Location", "地点", language: model.language))
            Button {
                showsLocationPicker = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(location?.name ?? localized("Choose a location", "选择地点", language: model.language))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        if let location {
                            Text(location.timezoneID)
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let current = location {
                HStack(spacing: 10) {
                    coordinateField(
                        localized("Latitude", "纬度", language: model.language),
                        id: "latitude",
                        value: Binding(
                            get: { current.latitude },
                            set: { updateLocation(latitude: $0, longitude: current.longitude) }
                        )
                    )
                    coordinateField(
                        localized("Longitude", "经度", language: model.language),
                        id: "longitude",
                        value: Binding(
                            get: { current.longitude },
                            set: { updateLocation(latitude: current.latitude, longitude: $0) }
                        )
                    )
                }
            }
        }
        .cardSurface()
    }

    private func resultView(_ session: HorarySession) -> some View {
        let overlay = overlay(for: session)
        return VStack(alignment: .leading, spacing: 18) {
            backHeader(
                title: localized("Your answer", "问事结果", language: model.language),
                subtitle: formattedSessionDate(session)
            )

            resultHero(session)

            ChartWheelView(
                snapshot: session.snapshot,
                reference: nil,
                comparisonAspects: [],
                language: model.language,
                horaryOverlay: overlay
            )
            .padding(10)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

            if session.mode == .choice {
                choiceRanking(session.choices)
            } else if session.mode == .timing {
                timingRanking(session.timingCandidates)
            }

            resultCards(session)

            NavigationLink {
                HoraryProfessionalView(session: session, overlay: overlay, language: model.language)
            } label: {
                Label(
                    localized("View chart analysis", "查看专业分析", language: model.language),
                    systemImage: "chart.xyaxis.line"
                )
                .font(.headline)
                .foregroundStyle(AppTheme.violet)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(
                localized(
                    "Likelihood and suitability describe support within this chart model. They are not statistical probabilities.",
                    "可能性和适合度表示当前盘面模型中的支持程度，并非统计学概率。",
                    language: model.language
                )
            )
            .font(AppTypography.supporting)
            .foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultHero(_ session: HorarySession) -> some View {
        let score = primaryScore(session)
        let label = primaryLabel(session)
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppTheme.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        scoreColor(score),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score.rounded()))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    Text(session.mode == .timing
                        ? localized("Suitable", "适合度", language: model.language)
                        : localized("Likelihood", "可能性", language: model.language))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 7) {
                Text(label)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if !session.question.trimmed.isEmpty {
                    Text(session.question)
                        .font(AppTypography.summary)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
    }

    private func choiceRanking(_ choices: [HoraryChoiceResult]) -> some View {
        let display = displayPercentages(choices)
        let close = choices.count > 1 && choices[0].likelihood - choices[1].likelihood <= 8
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("Option ranking", "选项排名", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if close {
                    Text(localized("Close call", "结果接近", language: model.language))
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.amber)
                }
            }
            ForEach(Array(choices.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(index + 1)")
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.violet)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.violet.opacity(0.12), in: Circle())
                        Text(item.label)
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text("\(display[item.id, default: 0])%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                    }
                    ProgressView(value: item.likelihood, total: 100)
                        .tint(index == 0 ? AppTheme.violet : AppTheme.blue.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
        }
        .cardSurface()
    }

    private func timingRanking(_ candidates: [ElectionTimingCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Best timing", "推荐时间", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                HStack(spacing: 12) {
                    Image(systemName: index == 0 ? "star.fill" : "calendar")
                        .foregroundStyle(index == 0 ? AppTheme.amber : AppTheme.violet)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedInterval(candidate))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        if timingPrecision != .day {
                            Text(
                                localized("Peak: ", "峰值日：", language: model.language)
                                    + formattedDate(candidate.peakDate, includesTime: false)
                            )
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text("\(Int(candidate.score.rounded()))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                }
                .frame(minHeight: 48)
            }
        }
        .cardSurface()
    }

    private func resultCards(_ session: HorarySession) -> some View {
        let cards: [AskResultCard]
        do {
            cards = try AskContentComposer.cards(
                for: session,
                language: model.language
            )
        } catch {
            return AnyView(
                Label(
                    localized(
                        "Result explanations are unavailable.",
                        "结果解读内容暂不可用。",
                        language: model.language
                    ),
                    systemImage: "exclamationmark.triangle"
                )
                .font(AppTypography.summary)
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            )
        }
        return AnyView(
            VStack(spacing: 12) {
                ForEach(cards) { card in
                    DisclosureGroup {
                        Text(card.detail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: card.icon)
                                .font(.title3)
                                .foregroundStyle(AppTheme.violet)
                                .frame(width: 28)
                            Text(card.summary)
                                .font(AppTypography.summary)
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .tint(AppTheme.violet)
                    .cardSurface()
                }
            }
        )
    }

    private func backHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                resetToModes()
            } label: {
                Label(
                    localized("Ask something else", "返回选择", language: model.language),
                    systemImage: "chevron.left"
                )
                .font(AppTypography.label)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.violet)
            ScreenTitle(
                eyebrow: localized("ASK THE CHART", "问事盘", language: model.language),
                title: title,
                subtitle: subtitle
            )
        }
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.label)
            .foregroundStyle(AppTheme.text)
    }

    private func housePicker(
        selection: Binding<Int>,
        excluding: Set<Int>,
        includesPrompt: Bool = false
    ) -> some View {
        Picker(
            localized("Life area", "生活领域", language: model.language),
            selection: selection
        ) {
            if includesPrompt {
                Text(localized("Choose an area", "选择对应领域", language: model.language))
                    .tag(0)
            }
            ForEach(1 ... 12, id: \.self) { house in
                Text(houseTitle(house))
                    .tag(house)
                    .disabled(excluding.contains(house))
            }
        }
        .pickerStyle(.navigationLink)
        .frame(minHeight: 44)
    }

    private func coordinateField(
        _ title: String,
        id: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
            TextField(
                title,
                value: value,
                format: .number.precision(.fractionLength(0 ... 6))
            )
            .focused($focusedInputID, equals: id)
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .keyboardType(.numbersAndPunctuation)
            .font(AppTypography.label)
            .padding(10)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func generate(_ mode: HoraryQuestionMode) {
        guard let location else { return }
        calculationTask?.cancel()
        isCalculating = true
        progress = 0
        errorMessage = nil
        let requestLocation = GeographicLocation(
            latitudeDegrees: location.latitude,
            longitudeDegrees: location.longitude
        )
        calculationTask = Task {
            do {
                let newSession: HorarySession
                switch mode {
                case .yesNo:
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: HoraryEngine.analyze(
                            snapshot: snapshot,
                            targetHouse: targetHouse
                        ),
                        choices: [],
                        timingCandidates: []
                    )
                case .choice:
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    let candidates = options.compactMap { option -> HoraryChoiceCandidate? in
                        guard let house = option.house else { return nil }
                        return HoraryChoiceCandidate(
                            id: option.id,
                            label: option.label.trimmed,
                            house: house
                        )
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: "",
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: nil,
                        choices: HoraryEngine.analyzeChoices(
                            snapshot: snapshot,
                            candidates: candidates
                        ),
                        timingCandidates: []
                    )
                case .timing:
                    guard let timeZone = TimeZone(identifier: location.timezoneID) else {
                        throw AskViewError.invalidTimeZone
                    }
                    let request = ElectionTimingRequest(
                        targetHouse: targetHouse,
                        startDate: startDate,
                        endDate: selectedEndDate,
                        location: requestLocation,
                        timeZone: timeZone,
                        calendarIdentifier: .gregorian,
                        precision: timingPrecision
                    )
                    let candidates = try await model.searchElectionTiming(request) { value in
                        Task { @MainActor in
                            progress = value
                        }
                    }
                    guard let first = candidates.first else {
                        throw ElectionTimingError.noCandidates
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: startDate,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: first.snapshot,
                        analysis: first.analysis,
                        choices: [],
                        timingCandidates: candidates
                    )
                }
                try Task.checkCancellation()
                await MainActor.run {
                    session = newSession
                    isCalculating = false
                    progress = 1
                    askHistoryStore.append(historyEntry(from: newSession))
                    askHistory = askHistoryStore.load()
                }
            } catch is CancellationError {
                await MainActor.run {
                    isCalculating = false
                    progress = 0
                }
            } catch {
                await MainActor.run {
                    errorMessage = localized(
                        "The chart could not be calculated. Check the time and location, then try again.",
                        "暂时无法完成计算，请检查时间和地点后重试。",
                        language: model.language
                    )
                    isCalculating = false
                }
            }
        }
    }

    private func select(_ selectedMode: HoraryQuestionMode) {
        mode = selectedMode
        focusedInputID = nil
        chartDate = Date()
        startDate = Date()
        customEndDate = defaultEndDate
        session = nil
        errorMessage = nil
    }

    private func resetToModes() {
        calculationTask?.cancel()
        calculationTask = nil
        mode = nil
        session = nil
        focusedInputID = nil
        question = ""
        targetHouse = 10
        options = [AskOptionDraft(), AskOptionDraft()]
        timingPrecision = .day
        timingRange = .medium
        startDate = Date()
        chartDate = Date()
        customEndDate = defaultEndDate
        isCalculating = false
        progress = 0
        errorMessage = nil
    }

    private func canGenerate(_ mode: HoraryQuestionMode) -> Bool {
        guard location != nil else { return false }
        switch mode {
        case .yesNo:
            return !question.trimmed.isEmpty
        case .choice:
            let houses = options.compactMap(\.house)
            return options.count >= 2
                && options.allSatisfy { !$0.label.trimmed.isEmpty && $0.house != nil }
                && Set(houses).count == houses.count
        case .timing:
            return selectedEndDate > startDate
        }
    }

    private func selectedHouses(except id: UUID) -> Set<Int> {
        Set(options.filter { $0.id != id }.compactMap(\.house))
    }

    private func optionLetter(_ id: UUID) -> String {
        guard let index = options.firstIndex(where: { $0.id == id }) else { return "" }
        return String(UnicodeScalar(65 + index)!)
    }

    private func historyEntry(from session: HorarySession) -> AskHistoryEntry {
        let title: String
        let text: String
        switch session.mode {
        case .yesNo:
            title = session.analysis.map { $0.score >= 55 ? localized("Leaning yes", "倾向可以", language: model.language) : localized("Leaning no", "倾向不行", language: model.language) } ?? localized("Result", "结果", language: model.language)
            text = session.analysis.map { "\(Int($0.score))% " + localized("likelihood", "可能性", language: model.language) } ?? ""
        case .choice:
            if let first = session.choices.first {
                title = first.label
                text = "\(Int(first.likelihood * 100))%"
            } else {
                title = localized("Result", "结果", language: model.language)
                text = ""
            }
        case .timing:
            title = session.timingCandidates.first.map { formatDateRange($0.interval) } ?? localized("Result", "结果", language: model.language)
            text = localized("Recommended window", "推荐窗口", language: model.language)
        }
        return AskHistoryEntry(
            id: session.snapshot.utcDate.timeIntervalSince1970.description + session.question,
            mode: session.mode.rawValue,
            question: session.question.isEmpty ? modeTitle(session.mode) : session.question,
            answerTitle: title,
            answerText: text,
            createdAt: session.createdAt,
            locationName: session.locationName,
            significators: []
        )
    }

    private func formatDateRange(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: interval.start)
    }

    private var profileLocation: LocationSelection {
        LocationSelection(
            name: model.profile.placeName,
            latitude: model.profile.latitude,
            longitude: model.profile.longitude,
            timezoneID: model.profile.timezoneID
        )
    }

    private func updateLocation(latitude: Double, longitude: Double) {
        guard let current = location else { return }
        location = LocationSelection(
            name: current.name,
            latitude: min(90, max(-90, latitude)),
            longitude: min(180, max(-180, longitude)),
            timezoneID: current.timezoneID
        )
    }

    private var selectedEndDate: Date {
        if timingRange == .custom {
            return min(customEndDate, maximumEndDate)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        let component: Calendar.Component
        let value: Int
        switch timingPrecision {
        case .day:
            component = .day
            value = timingRange == .short ? 7 : timingRange == .medium ? 30 : 90
        case .week:
            component = .month
            value = timingRange == .short ? 1 : timingRange == .medium ? 3 : 6
        case .month:
            component = .month
            value = timingRange == .short ? 3 : timingRange == .medium ? 6 : 12
        }
        return calendar.date(byAdding: component, value: value, to: startDate)
            ?? startDate.addingTimeInterval(Double(value) * 30 * 86_400)
    }

    private var maximumEndDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        switch timingPrecision {
        case .day:
            return calendar.date(byAdding: .day, value: 90, to: startDate)
                ?? startDate.addingTimeInterval(90 * 86_400)
        case .week:
            return calendar.date(byAdding: .month, value: 6, to: startDate)
                ?? startDate.addingTimeInterval(184 * 86_400)
        case .month:
            return calendar.date(byAdding: .month, value: 12, to: startDate)
                ?? startDate.addingTimeInterval(366 * 86_400)
        }
    }

    private var defaultEndDate: Date {
        selectedEndDate
    }

    private func rangeTitle(_ range: TimingRangeSelection) -> String {
        if range == .custom {
            return localized("Custom", "自定义", language: model.language)
        }
        let values: [Int]
        switch timingPrecision {
        case .day: values = [7, 30, 90]
        case .week: values = [1, 3, 6]
        case .month: values = [3, 6, 12]
        }
        let index = range == .short ? 0 : range == .medium ? 1 : 2
        let value = values[index]
        switch timingPrecision {
        case .day:
            return LocalizedFormatters.nextDays(value, language: model.language)
        case .week, .month:
            return LocalizedFormatters.nextMonths(value, language: model.language)
        }
    }

    private func modeTitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo: localized("Will It Happen?", "会发生吗？", language: model.language)
        case .choice: localized("Which One?", "选哪个？", language: model.language)
        case .timing: localized("Find the Best Time", "什么时候做最好？", language: model.language)
        }
    }

    private func modeSubtitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo:
            localized(
                "Keep the question specific and choose the area it belongs to.",
                "问题尽量具体，并选择它所属的生活领域。",
                language: model.language
            )
        case .choice:
            localized(
                "Name the real options and give each one a different area.",
                "填写真实选项，并为每项选择不同的对应领域。",
                language: model.language
            )
        case .timing:
            localized(
                "Choose what matters, how far to search, and the precision you need.",
                "选择目标领域、搜索范围和所需精度。",
                language: model.language
            )
        }
    }

    private func houseTitle(_ house: Int) -> String {
        let english = [
            "Self & action", "Money & resources", "Learning & short travel",
            "Home & family", "Romance & creativity", "Work, health & routine",
            "Partners & agreements", "Shared money & change", "Travel & higher learning",
            "Career & public role", "Friends, community & goals", "Rest & private matters",
        ]
        let chinese = [
            "自我与行动", "金钱与资源", "学习、沟通与短途旅行",
            "家庭与居所", "恋爱、创造与子女", "日常工作、健康与习惯",
            "伴侣、合作与契约", "共同财务与改变", "远行、深造与信念",
            "事业与社会位置", "朋友、社群与目标", "休息与隐秘事务",
        ]
        return model.language == .english ? english[house - 1] : chinese[house - 1]
    }

    private func primaryScore(_ session: HorarySession) -> Double {
        switch session.mode {
        case .yesNo: session.analysis?.score ?? 0
        case .choice: session.choices.first?.likelihood ?? 0
        case .timing: session.timingCandidates.first?.score ?? 0
        }
    }

    private func primaryLabel(_ session: HorarySession) -> String {
        let score = primaryScore(session)
        switch session.mode {
        case .yesNo:
            if score >= 80 { return localized("Very likely", "很可能", language: model.language) }
            if score >= 65 { return localized("Likely yes", "比较可能", language: model.language) }
            if score >= 45 { return localized("Still unclear", "尚不明确", language: model.language) }
            if score >= 30 { return localized("Likely no", "可能性较低", language: model.language) }
            return localized("Very unlikely", "很不可能", language: model.language)
        case .choice:
            return session.choices.first?.label
                ?? localized("No clear option", "暂无明确选项", language: model.language)
        case .timing:
            guard let first = session.timingCandidates.first else {
                return localized("No timing found", "暂无推荐时间", language: model.language)
            }
            return formattedInterval(first)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 65 { return AppTheme.mint }
        if score >= 45 { return AppTheme.amber }
        return AppTheme.coral
    }

    private func displayPercentages(_ choices: [HoraryChoiceResult]) -> [UUID: Int] {
        let floors = choices.map { Int(floor($0.likelihood)) }
        var remainder = max(0, 100 - floors.reduce(0, +))
        let fractionalOrder = choices.indices.sorted {
            choices[$0].likelihood - floor(choices[$0].likelihood)
                > choices[$1].likelihood - floor(choices[$1].likelihood)
        }
        var values = floors
        for index in fractionalOrder where remainder > 0 {
            values[index] += 1
            remainder -= 1
        }
        return Dictionary(
            uniqueKeysWithValues: zip(choices, values).map { ($0.0.id, $0.1) }
        )
    }

    private func overlay(for session: HorarySession) -> HoraryOverlay {
        var houses: Set<Int> = [1]
        var labels: [CelestialBody: [String]] = [:]
        var aspects: Set<String> = []

        func append(_ label: String, for body: CelestialBody) {
            var values = labels[body, default: []]
            if !values.contains(label) { values.append(label) }
            labels[body] = values
        }

        switch session.mode {
        case .yesNo, .timing:
            if let analysis = session.analysis {
                houses.insert(analysis.targetHouse)
                append(localized("You", "你", language: model.language), for: analysis.querentRuler)
                append(
                    session.mode == .timing
                        ? localized("Goal", "目标", language: model.language)
                        : localized("Answer", "结果", language: model.language),
                    for: analysis.targetRuler
                )
                if let relationship = analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        case .choice:
            if let first = session.choices.first {
                append(localized("You", "你", language: model.language), for: first.analysis.querentRuler)
            }
            for (index, choice) in session.choices.enumerated() {
                houses.insert(choice.house)
                append(
                    "\(String(UnicodeScalar(65 + index)!)) · \(choice.label)",
                    for: choice.ruler
                )
                if let relationship = choice.analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        }
        return HoraryOverlay(
            highlightedHouses: houses,
            planetLabels: labels.mapValues { $0.joined(separator: " / ") },
            keyAspectIDs: aspects
        )
    }

    private func formattedSessionDate(_ session: HorarySession) -> String {
        "\(formattedDate(session.createdAt, includesTime: true)) · \(session.locationName)"
    }

    private func formattedDate(_ date: Date, includesTime: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = includesTime ? .short : .none
        return formatter.string(from: date)
    }

    private func formattedInterval(_ candidate: ElectionTimingCandidate) -> String {
        if timingPrecision == .day {
            return formattedDate(candidate.peakDate, includesTime: false)
        }
        let start = formattedDate(candidate.interval.start, includesTime: false)
        let end = formattedDate(
            candidate.interval.end.addingTimeInterval(-1),
            includesTime: false
        )
        return "\(start) – \(end)"
    }
}

private enum AskViewError: Error {
    case invalidTimeZone
}

private enum AskContentComposer {
    static func cards(
        for session: HorarySession,
        language: AppLanguage
    ) throws -> [AskResultCard] {
        let content = ContentProvider(language: language)
        switch session.mode {
        case .yesNo:
            guard let analysis = session.analysis else { return [] }
            let band: String
            if analysis.score >= 80 { band = "very-likely" }
            else if analysis.score >= 65 { band = "likely" }
            else if analysis.score >= 45 { band = "mixed" }
            else if analysis.score >= 30 { band = "unlikely" }
            else { band = "very-unlikely" }
            return try [
                card(
                    id: "answer",
                    icon: "checkmark.seal",
                    copy: content.requiredCopy(
                        key: "ask.verdict.\(band)",
                        variables: ["score": "\(Int(analysis.score.rounded()))"]
                    )
                ),
                relationshipCard(analysis, content: content),
                moonCard(analysis, content: content),
                obstacleCard(analysis, content: content),
            ]
        case .choice:
            guard let first = session.choices.first else { return [] }
            let close = session.choices.count > 1
                && first.likelihood - session.choices[1].likelihood <= 8
            return try [
                card(
                    id: "choice-result",
                    icon: "list.number",
                    copy: content.requiredCopy(
                        key: close ? "ask.choice.close" : "ask.choice.leading",
                        variables: [
                            "option": first.label,
                            "score": "\(Int(first.likelihood.rounded()))",
                        ]
                    )
                ),
                relationshipCard(first.analysis, content: content),
                moonCard(first.analysis, content: content),
                obstacleCard(first.analysis, content: content),
            ]
        case .timing:
            guard let first = session.timingCandidates.first else { return [] }
            return try [
                card(
                    id: "timing-result",
                    icon: "calendar.badge.checkmark",
                    copy: content.requiredCopy(
                        key: "ask.timing.best",
                        variables: ["score": "\(Int(first.score.rounded()))"]
                    )
                ),
                relationshipCard(first.analysis, content: content),
                moonCard(first.analysis, content: content),
                obstacleCard(first.analysis, content: content),
            ]
        }
    }

    private static func relationshipCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let key: String
        if let relationship = analysis.relationship {
            if relationship.phase == .separating {
                key = "ask.connection.separating"
            } else if relationship.kind.supportive || relationship.kind == .conjunction {
                key = "ask.connection.supportive"
            } else {
                key = "ask.connection.challenging"
            }
        } else {
            key = "ask.connection.none"
        }
        return card(
            id: "connection",
            icon: "link",
            copy: try content.requiredCopy(key: key)
        )
    }

    private static func moonCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        card(
            id: "moon",
            icon: "moon.stars",
            copy: try content.requiredCopy(
                key: analysis.moon.isVoidOfCourse
                    ? "ask.moon.void"
                    : "ask.moon.next"
            )
        )
    }

    private static func obstacleCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let risk = analysis.components.first { $0.id == "risk" || $0.id == "obstruction" }?.value ?? 0
        return card(
            id: "obstacle",
            icon: risk <= -10 ? "exclamationmark.triangle" : "shield.checkered",
            copy: try content.requiredCopy(
                key: risk <= -10 ? "ask.risk.present" : "ask.risk.limited"
            )
        )
    }

    private static func card(
        id: String,
        icon: String,
        copy: (summary: String, detail: String)
    ) -> AskResultCard {
        AskResultCard(
            id: id,
            icon: icon,
            summary: copy.summary,
            detail: copy.detail
        )
    }
}

private struct HoraryProfessionalView: View {
    let session: HorarySession
    let overlay: HoraryOverlay
    let language: AppLanguage

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ChartWheelView(
                    snapshot: session.snapshot,
                    reference: nil,
                    comparisonAspects: [],
                    language: language,
                    horaryOverlay: overlay
                )
                .padding(10)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

                AspectChartView(
                    aspects: HoraryEngine.validTraditionalAspects(in: session.snapshot),
                    movingPoints: session.snapshot.points,
                    referencePoints: [],
                    language: language,
                    comparison: false
                )

                ForEach(analyses, id: \.targetHouse) { analysis in
                    analysisBlock(analysis)
                }
            }
            .padding(18)
        }
        .background(ScreenBackground())
        .navigationTitle(localized("Chart analysis", "专业分析", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var analyses: [HoraryAnalysis] {
        if session.mode == .choice {
            return session.choices.map(\.analysis)
        }
        return [session.analysis].compactMap { $0 }
    }

    private func analysisBlock(_ analysis: HoraryAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                localized(
                    "House \(analysis.targetHouse) analysis",
                    "第\(analysis.targetHouse)宫分析",
                    language: language
                )
            )
            .font(.headline)
            .foregroundStyle(AppTheme.text)

            professionalRow(
                localized("Querent ruler", "提问者主星", language: language),
                bodyName(analysis.querentRuler, language: language)
            )
            professionalRow(
                localized("Target ruler", "目标主星", language: language),
                bodyName(analysis.targetRuler, language: language)
            )
            professionalRow(
                localized("Connection", "代表星联系", language: language),
                analysis.relationship.map {
                    "\(aspectKindName($0.kind, language: language)) · \(phaseLabel($0.phase, language: language)) · \(formatOrb($0.orbDegrees))"
                } ?? localized("No major aspect in orb", "容许度内没有主要相位", language: language)
            )
            professionalRow(
                localized("Reception", "接纳", language: language),
                receptionLabel(analysis)
            )
            professionalRow(
                localized("Moon", "月亮", language: language),
                analysis.moon.isVoidOfCourse
                    ? localized("Void of course", "空亡", language: language)
                    : nextMoonAspect(analysis)
            )

            Divider().overlay(AppTheme.line)
            ForEach(analysis.components) { component in
                HStack {
                    Text(componentLabel(component.id))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(String(format: "%+.1f", component.value))
                        .font(AppTypography.label.monospacedDigit())
                        .foregroundStyle(component.value < 0 ? AppTheme.coral : AppTheme.mint)
                }
            }
            HStack {
                Text(localized("Total", "总分", language: language))
                    .font(.headline)
                Spacer()
                Text("\(Int(analysis.score.rounded()))")
                    .font(.title3.bold().monospacedDigit())
            }
            .foregroundStyle(AppTheme.text)
        }
        .cardSurface()
    }

    private func professionalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(AppTypography.label)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func receptionLabel(_ analysis: HoraryAnalysis) -> String {
        if analysis.receptionFromQuerent.isPresent, analysis.receptionFromTarget.isPresent {
            return localized("Mutual reception", "互相接纳", language: language)
        }
        if analysis.receptionFromQuerent.isPresent || analysis.receptionFromTarget.isPresent {
            return localized("One-way reception", "单向接纳", language: language)
        }
        return localized("No major reception", "没有主要接纳", language: language)
    }

    private func nextMoonAspect(_ analysis: HoraryAnalysis) -> String {
        guard let aspect = analysis.moon.nextAspect else {
            return localized("No next major aspect", "没有后续主要相位", language: language)
        }
        let target = CelestialBody(rawValue: aspect.secondID)
            .map { bodyName($0, language: language) } ?? aspect.secondID
        let hours = analysis.moon.hoursUntilNextAspect.map { Int($0.rounded()) }
        return "\(aspectKindName(aspect.kind, language: language)) \(target)"
            + (hours.map { LocalizedFormatters.hoursDuration($0, language: language) } ?? "")
    }

    private func componentLabel(_ id: String) -> String {
        let english: [String: String] = [
            "significator-relationship": "Significator relationship",
            "reception": "Reception",
            "moon": "Moon condition",
            "strength": "Planet strength",
            "obstruction": "Obstructions",
            "target-strength": "Target ruler strength",
            "moon-condition": "Moon condition",
            "ascendant-strength": "Ascendant ruler",
            "benefic-support": "Benefic support",
            "applying-connection": "Applying connection",
            "risk": "Risk",
        ]
        let chinese: [String: String] = [
            "significator-relationship": "代表星关系",
            "reception": "接纳",
            "moon": "月亮状态",
            "strength": "行星力量",
            "obstruction": "阻碍",
            "target-strength": "目标主星力量",
            "moon-condition": "月亮状态",
            "ascendant-strength": "上升主星",
            "benefic-support": "吉星支持",
            "applying-connection": "入相联系",
            "risk": "风险",
        ]
        return language == .english ? english[id, default: id] : chinese[id, default: id]
    }
}

struct AskHistoryView: View {
    let entries: [AskHistoryEntry]
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var selected: AskHistoryEntry?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle(
                        eyebrow: localized("ASK HISTORY", "问事历史", language: language),
                        title: localized("History", "历史", language: language),
                        subtitle: localized("Local results only", "仅保存在本机", language: language)
                    )
                    if entries.isEmpty {
                        Text(localized("No questions yet.", "还没有问过问题。", language: language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .cardSurface()
                    } else {
                        ForEach(entries) { entry in
                            Button {
                                selected = entry
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.question)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text("\(entry.answerTitle) · \(entry.answerText)")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.muted)
                                    Text(shortDate(entry.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.muted.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(13)
                                .cardSurface()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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
                    Image(systemName: "chevron.left").foregroundStyle(AppTheme.text)
                }
                .accessibilityLabel(localized("Back", "返回", language: language))
            }
        }
        .sheet(item: $selected) { entry in
            AskHistoryDetailView(entry: entry, language: language)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AskHistoryDetailView: View {
    let entry: AskHistoryEntry
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(entry.question)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(entry.answerTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                        if !entry.answerText.isEmpty {
                            Text(entry.answerText)
                                .font(.body)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                    .padding(18)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(AppTheme.text)
                    }
                    .accessibilityLabel(localized("Close", "关闭", language: language))
                }
            }
        }
    }
}
