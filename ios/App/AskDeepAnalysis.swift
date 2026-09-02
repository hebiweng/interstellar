import AstroCore
import Foundation
import SwiftUI

struct AskDeepFact: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let category: String
    let values: [String: String]

    init(identity: DeterministicFactIdentity, category: String, values: [String: String]) {
        id = identity.key
        self.category = category
        self.values = values
    }
}

/// Privacy-minimized payload for the paid Ask synthesis. It deliberately contains
/// no ChartSnapshot, profile, coordinates, timezone or rendered chart data.
struct AskDeepAIRequest: Codable, Equatable, Sendable {
    let questionType: String
    let question: String
    let facts: [AskDeepFact]
    let locale: String
}

struct AskDeepNarrativeSection: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let evidenceFactIDs: [String]
}

struct AskDeepNarrativeResponse: Codable, Equatable, Sendable {
    let summary: String
    let summaryEvidenceFactIDs: [String]
    let sections: [AskDeepNarrativeSection]
}

enum AskDeepValidationError: LocalizedError, Equatable {
    case missingValidEvidence

    var errorDescription: String? {
        "Deep Analysis returned no valid local chart evidence."
    }
}

enum AskDeepNarrativeValidator {
    static func validate(
        _ response: AskDeepNarrativeResponse,
        validFactIDs: Set<String>
    ) throws -> AskDeepNarrativeResponse {
        let summaryEvidence = response.summaryEvidenceFactIDs.filter(validFactIDs.contains)
        guard !summaryEvidence.isEmpty else { throw AskDeepValidationError.missingValidEvidence }

        let sections = response.sections.compactMap { section -> AskDeepNarrativeSection? in
            let evidence = section.evidenceFactIDs.filter(validFactIDs.contains)
            guard !evidence.isEmpty else { return nil }
            return AskDeepNarrativeSection(
                id: section.id,
                title: section.title,
                body: section.body,
                evidenceFactIDs: evidence
            )
        }
        guard !sections.isEmpty else { throw AskDeepValidationError.missingValidEvidence }
        return AskDeepNarrativeResponse(
            summary: response.summary,
            summaryEvidenceFactIDs: summaryEvidence,
            sections: sections
        )
    }
}

