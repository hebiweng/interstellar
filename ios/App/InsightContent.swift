import ContentKit
import Foundation

struct InsightContentEntry: Codable, Equatable {
    let contentKey: String
    let summary: String
    let detail: String
    let sourceRevision: String?
    let translationStatus: String?
}

private struct InsightContentPack: Codable {
    let version: String
    let locale: String
    let entries: [InsightContentEntry]
}

struct ContentProvider {
    private let entries: [String: InsightContentEntry]

    init(language: AppLanguage, bundle: Bundle = .main) {
        let resourceName = "PrivateContent-\(language.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        var loaded: [InsightContentEntry] = []
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let pack = try? JSONDecoder().decode(InsightContentPack.self, from: data)
            {
                loaded = pack.entries.filter {
                    $0.translationStatus == "approved"
                        || $0.translationStatus == "sample"
                }
                break
            }
        }
        entries = Dictionary(uniqueKeysWithValues: loaded.map { ($0.contentKey, $0) })
    }

    func requiredCopy(
        key: String,
        variables: [String: String] = [:]
    ) throws -> (summary: String, detail: String) {
        guard let entry = entries[key] else {
            throw ConsumerContentError.missingEntry(key)
        }
        return (
            interpolate(entry.summary, variables: variables),
            interpolate(entry.detail, variables: variables)
        )
    }

    private func interpolate(
        _ template: String,
        variables: [String: String]
    ) -> String {
        variables.reduce(template) { result, item in
            result.replacingOccurrences(of: "{{\(item.key)}}", with: item.value)
        }
    }
}

enum ConsumerContentError: Error, LocalizedError {
    case missingEntry(String)

    var errorDescription: String? {
        switch self {
        case let .missingEntry(key):
            "Required consumer content is missing: \(key)"
        }
    }
}

enum CorpusContentProviderError: Error, LocalizedError {
    case resourceMissing(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(name):
            "Required interpretation pack \(name) is missing."
        case let .unreadable(reason):
            "Interpretation content could not be loaded: \(reason)"
        }
    }
}

struct CorpusContentProvider {
    private let engine: InterpretationEngine

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let resourceName = "PrivateCorpus-\(language.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CorpusContentProviderError.resourceMissing(resourceName)
        }

        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(InterpretationContentPack.self, from: data)
            #if DEBUG
            engine = try InterpretationEngine(
                pack: pack,
                allowedStatuses: ["approved", "sample"]
            )
            #else
            engine = try InterpretationEngine(pack: pack)
            #endif
            try engine.validateCoverage(requiredCards: Self.requiredCards)
        } catch {
            throw CorpusContentProviderError.unreadable(String(describing: error))
        }
    }

    func interpret(_ context: InterpretationContext) throws -> InterpretationResult {
        try engine.interpret(context)
    }

    private static let requiredCards: [InterpretationTechnique: Set<String>] = [
        .natal: [
            "natal-interpretation",
            "love-connection",
            "career-direction",
            "strengths-growth",
            "element-balance",
            "house-emphasis",
            "chart-signature",
            "planet-placements",
            "key-aspects",
        ],
        .currentSky: [
            "sky-overview",
            "moon-now",
            "aspect-pattern",
            "planetary-motion",
            "sign-changes",
            "element-climate",
            "upcoming-7-days",
        ],
        .transit: [
            "current-story",
            "current-cycles",
            "transit-timeline",
            "planet-paths",
            "life-areas",
            "active-transits",
        ],
        .secondary: [
            "developmental-chapter",
            "progressed-moon",
            "identity-development",
            "turning-points",
            "areas-maturing",
            "timeline",
        ],
        .solarReturn: [
            "year-theme",
            "year-anchors",
            "priority-areas",
            "year-dynamics",
            "year-timeline",
            "natal-overlay",
            "year-aspects",
        ],
        .synastry: [
            "relationship-overview",
            "perspectives",
            "emotional-connection",
            "communication",
            "chemistry",
            "commitment",
            "house-overlays",
            "key-inter-aspects",
        ],
    ]
}
