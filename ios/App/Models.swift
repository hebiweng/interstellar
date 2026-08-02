import AstroCore
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case french = "fr"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .spanish: "Español"
        case .french: "Français"
        }
    }

    /// The reviewed runtime corpus is now delivered for all four consumer locales.
    var corpusLanguage: AppLanguage { self }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .system: localized("System", "跟随系统", language: language)
        case .light: localized("Light", "浅色", language: language)
        case .dark: localized("Dark", "深色", language: language)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppFontSize: String, CaseIterable, Identifiable, Codable {
    case small
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .small: localized("Small", "小", language: language)
        case .standard: localized("Standard", "标准", language: language)
        case .large: localized("Large", "大", language: language)
        case .extraLarge: localized("Extra Large", "特大", language: language)
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .medium
        case .standard: .large
        case .large: .xLarge
        case .extraLarge: .xxLarge
        }
    }
}

func localized(_ english: String, _ chinese: String, language: AppLanguage) -> String {
    let fallback = language == .simplifiedChinese ? chinese : english
    guard let localizationPath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let localizationBundle = Bundle(path: localizationPath)
    else { return fallback }
    return localizationBundle.localizedString(forKey: english, value: fallback, table: "Localizable")
}

func localized(
    _ key: String,
    default english: String,
    chinese: String,
    language: AppLanguage
) -> String {
    let fallback = language == .simplifiedChinese ? chinese : english
    guard let localizationPath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let localizationBundle = Bundle(path: localizationPath)
    else { return fallback }
    return localizationBundle.localizedString(forKey: key, value: fallback, table: "Localizable")
}

func localized(
    _ english: String,
    _ chinese: String,
    spanish: String,
    french: String,
    language: AppLanguage
) -> String {
    let fallback = switch language {
    case .english: english
    case .simplifiedChinese: chinese
    case .spanish: spanish
    case .french: french
    }
    guard let localizationPath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let localizationBundle = Bundle(path: localizationPath)
    else { return fallback }
    return localizationBundle.localizedString(forKey: english, value: fallback, table: "Localizable")
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ChartKind: String, CaseIterable, Identifiable, Codable {
    case natal
    case transit
    case secondary
    case solarReturn
    case synastry
    case currentSky

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("Natal", "本命", language: language)
        case .currentSky: localized("chart-kind.current-sky.short", default: "Current Sky", chinese: "天象", language: language)
        case .transit: localized("Transits", "行运", language: language)
        case .secondary: localized("Progressed", "次限", language: language)
        case .solarReturn: localized("Solar Return", "日返盘", language: language)
        case .synastry: localized("Synastry", "合盘", language: language)
        }
    }

    func eyebrow(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("BIRTH CHART", "本命盘", language: language)
        case .currentSky: localized("chart-kind.current-sky.eyebrow", default: "SKY NOW", chinese: "当前天象", language: language)
        case .transit: localized("NATAL + CURRENT SKY", "本命与当前天空", language: language)
        case .secondary: localized("SECONDARY PROGRESSIONS", "次限推运", language: language)
        case .solarReturn: localized("SOLAR RETURN", "日返盘", language: language)
        case .synastry: localized("SYNASTRY", "合盘", language: language)
        }
    }

    var isComparison: Bool { self == .transit || self == .secondary || self == .synastry }

    var contentPrefix: String {
        switch self {
        case .natal: "natal"
        case .currentSky: "current-sky"
        case .transit: "transit"
        case .secondary: "secondary"
        case .solarReturn: "solar-return"
        case .synastry: "synastry"
        }
    }
}

enum ChartViewMode: String, CaseIterable, Identifiable {
    case wheel = "Wheel"
    case aspects = "Aspects"
    var id: String { rawValue }
}

extension CalculationPreset {
    static let consumerCases: [CalculationPreset] = [.modern, .classical]

    func title(language: AppLanguage) -> String {
        switch self {
        case .modern: localized("Modern", "现代", language: language)
        case .classical: localized("Classical", "古典", language: language)
        case .special: localized("Special", "特殊", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .modern: localized("Tropical · Placidus", "回归黄道 · 普拉西德", language: language)
        case .classical: localized("Traditional · Alcabitius", "传统七曜 · 阿卡比特", language: language)
        case .special: localized("Whole Sign", "整宫制", language: language)
        }
    }
}

struct UserProfile: Codable, Equatable {
    var name: String
    var birthDateUTC: Date
    var placeName: String
    var timezoneID: String
    var latitude: Double
    var longitude: Double
    var avatarData: Data? = nil

