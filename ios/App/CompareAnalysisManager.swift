import AstroCore
import Combine
import Foundation

@MainActor
final class CompareAnalysisManager: ObservableObject {
    static let shared = CompareAnalysisManager()

    private let coordinator = CompareCalculationCoordinator()
    private let reportService = CompareAIService()
    let store: CompareAnalysisStore
    private var reportTasks: [String: Task<Void, Never>] = [:]

    @Published private(set) var activeAnalysisID: String?
    @Published private(set) var isWorking = false
    @Published private(set) var stage: CompareAnalysisStage?

    init(store: CompareAnalysisStore = .shared) {
        self.store = store
    }

    func startLocal(request: CompareRequest, model: AppModel) async throws -> CompareAnalysis {
        isWorking = true
        stage = .calculatingCharts
        defer {
            isWorking = false
            stage = nil
        }

        let validated = try request.validated()
        let calculator = try model.themeCalculator()
        let bundle = try await coordinator.calculate(
            request: validated,
            calculator: calculator,
            onStage: { [weak self] next in self?.stage = next }
        )
        stage = .preparingAnalysis
        let identity = try reportService.identity(request: validated, bundle: bundle)
        let localAnalysis = CompareAnalysis(
            id: UUID().uuidString.lowercased(),
            createdAt: Date(),
            request: validated,
            bundle: bundle,
            status: .chartsReady,
            result: nil,
            generationError: nil,
            semanticFingerprint: identity.semanticFingerprint,
            factsHash: identity.factsHash
        )
        guard store.upsert(localAnalysis) else {
            throw CompareAIError.failed("Unable to persist the local comparison.")
        }
        activeAnalysisID = localAnalysis.id
        return localAnalysis
    }

    @discardableResult
    func generateReport(
        analysisID: String,
        model: AppModel,
        recoverFirst: Bool = false
    ) async throws -> CompareAnalysis {
        guard var current = store.analysis(id: analysisID) else {
            throw CompareAIError.failed("Comparison not found.")
        }
        if let result = current.result, current.status == .completed {
            _ = result
            return current
        }

        guard model.aiConsentGranted else {
            current.status = .chartsReady
            current.generationError = nil
            store.upsert(current)
            return current
        }
        guard model.isOnline else {
            current.status = .chartsReady
            current.generationError = nil
            store.upsert(current)
            return current
        }

        current.status = .generatingReport
        current.generationError = nil
        store.upsert(current)
        activeAnalysisID = current.id
        isWorking = true
        stage = .preparingAnalysis
        defer {
            isWorking = false
            stage = nil
        }

        do {
            let delivery = try await reportService.generate(
                request: current.request,
                bundle: current.bundle,
                requestID: current.id,
                recoverFirst: recoverFirst
            )
            guard delivery.semanticFingerprint == current.semanticFingerprint,
                  delivery.factsHash == current.factsHash
            else { throw CompareAIError.fingerprintMismatch }
            current.result = delivery.result
            current.status = .completed
            current.generationError = nil
            guard store.upsert(current) else {
                throw CompareAIError.failed("Unable to persist the comparison result.")
            }
            // Relay may consume the reserved Credit only after the complete,
            // validated result is locally readable.
            await CommerceStore.shared.acknowledgeReport(requestID: delivery.requestID)
            return current
        } catch is CancellationError {
            current.status = .deliveryFailed
            current.generationError = "Report generation was interrupted."
            store.upsert(current)
            throw CancellationError()
        } catch is URLError {
            current.status = .deliveryFailed
            current.generationError = "The local comparison is saved. Reconnect and try the report again."
            store.upsert(current)
            throw CompareAIError.delivery("The local comparison is saved. Reconnect and try the report again.")
        } catch CompareAIError.delivery(let message) {
            current.status = .deliveryFailed
            current.generationError = message
            store.upsert(current)
            throw CompareAIError.delivery(message)
        } catch CompareAIError.relayFailed(let message) {
            current.status = .relayFailed
            current.generationError = message
            store.upsert(current)
            throw CompareAIError.relayFailed(message)
        } catch {
            var failed = current
            failed.status = .relayFailed
            failed.generationError = error.localizedDescription
            store.upsert(failed)
            throw error
        }
    }

