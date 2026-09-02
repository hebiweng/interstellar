import AstroCore
import Foundation

struct CompareAIDelivery: Sendable {
    let requestID: String
    let semanticFingerprint: String
    let factsHash: String
    let result: CompareNarrativeResponse
}

enum CompareAIError: LocalizedError {
    case invalidEnvelope
    case fingerprintMismatch
    case delivery(String)
    case relayFailed(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEnvelope: "Compare Relay returned an invalid response."
        case .fingerprintMismatch: "Compare Relay returned facts for a different calculation."
        case let .delivery(message), let .relayFailed(message): message
        case let .failed(message): message
        }
    }
}

private struct CompareFetchEnvelope: Decodable {
    let semanticFingerprint: String
    let factsHash: String
    let result: CompareNarrativeResponse
}

private struct CompareRelayClient: Sendable {
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
            response = try await AppAttestAuthorizer.shared.send(
                request,
                body: body,
                baseURL: baseURL,
                language: language
            )
        } catch {
            throw CompareAIError.delivery(error.localizedDescription)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any]
            throw CompareAIError.failed(
                (json?["error"] as? String) ?? "Compare Relay HTTP \(response.statusCode)"
            )
        }
        return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
    }

    func status(userID: String, requestID: String, language: AppLanguage) async throws -> ReportTaskState {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        return try JSONDecoder().decode(
            ReportTaskState.self,
            from: try await post(body, path: "v1/reports/status", language: language)
        )
    }

    func statusIfExists(userID: String, requestID: String, language: AppLanguage) async throws -> ReportTaskState? {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        let response = try await postResponse(body, path: "v1/reports/status", language: language)
        if response.statusCode == 404 { return nil }
        try validate(response, fallback: "Compare Relay HTTP \(response.statusCode)")
        return try JSONDecoder().decode(ReportTaskState.self, from: response.data)
    }

    func fetch(userID: String, requestID: String, language: AppLanguage) async throws -> Data {
        let body = try JSONEncoder().encode(["userID": userID, "requestID": requestID])
        return try await post(body, path: "v1/reports/fetch", language: language)
    }

    private func post(_ body: Data, path: String, language: AppLanguage) async throws -> Data {
        let response = try await postResponse(body, path: path, language: language)
        try validate(response, fallback: "Compare Relay HTTP \(response.statusCode)")
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
            return try await AppAttestAuthorizer.shared.send(
                request,
                body: body,
                baseURL: baseURL,
                language: language
            )
        } catch {
            throw CompareAIError.delivery(error.localizedDescription)
        }
    }

    private func validate(_ response: AppAttestHTTPResponse, fallback: String) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any]
            throw CompareAIError.delivery((json?["error"] as? String) ?? fallback)
        }
    }
}

@MainActor
struct CompareAIService {
    private let client = CompareRelayClient()

    struct Identity {
        let semanticFingerprint: String
        let factsHash: String
        let factsObject: [String: Any]
        let validFactIDs: Set<String>
        let estimatedTokenCount: Int
        let outboundFactCount: Int
    }

