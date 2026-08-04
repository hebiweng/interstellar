import SwiftUI

extension InsightVisualView {
    func skyOverview(phase: Double, activity: Int, cycles: [Double]) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10 + Double(activity) / 400))
                    .frame(width: 74, height: 74)
                    .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, phase / 360))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(phase))°").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.text)
                    Text(localized("phase", "月相", language: language)).font(.system(size: 9)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(activity)%", localized("Activity", "活跃度", language: language), .transition)
                metric("\(Int((cycles.first ?? 0) * 100))%", localized("Long cycle", "长期周期", language: language), .supportive)
                metric("\(Int((cycles.last ?? 0) * 100))%", localized("Short cycle", "短期周期", language: language), .neutral)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var themeCards: some View {
        VStack(spacing: 10) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.symbol ?? "✦").foregroundStyle(AppTheme.tone(fact.emphasis))
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
                .padding(12)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    // MARK: - Timeline / event list (prototype .time-event + rail + now-line)

    var eventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                HStack(alignment: .top, spacing: 12) {
                    Text(fact.label)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 42, alignment: .leading)
                    VStack(spacing: 0) {
                        Circle()
                            .fill(AppTheme.tone(fact.emphasis))
                            .frame(width: 8, height: 8)
                        if index < min(4, facts.count) - 1 {
                            Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 24)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.value).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
            }
        }
    }

    var dateEventList: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 12) {
                    let parts = dateParts(fact.label)
                    VStack(spacing: 1) {
                        Text(parts.0)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.muted)
                        Text(parts.1)
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(width: 54)
                    .padding(.vertical, 8)
                    .background(AppTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fact.value)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = fact.note {
                            Text(note)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(AppTheme.violet)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 4))
                }
                .padding(14)
                .cardSurface()
            }
        }
    }

    func dateParts(_ label: String) -> (String, String) {
        let parts = label.split(separator: " ")
        if parts.count == 2 {
            return (String(parts[0]).uppercased(), String(parts[1]))
        }
        if let monthEnd = label.range(of: "月"), let dayStart = label.range(of: "日") {
            let month = String(label[..<monthEnd.upperBound])
            let day = String(label[monthEnd.upperBound..<dayStart.lowerBound])
            return (month, day + "日")
        }
        return (label, "")
    }

    // MARK: - Domain bars

    func domainBars(_ values: [Double]) -> some View {
        let labels = language == .english
            ? ["Information", "Relationships", "Action", "Institutions", "Technology", "Resources", "Public mood", "Culture"]
            : ["信息传播", "关系合作", "行动竞争", "制度结构", "技术创新", "资源经济", "公共情绪", "文化价值"]
        return VStack(spacing: 8) {
            ForEach(Array(zip(labels, values).enumerated()), id: \.offset) { index, item in
                HStack(spacing: 9) {
                    Text(item.0).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted).frame(width: 76, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6))
                            Capsule().fill(AppTheme.violet.opacity(0.85))
                                .frame(width: proxy.size.width * max(0.02, min(1, item.1)))
                        }
                    }
                    .frame(height: 7)
                    Text("\(Int(item.1 * 100))%").font(.system(size: 10).monospacedDigit()).foregroundStyle(AppTheme.muted)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }

    var evolution: some View {
        factRows
    }

    var planetTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.prefix(10).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 9) {
                    Text(fact.symbol ?? "✦")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 24)
                    Text(fact.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.text)
                    Spacer()
                    Text(fact.value).font(.system(size: 10.5)).foregroundStyle(AppTheme.muted)
                    if let note = fact.note {
                        Text(note).font(.system(size: 9.5)).foregroundStyle(AppTheme.muted.opacity(0.8))
                            .frame(width: 84, alignment: .trailing)
                    }
                }
                .padding(.vertical, 7)
                Divider().overlay(AppTheme.line.opacity(0.6))
            }
        }
    }

    func phaseDial(phase: Double, illumination: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, illumination))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("☽").font(.system(size: 22)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(Int(illumination * 100))%", localized("illuminated", "照亮", language: language), .transition)
                metric(progressedPhaseName(phase), localized("phase", "月相", language: language), .neutral)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
