import AstroCore
import Foundation

struct AppAIChartFactsInput {
    let chart: ChartKind
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let techniqueMetadata: ChartTechniqueMetadata?
    let preset: CalculationPreset
    let personName: String
    let partnerName: String?
    let partnerChart: ChartSnapshot?
    let classicalSynastryAssessment: ClassicalSynastryAssessment?
    let events: ChartEventData
    let params: [String: String]
    let locale: String
    let transitBundle: TransitFactBundle?
    let relationship: PersonRelationship?
}
struct AppAIChartFactsOutput {
    let document: [String: Any]
    let transitPlan: TransitContentPlan?
}

final class AppAIReportService {
    func buildFacts(_ input: AppAIChartFactsInput) -> AppAIChartFactsOutput {
        var document = AIFactsBuilder.document(
            chart: input.chart,
            snapshot: input.snapshot,
            reference: input.reference,
            comparisonAspects: input.comparisonAspects,
            techniqueMetadata: input.techniqueMetadata,
            preset: input.preset,
            personName: input.personName,
            partnerName: input.partnerName,
            partnerChart: input.partnerChart,
            classicalSynastryAssessment: input.classicalSynastryAssessment,
            events: input.events,
            params: providerContextParameters(input.params),
            locale: input.locale,
            relationship: input.relationship
        )
        let transitPlan = input.transitBundle.map(TransitContentPlanner.plan)
        if let bundle = input.transitBundle, let transitPlan {
            document["transit"] = transitBundleDocument(bundle)
            document["transitAssessment"] = transitAssessmentDocument(transitPlan)
            document["evidenceFacts"] = transitEvidenceFacts(bundle)
        }
        return AppAIChartFactsOutput(document: document, transitPlan: transitPlan)
    }

