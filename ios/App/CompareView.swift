import AstroCore
import Foundation
import SwiftUI

struct CompareView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = CompareAnalysisStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(localized("compare.title", language: model.language))
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        CompareHeroGraphic()
                            .frame(height: 118)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(localized("compare.hero.question", language: model.language))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(localized("compare.subtitle", language: model.language))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(localized("compare.hero.categories", language: model.language))
                                .font(.subheadline.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink(value: CompareType.meOverTime) {
                            comparePrimaryCard(.meOverTime)
                        }
                        .buttonStyle(CompareCardPressStyle())
                        .accessibilityIdentifier("compare-card-me-over-time")

                        HStack(alignment: .top, spacing: 12) {
                            NavigationLink(value: CompareType.twoPeople) {
                                compareCompactCard(.twoPeople)
                            }
                            .buttonStyle(CompareCardPressStyle())
                            .accessibilityIdentifier("compare-card-two-people")

                            NavigationLink(value: CompareType.twoPlaces) {
                                compareCompactCard(.twoPlaces)
                            }
                            .buttonStyle(CompareCardPressStyle())
                            .accessibilityIdentifier("compare-card-two-places")
                        }

                        NavigationLink(value: CompareType.relationshipOverTime) {
                            compareRelationshipCard()
                        }
                        .buttonStyle(CompareCardPressStyle())
                        .accessibilityIdentifier("compare-card-relationship-over-time")

                        if !store.recentAnalyses.isEmpty {
                            Text(localized("compare.recent", language: model.language))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .padding(.top, 8)
                            ForEach(store.recentAnalyses) { analysis in
                                NavigationLink {
                                    CompareResultView(analysisID: analysis.id)
                                } label: {
                                    recentRow(analysis)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CompareType.self) { type in
                CompareSetupView(type: type)
            }
        }
        .task { CompareAnalysisManager.shared.reconcilePendingReports(model: model) }
    }

    private func comparePrimaryCard(_ type: CompareType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CompareModeGraphic(type: type)
                .frame(height: 78)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(type.title(language: model.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                    Text(type.subtitle(language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                cardChevron
            }
        }
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
        .compareCardSurface(accent: accent(for: type))
    }

    private func compareCompactCard(_ type: CompareType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CompareModeGraphic(type: type)
                .frame(height: 58)

            Text(type.title(language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Text(type.subtitle(language: model.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
            cardChevron
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .compareCardSurface(accent: accent(for: type))
    }

    private func compareRelationshipCard() -> some View {
        let type = CompareType.relationshipOverTime
        return VStack(alignment: .leading, spacing: 14) {
            CompareModeGraphic(type: type)
                .frame(height: 72)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(type.title(language: model.language))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text(type.subtitle(language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                cardChevron
            }
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .compareCardSurface(accent: accent(for: type))
    }

    private var cardChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(AppTheme.violet)
            .frame(width: 30, height: 30)
            .background(AppTheme.violet.opacity(0.10), in: Circle())
    }

    private func accent(for type: CompareType) -> Color {
        switch type {
        case .meOverTime: AppTheme.violet
        case .twoPeople: AppTheme.blue
        case .twoPlaces: AppTheme.mint
        case .relationshipOverTime: AppTheme.coral
        }
    }

    private func recentRow(_ analysis: CompareAnalysis) -> some View {
        HStack(spacing: 12) {
            Image(systemName: analysis.request.type.systemImage)
                .foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 3) {
                Text(analysis.request.type.title(language: model.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(LocalizedFormatters.shortDateWithYear(analysis.createdAt, language: model.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                if analysis.status == .generatingReport || analysis.status == .chartsReady {
                    Label(localized("compare.stage.preparing-analysis", language: model.language), systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppTheme.violet)
                } else if analysis.status == .reportFailed
                            || analysis.status == .deliveryFailed
                            || analysis.status == .relayFailed {
                    Label(localized("common.retry", language: model.language), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(AppTheme.coral)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
        }
        .cardSurface()
    }
}

private struct CompareHeroGraphic: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(time * 0.84) + 1) / 2)
            let driftA = reduceMotion ? 0 : CGFloat(sin(time * 0.48)) * 1.8
            let driftB = reduceMotion ? 0 : CGFloat(sin(time * 0.48 + 1.7)) * 1.8
            let dashPhase = reduceMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 12)) * -3.2

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                ZStack {
                    Capsule()
                        .fill(AppTheme.violet.opacity(0.025 + 0.018 * pulse))
                        .frame(width: width * 0.62, height: 54)
                        .blur(radius: 14)
                        .position(x: width * 0.5, y: height * 0.5)

                    Path { path in
                        path.move(to: CGPoint(x: width * 0.28, y: height * 0.5))
                        path.addCurve(
                            to: CGPoint(x: width * 0.72, y: height * 0.5),
                            control1: CGPoint(x: width * 0.41, y: height * 0.20),
                            control2: CGPoint(x: width * 0.59, y: height * 0.80)
                        )
                    }
                    .stroke(AppTheme.violet.opacity(0.10), lineWidth: 1)

                    Path { path in
                        path.move(to: CGPoint(x: width * 0.28, y: height * 0.5))
                        path.addCurve(
                            to: CGPoint(x: width * 0.72, y: height * 0.5),
                            control1: CGPoint(x: width * 0.41, y: height * 0.20),
                            control2: CGPoint(x: width * 0.59, y: height * 0.80)
                        )
                    }
                    .stroke(
                        AppTheme.violet.opacity(0.28 + 0.12 * pulse),
                        style: StrokeStyle(lineWidth: 1.35, lineCap: .round, dash: [5, 7], dashPhase: dashPhase)
                    )

                    CompareOrbitalNode(label: "A", accent: AppTheme.violet)
                        .scaleEffect(1 + 0.025 * pulse)
                        .position(x: width * 0.22, y: height * 0.5 + driftA)
                    CompareOrbitalNode(label: "B", accent: AppTheme.blue)
                        .scaleEffect(1 + 0.025 * (1 - pulse))
                        .position(x: width * 0.78, y: height * 0.5 + driftB)

                    Text("⇄")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(AppTheme.violet)
                        .opacity(0.72 + 0.28 * pulse)
                        .scaleEffect(0.98 + 0.04 * pulse)
                        .position(x: width * 0.5, y: height * 0.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CompareCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.965 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CompareOrbitalNode: View {
    let label: String
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.18), lineWidth: 1)
                .frame(width: 58, height: 58)
            Circle()
                .stroke(accent.opacity(0.45), lineWidth: 1.4)
                .frame(width: 40, height: 40)
            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: 30, height: 30)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
        }
    }
}

private struct CompareModeGraphic: View {
    let type: CompareType

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            switch type {
            case .meOverTime:
                ZStack {
                    comparisonLine(width: width, height: height, accent: AppTheme.violet)
                    miniOrbit(accent: AppTheme.violet)
                        .position(x: width * 0.18, y: height * 0.5)
                    miniOrbit(accent: AppTheme.blue)
                        .position(x: width * 0.82, y: height * 0.5)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .position(x: width * 0.5, y: height * 0.5)
                }
            case .twoPeople:
                HStack(spacing: 8) {
                    personNode(accent: AppTheme.blue)
                    Text("⇄")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(AppTheme.violet)
                    personNode(accent: AppTheme.violet)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .twoPlaces:
                HStack(spacing: 8) {
                    placeNode(accent: AppTheme.mint)
                    Text("⇄")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(AppTheme.violet)
                    placeNode(accent: AppTheme.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .relationshipOverTime:
                HStack(spacing: 10) {
                    bondPair(accent: AppTheme.coral, lineWidth: 1.2)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    bondPair(accent: AppTheme.coral, lineWidth: 3.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func comparisonLine(width: CGFloat, height: CGFloat, accent: Color) -> some View {
        Capsule()
            .fill(accent.opacity(0.18))
            .frame(width: max(20, width * 0.52), height: 1)
            .position(x: width * 0.5, y: height * 0.5)
    }

    private func miniOrbit(accent: Color) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.22), lineWidth: 1).frame(width: 52, height: 52)
            Circle().stroke(accent.opacity(0.48), lineWidth: 1.2).frame(width: 34, height: 34)
            Circle().fill(accent.opacity(0.16)).frame(width: 7, height: 7)
        }
    }

    private func personNode(accent: Color) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.30), lineWidth: 1.2).frame(width: 45, height: 45)
            Circle().fill(accent.opacity(0.12)).frame(width: 31, height: 31)
            Image(systemName: "person.fill")
                .font(.caption)
                .foregroundStyle(accent)
        }
    }

    private func placeNode(accent: Color) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.28), lineWidth: 1.2).frame(width: 45, height: 45)
            Circle().stroke(accent.opacity(0.42), lineWidth: 1).frame(width: 27, height: 27)
            Circle().fill(accent.opacity(0.75)).frame(width: 6, height: 6)
        }
    }

    private func bondPair(accent: Color, lineWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Circle().fill(accent.opacity(0.78)).frame(width: 11, height: 11)
            Capsule().fill(accent.opacity(0.42)).frame(width: 42, height: lineWidth)
            Circle().fill(accent.opacity(0.78)).frame(width: 11, height: 11)
        }
    }
}

