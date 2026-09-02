import AstroCore
import SwiftUI

extension AskView {
    func resultView(_ session: HorarySession) -> some View {
        let overlay = overlay(for: session)
        return VStack(alignment: .leading, spacing: 18) {
            ScreenTitle(
                eyebrow: localized("ask.ask-the-chart", language: model.language),
                title: localized("ask.your-answer", language: model.language),
                subtitle: formattedSessionDate(session)
            )

            resultHero(session)

            ChartWheelView(
                snapshot: session.snapshot,
                reference: nil,
                comparisonAspects: [],
                language: model.language,
                horaryOverlay: overlay,
                presentation: .ask
            )
            .padding(10)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

            if session.mode == .choice {
                choiceRanking(session.choices)
            } else if session.mode == .timing {
                if let timing = session.timingResult {
                    lillyTiming(timing)
                } else {
                    timingRanking(session.timingCandidates)
                }
            } else if session.mode == .bestTime {
                electionTimingRanking(session.electionCandidates)
            }

            resultCards(session)

            AskDeepAnalysisSection(session: session)

            NavigationLink {
                HoraryProfessionalView(session: session, overlay: overlay, language: model.language)
            } label: {
                Label(
                    localized("ask.view-chart-analysis", language: model.language),
                    systemImage: "chart.xyaxis.line"
                )
                .font(.headline)
                .foregroundStyle(AppTheme.violet)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(
                session.mode == .timing
                    ? localized("ask.timing-consumer-note", language: model.language)
                    : (session.mode == .bestTime
                        ? localized("ask.best-time-consumer-note", language: model.language)
                        : localized("ask.support-note", language: model.language))
            )
            .font(AppTypography.supporting)
            .foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func resultHero(_ session: HorarySession) -> some View {
        switch session.mode {
        case .yesNo:
            judgmentResultHero(session: session)
        case .choice:
            choiceResultHero(session: session)
        case .timing:
            if let timing = session.timingResult {
                lillyTimingHero(session: session, timing: timing)
            } else {
                legacyTimingHero(session: session)
            }
        case .bestTime:
            bestTimeSuitabilityHero(session: session)
        }
    }

    func lillyTimingHero(session: HorarySession, timing: HoraryTimingResult) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10))
                Circle()
                    .stroke(AppTheme.violet.opacity(0.24), lineWidth: 1.5)
                Image(systemName: timing.status == .indicated ? "clock.badge.checkmark" : "clock.badge.questionmark")
                    .font(AppTypography.scaled(32, weight: .medium))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(width: 94, height: 94)

            VStack(alignment: .leading, spacing: 7) {
                Text(timingHistoryTitle(timing))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !session.question.trimmed.isEmpty {
                    Text(session.question)
                        .font(AppTypography.summary)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
    }

    func lillyTiming(_ timing: HoraryTimingResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("ask.timing-reading", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if timing.status == .indicated {
                if let units = timing.symbolicUnits {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(String(format: "%.1f°", units))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(AppTheme.violet)
                        Text(localized("ask.to-perfection", language: model.language))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(timing.scales, id: \.rawValue) { scale in
                        Label(timingScaleLabel(scale), systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                }

                if timing.isMixed {
                    Text(localized("ask.timing-mixed-explanation", language: model.language))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(localized("ask.timing-no-promise", language: model.language))
                    .font(AppTypography.summary)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }

    func resultCards(_ session: HorarySession) -> some View {
        let cards: [AskResultCard]
        do {
            cards = try AskContentComposer.cards(
                for: session,
                language: model.language
            )
        } catch {
            return AnyView(
                Label(
                    localized("ask.result-explanations-are-unavailable", language: model.language),
                    systemImage: "exclamationmark.triangle"
                )
                .font(AppTypography.summary)
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            )
        }
        return AnyView(
            VStack(spacing: 12) {
                ForEach(cards) { card in
                    DisclosureGroup {
                        Text(card.detail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: card.icon)
                                .font(.title3)
                                .foregroundStyle(AppTheme.violet)
                                .frame(width: 28)
                            Text(card.summary)
                                .font(AppTypography.summary)
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .tint(AppTheme.violet)
                    .cardSurface()
                }
            }
        )
    }


    func overlay(for session: HorarySession) -> HoraryOverlay {
        var houses: Set<Int> = [1]
        var labels: [CelestialBody: [String]] = [:]
        var aspects: Set<String> = []

        func append(_ label: String, for body: CelestialBody) {
            var values = labels[body, default: []]
            if !values.contains(label) { values.append(label) }
            labels[body] = values
        }

        switch session.mode {
        case .yesNo, .timing, .bestTime:
            if let analysis = session.analysis {
                houses.insert(analysis.targetHouse)
                append(localized("ask.you", language: model.language), for: analysis.querentRuler)
                append(
                    (session.mode == .timing || session.mode == .bestTime)
                        ? localized("ask.goal", language: model.language)
                        : localized("ask.answer", language: model.language),
                    for: analysis.targetRuler
                )
                if let relationship = analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        case .choice:
            if let first = session.choices.first {
                append(localized("ask.you", language: model.language), for: first.analysis.querentRuler)
            }
            for choice in session.choices {
                houses.insert(choice.house)
                append(
                    "\(String(UnicodeScalar(65 + choice.originalIndex)!)) · \(choice.label)",
                    for: choice.ruler
                )
                if let relationship = choice.analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        }
        return HoraryOverlay(
            highlightedHouses: houses,
            planetLabels: labels.mapValues { $0.joined(separator: " / ") },
            keyAspectIDs: aspects
        )
    }

    func formattedSessionDate(_ session: HorarySession) -> String {
        "\(formattedDate(session.createdAt, includesTime: true)) · \(session.locationName)"
    }

    func formattedDate(_ date: Date, includesTime: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = includesTime ? .short : .none
        return formatter.string(from: date)
    }

    func formattedInterval(_ candidate: ElectionTimingCandidate) -> String {
        let start = formattedDate(candidate.interval.start, includesTime: false)
        let end = formattedDate(
            candidate.interval.end.addingTimeInterval(-1),
            includesTime: false
        )
        return start == end ? start : "\(start) – \(end)"
    }
}
