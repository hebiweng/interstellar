import AstroCore
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
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
    language == .english ? english : chinese
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ChartKind: String, CaseIterable, Identifiable, Codable {
    case natal
    case currentSky
    case transit
    case secondary

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("Natal", "本命", language: language)
        case .currentSky: localized("Current Sky", "天象", language: language)
        case .transit: localized("Transits", "行运", language: language)
        case .secondary: localized("Progressed", "次限", language: language)
        }
    }

    func eyebrow(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("BIRTH CHART", "本命盘", language: language)
        case .currentSky: localized("SKY NOW", "当前天象", language: language)
        case .transit: localized("NATAL + CURRENT SKY", "本命与当前天空", language: language)
        case .secondary: localized("SECONDARY PROGRESSIONS", "次限推运", language: language)
        }
    }

    var isComparison: Bool { self == .transit || self == .secondary }

    var contentPrefix: String {
        switch self {
        case .natal: "natal"
        case .currentSky: "current-sky"
        case .transit: "transit"
        case .secondary: "secondary"
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
    let id = UUID()
    let label: String
    let value: String
    var emphasis: InsightTone = .neutral
    var note: String? = nil
    var progress: Double? = nil
    var symbol: String? = nil
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
    case eventTimeline
    case structureMap(supportive: Int, challenging: Int, neutral: Int)
    case domainBars([Double])
    case observation
    case evolution
    case planetTable
    case activityGauge(value: Int, supportive: Int, adjustment: Int)
    case transitOverview(intensity: Int, rhythm: [Double])
    case gantt
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
}

struct InsightCardModel: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let visual: InsightVisual
    let facts: [InsightFact]
    let summary: String
    let detail: String
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
    static let symbols = ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"]

    static func name(index: Int, language: AppLanguage) -> String {
        language == .english ? englishNames[index] : chineseNames[index]
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
    guard language == .simplifiedChinese else { return body.displayName }
    return switch body {
    case .sun: "太阳"
    case .moon: "月亮"
    case .mercury: "水星"
    case .venus: "金星"
    case .mars: "火星"
    case .jupiter: "木星"
    case .saturn: "土星"
    case .uranus: "天王星"
    case .neptune: "海王星"
    case .pluto: "冥王星"
    case .trueNode: "北交点"
    }
}

func aspectKindName(_ kind: AspectKind, language: AppLanguage) -> String {
    guard language == .simplifiedChinese else {
        return kind.rawValue.prefix(1).uppercased() + kind.rawValue.dropFirst()
    }
    return switch kind {
    case .conjunction: "合相"
    case .sextile: "六合"
    case .square: "刑相"
    case .trine: "拱相"
    case .opposition: "冲相"
    }
}
