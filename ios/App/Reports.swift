import AstroCore
import Foundation

enum ReportScope: String, Codable, CaseIterable, Identifiable {
    case daily
    case monthly
    case solarReturn

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .daily: localized("Daily Report", "日报告", language: language)
        case .monthly: localized("Monthly Report", "月报告", language: language)
        case .solarReturn: localized("Solar Return Report", "日返盘报告", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .daily: localized("Today's changes, once the day is complete.", "当天变化，等一天结束后可生成。", language: language)
        case .monthly: localized("The month's transits, once the month closes.", "本月行运变化，等月份结束后可生成。", language: language)
        case .solarReturn: localized("The year that opens at the next solar return.", "下一个日返时刻开启的年度解读。", language: language)
        }
    }
}

struct AvailableReport: Identifiable {
    let scope: ReportScope
    let unlockedAt: Date?
    var id: String { scope.rawValue }

    var isUnlocked: Bool { unlockedAt != nil && Date() >= (unlockedAt ?? .distantFuture) }

    func countdown(language: AppLanguage, timeZone: TimeZone) -> String {
        guard let unlockedAt else { return localized("—", "—", language: language) }
        let interval = unlockedAt.timeIntervalSince(Date())
        guard interval > 0 else { return localized("Ready", "已就绪", language: language) }
        let days = Int(interval / 86_400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86_400)) / 3_600)
        if days > 0 {
            return localized("\(days)d left", "剩 \(days) 天", language: language)
        }
        return localized("\(hours)h left", "剩 \(hours) 小时", language: language)
    }
}

struct SavedReport: Codable, Identifiable, Equatable {
    let id: String
    let scope: String // chart.<kind> or period.<type>
    let title: String
    let subtitle: String
    let generatedAt: Date
    let report: AIReport

    static func == (lhs: SavedReport, rhs: SavedReport) -> Bool { lhs.id == rhs.id }
}

func savedReportScopeTitle(_ scope: String, language: AppLanguage) -> String {
    switch scope {
    case "chart.natal": localized("Natal Report", "本命报告", language: language)
    case "chart.current-sky": localized("Current Sky Report", "天象报告", language: language)
    case "chart.transit": localized("Transit Report", "行运报告", language: language)
    case "chart.secondary": localized("Progressed Report", "次限报告", language: language)
    case "chart.solar-return": localized("Solar Return Report", "日返盘报告", language: language)
    case "chart.synastry": localized("Synastry Report", "合盘报告", language: language)
    case "period.daily": localized("Daily Report", "日报告", language: language)
    case "period.monthly": localized("Monthly Report", "月报告", language: language)
    case "period.solar-return": localized("Solar Return Report", "日返盘报告", language: language)
    default: scope
    }
}

func savedReportScopeSymbol(_ scope: String) -> String {
    switch scope {
    case "chart.natal": "✦"
    case "chart.current-sky": "◉"
    case "chart.transit": "◎"
    case "chart.secondary": "◐"
    case "chart.solar-return": "☉"
    case "chart.synastry": "∞"
    case "period.daily": "☾"
    case "period.monthly": "◐"
    case "period.solar-return": "☉"
    default: "◎"
    }
}

final class ReportStore: @unchecked Sendable {
    private let directory: URL
    private let indexURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("Reports", isDirectory: true)
        self.indexURL = self.directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func load() -> [SavedReport] {
        guard let data = try? Data(contentsOf: indexURL),
              let reports = try? JSONDecoder().decode([SavedReport].self, from: data)
        else {
            return []
        }
        return reports.sorted { $0.generatedAt > $1.generatedAt }
    }

    func save(_ report: SavedReport) {
        var reports = load()
        reports.removeAll { $0.id == report.id }
        reports.append(report)
        reports.sort { $0.generatedAt > $1.generatedAt }
        if let data = try? JSONEncoder().encode(reports) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    func remove(id: String) {
        var reports = load()
        reports.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(reports) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}

enum ReportUnlock {
    static func nextLocalMidnight(after date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    static func nextMonthStart(after date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let thisMonth = calendar.date(from: components),
              let next = calendar.date(byAdding: .month, value: 1, to: thisMonth)
        else {
            return date.addingTimeInterval(30 * 86_400)
        }
        return next
    }

    /// Next solar return moment (Sun returns to the natal Sun longitude).
    static func nextSolarReturn(
        birthDate: Date,
        after date: Date,
        calculator: SwissEphemerisCalculator
    ) async throws -> Date {
        try await calculator.solarReturnMoment(birthDate: birthDate, after: date)
    }
}
