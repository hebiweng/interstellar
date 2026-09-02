import AstroCore
import SwiftUI

extension AskView {
    func judgmentResultHero(session: HorarySession) -> some View {
        let analysis = session.analysis
        let verdict = analysis?.judgment?.verdict
        let reliability = analysis?.judgment?.considerations?.reliability
        let icon: String = switch verdict {
        case .yes: "checkmark"
        case .no: "xmark"
        case .noClearJudgment, nil: "questionmark"
        }
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10))
                Circle()
                    .stroke(AppTheme.violet.opacity(0.24), lineWidth: 1.5)
                Image(systemName: icon)
                    .font(AppTypography.scaled(32, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(width: 94, height: 94)

            VStack(alignment: .leading, spacing: 7) {
                Text(analysis.map(judgmentLabel) ?? localized("ask.still-unclear", language: model.language))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if let reliability {
                    Text(localized("ask.judgment-clarity", language: model.language) + ": " + judgmentReliabilityText(reliability))
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.muted)
                }
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

    func choiceResultHero(session: HorarySession) -> some View {
        let first = session.choices.first
        let hasClearLead = first?.isTiedForLead == false
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10))
                Circle()
                    .stroke(AppTheme.violet.opacity(0.24), lineWidth: 1.5)
                Image(systemName: hasClearLead ? "flag.checkered" : "arrow.triangle.branch")
                    .font(AppTypography.scaled(30, weight: .medium))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(width: 94, height: 94)

            VStack(alignment: .leading, spacing: 7) {
                Text(hasClearLead ? (first?.label ?? localized("ask.no-clear-option", language: model.language)) : localized("ask.no-clear-option", language: model.language))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if first != nil {
                    Text(hasClearLead ? localized("ask.leading", language: model.language) : localized("ask.close-call", language: model.language))
                        .font(AppTypography.label)
                        .foregroundStyle(hasClearLead ? AppTheme.violet : AppTheme.amber)
                }
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

    func bestTimeSuitabilityHero(session: HorarySession) -> some View {
        let score = session.electionCandidates.first?.assessment.suitabilityScore ?? 0
        let label = primaryLabel(session)
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppTheme.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        suitabilityColor(score),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score.rounded())) / 100")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    Text(localized("ask.best-time-suitability", language: model.language))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 7) {
                Text(label)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
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

    func legacyTimingHero(session: HorarySession) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.violet.opacity(0.10))
                Circle()
                    .stroke(AppTheme.violet.opacity(0.24), lineWidth: 1.5)
                Image(systemName: "clock.badge.questionmark")
                    .font(AppTypography.scaled(30, weight: .medium))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(width: 94, height: 94)

            VStack(alignment: .leading, spacing: 7) {
                Text(primaryLabel(session))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(localized("ask.recommended-window", language: model.language))
                    .font(AppTypography.label)
                    .foregroundStyle(AppTheme.muted)
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

    func choiceRanking(_ choices: [HoraryChoiceResult]) -> some View {
        let close = choices.first?.isTiedForLead == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("ask.option-ranking", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if close {
                    Text(localized("ask.close-call", language: model.language))
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.amber)
                }
            }
            ForEach(Array(choices.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text(String(UnicodeScalar(65 + item.originalIndex)!))
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.violet.opacity(0.12), in: Circle())
                    Text(item.label)
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if item.isTiedForLead {
                        Text(localized("ask.close-call", language: model.language))
                            .font(AppTypography.supporting.weight(.semibold))
                            .foregroundStyle(AppTheme.amber)
                    } else if index == 0 {
                        Text(localized("ask.leading", language: model.language))
                            .font(AppTypography.supporting.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                    } else {
                        Text("#\(index + 1)")
                            .font(AppTypography.supporting.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(minHeight: 42)
                .padding(.vertical, 3)
            }
        }
        .cardSurface()
    }

    func timingRanking(_ candidates: [ElectionTimingCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("ask.recommended-window", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                HStack(spacing: 12) {
                    Image(systemName: index == 0 ? "clock.fill" : "calendar")
                        .foregroundStyle(index == 0 ? AppTheme.violet : AppTheme.muted)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedInterval(candidate))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        Text(localized("ask.peak", language: model.language) + formattedDate(candidate.peakDate, includesTime: false))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .frame(minHeight: 48)
            }
        }
        .cardSurface()
    }

    func electionTimingRanking(_ candidates: [ElectionTimingCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("ask.best-timing", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                HStack(spacing: 12) {
                    Image(systemName: index == 0 ? "star.fill" : "calendar")
                        .foregroundStyle(index == 0 ? AppTheme.amber : AppTheme.violet)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedInterval(candidate))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        Text(localized("ask.peak", language: model.language) + formattedDate(candidate.peakDate, includesTime: false))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(localized("ask.best-time-suitability", language: model.language))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                        Text("\(Int(candidate.assessment.suitabilityScore.rounded())) / 100")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                    }
                }
                .frame(minHeight: 52)
            }
        }
        .cardSurface()
    }

    func primaryLabel(_ session: HorarySession) -> String {
        switch session.mode {
        case .yesNo:
            guard let analysis = session.analysis else {
                return localized("ask.still-unclear", language: model.language)
            }
            return judgmentLabel(analysis)
        case .choice:
            guard let first = session.choices.first, !first.isTiedForLead else {
                return localized("ask.no-clear-option", language: model.language)
            }
            return first.label
        case .timing:
            if let timing = session.timingResult {
                return timingHistoryTitle(timing)
            }
            guard let first = session.timingCandidates.first else {
                return localized("ask.no-timing-found", language: model.language)
            }
            return formattedInterval(first)
        case .bestTime:
            guard let first = session.electionCandidates.first else {
                return localized("ask.no-timing-found", language: model.language)
            }
            return formattedInterval(first)
        }
    }

    func suitabilityColor(_ score: Double) -> Color {
        if score >= 65 { return AppTheme.mint }
        if score >= 45 { return AppTheme.amber }
        return AppTheme.coral
    }

    func judgmentLabel(_ analysis: HoraryAnalysis) -> String {
        switch analysis.judgment?.verdict {
        case .yes: localized("ask.likely-yes", language: model.language)
        case .no: localized("ask.likely-no", language: model.language)
        case .noClearJudgment, nil: localized("ask.mixed", language: model.language)
        }
    }

    func judgmentReliabilityText(_ reliability: HoraryJudgmentReliability) -> String {
        switch reliability {
        case .high: localized("ask.reliability.high", language: model.language)
        case .moderate: localized("ask.reliability.moderate", language: model.language)
        case .caution: localized("ask.reliability.caution", language: model.language)
        }
    }

}