struct AskDeepFactBuilder {
    func build(session: HorarySession) -> [AskDeepFact] {
        var facts: [AskDeepFact] = []

        if let analysis = session.analysis {
            facts += analysisFacts(analysis, scope: "primary")
        }

        for (index, choice) in session.choices.enumerated() {
            let scope = "choice_\(index)"
            facts.append(fact(
                factType: "choice_ranking",
                source: scope,
                values: [
                    "label": choice.label,
                    "house": String(choice.house),
                    "related_houses": choice.relatedHouses.map(String.init).joined(separator: ","),
                    "ruler": choice.ruler.id,
                    "rank": String(index + 1),
                    "verdict": choice.analysis.judgment?.verdict.rawValue ?? "",
                    "original_index": String(choice.originalIndex),
                    "tied_for_lead": String(choice.isTiedForLead),
                ]
            ))
            facts += analysisFacts(choice.analysis, scope: scope)
        }

        if let timing = session.timingResult {
            var values = [
                "status": timing.status.rawValue,
                "symbolic_units": timing.symbolicUnits.map(formatted) ?? "",
                "timing_scales": timing.scales.map(\.rawValue).joined(separator: ","),
                "mixed_testimony": String(timing.isMixed),
                "applying_body": timing.applyingBody?.id ?? "",
                "receiving_body": timing.receivingBody?.id ?? "",
            ]
            if let exact = timing.exactPerfectionDate {
                values["exact_perfection_date"] = iso(exact)
            }
            facts.append(fact(
                factType: "horary_timing",
                source: "primary",
                values: values
            ))
            for testimony in timing.testimonies {
                facts.append(fact(
                    factType: "horary_timing_testimony",
                    source: testimony.role.rawValue,
                    target: testimony.body.id,
                    values: [
                        "body": testimony.body.id,
                        "scale": testimony.scale.rawValue,
                        "sign_quality": testimony.signQuality?.rawValue ?? "",
                        "house_quality": testimony.houseQuality?.rawValue ?? "",
                    ]
                ))
            }
        } else if session.mode == .bestTime {
            for (index, candidate) in session.electionCandidates.prefix(5).enumerated() {
                let scope = "election_\(index)"
                facts.append(fact(
                    factType: "election_candidate",
                    source: scope,
                    values: [
                        "rank": String(index + 1),
                        "interval_start": iso(candidate.interval.start),
                        "interval_end": iso(candidate.interval.end),
                        "peak_date": iso(candidate.peakDate),
                        "suitability_score": formatted(candidate.assessment.suitabilityScore),
                        "target_house": candidate.assessment.targetHouse.map(String.init) ?? "",
                        "target_ruler": candidate.assessment.targetRuler?.id ?? "",
                        "moon_void_of_course": candidate.assessment.moonIsVoidOfCourse.map(String.init) ?? "",
                    ]
                ))
                for factor in candidate.assessment.factors {
                    var values = factor.values
                    values["contribution"] = formatted(factor.contribution)
                    facts.append(fact(
                        factType: "election_factor",
                        source: scope,
                        target: factor.id,
                        values: values
                    ))
                }
            }
        } else {
            // Schema v1/v2 history used election-style candidates for the old When flow.
            // They remain readable but are never created by new When sessions.
            for (index, candidate) in session.timingCandidates.prefix(5).enumerated() {
                let scope = "legacy_timing_\(index)"
                facts.append(fact(
                    factType: "legacy_timing_candidate",
                    source: scope,
                    values: [
                        "rank": String(index + 1),
                        "interval_start": iso(candidate.interval.start),
                        "interval_end": iso(candidate.interval.end),
                        "peak_date": iso(candidate.peakDate),
                    ]
                ))
                if let legacy = candidate.legacyHoraryAnalysis {
                    facts += analysisFacts(legacy, scope: scope)
                }
            }
        }

        for (index, significator) in session.significators.enumerated() {
            let scope = "significator_\(index)"
            facts.append(fact(
                factType: "named_significator",
                source: scope,
                target: significator.ruler.id,
                values: [
                    "label": significator.label,
                    "house": String(significator.house),
                    "ruler": significator.ruler.id,
                    "ruler_house": String(significator.planet.house),
                    "ruler_sign_index": String(significator.planet.signIndex),
                    "conditions": significator.planet.conditions.map(\.rawValue).sorted().joined(separator: ","),
                    "relationship": significator.relationship?.kind.rawValue ?? "none",
                    "relationship_phase": significator.relationship?.phase.rawValue ?? "none",
                    "relationship_orb": significator.relationship.map { formatted($0.orbDegrees) } ?? "",
                ]
            ))
        }

        return deduplicated(facts)
    }

