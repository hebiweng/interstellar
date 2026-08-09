import AstroCore
import CryptoKit
import DeviceCheck
import Foundation
import Security

// MARK: - Generation states

enum AIReportGenerationStatus: Equatable, Sendable {
    case idle
    case generating
    case ready
    case failed(String)
}

struct AIReportSection: Codable, Equatable, Sendable {
    let number: String
    let title: String
    let body: String
    let callout: String?
    let evidenceFactIDs: [String]?

    init(number: String, title: String, body: String, callout: String? = nil, evidenceFactIDs: [String]? = nil) {
        self.number = number
        self.title = title
        self.body = body
        self.callout = callout
        self.evidenceFactIDs = evidenceFactIDs
    }
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
    let report: Report
    let provider: String?
    let model: String?
    let cached: Bool?
    let promptVersion: Int?
    let generationSchemaVersion: Int?
    let generatedAt: String?
    let semanticFingerprint: String?
    let factsHash: String?
}

struct GeneratedChartArtifact: Codable, Equatable, Sendable, Identifiable {
    static let schemaVersion = 2

    let semanticFingerprint: String
    let chartKind: String
    let subjectHashes: [String]
    let parameters: [String: String]
    let locale: String
    let preset: String
    let factsHash: String
    let provider: String?
    let model: String?
    let promptVersion: Int?
    let generationSchemaVersion: Int
    let generatedAt: Date
    let response: AIGenerateResponse

    var id: String { semanticFingerprint }
}

struct AIChartContent: Equatable, Sendable {
    var cacheKey: String = ""
    var report: AIReport?
    var status: AIReportGenerationStatus = .idle

    static let empty = AIChartContent()
}

enum AIArtifactIdentity {
    /// Report identity follows the calculated chart, not the language used to
    /// narrate it. The full request facts hash still includes locale and is
    /// verified independently by the Relay response contract.
    static func factsIdentityHash(_ facts: [String: Any]) throws -> String {
        var identityFacts = facts
        identityFacts.removeValue(forKey: "locale")
        let data = try JSONSerialization.data(withJSONObject: identityFacts, options: [.sortedKeys])
        return SHA256Digest.hash(data).hex
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
        classicalSynastryAssessment: ClassicalSynastryAssessment? = nil,
        events: ChartEventData,
        params: [String: String],
        locale: String
    ) -> [String: Any] {
        if chart == .synastry,
           let secondChart = partnerChart ?? reference,
           let partnerName
        {
            return synastryDocument(
                firstName: personName,
                firstChart: snapshot,
                secondName: partnerName,
                secondChart: secondChart,
                crossAspects: comparisonAspects,
                classicalAssessment: classicalSynastryAssessment,
                preset: preset,
                params: params,
                locale: locale
            )
        }
        var document: [String: Any] = [
            "kind": chart.contentPrefix,
            "preset": preset.rawValue,
            "locale": locale,
            "params": params,
            "chart": chartDocument(snapshot, houseReference: chart.isComparison ? (reference ?? snapshot) : snapshot),
            "evidenceFacts": evidenceDocuments(
                snapshot: snapshot,
                houseReference: chart.isComparison ? (reference ?? snapshot) : snapshot,
                comparisonAspects: comparisonAspects
            ) + eventEvidenceDocuments(events),
        ]
        if let reference {
            document["reference"] = chartDocument(reference, houseReference: reference)
        }
        document["comparisonAspects"] = comparisonAspects.map(aspectDocument)
        if let phase = lunarPhase(snapshot) {
            document["lunarPhase"] = phase
        }
        document["events"] = eventEvidenceDocuments(events)
        document["person"] = ["name": personName]
        if let partnerName, let partnerChart {
            document["partner"] = [
                "name": partnerName,
                "chart": chartDocument(partnerChart, houseReference: partnerChart),
            ]
        }
        return document
    }

