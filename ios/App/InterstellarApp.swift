import SwiftUI

@main
struct InterstellarApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.appearance.colorScheme)
        }
    }
}