    func identity(request: CompareRequest, bundle: CompareCalculationBundle) throws -> Identity {
        let payload = CompareAIRequest.make(request: request, bundle: bundle)
        let encoded = try JSONEncoder().encode(payload)
        guard let factsObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw CompareAIError.invalidEnvelope
        }
        let canonical = try JSONSerialization.data(withJSONObject: factsObject, options: [.sortedKeys])
        let factsHash = SHA256Digest.hash(canonical).hex
        let subjectHashes = [request.subjectA.profile, request.subjectB?.profile]
            .compactMap { $0 }
            .map { AppAIReportService().profileHash($0) }
        let raw = [
            "compare.\(request.type.rawValue)",
            request.preset.rawValue,
            subjectHashes.joined(separator: ","),
            request.focus.map(\.id).joined(separator: ","),
            request.relationshipContext?.rawValue ?? "_",
            factsHash,
        ].joined(separator: "|")
        return Identity(
            semanticFingerprint: SHA256Digest.hash(Data(raw.utf8)).hex,
            factsHash: factsHash,
            factsObject: factsObject,
            validFactIDs: payload.validFactIDs,
            estimatedTokenCount: max(1, (encoded.count + 3) / 4),
            outboundFactCount: payload.facts.all.count
        )
    }

    func recover(
        request: CompareRequest,
        bundle: CompareCalculationBundle,
        requestID: String,
        onGenerating: @MainActor @escaping () -> Void = {}
    ) async throws -> CompareAIDelivery? {
        let identity = try identity(request: request, bundle: bundle)
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        guard let state = try await client.statusIfExists(
            userID: userID,
            requestID: requestID,
            language: request.locale
        ) else { return nil }
        switch state.status {
        case "completed":
            return try await fetchResult(request: request, requestID: requestID, identity: identity)
        case "failed":
            throw CompareAIError.relayFailed(state.error ?? "Compare report generation failed")
        default:
            onGenerating()
            return try await waitForResult(
                request: request,
                bundle: bundle,
                requestID: requestID,
                identity: identity
            )
        }
    }

    func generate(
        request: CompareRequest,
        bundle: CompareCalculationBundle,
        requestID: String,
        forceRegenerate: Bool = false,
        recoverFirst: Bool = false
    ) async throws -> CompareAIDelivery {
        let identity = try identity(request: request, bundle: bundle)
        if recoverFirst {
            do {
                if let recovered = try await recover(
                    request: request,
                    bundle: bundle,
                    requestID: requestID
                ) { return recovered }
            } catch CompareAIError.relayFailed {
                // Only an explicit user retry may resubmit a Relay-confirmed failure.
            }
        }
        let body = try requestBody(
            request: request,
            requestID: requestID,
            identity: identity,
            forceRegenerate: forceRegenerate
        )
        _ = try await client.createTask(body: body, language: request.locale)
        return try await waitForResult(
            request: request,
            bundle: bundle,
            requestID: requestID,
            identity: identity
        )
    }

    private func waitForResult(
        request: CompareRequest,
        bundle: CompareCalculationBundle,
        requestID: String,
        identity: Identity
    ) async throws -> CompareAIDelivery {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        while !Task.isCancelled {
            let state = try await client.status(
                userID: userID,
                requestID: requestID,
                language: request.locale
            )
            switch state.status {
            case "completed":
                return try await fetchResult(request: request, requestID: requestID, identity: identity)
            case "failed":
                throw CompareAIError.relayFailed(state.error ?? "Compare report generation failed")
            default:
                try await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        throw CancellationError()
    }

    private func fetchResult(
        request: CompareRequest,
        requestID: String,
        identity: Identity
    ) async throws -> CompareAIDelivery {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        let data = try await client.fetch(
            userID: userID,
            requestID: requestID,
            language: request.locale
        )
        let envelope = try JSONDecoder().decode(CompareFetchEnvelope.self, from: data)
        guard envelope.semanticFingerprint == identity.semanticFingerprint,
              envelope.factsHash == identity.factsHash
        else { throw CompareAIError.fingerprintMismatch }
        let validated = try CompareNarrativeValidator.validate(
            envelope.result,
            expectedType: request.type,
            validFactIDs: identity.validFactIDs
        )
        return CompareAIDelivery(
            requestID: requestID,
            semanticFingerprint: identity.semanticFingerprint,
            factsHash: identity.factsHash,
            result: validated
        )
    }

    private func requestBody(
        request: CompareRequest,
        requestID: String,
        identity: Identity,
        forceRegenerate: Bool
    ) throws -> Data {
        let body: [String: Any] = [
            "userID": CommerceStore.shared.userID.uuidString.lowercased(),
            "requestID": requestID,
            "reportID": identity.semanticFingerprint,
            "mode": "compare",
            "compareType": request.type.rawValue,
            "reportPromptKey": "compare.\(request.type.rawValue)",
            "preset": request.preset.rawValue,
            "semanticFingerprint": identity.semanticFingerprint,
            "factsHash": identity.factsHash,
            "generationSchemaVersion": GeneratedChartArtifact.schemaVersion,
            "facts": identity.factsObject,
            "locale": request.locale.reportRequestLanguage.rawValue,
            "clientVersion": "ios-v7-compare",
            "forceRegenerate": forceRegenerate,
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}
