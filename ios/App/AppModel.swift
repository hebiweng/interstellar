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
    @Published private(set) var currentSkyTargetDate = Date()
    @Published private(set) var transitTargetDate = Date()
    @Published private(set) var secondaryTargetDate = Date()
    @Published private(set) var solarReturnYear = Calendar.current.component(.year, from: Date())
    @Published private(set) var currentSkyUsesLiveDefault = true
    @Published private(set) var transitUsesLiveDefault = true
    @Published private(set) var secondaryUsesLiveDefault = true
    @Published private(set) var currentSkyLocationOverride: ChartLocationSelection?
    @Published private(set) var transitLocationOverride: ChartLocationSelection?
    @Published private(set) var solarReturnLocationOverride: ChartLocationSelection?
    @Published private(set) var transitRangeDays = 7
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
    @Published var chartSubjectID: String {
        didSet {
            defaults.set(chartSubjectID, forKey: "charts.subject.v1")
            if synastryPartnerID == chartSubjectID {
                synastryPartnerID = nil
            }
            Task { await refresh() }
        }
    }
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
    @Published var synastryPartnerID: String? {
        didSet {
            defaults.set(synastryPartnerID, forKey: "synastry.partner.v1")
            Task { await refresh() }
        }
    }
    @Published private(set) var transitAspects: [ChartAspect] = []
    @Published private(set) var progressedAspects: [ChartAspect] = []
    @Published private(set) var todaySignals: [DailySignal] = []
    @Published private(set) var todayContributions: [WeeklySignalContribution] = []
    @Published private(set) var todayDashboardModel: TodayDashboardModel?
    @Published private(set) var transitCalendar: [TransitCalendarDay] = []
    @Published private(set) var transitContentPlan: TransitContentPlan?
    @Published private(set) var chartEvents = ChartEventData.empty
    @Published private(set) var weeklyForecast: WeeklyForecastModel = .empty
    @Published private(set) var isCalculating = false
    @Published private(set) var isEnriching = false
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
    private var todayNatalForContent: ChartSnapshot?
    private var todaySkyForContent: ChartSnapshot?
    private var todayTransitForContent: ChartSnapshot?
    private var todayTransitAspectsForContent: [ChartAspect] = []
    private var refreshRequested = false
    private var refreshInFlight = false
    private let defaults: UserDefaults
    private var corpusProviders: [AppLanguage: Result<CorpusContentProvider, Error>] = [:]
    private var copyCatalogProviders: [AppLanguage: Result<CopyCatalogProvider, Error>] = [:]
    private let aiClient = AIGenerationClient()
    private let artifactStore = GeneratedArtifactStore()
    private let snapshotCache = SnapshotCacheStore()
    private var generatingCharts: Set<ChartKind> = []
    private var generatingPeriods: Set<ReportScope> = []
    private var networkMonitor: NWPathMonitor?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aiConsentGranted = defaults.bool(forKey: "ai.network.consent.v1")
        synastryPartnerID = defaults.string(forKey: "synastry.partner.v1")
        chartSubjectID = defaults.string(forKey: "charts.subject.v1") ?? "self"
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
        if testEnvironment["INTERSTELLAR_UI_TEST_SYNASTRY_SAMPLE"] == "1", savedPeople.isEmpty {
            let partner = SavedPerson(
                id: UUID(uuidString: "72A8F98A-2E25-4CC3-91D5-65FCFEC808A4")!,
                profile: UserProfile(
                    name: "Alex Morgan",
                    birthDateUTC: Date(timeIntervalSince1970: 663_422_400),
                    placeName: "Shanghai, China",
                    timezoneID: "Asia/Shanghai",
                    latitude: 31.2304,
                    longitude: 121.4737
                ),
                relationship: .partner
            )
            savedPeople = [partner]
            synastryPartnerID = partner.id.uuidString
        }
        restoreSnapshotCache()
        reloadSavedReports()
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

    var chartSubjectProfile: UserProfile {
        profileForPersonID(chartSubjectID) ?? profile
    }

    func profileForPersonID(_ id: String) -> UserProfile? {
        if id == "self" { return profile }
        return savedPeople.first(where: { $0.id.uuidString == id })?.profile
    }

    func clearReports() {
        artifactStore.clearAll()
        savedReports = []
        aiContent = [:]
        Task { await refreshAvailableReports() }
    }

    func clearAskHistory() {
        AskHistoryStore.shared.removeAll()
    }

    func clearAICache() {
        artifactStore.clearAll()
        aiContent = [:]
        reloadSavedReports()
    }

    func clearGeneratedArtifacts(for chart: ChartKind) {
        artifactStore.remove(chartKind: chart)
        aiContent[chart] = .empty
        reloadSavedReports()
    }

    func clearGeneratedArtifactsForCurrentPerson() {
        artifactStore.remove(subjectHash: profileHashValue)
        aiContent = [:]
        reloadSavedReports()
    }

    func clearGeneratedArtifacts(for person: SavedPerson) {
        artifactStore.remove(subjectHash: profileHash(person.profile))
        aiContent[.synastry] = .empty
        reloadSavedReports()
    }

    func deletePeople(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let deletedID = savedPeople[index].id.uuidString
            artifactStore.remove(subjectHash: profileHash(savedPeople[index].profile))
            savedPeople.remove(at: index)
            if chartSubjectID == deletedID { chartSubjectID = "self" }
            if synastryPartnerID == deletedID { synastryPartnerID = nil }
        }
        persistPeople()
        reloadSavedReports()
    }

    private func reloadSavedReports() {
        savedReports = (artifactStore.loadAll().map { SavedReport(artifact: $0) } + artifactStore.loadPeriodReports())
            .sorted { $0.generatedAt > $1.generatedAt }
    }

    func refresh() async {
        let refreshStartedAt = Date()
        clearChartFocus()
        guard !refreshInFlight else {
            refreshRequested = true
            return
        }
        refreshInFlight = true
        // A valid cache remains immediately usable while live calculations are
        // refreshed in the background. This prevents every launch or pull-to-
        // refresh from replacing the UI with a multi-second local spinner.
        isCalculating = natal == nil || currentSky == nil
        isEnriching = false
        refreshRequested = false
        errorMessage = nil
        if currentSky == nil {
            todayDashboardModel = nil
        }
        do {
            let calculator = try calculatorInstance()
            logRefreshTiming("calculator-ready", since: refreshStartedAt)
            let subjectProfile = chartSubjectProfile
            let natalInput = NatalInput(utcDate: subjectProfile.birthDateUTC, location: subjectProfile.location)
            let now = Date()
            let defaultLocation = ChartLocationSelection(
                placeName: subjectProfile.placeName,
                timezoneID: subjectProfile.timezoneID,
                latitude: subjectProfile.latitude,
                longitude: subjectProfile.longitude
            )
            let skyLocation = currentSkyLocationOverride ?? defaultLocation
            let transitLocation = transitLocationOverride ?? defaultLocation
            let returnLocation = solarReturnLocationOverride ?? defaultLocation
            let skyDate = currentSkyUsesLiveDefault ? now : currentSkyTargetDate
            let transitDate = transitUsesLiveDefault ? now : transitTargetDate
            let secondaryDate = secondaryUsesLiveDefault ? now : secondaryTargetDate
            let skyInput = NatalInput(utcDate: skyDate, location: skyLocation.geographicLocation)
            let transitInput = NatalInput(utcDate: transitDate, location: transitLocation.geographicLocation)
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: subjectProfile.birthDateUTC,
                targetDate: secondaryDate
            )
            let progressedInput = NatalInput(utcDate: progressedDate, location: subjectProfile.location)

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
            let transitMovingSnapshot = try await calculator.calculateSnapshot(
                transitInput,
                preset: preset(for: .transit)
            )
            let progressedSnapshot = try await calculator.calculateSnapshot(
                progressedInput,
                preset: preset(for: .secondary),
                aspectOrbDegrees: 3
            )
            logRefreshTiming("base-snapshots-ready", since: refreshStartedAt)

            var returnCalendar = Calendar(identifier: .gregorian)
            returnCalendar.timeZone = TimeZone(identifier: returnLocation.timezoneID) ?? .current
            let returnYearAnchor = returnCalendar.date(
                from: DateComponents(year: solarReturnYear, month: 1, day: 1)
            ) ?? now
            let solarReturnSnapshot = try await calculator.calculateSolarReturn(
                birthDate: subjectProfile.birthDateUTC,
                after: returnYearAnchor.addingTimeInterval(-1),
                location: returnLocation.geographicLocation,
                preset: preset(for: .solarReturn)
            )
            logRefreshTiming("solar-return-ready", since: refreshStartedAt)
            let solarReturnCross = SwissEphemerisCalculator.solarReturnNatalAspects(
                solarReturn: solarReturnSnapshot,
                natal: natalSnapshot
            )
            let synastryComparison: SynastryComparison?
            if let partnerID = synastryPartnerID,
               partnerID != chartSubjectID,
               let partner = profileForPersonID(partnerID)
            {
                synastryComparison = try await calculator.calculateSynastry(
                    first: natalInput,
                    second: NatalInput(utcDate: partner.birthDateUTC, location: partner.location),
                    preset: preset(for: .synastry)
                )
            } else {
                synastryComparison = nil
            }
            logRefreshTiming("synastry-ready", since: refreshStartedAt)

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

            // Today is always calculated for the actual current moment. Chart
            // exploration parameters must never rewrite the consumer homepage.
            let chartsUseOwner = chartSubjectID == "self"
            let todayNatalSnapshot = chartsUseOwner
                ? natalSnapshot
                : try await calculator.calculateSnapshot(
                    NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                    preset: preset(for: .natal)
                )
            let todayTransitReferenceSnapshot = chartsUseOwner
                ? transitReferenceSnapshot
                : try await calculator.calculateSnapshot(
                    NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                    preset: preset(for: .transit)
                )
            let todayProgressedReferenceSnapshot = chartsUseOwner
                ? progressedReferenceSnapshot
                : try await calculator.calculateSnapshot(
                    NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                    preset: preset(for: .secondary)
                )
            let todaySkySnapshot = chartsUseOwner && currentSkyUsesLiveDefault && currentSkyLocationOverride == nil
                ? skySnapshot
                : try await calculator.calculateSnapshot(
                    NatalInput(utcDate: now, location: profile.location),
                    preset: preset(for: .currentSky)
                )
            let todayTransitSnapshot = chartsUseOwner && transitUsesLiveDefault && transitLocationOverride == nil
                ? transitMovingSnapshot
                : try await calculator.calculateSnapshot(
                    NatalInput(utcDate: now, location: profile.location),
                    preset: preset(for: .transit)
                )
            let todayProgressedSnapshot: ChartSnapshot
            if chartsUseOwner && secondaryUsesLiveDefault {
                todayProgressedSnapshot = progressedSnapshot
            } else {
                let todayProgressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                    birthDate: profile.birthDateUTC,
                    targetDate: now
                )
                todayProgressedSnapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: todayProgressedDate, location: profile.location),
                    preset: preset(for: .secondary),
                    aspectOrbDegrees: 3
                )
            }
            let todayTransitAspects = SwissEphemerisCalculator.compare(
                moving: todayTransitSnapshot,
                reference: todayTransitReferenceSnapshot,
                orbDegrees: 3
            )
            let todayProgressedAspects = SwissEphemerisCalculator.compare(
                moving: todayProgressedSnapshot,
                reference: todayProgressedReferenceSnapshot,
                orbDegrees: 2
            )
            todayNatalForContent = todayNatalSnapshot
            todaySkyForContent = todaySkySnapshot
            todayTransitForContent = todayTransitSnapshot
            todayTransitAspectsForContent = todayTransitAspects
            let dashboardRules = TodayDashboardRules.load()
            let todayContext = WeeklyDayContext(
                date: now,
                natal: todayNatalSnapshot,
                frames: [
                    "natal": WeeklySignalFrame(
                        sourceID: "natal",
                        aspects: todayNatalSnapshot.aspects,
                        reference: todayNatalSnapshot
                    ),
                    "current-sky": WeeklySignalFrame(
                        sourceID: "current-sky",
                        aspects: todaySkySnapshot.aspects,
                        reference: todayNatalSnapshot
                    ),
                    "transit": WeeklySignalFrame(
                        sourceID: "transit",
                        aspects: todayTransitAspects,
                        reference: todayTransitReferenceSnapshot
                    ),
                    "secondary": WeeklySignalFrame(
                        sourceID: "secondary",
                        aspects: todayProgressedAspects,
                        reference: todayProgressedReferenceSnapshot
                    ),
                ]
            )
            todayContributions = WeeklySignalRegistry.standard(rules: dashboardRules)
                .flatMap { $0.contributions(for: todayContext) }
            let activeSignals = buildActiveSignals(
                sky: todaySkySnapshot,
                transits: todayTransitAspects,
                progressions: todayProgressedAspects,
                language: language
            )
            todaySignals = Array(activeSignals.prefix(5))
            todayDashboardModel = try TodayDashboardFactory.make(
                contributions: todayContributions,
                signals: todaySignals,
                content: ContentProvider(language: language),
                rules: dashboardRules,
                language: language,
                timeZone: TimeZone(identifier: profile.timezoneID) ?? .current
            )
            saveSnapshotCache()
            logRefreshTiming("blocking-content-ready", since: refreshStartedAt)
            // Snapshot-driven screens are ready here. Event searches and the
            // seven-day aggregation are useful enrichment, but must not hold
            // the whole app behind the launch spinner.
            isCalculating = false
            isEnriching = true
            do {
                let transitTimeZone = TimeZone(identifier: transitLocation.timezoneID) ?? .current
                let transitScopeID = TransitFactBundleBuilder.makeScopeID(
                    snapshot: transitMovingSnapshot,
                    natal: transitReferenceSnapshot,
                    crossAspects: transitAspects,
                    preset: preset(for: .transit).rawValue,
                    timeZoneIdentifier: transitTimeZone.identifier,
                    rangeDays: transitRangeDays
                )
                transitCalendar = try await buildTransitCalendar(
                    calculator: calculator,
                    natal: transitReferenceSnapshot,
                    startingAt: transitDate,
                    rangeDays: transitRangeDays,
                    scopeID: transitScopeID,
                    timeZone: transitTimeZone
                )
                logRefreshTiming("transit-calendar-ready", since: refreshStartedAt)
                weeklyForecast = try await buildWeeklyForecast(
                    calculator: calculator,
                    natal: todayNatalSnapshot,
                    transitReference: todayTransitReferenceSnapshot,
                    progressedReference: todayProgressedReferenceSnapshot,
                    startingAt: now
                )
                logRefreshTiming("weekly-forecast-ready", since: refreshStartedAt)
                chartEvents = try await ChartEventBuilder.build(
                    calculator: calculator,
                    skyAnchor: skyDate,
                    transitAnchor: transitDate,
                    secondaryTargetDate: secondaryDate,
                    birthDate: subjectProfile.birthDateUTC,
                    location: subjectProfile.location,
                    skySnapshot: skySnapshot,
                    skyPreset: preset(for: .currentSky),
                    transitNatal: transitReferenceSnapshot,
                    transitPreset: preset(for: .transit),
                    transitRangeDays: transitRangeDays,
                    timeZone: transitTimeZone,
                    transitAspects: transitAspects,
                    progressedSnapshot: progressedSnapshot,
                    progressedAspects: progressedAspects,
                    solarReturnMoment: solarReturnSnapshot.utcDate
                )
                transitContentPlan = makeTransitContentPlan(
                    snapshot: transitMovingSnapshot,
                    natal: transitReferenceSnapshot,
                    aspects: transitAspects,
                    events: chartEvents,
                    timeZone: transitTimeZone
                )
                saveSnapshotCache()
                logRefreshTiming("chart-events-ready", since: refreshStartedAt)
                let todayEvents = try await TodayEngine(
                    calculator: calculator,
                    profile: profile,
                    natal: todayTransitReferenceSnapshot,
                    skyPreset: preset(for: .currentSky),
                    transitPreset: preset(for: .transit),
                    language: language,
                    content: ContentProvider(language: language)
                ).scan(containing: now)
                logRefreshTiming("today-events-ready", since: refreshStartedAt)
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
                #if DEBUG
                print("TIMING_ENRICHMENT_ERROR: \(error)")
                #endif
            }
            isEnriching = false
            logRefreshTiming("refresh-complete", since: refreshStartedAt)
        } catch {
            errorMessage = localized(
                error.localizedDescription,
                "本地星盘计算失败，请检查出生资料后重试。",
                language: language
            )
        }
        isCalculating = false
        isEnriching = false
        refreshInFlight = false
        if refreshRequested {
            await refresh()
        }
    }

    private func logRefreshTiming(_ stage: String, since startedAt: Date) {
        #if DEBUG
        let elapsed = Date().timeIntervalSince(startedAt)
        print(String(format: "REFRESH_TIMING %.3fs %@", elapsed, stage))
        #endif
    }

    private func restoreSnapshotCache() {
        guard let cached = snapshotCache.load(),
              cached.schemaVersion == SnapshotCachePayload.currentSchemaVersion,
              cached.configurationFingerprint == snapshotCacheFingerprint(at: Date())
        else {
            return
        }
        natal = cached.natal
        transitReference = cached.transitReference
        progressedReference = cached.progressedReference
        currentSky = cached.currentSky
        transit = cached.transit
        progressed = cached.progressed
        solarReturn = cached.solarReturn
        solarReturnAspects = cached.solarReturnAspects
        synastry = cached.synastry
        transitAspects = cached.transitAspects
        progressedAspects = cached.progressedAspects
        transitCalendar = cached.transitCalendar
        chartEvents = cached.chartEvents
        transitContentPlan = makeTransitContentPlan(
            snapshot: cached.transit,
            natal: cached.transitReference,
            aspects: cached.transitAspects,
            events: cached.chartEvents,
            timeZone: TimeZone(
                identifier: transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            ) ?? .current
        )
    }

    private func saveSnapshotCache() {
        guard let natal,
              let transitReference,
              let progressedReference,
              let currentSky,
              let transit,
              let progressed,
              let solarReturn
        else {
            return
        }
        snapshotCache.save(
            SnapshotCachePayload(
                schemaVersion: SnapshotCachePayload.currentSchemaVersion,
                configurationFingerprint: snapshotCacheFingerprint(at: Date()),
                savedAt: Date(),
                natal: natal,
                transitReference: transitReference,
                progressedReference: progressedReference,
                currentSky: currentSky,
                transit: transit,
                progressed: progressed,
                solarReturn: solarReturn,
                solarReturnAspects: solarReturnAspects,
                synastry: synastry,
                transitAspects: transitAspects,
                progressedAspects: progressedAspects,
                transitCalendar: transitCalendar,
                chartEvents: chartEvents
            )
        )
    }

    private func snapshotCacheFingerprint(at date: Date) -> String {
        let subject = chartSubjectProfile
        let defaultLocation = ChartLocationSelection(
            placeName: subject.placeName,
            timezoneID: subject.timezoneID,
            latitude: subject.latitude,
            longitude: subject.longitude
        )
        let skyLocation = currentSkyLocationOverride ?? defaultLocation
        let transitLocation = transitLocationOverride ?? defaultLocation
        let returnLocation = solarReturnLocationOverride ?? defaultLocation
        let presetValues = ChartKind.allCases
            .map { "\($0.rawValue)=\(preset(for: $0).rawValue)" }
            .sorted()
            .joined(separator: ",")
        let partnerHash = synastryPartnerID
            .flatMap { id in savedPeople.first(where: { $0.id.uuidString == id }) }
            .map { profileHash($0.profile) } ?? "none"
        let raw = [
            "snapshot-cache-v\(SnapshotCachePayload.currentSchemaVersion)",
            profileHash(subject),
            presetValues,
            "partner=\(partnerHash)",
            "sky=\(currentSkyUsesLiveDefault ? bucket(date, format: "yyyy-MM-dd", timeZoneID: skyLocation.timezoneID) : minuteCacheValue(currentSkyTargetDate))",
            "sky-location=\(cacheLocationValue(skyLocation))",
            "transit=\(transitUsesLiveDefault ? bucket(date, format: "yyyy-MM-dd", timeZoneID: transitLocation.timezoneID) : minuteCacheValue(transitTargetDate))",
            "transit-location=\(cacheLocationValue(transitLocation))",
            "transit-range=\(transitRangeDays)",
            "secondary=\(secondaryUsesLiveDefault ? bucket(date, format: "yyyy-MM", timeZoneID: subject.timezoneID) : dayCacheValue(secondaryTargetDate, timeZoneID: subject.timezoneID))",
            "return=\(solarReturnYear)|\(cacheLocationValue(returnLocation))",
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func cacheLocationValue(_ location: ChartLocationSelection) -> String {
        [
            location.timezoneID,
            String(format: "%.6f", location.latitude),
            String(format: "%.6f", location.longitude),
        ].joined(separator: ",")
    }

    private func minuteCacheValue(_ date: Date) -> String {
        String(Int(floor(date.timeIntervalSince1970 / 60)))
    }

    private func dayCacheValue(_ date: Date, timeZoneID: String) -> String {
        bucket(date, format: "yyyy-MM-dd", timeZoneID: timeZoneID)
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
            let provider = try? providerResult.get()
            let catalogResult: Result<CopyCatalogProvider, Error>
            if let cached = copyCatalogProviders[language] {
                catalogResult = cached
            } else {
                catalogResult = Result { try CopyCatalogProvider(language: language) }
                copyCatalogProviders[language] = catalogResult
            }
            let cardSnapshot = snapshot(for: chart)
            let cardNatal = chart.isComparison ? referenceSnapshot(for: chart) : natal
            let cardAspects = comparisonAspects(for: chart)
            let isFocusedTransit = focusedChart == .transit && chart == .transit
            let cardEvents = focusedChart == chart ? .empty : chartEvents
            let cardTimeZoneID = chart == .transit
                ? transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
                : chartSubjectProfile.timezoneID
            let cardTimeZone = TimeZone(identifier: cardTimeZoneID) ?? .current
            let cardTransitCalendar = isFocusedTransit ? [] : transitCalendar
            let plannedTransit = chart == .transit && preset(for: chart) == .modern
                ? makeTransitContentPlan(
                    snapshot: cardSnapshot,
                    natal: cardNatal,
                    aspects: cardAspects,
                    events: cardEvents,
                    timeZone: cardTimeZone,
                    calendarDays: cardTransitCalendar
                )
                : nil
            let cards = try InsightFactory.make(
                chart: chart,
                snapshot: cardSnapshot,
                natal: cardNatal,
                aspects: cardAspects,
                content: provider,
                copyCatalog: try catalogResult.get(),
                language: language,
                transitCalendar: cardTransitCalendar,
                transitRangeDays: transitRangeDays,
                transitContentPlan: plannedTransit,
                preset: preset(for: chart).rawValue,
                events: cardEvents,
                timeZone: cardTimeZone
            )
            return .loaded(cards)
        } catch {
            #if DEBUG
            print("INSIGHT_ERROR \(chart.rawValue): \(error)")
            #endif
            #if DEBUG
            return .unavailable(String(describing: error))
            #else
            return .unavailable(
                localized(
                    "Interpretation content is incomplete for this chart.",
                    "当前星盘的解读内容尚未完整加载。",
                    language: language
                )
            )
            #endif
        }
    }

    func todayCardText(_ cardID: String) -> CardTextModel? {
        guard let sky = todaySkyForContent ?? currentSky,
              let transit = todayTransitForContent ?? self.transit,
              let natal = todayNatalForContent ?? self.natal
        else { return nil }
        let result: Result<CopyCatalogProvider, Error>
        if let cached = copyCatalogProviders[language] {
            result = cached
        } else {
            result = Result { try CopyCatalogProvider(language: language) }
            copyCatalogProviders[language] = result
        }
        guard let matcher = try? result.get() else { return nil }
       return matcher.todayText(
           cardID: cardID,
           sky: sky,
           transit: transit,
           natal: natal,
            transitAspects: todayTransitAspectsForContent.isEmpty ? transitAspects : todayTransitAspectsForContent,
            preset: todayCardPreset(cardID)
        )
    }

    private func todayCardPreset(_ cardID: String) -> String {
        switch cardID {
        case "current-chapter", "active-today", "coming-next":
            return preset(for: .transit).rawValue
        default:
            return preset(for: .currentSky).rawValue
        }
    }

    func selectChart(_ chart: ChartKind) {
        clearChartFocus()
        selectedChart = chart
    }

    func chartContext(for chart: ChartKind) -> ChartContext {
        let subject = chartSubjectProfile
        let defaultLocation = ChartLocationSelection(
            placeName: subject.placeName,
            timezoneID: subject.timezoneID,
            latitude: subject.latitude,
            longitude: subject.longitude
        )
        let target: ChartTarget = switch chart {
        case .natal:
            .natal
        case .currentSky:
            .currentSky(
                instant: currentSkyUsesLiveDefault ? Date() : currentSkyTargetDate,
                location: currentSkyLocationOverride ?? defaultLocation,
                usesLiveDefault: currentSkyUsesLiveDefault
            )
        case .transit:
            .transit(
                instant: transitUsesLiveDefault ? Date() : transitTargetDate,
                location: transitLocationOverride ?? defaultLocation,
                rangeDays: transitRangeDays,
                usesLiveDefault: transitUsesLiveDefault
            )
        case .secondary:
            .secondary(
                targetDate: secondaryUsesLiveDefault ? Date() : secondaryTargetDate,
                usesLiveDefault: secondaryUsesLiveDefault
            )
        case .solarReturn:
            .solarReturn(year: solarReturnYear, location: solarReturnLocationOverride ?? defaultLocation)
        case .synastry:
            .synastry
        }
        return ChartContext(
            chartKind: chart,
            primaryPersonID: chart == .currentSky ? "none" : profileHash(subject),
            comparisonPersonID: chart == .synastry ? subjectHashes(for: chart).dropFirst().first : nil,
            preset: preset(for: chart),
            locale: language,
            target: target
        )
    }

    func setTargetDate(_ date: Date, for chart: ChartKind) {
        clearChartFocus()
        switch chart {
        case .currentSky:
            currentSkyTargetDate = date
            currentSkyUsesLiveDefault = false
        case .transit:
            transitTargetDate = date
            transitUsesLiveDefault = false
        case .secondary:
            secondaryTargetDate = date
            secondaryUsesLiveDefault = false
        case .solarReturn:
            solarReturnYear = Calendar.current.component(.year, from: date)
        case .natal, .synastry:
            return
        }
        Task { await refresh() }
    }

    func setReferenceLocation(_ selection: LocationSelection, for chart: ChartKind) {
        let value = ChartLocationSelection(
            placeName: selection.name,
            timezoneID: selection.timezoneID,
            latitude: selection.latitude,
            longitude: selection.longitude
        )
        switch chart {
        case .currentSky: currentSkyLocationOverride = value
        case .transit: transitLocationOverride = value
        case .solarReturn: solarReturnLocationOverride = value
        case .natal, .secondary, .synastry: return
        }
        Task { await refresh() }
    }

    func setTransitRangeDays(_ days: Int) {
        transitRangeDays = [7, 30, 90].contains(days) ? days : 7
        Task { await refresh() }
    }

    func resetTarget(for chart: ChartKind) {
        switch chart {
        case .currentSky:
            currentSkyUsesLiveDefault = true
            currentSkyTargetDate = Date()
            currentSkyLocationOverride = nil
        case .transit:
            transitUsesLiveDefault = true
            transitTargetDate = Date()
            transitLocationOverride = nil
            transitRangeDays = 7
        case .secondary:
            secondaryUsesLiveDefault = true
            secondaryTargetDate = Date()
        case .solarReturn:
            solarReturnYear = Calendar.current.component(.year, from: Date())
            solarReturnLocationOverride = nil
        case .natal, .synastry:
            return
        }
        Task { await refresh() }
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
            let subject = chartSubjectProfile
            let natalSnapshot: ChartSnapshot
            if let reference = referenceSnapshot(for: chart) {
                natalSnapshot = reference
            } else {
                natalSnapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: subject.birthDateUTC, location: subject.location),
                    preset: preset(for: chart)
                )
            }

            let movingDate: Date
            if chart == .secondary {
                movingDate = SwissEphemerisCalculator.secondaryProgressedDate(
                    birthDate: subject.birthDateUTC,
                    targetDate: date
                )
            } else {
                movingDate = date
            }
            let movingLocation = chart == .transit
                ? transitLocationOverride?.geographicLocation ?? subject.location
                : subject.location
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: movingDate, location: movingLocation),
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
            errorMessage = localized(
                error.localizedDescription,
                "无法计算所选事件时刻的星盘。",
                language: language
            )
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
        startingAt date: Date,
        rangeDays: Int,
        scopeID: String,
        timeZone: TimeZone
    ) async throws -> [TransitCalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let location = transitLocationOverride?.geographicLocation ?? chartSubjectProfile.location
        var values: [TransitCalendarDay] = []
        values.reserveCapacity(rangeDays)

        for offset in 0 ..< rangeDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let localNoon = calendar.date(byAdding: .hour, value: 12, to: day)
            else { continue }
            let moving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: localNoon, location: location),
                preset: preset(for: .transit)
            )
            let aspects = SwissEphemerisCalculator.compare(
                moving: moving,
                reference: natal,
                orbDegrees: 3
            )
            let strongest = Array(aspects.prefix(8))
            let density = strongest.isEmpty
                ? 0
                : strongest.reduce(0) { $0 + $1.strength } / 8
            values.append(
                TransitCalendarDay(
                    date: day,
                    score: Int(min(1, density) * 100),
                    sourceFactIDs: strongest.map {
                        TransitFactBundleBuilder.calendarSourceFactID(
                            scopeID: scopeID,
                            date: day,
                            aspect: $0,
                            timeZone: timeZone
                        )
                    }.sorted()
                )
            )
        }
        return values
    }

    private func makeTransitContentPlan(
        snapshot: ChartSnapshot?,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        timeZone: TimeZone,
        calendarDays: [TransitCalendarDay]? = nil
    ) -> TransitContentPlan? {
        guard let snapshot else { return nil }
        let bundle = TransitFactBundleBuilder.build(
            snapshot: snapshot,
            natal: natal,
            crossAspects: aspects,
            transitWindows: events.transitWindows,
            planetEvents: events.transitPlanetEvents,
            transitCalendar: calendarDays ?? transitCalendar,
            rangeDays: transitRangeDays,
            preset: preset(for: .transit).rawValue,
            timeZone: timeZone
        )
        return TransitContentPlanner.plan(bundle)
    }
    // MARK: - AI generation (LLM interpretation + reports)

    func grantAIConsent() {
        aiConsentGranted = true
        defaults.set(true, forKey: "ai.network.consent.v1")
    }

    func revokeAIConsent() {
        aiConsentGranted = false
        defaults.set(false, forKey: "ai.network.consent.v1")
    }

    func aiCardDetail(for chart: ChartKind, cardID: String) -> (detail: String?, status: AIDetailStatus) {
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
        guard snapshot(for: chart) != nil else { return }
        guard !generatingCharts.contains(chart) else { return }

        let cardIDs = Self.expectedCardIDs(for: chart)
        let params = aiParams(for: chart)
        guard let facts = try? buildAIFacts(chart: chart, params: params, cardIDs: cardIDs),
              let factsData = try? JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
        else { return }
        let factsHash = SHA256Digest.hash(factsData).hex
        let key = semanticFingerprint(
            chart: chart,
            cardIDs: cardIDs,
            params: params,
            factsHash: factsHash
        )
        if let artifact = artifactStore.load(key: key) {
            applyArtifact(artifact, chart: chart, cardIDs: cardIDs)
            return
        }
        if let existing = aiContent[chart], existing.cacheKey == key {
            return
        }
        guard aiConsentGranted, isOnline else { return }

        generatingCharts.insert(chart)
        var content = aiContent[chart] ?? .empty
        content.cacheKey = key
        for id in cardIDs {
            content.statusByCard[id] = .generating
        }
        aiContent[chart] = content

        Task {
            await performAIGeneration(
                chart: chart,
                key: key,
                cardIDs: cardIDs,
                params: params,
                facts: facts,
                factsHash: factsHash
            )
        }
    }

    func regenerateAIArtifact(for chart: ChartKind) {
        let cardIDs = Self.expectedCardIDs(for: chart)
        let params = aiParams(for: chart)
        guard let facts = try? buildAIFacts(chart: chart, params: params, cardIDs: cardIDs),
              let factsData = try? JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
        else { return }
        let factsHash = SHA256Digest.hash(factsData).hex
        let key = semanticFingerprint(chart: chart, cardIDs: cardIDs, params: params, factsHash: factsHash)
        artifactStore.remove(key: key)
        aiContent[chart] = .empty
        ensureAIGeneration(for: chart)
    }

    private func performAIGeneration(
        chart: ChartKind,
        key: String,
        cardIDs: [String],
        params: [String: String],
        facts: [String: Any],
        factsHash: String
    ) async {
        defer { generatingCharts.remove(chart) }
        do {
            let evidenceFacts = facts["evidenceFacts"] as? [[String: Any]] ?? []
            let evidenceIDs = evidenceFacts.compactMap { $0["id"] as? String }
            let allowedEvidence = allowedEvidenceByCard(
                chart: chart,
                cardIDs: cardIDs,
                evidenceIDs: evidenceIDs
            )
            let body: [String: Any] = [
                "mode": "chart",
                "chartKind": chart.contentPrefix,
                "periodType": NSNull(),
                "preset": preset(for: chart).rawValue,
                "profileHash": subjectHashes(for: chart).first ?? "none",
                "params": params,
                "facts": facts,
                "semanticFingerprint": key,
                "factsHash": factsHash,
                "generationSchemaVersion": GeneratedChartArtifact.schemaVersion,
                "cardIDs": cardIDs,
                "allowedEvidenceByCard": allowedEvidence,
                "locale": language.corpusLanguage.rawValue,
                "clientVersion": "ios-v6",
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            let request = AIGenerateRequest(bodyData: bodyData)
            let response = try await aiClient.generate(request)
            guard response.semanticFingerprint == key else {
                throw AIGenerationError.contract("semantic fingerprint mismatch")
            }
            guard response.factsHash == factsHash else {
                throw AIGenerationError.contract("facts hash mismatch")
            }
            guard response.generationSchemaVersion == GeneratedChartArtifact.schemaVersion else {
                throw AIGenerationError.contract("generation schema mismatch")
            }
            let generatedAt = response.generatedAt
                .flatMap { ISO8601DateFormatter().date(from: $0) }
                ?? Date()
            let artifact = GeneratedChartArtifact(
                semanticFingerprint: key,
                chartKind: chart.contentPrefix,
                subjectHashes: subjectHashes(for: chart),
                parameters: params,
                locale: language.corpusLanguage.rawValue,
                preset: preset(for: chart).rawValue,
                cardContractVersion: 3,
                factsHash: factsHash,
                provider: response.provider,
                model: response.model,
                promptVersion: response.promptVersion,
                generationSchemaVersion: response.generationSchemaVersion ?? GeneratedChartArtifact.schemaVersion,
                generatedAt: generatedAt,
                response: response
            )
            artifactStore.save(artifact)
            applyArtifact(artifact, chart: chart, cardIDs: cardIDs)
        } catch {
            var content = aiContent[chart] ?? .empty
            for id in cardIDs {
                content.statusByCard[id] = .failed(error.localizedDescription)
            }
            aiContent[chart] = content
        }
    }

    private func allowedEvidenceByCard(
        chart: ChartKind,
        cardIDs: [String],
        evidenceIDs: [String]
    ) -> [String: [String]] {
        let available = Set(evidenceIDs)
        if chart == .transit, let plan = transitContentPlan {
            return Dictionary(uniqueKeysWithValues: cardIDs.map { cardID in
                let sourceFactIDs = plan.card(cardID)?.sourceFactIDs.filter(available.contains) ?? []
                return (cardID, sourceFactIDs)
            })
        }
        let pointIDs = evidenceIDs.filter { $0.hasPrefix("point.") }
        let aspectIDs = evidenceIDs.filter { $0.hasPrefix("aspect.") }
        let angleIDs = evidenceIDs.filter { $0.hasPrefix("angle.") }
        let eventIDs = evidenceIDs.filter { $0.hasPrefix("event.") }
        let cards = insightCards(for: chart).cards

        return Dictionary(uniqueKeysWithValues: cardIDs.map { cardID in
            let explicit = cards
                .first(where: { $0.id == cardID })?
                .facts
                .flatMap(\.sourceFactIDs)
                .filter { available.contains($0) } ?? []
            if !explicit.isEmpty {
                return (cardID, Array(Set(explicit)).sorted())
            }

            let lower = cardID.lowercased()
            var policy: [String] = []
            if lower.contains("moon") || lower.contains("emotional") {
                policy += pointIDs.filter { $0 == "point.moon" }
                policy += aspectIDs.filter { $0.contains(".moon.") || $0.hasSuffix(".moon") }
            }
            if lower.contains("aspect") || lower.contains("cycle") || lower.contains("turning") || lower.contains("dynamic") {
                policy += aspectIDs
            }
            if lower.contains("placement") || lower.contains("motion") || lower.contains("element") || lower.contains("area") || lower.contains("path") {
                policy += pointIDs
            }
            if lower.contains("anchor") || lower.contains("signature") || lower.contains("overview") || lower.contains("interpretation") || lower.contains("perspective") {
                policy += pointIDs + angleIDs
            }
            if lower.contains("timeline") || lower.contains("story") || lower.contains("connection") || lower.contains("chemistry") || lower.contains("commitment") || lower.contains("overlay") || lower.contains("upcoming") || lower.contains("change") {
                policy += pointIDs + aspectIDs + eventIDs
            }
            if policy.isEmpty {
                policy = pointIDs + aspectIDs + angleIDs
            }
            return (cardID, Array(Set(policy)).sorted())
        })
    }

    private func applyArtifact(_ artifact: GeneratedChartArtifact, chart: ChartKind, cardIDs: [String]) {
        let response = artifact.response
        var content = aiContent[chart] ?? .empty
        content.cacheKey = artifact.semanticFingerprint
        content.report = AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
        for id in cardIDs {
            if let detail = response.cards[id]?.detail, !detail.isEmpty {
                content.cardDetails[id] = detail
                content.statusByCard[id] = .ready
            } else {
                content.statusByCard[id] = .hidden
            }
        }
        aiContent[chart] = content
        reloadSavedReports()
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
                let name = synastryPartnerID.flatMap(profileForPersonID)?.name ?? "Partner"
                partner = (name, partnerSnapshot)
            } else {
                partner = nil
            }
        } else {
            partner = nil
        }
        var document = AIFactsBuilder.document(
            chart: chart,
            snapshot: snapshot,
            reference: reference,
            comparisonAspects: comparison,
            preset: preset(for: chart),
            personName: chartSubjectProfile.name,
            partnerName: partner?.name,
            partnerChart: partner?.chart,
            events: chartEvents,
            params: params,
            locale: language.corpusLanguage.rawValue,
            cardIDs: cardIDs
        )
        if chart == .transit {
            let timeZone = TimeZone(
                identifier: transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            ) ?? .current
            let isFocusedTransit = focusedChart == .transit
            let plan = makeTransitContentPlan(
                snapshot: snapshot,
                natal: reference,
                aspects: comparison,
                events: isFocusedTransit ? .empty : chartEvents,
                timeZone: timeZone,
                calendarDays: isFocusedTransit ? [] : transitCalendar
            )
            transitContentPlan = plan
            if let plan {
                document["transitContentPlan"] = transitPlanDocument(plan)
                document["evidenceFacts"] = transitEvidenceFacts(plan)
            }
        }
        return document
    }

    private func transitPlanDocument(_ plan: TransitContentPlan) -> [String: Any] {
        [
            "scopeID": plan.scopeID,
            "anchorDate": ISO8601DateFormatter().string(from: plan.anchorDate),
            "timeZone": plan.timeZoneIdentifier,
            "rangeDays": plan.rangeDays,
            "preset": plan.preset,
            "cards": plan.cards.map { card in
                [
                    "cardID": card.cardID,
                    "copySlot": card.copySlot.map { $0.rawValue as Any } ?? NSNull(),
                    "primaryFactID": card.primaryFactID.map { $0 as Any } ?? NSNull(),
                    "integratedThemeID": card.integratedThemeID.map { $0.rawValue as Any } ?? NSNull(),
                    "sourceFactIDs": card.sourceFactIDs,
                    "evidence": card.evidence.map {
                        [
                            "factID": $0.fact.factID,
                            "claimMode": $0.claimMode.rawValue,
                            "roleID": $0.role.rawValue,
                        ]
                    },
                    "signals": card.signalRoles.map {
                        [
                            "signalID": $0.signalID,
                            "signalRole": $0.signalRole.rawValue,
                            "transitPlanet": $0.movingID,
                            "lifeAreas": $0.lifeAreas,
                            "sourceFactIDs": $0.sourceFactIDs,
                        ]
                    },
                ]
            },
        ]
    }

    private func transitEvidenceFacts(_ plan: TransitContentPlan) -> [[String: Any]] {
        var factsByID: [String: [String: Any]] = [:]
        for evidence in plan.cards.flatMap(\.evidence) {
            let fact = evidence.fact
            factsByID[fact.factID] = transitEvidenceDocument(fact)
            for sourceFactID in fact.sourceFactIDs where factsByID[sourceFactID] == nil {
                factsByID[sourceFactID] = [
                    "id": sourceFactID,
                    "kind": "source-reference",
                ]
            }
        }
        return factsByID.values.sorted {
            ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
        }
    }

    private func transitEvidenceDocument(_ fact: TransitFact) -> [String: Any] {
        switch fact {
        case let .aspect(value):
            return [
                "id": value.factID,
                "kind": "transit-aspect",
                "movingID": value.movingID,
                "referenceID": value.referenceID,
                "aspect": value.kind.rawValue,
                "orbDegrees": value.orbDegrees,
                "phase": value.phase.rawValue,
                "strength": value.strength,
                "movingLongitude": value.movingLongitude,
                "referenceLongitude": value.referenceLongitude,
                "natalHouse": value.natalHouse,
            ]
        case let .window(value):
            return [
                "id": value.factID,
                "kind": "transit-window",
                "sourceAspectFactID": value.sourceAspectFactID.map { $0 as Any } ?? NSNull(),
                "start": ISO8601DateFormatter().string(from: value.start),
                "exact": ISO8601DateFormatter().string(from: value.exact),
                "end": ISO8601DateFormatter().string(from: value.end),
                "repeatExact": value.repeatExact.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
                "nextExact": value.nextExact.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
                "passIndex": value.passIndex,
                "passCount": value.passCount,
                "returning": value.returning,
                "timeZone": value.timeZoneIdentifier,
            ]
        case let .planetEvent(value):
            return [
                "id": value.factID,
                "kind": "transit-planet-event",
                "body": value.body.rawValue,
                "eventKind": value.kind.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: value.timestamp),
                "timeZone": value.timeZoneIdentifier,
                "fromIndex": value.fromIndex.map { $0 as Any } ?? NSNull(),
                "toIndex": value.toIndex.map { $0 as Any } ?? NSNull(),
            ]
        case let .placement(value):
            return [
                "id": value.factID,
                "kind": "transit-placement",
                "body": value.body.rawValue,
                "longitudeDegrees": value.longitudeDegrees,
                "signIndex": value.signIndex,
                "degreeInSign": value.degreeInSign,
                "natalHouse": value.natalHouse,
                "retrograde": value.retrograde,
                "longitudeSpeedDegreesPerDay": value.longitudeSpeedDegreesPerDay,
            ]
        case let .lifeArea(value):
            return [
                "id": value.factID,
                "kind": "transit-life-area",
                "house": value.house,
                "normalizedScore": value.normalizedScore,
                "sourceFactIDs": value.contributingFactIDs,
            ]
        case let .calendar(value):
            return [
                "id": value.factID,
                "kind": "transit-calendar-day",
                "date": ISO8601DateFormatter().string(from: value.date),
                "score": value.score,
                "sourceFactIDs": value.sourceFactIDs,
                "timeZone": value.timeZoneIdentifier,
            ]
        }
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
        let context = chartContext(for: chart)
        let formatter = ISO8601DateFormatter()
        switch context.target {
        case .natal:
            return [:]
        case let .currentSky(instant, location, usesLiveDefault):
            return locationParameters(location).merging([
                usesLiveDefault ? "localDay" : "instant": usesLiveDefault
                    ? bucket(instant, format: "yyyy-MM-dd", timeZoneID: location.timezoneID)
                    : minuteString(instant, formatter: formatter),
                "selectionMode": usesLiveDefault ? "live-day" : "exact",
            ]) { _, new in new }
        case let .transit(instant, location, rangeDays, usesLiveDefault):
            return locationParameters(location).merging([
                usesLiveDefault ? "localDay" : "instant": usesLiveDefault
                    ? bucket(instant, format: "yyyy-MM-dd", timeZoneID: location.timezoneID)
                    : minuteString(instant, formatter: formatter),
                "rangeDays": String(rangeDays),
                "selectionMode": usesLiveDefault ? "live-day" : "exact",
            ]) { _, new in new }
        case let .secondary(targetDate, usesLiveDefault):
            return [
                usesLiveDefault ? "targetMonth" : "targetDate": bucket(
                    targetDate,
                    format: usesLiveDefault ? "yyyy-MM" : "yyyy-MM-dd",
                    timeZoneID: chartSubjectProfile.timezoneID
                ),
                "selectionMode": usesLiveDefault ? "live-month" : "exact-date",
            ]
        case let .solarReturn(year, location):
            return locationParameters(location).merging(["returnYear": String(year)]) { _, new in new }
        case .synastry:
            return ["partnerHash": subjectHashes(for: chart).dropFirst().first ?? ""]
        }
    }

    private func semanticFingerprint(chart: ChartKind, cardIDs: [String], params: [String: String], factsHash: String) -> String {
        let includeExactFacts: Bool = switch chartContext(for: chart).target {
        case .natal, .solarReturn, .synastry: true
        case let .currentSky(_, _, usesLiveDefault): !usesLiveDefault
        case let .transit(_, _, _, usesLiveDefault): !usesLiveDefault
        case let .secondary(_, usesLiveDefault): !usesLiveDefault
        }
        let raw = [
            chart.contentPrefix,
            preset(for: chart).rawValue,
            subjectHashes(for: chart).joined(separator: ","),
            params.keys.sorted().map { "\($0)=\(params[$0] ?? "")" }.joined(separator: ","),
            language.corpusLanguage.rawValue,
            cardIDs.joined(separator: ","),
            "contract=3",
            "generation=\(GeneratedChartArtifact.schemaVersion)",
            includeExactFacts ? factsHash : "semantic-bucket",
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func subjectHashes(for chart: ChartKind) -> [String] {
        guard chart != .currentSky else { return [] }
        var hashes = [profileHash(chartSubjectProfile)]
        if chart == .synastry,
           let partnerID = synastryPartnerID,
           let partner = profileForPersonID(partnerID)
        {
            hashes.append(profileHash(partner))
        }
        return hashes
    }

    private func profileHash(_ value: UserProfile) -> String {
        let raw = [
            value.name, value.placeName, value.timezoneID,
            String(value.birthDateUTC.timeIntervalSince1970),
            String(value.latitude), String(value.longitude),
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func locationParameters(_ location: ChartLocationSelection) -> [String: String] {
        [
            "place": location.placeName,
            "timezone": location.timezoneID,
            "latitude": String(format: "%.6f", location.latitude),
            "longitude": String(format: "%.6f", location.longitude),
        ]
    }

    private func bucket(_ date: Date, format: String, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func minuteString(_ date: Date, formatter: ISO8601DateFormatter) -> String {
        let seconds = floor(date.timeIntervalSince1970 / 60) * 60
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }

    private static func expectedCardIDs(for chart: ChartKind) -> [String] {
        switch chart {
        case .natal: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"]
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
        reloadSavedReports()
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
                    locale: language.corpusLanguage.rawValue,
                    events: todaySignalEvents(),
                    params: params
                )
            case .monthly:
                facts = AIFactsBuilder.periodDocument(
                    periodType: "monthly",
                    personName: profile.name,
                    locale: language.corpusLanguage.rawValue,
                    events: transitEventSummaries(),
                    params: params
                )
            case .solarReturn:
                facts = AIFactsBuilder.periodDocument(
                    periodType: "solar-return",
                    personName: profile.name,
                    locale: language.corpusLanguage.rawValue,
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
                "locale": language.corpusLanguage.rawValue,
                "clientVersion": "ios-v2",
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            let response = try await aiClient.generate(AIGenerateRequest(bodyData: bodyData))
            let key = aiPeriodCacheKey(scope: scope, params: params)
            let periodScope = "period.\(scope.rawValue)"
            let saved = SavedReport(
                id: key,
                scope: periodScope,
                title: response.report.title,
                subtitle: response.report.subtitle,
                generatedAt: Date(),
                report: AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
            )
            artifactStore.savePeriodReport(saved)
            reloadSavedReports()
        } catch {
            // Silent failure: the library keeps its current state; retry on next tap.
        }
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
            language.corpusLanguage.rawValue,
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

private struct SnapshotCachePayload: Codable {
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    let configurationFingerprint: String
    let savedAt: Date
    let natal: ChartSnapshot
    let transitReference: ChartSnapshot
    let progressedReference: ChartSnapshot
    let currentSky: ChartSnapshot
    let transit: ChartSnapshot
    let progressed: ChartSnapshot
    let solarReturn: ChartSnapshot
    let solarReturnAspects: [ChartAspect]
    let synastry: SynastryComparison?
    let transitAspects: [ChartAspect]
    let progressedAspects: [ChartAspect]
    let transitCalendar: [TransitCalendarDay]
    let chartEvents: ChartEventData
}

private final class SnapshotCacheStore: @unchecked Sendable {
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.url = base.appendingPathComponent("CalculatedSnapshots-v1.json")
    }

    func load() -> SnapshotCachePayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SnapshotCachePayload.self, from: data)
    }

    func save(_ payload: SnapshotCachePayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
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
