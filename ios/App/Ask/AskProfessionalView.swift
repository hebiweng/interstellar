import AstroCore
import SwiftUI

struct HoraryProfessionalView: View {
    let session: HorarySession
    let overlay: HoraryOverlay
    let language: AppLanguage

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ChartWheelView(
                    snapshot: session.snapshot,
                    reference: nil,
                    comparisonAspects: [],
                    language: language,
                    horaryOverlay: overlay,
                    presentation: .ask
                )
                .padding(10)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

                AspectChartView(
                    aspects: HoraryEngine.validTraditionalAspects(in: session.snapshot),
                    movingPoints: session.snapshot.points,
                    referencePoints: [],
                    language: language,
                    comparison: false
                )

                ForEach(Array(analyses.enumerated()), id: \.offset) { _, analysis in
                    analysisBlock(analysis)
                }
            }
            .padding(18)
        }
        .background(ScreenBackground())
        .navigationTitle(localized("ask.chart-analysis", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var analyses: [HoraryAnalysis] {
        if session.mode == .choice {
            return session.choices.map(\.analysis)
        }
        return [session.analysis].compactMap { $0 }
    }

    private func analysisBlock(_ analysis: HoraryAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                localizedTemplate("dynamic.d9e7f60cb4", substitutions: ["value1": String(describing: analysis.targetHouse)], language: language)
            )
            .font(.headline)
            .foregroundStyle(AppTheme.text)

            professionalRow(
                localized("ask.querent-ruler", language: language),
                bodyName(analysis.querentRuler, language: language)
            )
            professionalRow(
                localized("ask.target-ruler", language: language),
                bodyName(analysis.targetRuler, language: language)
            )
            if let judgment = analysis.judgment {
                professionalRow(
                    localized("ask.judgment", language: language),
                    judgmentLabel(judgment.verdict)
                )
                professionalRow(
                    localized("ask.perfection", language: language),
                    perfectionLabel(judgment.perfection)
                )
            }
            professionalRow(
                localized("ask.connection", language: language),
                analysis.relationship.map {
                    "\(aspectKindName($0.kind, language: language)) · \(phaseLabel($0.phase, language: language)) · \(formatOrb($0.orbDegrees))"
                } ?? localized("ask.no-major-aspect-in-orb", language: language)
            )
            professionalRow(
                localized("ask.reception", language: language),
                receptionLabel(analysis)
            )
            professionalRow(
                localized("insight.natal.moon", language: language),
                analysis.moon.isVoidOfCourse
                    ? localized("ask.void-of-course", language: language)
                    : nextMoonAspect(analysis)
            )

            if let considerations = analysis.judgment?.considerations {
                Divider().overlay(AppTheme.line)
                Text(localized("ask.considerations", language: language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                professionalRow(
                    localized("ask.judgment-clarity", language: language),
                    reliabilityLabel(considerations.reliability)
                )
                if let radicality = considerations.radicality {
                    professionalRow(
                        localized("ask.radicality", language: language),
                        radicalityLabel(radicality.status)
                    )
                }
                if let planetaryHour = considerations.planetaryHour {
                    professionalRow(
                        localized("ask.planetary-hour", language: language),
                        planetaryHourLabel(planetaryHour)
                    )
                }
                ForEach(considerations.flags) { flag in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(flag.severity == .strongCaution ? AppTheme.coral : AppTheme.amber)
                            .frame(width: 7, height: 7)
                        Text(considerationLabel(flag.kind))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if analysis.judgment == nil {
                Divider().overlay(AppTheme.line)
                ForEach(analysis.components) { component in
                    HStack {
                        Text(componentLabel(component.id))
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Text(String(format: "%+.1f", component.value))
                            .font(AppTypography.label.monospacedDigit())
                            .foregroundStyle(component.value < 0 ? AppTheme.coral : AppTheme.mint)
                    }
                }
                HStack {
                    Text(localized("ask.total", language: language))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(analysis.score.rounded()))")
                        .font(.title3.bold().monospacedDigit())
                }
                .foregroundStyle(AppTheme.text)
            }

            if analysis.judgment != nil {
                HoraryProfessionalEvidenceView(
                    analysis: analysis,
                    session: session,
                    language: language
                )
            }
        }
        .cardSurface()
    }

    private func professionalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(AppTypography.label)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func receptionLabel(_ analysis: HoraryAnalysis) -> String {
        if analysis.receptionFromQuerent.isPresent, analysis.receptionFromTarget.isPresent {
            return localized("ask.mutual-reception", language: language)
        }
        if analysis.receptionFromQuerent.isPresent || analysis.receptionFromTarget.isPresent {
            return localized("ask.one-way-reception", language: language)
        }
        return localized("ask.no-major-reception", language: language)
    }

    private func judgmentLabel(_ verdict: HoraryJudgmentVerdict) -> String {
        switch verdict {
        case .yes: localized("common.yes", language: language)
        case .no: localized("common.no", language: language)
        case .noClearJudgment: localized("ask.no-clear-judgment", language: language)
        }
    }

    private func perfectionLabel(_ assessment: HoraryPerfectionAssessment) -> String {
        if let path = assessment.primaryPath, assessment.status == .completes {
            let distance = " · " + formatOrb(path.distanceDegrees)
            let mediator = path.mediator.map { " · " + bodyName($0, language: language) } ?? ""
            switch path.kind {
            case .direct:
                return localized("ask.perfection.direct", language: language) + distance
            case .translation:
                return localized("ask.perfection.translation", language: language) + mediator + distance
            case .collection:
                return localized("ask.perfection.collection", language: language) + mediator + distance
            }
        }
        switch assessment.status {
        case .prevented: return localized("ask.perfection.prevented", language: language)
        case .delayed: return localized("ask.perfection.delayed", language: language)
        case .none, .ambiguous: return localized("ask.perfection.none", language: language)
        case .completes: return localized("ask.perfection.direct", language: language)
        }
    }

    private func nextMoonAspect(_ analysis: HoraryAnalysis) -> String {
        guard let aspect = analysis.moon.nextAspect else {
            return localized("ask.no-next-major-aspect", language: language)
        }
        let target = CelestialBody(rawValue: aspect.secondID)
            .map { bodyName($0, language: language) } ?? aspect.secondID
        let hours = analysis.moon.hoursUntilNextAspect.map { Int($0.rounded()) }
        return "\(aspectKindName(aspect.kind, language: language)) \(target)"
            + (hours.map { LocalizedFormatters.hoursDuration($0, language: language) } ?? "")
    }

    private func reliabilityLabel(_ reliability: HoraryJudgmentReliability) -> String {
        switch reliability {
        case .high: localized("ask.reliability.high", language: language)
        case .moderate: localized("ask.reliability.moderate", language: language)
        case .caution: localized("ask.reliability.caution", language: language)
        }
    }

    private func radicalityLabel(_ status: HoraryRadicalityStatus) -> String {
        switch status {
        case .supported: localized("ask.radicality.supported", language: language)
        case .notEstablished: localized("ask.radicality.not-established", language: language)
        case .unavailable: localized("ask.radicality.unavailable", language: language)
        }
    }

    private func planetaryHourLabel(_ assessment: HoraryPlanetaryHourAssessment) -> String {
        guard assessment.availability == .resolved,
              let ruler = assessment.hourRuler,
              let number = assessment.hourNumber
        else {
            return localized("ask.planetary-hour-unavailable", language: language)
        }
        let agreement: String
        switch assessment.agreement {
        case .samePlanet, .sameTriplicity, .sameNature:
            agreement = localized("ask.planetary-hour-agrees", language: language)
        case .none:
            agreement = localized("ask.planetary-hour-differs", language: language)
        case .unavailable:
            agreement = localized("ask.planetary-hour-unavailable", language: language)
        }
        return "\(bodyName(ruler, language: language)) · #\(number) · \(agreement)"
    }

    private func considerationLabel(_ kind: HoraryConsiderationKind) -> String {
        switch kind {
        case .planetaryHourDiscordant: localized("ask.consideration.planetaryHourDiscordant", language: language)
        case .earlyAscendant: localized("ask.consideration.earlyAscendant", language: language)
        case .lateAscendant: localized("ask.consideration.lateAscendant", language: language)
        case .moonLateDegrees: localized("ask.consideration.moonLateDegrees", language: language)
        case .moonViaCombusta: localized("ask.consideration.moonViaCombusta", language: language)
        case .moonVoidOfCourse: localized("ask.consideration.moonVoidOfCourse", language: language)
        case .saturnInAscendant: localized("ask.consideration.saturnInAscendant", language: language)
        case .saturnInSeventh: localized("ask.consideration.saturnInSeventh", language: language)
        case .ascendantLordCombust: localized("ask.consideration.ascendantLordCombust", language: language)
        case .seventhLordRetrograde: localized("ask.consideration.seventhLordRetrograde", language: language)
        case .seventhLordInFall: localized("ask.consideration.seventhLordInFall", language: language)
        case .seventhCuspAfflicted: localized("ask.consideration.seventhCuspAfflicted", language: language)
        case .seventhLordUnfortunate: localized("ask.consideration.seventhLordUnfortunate", language: language)
        case .seventhLordInMaleficTerm: localized("ask.consideration.seventhLordInMaleficTerm", language: language)
        case .saturnInTenthUnfortunate: localized("ask.consideration.saturnInTenthUnfortunate", language: language)
        case .marsInTenthUnfortunate: localized("ask.consideration.marsInTenthUnfortunate", language: language)
        case .southNodeInTenth: localized("ask.consideration.southNodeInTenth", language: language)
        }
    }

    private func componentLabel(_ id: String) -> String {
        switch id {
        case "significator-relationship": localized("ask.fact.significator-relationship", language: language)
        case "reception": localized("ask.reception", language: language)
        case "moon", "moon-condition": localized("ask.fact.moon-condition", language: language)
        case "strength": localized("ask.fact.planet-strength", language: language)
        case "obstruction": localized("ask.fact.obstructions", language: language)
        case "target-strength": localized("ask.fact.target-ruler-strength", language: language)
        case "ascendant-strength": localized("ask.fact.ascendant-ruler", language: language)
        case "benefic-support": localized("ask.fact.benefic-support", language: language)
        case "applying-connection": localized("ask.fact.applying-connection", language: language)
        case "risk": localized("ask.fact.risk", language: language)
        default: id
        }
    }
}
