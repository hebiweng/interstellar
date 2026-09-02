import SwiftUI

enum RootTab: Hashable {
    case ask
    case themes
    case compare
    case charts
    case profile
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared
    @State private var selection: RootTab = .charts
    @State private var initialProfileSetupRequested = false
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false

    var body: some View {
        Group {
            if onboardingCompleted || bypassesOnboardingForUITests {
                TabView(selection: $selection) {
                    AskView()
                        .tag(RootTab.ask)
                        .tabItem {
                            Label(
                                localized("navigation.ask", language: model.language),
                                systemImage: "sparkle.magnifyingglass"
                            )
                        }

                    ThemesView()
                        .tag(RootTab.themes)
                        .tabItem {
                            Label(
                                localized("navigation.themes", language: model.language),
                                systemImage: "square.grid.2x2"
                            )
                        }

                    CompareView()
                        .tag(RootTab.compare)
                        .tabItem {
                            Label(
                                localized("navigation.compare", language: model.language),
                                systemImage: "arrow.left.arrow.right"
                            )
                        }

                    ChartsView(selectedTab: $selection)
                        .tag(RootTab.charts)
                        .tabItem {
                            Label(
                                localized("charts.charts", language: model.language),
                                systemImage: "circle.hexagongrid"
                            )
                        }

                    ProfileView(
                        initialSetupRequested: $initialProfileSetupRequested,
                        onInitialSetupComplete: {
                            selection = .charts
                        }
                    )
                    .tag(RootTab.profile)
                    .tabItem {
                        Label(
                            localized("profile.profile", language: model.language),
                            systemImage: "person.crop.circle"
                        )
                    }
                }
                .tint(AppTheme.violet)
            } else {
                OnboardingView(language: model.language) {
                    onboardingCompleted = true
                    // Profile hosts the existing first-run birth-data editor; saving or
                    // skipping it immediately moves the user to Charts.
                    selection = .profile
                    initialProfileSetupRequested = true
                }
            }
        }
        .dynamicTypeSize(model.fontSize.dynamicTypeSize)
        .task {
            await model.refresh()
        }
        .sheet(isPresented: $commerce.showsPaywall) { PremiumPaywallView(language: model.language) }
        .sheet(isPresented: $commerce.showsCredits) { CreditsPurchaseView(language: model.language) }
    }

    private var bypassesOnboardingForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["INTERSTELLAR_UI_TEST_LANGUAGE"] != nil
        #else
        false
        #endif
    }
}

struct ScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.background,
                AppTheme.backgroundAccent,
                AppTheme.background,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String?

    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.footnote.weight(.bold))
                .tracking(1.7)
                .foregroundStyle(AppTheme.violet)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
