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

@MainActor
struct CompareAIService {
    private let taskManager = AIReportTaskManager()

    struct Identity {
        let semanticFingerprint: String
        let factsHash: String
        let factsObject: [String: Any]
        let validFactIDs: Set<String>
        let estimatedTokenCount: Int
        let outboundFactCount: Int
    }

    func identity(
        request: CompareRequest,
        bundle: CompareCalculationBundle
    ) throws -> Identity {
        let payload = CompareAIRequest.make(request: request, bundle: bundle)
        let encoded = try JSONEncoder().encode(payload)
        guard let factsObject = try JSONSerialization.jsonObject(with: encoded)
            as? [String: Any]
        else {
            throw CompareAIError.invalidEnvelope
        }

        let canonical = try JSONSerialization.data(
            withJSONObject: factsObject,
            options: [.sortedKeys]
        )
        let factsHash = SHA256Digest.hash(canonical).hex
        let subjectHashes = [
            request.subjectA.profile,
            request.subjectB?.profile,
        ]
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

    /// Recovery path. It never creates a new Relay task.
    func recover(
        request: CompareRequest,
        bundle: CompareCalculationBundle,
        requestID: String,
        onGenerating: @MainActor @escaping () -> Void = {}
    ) async throws -> CompareAIDelivery? {
        let identity = try identity(request: request, bundle: bundle)

        do {
            return try await taskManager.recover(
                requestID: requestID,
                language: request.locale,
                onGenerating: onGenerating
            ) { data in
                try decodeDelivery(
                    data: data,
                    request: request,
                    requestID: requestID,
                    identity: identity
                )
            }
        } catch AIReportTaskError.delivery(let message) {
            throw CompareAIError.delivery(message)
        } catch AIReportTaskError.relayFailed(let message) {
            throw CompareAIError.relayFailed(message)
        }
    }

    /// The only path that may create a new Relay task.
    ///
    /// `recoverFirst` is used only by an explicit user retry. Automatic
    /// reconciliation calls `recover` directly and therefore cannot POST a
    /// second AI request.
    func generate(
        request: CompareRequest,
        bundle: CompareCalculationBundle,
        requestID: String,
        forceRegenerate: Bool = false,
        recoverFirst: Bool = false
    ) async throws -> CompareAIDelivery {
        let identity = try identity(request: request, bundle: bundle)
        let body = try requestBody(
            request: request,
            requestID: requestID,
            identity: identity,
            forceRegenerate: forceRegenerate
        )

        do {
            return try await taskManager.submit(
                requestID: requestID,
                body: body,
                language: request.locale,
                recoverFirst: recoverFirst
            ) { data in
                try decodeDelivery(
                    data: data,
                    request: request,
                    requestID: requestID,
                    identity: identity
                )
            }
        } catch AIReportTaskError.delivery(let message) {
            throw CompareAIError.delivery(message)
        } catch AIReportTaskError.relayFailed(let message) {
            throw CompareAIError.relayFailed(message)
        }
    }

    private func decodeDelivery(
        data: Data,
        request: CompareRequest,
        requestID: String,
        identity: Identity
    ) throws -> CompareAIDelivery {
        let envelope = try JSONDecoder().decode(
            CompareFetchEnvelope.self,
            from: data
        )

        guard envelope.semanticFingerprint == identity.semanticFingerprint,
              envelope.factsHash == identity.factsHash
        else {
            throw CompareAIError.fingerprintMismatch
        }

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
            "clientVersion": "ios-v8-shared-ai-manager",
            "forceRegenerate": forceRegenerate,
        ]

        return try JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )
    }
}
