import SwiftUI

@main
struct InterstellarApp: App {
    @StateObject private var model = AppModel()

    init() {
#if DEBUG
        let freshInstallKey = "debug.identity-initialized-for-install.v1"
        let isFreshDebugInstall = !UserDefaults.standard.bool(forKey: freshInstallKey)
        if isFreshDebugInstall || ProcessInfo.processInfo.arguments.contains("--reset-test-identity") {
            CommerceIdentity.resetForTesting()
            InstallationIdentity.resetForTesting()
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.xiaoguiwk.interstellar")
            UserDefaults.standard.set(true, forKey: freshInstallKey)
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