    static let sample = UserProfile(
        name: "Darryl Smith",
        birthDateUTC: Date(timeIntervalSince1970: 824_259_600),
        placeName: "Yuncheng, China",
        timezoneID: "Asia/Shanghai",
        latitude: 35.0263,
        longitude: 111.0073
    )

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var location: GeographicLocation {
        GeographicLocation(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}

enum PersonRelationship: String, CaseIterable, Codable, Identifiable {
    case partner
    case family
    case friend
    case colleague
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .partner: localized("Partner", "伴侣", language: language)
        case .family: localized("Family", "家人", language: language)
        case .friend: localized("Friend", "朋友", language: language)
        case .colleague: localized("Colleague", "同事", language: language)
        case .other: localized("Other", "其他", language: language)
        }
    }
}

/// A single, auditable calculation context.  Screens, insight builders and AI
/// generation must all consume this value so a parameter change cannot update
/// one layer while leaving another layer stale.
struct ChartContext: Codable, Equatable, Sendable {
    let chartKind: ChartKind
    let primaryPersonID: String
    let comparisonPersonID: String?
    let preset: CalculationPreset
    let locale: AppLanguage
    let target: ChartTarget
}

struct ChartLocationSelection: Codable, Equatable, Sendable {
    let placeName: String
    let timezoneID: String
    let latitude: Double
    let longitude: Double

    var geographicLocation: GeographicLocation {
        GeographicLocation(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}

enum ChartTarget: Codable, Equatable, Sendable {
    case natal
    case currentSky(instant: Date, location: ChartLocationSelection, usesLiveDefault: Bool)
    case transit(instant: Date, location: ChartLocationSelection, rangeDays: Int, usesLiveDefault: Bool)
    case secondary(targetDate: Date, usesLiveDefault: Bool)
    case solarReturn(year: Int, location: ChartLocationSelection)
    case synastry
}

struct SavedPerson: Identifiable, Codable, Equatable {
    var id: UUID
    var profile: UserProfile
    var relationship: PersonRelationship

    static func new(using owner: UserProfile) -> SavedPerson {
        SavedPerson(
            id: UUID(),
            profile: UserProfile(
                name: "",
                birthDateUTC: owner.birthDateUTC,
                placeName: owner.placeName,
                timezoneID: owner.timezoneID,
                latitude: owner.latitude,
                longitude: owner.longitude
            ),
            relationship: .friend
        )
    }
}

struct InsightFact: Identifiable, Equatable {
    /// Stable within a card and across launches. It is also the evidence ID sent
    /// to the relay; UUIDs here would make otherwise identical reports miss the
    /// local cache.
    let id: String
    let metricLabel: String
    let calculatedValue: String
    let interpretationKey: String?
    let interpretationVariables: [String: String]
    let sourceFactIDs: [String]
    let visualRole: String?
    let interpretation: String?
    var emphasis: InsightTone = .neutral
    var progress: Double? = nil
    var symbol: String? = nil
    var category: String? = nil
    var markers: [Double]? = nil

    init(
        id: String,
        metricLabel: String,
        calculatedValue: String,
        interpretationKey: String? = nil,
        interpretationVariables: [String: String] = [:],
        sourceFactIDs: [String] = [],
        visualRole: String? = nil,
        interpretation: String? = nil,
        emphasis: InsightTone = .neutral,
        progress: Double? = nil,
        symbol: String? = nil,
        category: String? = nil,
        markers: [Double]? = nil
    ) {
        self.id = id
        self.metricLabel = metricLabel
        self.calculatedValue = calculatedValue
        self.interpretationKey = interpretationKey
        self.interpretationVariables = interpretationVariables
        self.sourceFactIDs = sourceFactIDs.isEmpty ? [id] : sourceFactIDs
        self.visualRole = visualRole
        self.interpretation = interpretation
        self.emphasis = emphasis
        self.progress = progress
        self.symbol = symbol
        self.category = category
        self.markers = markers
    }

    // Compatibility names used by the existing visual components while the
    // product-facing model remains explicit.
    var label: String { metricLabel }
    var value: String { calculatedValue }
    var note: String? { interpretation }
}

enum InsightTone: String, Equatable {
    case supportive
    case challenging
    case transition
    case neutral
}

enum InsightVisual: Equatable {
    case natalCore
    case rankedThemes
    case strengthOrbit(supportive: Int, challenging: Int, neutral: Int)
    case blindSpot
    case growthPath
    case skyOverview(phase: Double, activity: Int, cycles: [Double])
    case themeCards
    case needsCard
    case eventTimeline
    case dateEvents
    case structureMap(supportive: Int, challenging: Int, neutral: Int)
    case domainBars([Double])
    case observation
    case evolution
    case planetTable
    case activityGauge(value: Int, supportive: Int, adjustment: Int)
    case transitOverview(intensity: Int, rhythm: [Double])
    case gantt
    case transitTimeline([ChartEventData.TransitWindow])
    case balanceRing(supportive: Int, challenging: Int, neutral: Int)
    case houseRadar([Double])
    case actionGuidance
    case arcTimeline
    case doubleRing
    case calendar([Int])
    case progressedStage(phase: Double, moonProgress: Double, sunProgress: Double)
    case progressedThemes(supportive: Int, challenging: Int, neutral: Int)
    case turningTimeline
    case comparison
    // V2 prototype visuals (six-chart redesign)
    case signatureTrio(ruler: String, dominant: String, orientation: String)
    case placementList
    case aspectList
    case storyWeave(expanding: String, structuring: String, result: String)
    case cycleTabs(long: String, longMeta: String, current: String, currentMeta: String, daily: String, dailyMeta: String)
    case positionRows
    case areaRows
    case phaseDial(phase: Double, illumination: Double)
    case motionList
    case elementRows
    case stageFlow(old: String, transition: String, emerging: String)
    case moonProgress(progress: Double)
    case identityCompare(natal: String, progressed: String)
    case turningRows
    case yearOrbit
    case anchorGrid
    case dualInsight(opening: String, demand: String, openingLabel: String, demandLabel: String)
    case edgeDual(opening: String, demand: String)
    case quarterTabs
    case overlayCompare
    case natalOverlay(firstLabel: String, firstValue: String, secondLabel: String, secondValue: String)
    case bondOrbit
    case perspectiveTabs
    case connectionGrid
    case pathFlow
    case houseOverlayRows
}

struct InsightCardModel: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let visual: InsightVisual
    let facts: [InsightFact]
    /// Optional card-level conclusion from the private content pack.
    let conclusionKey: String?
    let conclusion: String
    let text: CardTextModel?

    init(
        id: String,
        title: String,
        icon: String,
        visual: InsightVisual,
        facts: [InsightFact],
        conclusionKey: String? = nil,
        conclusion: String,
        text: CardTextModel? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.visual = visual
        self.facts = facts
        self.conclusionKey = conclusionKey
        self.conclusion = conclusion
        self.text = text
    }

    // Compatibility for views still referring to the former summary field.
    var summary: String { conclusion }
}

/// Reviewed consumer copy selected from a normalized Copy Catalog. Technical
/// labels remain separate so a fact template can never become interpretation.
struct CardTextModel: Codable, Equatable, Sendable {
    let sectionLabel: String?
    let cardLabel: String
    let headline: String?
    let body: String?
    let secondaryBody: String?
    let areaLabel: String?
    let statusLabel: String?
    let technicalLabel: String?
    let startLabel: String?
    let endLabel: String?
    let themeID: String?
    let sourceSignalIDs: [String]
    let copyPackID: String?
}

struct InsightCardLoadState {
    let cards: [InsightCardModel]
    let errorMessage: String?

