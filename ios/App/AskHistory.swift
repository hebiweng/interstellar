import Foundation

struct AskHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let mode: String
    let question: String
    let answerTitle: String
    let answerText: String
    let createdAt: Date
    let locationName: String
    let significators: [String]

    static func == (lhs: AskHistoryEntry, rhs: AskHistoryEntry) -> Bool { lhs.id == rhs.id }
}

final class AskHistoryStore: @unchecked Sendable {
    static let shared = AskHistoryStore()
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.url = base.appendingPathComponent("AskHistory.json")
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: url)
    }

    func load() -> [AskHistoryEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AskHistoryEntry].self, from: data)
        else {
            return []
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    func append(_ entry: AskHistoryEntry, limit: Int = 100) {
        var entries = load()
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        entries.sort { $0.createdAt > $1.createdAt }
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