    private func analysisFacts(_ analysis: HoraryAnalysis, scope: String) -> [AskDeepFact] {
        var facts: [AskDeepFact] = []
        facts.append(planetFact(role: "querent", assessment: analysis.querent, scope: scope))
        facts.append(planetFact(role: "target", assessment: analysis.target, scope: scope))

        if let relationship = analysis.relationship {
            facts.append(aspectFact(relationship, factType: "significator_relationship", source: "\(scope)_querent", target: "\(scope)_target"))
        }

        facts.append(receptionFact(analysis.receptionFromQuerent, role: "querent_to_target", scope: scope))
        facts.append(receptionFact(analysis.receptionFromTarget, role: "target_to_querent", scope: scope))
        if let querentFortitude = analysis.querentFortitude {
            facts += fortitudeFacts(querentFortitude, role: "querent", scope: scope)
        }
        if let targetFortitude = analysis.targetFortitude {
            facts += fortitudeFacts(targetFortitude, role: "target", scope: scope)
        }

        facts.append(fact(
            factType: "moon_condition",
            source: scope,
            target: "moon",
            values: [
                "void_of_course": String(analysis.moon.isVoidOfCourse),
                "via_combusta": String(analysis.moon.isViaCombusta),
                "hours_until_sign_exit": analysis.moon.hoursUntilSignExit.map(formatted) ?? "",
            ]
        ))
        if let previous = analysis.moon.previousAspect {
            facts.append(fact(
                factType: "moon_previous_aspect",
                source: scope,
                target: previous.aspect.secondID,
                relation: previous.aspect.kind.rawValue,
                values: [
                    "body": previous.aspect.secondID,
                    "aspect": previous.aspect.kind.rawValue,
                    "hours_from_question": formatted(previous.hoursFromQuestion),
                ]
            ))
        }
        for (index, event) in analysis.moon.upcomingAspects.prefix(3).enumerated() {
            facts.append(fact(
                factType: "moon_upcoming_aspect",
                source: "\(scope).sequence_\(index + 1)",
                target: event.aspect.secondID,
                relation: event.aspect.kind.rawValue,
                values: [
                    "body": event.aspect.secondID,
                    "aspect": event.aspect.kind.rawValue,
                    "hours_from_question": formatted(event.hoursFromQuestion),
                ]
            ))
        }
        if let nextAspect = analysis.moon.nextAspect {
            var values = aspectValues(nextAspect)
            if let hours = analysis.moon.hoursUntilNextAspect {
                values["hours_until_next_aspect"] = formatted(hours)
            }
            facts.append(fact(
                factType: "moon_next_aspect",
                source: scope,
                target: nextAspect.secondID,
                relation: nextAspect.kind.rawValue,
                values: values
            ))
        }

        if let judgment = analysis.judgment {
            facts.append(fact(
                factType: "judgment",
                source: scope,
                values: ["verdict": judgment.verdict.rawValue]
            ))
            facts += perfectionFacts(judgment.perfection, scope: scope)
            if let considerations = judgment.considerations {
                facts.append(fact(
                    factType: "judgment_reliability",
                    source: scope,
                    values: ["reliability": considerations.reliability.rawValue]
                ))
                if let radicality = considerations.radicality {
                    facts.append(fact(
                        factType: "radicality",
                        source: scope,
                        values: [
                            "status": radicality.status.rawValue,
                            "agreement": radicality.agreement.rawValue,
                        ]
                    ))
                }
                if let planetaryHour = considerations.planetaryHour {
                    var values: [String: String] = [
                        "availability": planetaryHour.availability.rawValue,
                        "agreement": planetaryHour.agreement.rawValue,
                    ]
                    if let dayRuler = planetaryHour.dayRuler { values["day_ruler"] = dayRuler.rawValue }
                    if let hourRuler = planetaryHour.hourRuler { values["hour_ruler"] = hourRuler.rawValue }
                    if let hourNumber = planetaryHour.hourNumber { values["hour_number"] = String(hourNumber) }
                    if let isDayHour = planetaryHour.isDayHour { values["is_day_hour"] = String(isDayHour) }
                    facts.append(fact(
                        factType: "planetary_hour",
                        source: scope,
                        values: values
                    ))
                }
                for flag in considerations.flags {
                    var values = flag.values ?? [:]
                    values["kind"] = flag.kind.rawValue
                    values["severity"] = flag.severity.rawValue
                    facts.append(fact(
                        factType: "consideration",
                        source: scope,
                        target: flag.kind.rawValue,
                        values: values
                    ))
                }
            }
        }
        return facts
    }

    private func fortitudeFacts(
        _ assessment: HoraryFortitudeAssessment,
        role: String,
        scope: String
    ) -> [AskDeepFact] {
        var result: [AskDeepFact] = [
            fact(
                factType: "lilly_fortitude_total",
                source: "\(scope).\(role)",
                target: assessment.body.id,
                values: [
                    "body": assessment.body.id,
                    "role": role,
                    "total": String(assessment.total),
                ]
            )
        ]
        for factor in assessment.factors {
            var values = factor.values
            values["body"] = assessment.body.id
            values["role"] = role
            values["rule"] = factor.rule.rawValue
            values["points"] = String(factor.points)
            values["category"] = factor.rule.category.rawValue
            result.append(fact(
                factType: "lilly_fortitude_factor",
                source: "\(scope).\(role)",
                target: factor.rule.rawValue,
                values: values
            ))
        }
        return result
    }

    private func planetFact(role: String, assessment: HoraryPlanetAssessment, scope: String) -> AskDeepFact {
        fact(
            factType: "significator_condition",
            source: "\(scope)_\(role)",
            target: assessment.body.id,
            values: [
                "role": role,
                "body": assessment.body.id,
                "house": String(assessment.house),
                "sign_index": String(assessment.signIndex),
                "conditions": assessment.conditions.map(\.rawValue).sorted().joined(separator: ","),
            ]
        )
    }

