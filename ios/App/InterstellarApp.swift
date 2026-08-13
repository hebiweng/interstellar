import SwiftUI

@main
struct InterstellarApp: App {
    @StateObject private var model = AppModel()

    init() {
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
                .task { await CommerceStore.shared.start() }
        }
    }
}
