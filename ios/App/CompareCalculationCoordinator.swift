import AstroCore
import Foundation

@MainActor
final class CompareCalculationCoordinator {
    private let chartService: AppChartCalculationService
    private let advancedService: AppAdvancedChartCalculationService
    private let relationshipService: AppRelationshipChartCalculationService

    init(
        chartService: AppChartCalculationService = AppChartCalculationService(),
        advancedService: AppAdvancedChartCalculationService = AppAdvancedChartCalculationService(),
        relationshipService: AppRelationshipChartCalculationService = AppRelationshipChartCalculationService()
    ) {
        self.chartService = chartService
        self.advancedService = advancedService
        self.relationshipService = relationshipService
    }

    func calculate(
        request rawRequest: CompareRequest,
        calculator: SwissEphemerisCalculator,
        onStage: ((CompareAnalysisStage) -> Void)? = nil
    ) async throws -> CompareCalculationBundle {
        let request = try rawRequest.validated()
        onStage?(.calculatingCharts)
        let bundle: CompareCalculationBundle
        switch request.type {
        case .meOverTime:
            bundle = try await calculateMeOverTime(request: request, calculator: calculator, onStage: onStage)
        case .twoPeople:
            bundle = try await calculateTwoPeople(request: request, calculator: calculator, onStage: onStage)
        case .twoPlaces:
            bundle = try await calculateTwoPlaces(request: request, calculator: calculator, onStage: onStage)
        case .relationshipOverTime:
            bundle = try await calculateRelationshipOverTime(request: request, calculator: calculator, onStage: onStage)
        }
        return bundle
    }

    private func calculateMeOverTime(
        request: CompareRequest,
        calculator: SwissEphemerisCalculator,
        onStage: ((CompareAnalysisStage) -> Void)? = nil
    ) async throws -> CompareCalculationBundle {
        guard let dateA = request.dateA, let dateB = request.dateB else {
            throw CompareValidationError.missingDates
        }
        let profile = request.subjectA.profile
        let location = ComparePlace.profileLocation(profile).location
        let natal = try await chartService.calculateThemeChart(
            chart: .natal,
            profile: profile,
            targetDate: dateB,
            location: location,
            preset: request.preset,
            calculator: calculator
        )
        let a = try await timeSnapshot(
            profile: profile,
            subjectID: request.subjectA.id,
            date: dateA,
            location: location,
            preset: request.preset,
            locale: request.locale,
            calculator: calculator,
            suffix: "a"
        )
        let b = try await timeSnapshot(
            profile: profile,
            subjectID: request.subjectA.id,
            date: dateB,
            location: location,
            preset: request.preset,
            locale: request.locale,
            calculator: calculator,
            suffix: "b"
        )
        let baselineFacts = CompareFactBuilder.chartFacts(technique: "natal", result: natal)
        onStage?(.comparingChanges)
        return CompareCalculationBundle(
            compareType: .meOverTime,
            baselineFacts: baselineFacts,
            snapshotAFacts: a.facts,
            snapshotBFacts: b.facts,
            relationshipFacts: [],
            diff: CompareDiffEngine.diff(from: a.facts, to: b.facts),
            cachedCharts: [cached(id: "natal", labelKey: "compare.chart.natal", technique: "natal", result: natal)] + a.charts + b.charts
        )
    }

    private func calculateTwoPeople(
        request: CompareRequest,
        calculator: SwissEphemerisCalculator,
        onStage: ((CompareAnalysisStage) -> Void)? = nil
    ) async throws -> CompareCalculationBundle {
        guard let subjectB = request.subjectB else {
            throw CompareValidationError.missingSecondSubject
        }
        let date = request.dateB ?? Date()
        let locationA = ComparePlace.profileLocation(request.subjectA.profile).location
        let locationB = ComparePlace.profileLocation(subjectB.profile).location
        let natalA = try await chartService.calculateThemeChart(
            chart: .natal,
            profile: request.subjectA.profile,
            targetDate: date,
            location: locationA,
            preset: request.preset,
            calculator: calculator
        )
        let natalB = try await chartService.calculateThemeChart(
            chart: .natal,
            profile: subjectB.profile,
            targetDate: date,
            location: locationB,
            preset: request.preset,
            calculator: calculator
        )
        let synastry = try await relationship(
            kind: .synastryA,
            request: request,
            targetDate: nil,
            calculator: calculator
        )
        let reverseSynastry = try await relationship(
            kind: .synastryB,
            request: request,
            targetDate: nil,
            calculator: calculator
        )
        let factsA = CompareFactBuilder.chartFacts(
            technique: "natal",
            result: natalA,
            identityScope: "person_a"
        )
        let factsB = CompareFactBuilder.chartFacts(
            technique: "natal",
            result: natalB,
            identityScope: "person_b"
        )
        let relationshipFacts = CompareFactBuilder.relationshipFacts(artifact: synastry)
            + CompareFactBuilder.relationshipFacts(artifact: reverseSynastry)
        onStage?(.comparingChanges)
        return CompareCalculationBundle(
            compareType: .twoPeople,
            baselineFacts: [],
            snapshotAFacts: factsA,
            snapshotBFacts: factsB,
            relationshipFacts: relationshipFacts,
            diff: CompareDiff(),
            cachedCharts: [
                cached(id: "person-a", labelKey: "compare.chart.person-a", technique: "natal", result: natalA),
                cached(id: "person-b", labelKey: "compare.chart.person-b", technique: "natal", result: natalB),
                cached(id: "synastry", labelKey: "compare.chart.synastry", artifact: synastry),
            ]
        )
    }

