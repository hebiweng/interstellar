import AstroCore
import Foundation

// MARK: - Generation states

enum AIDetailStatus: Equatable {
    case hidden      // offline, not authorized, or never requested
    case generating  // request in flight
    case ready       // detail available locally
}

struct AIReportSection: Codable, Equatable, Sendable {
    let number: String
    let title: String
    let body: String
    let callout: String?
}

struct AIReport: Codable, Equatable, Sendable {
    let title: String
    let subtitle: String
    let sections: [AIReportSection]
}

struct AIGenerateResponse: Codable, Equatable, Sendable {
    struct Report: Codable, Equatable, Sendable {
        let title: String
        let subtitle: String
        let sections: [AIReportSection]
    }
    struct CardDetail: Codable, Equatable, Sendable {
        let detail: String
    }
    let report: Report
    let cards: [String: CardDetail]
    let model: String?
    let cached: Bool?
}

struct AIChartContent: Equatable, Sendable {
    var cacheKey: String = ""
    var cardDetails: [String: String] = [:]
    var report: AIReport?
    var statusByCard: [String: AIDetailStatus] = [:]

    static let empty = AIChartContent()

    func status(for cardID: String) -> AIDetailStatus {
        statusByCard[cardID] ?? .hidden
    }
}

// MARK: - Facts document (what the relay sends to the LLM)

enum AIFactsBuilder {
    static func document(
        chart: ChartKind,
        snapshot: ChartSnapshot,
        reference: ChartSnapshot?,
        comparisonAspects: [ChartAspect],
        preset: CalculationPreset,
        personName: String,
        partnerName: String?,
        partnerChart: ChartSnapshot?,
        params: [String: String],
        locale: String,
        cardIDs: [String]
    ) -> [String: Any] {
        var document: [String: Any] = [
            "kind": chart.contentPrefix,
            "preset": preset.rawValue,
            "locale": locale,
            "cardIDs": cardIDs,
            "params": params,
            "chart": chartDocument(snapshot, houseReference: chart.isComparison ? (reference ?? snapshot) : snapshot),
        ]
        if let reference {
            document["reference"] = chartDocument(reference, houseReference: reference)
        }
        document["comparisonAspects"] = comparisonAspects.map(aspectDocument)
        if let phase = lunarPhase(snapshot) {
            document["lunarPhase"] = phase
        }
        document["person"] = ["name": personName]
        if let partnerName, let partnerChart {
            document["partner"] = [
                "name": partnerName,
                "chart": chartDocument(partnerChart, houseReference: partnerChart),
            ]
        }
        return document
    }

    static func periodDocument(
        periodType: String,
        personName: String,
        locale: String,
        events: [[String: Any]],
        params: [String: String]
    ) -> [String: Any] {
        [
            "kind": "period",
            "periodType": periodType,
            "locale": locale,
            "person": ["name": personName],
            "events": events,
            "params": params,
        ]
    }

    private static func chartDocument(_ snapshot: ChartSnapshot, houseReference: ChartSnapshot) -> [String: Any] {
        [
            "utcDate": ISO8601DateFormatter().string(from: snapshot.utcDate),
            "julianDay": round4(snapshot.julianDayUT),
            "angles": [
                "ascendant": round2(snapshot.angles.ascendantDegrees),
                "midheaven": round2(snapshot.angles.midheavenDegrees),
                "descendant": round2((snapshot.angles.ascendantDegrees + 180).truncatingRemainder(dividingBy: 360)),
                "imumCoeli": round2((snapshot.angles.midheavenDegrees + 180).truncatingRemainder(dividingBy: 360)),
            ],
            "houses": snapshot.houses.map { ["number": $0.number, "cusp": round2($0.cuspDegrees)] },
            "points": snapshot.points.map { pointDocument($0, houseReference: houseReference) },
            "aspects": snapshot.aspects.map(aspectDocument),
        ]
    }

    private static func pointDocument(_ point: ChartPoint, houseReference: ChartSnapshot) -> [String: Any] {
        [
            "id": point.body.rawValue,
            "name": point.body.displayName,
            "longitude": round2(point.longitudeDegrees),
            "sign": Zodiac.englishNames[point.signIndex],
            "degreeInSign": round2(point.degreeInSign),
            "house": houseReference.house(containing: point.longitudeDegrees),
            "retrograde": point.retrograde,
            "speed": round4(point.position.longitudeSpeedDegreesPerDay),
        ]
    }

    private static func aspectDocument(_ aspect: ChartAspect) -> [String: Any] {
        [
            "first": aspect.firstID,
            "second": aspect.secondID,
            "kind": aspect.kind.rawValue,
            "phase": aspect.phase.rawValue,
            "orb": round2(aspect.orbDegrees),
            "strength": round3(aspect.strength),
        ]
    }

    private static func lunarPhase(_ snapshot: ChartSnapshot) -> [String: Any]? {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return nil }
        let raw = (moon.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        let angle = raw >= 0 ? raw : raw + 360
        return ["angle": round2(angle)]
    }

    private static func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }
    private static func round3(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
    private static func round4(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }
}

// MARK: - Relay client

struct AIGenerateRequest: Sendable {
    let bodyData: Data
}

enum AIGenerationError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from the interpretation service."
        case let .server(message): message
        }
    }
}

struct AIGenerationClient: Sendable {
    let baseURL: URL

    init(baseURL: URL = URL(string: "https://fate.xiaoguiwk.top/relay")!) {
        self.baseURL = baseURL
    }

    func generate(_ request: AIGenerateRequest) async throws -> AIGenerateResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/generate"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 180
        urlRequest.httpBody = request.bodyData
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AIGenerationError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw AIGenerationError.server(message ?? "HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(AIGenerateResponse.self, from: data)
    }
}

// MARK: - Local cache

final class AIGenerationCache: @unchecked Sendable {
    private struct Entry: Codable {
        let cacheKey: String
        let scope: String
        let createdAt: Date
        let expiresAt: Date
        let response: AIGenerateResponse
    }

    private let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("AICache", isDirectory: true)
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    static func ttl(for chart: ChartKind) -> TimeInterval {
        switch chart {
        case .natal, .synastry: 3650 * 86_400
        case .currentSky: 86_400
        case .transit, .solarReturn: 7 * 86_400
        case .secondary: 30 * 86_400
        }
    }

    func url(for key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }

    func load(key: String) -> AIGenerateResponse? {
        guard let data = try? Data(contentsOf: url(for: key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              Date() < entry.expiresAt
        else {
            return nil
        }
        return entry.response
    }

    func clearAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(key: String, scope: String, response: AIGenerateResponse, ttl: TimeInterval) {
        let entry = Entry(
            cacheKey: key,
            scope: scope,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(ttl),
            response: response
        )
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }
}
