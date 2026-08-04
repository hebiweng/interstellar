import SwiftUI

// MARK: - Shared prototype primitives

private struct Kicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(AppTheme.violet)
    }
}

enum InsightBadgeTone {
    case purple
    case warm
    case good
}

struct InsightBadge: View {
    let text: String
    var tone: InsightBadgeTone = .purple

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch tone {
        case .purple: Color(red: 0.85, green: 0.82, blue: 1.0)
        case .warm: AppTheme.amber
        case .good: AppTheme.mint
        }
    }

    private var background: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.13)
        case .warm: AppTheme.amber.opacity(0.11)
        case .good: AppTheme.mint.opacity(0.11)
        }
    }

    private var border: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.22)
        case .warm: AppTheme.amber.opacity(0.18)
        case .good: AppTheme.mint.opacity(0.18)
        }
    }
}

struct TagChip: View {
    let text: String
    var tone: InsightTone = .neutral
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.tone(tone).opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.tone(tone).opacity(0.25), lineWidth: 1))
            .foregroundStyle(AppTheme.tone(tone).mix(with: AppTheme.text, by: 0.35))
    }
}

private extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let lhs = UIColor(self)
        let rhs = UIColor(other)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return Color(
            red: Double(lr * (1 - amount) + rr * amount),
            green: Double(lg * (1 - amount) + rg * amount),
            blue: Double(lb * (1 - amount) + rb * amount),
            opacity: Double(la * (1 - amount) + ra * amount)
        )
    }
}

private struct SectionSub: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.muted)
    }
}

// MARK: - Visual renderer