private struct CompareCardSurface: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(17)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelRaised, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .background(alignment: .topTrailing) {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 112, height: 112)
                    .blur(radius: 5)
                    .offset(x: 28, y: -36)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
    }
}

private extension View {
    func compareCardSurface(accent: Color) -> some View {
        modifier(CompareCardSurface(accent: accent))
    }
}

private enum CompareNewPersonTarget {
    case primary
    case secondary
}

private enum ComparePlaceTarget: String, Identifiable {
    case first
    case second
    var id: String { rawValue }
}

private enum CompareDatePreset: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case custom

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .oneMonth: localized("compare.date.1-month", language: language)
        case .threeMonths: localized("compare.date.3-months", language: language)
        case .sixMonths: localized("compare.date.6-months", language: language)
        case .oneYear: localized("compare.date.1-year", language: language)
        case .custom: localized("compare.date.custom", language: language)
        }
    }

    func date(relativeTo now: Date) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        switch self {
        case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: now)
        case .custom: return nil
        }
    }
}

private struct ComparePersonChoice: Identifiable {
    let id: String
    let name: String
    let profile: UserProfile
}

struct CompareSetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var commerce = CommerceStore.shared
    @ObservedObject private var manager = CompareAnalysisManager.shared

    let type: CompareType

    @State private var primaryID = "self"
    @State private var secondaryID: String?
    @State private var relationshipContext: CompareRelationshipContext = .skip
    @State private var datePreset: CompareDatePreset = .threeMonths
    @State private var dateA = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var dateB = Date()
    @State private var placeA: ComparePlace?
    @State private var placeB: ComparePlace?
    @State private var focusIDs: [String] = ["overall"]
    @State private var placeTarget: ComparePlaceTarget?
    @State private var editingNewPerson: SavedPerson?
    @State private var newPersonTarget: CompareNewPersonTarget?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var resultAnalysisID: String?
    @State private var showsResult = false
    @State private var showsAIConsentReminder = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(
                        eyebrow: localized("compare.title", language: model.language).uppercased(),
                        title: type.title(language: model.language),
                        subtitle: type.subtitle(language: model.language)
                    )

                    setupSection(localized("compare.input", language: model.language)) {
                        personRow(
                            title: localized("compare.person", language: model.language),
                            selected: primaryChoice?.name ?? model.profile.name,
                            choices: primaryChoices,
                            target: .primary
                        )

                        if type == .twoPeople || type == .relationshipOverTime {
                            Divider().overlay(AppTheme.line)
                            personRow(
                                title: localized("compare.person-b", language: model.language),
                                selected: secondaryChoice?.name ?? localized("compare.choose-person", language: model.language),
                                choices: secondaryChoices,
                                target: .secondary
                            )
                        }

                        if type == .twoPlaces {
                            Divider().overlay(AppTheme.line)
                            placeRow(
                                title: localized("compare.place-a", language: model.language),
                                value: placeA?.displayName ?? localized("compare.choose-place", language: model.language),
                                target: .first
                            )
                            Divider().overlay(AppTheme.line)
                            placeRow(
                                title: localized("compare.place-b", language: model.language),
                                value: placeB?.displayName ?? localized("compare.choose-place", language: model.language),
                                target: .second
                            )
                        }

                        if type == .meOverTime || type == .relationshipOverTime {
                            Divider().overlay(AppTheme.line)
                            dateSection
                        }
                    }

                    if type == .twoPeople || type == .relationshipOverTime {
                        setupSection(localized("compare.relationship-context", language: model.language)) {
                            Picker("", selection: $relationshipContext) {
                                ForEach(CompareRelationshipContext.allCases) { context in
                                    Text(context.title(language: model.language)).tag(context)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.violet)
                        }
                    }

                    setupSection(localized("compare.focus", language: model.language)) {
                        focusGrid
                    }

                    setupSection(localized("compare.review", language: model.language)) {
                        reviewRows
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        requestAnalysis()
                    } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing { ProgressView().tint(.white) }
                            Text(isAnalyzing
                                 ? localized(manager.stage?.localizationKey ?? "compare.stage.calculating-charts", language: model.language)
                                 : localized("compare.analyze-credit", language: model.language))
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzing || !canAnalyze)
                    .opacity((isAnalyzing || !canAnalyze) ? 0.55 : 1)
                    .accessibilityIdentifier("compare-analyze-button")
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if type == .twoPlaces, placeA == nil {
                placeA = ComparePlace.profileLocation(primaryChoice?.profile ?? model.profile)
            }
        }
        .sheet(item: $placeTarget) { target in
            LocationSearchView(language: model.language) { selection in
                let place = ComparePlace(selection)
                if target == .first { placeA = place } else { placeB = place }
            }
        }
        .sheet(item: $editingNewPerson) { person in
            SavedPersonEditorView(person: person, language: model.language) { saved in
                model.savePerson(saved)
                let id = saved.id.uuidString.lowercased()
                switch newPersonTarget {
                case .primary:
                    primaryID = id
                    if type == .twoPlaces { placeA = ComparePlace.profileLocation(saved.profile) }
                case .secondary:
                    secondaryID = id
                case nil:
                    break
                }
                newPersonTarget = nil
            }
        }
        .navigationDestination(isPresented: $showsResult) {
            if let resultAnalysisID {
                CompareResultView(analysisID: resultAnalysisID)
            }
        }
        .alert(
            localized("ai.network-consent.title", language: model.language),
            isPresented: $showsAIConsentReminder
        ) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                Task { await runAnalysis() }
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {}
        } message: {
            Text(localized("compare.ai-consent.message", language: model.language))
        }
    }

    private var primaryChoices: [ComparePersonChoice] {
        [ComparePersonChoice(id: "self", name: model.profile.name, profile: model.profile)]
            + model.savedPeople.map {
                ComparePersonChoice(
                    id: $0.id.uuidString.lowercased(),
                    name: $0.profile.name,
                    profile: $0.profile
                )
            }
    }

    private var secondaryChoices: [ComparePersonChoice] {
        primaryChoices.filter { $0.id != primaryID }
    }

    private var primaryChoice: ComparePersonChoice? {
        primaryChoices.first { $0.id == primaryID }
    }

    private var secondaryChoice: ComparePersonChoice? {
        secondaryChoices.first { $0.id == secondaryID }
    }

    private var canAnalyze: Bool {
        guard primaryChoice != nil else { return false }
        switch type {
        case .meOverTime:
            return dateA != dateB
        case .twoPeople:
            return secondaryChoice != nil
        case .twoPlaces:
            return placeA != nil && placeB != nil && placeA?.validationIdentity != placeB?.validationIdentity
        case .relationshipOverTime:
            return secondaryChoice != nil && dateA != dateB
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("compare.from", language: model.language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CompareDatePreset.allCases) { preset in
                        Button {
                            datePreset = preset
                            if let date = preset.date(relativeTo: Date()) { dateA = date }
                        } label: {
                            Text(preset.title(language: model.language))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(datePreset == preset ? Color.white : AppTheme.text)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    datePreset == preset ? AppTheme.violet : AppTheme.panel,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(AppTheme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            DatePicker(
                localized("compare.from", language: model.language),
                selection: Binding(
                    get: { dateA },
                    set: { value in
                        dateA = value
                        datePreset = .custom
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            Divider().overlay(AppTheme.line)
            DatePicker(
                localized("compare.to", language: model.language),
                selection: $dateB,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }

    private var focusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 9)], spacing: 9) {
            ForEach(type.focusOptions) { focus in
                let selected = focusIDs.contains(focus.id)
                Button {
                    toggleFocus(focus.id)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        Text(focus.title(language: model.language))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? AppTheme.violet : AppTheme.text)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(
                        selected ? AppTheme.violet.opacity(0.10) : AppTheme.panel.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? AppTheme.violet.opacity(0.35) : AppTheme.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var reviewRows: some View {
        reviewRow(
            localized("compare.person", language: model.language),
            primaryChoice?.name ?? "—"
        )
        if type == .twoPeople || type == .relationshipOverTime {
            reviewRow(
                localized("compare.person-b", language: model.language),
                secondaryChoice?.name ?? "—"
            )
        }
        if type == .twoPlaces {
            reviewRow(localized("compare.place-a", language: model.language), placeA?.displayName ?? "—")
            reviewRow(localized("compare.place-b", language: model.language), placeB?.displayName ?? "—")
        }
        if type == .meOverTime || type == .relationshipOverTime {
            reviewRow(localized("compare.from", language: model.language), formatted(dateA))
            reviewRow(localized("compare.to", language: model.language), formatted(dateB))
        }
        reviewRow(
            localized("compare.focus", language: model.language),
            selectedFocusTitles.joined(separator: " · ")
        )
    }

    private var selectedFocusTitles: [String] {
        type.focusOptions
            .filter { focusIDs.contains($0.id) }
            .map { $0.title(language: model.language) }
    }

    @ViewBuilder
    private func personRow(
        title: String,
        selected: String,
        choices: [ComparePersonChoice],
        target: CompareNewPersonTarget
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Text(selected)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }
            Spacer()
            Menu {
                ForEach(choices) { choice in
                    Button(choice.name) {
                        if target == .primary {
                            primaryID = choice.id
                            if secondaryID == choice.id { secondaryID = nil }
                            if type == .twoPlaces { placeA = ComparePlace.profileLocation(choice.profile) }
                        } else {
                            secondaryID = choice.id
                        }
                    }
                }
                Divider()
                Button {
                    newPersonTarget = target
                    editingNewPerson = SavedPerson.new(using: primaryChoice?.profile ?? model.profile)
                } label: {
                    Label(localized("compare.add-person", language: model.language), systemImage: "person.badge.plus")
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.violet.opacity(0.09), in: Circle())
            }
        }
    }

    private func placeRow(title: String, value: String, target: ComparePlaceTarget) -> some View {
        Button {
            placeTarget = target
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(value)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(AppTheme.violet)
            }
        }
        .buttonStyle(.plain)
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func setupSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func toggleFocus(_ id: String) {
        if id == "overall" {
            focusIDs = ["overall"]
            return
        }
        var next = focusIDs.filter { $0 != "overall" }
        if let index = next.firstIndex(of: id) {
            next.remove(at: index)
        } else if next.count < CompareFocus.maximumSelectionCount {
            next.append(id)
        }
        focusIDs = CompareFocusPolicy.normalized(next)
    }

    private func requestAnalysis() {
        errorMessage = nil
        guard canAnalyze else { return }
        Task {
            await commerce.refreshAccountIfStale()
            guard commerce.totalCredits >= 1 else {
                commerce.showsCredits = true
                return
            }
            guard model.aiConsentGranted else {
                showsAIConsentReminder = true
                return
            }
            await runAnalysis()
        }
    }

    @MainActor
    private func runAnalysis() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let request = try makeRequest().validated()
            let local = try await manager.startLocal(request: request, model: model)
            resultAnalysisID = local.id
            showsResult = true
            manager.beginReportGeneration(analysisID: local.id, model: model)
        } catch {
            errorMessage = validationMessage(error)
        }
    }

    private func makeRequest() throws -> CompareRequest {
        guard let primaryChoice else { throw CompareValidationError.missingSubject }
        let subjectA = CompareSubject(
            id: primaryChoice.id,
            displayName: primaryChoice.name,
            profile: primaryChoice.profile
        )
        let subjectB = secondaryChoice.map {
            CompareSubject(id: $0.id, displayName: $0.name, profile: $0.profile)
        }
        let selectedFocus = type.focusOptions.filter { focusIDs.contains($0.id) }
        return CompareRequest(
            type: type,
            subjectA: subjectA,
            subjectB: subjectB,
            dateA: type == .meOverTime || type == .relationshipOverTime ? dateA : nil,
            dateB: type == .meOverTime || type == .relationshipOverTime ? dateB : nil,
            placeA: type == .twoPlaces ? placeA : nil,
            placeB: type == .twoPlaces ? placeB : nil,
            relationshipContext: type == .twoPeople || type == .relationshipOverTime ? relationshipContext : nil,
            focus: selectedFocus,
            preset: model.preset(for: .natal),
            locale: model.language
        )
    }

    private func validationMessage(_ error: Error) -> String {
        guard let validation = error as? CompareValidationError else {
            return localized("compare.error.calculation-failed", language: model.language)
        }
        switch validation {
        case .sameDate: return localized("compare.error.same-date", language: model.language)
        case .samePlace: return localized("compare.error.same-place", language: model.language)
        case .samePerson: return localized("compare.error.same-person", language: model.language)
        case .missingDates: return localized("compare.error.missing-dates", language: model.language)
        case .missingPlaces: return localized("compare.error.missing-places", language: model.language)
        case .missingSecondSubject: return localized("compare.error.missing-person", language: model.language)
        case .tooManyFocuses: return localized("compare.error.too-many-focuses", language: model.language)
        case .missingSubject: return localized("compare.error.missing-person", language: model.language)
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = model.language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct CompareEvidenceSelection: Identifiable {
    let id = UUID()
    let factIDs: [String]
}

struct CompareResultView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = CompareAnalysisStore.shared
    @ObservedObject private var manager = CompareAnalysisManager.shared

    let analysisID: String

    @State private var evidenceSelection: CompareEvidenceSelection?
    @State private var isRetrying = false
    @State private var retryError: String?

    private var analysis: CompareAnalysis? { store.analysis(id: analysisID) }

    var body: some View {
        ZStack {
            ScreenBackground()
            if let analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        comparisonHeader(analysis)

                        if let result = analysis.result {
                            narrativeSection(result.summary, prominent: true)
                            ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                                narrativeSection(section, prominent: false)
                            }
                        } else {
                            localOnlyState(analysis)
                        }

                        calculatedChanges(analysis)

                        NavigationLink {
                            CompareChartsView(analysisID: analysis.id)
                        } label: {
                            HStack {
                                Label(localized("compare.view-charts", language: model.language), systemImage: "circle.hexagongrid")
                                    .font(.headline)
                                Spacer()
                                Text(localized("compare.no-extra-credit", language: model.language))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(AppTheme.text)
                            .cardSurface()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView(
                    localized("compare.result-unavailable", language: model.language),
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $evidenceSelection) { selection in
            CompareEvidenceSheet(analysisID: analysisID, factIDs: selection.factIDs)
        }
        .task { manager.reconcile(analysisID: analysisID, model: model) }
    }

    private func comparisonHeader(_ analysis: CompareAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(analysis.request.type.title(language: model.language).uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.violet)
            Text(headerPair(analysis.request))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(analysis.request.focus.map { $0.title(language: model.language) }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerPair(_ request: CompareRequest) -> String {
        switch request.type {
        case .meOverTime:
            return "\(formatted(request.dateA)) ↔ \(formatted(request.dateB))"
        case .twoPeople:
            return "\(request.subjectA.displayName) ↔ \(request.subjectB?.displayName ?? "—")"
        case .twoPlaces:
            return "\(request.placeA?.displayName ?? "—") ↔ \(request.placeB?.displayName ?? "—")"
        case .relationshipOverTime:
            let names = "\(request.subjectA.displayName) & \(request.subjectB?.displayName ?? "—")"
            return "\(names)\n\(formatted(request.dateA)) ↔ \(formatted(request.dateB))"
        }
    }

    private func narrativeSection(_ section: CompareNarrativeSection, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(section.title)
                .font(prominent ? .title2.weight(.bold) : .headline)
                .foregroundStyle(AppTheme.text)
            Text(section.text)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                evidenceSelection = CompareEvidenceSelection(factIDs: section.evidence)
            } label: {
                HStack(spacing: 6) {
                    Text(localizedTemplate(
                        "compare.based-on-factors",
                        substitutions: ["value": String(section.evidence.count)],
                        language: model.language
                    ))
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private func localOnlyState(_ analysis: CompareAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized(
                analysis.status == .generatingReport ? "compare.stage.preparing-analysis" : "compare.local-ready",
                language: model.language
            ))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            if analysis.status == .generatingReport {
                HStack(spacing: 9) {
                    ProgressView()
                    Text(localized("themes.report.preparing-detail", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
            } else {
                Text(localized("compare.local-ready-message", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            if analysis.generationError != nil || retryError != nil {
                Label(
                    localized("compare.error.ai-failed", language: model.language),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
            }
            if analysis.canRetryReport {
                Button {
                    retry()
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying { ProgressView() }
                        Text(localized("common.retry", language: model.language))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                }
                .buttonStyle(.plain)
                .disabled(isRetrying)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private func calculatedChanges(_ analysis: CompareAnalysis) -> some View {
        if analysis.request.type == .twoPeople {
            primaryComparisons(analysis)
        } else {
            primaryChanges(analysis)
        }
    }

    private func primaryChanges(_ analysis: CompareAnalysis) -> some View {
        let changes = ComparePrimaryResultSelector.changes(from: analysis.bundle.diff.allChanges)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("compare.primary-changes", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(String(changes.count))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
            }
            if changes.isEmpty {
                Text(localized("compare.no-calculated-changes", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(Array(changes.prefix(8).enumerated()), id: \.offset) { _, change in
                    Button {
                        evidenceSelection = CompareEvidenceSelection(factIDs: [change.id])
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: changeIcon(change.kind))
                                .foregroundStyle(AppTheme.violet)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(changeTitle(change))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(factSummary(change.after ?? change.before))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    if change.id != changes.prefix(8).last?.id {
                        Divider().overlay(AppTheme.line)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func primaryComparisons(_ analysis: CompareAnalysis) -> some View {
        let facts = ComparePrimaryResultSelector.comparisons(from: analysis.bundle.relationshipFacts)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("compare.primary-comparisons", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(String(facts.count))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
            }
            if facts.isEmpty {
                Text(localized("compare.no-calculated-changes", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                    Button {
                        evidenceSelection = CompareEvidenceSelection(factIDs: [fact.id])
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppTheme.violet)
                            Text(factSummary(fact))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    if index < facts.count - 1 { Divider().overlay(AppTheme.line) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func retry() {
        guard !isRetrying else { return }
        isRetrying = true
        retryError = nil
        Task {
            defer { isRetrying = false }
            do {
                _ = try await manager.retry(analysisID: analysisID, model: model)
            } catch {
                retryError = localized("compare.error.ai-failed", language: model.language)
            }
        }
    }

    private func changeTitle(_ change: CompareFactChange) -> String {
        let key: String = switch change.kind {
        case .added: "compare.change.added"
        case .removed: "compare.change.removed"
        case .strengthened: "compare.change.strengthened"
        case .weakened: "compare.change.weakened"
        case .exactOrPeaked: "compare.change.exact"
        case .structuralChange: "compare.change.structural"
        case .stable: "compare.change.stable"
        }
        return localized(key, language: model.language)
    }

    private func changeIcon(_ kind: CompareFactChangeKind) -> String {
        switch kind {
        case .added: "plus.circle"
        case .removed: "minus.circle"
        case .strengthened: "arrow.up.right.circle"
        case .weakened: "arrow.down.right.circle"
        case .exactOrPeaked: "scope"
        case .structuralChange: "arrow.triangle.2.circlepath"
        case .stable: "equal.circle"
        }
    }

    private func factSummary(_ fact: CompareFact?) -> String {
        guard let fact else { return "—" }
        let source = displayObject(fact.identity.sourceObject)
        let target = fact.identity.targetObject.map(displayObject)
        let relation = fact.identity.relation.map { relationName($0) }
        var parts = [source]
        if let relation { parts.append(relation) }
        if let target { parts.append(target) }
        if let house = fact.state.house { parts.append(AstroTerms.house(house, language: model.language)) }
        if let sign = fact.state.sign { parts.append(AstroTerms.value("zodiac", sign, language: model.language)) }
        if let orb = fact.state.orb { parts.append(String(format: "%.2f°", orb)) }
        return parts.joined(separator: " · ")
    }

    private func displayObject(_ raw: String) -> String {
        if let body = CelestialBody(rawValue: raw) { return bodyName(body, language: model.language) }
        if raw == "ascendant" { return AstroTerms.value("angles", "ascendant", language: model.language) }
        if raw == "midheaven" { return AstroTerms.value("angles", "midheaven", language: model.language) }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func relationName(_ raw: String) -> String {
        if let aspect = AspectKind(rawValue: raw) { return aspectKindName(aspect, language: model.language) }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = model.language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CompareEvidenceSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = CompareAnalysisStore.shared

    let analysisID: String
    let factIDs: [String]

    private var facts: [CompareFact] {
        guard let analysis = store.analysis(id: analysisID) else { return [] }
        let all = analysis.bundle.baselineFacts
            + analysis.bundle.snapshotAFacts
            + analysis.bundle.snapshotBFacts
            + analysis.bundle.relationshipFacts
        let wanted = Set(factIDs)
        return all.filter { wanted.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(facts) { fact in
                VStack(alignment: .leading, spacing: 6) {
                    Text(fact.identity.factType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline)
                    Text(evidenceDescription(fact))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.text)
                    Text(fact.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(AppTheme.muted)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(localized("compare.evidence", language: model.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("common.done", language: model.language)) { dismiss() }
                }
            }
        }
    }

    private func evidenceDescription(_ fact: CompareFact) -> String {
        var values: [String] = [fact.identity.sourceObject]
        if let relation = fact.identity.relation { values.append(relation) }
        if let target = fact.identity.targetObject { values.append(target) }
        if let sign = fact.state.sign { values.append(AstroTerms.value("zodiac", sign, language: model.language)) }
        if let house = fact.state.house { values.append(AstroTerms.house(house, language: model.language)) }
        if let motion = fact.state.motion { values.append(AstroTerms.value("motions", motion, language: model.language)) }
        if let phase = fact.state.phase { values.append(AstroTerms.value("aspectPhases", phase, language: model.language)) }
        if let orb = fact.state.orb { values.append(String(format: "orb %.2f°", orb)) }
        if let numeric = fact.state.numericValue { values.append(String(format: "%.2f°", numeric)) }
        return values.joined(separator: " · ")
    }
}

struct CompareChartsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = CompareAnalysisStore.shared
    let analysisID: String
    @State private var selectedSide = 0

    private var analysis: CompareAnalysis? { store.analysis(id: analysisID) }

    var body: some View {
        ZStack {
            ScreenBackground()
            if let analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(
                            eyebrow: localized("compare.view-charts", language: model.language).uppercased(),
                            title: analysis.request.type.title(language: model.language),
                            subtitle: localized("compare.cached-charts", language: model.language)
                        )
                        ForEach(sharedCharts(analysis)) { chart in
                            chartCard(chart)
                        }

                        if !sideCharts(analysis, side: 0).isEmpty || !sideCharts(analysis, side: 1).isEmpty {
                            Picker("", selection: $selectedSide) {
                                Text("A · \(analysis.request.subjectA.displayName)").tag(0)
                                Text("B · \(analysis.request.subjectB?.displayName ?? personBLabel)").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("compare-chart-side-picker")
                        }

                        ForEach(sideCharts(analysis, side: selectedSide)) { chart in
                            chartCard(chart)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView(
                    localized("compare.result-unavailable", language: model.language),
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chartCard(_ chart: CompareCachedChart) -> some View {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(localized(chart.labelKey, language: model.language))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                ChartWheelView(
                                    snapshot: chart.snapshot,
                                    reference: chart.reference,
                                    comparisonAspects: chart.comparisonAspects,
                                    language: model.language,
                                    presentation: .compare
                                )
                                .frame(minHeight: 330)
                            }
                            .padding(12)
                            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
    }

    private var personBLabel: String {
        localized("compare.person-b", language: model.language)
    }

    private func sharedCharts(_ analysis: CompareAnalysis) -> [CompareCachedChart] {
        analysis.bundle.cachedCharts.filter { side(for: $0.id) == nil }
    }

    private func sideCharts(_ analysis: CompareAnalysis, side: Int) -> [CompareCachedChart] {
        analysis.bundle.cachedCharts.filter { self.side(for: $0.id) == side }
    }

    private func side(for id: String) -> Int? {
        let value = id.lowercased()
        if value.hasSuffix("-a") || value.contains("person-a") || value.contains("place-a") { return 0 }
        if value.hasSuffix("-b") || value.contains("person-b") || value.contains("place-b") { return 1 }
        return nil
    }
}