    func beginReportGeneration(analysisID: String, model: AppModel) {
        guard reportTasks[analysisID] == nil,
              let analysis = store.analysis(id: analysisID),
              analysis.result == nil,
              analysis.status == .chartsReady
        else { return }
        reportTasks[analysisID] = Task { [weak self] in
            guard let self else { return }
            defer { self.reportTasks[analysisID] = nil }
            _ = try? await self.generateReport(analysisID: analysisID, model: model)
        }
    }

    func reconcilePendingReports(model: AppModel) {
        let recentLegacyIDs = Set(store.recentAnalyses.map(\.id))
        for analysis in store.analyses where analysis.result == nil {
            switch analysis.status {
            case .generatingReport, .deliveryFailed:
                reconcile(analysisID: analysis.id, model: model)
            case .reportFailed where recentLegacyIDs.contains(analysis.id):
                reconcile(analysisID: analysis.id, model: model)
            case .chartsReady, .completed, .relayFailed:
                break
            case .reportFailed:
                break
            }
        }
    }

    func reconcile(analysisID: String, model: AppModel) {
        guard reportTasks[analysisID] == nil,
              let analysis = store.analysis(id: analysisID),
              analysis.result == nil
        else { return }
        switch analysis.status {
        case .chartsReady, .generatingReport, .deliveryFailed, .reportFailed:
            break
        case .completed, .relayFailed:
            return
        }
        _ = model
        reportTasks[analysisID] = Task { [weak self] in
            guard let self else { return }
            defer { self.reportTasks[analysisID] = nil }
            do {
                let delivery = try await self.reportService.recover(
                    request: analysis.request,
                    bundle: analysis.bundle,
                    requestID: analysis.id,
                    onGenerating: { [weak self] in
                        guard let self, var running = self.store.analysis(id: analysis.id) else { return }
                        running.status = .generatingReport
                        running.generationError = nil
                        self.store.upsert(running)
                    }
                )
                guard let delivery else {
                    if analysis.status == .chartsReady { return }
                    var missing = analysis
                    missing.status = .relayFailed
                    missing.generationError = "The Relay has no report for this request."
                    self.store.upsert(missing)
                    return
                }
                guard var completed = self.store.analysis(id: analysis.id) else { return }
                completed.result = delivery.result
                completed.status = .completed
                completed.generationError = nil
                guard self.store.upsert(completed) else { return }
                await CommerceStore.shared.acknowledgeReport(requestID: delivery.requestID)
            } catch CompareAIError.relayFailed(let message) {
                guard var failed = self.store.analysis(id: analysis.id) else { return }
                failed.status = .relayFailed
                failed.generationError = message
                self.store.upsert(failed)
            } catch {
                guard var pending = self.store.analysis(id: analysis.id) else { return }
                pending.status = .deliveryFailed
                pending.generationError = error.localizedDescription
                self.store.upsert(pending)
            }
        }
    }

    @discardableResult
    func analyze(request: CompareRequest, model: AppModel) async throws -> CompareAnalysis {
        let local = try await startLocal(request: request, model: model)
        return try await generateReport(analysisID: local.id, model: model)
    }

    @discardableResult
    func retry(analysisID: String, model: AppModel) async throws -> CompareAnalysis {
        if let recovery = reportTasks[analysisID] {
            await recovery.value
        }
        guard let current = store.analysis(id: analysisID) else {
            throw CompareAIError.failed("Comparison not found.")
        }
        guard current.canRetryReport else { return current }
        return try await generateReport(analysisID: current.id, model: model, recoverFirst: true)
    }
}
