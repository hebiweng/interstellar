import AstroCore
import Foundation

struct AskOptionDraft: Identifiable, Equatable {
    let id: UUID
    var label: String
    var primaryHouse: Int?
    var additionalHouses: Set<Int>

    init(
        id: UUID = UUID(),
        label: String = "",
        primaryHouse: Int? = nil,
        additionalHouses: Set<Int> = []
    ) {
        self.id = id
        self.label = label
        self.primaryHouse = primaryHouse
        self.additionalHouses = additionalHouses
    }
}

enum BestTimeSearchWindow: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .sevenDays: localized("ask.best-time-next-7-days", language: language)
        case .thirtyDays: localized("ask.best-time-next-30-days", language: language)
        case .ninetyDays: localized("ask.best-time-next-90-days", language: language)
        }
    }
}

struct AskResultCard: Identifiable {
    let id: String
    let icon: String
    let summary: String
    let detail: String
}


enum AskViewError: Error {
    case invalidTimeZone
}

