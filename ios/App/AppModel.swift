import AstroCore
import Combine
import CommonCrypto
import Foundation
import Network

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
    @Published private(set) var solarReturn: ChartSnapshot?
    @Published private(set) var solarReturnAspects: [ChartAspect] = []
    @Published private(set) var synastry: SynastryComparison?
    @Published private(set) var transitAspects: [ChartAspect] = []
    @Published private(set) var progressedAspects: [ChartAspect] = []
    @Published private(set) var todaySignals: [DailySignal] = []
    @Published private(set) var todayContributions: [WeeklySignalContribution] = []
    @Published private(set) var todayDashboardModel: TodayDashboardModel?
    @Published private(set) var transitCalendar: [Int] = []
    @Published private(set) var weeklyForecast: WeeklyForecastModel = .empty
    @Published private(set) var isCalculating = false
    @Published private(set) var isOnline = true
    @Published private(set) var aiConsentGranted: Bool
    @Published private(set) var aiContent: [ChartKind: AIChartContent] = [:]
    @Published private(set) var availableReports: [AvailableReport] = []
    @Published private(set) var savedReports: [SavedReport] = []
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
    private let aiClient = AIGenerationClient()
    private let aiCache = AIGenerationCache()
    private let reportStore = ReportStore()
    private var generatingCharts: Set<ChartKind> = []
    private var generatingPeriods: Set<ReportScope> = []
    private var networkMonitor: NWPathMonitor?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aiConsentGranted = defaults.bool(forKey: "ai.network.consent.v1")
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
        startNetworkMonitoring()
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

            let solarReturnSnapshot = try await calculator.calculateSolarReturn(
                birthDate: profile.birthDateUTC,
                after: now,
                location: profile.location,
                preset: preset(for: .solarReturn)
            )
            let solarReturnCross = SwissEphemerisCalculator.solarReturnNatalAspects(
                solarReturn: solarReturnSnapshot,
                natal: natalSnapshot
            )
            let synastryComparison: SynastryComparison?
            if let partner = savedPeople.first?.profile {
                synastryComparison = try await calculator.calculateSynastry(
                    first: natalInput,
                    second: NatalInput(utcDate: partner.birthDateUTC, location: partner.location),
                    preset: preset(for: .synastry)
                )
            } else {
                synastryComparison = nil
            }

            natal = natalSnapshot
            transitReference = transitReferenceSnapshot
            progressedReference = progressedReferenceSnapshot
            currentSky = skySnapshot
            transit = transitMovingSnapshot
            progressed = progressedSnapshot
            solarReturn = solarReturnSnapshot
            solarReturnAspects = solarReturnCross
            synastry = synastryComparison
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
        case .solarReturn: solarReturn
        case .synastry: synastry?.first
        }
    }

    func comparisonAspects(for chart: ChartKind) -> [ChartAspect] {
        if focusedChart == chart {
            return focusedAspects
        }
        return switch chart {
        case .transit: transitAspects
        case .secondary: progressedAspects
        case .solarReturn: solarReturnAspects
        case .synastry: synastry?.crossAspects ?? []
        case .natal, .currentSky: snapshot(for: chart)?.aspects ?? []
        }
    }

    func referenceSnapshot(for chart: ChartKind) -> ChartSnapshot? {
        switch chart {
        case .transit: transitReference
        case .secondary: progressedReference
        case .solarReturn: natal
        case .synastry: synastry?.second
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
                transitCalendar: transitCalendar,
                preset: preset(for: chart).rawValue
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
    // MARK: - AI generation (LLM interpretation + reports)

    func grantAIConsent() {
        aiConsentGranted = true
        defaults.set(true, forKey: "ai.network.consent.v1")
    }

    func aiCardDetail(for chart: ChartKind, cardID: String) -> (detail: String?, status: AIDetailStatus) {
        guard aiConsentGranted, isOnline else {
            return (nil, .hidden)
        }
        let content = aiContent[chart] ?? .empty
        if let detail = content.cardDetails[cardID] {
            return (detail, .ready)
        }
        return (nil, content.status(for: cardID))
    }

    func aiReport(for chart: ChartKind) -> AIReport? {
        aiContent[chart]?.report
    }

    func ensureAIGeneration(for chart: ChartKind) {
        guard aiConsentGranted, isOnline else { return }
        guard snapshot(for: chart) != nil else { return }
        guard !generatingCharts.contains(chart) else { return }

        let cardIDs = Self.expectedCardIDs(for: chart)
        let params = aiParams(for: chart)
        let key = aiCacheKey(chart: chart, cardIDs: cardIDs, params: params)
        if let cached = aiCache.load(key: key) {
            applyAIResponse(cached, chart: chart, key: key, cardIDs: cardIDs)
            return
        }
        if let existing = aiContent[chart], existing.cacheKey == key {
            return
        }

        generatingCharts.insert(chart)
        var content = aiContent[chart] ?? .empty
        content.cacheKey = key
        for id in cardIDs {
            content.statusByCard[id] = .generating
        }
        aiContent[chart] = content

        Task {
            await performAIGeneration(chart: chart, key: key, cardIDs: cardIDs, params: params)
        }
    }

    private func performAIGeneration(chart: ChartKind, key: String, cardIDs: [String], params: [String: String]) async {
        defer { generatingCharts.remove(chart) }
        do {
            let facts = try buildAIFacts(chart: chart, params: params, cardIDs: cardIDs)
            let body: [String: Any] = [
                "mode": "chart",
                "chartKind": chart.contentPrefix,
                "periodType": NSNull(),
                "preset": preset(for: chart).rawValue,
                "profileHash": profileHashValue,
                "params": params,
                "facts": facts,
                "cardIDs": cardIDs,
                "locale": language.rawValue,
                "clientVersion": "ios-v2",
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            let request = AIGenerateRequest(bodyData: bodyData)
            let response = try await aiClient.generate(request)
            aiCache.save(key: key, scope: chart.contentPrefix, response: response, ttl: AIGenerationCache.ttl(for: chart))
            applyAIResponse(response, chart: chart, key: key, cardIDs: cardIDs)
        } catch {
            var content = aiContent[chart] ?? .empty
            for id in cardIDs {
                content.statusByCard[id] = .hidden
            }
            aiContent[chart] = content
        }
    }

    private func applyAIResponse(_ response: AIGenerateResponse, chart: ChartKind, key: String, cardIDs: [String]) {
        var content = aiContent[chart] ?? .empty
        content.cacheKey = key
        content.report = AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
        saveChartReport(chart: chart, response: response)
        for id in cardIDs {
            if let detail = response.cards[id]?.detail, !detail.isEmpty {
                content.cardDetails[id] = detail
                content.statusByCard[id] = .ready
            } else {
                content.statusByCard[id] = .hidden
            }
        }
        aiContent[chart] = content
    }

    private func buildAIFacts(chart: ChartKind, params: [String: String], cardIDs: [String]) throws -> [String: Any] {
        guard let snapshot = snapshot(for: chart) else {
            throw AppModelError.missingSnapshot
        }
        let reference = referenceSnapshot(for: chart)
        let comparison = comparisonAspects(for: chart)
        let partner: (name: String, chart: ChartSnapshot)?
        if chart == .synastry {
            if let partnerSnapshot = synastry?.second {
                partner = (savedPeople.first?.profile.name ?? "Partner", partnerSnapshot)
            } else {
                partner = nil
            }
        } else {
            partner = nil
        }
        return AIFactsBuilder.document(
            chart: chart,
            snapshot: snapshot,
            reference: reference,
            comparisonAspects: comparison,
            preset: preset(for: chart),
            personName: profile.name,
            partnerName: partner?.name,
            partnerChart: partner?.chart,
            params: params,
            locale: language.rawValue,
            cardIDs: cardIDs
        )
    }

    private var profileHashValue: String {
        let raw = [
            profile.name, profile.placeName, profile.timezoneID,
            String(profile.birthDateUTC.timeIntervalSince1970),
            String(profile.latitude), String(profile.longitude),
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func aiParams(for chart: ChartKind) -> [String: String] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        switch chart {
        case .natal, .currentSky, .solarReturn:
            return ["anchor": formatter.string(from: now)]
        case .transit:
            return ["anchor": formatter.string(from: now), "rangeDays": "7"]
        case .secondary:
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(birthDate: profile.birthDateUTC, targetDate: now)
            return ["anchor": formatter.string(from: now), "progressedDate": formatter.string(from: progressedDate)]
        case .synastry:
            return ["anchor": formatter.string(from: now), "partner": savedPeople.first?.profile.name ?? ""]
        }
    }

    private func aiCacheKey(chart: ChartKind, cardIDs: [String], params: [String: String]) -> String {
        let raw = [
            chart.contentPrefix,
            preset(for: chart).rawValue,
            profileHashValue,
            params.keys.sorted().map { "\($0)=\(params[$0] ?? "")" }.joined(separator: ","),
            language.rawValue,
            cardIDs.joined(separator: ","),
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private static func expectedCardIDs(for chart: ChartKind) -> [String] {
        switch chart {
        case .natal: ["natal-interpretation", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"]
        case .currentSky: ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"]
        case .transit: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"]
        case .secondary: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"]
        case .solarReturn: ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"]
        case .synastry: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"]
        }
    }

    // MARK: - Report library

    func refreshAvailableReports() async {
        let timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        let now = Date()
        var reports: [AvailableReport] = []
        reports.append(
            AvailableReport(
                scope: .daily,
                unlockedAt: ReportUnlock.nextLocalMidnight(after: now, timeZone: timeZone)
            )
        )
        reports.append(
            AvailableReport(
                scope: .monthly,
                unlockedAt: ReportUnlock.nextMonthStart(after: now, timeZone: timeZone)
            )
        )
        do {
            let calculator = try calculatorInstance()
            let moment = try await ReportUnlock.nextSolarReturn(birthDate: profile.birthDateUTC, after: now, calculator: calculator)
            reports.append(AvailableReport(scope: .solarReturn, unlockedAt: moment))
        } catch {
            reports.append(AvailableReport(scope: .solarReturn, unlockedAt: nil))
        }
        availableReports = reports
        savedReports = reportStore.load()
    }

    func generatePeriodReport(_ scope: ReportScope) async {
        guard aiConsentGranted, isOnline else { return }
        guard !generatingPeriods.contains(scope) else { return }
        generatingPeriods.insert(scope)
        defer { generatingPeriods.remove(scope) }

        do {
            let formatter = ISO8601DateFormatter()
            let now = Date()
            let params: [String: String] = ["anchor": formatter.string(from: now)]
            let facts: [String: Any]
            switch scope {
            case .daily:
                facts = AIFactsBuilder.periodDocument(
                    periodType: "daily",
                    personName: profile.name,
                    locale: language.rawValue,
                    events: todaySignalEvents(),
                    params: params
                )
            case .monthly:
                facts = AIFactsBuilder.periodDocument(
                    periodType: "monthly",
                    personName: profile.name,
                    locale: language.rawValue,
                    events: transitEventSummaries(),
                    params: params
                )
            case .solarReturn:
                facts = AIFactsBuilder.periodDocument(
                    periodType: "solar-return",
                    personName: profile.name,
                    locale: language.rawValue,
                    events: [],
                    params: params
                )
            }
            let body: [String: Any] = [
                "mode": "period",
                "periodType": scope.rawValue,
                "preset": NSNull(),
                "profileHash": profileHashValue,
                "params": params,
                "facts": facts,
                "cardIDs": [String](),
                "locale": language.rawValue,
                "clientVersion": "ios-v2",
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            let response = try await aiClient.generate(AIGenerateRequest(bodyData: bodyData))
            let periodScope = "period.\(scope.rawValue)"
            let key = aiPeriodCacheKey(scope: scope, params: params)
            aiCache.save(key: key, scope: periodScope, response: response, ttl: AIGenerationCache.ttl(for: .secondary))
            let saved = SavedReport(
                id: key,
                scope: periodScope,
                title: response.report.title,
                subtitle: response.report.subtitle,
                generatedAt: Date(),
                report: AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
            )
            reportStore.save(saved)
            savedReports = reportStore.load()
        } catch {
            // Silent failure: the library keeps its current state; retry on next tap.
        }
    }

    private func saveChartReport(chart: ChartKind, response: AIGenerateResponse) {
        let scope = "chart.\(chart.contentPrefix)"
        let existing = savedReports.contains { $0.scope == scope }
        if existing { return }
        let saved = SavedReport(
            id: scope,
            scope: scope,
            title: response.report.title,
            subtitle: response.report.subtitle,
            generatedAt: Date(),
            report: AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
        )
        reportStore.save(saved)
        savedReports = reportStore.load()
    }

    private func todaySignalEvents() -> [[String: Any]] {
        todaySignals.prefix(5).map { signal in
            [
                "id": signal.id,
                "category": signal.category.rawValue,
                "source": signal.source.rawValue,
                "title": signal.title,
                "detail": signal.subtitle,
                "strength": signal.strength,
                "time": signal.eventDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            ]
        }
    }

    private func transitEventSummaries() -> [[String: Any]] {
        transitAspects.prefix(12).map { aspect in
            [
                "first": aspect.firstID,
                "second": aspect.secondID,
                "kind": aspect.kind.rawValue,
                "phase": aspect.phase.rawValue,
                "orb": String(format: "%.2f", aspect.orbDegrees),
                "strength": String(format: "%.2f", aspect.strength),
            ]
        }
    }

    private func aiPeriodCacheKey(scope: ReportScope, params: [String: String]) -> String {
        let raw = [
            "period", scope.rawValue, profileHashValue,
            params.keys.sorted().map { "\($0)=\(params[$0] ?? "")" }.joined(separator: ","),
            language.rawValue,
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "ai-network-monitor"))
        networkMonitor = monitor
    }


}
enum AppModelError: LocalizedError {
    case missingEphemeris
    case missingSnapshot

    var errorDescription: String? {
        switch self {
        case .missingEphemeris:
            "The bundled Swiss Ephemeris data could not be found."
        case .missingSnapshot:
            "The chart has not been calculated yet."
        }
    }
}

enum SHA256Digest {
    static func hash(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
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
