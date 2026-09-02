import AstroCore
import Combine
import Foundation

enum CompareAnalysisStatus: String, Codable, Equatable, Sendable {
    case chartsReady = "charts_ready"
    case generatingReport = "generating_report"
    case completed
    case deliveryFailed = "delivery_failed"
    case reportFailed = "report_failed"
    case relayFailed = "relay_failed"
}

struct CompareAnalysis: Codable, Equatable, Identifiable {
    let id: String
    let createdAt: Date
    let request: CompareRequest
    let bundle: CompareCalculationBundle
    var status: CompareAnalysisStatus
    var result: CompareNarrativeResponse?
    var generationError: String?
    let semanticFingerprint: String
    let factsHash: String

    var canRetryReport: Bool {
        result == nil && status != .generatingReport && status != .completed
    }
}

@MainActor
final class CompareAnalysisStore: ObservableObject {
    static let shared = CompareAnalysisStore()
    static let recentHistoryLimit = 6
    static let persistedHistoryLimit = 100

    @Published private(set) var analyses: [CompareAnalysis] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Interstellar", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            self.fileURL = directory.appendingPathComponent("compare-analyses-v1.json")
        }
        load()
    }

    func analysis(id: String) -> CompareAnalysis? {
        analyses.first { $0.id == id }
    }

    var recentAnalyses: [CompareAnalysis] {
        Array(analyses.sorted { $0.createdAt > $1.createdAt }.prefix(Self.recentHistoryLimit))
    }

    @discardableResult
    func upsert(_ analysis: CompareAnalysis) -> Bool {
        if let index = analyses.firstIndex(where: { $0.id == analysis.id }) {
            analyses[index] = analysis
        } else {
            analyses.append(analysis)
        }
        analyses.sort { $0.createdAt > $1.createdAt }
        trimHistory()
        return persist()
    }

    func remove(id: String) {
        analyses.removeAll { $0.id == id }
        _ = persist()
    }

    func clearAll() {
        analyses = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func trimHistory() {
        analyses = Array(analyses.sorted { $0.createdAt > $1.createdAt }.prefix(Self.persistedHistoryLimit))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CompareAnalysis].self, from: data)
        else { return }
        analyses = decoded.sorted { $0.createdAt > $1.createdAt }
        trimHistory()
    }

    private func persist() -> Bool {
        guard let data = try? JSONEncoder().encode(analyses) else { return false }
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }
}
