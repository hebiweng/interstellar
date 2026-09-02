import AstroCore
import Foundation
import SwiftUI

struct HoraryProfessionalEvidenceView: View {
    let analysis: HoraryAnalysis
    let session: HorarySession
    let language: AppLanguage

    var body: some View {
        Group {
            if analysis.querentFortitude != nil || analysis.targetFortitude != nil {
                Divider().overlay(AppTheme.line)
                Text(localized("ask.professional.lilly-fortitude", language: language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                if let querentFortitude = analysis.querentFortitude {
                    fortitudeEvidence(
                        querentFortitude,
                        title: localized("ask.professional.querent-fortitude", language: language)
                    )
                }
                if let targetFortitude = analysis.targetFortitude {
                    fortitudeEvidence(
                        targetFortitude,
                        title: localized("ask.professional.target-fortitude", language: language)
                    )
                }
            }

            if let judgment = analysis.judgment, !judgment.perfection.interruptions.isEmpty {
                Divider().overlay(AppTheme.line)
                Text(localized("ask.professional.interruptions", language: language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                perfectionInterruptionEvidence(judgment.perfection.interruptions)
            }
        }
    }

    @ViewBuilder
    private func fortitudeEvidence(
        _ assessment: HoraryFortitudeAssessment,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTypography.label)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(String(format: "%+d", assessment.total))
                    .font(AppTypography.label.bold().monospacedDigit())
                    .foregroundStyle(assessment.total < 0 ? AppTheme.coral : AppTheme.mint)
            }

            fortitudeCategoryEvidence(
                localized("ask.professional.essential-fortitudes", language: language),
                factors: assessment.essentialFortitudes
            )
            fortitudeCategoryEvidence(
                localized("ask.professional.essential-debilities", language: language),
                factors: assessment.essentialDebilities
            )
            fortitudeCategoryEvidence(
                localized("ask.professional.accidental-fortitudes", language: language),
                factors: assessment.accidentalFortitudes
            )
            fortitudeCategoryEvidence(
                localized("ask.professional.accidental-debilities", language: language),
                factors: assessment.accidentalDebilities
            )
        }
        .padding(12)
        .background(AppTheme.panel.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line))
    }

    @ViewBuilder
    private func fortitudeCategoryEvidence(
        _ title: String,
        factors: [HoraryFortitudeFactor]
    ) -> some View {
        if !factors.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(String(format: "%+d", factors.reduce(0) { $0 + $1.points }))
                        .font(AppTypography.supporting.monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                }
                ForEach(factors) { factor in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(humanizedRule(factor.rule.rawValue))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(String(format: "%+d", factor.points))
                            .font(AppTypography.supporting.monospacedDigit())
                            .foregroundStyle(factor.points < 0 ? AppTheme.coral : AppTheme.mint)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func perfectionInterruptionEvidence(
        _ interruptions: [HoraryPerfectionInterruption]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(interruptions.enumerated()), id: \.offset) { _, interruption in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(interruptionLabel(interruption.kind))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(bodyName(interruption.body, language: language))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Text(interruptionDate(interruption.date))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(10)
                .background(AppTheme.panel.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func interruptionLabel(_ kind: HoraryInterruptionKind) -> String {
        switch kind {
        case .signChange: localized("ask.professional.interruption.sign-change", language: language)
        case .refranation: localized("ask.professional.interruption.refranation", language: language)
        case .prohibition: localized("ask.professional.interruption.prohibition", language: language)
        case .frustration: localized("ask.professional.interruption.frustration", language: language)
        }
    }

    private func interruptionDate(_ date: Date) -> String {
        let timeZone = TimeZone(identifier: session.timezoneID) ?? .current
        return "\(LocalizedFormatters.shortDateWithYear(date, language: language, timeZone: timeZone)) · "
            + LocalizedFormatters.time(date, language: language, timeZone: timeZone)
    }

    private func humanizedRule(_ rawValue: String) -> String {
        let spaced = rawValue.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