    static func loaded(_ cards: [InsightCardModel]) -> Self {
        Self(cards: cards, errorMessage: nil)
    }

    static func unavailable(_ message: String) -> Self {
        Self(cards: [], errorMessage: message)
    }
}

struct HoraryOverlay: Equatable {
    let highlightedHouses: Set<Int>
    let planetLabels: [CelestialBody: String]
    let keyAspectIDs: Set<String>

    static let empty = HoraryOverlay(
        highlightedHouses: [],
        planetLabels: [:],
        keyAspectIDs: []
    )
}

struct HorarySession: Equatable {
    let mode: HoraryQuestionMode
    let question: String
    let createdAt: Date
    let locationName: String
    let timezoneID: String
    let snapshot: ChartSnapshot
    let analysis: HoraryAnalysis?
    let choices: [HoraryChoiceResult]
    let timingCandidates: [ElectionTimingCandidate]
    let significators: [HorarySignificatorAssessment]

    init(
        mode: HoraryQuestionMode,
        question: String,
        createdAt: Date,
        locationName: String,
        timezoneID: String,
        snapshot: ChartSnapshot,
        analysis: HoraryAnalysis?,
        choices: [HoraryChoiceResult],
        timingCandidates: [ElectionTimingCandidate],
        significators: [HorarySignificatorAssessment] = []
    ) {
        self.mode = mode
        self.question = question
        self.createdAt = createdAt
        self.locationName = locationName
        self.timezoneID = timezoneID
        self.snapshot = snapshot
        self.analysis = analysis
        self.choices = choices
        self.timingCandidates = timingCandidates
        self.significators = significators
    }
}

struct DailySignal: Identifiable, Equatable {
    enum Category: String {
        case happeningToday
        case activeNow
    }

    enum Source: String {
        case sky = "Current Sky"
        case transit = "Transit"
        case secondary = "Progressed"
    }

    let id: String
    let category: Category
    let source: Source
    let title: String
    let subtitle: String
    let tone: InsightTone
    let strength: Int
    let eventDate: Date?
}

enum Zodiac {
    static let englishNames = [
        "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
    ]

    static let chineseNames = [
        "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座",
        "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座",
    ]

    static let names = englishNames
    static let termKeys = [
        "aries", "taurus", "gemini", "cancer", "leo", "virgo",
        "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
    ]
    static let symbols = ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"]

    static func name(index: Int, language: AppLanguage) -> String {
        AstroTerms.value("zodiac", termKeys[index], language: language)
    }

    static func position(_ point: ChartPoint, language: AppLanguage = .english) -> String {
        "\(name(index: point.signIndex, language: language)) \(formatDegree(point.degreeInSign))\(point.retrograde ? " ℞" : "")"
    }

    static func formatDegree(_ value: Double) -> String {
        let degrees = Int(value)
        let minutes = Int((value - Double(degrees)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))′"
    }
}

func bodyName(_ body: CelestialBody, language: AppLanguage) -> String {
    AstroTerms.value("bodies", body.rawValue, language: language)
}

func aspectKindName(_ kind: AspectKind, language: AppLanguage) -> String {
    AstroTerms.value("aspects", kind.rawValue, language: language)
}