    private func receptionFact(_ reception: HoraryReception, role: String, scope: String) -> AskDeepFact {
        fact(
            factType: "reception",
            source: "\(scope)_\(role)",
            target: reception.to.id,
            relation: reception.from.id,
            values: [
                "from": reception.from.id,
                "to": reception.to.id,
                "by_domicile": String(reception.byDomicile),
                "by_exaltation": String(reception.byExaltation),
                "dignities": reception.dignities.map(\.rawValue).joined(separator: ","),
                "strength": String(reception.strength),
                "mutual": String(reception.isMutual),
                "present": String(reception.isPresent),
            ]
        )
    }

    private func perfectionFacts(_ perfection: HoraryPerfectionAssessment, scope: String) -> [AskDeepFact] {
        var facts: [AskDeepFact] = [fact(
            factType: "perfection",
            source: scope,
            values: ["status": perfection.status.rawValue]
        )]
        if let path = perfection.primaryPath {
            facts.append(fact(
                factType: "perfection_path",
                source: scope,
                target: path.mediator?.id,
                relation: path.kind.rawValue,
                values: [
                    "kind": path.kind.rawValue,
                    "exact_date": iso(path.exactDate),
                    "aspect": path.aspectKind.rawValue,
                    "distance_degrees": formatted(path.distanceDegrees),
                    "mediator": path.mediator?.id ?? "",
                ]
            ))
        }
        for (index, interruption) in perfection.interruptions.enumerated() {
            facts.append(fact(
                factType: "perfection_interruption",
                source: scope,
                target: "interruption_\(index)_\(interruption.body.id)",
                relation: interruption.kind.rawValue,
                values: [
                    "kind": interruption.kind.rawValue,
                    "date": iso(interruption.date),
                    "body": interruption.body.id,
                ]
            ))
        }
        return facts
    }

    private func aspectFact(
        _ aspect: ChartAspect,
        factType: String,
        source: String,
        target: String
    ) -> AskDeepFact {
        fact(
            factType: factType,
            source: source,
            target: target,
            relation: aspect.kind.rawValue,
            values: aspectValues(aspect)
        )
    }

    private func aspectValues(_ aspect: ChartAspect) -> [String: String] {
        [
            "first": aspect.firstID,
            "second": aspect.secondID,
            "aspect": aspect.kind.rawValue,
            "orb": formatted(aspect.orbDegrees),
            "phase": aspect.phase.rawValue,
            "strength": formatted(aspect.strength),
        ]
    }

    private func fact(
        factType: String,
        source: String,
        target: String? = nil,
        relation: String? = nil,
        values: [String: String]
    ) -> AskDeepFact {
        AskDeepFact(
            identity: DeterministicFactIdentity(
                technique: "horary",
                factType: factType,
                sourceObject: source,
                targetObject: target,
                relation: relation,
                referenceChart: "question_chart"
            ),
            category: factType,
            values: values
        )
    }

    private func deduplicated(_ facts: [AskDeepFact]) -> [AskDeepFact] {
        var seen = Set<String>()
        return facts.filter { seen.insert($0.id).inserted }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private struct AskDeepFetchEnvelope: Decodable {
    let semanticFingerprint: String
    let factsHash: String
    let result: AskDeepNarrativeResponse
}

private struct AskDeepRelayClient: Sendable {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? RelayEnvironment.baseURL
    }

    func createTask(body: Data, language: AppLanguage) async throws -> ReportTaskState {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        request.timeoutInterval = 30
        request.httpBody = body
        let response: AppAttestHTTPResponse
        do {
            response = try await AppAttestAuthorizer.shared.send(request, body: body, baseURL: baseURL, language: language)
        } catch {
            throw AskDeepAIError.delivery(error.localizedDescription)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any]
            throw AskDeepAIError.failed((json?["error"] as? String) ?? "Ask Deep Analysis HTTP \(response.statusCode)")
        }
        return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
    }

    func status(userID: String, requestID: String, language: AppLanguage) async throws -> ReportTaskState {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        return try JSONDecoder().decode(ReportTaskState.self, from: try await post(body, path: "v1/reports/status", language: language))
    }

