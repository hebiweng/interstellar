import SwiftUI

extension InsightVisualView {
    var orbitCircle: some View {
        let items = facts.prefix(3)
        let symbols = ["☉", "☽", "↑"]
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.3), lineWidth: 1).frame(width: 96, height: 96)
                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    let angle = Double(index) / 3 * 2 * Double.pi - Double.pi / 2
                    let radius = 44.0
                    Text(symbols[min(index, 2)])
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.tone(items[index].emphasis))
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
                Circle().fill(AppTheme.violet.opacity(0.12)).frame(width: 34, height: 34)
                Text("✶").font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, fact in
                    HStack(spacing: 6) {
                        Text(fact.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 40, alignment: .leading)
                        Text(fact.value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero-like structures

    var rankedThemes: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.violet)
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                    if let note = fact.note {
                        Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
    }

    func metricTrio(ruler: String, dominant: String, orientation: String) -> some View {
        HStack(spacing: 9) {
            trioCell(label: localized("Chart ruler", "命主星", language: language), value: ruler)
            trioCell(label: localized("Dominant", "主导星体", language: language), value: dominant)
            trioCell(label: localized("Orientation", "总体取向", language: language), value: orientation)
        }
    }

    var placementRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(8).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    if let category = fact.category {
                        Text(category)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(AppTheme.violet)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.violet.opacity(0.1), in: Capsule())
                    }
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                }
                .padding(.vertical, 8)
                Divider().overlay(AppTheme.line.opacity(0.6))
            }
        }
    }

    func edgeDual(opening: String, demand: String) -> some View {
        VStack(spacing: 10) {
            dualInsight(opening: opening, demand: demand, openingLabel: localized("CORE STRENGTH", "核心优势", language: language), demandLabel: localized("GROWTH EDGE", "成长面", language: language))
            ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(indexMark(fact.emphasis)).font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Text(fact.value).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    func indexMark(_ tone: InsightTone) -> String {
        tone == .supportive ? "+" : "↗"
    }

    // MARK: - Quarter tabs (prototype .quarter-tabs)

    var needsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("☽")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 40, height: 40)
                .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            ForEach(Array(facts.prefix(2).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                    Text(fact.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Transit timeline (prototype TR-03: range + timeline/calendar)
}
