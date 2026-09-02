import SwiftUI

@main
struct InterstellarApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppInstallationLifecycle.prepareForCurrentContainer()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-test-identity") {
            CommerceIdentity.resetForTesting()
            InstallationIdentity.resetForTesting()
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.xiaoguiwk.interstellar")
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.appearance.colorScheme)
                .task {
					await CommerceStore.shared.start()
					if CommerceAccountDeletionState.requiresPersonalErase {
						await model.erasePersonalDataForAccountDeletion()
					}
					PendingReportManager.shared.attach(model: model)
					PendingReportManager.shared.syncPendingReports()
                    AskDeepAnalysisManager.shared.reconcilePendingReports()
                    CompareAnalysisManager.shared.reconcilePendingReports(model: model)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        PendingReportManager.shared.syncPendingReports()
						AskDeepAnalysisManager.shared.reconcilePendingReports()
						CompareAnalysisManager.shared.reconcilePendingReports(model: model)
						Task {
							async let commerce: Void = CommerceStore.shared.refreshForForeground()
							async let today: Void = model.refreshTodayEventsIfNeeded()
							_ = await (commerce, today)
						}
                    } else {
                        PendingReportManager.shared.suspendPollers()
                    }
                }
        }
    }
}
