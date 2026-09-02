import AstroCore
import Foundation
import SwiftUI

extension AskView {
    var modeSelection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(localized("navigation.ask", language: model.language))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)

            AskPathHero()

            VStack(alignment: .leading, spacing: 7) {
                Text(localized("ask.what-do-you-want-to-ask", language: model.language))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(localized("ask.choose-one-path-your-question-is-calculated-privately-on-this-device", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            askPrimaryModeCard(
                mode: .yesNo,
                icon: "questionmark.circle.fill",
                title: localized("ask.will-it-happen", language: model.language),
                detail: localized("ask.ask-about-one-specific-outcome", language: model.language)
            )

            HStack(alignment: .top, spacing: 12) {
                askCompactModeCard(
                    mode: .timing,
                    icon: "clock.arrow.circlepath",
                    title: localized("ask.when", language: model.language),
                    detail: localized("ask.when-card-detail", language: model.language)
                )
                askCompactModeCard(
                    mode: .choice,
                    icon: "arrow.triangle.branch",
                    title: localized("ask.which-one", language: model.language),
                    detail: localized("ask.compare-two-to-five-real-options", language: model.language)
                )
            }

            askWideModeCard(
                mode: .bestTime,
                icon: "calendar.badge.clock",
                title: localized("ask.find-the-best-time", language: model.language),
                detail: localized("ask.best-time-card-detail", language: model.language)
            )

            if !askHistory.isEmpty {
                recentQuestionsSection
            }
        }
    }

    var recentQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(localized("ask.recent-questions", language: model.language))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Button(localized("ask.history", language: model.language)) {
                    showAskHistory = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
            }

            VStack(spacing: 0) {
                ForEach(Array(askHistory.prefix(3).enumerated()), id: \.element.id) { index, entry in
                    Button {
                        if entry.session != nil {
                            openHistoryEntry(entry)
                        } else {
                            showAskHistory = true
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.question)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(recentQuestionMetadata(entry))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                if let status = deepAnalysisStatus(entry) {
                                    Label(
                                        localized(status == .pending ? "ask.deep-analysis-running" : "common.retry", language: model.language),
                                        systemImage: status == .pending ? "sparkles" : "arrow.clockwise"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(status == .pending ? AppTheme.violet : AppTheme.coral)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.violet)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if index < min(askHistory.count, 3) - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(AppTheme.panelRaised.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    func askPrimaryModeCard(
        mode: HoraryQuestionMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            select(mode)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    AskModeMiniVisual(mode: mode, icon: icon)
                        .frame(width: 72, height: 66)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(AskCardPressStyle())
        .accessibilityIdentifier("ask-mode-\(mode.rawValue)")
    }

    func askCompactModeCard(
        mode: HoraryQuestionMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            select(mode)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AskModeMiniVisual(mode: mode, icon: icon)
                        .frame(width: 56, height: 42)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(AskCardPressStyle())
        .accessibilityIdentifier("ask-mode-\(mode.rawValue)")
    }

    func askWideModeCard(
        mode: HoraryQuestionMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            select(mode)
        } label: {
            HStack(spacing: 16) {
                AskModeMiniVisual(mode: mode, icon: icon)
                    .frame(width: 72, height: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(AskCardPressStyle())
        .accessibilityIdentifier("ask-mode-\(mode.rawValue)")
    }

    func recentQuestionMetadata(_ entry: AskHistoryEntry) -> String {
        let modeName: String = switch entry.session?.mode ?? HoraryQuestionMode(rawValue: entry.mode) {
        case .yesNo?: localized("ask.will-it-happen", language: model.language)
        case .timing?: localized("ask.when", language: model.language)
        case .choice?: localized("ask.which-one", language: model.language)
        case .bestTime?: localized("ask.find-the-best-time", language: model.language)
        case nil: localized("navigation.ask", language: model.language)
        }
        return modeName + " · " + formattedDate(entry.createdAt, includesTime: false)
    }

    func deepAnalysisStatus(_ entry: AskHistoryEntry) -> AskDeepRecordStatus? {
        guard let session = entry.session else { return nil }
        let fingerprint = AskDeepAIService().sessionFingerprint(session)
        let status = deepAnalysisStore.record(sessionFingerprint: fingerprint)?.status
        return status == .completed ? nil : status
    }
}

struct AskPathHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(time * 1.15) + 1) / 2)
            let drift = CGFloat(sin(time * 0.72)) * 2.2

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.panelRaised.opacity(0.72),
                                AppTheme.violet.opacity(0.035),
                                AppTheme.panel.opacity(0.72),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppTheme.violet.opacity(0.11 + 0.04 * pulse), lineWidth: 1)

                GeometryReader { proxy in
                    let centerX = proxy.size.width / 2
                    let topY: CGFloat = 34
                    let nodeY: CGFloat = 103

                    Canvas { context, _ in
                        let targets = [centerX - 105, centerX - 35, centerX + 35, centerX + 105]
                        for (index, targetX) in targets.enumerated() {
                            var path = Path()
                            path.move(to: CGPoint(x: centerX, y: topY + 13))
                            let direction: CGFloat = targetX < centerX ? -1 : 1
                            path.addCurve(
                                to: CGPoint(x: targetX, y: nodeY),
                                control1: CGPoint(x: centerX + 8 * direction, y: 61),
                                control2: CGPoint(x: targetX - 22 * direction, y: 72)
                            )
                            let branchWave = CGFloat((sin(time * 1.0 + Double(index) * 1.65) + 1) / 2)
                            context.stroke(
                                path,
                                with: .color(AppTheme.violet.opacity(0.18 + 0.20 * branchWave)),
                                lineWidth: 1.15
                            )
                        }
                    }

                    Circle()
                        .fill(AppTheme.violet.opacity(0.05 + 0.04 * pulse))
                        .frame(width: 58 + 8 * pulse, height: 58 + 8 * pulse)
                        .position(x: centerX, y: topY + drift)
                        .blur(radius: 1.5)

                    Image(systemName: "sparkle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .scaleEffect(1 + 0.07 * pulse)
                        .opacity(0.78 + 0.22 * pulse)
                        .position(x: centerX, y: topY + drift)

                    ForEach(Array([-1.5, -0.5, 0.5, 1.5].enumerated()), id: \.offset) { offset, index in
                        let nodeWave = CGFloat(sin(time * 0.82 + Double(offset) * 1.25))
                        let accents = [AppTheme.blue, AppTheme.violet, AppTheme.coral, AppTheme.mint]
                        let accent = accents[offset]
                        ZStack {
                            Circle()
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                                .frame(width: 38, height: 38)
                                .scaleEffect(1 + 0.05 * CGFloat((sin(time + Double(offset)) + 1) / 2))
                            Circle()
                                .fill(accent.opacity(0.14))
                                .frame(width: 25, height: 25)
                            Circle()
                                .fill(accent.opacity(0.78))
                                .frame(width: 6, height: 6)
                        }
                        .position(
                            x: centerX + CGFloat(index) * 70,
                            y: nodeY + (reduceMotion ? 0 : nodeWave * 2.0)
                        )
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: 142)
        .accessibilityHidden(true)
    }
}

private struct AskModeMiniVisual: View {
    let mode: HoraryQuestionMode
    let icon: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Canvas { context, _ in
                    switch mode {
                    case .yesNo:
                        let center = CGPoint(x: width * 0.5, y: height * 0.5)
                        context.stroke(
                            Path(ellipseIn: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)),
                            with: .color(AppTheme.violet.opacity(0.25)),
                            lineWidth: 1.2
                        )
                        var axis = Path()
                        axis.move(to: CGPoint(x: width * 0.18, y: center.y))
                        axis.addLine(to: CGPoint(x: width * 0.82, y: center.y))
                        context.stroke(axis, with: .color(AppTheme.violet.opacity(0.18)), lineWidth: 1)
                    case .timing:
                        var line = Path()
                        line.move(to: CGPoint(x: width * 0.12, y: height * 0.54))
                        line.addLine(to: CGPoint(x: width * 0.88, y: height * 0.54))
                        context.stroke(line, with: .color(AppTheme.blue.opacity(0.30)), lineWidth: 1.2)
                    case .choice:
                        let origin = CGPoint(x: width * 0.22, y: height * 0.52)
                        for targetY in [height * 0.22, height * 0.52, height * 0.82] {
                            var branch = Path()
                            branch.move(to: origin)
                            branch.addCurve(
                                to: CGPoint(x: width * 0.80, y: targetY),
                                control1: CGPoint(x: width * 0.44, y: origin.y),
                                control2: CGPoint(x: width * 0.58, y: targetY)
                            )
                            context.stroke(branch, with: .color(AppTheme.coral.opacity(0.27)), lineWidth: 1)
                        }
                    case .bestTime:
                        var timeline = Path()
                        timeline.move(to: CGPoint(x: width * 0.10, y: height * 0.58))
                        timeline.addLine(to: CGPoint(x: width * 0.90, y: height * 0.58))
                        context.stroke(timeline, with: .color(AppTheme.mint.opacity(0.28)), lineWidth: 1.2)
                        for x in [0.22, 0.48, 0.76] {
                            let rect = CGRect(x: width * x - 3, y: height * 0.58 - 3, width: 6, height: 6)
                            context.fill(Path(ellipseIn: rect), with: .color(AppTheme.mint.opacity(x == 0.48 ? 0.85 : 0.32)))
                        }
                    }
                }

                switch mode {
                case .yesNo:
                    Circle()
                        .fill(AppTheme.violet.opacity(0.16))
                        .frame(width: 31, height: 31)
                        .overlay(
                            Image(systemName: icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.violet)
                        )
                    HStack {
                        Circle().fill(AppTheme.blue.opacity(0.72)).frame(width: 6, height: 6)
                        Spacer()
                        Circle().fill(AppTheme.coral.opacity(0.72)).frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, width * 0.11)
                case .timing:
                    Circle()
                        .fill(AppTheme.blue.opacity(0.78))
                        .frame(width: 8, height: 8)
                        .position(x: width * 0.48, y: height * 0.54)
                    Circle()
                        .stroke(AppTheme.blue.opacity(0.18), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .position(x: width * 0.48, y: height * 0.54)
                case .choice:
                    Circle()
                        .fill(AppTheme.coral.opacity(0.80))
                        .frame(width: 8, height: 8)
                        .position(x: width * 0.22, y: height * 0.52)
                    ForEach([0.22, 0.52, 0.82], id: \.self) { y in
                        Circle()
                            .fill(AppTheme.violet.opacity(0.68))
                            .frame(width: 6, height: 6)
                            .position(x: width * 0.80, y: height * y)
                    }
                case .bestTime:
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.mint)
                        .position(x: width * 0.48, y: height * 0.28)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AskCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.965 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