    private func calculateTwoPlaces(
        request: CompareRequest,
        calculator: SwissEphemerisCalculator,
        onStage: ((CompareAnalysisStage) -> Void)? = nil
    ) async throws -> CompareCalculationBundle {
        guard let placeA = request.placeA, let placeB = request.placeB else {
            throw CompareValidationError.missingPlaces
        }
        let profile = request.subjectA.profile
        let natal = try await chartService.calculateThemeChart(
            chart: .natal,
            profile: profile,
            targetDate: profile.birthDateUTC,
            location: ComparePlace.profileLocation(profile).location,
            preset: request.preset,
            calculator: calculator
        )
        let relocationA = try await relocation(
            profile: profile,
            subjectID: request.subjectA.id,
            place: placeA,
            preset: request.preset,
            locale: request.locale,
            calculator: calculator
        )
        let relocationB = try await relocation(
            profile: profile,
            subjectID: request.subjectA.id,
            place: placeB,
            preset: request.preset,
            locale: request.locale,
            calculator: calculator
        )
        let baselineFacts = CompareFactBuilder.chartFacts(technique: "natal", result: natal)
        let factsA = CompareFactBuilder.chartFacts(
            technique: "relocation",
            result: relocationA,
            includeAngles: true,
            includeAngleAspects: true,
            includeHouseEmphasis: true
        )
        let factsB = CompareFactBuilder.chartFacts(
            technique: "relocation",
            result: relocationB,
            includeAngles: true,
            includeAngleAspects: true,
            includeHouseEmphasis: true
        )
        onStage?(.comparingChanges)
        return CompareCalculationBundle(
            compareType: .twoPlaces,
            baselineFacts: baselineFacts,
            snapshotAFacts: factsA,
            snapshotBFacts: factsB,
            relationshipFacts: [],
            diff: CompareDiffEngine.diff(from: factsA, to: factsB),
            cachedCharts: [
                cached(id: "natal", labelKey: "compare.chart.natal", technique: "natal", result: natal),
                cached(id: "place-a", labelKey: "compare.chart.place-a", technique: "relocation", result: relocationA),
                cached(id: "place-b", labelKey: "compare.chart.place-b", technique: "relocation", result: relocationB),
            ]
        )
    }

    private func calculateRelationshipOverTime(
        request: CompareRequest,
        calculator: SwissEphemerisCalculator,
        onStage: ((CompareAnalysisStage) -> Void)? = nil
    ) async throws -> CompareCalculationBundle {
        guard request.subjectB != nil else { throw CompareValidationError.missingSecondSubject }
        guard let dateA = request.dateA, let dateB = request.dateB else {
            throw CompareValidationError.missingDates
        }

        let synastry = try await relationship(kind: .synastryA, request: request, targetDate: nil, calculator: calculator)
        let reverseSynastry = try await relationship(kind: .synastryB, request: request, targetDate: nil, calculator: calculator)
        let composite = try await relationship(kind: .composite, request: request, targetDate: nil, calculator: calculator)
        let transitA = try await relationship(kind: .compositeTransit, request: request, targetDate: dateA, calculator: calculator)
        let progressionA = try await relationship(kind: .compositeSecondaryCompare, request: request, targetDate: dateA, calculator: calculator)
        let transitB = try await relationship(kind: .compositeTransit, request: request, targetDate: dateB, calculator: calculator)
        let progressionB = try await relationship(kind: .compositeSecondaryCompare, request: request, targetDate: dateB, calculator: calculator)

        let relationshipFacts = CompareFactBuilder.relationshipFacts(artifact: synastry)
            + CompareFactBuilder.relationshipFacts(artifact: reverseSynastry)
            + CompareFactBuilder.relationshipFacts(artifact: composite)
        let factsA = CompareFactBuilder.relationshipFacts(artifact: transitA)
            + CompareFactBuilder.relationshipFacts(artifact: progressionA)
        let factsB = CompareFactBuilder.relationshipFacts(artifact: transitB)
            + CompareFactBuilder.relationshipFacts(artifact: progressionB)

        onStage?(.comparingChanges)
        return CompareCalculationBundle(
            compareType: .relationshipOverTime,
            baselineFacts: [],
            snapshotAFacts: factsA,
            snapshotBFacts: factsB,
            relationshipFacts: relationshipFacts,
            diff: CompareDiffEngine.diff(from: factsA, to: factsB),
            cachedCharts: [
                cached(id: "synastry", labelKey: "compare.chart.synastry", artifact: synastry),
                cached(id: "composite", labelKey: "compare.chart.composite", artifact: composite),
                cached(id: "relationship-transit-a", labelKey: "compare.chart.relationship-transit-a", artifact: transitA),
                cached(id: "composite-secondary-a", labelKey: "compare.chart.composite-secondary-a", artifact: progressionA),
                cached(id: "relationship-transit-b", labelKey: "compare.chart.relationship-transit-b", artifact: transitB),
                cached(id: "composite-secondary-b", labelKey: "compare.chart.composite-secondary-b", artifact: progressionB),
            ]
        )
    }