    func parameters(
        for target: ChartTarget,
        subjectTimeZoneID: String,
        subjectHashes: [String],
        relationship: PersonRelationship? = nil
    ) -> [String: String] {
        let formatter = ISO8601DateFormatter()
        switch target {
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
                    timeZoneID: subjectTimeZoneID
                ),
                "selectionMode": usesLiveDefault ? "live-month" : "exact-date",
            ]
        case let .solarReturn(year, location):
            return locationParameters(location).merging(["returnYear": String(year)]) { _, new in new }
        case .synastry:
            var params: [String: String] = ["partnerHash": subjectHashes.dropFirst().first ?? ""]
            if let relationship {
                params["relationship"] = relationship.rawValue
            }
            return params
        case let .tertiary(targetDate, usesLiveDefault):
            return [
                "targetDate": bucket(targetDate, format: "yyyy-MM-dd", timeZoneID: subjectTimeZoneID),
                "selectionMode": usesLiveDefault ? "live-day" : "exact-date",
            ]
        case let .lunarReturn(targetDate, location, usesLiveDefault):
            return locationParameters(location).merging([
                "targetDate": bucket(targetDate, format: "yyyy-MM-dd", timeZoneID: location.timezoneID),
                "selectionMode": usesLiveDefault ? "live-day" : "exact-date",
            ]) { _, new in new }
        case let .solarArc(targetDate, usesLiveDefault):
            return [
                "targetDate": bucket(targetDate, format: "yyyy-MM-dd", timeZoneID: subjectTimeZoneID),
                "selectionMode": usesLiveDefault ? "live-day" : "exact-date",
            ]
        case let .relocation(location):
            return locationParameters(location)
        case .twelfthHarmonic, .thirteenthHarmonic:
            return [:]
        }
    }

    func semanticFingerprint(
        chart: ChartKind,
        preset: CalculationPreset,
        target: ChartTarget,
        subjectHashes: [String],
        params: [String: String],
        factsHash: String
    ) -> String {
        let includeExactFacts: Bool = switch target {
        case .natal, .solarReturn, .synastry, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            true
        case let .currentSky(_, _, usesLiveDefault): !usesLiveDefault
        case let .transit(_, _, _, usesLiveDefault): !usesLiveDefault
        case let .secondary(_, usesLiveDefault): !usesLiveDefault
        case let .tertiary(_, usesLiveDefault): !usesLiveDefault
        case let .lunarReturn(_, _, usesLiveDefault): !usesLiveDefault
        case let .solarArc(_, usesLiveDefault): !usesLiveDefault
        }
        let raw = [
            chart.contentPrefix,
            preset.rawValue,
            subjectHashes.joined(separator: ","),
            params.keys.sorted().map { "\($0)=\(params[$0] ?? "")" }.joined(separator: ","),
            "generation=\(GeneratedChartArtifact.schemaVersion)",
            includeExactFacts ? factsHash : "semantic-bucket",
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    func profileHash(_ profile: UserProfile) -> String {
        let raw = [
            profile.name, profile.placeName, profile.timezoneID,
            String(profile.birthDateUTC.timeIntervalSince1970),
            String(profile.latitude), String(profile.longitude),
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    func relationshipSemanticFingerprint(
        kind: RelationshipChartKind,
        preset: CalculationPreset,
        subjectHashes: [String],
        params: [String: String],
        factsHash: String
    ) -> String {
        let raw = [
            "relationship.\(kind.rawValue)",
            preset.rawValue,
            subjectHashes.joined(separator: ","),
            params.keys.sorted().map { "\($0)=\(params[$0] ?? "")" }.joined(separator: ","),
            "generation=\(GeneratedChartArtifact.schemaVersion)",
            factsHash,
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    func relationshipRequestBody(
        kind: RelationshipChartKind,
        preset: CalculationPreset,
        primarySubjectHash: String,
        params: [String: String],
        facts: [String: Any],
        semanticFingerprint: String,
        factsHash: String,
        locale: String,
        userID: String,
        forceRegenerate: Bool
    ) -> [String: Any] {
        [
            "userID": userID,
            "requestID": UUID().uuidString.lowercased(),
            "reportID": semanticFingerprint,
            "mode": "chart",
            "chartKind": "relationship.\(kind.rawValue)",
            "reportPromptKey": "relationship.\(kind.rawValue)",
            "periodType": NSNull(),
            "preset": preset.rawValue,
            "profileHash": primarySubjectHash,
            "params": providerContextParameters(params),
            "facts": providerSafeFacts(facts),
            "semanticFingerprint": semanticFingerprint,
            "factsHash": factsHash,
            "generationSchemaVersion": GeneratedChartArtifact.schemaVersion,
            "locale": locale,
            "clientVersion": "ios-v6",
            "forceRegenerate": forceRegenerate,
        ]
    }

    func chartRequestBody(
        chart: ChartKind,
        preset: CalculationPreset,
        primarySubjectHash: String,
        params: [String: String],
        facts: [String: Any],
        semanticFingerprint: String,
        factsHash: String,
        locale: String,
		userID: String,
        forceRegenerate: Bool
    ) -> [String: Any] {
        [
			"userID": userID,
			"requestID": UUID().uuidString.lowercased(),
			"reportID": semanticFingerprint,
            "mode": "chart",
            "chartKind": chart.contentPrefix,
            "periodType": NSNull(),
            "preset": preset.rawValue,
            "profileHash": primarySubjectHash,
            "params": providerContextParameters(params),
            "facts": providerSafeFacts(facts),
            "semanticFingerprint": semanticFingerprint,
            "factsHash": factsHash,
            "generationSchemaVersion": GeneratedChartArtifact.schemaVersion,
            "locale": locale,
            "clientVersion": "ios-v6",
            "forceRegenerate": forceRegenerate,
        ]
    }

    private func transitBundleDocument(_ bundle: TransitFactBundle) -> [String: Any] {
        [
            "scopeID": bundle.scopeID,
            "anchorDate": ISO8601DateFormatter().string(from: bundle.anchorDate),
            "rangeDays": bundle.rangeDays,
            "preset": bundle.preset,
        ]
    }

    private func transitAssessmentDocument(_ plan: TransitContentPlan) -> [String: Any] {
        let currentStory = plan.card("current-story")
        let themeInputs = plan.cards.flatMap(\.themeInputs).map { input in
            [
                "signalID": input.signalID,
                "sourceFactIDs": input.sourceFactIDs,
                "movingID": input.movingID.map { $0 as Any } ?? NSNull(),
                "referenceID": input.referenceID.map { $0 as Any } ?? NSNull(),
                "aspect": input.aspectKind.map { $0.rawValue as Any } ?? NSNull(),
                "tone": input.tone,
                "house": input.house.map { $0 as Any } ?? NSNull(),
                "roleID": input.roleID,
                "classicalThemeID": input.classicalThemeID.map { $0.rawValue as Any } ?? NSNull(),
            ] as [String: Any]
        }
        return [
            "preset": plan.preset,
            "themeInputs": themeInputs,
            "currentStoryAnchor": [
                "modernIntegratedThemeID": currentStory?.integratedThemeID?.rawValue as Any? ?? NSNull(),
                "modernSignalRoles": currentStory?.signalRoles.map {
                    [
                        "signalID": $0.signalID,
                        "signalRole": $0.signalRole.rawValue,
                        "movingID": $0.movingID,
                        "lifeAreas": $0.lifeAreas,
                        "sourceFactIDs": $0.sourceFactIDs,
                    ]
                } ?? [],
                "classicalIntegratedThemeID": currentStory?.classicalIntegratedThemeID?.rawValue as Any? ?? NSNull(),
                "classicalSignalRoles": currentStory?.classicalSignalRoles.map {
                    [
                        "signalRole": $0.signalRole.rawValue,
                        "movingID": $0.movingID,
                        "sourceFactIDs": $0.sourceFactIDs,
                    ]
                } ?? [],
            ] as [String: Any],
        ]
    }

    private func transitEvidenceFacts(_ bundle: TransitFactBundle) -> [[String: Any]] {
        var factsByID: [String: [String: Any]] = [:]
        let facts: [TransitFact] = bundle.crossAspects.map(TransitFact.aspect)
            + bundle.transitWindows.map(TransitFact.window)
            + bundle.planetEvents.map(TransitFact.planetEvent)
            + bundle.planetPlacements.map(TransitFact.placement)
            + bundle.lifeAreaScores.map(TransitFact.lifeArea)
        for fact in facts {
            factsByID[fact.factID] = transitEvidenceDocument(fact)
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
                "cycleBand": value.cycleBand.rawValue,
                "classicalContext": value.classicalContext.map {
                    [
                        "movingScore": $0.movingScore,
                        "movingConditions": $0.movingConditions.map(\.rawValue),
                        "receptionFromMoving": $0.receptionFromMoving,
                        "receptionFromReference": $0.receptionFromReference,
                    ] as [String: Any]
                } ?? NSNull(),
            ]
        case let .window(value):
            return [
                "id": value.factID,
                "kind": "transit-window",
                "sourceAspectFactID": value.sourceAspectFactID.map { $0 as Any } ?? NSNull(),
                "movingID": value.movingID,
                "referenceID": value.referenceID,
                "aspect": value.kind.rawValue,
                "movingLongitude": value.movingLongitude,
                "natalHouse": value.natalHouse,
                "start": ISO8601DateFormatter().string(from: value.start),
                "exact": ISO8601DateFormatter().string(from: value.exact),
                "end": ISO8601DateFormatter().string(from: value.end),
                "repeatExact": value.repeatExact.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
                "nextExact": value.nextExact.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
                "passIndex": value.passIndex,
                "passCount": value.passCount,
                "returning": value.returning,
                "timeZone": value.timeZoneIdentifier,
                "cycleBand": value.cycleBand.rawValue,
            ]
        case let .planetEvent(value):
            return [
                "id": value.factID,
                "kind": "transit-planet-event",
                "body": value.body.rawValue,
                "eventKind": value.kind.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: value.timestamp),
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
                "classicalScore": value.classicalScore.map { $0 as Any } ?? NSNull(),
                "classicalConditions": value.classicalConditions.map(\.rawValue),
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
            ]
        }
    }

    private func providerContextParameters(_ params: [String: String]) -> [String: String] {
        guard let relationship = params["relationship"] else { return [:] }
        return ["relationship": relationship]
    }

    private func providerSafeFacts(_ rawFacts: [String: Any]) -> [String: Any] {
        var facts = rawFacts
        if let params = facts["params"] as? [String: String] {
            let context = providerContextParameters(params)
            if context.isEmpty {
                facts.removeValue(forKey: "params")
            } else {
                facts["params"] = context
            }
        }
        for key in ["chart", "reference"] {
            if var chart = facts[key] as? [String: Any] {
                chart.removeValue(forKey: "utcDate")
                chart.removeValue(forKey: "julianDay")
                facts[key] = chart
            }
        }
        if var partner = facts["partner"] as? [String: Any],
           var chart = partner["chart"] as? [String: Any]
        {
            chart.removeValue(forKey: "utcDate")
            chart.removeValue(forKey: "julianDay")
            partner["chart"] = chart
            facts["partner"] = partner
        }
        return removingTimeZoneMetadata(from: facts) as? [String: Any] ?? facts
    }

    private func removingTimeZoneMetadata(from value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                guard item.key.caseInsensitiveCompare("timezone") != .orderedSame,
                      item.key.caseInsensitiveCompare("timeZoneIdentifier") != .orderedSame
                else { return }
                result[item.key] = removingTimeZoneMetadata(from: item.value)
            }
        }
        if let array = value as? [Any] {
            return array.map { removingTimeZoneMetadata(from: $0) }
        }
        return value
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
}

// MARK: - Shared AI Report Task Lifecycle

enum AIReportTaskError: LocalizedError, Sendable, Equatable {
    case delivery(String)
    case relayFailed(String)

    var errorDescription: String? {
        switch self {
        case let .delivery(message), let .relayFailed(message):
            message
        }
    }
}

/// Shared lifecycle manager for report-style AI tasks.
///
/// Domain services (Ask / Compare) remain responsible for facts construction,
/// fingerprints, request schemas, response decoding and evidence validation.
///
/// Invariant: recovery never creates a new AI task. Only `submit` may POST to
/// /v1/generate. `recoverFirst` is reserved for an explicit user retry.
@MainActor
protocol AIReportTaskTransport {
    func createTask(
        body: Data,
        language: AppLanguage
    ) async throws -> ReportTaskState

    func status(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState

    func statusIfExists(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState?

    func fetch(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> Data
}

@MainActor
struct AIReportTaskManager {
    private let client: any AIReportTaskTransport
    private let pollIntervalNanoseconds: UInt64

    init(
        baseURL: URL? = nil,
        pollIntervalNanoseconds: UInt64 = 10_000_000_000
    ) {
        client = AIReportTaskClient(baseURL: baseURL)
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    init(
        client: any AIReportTaskTransport,
        pollIntervalNanoseconds: UInt64 = 10_000_000_000
    ) {
        self.client = client
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    func submit<Result>(
        requestID: String,
        body: Data,
        language: AppLanguage,
        recoverFirst: Bool = false,
        onGenerating: @escaping () -> Void = {},
        decode: @escaping (Data) throws -> Result
    ) async throws -> Result {
        if recoverFirst {
            do {
                if let recovered: Result = try await recover(
                    requestID: requestID,
                    language: language,
                    onGenerating: onGenerating,
                    decode: decode
                ) {
                    return recovered
                }
            } catch AIReportTaskError.relayFailed {
                // Explicit user retry only: a Relay-confirmed terminal failure
                // may be resubmitted with the same idempotency key.
            }
        }

        _ = try await client.createTask(body: body, language: language)
        return try await waitForResult(
            requestID: requestID,
            language: language,
            onGenerating: onGenerating,
            decode: decode
        )
    }

    /// Reconciles an existing task. Returns nil only when Relay has no task for
    /// requestID. This method never calls /v1/generate.
    func recover<Result>(
        requestID: String,
        language: AppLanguage,
        onGenerating: @escaping () -> Void = {},
        decode: @escaping (Data) throws -> Result
    ) async throws -> Result? {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        guard let state = try await client.statusIfExists(
            userID: userID,
            requestID: requestID,
            language: language
        ) else {
            return nil
        }

        switch state.status {
        case "completed":
            let data = try await client.fetch(
                userID: userID,
                requestID: requestID,
                language: language
            )
            return try decode(data)

        case "failed":
            throw AIReportTaskError.relayFailed(
                state.error ?? "Report generation failed."
            )

        default:
            onGenerating()
            return try await waitForResult(
                requestID: requestID,
                language: language,
                onGenerating: onGenerating,
                alreadyNotifiedGenerating: true,
                decode: decode
            )
        }
    }

    private func waitForResult<Result>(
        requestID: String,
        language: AppLanguage,
        onGenerating: @escaping () -> Void,
        alreadyNotifiedGenerating: Bool = false,
        decode: @escaping (Data) throws -> Result
    ) async throws -> Result {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        var didNotifyGenerating = alreadyNotifiedGenerating

        while !Task.isCancelled {
            let state = try await client.status(
                userID: userID,
                requestID: requestID,
                language: language
            )

            switch state.status {
            case "completed":
                let data = try await client.fetch(
                    userID: userID,
                    requestID: requestID,
                    language: language
                )
                return try decode(data)

            case "failed":
                throw AIReportTaskError.relayFailed(
                    state.error ?? "Report generation failed."
                )

            default:
                if !didNotifyGenerating {
                    didNotifyGenerating = true
                    onGenerating()
                }
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        }

        throw CancellationError()
    }
}

@MainActor
private struct AIReportTaskClient: AIReportTaskTransport {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? RelayEnvironment.baseURL
    }

    func createTask(body: Data, language: AppLanguage) async throws -> ReportTaskState {
        let response = try await postResponse(
            body,
            path: "v1/generate",
            language: language
        )
        guard (200 ..< 300).contains(response.statusCode) else {
            // A create-response error does not prove that generation failed.
            // The POST may have reached Relay and persisted a task before the
            // client lost delivery/auth state. Treat it as delivery failure;
            // an explicit /reports/status == failed is the only relayFailed.
            throw AIReportTaskError.delivery(
                serverMessage(
                    data: response.data,
                    fallback: "Report Relay HTTP \(response.statusCode)"
                )
            )
        }
        do {
            return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
        } catch {
            throw AIReportTaskError.delivery(error.localizedDescription)
        }
    }

    func status(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState {
        let body = try statusBody(userID: userID, requestID: requestID)
        let response = try await postResponse(
            body,
            path: "v1/reports/status",
            language: language
        )
        guard (200 ..< 300).contains(response.statusCode) else {
            throw AIReportTaskError.delivery(
                serverMessage(
                    data: response.data,
                    fallback: "Report status HTTP \(response.statusCode)"
                )
            )
        }
        do {
            return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
        } catch {
            throw AIReportTaskError.delivery(error.localizedDescription)
        }
    }

    func statusIfExists(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState? {
        let body = try statusBody(userID: userID, requestID: requestID)
        let response = try await postResponse(
            body,
            path: "v1/reports/status",
            language: language
        )
        if response.statusCode == 404 {
            return nil
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw AIReportTaskError.delivery(
                serverMessage(
                    data: response.data,
                    fallback: "Report status HTTP \(response.statusCode)"
                )
            )
        }
        do {
            return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
        } catch {
            throw AIReportTaskError.delivery(error.localizedDescription)
        }
    }

    func fetch(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> Data {
        let body = try statusBody(userID: userID, requestID: requestID)
        let response = try await postResponse(
            body,
            path: "v1/reports/fetch",
            language: language
        )
        guard (200 ..< 300).contains(response.statusCode) else {
            throw AIReportTaskError.delivery(
                serverMessage(
                    data: response.data,
                    fallback: "Report fetch HTTP \(response.statusCode)"
                )
            )
        }
        return response.data
    }

    private func statusBody(userID: String, requestID: String) throws -> Data {
        try JSONEncoder().encode([
            "userID": userID,
            "requestID": requestID,
        ])
    }

    private func postResponse(
        _ body: Data,
        path: String,
        language: AppLanguage
    ) async throws -> AppAttestHTTPResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            InstallationIdentity.value,
            forHTTPHeaderField: "X-Installation-ID"
        )
        request.timeoutInterval = 30
        request.httpBody = body

        do {
            return try await AppAttestAuthorizer.shared.send(
                request,
                body: body,
                baseURL: baseURL,
                language: language
            )
        } catch {
            throw AIReportTaskError.delivery(error.localizedDescription)
        }
    }

    private func serverMessage(data: Data, fallback: String) -> String {
        let json = (try? JSONSerialization.jsonObject(with: data))
            as? [String: Any]
        return (json?["error"] as? String) ?? fallback
    }
}
