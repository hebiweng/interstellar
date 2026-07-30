import SwiftUI
import UIKit

enum AppTheme {
    static let background = adaptive(
        light: UIColor(red: 0.965, green: 0.972, blue: 0.992, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.043, blue: 0.071, alpha: 1)
    )
    static let backgroundAccent = adaptive(
        light: UIColor(red: 0.91, green: 0.925, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.05, green: 0.052, blue: 0.09, alpha: 1)
    )
    static let panel = adaptive(
        light: UIColor(red: 0.992, green: 0.994, blue: 1, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.09, blue: 0.14, alpha: 1)
    )
    static let panelRaised = adaptive(
        light: UIColor(red: 0.925, green: 0.936, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.122, blue: 0.18, alpha: 1)
    )
    static let line = adaptive(
        light: UIColor(red: 0.16, green: 0.19, blue: 0.29, alpha: 0.12),
        dark: UIColor(white: 1, alpha: 0.085)
    )
    static let text = adaptive(
        light: UIColor(red: 0.09, green: 0.105, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.37, green: 0.40, blue: 0.49, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.65, blue: 0.73, alpha: 1)
    )
    static let violet = adaptive(
        light: UIColor(red: 0.42, green: 0.31, blue: 0.83, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.55, blue: 0.98, alpha: 1)
    )
    static let blue = adaptive(
        light: UIColor(red: 0.27, green: 0.36, blue: 0.82, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.55, blue: 0.97, alpha: 1)
    )
    static let mint = adaptive(
        light: UIColor(red: 0.12, green: 0.57, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.47, green: 0.84, blue: 0.69, alpha: 1)
    )
    static let amber = adaptive(
        light: UIColor(red: 0.72, green: 0.46, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.76, blue: 0.46, alpha: 1)
    )
    static let coral = adaptive(
        light: UIColor(red: 0.78, green: 0.25, blue: 0.32, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.52, blue: 0.55, alpha: 1)
    )

    static func tone(_ tone: InsightTone) -> Color {
        switch tone {
        case .supportive: mint
        case .challenging: coral
        case .transition: amber
        case .neutral: blue
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum AppTypography {
    static let eyebrow = Font.footnote.weight(.bold)
    static let supporting = Font.footnote
    static let label = Font.subheadline.weight(.semibold)
    static let summary = Font.callout
    static let body = Font.body
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelRaised, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