    private func timeSnapshot(
        profile: UserProfile,
        subjectID: String,
        date: Date,
        location: ChartLocationSelection,
        preset: CalculationPreset,
        locale: AppLanguage,
        calculator: SwissEphemerisCalculator,
        suffix: String
    ) async throws -> (facts: [CompareFact], charts: [CompareCachedChart]) {
        let transit = try await chartService.calculateThemeChart(
            chart: .transit,
            profile: profile,
            targetDate: date,
            location: location,
            preset: preset,
            calculator: calculator
        )
        let secondary = try await chartService.calculateThemeChart(
            chart: .secondary,
            profile: profile,
            targetDate: date,
            location: location,
            preset: preset,
            calculator: calculator
        )
        let solarArc = try await advancedService.calculate(
            chart: .solarArc,
            context: ChartContext(
                chartKind: .solarArc,
                primaryPersonID: subjectID,
                comparisonPersonID: nil,
                preset: preset,
                locale: locale,
                target: .solarArc(targetDate: date, usesLiveDefault: false)
            ),
            profile: profile,
            calculator: calculator
        )
        let transitFacts = CompareFactBuilder.chartFacts(
            technique: "transit",
            result: transit,
            referenceChart: "natal"
        )
        let secondaryFacts = CompareFactBuilder.chartFacts(
            technique: "secondary_progression",
            result: secondary,
            referenceChart: "natal"
        )
        let solarArcFacts = CompareFactBuilder.chartFacts(
            technique: "solar_arc",
            result: solarArc,
            referenceChart: "natal"
        )
        return (
            transitFacts + secondaryFacts + solarArcFacts,
            [
                cached(id: "transit-\(suffix)", labelKey: "compare.chart.transit-\(suffix)", technique: "transit", result: transit),
                cached(id: "secondary-\(suffix)", labelKey: "compare.chart.secondary-\(suffix)", technique: "secondary_progression", result: secondary),
                cached(id: "solar-arc-\(suffix)", labelKey: "compare.chart.solar-arc-\(suffix)", technique: "solar_arc", result: solarArc),
            ]
        )
    }

    private func relocation(
        profile: UserProfile,
        subjectID: String,
        place: ComparePlace,
        preset: CalculationPreset,
        locale: AppLanguage,
        calculator: SwissEphemerisCalculator
    ) async throws -> ChartDisplayResult {
        try await advancedService.calculate(
            chart: .relocation,
            context: ChartContext(
                chartKind: .relocation,
                primaryPersonID: subjectID,
                comparisonPersonID: nil,
                preset: preset,
                locale: locale,
                target: .relocation(location: place.location)
            ),
            profile: profile,
            calculator: calculator
        )
    }

    private func relationship(
        kind: RelationshipChartKind,
        request: CompareRequest,
        targetDate: Date?,
        calculator: SwissEphemerisCalculator
    ) async throws -> RelationshipChartArtifact {
        guard let subjectB = request.subjectB else {
            throw CompareValidationError.missingSecondSubject
        }
        return try await relationshipService.calculate(
            request: AppRelationshipChartRequest(
                kind: kind,
                firstID: request.subjectA.id,
                firstProfile: request.subjectA.profile,
                secondID: subjectB.id,
                secondProfile: subjectB.profile,
                preset: request.preset,
                targetDate: targetDate
            ),
            calculator: calculator
        )
    }

    private func cached(
        id: String,
        labelKey: String,
        technique: String,
        result: ChartDisplayResult
    ) -> CompareCachedChart {
        CompareCachedChart(
            id: id,
            labelKey: labelKey,
            technique: technique,
            snapshot: result.snapshot,
            reference: result.reference,
            comparisonAspects: result.comparisonAspects
        )
    }

    private func cached(
        id: String,
        labelKey: String,
        artifact: RelationshipChartArtifact
    ) -> CompareCachedChart {
        CompareCachedChart(
            id: id,
            labelKey: labelKey,
            technique: "relationship.\(artifact.kind.rawValue)",
            snapshot: artifact.snapshot,
            reference: artifact.reference,
            comparisonAspects: artifact.comparisonAspects
        )
    }
}