    static func synastryDocument(
        firstName: String,
        firstChart: ChartSnapshot,
        secondName: String,
        secondChart: ChartSnapshot,
        crossAspects: [ChartAspect],
        classicalAssessment: ClassicalSynastryAssessment? = nil,
        preset: CalculationPreset,
        params: [String: String],
        locale: String
    ) -> [String: Any] {
        let firstID = "person-1"
        let secondID = "person-2"
        let firstNatalFacts = synastryNatalFacts(personID: firstID, snapshot: firstChart)
        let secondNatalFacts = synastryNatalFacts(personID: secondID, snapshot: secondChart)
        let receptions = Dictionary(
            uniqueKeysWithValues: (classicalAssessment?.crossChartReceptions ?? []).map {
                ("\($0.firstBody.rawValue)|\($0.aspectKind.rawValue)|\($0.secondBody.rawValue)", $0)
            }
        )
        let crossFacts = crossAspects.map { aspect -> [String: Any] in
            var fact: [String: Any] = [
                "id": "synastry.cross.\(firstID).\(aspect.firstID).\(aspect.kind.rawValue).\(secondID).\(aspect.secondID)",
                "type": "crossAspect",
                "firstPersonID": firstID,
                "firstBody": aspect.firstID,
                "secondPersonID": secondID,
                "secondBody": aspect.secondID,
                "aspect": aspect.kind.rawValue,
                "phase": aspect.phase.rawValue,
                "orb": round2(aspect.orbDegrees),
                "strength": round3(aspect.strength),
                "firstLongitude": round2(aspect.firstLongitude),
                "secondLongitude": round2(aspect.secondLongitude),
            ]
            if let reception = receptions["\(aspect.firstID)|\(aspect.kind.rawValue)|\(aspect.secondID)"] {
                fact["classicalAssessment"] = [
                    "receptionFromFirst": receptionDocument(reception.receptionFromFirst),
                    "receptionFromSecond": receptionDocument(reception.receptionFromSecond),
                ]
            }
            return fact
        }
        let overlayFacts = synastryOverlayFacts(
            sourceID: firstID,
            source: firstChart,
            receivingID: secondID,
            receiving: secondChart
        ) + synastryOverlayFacts(
            sourceID: secondID,
            source: secondChart,
            receivingID: firstID,
            receiving: firstChart
        )
        let conditionFacts = synastryConditionFacts(
            personID: firstID,
            assessments: classicalAssessment?.firstPlanets ?? []
        ) + synastryConditionFacts(
            personID: secondID,
            assessments: classicalAssessment?.secondPlanets ?? []
        )
        let evidenceFacts = (firstNatalFacts + secondNatalFacts + crossFacts + overlayFacts + conditionFacts).sorted {
            ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
        }

        return [
            "kind": ChartKind.synastry.contentPrefix,
            "preset": preset.rawValue,
            "locale": locale,
            "params": params,
            "people": [
                [
                    "id": firstID,
                    "name": firstName,
                    "natalFactIDs": firstNatalFacts.compactMap { $0["id"] as? String },
                ],
                [
                    "id": secondID,
                    "name": secondName,
                    "natalFactIDs": secondNatalFacts.compactMap { $0["id"] as? String },
                ],
            ],
            "relationship": [
                "crossAspectFactIDs": crossFacts.compactMap { $0["id"] as? String },
                "houseOverlayFactIDs": overlayFacts.compactMap { $0["id"] as? String },
                "classicalConditionFactIDs": conditionFacts.compactMap { $0["id"] as? String },
            ],
            "evidenceFacts": evidenceFacts,
        ]
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

    private static func synastryNatalFacts(personID: String, snapshot: ChartSnapshot) -> [[String: Any]] {
        let points = snapshot.points.map { point -> [String: Any] in
            [
                "id": "synastry.\(personID).point.\(point.body.rawValue)",
                "type": "natalPoint",
                "personID": personID,
                "body": point.body.rawValue,
                "longitude": round2(point.longitudeDegrees),
                "sign": Zodiac.englishNames[point.signIndex],
                "degreeInSign": round2(point.degreeInSign),
                "natalHouse": snapshot.house(containing: point.longitudeDegrees),
                "retrograde": point.retrograde,
                "speed": round4(point.position.longitudeSpeedDegreesPerDay),
            ]
        }
        let angles: [String: Any] = [
            "id": "synastry.\(personID).angles",
            "type": "natalAngles",
            "personID": personID,
            "ascendant": round2(snapshot.angles.ascendantDegrees),
            "midheaven": round2(snapshot.angles.midheavenDegrees),
            "descendant": round2((snapshot.angles.ascendantDegrees + 180).truncatingRemainder(dividingBy: 360)),
            "imumCoeli": round2((snapshot.angles.midheavenDegrees + 180).truncatingRemainder(dividingBy: 360)),
        ]
        return points + [angles]
    }

    private static func synastryOverlayFacts(
        sourceID: String,
        source: ChartSnapshot,
        receivingID: String,
        receiving: ChartSnapshot
    ) -> [[String: Any]] {
        source.points.map { point in
            let house = receiving.house(containing: point.longitudeDegrees)
            return [
                "id": "synastry.overlay.\(sourceID).\(point.body.rawValue).in.\(receivingID).house.\(house)",
                "type": "houseOverlay",
                "sourcePersonID": sourceID,
                "body": point.body.rawValue,
                "receivingPersonID": receivingID,
                "house": house,
            ] as [String: Any]
        }
    }

    private static func synastryConditionFacts(
        personID: String,
        assessments: [HoraryPlanetAssessment]
    ) -> [[String: Any]] {
        assessments.map { assessment in
            [
                "id": "synastry.\(personID).classical-condition.\(assessment.body.rawValue)",
                "type": "classicalPlanetCondition",
                "personID": personID,
                "body": assessment.body.rawValue,
                "house": assessment.house,
                "signIndex": assessment.signIndex,
                "score": round2(assessment.score),
                "conditions": assessment.conditions.map(\.rawValue),
            ] as [String: Any]
        }
    }

    private static func receptionDocument(_ reception: HoraryReception) -> [String: Any] {
        [
            "from": reception.from.rawValue,
            "to": reception.to.rawValue,
            "byDomicile": reception.byDomicile,
            "byExaltation": reception.byExaltation,
            "isPresent": reception.isPresent,
        ]
    }

    private static func evidenceDocuments(
        snapshot: ChartSnapshot,
        houseReference: ChartSnapshot,
        comparisonAspects: [ChartAspect]
    ) -> [[String: Any]] {
        var facts = snapshot.points.map { point -> [String: Any] in
            let house = houseReference.house(containing: point.longitudeDegrees)
            return [
                "id": "point.\(point.body.rawValue)",
                "type": "point",
                "body": point.body.rawValue,
                "longitude": round2(point.longitudeDegrees),
                "sign": Zodiac.englishNames[point.signIndex],
                "degreeInSign": round2(point.degreeInSign),
                "house": house,
                "retrograde": point.retrograde,
            ]
        }
        let sourceAspects = comparisonAspects.isEmpty ? snapshot.aspects : comparisonAspects
        facts.append(contentsOf: sourceAspects.map { aspect in
            [
                "id": "aspect.\(aspect.firstID).\(aspect.kind.rawValue).\(aspect.secondID)",
                "type": "aspect",
                "first": aspect.firstID,
                "second": aspect.secondID,
                "kind": aspect.kind.rawValue,
                "phase": aspect.phase.rawValue,
                "orb": round2(aspect.orbDegrees),
                "strength": round3(aspect.strength),
            ]
        })
        facts.append(contentsOf: [
            ["id": "angle.ascendant", "type": "angle", "longitude": round2(snapshot.angles.ascendantDegrees)],
            ["id": "angle.midheaven", "type": "angle", "longitude": round2(snapshot.angles.midheavenDegrees)],
        ])
        return facts
    }

    private static func eventEvidenceDocuments(_ events: ChartEventData) -> [[String: Any]] {
        let formatter = ISO8601DateFormatter()
        var facts: [[String: Any]] = events.skyIngresses.map { event in
            [
                "id": "event.ingress.\(event.body.rawValue).\(Int(event.date.timeIntervalSince1970))",
                "type": "skyIngress",
                "body": event.body.rawValue,
                "signIndex": event.signIndex,
                "date": formatter.string(from: event.date),
                "nextDate": event.nextDate.map(formatter.string(from:)) ?? "",
            ]
        }
        facts += events.skyExactEvents.map { event in
            [
                "id": "event.skyAspect.\(event.first.rawValue).\(event.kind.rawValue).\(event.second.rawValue).\(Int(event.date.timeIntervalSince1970))",
                "type": "skyExactAspect",
                "first": event.first.rawValue,
                "second": event.second.rawValue,
                "kind": event.kind.rawValue,
                "date": formatter.string(from: event.date),
            ]
        }
        facts += events.skyStations.map { event in
            [
                "id": "event.station.\(event.body.rawValue).\(Int(event.date.timeIntervalSince1970))",
                "type": "station",
                "body": event.body.rawValue,
                "date": formatter.string(from: event.date),
                "retrogradeAfter": event.retrogradeAfter,
            ]
        }
        facts += events.transitWindows.map { event in
            [
                "id": "event.transitWindow.\(event.first.rawValue).\(event.kind.rawValue).\(event.second.rawValue).\(Int(event.exact.timeIntervalSince1970))",
                "type": "transitWindow",
                "first": event.first.rawValue,
                "second": event.second.rawValue,
                "kind": event.kind.rawValue,
                "start": formatter.string(from: event.start),
                "exact": formatter.string(from: event.exact),
                "end": formatter.string(from: event.end),
                "nextExact": event.nextExact.map(formatter.string(from:)) ?? "",
            ]
        }
        facts += events.progressedTurningPoints.enumerated().map { index, event in
            [
                "id": "event.progressed.\(event.first.rawValue).\(event.kind.rawValue).\(event.second.rawValue).\(index)",
                "type": "progressedTurningPoint",
                "first": event.first.rawValue,
                "second": event.second.rawValue,
                "kind": event.kind.rawValue,
                "phase": event.phase.rawValue,
                "separation": round2(event.separationDegrees),
                "exactDate": event.exactDate.map(formatter.string(from:)) ?? "",
            ]
        }
        if let event = events.progressedMoon {
            facts.append([
                "id": "event.progressedMoon.\(Int(event.nextIngress.timeIntervalSince1970))",
                "type": "progressedMoonWindow",
                "signIndex": event.signIndex,
                "daysInSign": event.daysInSign,
                "nextIngress": formatter.string(from: event.nextIngress),
            ])
        }
        facts += events.solarSeasons.map { event in
            [
                "id": "event.solarSeason.\(event.index).\(Int(event.start.timeIntervalSince1970))",
                "type": "solarSeason",
                "index": event.index,
                "start": formatter.string(from: event.start),
                "end": formatter.string(from: event.end),
            ]
        }
        return facts
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
    case contract(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from the interpretation service."
        case let .server(message): message
        case let .contract(message): "Interpretation response contract failed: \(message)"
        }
    }
}

struct AIGenerationClient: Sendable {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
            ?? ProcessInfo.processInfo.environment["INTERSTELLAR_RELAY_BASE_URL"].flatMap(URL.init(string:))
            ?? URL(string: "https://aaadmin.xiaoguiwk.top")!
    }

