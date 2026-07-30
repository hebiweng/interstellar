import SwiftUI

enum RootTab: Hashable {
    case today
    case charts
    case ask
    case profile
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: RootTab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayView(selectedTab: $selection)
                .tag(RootTab.today)
                .tabItem {
                    Label(
                        localized("Today", "今日", language: model.language),
                        systemImage: "sparkles"
                    )
                }

            ChartsView()
                .tag(RootTab.charts)
                .tabItem {
                    Label(
                        localized("Charts", "星盘", language: model.language),
                        systemImage: "circle.hexagongrid"
                    )
                }

            AskView()
                .tag(RootTab.ask)
                .tabItem {
                    Label(
                        localized("Ask", "问事", language: model.language),
                        systemImage: "sparkle.magnifyingglass"
                    )
                }

            ProfileView()
                .tag(RootTab.profile)
                .tabItem {
                    Label(
                        localized("Profile", "我的", language: model.language),
                        systemImage: "person.crop.circle"
                    )
                }
        }
        .tint(AppTheme.violet)
        .dynamicTypeSize(model.fontSize.dynamicTypeSize)
        .task {
            await model.refresh()
        }
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
