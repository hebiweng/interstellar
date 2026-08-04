import SwiftUI

extension InsightVisualView {
    var bondOrbit: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.4), lineWidth: 1).frame(width: 104, height: 104)
                Circle().fill(AppTheme.violet.opacity(0.16)).frame(width: 52, height: 52)
                    .offset(x: -24)
                Circle().fill(AppTheme.blue.opacity(0.16)).frame(width: 52, height: 52)
                    .offset(x: 24)
                Text("∞").font(.system(size: 18, weight: .bold)).foregroundStyle(AppTheme.violet)
            }
            .frame(width: 112, height: 96)
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    TagChip(text: fact.label, tone: fact.emphasis)
                }
            }
        }
    }

    // MARK: - Perspective tabs (prototype .perspective-tabs)

    var perspectiveTabs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { index, fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(index == 0 ? AppTheme.violet : AppTheme.muted)
                        Text(fact.value)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(index == 0 ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
    }

    // MARK: - Connection grid (prototype .connection-grid)

    var houseOverlayRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }
}