    func generate(_ request: AIGenerateRequest) async throws -> AIGenerateResponse {
        for attempt in 0 ..< 2 {
            var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/generate"))
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
            let authorization = try await AppAttestAuthorizer.shared.headers(
                for: request.bodyData,
                baseURL: baseURL,
                forceTokenRefresh: attempt > 0
            )
            for (name, value) in authorization {
                urlRequest.setValue(value, forHTTPHeaderField: name)
            }
            urlRequest.timeoutInterval = 180
            urlRequest.httpBody = request.bodyData
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw AIGenerationError.invalidResponse
            }
            if http.statusCode == 401, attempt == 0 {
                await AppAttestAuthorizer.shared.invalidateToken()
                continue
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                throw AIGenerationError.server(message ?? "HTTP \(http.statusCode)")
            }
            return try JSONDecoder().decode(AIGenerateResponse.self, from: data)
        }
        throw AIGenerationError.server("App Attest authorization failed.")
    }
}

private actor AppAttestAuthorizer {
    static let shared = AppAttestAuthorizer()

    private struct ChallengeRequest: Encodable {
        let installationID: String
        let keyID: String
        let purpose: String
        let bodyHash: String
    }

    private struct ChallengeResponse: Decodable {
        let challengeID: String
        let challenge: String
        let expiresAt: Date
    }

    private struct AttestationRequest: Encodable {
        let installationID: String
        let keyID: String
        let challengeID: String
        let attestationObject: String
    }

    private struct TokenRequest: Encodable {
        let installationID: String
        let keyID: String
    }

    private struct TokenResponse: Decodable {
        let token: String
        let expiresAt: Date
    }

    private struct ClientData: Encodable {
        let challengeID: String
        let challenge: String
        let bodyHash: String
    }

    private struct ServerError: Decodable {
        let error: String?
        let code: String?
    }

    private struct InstallationToken {
        let value: String
        let expiresAt: Date

        var isUsable: Bool { expiresAt.timeIntervalSinceNow > 30 }
    }

    private enum AuthorizationError: LocalizedError {
        case unsupported
        case server(status: Int, code: String?, message: String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .unsupported:
                "This device cannot verify the app installation."
            case let .server(_, _, message):
                message
            case .invalidResponse:
                "Invalid response from the app verification service."
            }
        }

        var requiresNewKey: Bool {
            if case let .server(_, code, _) = self {
                return code == "attestation_required"
            }
            return false
        }
    }

    private let service = DCAppAttestService.shared
    private var installationToken: InstallationToken?

    func invalidateToken() {
        installationToken = nil
    }

   func headers(for body: Data, baseURL: URL, forceTokenRefresh: Bool) async throws -> [String: String] {
        // Temporary: skip App Attest in Debug builds while the Apple Developer Program is not purchased.
        #if DEBUG || targetEnvironment(simulator)
            return ["X-App-Attest-Development-Bypass": "1"]
        #else
            guard service.isSupported else { throw AuthorizationError.unsupported }
            if forceTokenRefresh {
                installationToken = nil
            }
            let keyID = try await ensureKeyAndToken(baseURL: baseURL)
            guard let token = installationToken, token.isUsable else {
                throw AuthorizationError.invalidResponse
            }
            return try await assertionHeaders(
                body: body,
                keyID: keyID,
                token: token.value,
                baseURL: baseURL
            )
        #endif
    }

    private func ensureKeyAndToken(baseURL: URL) async throws -> String {
        if let keyID = keyIdentifier(), installationToken?.isUsable == true {
            return keyID
        }
        if let keyID = keyIdentifier() {
            do {
                installationToken = try await refreshToken(keyID: keyID, baseURL: baseURL)
                return keyID
            } catch let error as AuthorizationError where error.requiresNewKey {
                removeKeyIdentifier()
            }
        }
        let keyID = try await service.generateKey()
        do {
            installationToken = try await attestNewKey(keyID: keyID, baseURL: baseURL)
            saveKeyIdentifier(keyID)
            return keyID
        } catch {
            removeKeyIdentifier()
            throw error
        }
    }

    private func attestNewKey(keyID: String, baseURL: URL) async throws -> InstallationToken {
        let challenge = try await fetchChallenge(
            purpose: "attest", keyID: keyID, bodyHash: "", baseURL: baseURL
        )
        guard let challengeData = Data(base64Encoded: challenge.challenge) else {
            throw AuthorizationError.invalidResponse
        }
        let attestation = try await service.attestKey(keyID, clientDataHash: digest(challengeData))
        let request = AttestationRequest(
            installationID: InstallationIdentity.value,
            keyID: keyID,
            challengeID: challenge.challengeID,
            attestationObject: attestation.base64EncodedString()
        )
        let body = try encoded(request)
        let response: TokenResponse = try await post(
            body: body,
            to: baseURL.appendingPathComponent("v1/app-attest/attest"),
            headers: [:]
        )
        return InstallationToken(value: response.token, expiresAt: response.expiresAt)
    }

    private func refreshToken(keyID: String, baseURL: URL) async throws -> InstallationToken {
        let body = try encoded(TokenRequest(installationID: InstallationIdentity.value, keyID: keyID))
        let headers = try await assertionHeaders(body: body, keyID: keyID, token: nil, baseURL: baseURL)
        let response: TokenResponse = try await post(
            body: body,
            to: baseURL.appendingPathComponent("v1/app-attest/token"),
            headers: headers
        )
        return InstallationToken(value: response.token, expiresAt: response.expiresAt)
    }

    private func assertionHeaders(body: Data, keyID: String, token: String?, baseURL: URL) async throws -> [String: String] {
        let bodyHash = digest(body).base64EncodedString()
        let challenge = try await fetchChallenge(
            purpose: "assertion", keyID: keyID, bodyHash: bodyHash, baseURL: baseURL
        )
        let clientData = try encoded(ClientData(
            challengeID: challenge.challengeID,
            challenge: challenge.challenge,
            bodyHash: bodyHash
        ))
        let assertion = try await service.generateAssertion(keyID, clientDataHash: digest(clientData))
        var headers = [
            "X-App-Attest-Key-ID": keyID,
            "X-App-Attest-Challenge-ID": challenge.challengeID,
            "X-App-Attest-Client-Data": clientData.base64EncodedString(),
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
        ]
        if let token {
            headers["X-App-Attest-Token"] = token
        }
        return headers
    }

    private func fetchChallenge(purpose: String, keyID: String, bodyHash: String, baseURL: URL) async throws -> ChallengeResponse {
        let body = try encoded(ChallengeRequest(
            installationID: InstallationIdentity.value,
            keyID: keyID,
            purpose: purpose,
            bodyHash: bodyHash
        ))
        return try await post(
            body: body,
            to: baseURL.appendingPathComponent("v1/app-attest/challenge"),
            headers: [:]
        )
    }

    private func post<Response: Decodable>(body: Data, to url: URL, headers: [String: String]) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthorizationError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let server = try? JSONDecoder().decode(ServerError.self, from: data)
            throw AuthorizationError.server(
                status: http.statusCode,
                code: server?.code,
                message: server?.error ?? "App verification failed (HTTP \(http.statusCode))."
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }

    private func encoded<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder.sorted.encode(value)
    }

    private func digest(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private func keyIdentifier() -> String? {
        let data = KeychainValue.read(service: InstallationIdentity.service, account: "app-attest-key-id")
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    private func saveKeyIdentifier(_ keyID: String) {
        KeychainValue.replace(
            Data(keyID.utf8),
            service: InstallationIdentity.service,
            account: "app-attest-key-id"
        )
    }

    private func removeKeyIdentifier() {
        KeychainValue.remove(service: InstallationIdentity.service, account: "app-attest-key-id")
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private enum InstallationIdentity {
    fileprivate static let service = "com.xiaoguiwk.interstellar.relay"
    private static let account = "installation-id"

    static let value: String = {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let existing = String(data: data, encoding: .utf8),
           !existing.isEmpty
        {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(created.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(add as CFDictionary, nil)
        return created
    }()
}

private enum KeychainValue {
    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func replace(_ data: Data, service: String, account: String) {
        remove(service: service, account: account)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func remove(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Local cache

final class GeneratedArtifactStore: @unchecked Sendable {
    private let directory: URL
    private let periodIndexURL: URL
    private let legacyReportsDirectory: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("GeneratedChartArtifacts", isDirectory: true)
        periodIndexURL = self.directory.appendingPathComponent("period-reports.json")
        legacyReportsDirectory = base.appendingPathComponent("Reports", isDirectory: true)
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        migrateLegacyPeriodReportsIfNeeded()
    }

    func url(for key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }

    func load(key: String) -> GeneratedChartArtifact? {
        guard let data = try? Data(contentsOf: url(for: key)),
              let artifact = try? JSONDecoder().decode(GeneratedChartArtifact.self, from: data),
              artifact.semanticFingerprint == key
        else {
            return nil
        }
        return artifact
    }

    func clearAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.removeItem(at: legacyReportsDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ artifact: GeneratedChartArtifact) {
        guard let data = try? JSONEncoder().encode(artifact) else { return }
        let destination = url(for: artifact.semanticFingerprint)
        do {
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: destination.path
            )
        } catch {
            // The UI keeps the in-memory result; a subsequent launch will
            // explicitly regenerate instead of treating a partial write as a hit.
        }
    }

    func loadAll() -> [GeneratedChartArtifact] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(GeneratedChartArtifact.self, from: data)
        }
        .sorted { $0.generatedAt > $1.generatedAt }
    }

    func remove(subjectHash: String) {
        for artifact in loadAll() where artifact.subjectHashes.contains(subjectHash) {
            try? fileManager.removeItem(at: url(for: artifact.semanticFingerprint))
        }
    }

    func remove(chartKind: ChartKind) {
        for artifact in loadAll() where artifact.chartKind == chartKind.contentPrefix {
            try? fileManager.removeItem(at: url(for: artifact.semanticFingerprint))
        }
    }

    func remove(key: String) {
        try? fileManager.removeItem(at: url(for: key))
    }

    func loadPeriodReports() -> [SavedReport] {
        guard let data = try? Data(contentsOf: periodIndexURL),
              let reports = try? JSONDecoder().decode([SavedReport].self, from: data)
        else { return [] }
        return reports.sorted { $0.generatedAt > $1.generatedAt }
    }

    func savePeriodReport(_ report: SavedReport) {
        var reports = loadPeriodReports()
        reports.removeAll { $0.id == report.id }
        reports.append(report)
        reports.sort { $0.generatedAt > $1.generatedAt }
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: periodIndexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func migrateLegacyPeriodReportsIfNeeded() {
        guard !fileManager.fileExists(atPath: periodIndexURL.path) else { return }
        let oldIndex = legacyReportsDirectory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: oldIndex),
              (try? JSONDecoder().decode([SavedReport].self, from: data)) != nil
        else { return }
        try? data.write(to: periodIndexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
