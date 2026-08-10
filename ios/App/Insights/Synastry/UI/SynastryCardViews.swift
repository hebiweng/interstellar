import SwiftUI

extension InsightVisualView {
    func bondOrbit(_ presentation: SynastryOverviewPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                personOrb(name: presentation.firstName)
                bondLine
                personOrb(name: presentation.secondName)
            }
            .padding(.top, 5)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(presentation.dimensions.enumerated()), id: \.offset) { _, dimension in
                        dimensionTag(dimension)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Array(presentation.dimensions.prefix(2).enumerated()), id: \.offset) { _, dimension in
                            dimensionTag(dimension)
                        }
                    }
                    if presentation.dimensions.count > 2 {
                        dimensionTag(presentation.dimensions[2])
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localized(
            "Relationship connection between \(presentation.firstName) and \(presentation.secondName)",
            "\(presentation.firstName) 与 \(presentation.secondName) 的关系连接",
            language: language
        ))
    }

    private func personOrb(name: String) -> some View {
        Text(synastryInitials(name))
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(AppTheme.text)
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .frame(width: 68, height: 68)
            .background(AppTheme.panelRaised, in: Circle())
            .overlay(Circle().stroke(AppTheme.text.opacity(0.14), lineWidth: 1))
            .accessibilityLabel(name)
    }

    private var bondLine: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.blue, AppTheme.violet],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)

            Image(systemName: "heart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 32, height: 32)
                .background(AppTheme.panelRaised, in: Circle())
                .overlay(Circle().stroke(AppTheme.violet.opacity(0.3), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func dimensionTag(_ dimension: SynastryOverviewDimension) -> some View {
        Text("\(dimensionLabel(dimension.id)): \(dimensionStateLabel(dimension.state))")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.text.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.text.opacity(0.085), lineWidth: 1))
            .fixedSize(horizontal: true, vertical: false)
    }

    private func dimensionLabel(_ id: SynastryOverviewDimensionID) -> String {
        switch id {
        case .communication: localized("Communication", "沟通", language: language)
        case .emotionalPace: localized("Emotional pace", "情感节奏", language: language)
        case .chemistry: localized("Chemistry", "吸引力", language: language)
        }
    }

    private func dimensionStateLabel(_ state: SynastryOverviewDimensionState) -> String {
        switch state {
        case .strong: localized("strong", "强", language: language)
        case .steady: localized("steady", "稳定", language: language)
        case .active: localized("active", "活跃", language: language)
        case .mixed: localized("mixed", "交错", language: language)
        case .different: localized("different", "不同", language: language)
        case .quiet: localized("quiet", "平静", language: language)
        }
    }

    private func synastryInitials(_ name: String) -> String {
        let parts = name.split(whereSeparator: \.isWhitespace)
        let initials = parts.prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "•" : initials.uppercased()
    }

    // MARK: - Perspective tabs (prototype .perspective-tabs)

    func perspectiveTabs(_ presentation: SynastryPerspectivePresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                perspectiveButton(name: presentation.pair.firstName, index: 0)
                perspectiveButton(name: presentation.pair.secondName, index: 1)
            }

            let role = selectedSynastryPerspective == 0 ? "personA" : "personB"
            VStack(alignment: .leading, spacing: 7) {
                if let headline = roleText("\(role).headline") {
                    Text(headline)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = roleText("\(role).body") {
                    Text(body)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        }
    }

    private func perspectiveButton(name: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedSynastryPerspective = index }
        } label: {
            Text(localized("\(name) feels", "\(name) 的感受", language: language))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selectedSynastryPerspective == index ? Color.white : AppTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedSynastryPerspective == index ? AppTheme.violet.opacity(0.36) : AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedSynastryPerspective == index ? .isSelected : [])
    }

    // MARK: - Connection grid (prototype .connection-grid)

    func synastryConnectionGrid(_ kind: SynastryConnectionGridKind) -> some View {
        let roles = kind == .emotional ? ["flow", "difference"] : ["stability", "growth"]
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                ForEach(roles, id: \.self) { role in
                    if let fact = facts.first(where: { $0.visualRole == role }) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gridRoleLabel(role))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(fact.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if let body = roleText("\(role).body") {
                                Text(body)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(AppTheme.muted)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gridRoleLabel(role))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(localized("No distinct signal", "暂无独立信号", language: language))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(missingGridRoleExplanation(role))
                                .font(.system(size: 11.5))
                                .foregroundStyle(AppTheme.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    var synastryPathFlow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Text(communicationStepText(index))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 5)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
                    if index < 2 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.violet)
                    }
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.line, lineWidth: 1))
            }
        }
    }

    var synastryChemistry: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                chemistryCell(role: "attraction", label: localized("ATTRACTION", "吸引", language: language), tone: AppTheme.mint)
                chemistryCell(role: "intensity", label: localized("INTENSITY", "强度", language: language), tone: AppTheme.coral)
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.line, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func chemistryCell(role: String, label: String, tone: Color) -> some View {
        if let fact = facts.first(where: { $0.visualRole == role }) {
            VStack(spacing: 5) {
                Text(label).font(.system(size: 9.5, weight: .bold)).foregroundStyle(tone)
                Text(fact.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(11)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tone.opacity(0.22), lineWidth: 1))
        }
    }

    func synastryHouseOverlayRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.element.id) { index, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fact.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Spacer(minLength: 8)
                        Text(fact.value)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    synastryRelevanceBar(fact.progress ?? 0)
                }
                .padding(.vertical, 4)
                if index < min(facts.count, 4) - 1 {
                    Divider().overlay(AppTheme.line)
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
        .accessibilityLabel(localized("House overlays between \(pair.firstName) and \(pair.secondName)", "\(pair.firstName) 与 \(pair.secondName) 的双向落宫", language: language))
    }

    func synastryInterAspectRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.element.id) { index, fact in
                Button { synastryFactDrawer = fact } label: {
                    HStack(spacing: 10) {
                        Text(fact.symbol ?? "✦")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fact.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(fact.value)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer(minLength: 8)
                        Text(technicalTag(fact.emphasis))
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                if index < min(facts.count, 6) - 1 {
                    Divider().overlay(AppTheme.line)
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
        .accessibilityLabel(localized("Key inter-aspects between \(pair.firstName) and \(pair.secondName)", "\(pair.firstName) 与 \(pair.secondName) 的关键跨盘相位", language: language))
    }

    private func gridRoleLabel(_ role: String) -> String {
        switch role {
        case "flow": localized("WHAT FLOWS", "顺畅之处", language: language)
        case "difference": localized("WHAT DIFFERS", "差异之处", language: language)
        case "stability": localized("STABILITY", "稳定性", language: language)
        case "growth": localized("GROWTH", "成长性", language: language)
        default: role.uppercased()
        }
    }

    private func synastryRelevanceBar(_ value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.background.opacity(0.8))
                LinearGradient(
                    colors: [AppTheme.blue, AppTheme.violet],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * min(max(value, 0), 1))
                .clipShape(Capsule())
            }
        }
        .frame(height: 8)
        .accessibilityValue(localized("Relevance \(Int(value * 100)) percent", "相关性 \(Int(value * 100))%", language: language))
    }

    private func missingGridRoleExplanation(_ role: String) -> String {
        switch role {
        case "flow":
            localized("No separate supportive Moon contact met the current threshold.", "当前没有另一条达到门槛的月亮支持相位。", language: language)
        case "difference":
            localized("No separate contrasting Moon contact met the current threshold.", "当前没有另一条达到门槛的月亮差异相位。", language: language)
        case "stability":
            localized("No separate Saturn contact met the current threshold.", "当前没有另一条达到门槛的土星相位。", language: language)
        case "growth":
            localized("No separate Jupiter contact met the current threshold.", "当前没有另一条达到门槛的木星相位。", language: language)
        default:
            localized("No separate qualifying contact was found.", "当前没有另一条符合条件的相位。", language: language)
        }
    }

    private func communicationStepText(_ index: Int) -> String {
        let supplied = roleText("step\(index + 1)")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let supplied, isCompactCommunicationStep(supplied) {
            return supplied
        }
        return facts[safe: index]?.label ?? localized("No signal", "暂无信号", language: language)
    }

    private func isCompactCommunicationStep(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        guard !lowercased.contains("you"), !value.contains("你") else { return false }
        if language == .simplifiedChinese {
            return value.count <= 10
        }
        return value.split(whereSeparator: \.isWhitespace).count <= 4 && value.count <= 28
    }

    private func roleText(_ roleID: String) -> String? {
        text?.roleTexts?.first(where: { $0.roleID == roleID })?.text
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct SynastryFactDetailSheet: View {
    let fact: InsightFact
    let interpretation: String?
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sheetHandle
                Text(fact.label)
                    .font(.system(size: 23, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(localized(
                    "A cross-chart contact showing how one person’s planet meets the other person’s natal pattern.",
                    "这是一条跨盘联系，显示一方行星如何触及另一方的本命结构。",
                    language: language
                ))
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    factTile(localized("Aspect", "相位", language: language), fact.label)
                    factTile(localized("Function", "作用", language: language), functionLabel)
                    factTile(localized("Orb & phase", "容许度与阶段", language: language), fact.value)
                    factTile(localized("Direction", "方向", language: language), fact.category ?? "—")
                }
                .padding(.vertical, 16)

                if let explanation = interpretation ?? fact.note, !explanation.isEmpty {
                    sheetSection(
                        title: localized("Interpretation", "解读", language: language),
                        body: explanation
                    )
                }

                doneButton
                    .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var functionLabel: String {
        switch fact.emphasis {
        case .supportive: localized("Core support", "核心支持", language: language)
        case .challenging: localized("Active friction", "活跃摩擦", language: language)
        case .transition: localized("Long-term bond", "长期联系", language: language)
        case .neutral: localized("Supporting context", "辅助背景", language: language)
        }
    }

    private var sheetHandle: some View {
        Capsule()
            .fill(AppTheme.muted.opacity(0.55))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    private func factTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }

    private func sheetSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }

    private var doneButton: some View {
        Button(localized("Done", "完成", language: language)) { dismiss() }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .buttonStyle(.plain)
    }
}

struct SynastryCardDetailSheet: View {
    let card: InsightCardModel
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(AppTheme.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)

                Text(card.title)
                    .font(.system(size: 23, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(detailIntroduction)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    ForEach(Array(card.facts.prefix(4).enumerated()), id: \.element.id) { index, fact in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(detailFactLabel(fact, index: index))
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.muted)
                            Text(fact.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
                .padding(.vertical, 16)

                if let headline = card.text?.headline, !headline.isEmpty {
                    interpretationSection(title: headline, body: card.text?.body)
                } else if let body = card.text?.body, !body.isEmpty {
                    interpretationSection(
                        title: localized("Interpretation", "解读", language: language),
                        body: body
                    )
                }

                Button {
                    dismiss()
                } label: {
                    Text(localized("Done", "完成", language: language))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var detailIntroduction: String {
        switch card.id {
        case "emotional-connection":
            localized("Moon contacts show emotional recognition, regulation and pacing.", "月亮联系显示彼此如何识别、调节与同步情绪。", language: language)
        case "communication":
            localized("Mercury contacts describe comprehension, pace and conflict style.", "水星联系描述理解方式、交流速度与冲突风格。", language: language)
        case "chemistry":
            localized("Venus and Mars contacts describe attraction and pursuit; other major contacts can add intensity.", "金星与火星联系描述吸引和追求，其他重要联系会增加强度。", language: language)
        case "commitment":
            localized("Saturn, Jupiter and angle contacts show reliability, growth and structural pressure.", "土星、木星与角点联系显示可靠性、成长空间与结构压力。", language: language)
        default:
            localized("This detail uses only the calculated evidence selected for this card.", "本详情只使用这张卡片已选中的计算证据。", language: language)
        }
    }

    private func detailFactLabel(_ fact: InsightFact, index: Int) -> String {
        if let role = fact.visualRole {
            switch role {
            case "flow": return localized("Support", "支持", language: language)
            case "difference": return localized("Friction", "差异", language: language)
            case "attraction": return localized("Attraction", "吸引", language: language)
            case "intensity": return localized("Intensity", "强度", language: language)
            case "stability": return localized("Stability", "稳定", language: language)
            case "growth": return localized("Growth", "成长", language: language)
            default: break
            }
        }
        if card.id == "communication" {
            if fact.emphasis == .supportive { return localized("Support", "支持", language: language) }
            if fact.emphasis == .challenging { return localized("Friction", "摩擦", language: language) }
        }
        return localized("Contact \(index + 1)", "联系 \(index + 1)", language: language)
    }

    private func interpretationSection(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            if let body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }
}

struct SynastryOverviewDetailSheet: View {
    let card: InsightCardModel
    let presentation: SynastryOverviewPresentation
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(AppTheme.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)

                Text(localized("Relationship Overview", "关系总览", language: language))
                    .font(.system(size: 23, weight: .bold))
                    .tracking(-0.55)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(localized(
                    "Synastry compares how \(presentation.firstName) and \(presentation.secondName) affect each other through inter-aspects and house overlays.",
                    "合盘通过跨盘相位与双向落宫，比较 \(presentation.firstName) 和 \(presentation.secondName) 如何彼此影响。",
                    language: language
                ))
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    overviewFact(
                        label: localized("Strongest link", "最强连接", language: language),
                        fact: strongestSupport ?? card.facts.first
                    )
                    overviewFact(
                        label: localized("Primary contrast", "主要差异", language: language),
                        fact: primaryContrast ?? card.facts.dropFirst().first
                    )
                }
                .padding(.vertical, 16)

                if let body = card.text?.body, !body.isEmpty {
                    detailSection(
                        title: localized("Main pattern", "主要结构", language: language),
                        body: body
                    )
                }

                detailSection(
                    title: localized("How to read this", "如何理解", language: language),
                    body: localized(
                        "This overview separates relationship functions because the same connection can flow easily in one area and require adjustment in another.",
                        "这张总览会分别呈现不同关系功能，因为同一段连接可能在一个领域自然顺畅，在另一个领域需要磨合。",
                        language: language
                    )
                )

                Button {
                    dismiss()
                } label: {
                    Text(localized("Done", "完成", language: language))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.blue, AppTheme.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var strongestSupport: InsightFact? {
        card.facts.first { $0.emphasis == .supportive }
    }

    private var primaryContrast: InsightFact? {
        card.facts.first { $0.emphasis == .challenging }
    }

    @ViewBuilder
    private func overviewFact(label: String, fact: InsightFact?) -> some View {
        if let fact {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.muted)
                Text(fact.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        }
    }

    private func detailSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.line).frame(height: 1)
        }
    }
}
