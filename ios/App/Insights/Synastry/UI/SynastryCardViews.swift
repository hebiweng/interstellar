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

            if presentation.dimensions.count >= 3 {
                HStack(spacing: 6) {
                    dimensionTag(presentation.dimensions[0])
                    dimensionTag(presentation.dimensions[1])
                }
                dimensionTag(presentation.dimensions[2])
            } else {
                ForEach(Array(presentation.dimensions.enumerated()), id: \.offset) { _, dimension in
                    dimensionTag(dimension)
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
            .font(.system(size: 10, weight: .medium))
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
            let selectedIDs = Set(selectedSynastryPerspective == 0
                ? presentation.firstSourceFactIDs
                : presentation.secondSourceFactIDs)
            let selectedFacts = facts.filter { selectedIDs.contains($0.id) }
            VStack(alignment: .leading, spacing: 7) {
                if let headline = roleText("\(role).headline") {
                    Text(headline)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = roleText("\(role).body") {
                    Text(body)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !selectedFacts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(selectedFacts.prefix(2))) { fact in
                            Text(fact.value)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(AppTheme.muted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(AppTheme.text.opacity(0.05), in: Capsule())
                        }
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
            .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func perspectiveButton(name: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedSynastryPerspective = index }
        } label: {
            Text(localized("\(name) feels", "\(name) 的感受", language: language))
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(selectedSynastryPerspective == index ? Color.white : AppTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selectedSynastryPerspective == index ? AppTheme.violet : AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
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
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(fact.label)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if let body = roleText("\(role).body") {
                                Text(body)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(AppTheme.muted)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
                        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gridRoleLabel(role))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(localized("No distinct signal", "暂无独立信号", language: language))
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(missingGridRoleExplanation(role))
                                .font(.system(size: 9.5))
                                .foregroundStyle(AppTheme.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
                        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
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
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 5)
                        .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
                    if index < 2 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.violet)
                    }
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
    }

    @ViewBuilder
    private func chemistryCell(role: String, label: String, tone: Color) -> some View {
        if let fact = facts.first(where: { $0.visualRole == role }) {
            VStack(spacing: 5) {
                Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(tone)
                Text(fact.label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .padding(10)
            .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    func synastryHouseOverlayRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(4))) { fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fact.label)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Spacer(minLength: 8)
                        Text(fact.value)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                    ProgressView(value: fact.progress ?? 0)
                        .tint(AppTheme.violet)
                }
                .padding(10)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
        .accessibilityLabel(localized("House overlays between \(pair.firstName) and \(pair.secondName)", "\(pair.firstName) 与 \(pair.secondName) 的双向落宫", language: language))
    }

    func synastryInterAspectRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(6))) { fact in
                Button { synastryFactDrawer = fact } label: {
                    HStack(spacing: 10) {
                        Text(fact.symbol ?? "✦")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fact.label)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(fact.value)
                                .font(.system(size: 9.5))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer(minLength: 8)
                        Text(technicalTag(fact.emphasis))
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(10)
                    .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
            if let body = text?.body {
                Text(body)
                    .font(.system(size: 10.5))
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
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(fact.label)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(fact.value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                if let note = fact.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                }
                Button(localized("Done", "完成", language: language)) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }
}

struct SynastryCardDetailSheet: View {
    let card: InsightCardModel
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(card.title)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                if let headline = card.text?.headline, !headline.isEmpty {
                    Text(headline)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                }
                if let body = card.text?.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    ForEach(Array(card.facts.prefix(4))) { fact in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(fact.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(fact.value)
                                .font(.system(size: 9.5))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Button(localized("Done", "完成", language: language)) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
        }
        .background(AppTheme.panel.ignoresSafeArea())
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
                .font(.system(size: 11))
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
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.muted)
                Text(fact.label)
                    .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text(body)
                .font(.system(size: 10))
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
