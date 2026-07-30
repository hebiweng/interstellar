import AstroCore
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: UserProfile {
        didSet { saveProfile() }
    }
    @Published var selectedChart: ChartKind = .natal
    @Published var viewMode: ChartViewMode = .wheel
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language.v1")
            Task { await refresh() }
        }
    }
    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance.v1")
        }
    }
    @Published var fontSize: AppFontSize {
        didSet {
            defaults.set(fontSize.rawValue, forKey: "font-size.v1")
        }
    }
    @Published private(set) var savedPeople: [SavedPerson] = []
    @Published var presets: [ChartKind: CalculationPreset]
    @Published private(set) var natal: ChartSnapshot?
    @Published private(set) var transitReference: ChartSnapshot?
    @Published private(set) var progressedReference: ChartSnapshot?
    @Published private(set) var currentSky: ChartSnapshot?
    @Published private(set) var transit: ChartSnapshot?
    @Published private(set) var progressed: ChartSnapshot?
    @Published private(set) var transitAspects: [ChartAspect] = []
    @Published private(set) var progressedAspects: [ChartAspect] = []
    @Published private(set) var todaySignals: [DailySignal] = []
    @Published private(set) var todayContributions: [WeeklySignalContribution] = []
    @Published private(set) var todayDashboardModel: TodayDashboardModel?
    @Published private(set) var transitCalendar: [Int] = []
    @Published private(set) var weeklyForecast: WeeklyForecastModel = .empty
    @Published private(set) var isCalculating = false
    @Published private(set) var focusedChart: ChartKind?
    @Published private(set) var focusedChartDate: Date?
    @Published private(set) var isCalculatingFocus = false
    @Published private(set) var errorMessage: String?

    private var calculator: SwissEphemerisCalculator?
    private var focusedSnapshot: ChartSnapshot?
    private var focusedAspects: [ChartAspect] = []
    private var refreshRequested = false
    private let defaults: UserDefaults
    private var corpusProviders: [AppLanguage: Result<CorpusContentProvider, Error>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let testEnvironment = ProcessInfo.processInfo.environment
        if let data = defaults.data(forKey: "profile.v1"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        {
            profile = decoded
        } else {
            profile = .sample
        }
        language = AppLanguage(rawValue: testEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] ?? "")
            ?? AppLanguage(rawValue: defaults.string(forKey: "language.v1") ?? "")
            ?? .english
        appearance = AppAppearance(
            rawValue: testEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"]
                ?? defaults.string(forKey: "appearance.v1")
                ?? ""
        ) ?? .system
        fontSize = AppFontSize(
            rawValue: testEnvironment["INTERSTELLAR_UI_TEST_FONT_SIZE"]
                ?? defaults.string(forKey: "font-size.v1")
                ?? ""
        ) ?? .standard
        if let data = defaults.data(forKey: "people.v1"),
           let decoded = try? JSONDecoder().decode([SavedPerson].self, from: data)
        {
            savedPeople = decoded
        }
        var restored: [ChartKind: CalculationPreset] = [:]
        for kind in ChartKind.allCases {
            let raw = defaults.string(forKey: "preset.\(kind.rawValue)")
            let decoded = raw.flatMap(CalculationPreset.init(rawValue:)) ?? .modern
            restored[kind] = decoded == .special ? .modern : decoded
            if decoded == .special {
                defaults.set(CalculationPreset.modern.rawValue, forKey: "preset.\(kind.rawValue)")
            }
        }
        presets = restored
    }

    func preset(for chart: ChartKind) -> CalculationPreset {
        presets[chart] ?? .modern
    }

    func setPreset(_ preset: CalculationPreset, for chart: ChartKind) {
        guard CalculationPreset.consumerCases.contains(preset) else { return }
        clearChartFocus()
        presets[chart] = preset
        defaults.set(preset.rawValue, forKey: "preset.\(chart.rawValue)")
        Task { await refresh() }
    }

    func savePerson(_ person: SavedPerson) {
        if let index = savedPeople.firstIndex(where: { $0.id == person.id }) {
            savedPeople[index] = person
        } else {
            savedPeople.append(person)
        }
        savedPeople.sort {
            $0.profile.name.localizedCaseInsensitiveCompare($1.profile.name) == .orderedAscending
        }
        persistPeople()
    }

    func deletePeople(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            savedPeople.remove(at: index)
        }
        persistPeople()
    }

    func refresh() async {
        clearChartFocus()
        guard !isCalculating else {
            refreshRequested = true
            return
        }
        isCalculating = true
        refreshRequested = false
        errorMessage = nil
        todayDashboardModel = nil
        do {
            let calculator = try calculatorInstance()
            let natalInput = NatalInput(utcDate: profile.birthDateUTC, location: profile.location)
            let now = Date()
            let skyInput = NatalInput(utcDate: now, location: profile.location)
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: profile.birthDateUTC,
                targetDate: now
            )
            let progressedInput = NatalInput(utcDate: progressedDate, location: profile.location)

            let natalSnapshot = try await calculator.calculateSnapshot(
                natalInput,
                preset: preset(for: .natal)
            )
            let transitReferenceSnapshot = preset(for: .transit) == preset(for: .natal)
                ? natalSnapshot
                : try await calculator.calculateSnapshot(
                    natalInput,
                    preset: preset(for: .transit)
                )
            let progressedReferenceSnapshot = preset(for: .secondary) == preset(for: .natal)
                ? natalSnapshot
                : try await calculator.calculateSnapshot(
                    natalInput,
                    preset: preset(for: .secondary)
                )
            let skySnapshot = try await calculator.calculateSnapshot(
                skyInput,
                preset: preset(for: .currentSky)
            )
            let transitMovingSnapshot = preset(for: .transit) == preset(for: .currentSky)
                ? skySnapshot
                : try await calculator.calculateSnapshot(skyInput, preset: preset(for: .transit))
            let progressedSnapshot = try await calculator.calculateSnapshot(
                progressedInput,
                preset: preset(for: .secondary),
                aspectOrbDegrees: 3
            )

            natal = natalSnapshot
            transitReference = transitReferenceSnapshot
            progressedReference = progressedReferenceSnapshot
            currentSky = skySnapshot
            transit = transitMovingSnapshot
            progressed = progressedSnapshot
            transitAspects = SwissEphemerisCalculator.compare(
                moving: transitMovingSnapshot,
                reference: transitReferenceSnapshot,
                orbDegrees: 3
            )
            progressedAspects = SwissEphemerisCalculator.compare(
                moving: progressedSnapshot,
                reference: progressedReferenceSnapshot,
                orbDegrees: 2
            )
            let dashboardRules = TodayDashboardRules.load()
            let todayContext = WeeklyDayContext(
                date: now,
                natal: natalSnapshot,
                frames: [
                    "natal": WeeklySignalFrame(
                        sourceID: "natal",
                        aspects: natalSnapshot.aspects,
                        reference: natalSnapshot
                    ),
                    "current-sky": WeeklySignalFrame(
                        sourceID: "current-sky",
                        aspects: skySnapshot.aspects,
                        reference: natalSnapshot
                    ),
                    "transit": WeeklySignalFrame(
                        sourceID: "transit",
                        aspects: transitAspects,
                        reference: transitReferenceSnapshot
                    ),
                    "secondary": WeeklySignalFrame(
                        sourceID: "secondary",
                        aspects: progressedAspects,
                        reference: progressedReferenceSnapshot
                    ),
                ]
            )
            todayContributions = WeeklySignalRegistry.standard(rules: dashboardRules)
                .flatMap { $0.contributions(for: todayContext) }
            transitCalendar = try await buildTransitCalendar(
                calculator: calculator,
                natal: transitReferenceSnapshot,
                startingAt: now
            )
            weeklyForecast = try await buildWeeklyForecast(
                calculator: calculator,
                natal: natalSnapshot,
                transitReference: transitReferenceSnapshot,
                progressedReference: progressedReferenceSnapshot,
                startingAt: now
            )
            let activeSignals = buildActiveSignals(
                sky: skySnapshot,
                transits: transitAspects,
                progressions: progressedAspects,
                language: language
            )
            let todayEvents = try await TodayEngine(
                calculator: calculator,
                profile: profile,
                natal: transitReferenceSnapshot,
                skyPreset: preset(for: .currentSky),
                transitPreset: preset(for: .transit),
                language: language,
                content: ContentProvider(language: language)
            ).scan(containing: now)
            todaySignals = Array((todayEvents + activeSignals).prefix(5))
            todayDashboardModel = try TodayDashboardFactory.make(
                contributions: todayContributions,
                signals: todaySignals,
                content: ContentProvider(language: language),
                rules: dashboardRules,
                language: language,
                timeZone: TimeZone(identifier: profile.timezoneID) ?? .current
            )
        } catch {
            errorMessage = language == .english
                ? error.localizedDescription
                : "本地星盘计算失败，请检查出生资料后重试。"
        }
        isCalculating = false
        if refreshRequested {
            await refresh()
        }
    }

    func snapshot(for chart: ChartKind) -> ChartSnapshot? {
        if focusedChart == chart {
            return focusedSnapshot
        }
        return switch chart {
        case .natal: natal
        case .currentSky: currentSky
        case .transit: transit
        case .secondary: progressed
        }
    }

    func comparisonAspects(for chart: ChartKind) -> [ChartAspect] {
        if focusedChart == chart {
            return focusedAspects
        }
        return switch chart {
        case .transit: transitAspects
        case .secondary: progressedAspects
        case .natal, .currentSky: snapshot(for: chart)?.aspects ?? []
        }
    }

    func referenceSnapshot(for chart: ChartKind) -> ChartSnapshot? {
        switch chart {
        case .transit: transitReference
        case .secondary: progressedReference
        case .natal, .currentSky: nil
        }
    }

    func insightCards(for chart: ChartKind) -> InsightCardLoadState {
        let providerResult: Result<CorpusContentProvider, Error>
        if let cached = corpusProviders[language] {
            providerResult = cached
        } else {
            providerResult = Result { try CorpusContentProvider(language: language) }
            corpusProviders[language] = providerResult
        }

        do {
            let provider = try providerResult.get()
            let cards = try InsightFactory.make(
                chart: chart,
                snapshot: snapshot(for: chart),
                natal: chart.isComparison ? referenceSnapshot(for: chart) : natal,
                aspects: comparisonAspects(for: chart),
                content: provider,
                language: language,
                transitCalendar: transitCalendar
            )
            return .loaded(cards)
        } catch {
            return .unavailable(
                localized(
                    "Interpretation content is incomplete for this chart.",
                    "当前星盘的解读内容尚未完整加载。",
                    language: language
                )
            )
        }
    }

    func selectChart(_ chart: ChartKind) {
        clearChartFocus()
        selectedChart = chart
    }

    func openSignal(_ signal: DailySignal) {
        let chart: ChartKind
        switch signal.source {
        case .sky: chart = .currentSky
        case .transit: chart = .transit
        case .secondary: chart = .secondary
        }
        selectedChart = chart

        guard let date = signal.eventDate else {
            clearChartFocus()
            return
        }

        focusedChart = chart
        focusedChartDate = date
        focusedSnapshot = nil
        focusedAspects = []
        isCalculatingFocus = true
        Task { await calculateFocusedChart(chart, at: date) }
    }

    func clearChartFocus() {
        focusedChart = nil
        focusedChartDate = nil
        focusedSnapshot = nil
        focusedAspects = []
        isCalculatingFocus = false
    }

    func calculateHorarySnapshot(
        at date: Date,
        location: GeographicLocation
    ) async throws -> ChartSnapshot {
        let calculator = try calculatorInstance()
        return try await calculator.calculateSnapshot(
            NatalInput(utcDate: date, location: location),
            configuration: .horary
        )
    }

    func searchElectionTiming(
        _ request: ElectionTimingRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [ElectionTimingCandidate] {
        let calculator = try calculatorInstance()
        return try await ElectionTimingEngine(calculator: calculator)
            .search(request, progress: progress)
    }

    private func calculateFocusedChart(_ chart: ChartKind, at date: Date) async {
        do {
            let calculator = try calculatorInstance()
            let natalSnapshot: ChartSnapshot
            if let reference = referenceSnapshot(for: chart) {
                natalSnapshot = reference
            } else {
                natalSnapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                    preset: preset(for: chart)
                )
            }

            let movingDate: Date
            if chart == .secondary {
                movingDate = SwissEphemerisCalculator.secondaryProgressedDate(
                    birthDate: profile.birthDateUTC,
                    targetDate: date
                )
            } else {
                movingDate = date
            }
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: movingDate, location: profile.location),
                preset: preset(for: chart),
                aspectOrbDegrees: chart == .secondary ? 3 : 6
            )
            let aspects: [ChartAspect]
            if chart.isComparison {
                aspects = SwissEphemerisCalculator.compare(
                    moving: snapshot,
                    reference: natalSnapshot,
                    orbDegrees: chart == .secondary ? 2 : 3
                )
            } else {
                aspects = snapshot.aspects
            }

            guard focusedChart == chart, focusedChartDate == date else { return }
            focusedSnapshot = snapshot
            focusedAspects = aspects
        } catch {
            guard focusedChart == chart, focusedChartDate == date else { return }
            errorMessage = language == .english
                ? error.localizedDescription
                : "无法计算所选事件时刻的星盘。"
        }
        if focusedChart == chart, focusedChartDate == date {
            isCalculatingFocus = false
        }
    }

    private func calculatorInstance() throws -> SwissEphemerisCalculator {
        if let calculator { return calculator }
        let candidates = [
            Bundle.main.url(forResource: "ephe", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("ephe"),
        ].compactMap { $0 }
        guard let directory = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            throw AppModelError.missingEphemeris
        }
        let created = try SwissEphemerisCalculator(ephemerisDirectory: directory)
        calculator = created
        return created
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: "profile.v1")
        }
    }

    private func persistPeople() {
        if let data = try? JSONEncoder().encode(savedPeople) {
            defaults.set(data, forKey: "people.v1")
        }
    }

    private func buildActiveSignals(
        sky: ChartSnapshot,
        transits: [ChartAspect],
        progressions: [ChartAspect],
        language: AppLanguage
    ) -> [DailySignal] {
        let transitSignals = transits.prefix(3).map {
            DailySignal(
                id: "transit-\($0.id)",
                category: .activeNow,
                source: .transit,
                title: aspectTitle($0, prefix: localized("Transit ", "行运", language: language), language: language),
                subtitle: "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        let skySignals = sky.aspects.prefix(2).map {
            DailySignal(
                id: "sky-\($0.id)",
                category: .activeNow,
                source: .sky,
                title: aspectTitle($0, language: language),
                subtitle: "\(localized("Active now", "当前活跃", language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        let progressedSignal = progressions.first.map {
            DailySignal(
                id: "secondary-\($0.id)",
                category: .activeNow,
                source: .secondary,
                title: aspectTitle($0, prefix: localized("Progressed ", "次限", language: language), language: language),
                subtitle: "\(localized("Long-term background", "长期背景", language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        return (Array(transitSignals) + Array(skySignals) + [progressedSignal].compactMap { $0 })
            .sorted { $0.strength > $1.strength }
            .prefix(5)
            .map { $0 }
    }

    private func buildWeeklyForecast(
        calculator: SwissEphemerisCalculator,
        natal: ChartSnapshot,
        transitReference: ChartSnapshot,
        progressedReference: ChartSnapshot,
        startingAt date: Date
    ) async throws -> WeeklyForecastModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        let start = calendar.startOfDay(for: date)
        var contexts: [WeeklyDayContext] = []
        contexts.reserveCapacity(7)

        for offset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let localNoon = calendar.date(byAdding: .hour, value: 12, to: day)
            else {
                continue
            }
            let input = NatalInput(utcDate: localNoon, location: profile.location)
            let sky = try await calculator.calculateSnapshot(
                input,
                preset: preset(for: .currentSky)
            )
            let transitMoving = preset(for: .transit) == preset(for: .currentSky)
                ? sky
                : try await calculator.calculateSnapshot(input, preset: preset(for: .transit))
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: profile.birthDateUTC,
                targetDate: localNoon
            )
            let progressedMoving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: progressedDate, location: profile.location),
                preset: preset(for: .secondary),
                aspectOrbDegrees: 3
            )

            contexts.append(
                WeeklyDayContext(
                    date: localNoon,
                    natal: natal,
                    frames: [
                        "natal": WeeklySignalFrame(
                            sourceID: "natal",
                            aspects: natal.aspects,
                            reference: natal
                        ),
                        "current-sky": WeeklySignalFrame(
                            sourceID: "current-sky",
                            aspects: sky.aspects,
                            reference: natal
                        ),
                        "transit": WeeklySignalFrame(
                            sourceID: "transit",
                            aspects: SwissEphemerisCalculator.compare(
                                moving: transitMoving,
                                reference: transitReference,
                                orbDegrees: 3
                            ),
                            reference: transitReference
                        ),
                        "secondary": WeeklySignalFrame(
                            sourceID: "secondary",
                            aspects: SwissEphemerisCalculator.compare(
                                moving: progressedMoving,
                                reference: progressedReference,
                                orbDegrees: 2
                            ),
                            reference: progressedReference
                        ),
                    ]
                )
            )
        }

        let rules = TodayDashboardRules.load()
        return try WeeklyForecastFactory.make(
            contexts: contexts,
            providers: WeeklySignalRegistry.standard(rules: rules),
            content: ContentProvider(language: language)
        )
    }

    private func buildTransitCalendar(
        calculator: SwissEphemerisCalculator,
        natal: ChartSnapshot,
        startingAt date: Date
    ) async throws -> [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        let start = calendar.startOfDay(for: date)
        var values: [Int] = []
        values.reserveCapacity(7)

        for offset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let localNoon = calendar.date(byAdding: .hour, value: 12, to: day)
            else {
                values.append(0)
                continue
            }
            let moving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: localNoon, location: profile.location),
                preset: preset(for: .transit)
            )
            let aspects = SwissEphemerisCalculator.compare(
                moving: moving,
                reference: natal,
                orbDegrees: 3
            )
            let strongest = Array(aspects.prefix(8))
            guard !strongest.isEmpty else {
                values.append(0)
                continue
            }
            let density = strongest.reduce(0) { $0 + $1.strength } / 8
            values.append(Int(min(1, density) * 100))
        }
        return values
    }
}

enum AppModelError: LocalizedError {
    case missingEphemeris

    var errorDescription: String? {
        "The bundled Swiss Ephemeris data could not be found."
    }
}

func aspectTitle(
    _ aspect: ChartAspect,
    prefix: String = "",
    language: AppLanguage = .english
) -> String {
    ConsumerCopy.connectionTitle(aspect, language: language)
}

func formatOrb(_ value: Double) -> String {
    String(format: "%.2f°", value)
}

func tone(_ kind: AspectKind) -> InsightTone {
    if kind.supportive { return .supportive }
    if kind.challenging { return .challenging }
    return .transition
}

func phaseLabel(_ phase: AspectPhase, language: AppLanguage) -> String {
    ConsumerCopy.timing(phase, language: language)
}