    func statusIfExists(userID: String, requestID: String, language: AppLanguage) async throws -> ReportTaskState? {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        let response = try await postResponse(body, path: "v1/reports/status", language: language)
        if response.statusCode == 404 { return nil }
        try validate(response, fallback: "Ask Deep Analysis HTTP \(response.statusCode)")
        return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
    }

    func fetch(userID: String, requestID: String, language: AppLanguage) async throws -> Data {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        return try await post(body, path: "v1/reports/fetch", language: language)
    }

    private func post(_ body: Data, path: String, language: AppLanguage) async throws -> Data {
        let response = try await postResponse(body, path: path, language: language)
        try validate(response, fallback: "Ask Deep Analysis HTTP \(response.statusCode)")
        return response.data
    }

    private func postResponse(_ body: Data, path: String, language: AppLanguage) async throws -> AppAttestHTTPResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        request.timeoutInterval = 30
        request.httpBody = body
        do {
            return try await AppAttestAuthorizer.shared.send(request, body: body, baseURL: baseURL, language: language)
        } catch {
            throw AskDeepAIError.delivery(error.localizedDescription)
        }
    }

    private func validate(_ response: AppAttestHTTPResponse, fallback: String) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any]
            throw AskDeepAIError.delivery((json?["error"] as? String) ?? fallback)
        }
    }
}

enum AskDeepAIError: LocalizedError {
    case invalidEnvelope
    case fingerprintMismatch
    case delivery(String)
    case relayFailed(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEnvelope: "Deep Analysis returned an invalid response."
        case .fingerprintMismatch: "Deep Analysis returned facts for a different question calculation."
        case let .delivery(message), let .relayFailed(message), let .failed(message): message
        }
    }
}

@MainActor
struct AskDeepAIService {
    struct Prepared {
        let request: AskDeepAIRequest
        let semanticFingerprint: String
        let factsHash: String
        let factsObject: [String: Any]
        let validFactIDs: Set<String>
    }

    private let client = AskDeepRelayClient()
    private let builder = AskDeepFactBuilder()

    func prepare(session: HorarySession, language: AppLanguage) throws -> Prepared {
        let facts = builder.build(session: session)
        let request = AskDeepAIRequest(
            questionType: session.mode.rawValue,
            question: session.question,
            facts: facts,
            locale: language.reportRequestLanguage.rawValue
        )
        let encoded = try JSONEncoder().encode(request)
        guard let factsObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw AskDeepAIError.invalidEnvelope
        }
        let canonical = try JSONSerialization.data(withJSONObject: factsObject, options: [.sortedKeys])
        let factsHash = SHA256Digest.hash(canonical).hex
        let fingerprintSeed = "ask_deep|\(session.mode.rawValue)|\(factsHash)"
        return Prepared(
            request: request,
            semanticFingerprint: SHA256Digest.hash(Data(fingerprintSeed.utf8)).hex,
            factsHash: factsHash,
            factsObject: factsObject,
            validFactIDs: Set(facts.map(\.id))
        )
    }

    func sessionFingerprint(_ session: HorarySession) -> String {
        let createdAt = String(format: "%.3f", session.createdAt.timeIntervalSince1970)
        let symbolicUnits = session.timingResult?.symbolicUnits
            .map { String(format: "%.6f", $0) } ?? ""
        let timingScales = session.timingResult?.scales
            .map(\.rawValue).joined(separator: ",") ?? ""
        let candidateCount = String(session.timingCandidates.count + session.electionCandidates.count)
        let raw = [
            session.mode.rawValue,
            createdAt,
            session.question,
            String(session.choices.count),
            session.timingResult?.status.rawValue ?? "legacy",
            symbolicUnits,
            timingScales,
            candidateCount,
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    func recover(
        session: HorarySession,
        language: AppLanguage,
        requestID: String,
        onGenerating: @MainActor @escaping () -> Void = {}
    ) async throws -> AskDeepNarrativeResponse? {
        let prepared = try prepare(session: session, language: language)
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        guard let state = try await client.statusIfExists(
            userID: userID,
            requestID: requestID,
            language: language
        ) else { return nil }
        switch state.status {
        case "completed":
            return try await fetchResult(prepared: prepared, requestID: requestID, language: language)
        case "failed":
            throw AskDeepAIError.relayFailed(state.error ?? "Deep Analysis generation failed")
        default:
            onGenerating()
            return try await waitForResult(prepared: prepared, requestID: requestID, language: language)
        }
    }

    func generate(
        session: HorarySession,
        language: AppLanguage,
        requestID: String,
        forceRegenerate: Bool = false,
        recoverFirst: Bool = false
    ) async throws -> AskDeepNarrativeResponse {
        let prepared = try prepare(session: session, language: language)
        if recoverFirst {
            do {
                if let recovered = try await recover(
                    session: session,
                    language: language,
                    requestID: requestID
                ) { return recovered }
            } catch AskDeepAIError.relayFailed {
                // Only an explicit user retry may resubmit a Relay-confirmed failure.
            }
        }
        let body = try requestBody(prepared: prepared, requestID: requestID, forceRegenerate: forceRegenerate)
        _ = try await client.createTask(body: body, language: language)
        return try await waitForResult(prepared: prepared, requestID: requestID, language: language)
    }

    private func waitForResult(
        prepared: Prepared,
        requestID: String,
        language: AppLanguage
    ) async throws -> AskDeepNarrativeResponse {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        while !Task.isCancelled {
            let state = try await client.status(userID: userID, requestID: requestID, language: language)
            switch state.status {
            case "completed":
                return try await fetchResult(prepared: prepared, requestID: requestID, language: language)
            case "failed":
                throw AskDeepAIError.relayFailed(state.error ?? "Deep Analysis generation failed")
            default:
                try await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        throw CancellationError()
    }

    private func fetchResult(
        prepared: Prepared,
        requestID: String,
        language: AppLanguage
    ) async throws -> AskDeepNarrativeResponse {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        let data = try await client.fetch(userID: userID, requestID: requestID, language: language)
        let envelope = try JSONDecoder().decode(AskDeepFetchEnvelope.self, from: data)
        guard envelope.semanticFingerprint == prepared.semanticFingerprint,
              envelope.factsHash == prepared.factsHash
        else { throw AskDeepAIError.fingerprintMismatch }
        return try AskDeepNarrativeValidator.validate(
            envelope.result,
            validFactIDs: prepared.validFactIDs
        )
    }

    private func requestBody(
        prepared: Prepared,
        requestID: String,
        forceRegenerate: Bool
    ) throws -> Data {
        let body: [String: Any] = [
            "userID": CommerceStore.shared.userID.uuidString.lowercased(),
            "requestID": requestID,
            "reportID": prepared.semanticFingerprint,
            "mode": "ask_deep",
            "reportPromptKey": "ask.deep_analysis",
            "semanticFingerprint": prepared.semanticFingerprint,
            "factsHash": prepared.factsHash,
            "generationSchemaVersion": GeneratedChartArtifact.schemaVersion,
            "facts": prepared.factsObject,
            "locale": prepared.request.locale,
            "clientVersion": "ios-v7-ask-deep",
            "forceRegenerate": forceRegenerate,
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}

enum AskDeepRecordStatus: String, Codable {
    case pending
    case completed
    case deliveryFailed = "delivery_failed"
    case failed
    case relayFailed = "relay_failed"
}

struct AskDeepRecord: Codable, Identifiable {
    let id: String
    let sessionFingerprint: String
    let createdAt: Date
    var status: AskDeepRecordStatus
    var result: AskDeepNarrativeResponse?
    var error: String?
    var session: HorarySession? = nil
    var language: AppLanguage? = nil
}

@MainActor
final class AskDeepAnalysisStore: ObservableObject {
    static let shared = AskDeepAnalysisStore()
    @Published private(set) var records: [AskDeepRecord] = []
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.url = base.appendingPathComponent("AskDeepAnalysis.json")
        records = Self.load(from: self.url)
    }

    func record(sessionFingerprint: String) -> AskDeepRecord? {
        records.first { $0.sessionFingerprint == sessionFingerprint }
    }

    @discardableResult
    func upsert(_ record: AskDeepRecord) -> Bool {
        records.removeAll { $0.id == record.id || $0.sessionFingerprint == record.sessionFingerprint }
        records.append(record)
        records.sort { $0.createdAt > $1.createdAt }
        records = Array(records.prefix(100))
        guard let data = try? JSONEncoder().encode(records) else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    private static func load(from url: URL) -> [AskDeepRecord] {
        guard let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([AskDeepRecord].self, from: data)
        else { return [] }
        return records
    }
}

@MainActor
final class AskDeepAnalysisManager: ObservableObject {
    static let shared = AskDeepAnalysisManager()
    private let service = AskDeepAIService()
    private let store = AskDeepAnalysisStore.shared
    private var tasks: [String: Task<Void, Never>] = [:]

    func begin(session: HorarySession, language: AppLanguage) {
        let fingerprint = service.sessionFingerprint(session)
        let existing = store.record(sessionFingerprint: fingerprint)
        let isRetry = existing?.status == .failed
            || existing?.status == .deliveryFailed
            || existing?.status == .relayFailed
        var record = existing ?? AskDeepRecord(
            id: UUID().uuidString.lowercased(), sessionFingerprint: fingerprint,
            createdAt: Date(), status: .pending, result: nil, error: nil
        )
        if let recovery = tasks[record.id] {
            Task { [weak self] in
                await recovery.value
                self?.begin(session: session, language: language)
            }
            return
        }
        guard record.result == nil else { return }
        record.status = .pending
        record.error = nil
        record.session = session
        record.language = language
        guard store.upsert(record) else { return }
        let requestID = record.id
        tasks[requestID] = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks[requestID] = nil }
            do {
                let result = try await self.service.generate(
                    session: session,
                    language: language,
                    requestID: requestID,
                    recoverFirst: isRetry
                )
                guard var completed = self.store.record(sessionFingerprint: fingerprint) else { return }
                completed.status = .completed
                completed.result = result
                completed.error = nil
                guard self.store.upsert(completed) else { return }
                await CommerceStore.shared.acknowledgeReport(requestID: requestID)
            } catch is CancellationError {
                guard var pending = self.store.record(sessionFingerprint: fingerprint) else { return }
                pending.status = .deliveryFailed
                pending.error = "Deep Analysis retrieval was interrupted."
                _ = self.store.upsert(pending)
            } catch AskDeepAIError.delivery(let message) {
                guard var pending = self.store.record(sessionFingerprint: fingerprint) else { return }
                pending.status = .deliveryFailed
                pending.error = message
                _ = self.store.upsert(pending)
            } catch AskDeepAIError.relayFailed(let message) {
                guard var failed = self.store.record(sessionFingerprint: fingerprint) else { return }
                failed.status = .relayFailed
                failed.error = message
                _ = self.store.upsert(failed)
            } catch {
                guard var failed = self.store.record(sessionFingerprint: fingerprint) else { return }
                failed.status = .relayFailed
                failed.error = error.localizedDescription
                _ = self.store.upsert(failed)
            }
        }
    }

    func reconcilePendingReports() {
        let recentLegacyIDs = Set(store.records.prefix(10).map(\.id))
        for record in store.records where record.result == nil {
            guard let session = record.session, let language = record.language else { continue }
            switch record.status {
            case .pending, .deliveryFailed:
                startRecovery(record: record, session: session, language: language)
            case .failed where recentLegacyIDs.contains(record.id):
                startRecovery(record: record, session: session, language: language)
            case .completed, .relayFailed:
                break
            case .failed:
                break
            }
        }
    }

    func reconcile(session: HorarySession, language: AppLanguage) {
        let fingerprint = service.sessionFingerprint(session)
        guard var record = store.record(sessionFingerprint: fingerprint), record.result == nil else { return }
        record.session = session
        record.language = language
        _ = store.upsert(record)
        switch record.status {
        case .pending, .deliveryFailed, .failed:
            startRecovery(record: record, session: session, language: language)
        case .completed, .relayFailed:
            break
        }
    }

    private func startRecovery(record: AskDeepRecord, session: HorarySession, language: AppLanguage) {
        guard tasks[record.id] == nil else { return }
        let fingerprint = record.sessionFingerprint
        tasks[record.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks[record.id] = nil }
            do {
                let result = try await self.service.recover(
                    session: session,
                    language: language,
                    requestID: record.id,
                    onGenerating: { [weak self] in
                        guard let self, var running = self.store.record(sessionFingerprint: fingerprint) else { return }
                        running.status = .pending
                        running.error = nil
                        _ = self.store.upsert(running)
                    }
                )
                guard let result else {
                    guard var missing = self.store.record(sessionFingerprint: fingerprint) else { return }
                    missing.status = .relayFailed
                    missing.error = "The Relay has no Deep Analysis for this request."
                    _ = self.store.upsert(missing)
                    return
                }
                guard var completed = self.store.record(sessionFingerprint: fingerprint) else { return }
                completed.status = .completed
                completed.result = result
                completed.error = nil
                guard self.store.upsert(completed) else { return }
                await CommerceStore.shared.acknowledgeReport(requestID: record.id)
            } catch AskDeepAIError.relayFailed(let message) {
                guard var failed = self.store.record(sessionFingerprint: fingerprint) else { return }
                failed.status = .relayFailed
                failed.error = message
                _ = self.store.upsert(failed)
            } catch {
                guard var pending = self.store.record(sessionFingerprint: fingerprint) else { return }
                pending.status = .deliveryFailed
                pending.error = error.localizedDescription
                _ = self.store.upsert(pending)
            }
        }
    }
}

struct AskDeepAnalysisSection: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared
    let session: HorarySession

    @ObservedObject private var store = AskDeepAnalysisStore.shared
    @ObservedObject private var manager = AskDeepAnalysisManager.shared
    @State private var showsAIConsentReminder = false
    @State private var errorMessage: String?

    private let service = AskDeepAIService()
    private var record: AskDeepRecord? { store.record(sessionFingerprint: sessionKey) }
    private var isWorking: Bool { record?.status == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = record?.result {
                resultView(result)
            } else {
                Text(localized("ask.deep-analysis-title", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(localized("ask.deep-analysis-subtitle", language: model.language))
                    .font(AppTypography.summary)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if errorMessage != nil
                    || record?.status == .failed
                    || record?.status == .deliveryFailed
                    || record?.status == .relayFailed {
                    Label(localized("ask.deep-analysis-failed", language: model.language), systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.coral)
                }

                Button {
                    requestAnalysis()
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text(localized(
                            isWorking ? "ask.deep-analysis-running" : "ask.deep-analysis-credit",
                            language: model.language
                        ))
                            .font(.headline)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                Text(localized("ask.deep-analysis-privacy", language: model.language))
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
        .alert(
            localized("ai.network-consent.title", language: model.language),
            isPresented: $showsAIConsentReminder
        ) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                manager.begin(session: session, language: model.language)
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {}
        } message: {
            Text(localized("ask.deep-analysis-consent", language: model.language))
        }
        .task { manager.reconcile(session: session, language: model.language) }
    }

    private var sessionKey: String {
        service.sessionFingerprint(session)
    }

    @ViewBuilder
    private func resultView(_ result: AskDeepNarrativeResponse) -> some View {
        Text(localized("ask.deep-analysis-title", language: model.language))
            .font(.headline)
            .foregroundStyle(AppTheme.text)
        Text(result.summary)
            .font(AppTypography.summary)
            .foregroundStyle(AppTheme.text)
            .fixedSize(horizontal: false, vertical: true)
        evidenceLabel(count: result.summaryEvidenceFactIDs.count)

        ForEach(result.sections) { section in
            Divider().overlay(AppTheme.line)
            Text(section.title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Text(section.body)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            evidenceLabel(count: section.evidenceFactIDs.count)
        }
    }

    private func evidenceLabel(count: Int) -> some View {
        Text(localizedTemplate(
            "ask.deep-analysis-evidence",
            substitutions: ["value": String(count)],
            language: model.language
        ))
        .font(AppTypography.supporting)
        .foregroundStyle(AppTheme.violet)
    }

    private func requestAnalysis() {
        errorMessage = nil
        Task {
            await commerce.refreshAccountIfStale()
            guard commerce.totalCredits >= 1 else {
                commerce.showsCredits = true
                return
            }
            guard model.aiConsentGranted else {
                showsAIConsentReminder = true
                return
            }
            manager.begin(session: session, language: model.language)
        }
    }
}
