import AstroCore
import Foundation
import SwiftUI

// MARK: - Theme domain

enum ThemeKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case loveRelationships = "love_relationships"
    case careerPurpose = "career_purpose"
    case moneyGrowth = "money_growth"
    case familyHome = "family_home"
    case selfWellbeing = "self_wellbeing"
    case creativityExpression = "creativity_expression"
    case learningExploration = "learning_exploration"
    case lifeDirection = "life_direction"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .loveRelationships: localized("themes.love-relationships", language: language)
        case .careerPurpose: localized("themes.career-purpose", language: language)
        case .moneyGrowth: localized("themes.money-growth", language: language)
        case .familyHome: localized("themes.family-home", language: language)
        case .selfWellbeing: localized("themes.self-wellbeing", language: language)
        case .creativityExpression: localized("themes.creativity-expression", language: language)
        case .learningExploration: localized("themes.learning-exploration", language: language)
        case .lifeDirection: localized("themes.life-direction", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .loveRelationships: localized("themes.love-relationships-subtitle", language: language)
        case .careerPurpose: localized("themes.career-purpose-subtitle", language: language)
        case .moneyGrowth: localized("themes.money-growth-subtitle", language: language)
        case .familyHome: localized("themes.family-home-subtitle", language: language)
        case .selfWellbeing: localized("themes.self-wellbeing-subtitle", language: language)
        case .creativityExpression: localized("themes.creativity-expression-subtitle", language: language)
        case .learningExploration: localized("themes.learning-exploration-subtitle", language: language)
        case .lifeDirection: localized("themes.life-direction-subtitle", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .loveRelationships: "heart.circle"
        case .careerPurpose: "briefcase"
        case .moneyGrowth: "chart.line.uptrend.xyaxis"
        case .familyHome: "house"
        case .selfWellbeing: "sparkles"
        case .creativityExpression: "paintpalette"
        case .learningExploration: "book.closed"
        case .lifeDirection: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }

    var definition: ThemeDefinition {
        ThemeDefinitionRegistry.definition(for: self)
    }
}

enum ThemeHorizon: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case now
    case threeMonths = "3_months"
    case sixMonths = "6_months"
    case oneYear = "1_year"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .now: localized("themes.horizon.now", language: language)
        case .threeMonths: localized("themes.horizon.3-months", language: language)
        case .sixMonths: localized("themes.horizon.6-months", language: language)
        case .oneYear: localized("themes.horizon.1-year", language: language)
        }
    }

    func period(startingAt date: Date, calendar sourceCalendar: Calendar = .current) -> ThemeDateRange {
        let calendar = sourceCalendar
        let end: Date
        switch self {
        case .now:
            end = date
        case .threeMonths:
            end = calendar.date(byAdding: .month, value: 3, to: date) ?? date.addingTimeInterval(90 * 86_400)
        case .sixMonths:
            end = calendar.date(byAdding: .month, value: 6, to: date) ?? date.addingTimeInterval(182 * 86_400)
        case .oneYear:
            end = calendar.date(byAdding: .year, value: 1, to: date) ?? date.addingTimeInterval(365 * 86_400)
        }
        return ThemeDateRange(start: date, end: end)
    }
}

enum ThemeLoveAnalysisMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case myLoveLife = "my_love_life"
    case specificRelationship = "specific_relationship"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .myLoveLife: localized("themes.love.mode.my-love-life", language: language)
        case .specificRelationship: localized("themes.love.mode.specific-relationship", language: language)
        }
    }
}

enum ThemeFamilyRole: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case mother
    case father
    case parent
    case child
    case sibling
    case partnerSpouse = "partner_spouse"
    case relative
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .mother: localized("themes.family-role.mother", language: language)
        case .father: localized("themes.family-role.father", language: language)
        case .parent: localized("themes.family-role.parent", language: language)
        case .child: localized("themes.family-role.child", language: language)
        case .sibling: localized("themes.family-role.sibling", language: language)
        case .partnerSpouse: localized("themes.family-role.partner-spouse", language: language)
        case .relative: localized("themes.family-role.relative", language: language)
        case .other: localized("themes.family-role.other", language: language)
        }
    }
}

enum ThemeEvidenceRole: String, Codable, Hashable, Sendable {
    case foundation
    case timingExternal
    case timingInternal
    case timingPeriod
    case shortTermDetail
    case memberRelationship
    case dependency
}

struct ThemeOption: Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String

    func title(language: AppLanguage) -> String {
        localized(titleKey, language: language)
    }
}

struct ThemeDefinition: Sendable {
    let kind: ThemeKind
    let focusOptions: [ThemeOption]
    let requiresCareerStage: Bool
    let supportsLoveMode: Bool
    let supportsFamilyMembers: Bool
    let minPeople: Int
    let maxPeople: Int
}

enum ThemeDefinitionRegistry {
    static let maxFamilyMembers = 3

    static func definition(for kind: ThemeKind) -> ThemeDefinition {
        let focusPrefix = "themes.focus.\(kind.rawValue.replacingOccurrences(of: "_", with: "-"))"
        let focusIDs: [String] = switch kind {
        case .loveRelationships:
            ["overall", "meeting_someone", "emotional_patterns", "attraction_connection", "commitment", "boundaries_reciprocity"]
        case .careerPurpose:
            ["overall", "career_direction", "purpose_contribution", "change", "opportunity", "leadership", "work_environment"]
        case .moneyGrowth:
            ["overall", "income_work", "financial_stability", "spending_resources", "growth_opportunity", "long_term_priorities"]
        case .familyHome:
            ["overall", "family_relationships", "home_roots", "belonging", "communication_boundaries", "care_responsibility", "changes_at_home"]
        case .selfWellbeing:
            ["overall", "emotional_balance", "energy_routines", "self_confidence", "stress_recovery", "inner_needs"]
        case .creativityExpression:
            ["overall", "creative_work", "self_expression", "personal_project", "visibility", "motivation_momentum"]
        case .learningExploration:
            ["overall", "learning", "study", "new_skills", "travel_exploration", "new_perspectives"]
        case .lifeDirection:
            ["overall", "identity", "relationships", "home_family", "work_purpose", "personal_growth"]
        }
        return ThemeDefinition(
            kind: kind,
            focusOptions: focusIDs.map {
                ThemeOption(
                    id: $0,
                    titleKey: "\(focusPrefix).\($0.replacingOccurrences(of: "_", with: "-"))"
                )
            },
            requiresCareerStage: kind == .careerPurpose,
            supportsLoveMode: kind == .loveRelationships,
            supportsFamilyMembers: kind == .familyHome,
            minPeople: 1,
            maxPeople: kind == .familyHome ? 1 + maxFamilyMembers : (kind == .loveRelationships ? 2 : 1)
        )
    }
}

struct ThemeDateRange: Codable, Equatable, Hashable, Sendable {
    let start: Date
    let end: Date
}

struct ThemePersonSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let ref: String
    let name: String
    let role: String
    let profile: UserProfile
}

struct ThemeInput: Codable, Equatable {
    let theme: ThemeKind
    let analysisMode: ThemeLoveAnalysisMode?
    let analysisDate: Date
    let primary: ThemePersonSnapshot
    let otherPerson: ThemePersonSnapshot?
    let familyMembers: [ThemePersonSnapshot]
    let horizon: ThemeHorizon
    let location: ChartLocationSelection
    let focus: String
    let optionalContext: String
    let relationshipType: String?
    let relationshipStatus: String?
    let careerStage: String?
    let presets: [String: String]
    let locale: AppLanguage

    var period: ThemeDateRange {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location.timezoneID) ?? .current
        return horizon.period(startingAt: analysisDate, calendar: calendar)
    }

    func preset(for chart: ChartKind) -> CalculationPreset {
        let raw = presets[chart.rawValue] ?? CalculationPreset.modern.rawValue
        let decoded = CalculationPreset(rawValue: raw) ?? .modern
        return decoded == .special ? .modern : decoded
    }

    var relationshipPreset: CalculationPreset {
        preset(for: .synastry)
    }
}

enum ThemeChartTechnique: Codable, Equatable, Hashable, Sendable {
    case chart(ChartKind)
    case relationship(RelationshipChartKind)

    var key: String {
        switch self {
        case let .chart(chart): chart.rawValue
        case let .relationship(kind): "relationship.\(kind.rawValue)"
        }
    }
}

struct ThemeChartTask: Codable, Equatable, Identifiable {
    let id: String
    let technique: ThemeChartTechnique
    let evidenceRole: ThemeEvidenceRole
    let participants: [ThemePersonSnapshot]
    let targetDate: Date?
    let range: ThemeDateRange?
    let includeInAIFacts: Bool
    let displayInResult: Bool
    let displayLabelKey: String
}

struct ThemeChartRecipe: Codable, Equatable {
    let theme: ThemeKind
    let horizon: ThemeHorizon
    let tasks: [ThemeChartTask]
}

// MARK: - Planner

struct ThemePlanner: Sendable {
    func recipe(for input: ThemeInput) -> ThemeChartRecipe {
        if input.theme == .loveRelationships,
           input.analysisMode == .specificRelationship,
           let other = input.otherPerson
        {
            return relationshipRecipe(input: input, other: other)
        }

        var tasks = singlePersonTasks(input: input)
        if input.theme == .familyHome {
            for member in input.familyMembers.prefix(ThemeDefinitionRegistry.maxFamilyMembers) {
                tasks.append(
                    relationshipTask(
                        kind: RelationshipChartKind.synastryA,
                        input: input,
                        participants: [input.primary, member],
                        role: .memberRelationship,
                        labelKey: "themes.chart.synastry",
                        suffix: member.ref
                    )
                )
                tasks.append(
                    relationshipTask(
                        kind: RelationshipChartKind.synastryB,
                        input: input,
                        participants: [input.primary, member],
                        role: .memberRelationship,
                        labelKey: "themes.chart.synastry",
                        suffix: member.ref
                    )
                )
            }
        }
        return ThemeChartRecipe(theme: input.theme, horizon: input.horizon, tasks: tasks)
    }

    private func singlePersonTasks(input: ThemeInput) -> [ThemeChartTask] {
        let primary = [input.primary]
        var tasks: [ThemeChartTask] = [
            chartTask(
                .natal,
                input: input,
                participants: primary,
                role: .foundation,
                targetDate: input.analysisDate,
                labelKey: "themes.chart.natal"
            ),
            chartTask(
                .transit,
                input: input,
                participants: primary,
                role: .timingExternal,
                targetDate: input.horizon == .now ? input.analysisDate : input.period.end,
                range: input.horizon == .now ? nil : input.period,
                labelKey: "themes.chart.transit"
            ),
        ]

        switch input.horizon {
        case .now:
            tasks.append(
                chartTask(
                    .tertiary,
                    input: input,
                    participants: primary,
                    role: .shortTermDetail,
                    targetDate: input.analysisDate,
                    labelKey: "themes.chart.tertiary"
                )
            )
            if [.loveRelationships, .familyHome, .selfWellbeing].contains(input.theme) {
                tasks.append(
                    chartTask(
                        .lunarReturn,
                        input: input,
                        participants: primary,
                        role: .timingPeriod,
                        targetDate: input.analysisDate,
                        labelKey: "themes.chart.lunar-return"
                    )
                )
            }

        case .threeMonths:
            tasks.append(
                chartTask(
                    .tertiary,
                    input: input,
                    participants: primary,
                    role: .shortTermDetail,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.tertiary"
                )
            )
            tasks.append(
                chartTask(
                    .secondary,
                    input: input,
                    participants: primary,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.secondary"
                )
            )

        case .sixMonths:
            tasks.append(
                chartTask(
                    .secondary,
                    input: input,
                    participants: primary,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.secondary"
                )
            )
            tasks.append(
                chartTask(
                    .solarArc,
                    input: input,
                    participants: primary,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.solar-arc"
                )
            )

        case .oneYear:
            tasks.append(
                chartTask(
                    .secondary,
                    input: input,
                    participants: primary,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.secondary"
                )
            )
            tasks.append(
                chartTask(
                    .solarArc,
                    input: input,
                    participants: primary,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.solar-arc"
                )
            )
            tasks.append(
                chartTask(
                    .solarReturn,
                    input: input,
                    participants: primary,
                    role: .timingPeriod,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.solar-return"
                )
            )
        }
        return tasks
    }

    private func relationshipRecipe(input: ThemeInput, other: ThemePersonSnapshot) -> ThemeChartRecipe {
        let people = [input.primary, other]
        var tasks: [ThemeChartTask] = [
            relationshipTask(
                kind: RelationshipChartKind.synastryA,
                input: input,
                participants: people,
                role: .foundation,
                labelKey: "themes.chart.synastry"
            ),
            relationshipTask(
                kind: RelationshipChartKind.synastryB,
                input: input,
                participants: people,
                role: .foundation,
                labelKey: "themes.chart.synastry"
            ),
            relationshipTask(
                kind: RelationshipChartKind.composite,
                input: input,
                participants: people,
                role: .foundation,
                labelKey: "themes.chart.composite"
            ),
            relationshipTask(
                kind: RelationshipChartKind.compositeTransit,
                input: input,
                participants: people,
                role: .timingExternal,
                targetDate: input.horizon == .now ? input.analysisDate : input.period.end,
                range: input.horizon == .now ? nil : input.period,
                labelKey: "themes.chart.current-influence"
            ),
        ]

        if input.horizon != .now {
            tasks.append(
                relationshipTask(
                    kind: RelationshipChartKind.compositeSecondaryCompare,
                    input: input,
                    participants: people,
                    role: .timingInternal,
                    targetDate: input.period.end,
                    labelKey: "themes.chart.long-term-change"
                )
            )
        }

        if input.horizon == .now || input.horizon == .threeMonths {
            tasks.append(
                relationshipTask(
                    kind: RelationshipChartKind.compositeTertiaryCompare,
                    input: input,
                    participants: people,
                    role: .shortTermDetail,
                    targetDate: input.horizon == .now ? input.analysisDate : input.period.end,
                    labelKey: "themes.chart.short-term-change"
                )
            )
        }

        return ThemeChartRecipe(theme: input.theme, horizon: input.horizon, tasks: tasks)
    }

    private func chartTask(
        _ chart: ChartKind,
        input: ThemeInput,
        participants: [ThemePersonSnapshot],
        role: ThemeEvidenceRole,
        targetDate: Date,
        range: ThemeDateRange? = nil,
        includeInAIFacts: Bool = true,
        displayInResult: Bool = true,
        labelKey: String
    ) -> ThemeChartTask {
        ThemeChartTask(
            id: "chart.\(chart.rawValue).\(role.rawValue)",
            technique: .chart(chart),
            evidenceRole: role,
            participants: participants,
            targetDate: targetDate,
            range: range,
            includeInAIFacts: includeInAIFacts,
            displayInResult: displayInResult,
            displayLabelKey: labelKey
        )
    }

    private func relationshipTask(
        kind: RelationshipChartKind,
        input: ThemeInput,
        participants: [ThemePersonSnapshot],
        role: ThemeEvidenceRole,
        targetDate: Date? = nil,
        range: ThemeDateRange? = nil,
        includeInAIFacts: Bool = true,
        displayInResult: Bool = true,
        labelKey: String,
        suffix: String? = nil
    ) -> ThemeChartTask {
        ThemeChartTask(
            id: "relationship.\(kind.rawValue).\(suffix ?? "primary")",
            technique: .relationship(kind),
            evidenceRole: role,
            participants: participants,
            targetDate: targetDate,
            range: range,
            includeInAIFacts: includeInAIFacts,
            displayInResult: displayInResult,
            displayLabelKey: labelKey
        )
    }

    /// Retained for dependency artifacts (06/07) if a future calculator needs
    /// them. The current AstroCore comparison techniques calculate their own
    /// dependencies, so v1 does not add redundant 06/07 tasks to the recipe.
    func dependencyTask(
        kind: RelationshipChartKind,
        input: ThemeInput,
        participants: [ThemePersonSnapshot],
        targetDate: Date
    ) -> ThemeChartTask {
        relationshipTask(
            kind: kind,
            input: input,
            participants: participants,
            role: .dependency,
            targetDate: targetDate,
            includeInAIFacts: false,
            displayInResult: false,
            labelKey: "themes.chart.dependency"
        )
    }
}

// MARK: - Deterministic calculation artifacts

struct ThemeChartFrame: Codable, Equatable, Identifiable {
    let id: String
    let sampledAt: Date
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let techniqueMetadata: ChartTechniqueMetadata?
    let relationshipMetadata: RelationshipTechniqueMetadata?
}

struct ThemeChartArtifact: Codable, Equatable, Identifiable {
    let id: String
    let task: ThemeChartTask
    let frames: [ThemeChartFrame]

    var displayFrame: ThemeChartFrame? { frames.last }
}

@MainActor
final class ThemeCalculationCoordinator {
    private let chartService = AppChartCalculationService()
    private let advancedService = AppAdvancedChartCalculationService()
    private let relationshipService = AppRelationshipChartCalculationService()

    func calculate(
        input: ThemeInput,
        recipe: ThemeChartRecipe,
        model: AppModel
    ) async throws -> [ThemeChartArtifact] {
        let calculator = try model.themeCalculator()
        var artifacts: [ThemeChartArtifact] = []
        artifacts.reserveCapacity(recipe.tasks.count)
        for task in recipe.tasks {
            try Task.checkCancellation()
            artifacts.append(
                try await calculate(task: task, input: input, calculator: calculator)
            )
        }
        return artifacts
    }

    private func calculate(
        task: ThemeChartTask,
        input: ThemeInput,
        calculator: SwissEphemerisCalculator
    ) async throws -> ThemeChartArtifact {
        switch task.technique {
        case let .chart(chart):
            return try await calculateChartTask(task, chart: chart, input: input, calculator: calculator)
        case let .relationship(kind):
            return try await calculateRelationshipTask(task, kind: kind, input: input, calculator: calculator)
        }
    }

    private func calculateChartTask(
        _ task: ThemeChartTask,
        chart: ChartKind,
        input: ThemeInput,
        calculator: SwissEphemerisCalculator
    ) async throws -> ThemeChartArtifact {
        guard let person = task.participants.first else {
            throw ThemeAnalysisError.invalidInput("missing primary person")
        }
        let dates = chart == .transit
            ? anchorDates(for: task)
            : [task.targetDate ?? input.analysisDate]
        var frames: [ThemeChartFrame] = []
        for date in dates {
            let result: ChartDisplayResult
            if chart.isAdvancedChart {
                let target: ChartTarget = switch chart {
                case .tertiary: .tertiary(targetDate: date, usesLiveDefault: false)
                case .lunarReturn: .lunarReturn(targetDate: date, location: input.location, usesLiveDefault: false)
                case .solarArc: .solarArc(targetDate: date, usesLiveDefault: false)
                default: throw ThemeAnalysisError.unsupportedTechnique(chart.rawValue)
                }
                result = try await advancedService.calculate(
                    chart: chart,
                    context: ChartContext(
                        chartKind: chart,
                        primaryPersonID: person.id,
                        comparisonPersonID: nil,
                        preset: input.preset(for: chart),
                        locale: input.locale,
                        target: target
                    ),
                    profile: person.profile,
                    calculator: calculator
                )
            } else {
                result = try await chartService.calculateThemeChart(
                    chart: chart,
                    profile: person.profile,
                    targetDate: date,
                    location: input.location,
                    preset: input.preset(for: chart),
                    calculator: calculator
                )
            }
            frames.append(
                ThemeChartFrame(
                    id: "\(task.id).\(Int(date.timeIntervalSince1970))",
                    sampledAt: date,
                    snapshot: result.snapshot,
                    reference: result.reference,
                    comparisonAspects: result.comparisonAspects,
                    techniqueMetadata: result.techniqueMetadata,
                    relationshipMetadata: nil
                )
            )
        }
        return ThemeChartArtifact(id: task.id, task: task, frames: frames)
    }

    private func calculateRelationshipTask(
        _ task: ThemeChartTask,
        kind: RelationshipChartKind,
        input: ThemeInput,
        calculator: SwissEphemerisCalculator
    ) async throws -> ThemeChartArtifact {
        guard task.participants.count == 2 else {
            throw ThemeAnalysisError.invalidInput("relationship task requires two people")
        }
        let first = task.participants[0]
        let second = task.participants[1]
        let dates: [Date?] = kind == .compositeTransit
            ? anchorDates(for: task).map(Optional.some)
            : [task.targetDate]
        var frames: [ThemeChartFrame] = []
        for targetDate in dates {
            let artifact = try await relationshipService.calculate(
                request: AppRelationshipChartRequest(
                    kind: kind,
                    firstID: first.id,
                    firstProfile: first.profile,
                    secondID: second.id,
                    secondProfile: second.profile,
                    preset: input.relationshipPreset,
                    targetDate: targetDate,
                    transitLocation: kind.supportsTransitLocation ? input.location : nil,
                    perspective: nil,
                    midpointAlgorithm: nil
                ),
                calculator: calculator
            )
            let sampledAt = targetDate ?? input.analysisDate
            frames.append(
                ThemeChartFrame(
                    id: "\(task.id).\(Int(sampledAt.timeIntervalSince1970))",
                    sampledAt: sampledAt,
                    snapshot: artifact.snapshot,
                    reference: artifact.reference,
                    comparisonAspects: artifact.comparisonAspects,
                    techniqueMetadata: nil,
                    relationshipMetadata: artifact.metadata
                )
            )
        }
        return ThemeChartArtifact(id: task.id, task: task, frames: frames)
    }

    private func anchorDates(for task: ThemeChartTask) -> [Date] {
        guard let range = task.range, range.end > range.start else {
            return [task.targetDate ?? rangeFallbackDate(task)]
        }
        let duration = range.end.timeIntervalSince(range.start)
        let days = duration / 86_400
        let count: Int
        if days <= 100 {
            count = 3
        } else if days <= 220 {
            count = 4
        } else {
            count = 5
        }
        guard count > 1 else { return [range.end] }
        return (0 ..< count).map { index in
            let fraction = Double(index) / Double(count - 1)
            return range.start.addingTimeInterval(duration * fraction)
        }
    }

    private func rangeFallbackDate(_ task: ThemeChartTask) -> Date {
        task.targetDate ?? Date()
    }
}

// MARK: - AI evidence contract

struct ThemeAIAnalysisPeriod: Codable, Equatable, Sendable {
    let label: String
    let start: String
    let end: String
}

struct ThemeAIAnalysisContext: Codable, Equatable, Sendable {
    let theme: String
    let analysisMode: String?
    let analysisDate: String
    let period: ThemeAIAnalysisPeriod
    let relationshipType: String?
    let relationshipStatus: String?
    let careerStage: String?
    let focus: String?

    enum CodingKeys: String, CodingKey {
        case theme
        case analysisMode = "analysis_mode"
        case analysisDate = "analysis_date"
        case period
        case relationshipType = "relationship_type"
        case relationshipStatus = "relationship_status"
        case careerStage = "career_stage"
        case focus
    }
}

struct ThemeAIPerson: Codable, Equatable, Sendable {
    let ref: String
    let name: String
    let role: String
}

struct ThemeAIUserContext: Codable, Equatable, Sendable {
    let focus: String
    let note: String?
}

struct ThemeAIFact: Codable, Equatable, Hashable, Sendable {
    let id: String
    let sourceChart: String
    let evidenceRole: String
    let factType: String
    let actorRef: String?
    let targetRef: String?
    let body: String?
    let otherBody: String?
    let sign: String?
    let house: Int?
    let aspect: String?
    let orb: Double?
    let phase: String?
    let strength: Double?
    let sampledAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceChart = "source_chart"
        case evidenceRole = "evidence_role"
        case factType = "fact_type"
        case actorRef = "actor_ref"
        case targetRef = "target_ref"
        case body
        case otherBody = "other_body"
        case sign
        case house
        case aspect
        case orb
        case phase
        case strength
        case sampledAt = "sampled_at"
    }
}

struct ThemeAIEvidenceGroup: Codable, Equatable, Sendable {
    let id: String
    let sourceChart: String
    let evidenceRole: String
    let facts: [ThemeAIFact]

    enum CodingKeys: String, CodingKey {
        case id
        case sourceChart = "source_chart"
        case evidenceRole = "evidence_role"
        case facts
    }
}

struct ThemeAIMemberRelationship: Codable, Equatable, Sendable {
    let memberRef: String
    let synastry: ThemeAIEvidenceGroup

    enum CodingKeys: String, CodingKey {
        case memberRef = "member_ref"
        case synastry
    }
}

struct ThemeAIEvidence: Codable, Equatable, Sendable {
    let foundation: [ThemeAIEvidenceGroup]
    let timing: [ThemeAIEvidenceGroup]
    let memberRelationships: [ThemeAIMemberRelationship]?

    enum CodingKeys: String, CodingKey {
        case foundation
        case timing
        case memberRelationships = "member_relationships"
    }
}

struct ThemeAIRequestedOutput: Codable, Equatable, Sendable {
    let language: String
    let sections: [String]
}

struct ThemeAIPayload: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let analysis: ThemeAIAnalysisContext
    let people: [ThemeAIPerson]
    let userContext: ThemeAIUserContext?
    let evidence: ThemeAIEvidence
    let requestedOutput: ThemeAIRequestedOutput

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case analysis
        case people
        case userContext = "user_context"
        case evidence
        case requestedOutput = "requested_output"
    }

    var flattenedEvidenceFacts: [ThemeAIFact] {
        var seen = Set<String>()
        func take(_ facts: [ThemeAIFact], limit: Int) -> [ThemeAIFact] {
            facts.filter { seen.insert($0.id).inserted }.prefix(limit).map { $0 }
        }
        let foundation = take(evidence.foundation.flatMap(\.facts), limit: 112)
        let timing = take(evidence.timing.flatMap(\.facts), limit: 64)
        let memberRelationships = take(
            (evidence.memberRelationships ?? []).flatMap(\.synastry.facts),
            limit: 64
        )
        return foundation + timing + memberRelationships
    }
}

struct ThemeReportSection: Codable, Equatable, Sendable, Identifiable {
    let number: String
    let title: String
    let body: String
    let callout: String?
    let evidenceFactIDs: [String]?

    var id: String { number }
}

struct ThemeReportResponse: Codable, Equatable, Sendable {
    let title: String
    let subtitle: String
    let sections: [ThemeReportSection]
}

struct ThemeEvidenceSelector: Sendable {
    func select(_ facts: [ThemeAIFact], for theme: ThemeKind) -> [ThemeAIFact] {
        let bodyIDs = selectedBodies(for: theme)
        let houses = selectedHouses(for: theme)
        let filtered = facts.filter { fact in
            if fact.factType == "angle" { return true }
            if let body = fact.body, bodyIDs.contains(body) { return true }
            if let otherBody = fact.otherBody, bodyIDs.contains(otherBody) { return true }
            if let house = fact.house, houses.contains(house) { return true }
            return theme == .lifeDirection
        }
        return Array(
            filtered.sorted {
                ($0.strength ?? 0) > ($1.strength ?? 0)
            }.prefix(48)
        )
    }

    private func selectedBodies(for theme: ThemeKind) -> Set<String> {
        switch theme {
        case .loveRelationships:
            ["sun", "moon", "mercury", "venus", "mars", "saturn"]
        case .careerPurpose:
            ["sun", "mercury", "jupiter", "saturn"]
        case .moneyGrowth:
            ["venus", "jupiter", "saturn"]
        case .familyHome:
            ["moon", "mercury", "venus", "saturn", "sun"]
        case .selfWellbeing:
            ["sun", "moon", "mercury", "saturn", "mars"]
        case .creativityExpression:
            ["sun", "mercury", "venus", "mars", "neptune"]
        case .learningExploration:
            ["mercury", "jupiter", "uranus", "sun"]
        case .lifeDirection:
            Set(CelestialBody.allCases.map(\.rawValue))
        }
    }

    private func selectedHouses(for theme: ThemeKind) -> Set<Int> {
        switch theme {
        case .loveRelationships: [5, 7, 8]
        case .careerPurpose: [2, 6, 10]
        case .moneyGrowth: [2, 8]
        case .familyHome: [4]
        case .selfWellbeing: [1, 6, 12]
        case .creativityExpression: [3, 5, 11]
        case .learningExploration: [3, 9]
        case .lifeDirection: [1, 4, 7, 10]
        }
    }
}

struct ThemeFactsBuilder: Sendable {
    private let selector = ThemeEvidenceSelector()

    func build(
        input: ThemeInput,
        recipe: ThemeChartRecipe,
        artifacts: [ThemeChartArtifact]
    ) -> ThemeAIPayload {
        let people = ([input.primary] + [input.otherPerson].compactMap { $0 } + input.familyMembers)
            .map { ThemeAIPerson(ref: $0.ref, name: $0.name, role: $0.role) }
        let period = input.period
        let analysisTimeZone = TimeZone(identifier: input.location.timezoneID) ?? .current
        let analysis = ThemeAIAnalysisContext(
            theme: input.theme.rawValue,
            analysisMode: input.analysisMode?.rawValue,
            analysisDate: dayString(input.analysisDate, timeZone: analysisTimeZone),
            period: ThemeAIAnalysisPeriod(
                label: input.horizon.rawValue,
                start: dayString(period.start, timeZone: analysisTimeZone),
                end: dayString(period.end, timeZone: analysisTimeZone)
            ),
            relationshipType: input.relationshipType,
            relationshipStatus: input.relationshipStatus,
            careerStage: input.careerStage,
            focus: input.focus
        )

        let evidence = buildEvidence(input: input, artifacts: artifacts)
        return ThemeAIPayload(
            schemaVersion: 1,
            analysis: analysis,
            people: people,
            userContext: nil,
            evidence: evidence,
            requestedOutput: ThemeAIRequestedOutput(
                language: input.locale.reportRequestLanguage.rawValue,
                sections: reportSections(for: input)
            )
        )
    }

    private func buildEvidence(
        input: ThemeInput,
        artifacts: [ThemeChartArtifact]
    ) -> ThemeAIEvidence {
        let eligible = artifacts.filter(\.task.includeInAIFacts)
        if input.theme == .loveRelationships,
           input.analysisMode == .specificRelationship,
           input.otherPerson != nil
        {
            let synastry = mergedSynastry(
                artifacts: eligible.filter {
                    if case let .relationship(kind) = $0.task.technique { return kind.isSynastry }
                    return false
                },
                theme: input.theme
            )
            var foundation = [synastry].compactMap { $0 }
            var timing: [ThemeAIEvidenceGroup] = []
            for artifact in eligible where !isSynastry(artifact) {
                let group = normalizedGroup(artifact: artifact, input: input)
                if artifact.task.evidenceRole == .foundation {
                    foundation.append(group)
                } else {
                    timing.append(group)
                }
            }
            return ThemeAIEvidence(
                foundation: foundation,
                timing: timing,
                memberRelationships: nil
            )
        }

        if input.theme == .familyHome {
            let primaryArtifacts = eligible.filter { $0.task.evidenceRole != .memberRelationship }
            let foundation = primaryArtifacts
                .filter { $0.task.evidenceRole == .foundation }
                .map { normalizedGroup(artifact: $0, input: input) }
            let timing = primaryArtifacts
                .filter { $0.task.evidenceRole != .foundation }
                .map { normalizedGroup(artifact: $0, input: input) }
            var relationships: [ThemeAIMemberRelationship] = []
            for member in input.familyMembers {
                let pair = eligible.filter {
                    $0.task.evidenceRole == .memberRelationship
                        && $0.task.participants.contains(where: { $0.ref == member.ref })
                }
                if let group = mergedSynastry(artifacts: pair, theme: input.theme) {
                    relationships.append(
                        ThemeAIMemberRelationship(memberRef: member.ref, synastry: group)
                    )
                }
            }
            return ThemeAIEvidence(
                foundation: foundation,
                timing: timing,
                memberRelationships: relationships.isEmpty ? nil : relationships
            )
        }

        let foundation = eligible
            .filter { $0.task.evidenceRole == .foundation }
            .map { normalizedGroup(artifact: $0, input: input) }
        let timing = eligible
            .filter { $0.task.evidenceRole != .foundation }
            .map { normalizedGroup(artifact: $0, input: input) }
        return ThemeAIEvidence(foundation: foundation, timing: timing, memberRelationships: nil)
    }

    private func isSynastry(_ artifact: ThemeChartArtifact) -> Bool {
        guard case let .relationship(kind) = artifact.task.technique else { return false }
        return kind.isSynastry
    }

    private func normalizedGroup(
        artifact: ThemeChartArtifact,
        input: ThemeInput
    ) -> ThemeAIEvidenceGroup {
        var facts: [ThemeAIFact] = []
        for frame in artifact.frames {
            if artifact.task.evidenceRole == .foundation {
                // Foundation charts (Natal / Composite / Return framework) are
                // structural evidence even if a calculator happens to expose
                // comparisonAspects as auxiliary metadata.
                facts += structuralFacts(frame: frame, artifact: artifact)
            } else {
                facts += activationFacts(frame: frame, artifact: artifact)
                if frame.comparisonAspects.isEmpty {
                    facts += structuralFacts(frame: frame, artifact: artifact)
                }
            }
        }
        let selected = selector.select(deduplicate(facts), for: input.theme)
        return ThemeAIEvidenceGroup(
            id: artifact.id,
            sourceChart: artifact.task.technique.key,
            evidenceRole: artifact.task.evidenceRole.rawValue,
            facts: selected
        )
    }

    private func structuralFacts(
        frame: ThemeChartFrame,
        artifact: ThemeChartArtifact
    ) -> [ThemeAIFact] {
        let source = artifact.task.technique.key
        let role = artifact.task.evidenceRole.rawValue
        let participant = artifact.task.participants.first?.ref
        var facts = frame.snapshot.points.map { point in
            ThemeAIFact(
                id: "\(source).placement.\(point.body.rawValue)",
                sourceChart: source,
                evidenceRole: role,
                factType: "placement",
                actorRef: participant,
                targetRef: nil,
                body: point.body.rawValue,
                otherBody: nil,
                sign: zodiacID(point.signIndex),
                house: frame.snapshot.house(containing: point.longitudeDegrees),
                aspect: nil,
                orb: nil,
                phase: nil,
                strength: nil,
                sampledAt: dayString(frame.sampledAt)
            )
        }
        facts.append(
            ThemeAIFact(
                id: "\(source).angle.ascendant",
                sourceChart: source,
                evidenceRole: role,
                factType: "angle",
                actorRef: participant,
                targetRef: nil,
                body: "ascendant",
                otherBody: nil,
                sign: zodiacID(Int(normalizeDegrees(frame.snapshot.angles.ascendantDegrees) / 30)),
                house: 1,
                aspect: nil,
                orb: nil,
                phase: nil,
                strength: nil,
                sampledAt: dayString(frame.sampledAt)
            )
        )
        facts.append(
            ThemeAIFact(
                id: "\(source).angle.midheaven",
                sourceChart: source,
                evidenceRole: role,
                factType: "angle",
                actorRef: participant,
                targetRef: nil,
                body: "midheaven",
                otherBody: nil,
                sign: zodiacID(Int(normalizeDegrees(frame.snapshot.angles.midheavenDegrees) / 30)),
                house: 10,
                aspect: nil,
                orb: nil,
                phase: nil,
                strength: nil,
                sampledAt: dayString(frame.sampledAt)
            )
        )
        facts += frame.snapshot.aspects.map { aspect in
            ThemeAIFact(
                id: "\(source).aspect.\(aspect.firstID).\(aspect.kind.rawValue).\(aspect.secondID)",
                sourceChart: source,
                evidenceRole: role,
                factType: "aspect",
                actorRef: participant,
                targetRef: participant,
                body: aspect.firstID,
                otherBody: aspect.secondID,
                sign: nil,
                house: nil,
                aspect: aspect.kind.rawValue,
                orb: rounded(aspect.orbDegrees),
                phase: aspect.phase.rawValue,
                strength: rounded(aspect.strength),
                sampledAt: dayString(frame.sampledAt)
            )
        }
        return facts
    }

    private func activationFacts(
        frame: ThemeChartFrame,
        artifact: ThemeChartArtifact
    ) -> [ThemeAIFact] {
        let source = artifact.task.technique.key
        let role = artifact.task.evidenceRole.rawValue
        let actor = artifact.task.participants.first?.ref
        return frame.comparisonAspects.map { aspect in
            let identity = DeterministicFactIdentity(
                technique: source,
                factType: "activation",
                sourceObject: aspect.firstID,
                targetObject: aspect.secondID,
                relation: aspect.kind.rawValue,
                referenceChart: activationReferenceChart(for: artifact.task.technique)
            )
            return ThemeAIFact(
                id: identity.key,
                sourceChart: source,
                evidenceRole: role,
                factType: "activation",
                actorRef: actor,
                targetRef: actor,
                body: aspect.firstID,
                otherBody: aspect.secondID,
                sign: nil,
                house: frame.reference?.house(containing: aspect.secondLongitude),
                aspect: aspect.kind.rawValue,
                orb: rounded(aspect.orbDegrees),
                phase: aspect.phase.rawValue,
                strength: rounded(aspect.strength),
                sampledAt: dayString(frame.sampledAt)
            )
        }
    }

    private func activationReferenceChart(for technique: ThemeChartTechnique) -> String? {
        switch technique {
        case let .chart(chart):
            switch chart {
            case .transit, .secondary, .tertiary, .solarArc:
                return "natal"
            default:
                return nil
            }
        case let .relationship(kind):
            switch kind {
            case .compositeTransit, .compositeSecondaryCompare, .compositeTertiaryCompare:
                return "composite"
            case .davisonTransit, .davisonSecondary, .davisonTertiary:
                return "davison"
            case .marksSecondary, .marksTertiary:
                return "marks"
            default:
                return nil
            }
        }
    }

    /// Merges 02/03 into one directional relationship evidence group. Shared
    /// cross-aspects are taken once; house overlays are preserved per direction.
    private func mergedSynastry(
        artifacts: [ThemeChartArtifact],
        theme: ThemeKind
    ) -> ThemeAIEvidenceGroup? {
        guard let first = artifacts.first,
              first.task.participants.count == 2
        else { return nil }
        let primary = first.task.participants[0]
        let other = first.task.participants[1]
        var facts: [ThemeAIFact] = []
        if let synastryA = artifacts.first(where: {
            if case .relationship(.synastryA) = $0.task.technique { return true }
            return false
        }), let frame = synastryA.frames.first {
            facts += frame.comparisonAspects.map { aspect in
                ThemeAIFact(
                    id: "synastry.cross.\(other.ref).\(aspect.firstID).\(aspect.kind.rawValue).\(primary.ref).\(aspect.secondID)",
                    sourceChart: "synastry",
                    evidenceRole: first.task.evidenceRole.rawValue,
                    factType: "cross_aspect",
                    actorRef: other.ref,
                    targetRef: primary.ref,
                    body: aspect.firstID,
                    otherBody: aspect.secondID,
                    sign: nil,
                    house: nil,
                    aspect: aspect.kind.rawValue,
                    orb: rounded(aspect.orbDegrees),
                    phase: aspect.phase.rawValue,
                    strength: rounded(aspect.strength),
                    sampledAt: nil
                )
            }
            facts += houseOverlayFacts(
                frame: frame,
                movingRef: other.ref,
                targetRef: primary.ref,
                role: first.task.evidenceRole.rawValue
            )
        }
        if let synastryB = artifacts.first(where: {
            if case .relationship(.synastryB) = $0.task.technique { return true }
            return false
        }), let frame = synastryB.frames.first {
            facts += houseOverlayFacts(
                frame: frame,
                movingRef: primary.ref,
                targetRef: other.ref,
                role: first.task.evidenceRole.rawValue
            )
        }
        return ThemeAIEvidenceGroup(
            id: "mergedSynastry.\(primary.ref).\(other.ref)",
            sourceChart: "synastry",
            evidenceRole: first.task.evidenceRole.rawValue,
            facts: selector.select(deduplicate(facts), for: theme)
        )
    }

    private func houseOverlayFacts(
        frame: ThemeChartFrame,
        movingRef: String,
        targetRef: String,
        role: String
    ) -> [ThemeAIFact] {
        guard let reference = frame.reference else { return [] }
        return frame.snapshot.points.map { point in
            ThemeAIFact(
                id: "synastry.overlay.\(movingRef).\(point.body.rawValue).\(targetRef).\(reference.house(containing: point.longitudeDegrees))",
                sourceChart: "synastry",
                evidenceRole: role,
                factType: "house_overlay",
                actorRef: movingRef,
                targetRef: targetRef,
                body: point.body.rawValue,
                otherBody: nil,
                sign: nil,
                house: reference.house(containing: point.longitudeDegrees),
                aspect: nil,
                orb: nil,
                phase: nil,
                strength: nil,
                sampledAt: nil
            )
        }
    }

    private func deduplicate(_ facts: [ThemeAIFact]) -> [ThemeAIFact] {
        var seen = Set<String>()
        return facts.filter { seen.insert($0.id).inserted }
    }

    private func reportSections(for input: ThemeInput) -> [String] {
        switch input.theme {
        case .loveRelationships where input.analysisMode == .specificRelationship:
            return ["core_dynamic", "emotional_connection", "communication", "attraction_intimacy", "stability_tension", "current_phase", "what_is_changing", "period_ahead"]
        case .loveRelationships:
            return ["relationship_pattern", "emotional_needs", "attraction_connection", "communication_reciprocity", "current_romantic_climate", "what_is_changing", "period_ahead"]
        case .careerPurpose:
            return ["work_purpose_pattern", "where_you_are_now", "strengths_contribution", "pressure_friction", "direction_opportunity", "what_is_changing", "period_ahead", "practical_focus"]
        case .moneyGrowth:
            return ["relationship_with_resources", "current_resource_climate", "growth_opportunity", "security_pressure", "priorities_tradeoffs", "what_is_changing", "period_ahead"]
        case .familyHome:
            var sections = ["family_home_pattern", "belonging_roots", "emotional_climate", "communication_boundaries", "home_stability"]
            sections += input.familyMembers.map(\.ref)
            sections += ["what_is_changing", "period_ahead"]
            return sections
        case .selfWellbeing:
            return ["inner_climate", "emotional_needs", "energy_vitality", "stress_recovery", "relationship_with_self", "what_is_changing", "period_ahead"]
        case .creativityExpression:
            return ["creative_signature", "voice_expression", "current_spark", "projects_momentum", "blocks_pressure", "what_is_changing", "period_ahead"]
        case .learningExploration:
            return ["how_you_learn_explore", "current_curiosity", "study_skill_growth", "travel_new_perspectives", "momentum_friction", "what_is_changing", "period_ahead"]
        case .lifeDirection:
            return ["current_chapter", "identity_inner_direction", "what_is_changing", "areas_of_growth", "pressure_transition", "what_deserves_attention", "period_ahead"]
        }
    }

    private func dayString(_ date: Date, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func zodiacID(_ index: Int) -> String {
        let ids = ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"]
        let normalized = ((index % 12) + 12) % 12
        return ids[normalized]
    }

    private func normalizeDegrees(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

// MARK: - Persistence and Relay

enum ThemeAnalysisStatus: String, Codable, Equatable, Sendable {
    case chartsReady = "charts_ready"
    case generatingReport = "generating_report"
    case completed
    case reportFailed = "report_failed"
}

struct ThemeAnalysis: Codable, Equatable, Identifiable {
    let id: String
    let createdAt: Date
    let input: ThemeInput
    let recipe: ThemeChartRecipe
    let chartArtifacts: [ThemeChartArtifact]
    let semanticFingerprint: String?
    let factsHash: String?
    var report: ThemeReportResponse?
    var status: ThemeAnalysisStatus
    var generationError: String?
}

enum ThemeAnalysisError: LocalizedError {
    case invalidInput(String)
    case unsupportedTechnique(String)
    case invalidRelayResponse
    case invalidReportContract
    case relay(String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message): message
        case let .unsupportedTechnique(name): "Unsupported Theme technique: \(name)"
        case .invalidRelayResponse: "Invalid Theme Relay response."
        case .invalidReportContract: "Theme report did not match the requested output contract."
        case let .relay(message): message
        }
    }
}

@MainActor
final class ThemeAnalysisStore: ObservableObject {
    static let shared = ThemeAnalysisStore()

    @Published private(set) var analyses: [ThemeAnalysis] = []
    private let fileURL: URL

    private init(fileManager: FileManager = .default) {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = root.appendingPathComponent("Interstellar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("theme-analyses-v1.json")
        load()
    }

    func analysis(id: String) -> ThemeAnalysis? {
        analyses.first { $0.id == id }
    }

    @discardableResult
    func upsert(_ analysis: ThemeAnalysis) -> Bool {
        if let index = analyses.firstIndex(where: { $0.id == analysis.id }) {
            analyses[index] = analysis
        } else {
            analyses.append(analysis)
        }
        analyses.sort { $0.createdAt > $1.createdAt }
        return persist()
    }

    func clearAll() {
        analyses = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    func removeAnalyses(involvingPersonID personID: String) {
        analyses.removeAll { analysis in
            analysis.input.primary.id == personID
                || analysis.input.otherPerson?.id == personID
                || analysis.input.familyMembers.contains(where: { $0.id == personID })
        }
        _ = persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ThemeAnalysis].self, from: data)
        else { return }
        analyses = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() -> Bool {
        guard let data = try? JSONEncoder().encode(analyses) else { return false }
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }
}

struct ThemeRelayClient: Sendable {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? RelayEnvironment.baseURL
    }

    func createTask(
        body: Data,
        language: AppLanguage
    ) async throws -> ReportTaskState {
        let response = try await postResponse(
            body,
            path: "v1/generate",
            language: language
        )
        try validate(
            response,
            fallback: "Theme Relay HTTP \(response.statusCode)"
        )
        return try JSONDecoder().decode(
            ReportTaskState.self,
            from: response.data
        )
    }

    func status(
        userID: String,
        analysisID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState {
        let body = try JSONEncoder().encode([
            "userID": userID,
            "requestID": analysisID,
        ])
        let response = try await postResponse(
            body,
            path: "v1/reports/status",
            language: language
        )
        try validate(
            response,
            fallback: "Theme Relay HTTP \(response.statusCode)"
        )
        return try JSONDecoder().decode(
            ReportTaskState.self,
            from: response.data
        )
    }

    func statusIfExists(
        userID: String,
        analysisID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState? {
        let body = try JSONEncoder().encode([
            "userID": userID,
            "requestID": analysisID,
        ])
        let response = try await postResponse(
            body,
            path: "v1/reports/status",
            language: language
        )
        if response.statusCode == 404 {
            return nil
        }
        try validate(
            response,
            fallback: "Theme Relay HTTP \(response.statusCode)"
        )
        return try JSONDecoder().decode(
            ReportTaskState.self,
            from: response.data
        )
    }

    func fetch(
        userID: String,
        analysisID: String,
        language: AppLanguage
    ) async throws -> Data {
        let body = try JSONEncoder().encode([
            "userID": userID,
            "requestID": analysisID,
        ])
        let response = try await postResponse(
            body,
            path: "v1/reports/fetch",
            language: language
        )
        try validate(
            response,
            fallback: "Theme Relay HTTP \(response.statusCode)"
        )
        return response.data
    }

    private func postResponse(
        _ body: Data,
        path: String,
        language: AppLanguage
    ) async throws -> AppAttestHTTPResponse {
        var request = URLRequest(
            url: baseURL.appendingPathComponent(path)
        )
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            InstallationIdentity.value,
            forHTTPHeaderField: "X-Installation-ID"
        )
        request.timeoutInterval = 30
        request.httpBody = body
        return try await AppAttestAuthorizer.shared.send(
            request,
            body: body,
            baseURL: baseURL,
            language: language
        )
    }

    private func validate(
        _ response: AppAttestHTTPResponse,
        fallback: String
    ) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let json = (
                try? JSONSerialization.jsonObject(with: response.data)
            ) as? [String: Any]
            throw ThemeAnalysisError.relay(
                (json?["error"] as? String) ?? fallback
            )
        }
    }
}

@MainActor
struct ThemeReportService: Sendable {
    private let client = ThemeRelayClient()

    struct Identity {
        let semanticFingerprint: String
        let factsHash: String
        let facts: [String: Any]
        let params: [String: Any]
    }

    struct Delivery: Sendable {
        let report: ThemeReportResponse
        let requestID: String
    }

    func identity(
        payload: ThemeAIPayload,
        input: ThemeInput
    ) throws -> Identity {
        let evidenceData = try JSONEncoder().encode(
            payload.flattenedEvidenceFacts
        )
        let peopleData = try JSONEncoder().encode(payload.people)
        let analysisData = try JSONEncoder().encode(payload.analysis)

        guard let evidenceFacts = try JSONSerialization.jsonObject(
            with: evidenceData
        ) as? [[String: Any]],
        let people = try JSONSerialization.jsonObject(
            with: peopleData
        ) as? [[String: Any]],
        let themeContext = try JSONSerialization.jsonObject(
            with: analysisData
        ) as? [String: Any]
        else {
            throw ThemeAnalysisError.invalidRelayResponse
        }

        let facts: [String: Any] = [
            "schemaVersion": payload.schemaVersion,
            "themeContext": themeContext,
            "people": people,
            "requestedSections": payload.requestedOutput.sections,
            "evidenceFacts": evidenceFacts,
        ]
        let params: [String: Any] = [
            "theme": input.theme.rawValue,
            "analysisMode": input.analysisMode?.rawValue ?? "individual",
            "period":
                "\(payload.analysis.period.label):"
                + "\(payload.analysis.period.start):"
                + "\(payload.analysis.period.end)",
            "focus": input.focus,
        ]

        let factsData = try JSONSerialization.data(
            withJSONObject: facts,
            options: [.sortedKeys]
        )
        let factsHash = SHA256Digest.hash(factsData).hex
        let profileHashes = (
            [input.primary]
                + [input.otherPerson].compactMap { $0 }
                + input.familyMembers
        )
        .map { AppAIReportService().profileHash($0.profile) }

        let raw = [
            "theme.\(input.theme.rawValue)",
            profileHashes.joined(separator: ","),
            params.keys.sorted().map {
                "\($0)=\(params[$0] ?? "")"
            }.joined(separator: ","),
            "generation=\(GeneratedChartArtifact.schemaVersion)",
            factsHash,
        ].joined(separator: "|")

        return Identity(
            semanticFingerprint: SHA256Digest.hash(Data(raw.utf8)).hex,
            factsHash: factsHash,
            facts: facts,
            params: params
        )
    }

    func generate(
        analysisID: String,
        payload: ThemeAIPayload,
        input: ThemeInput,
        semanticFingerprint: String,
        factsHash: String,
        language: AppLanguage
    ) async throws -> Delivery {
        let body = try requestBody(
            analysisID: analysisID,
            payload: payload,
            input: input,
            semanticFingerprint: semanticFingerprint,
            factsHash: factsHash,
            language: language
        )
        _ = try await client.createTask(
            body: body,
            language: language
        )
        return try await waitForReport(
            analysisID: analysisID,
            payload: payload,
            semanticFingerprint: semanticFingerprint,
            factsHash: factsHash,
            language: language
        )
    }

    /// Recovery-only path. This never calls /v1/generate.
    func recover(
        analysisID: String,
        payload: ThemeAIPayload,
        semanticFingerprint: String,
        factsHash: String,
        language: AppLanguage
    ) async throws -> Delivery? {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        guard let state = try await client.statusIfExists(
            userID: userID,
            analysisID: analysisID,
            language: language
        ) else {
            return nil
        }

        switch state.status {
        case "completed":
            return try await fetchDelivery(
                analysisID: analysisID,
                payload: payload,
                semanticFingerprint: semanticFingerprint,
                factsHash: factsHash,
                language: language
            )
        case "failed":
            throw ThemeAnalysisError.relay(
                state.error ?? "Theme report generation failed"
            )
        default:
            return try await waitForReport(
                analysisID: analysisID,
                payload: payload,
                semanticFingerprint: semanticFingerprint,
                factsHash: factsHash,
                language: language
            )
        }
    }

    private func waitForReport(
        analysisID: String,
        payload: ThemeAIPayload,
        semanticFingerprint: String,
        factsHash: String,
        language: AppLanguage
    ) async throws -> Delivery {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()

        while !Task.isCancelled {
            let state = try await client.status(
                userID: userID,
                analysisID: analysisID,
                language: language
            )
            switch state.status {
            case "completed":
                return try await fetchDelivery(
                    analysisID: analysisID,
                    payload: payload,
                    semanticFingerprint: semanticFingerprint,
                    factsHash: factsHash,
                    language: language
                )
            case "failed":
                throw ThemeAnalysisError.relay(
                    state.error ?? "Theme report generation failed"
                )
            default:
                try await Task.sleep(
                    nanoseconds: 10_000_000_000
                )
            }
        }

        throw CancellationError()
    }

    private func fetchDelivery(
        analysisID: String,
        payload: ThemeAIPayload,
        semanticFingerprint: String,
        factsHash: String,
        language: AppLanguage
    ) async throws -> Delivery {
        let userID = CommerceStore.shared.userID.uuidString.lowercased()
        let data = try await client.fetch(
            userID: userID,
            analysisID: analysisID,
            language: language
        )
        let response = try JSONDecoder().decode(
            AIGenerateResponse.self,
            from: data
        )
        guard response.semanticFingerprint == semanticFingerprint,
              response.factsHash == factsHash
        else {
            throw ThemeAnalysisError.invalidReportContract
        }

        let report = ThemeReportResponse(
            title: response.report.title,
            subtitle: response.report.subtitle,
            sections: response.report.sections.map {
                ThemeReportSection(
                    number: $0.number,
                    title: $0.title,
                    body: $0.body,
                    callout: $0.callout,
                    evidenceFactIDs: $0.evidenceFactIDs
                )
            }
        )
        try validate(
            report: report,
            evidenceFacts: payload.flattenedEvidenceFacts
        )
        return Delivery(
            report: report,
            requestID: analysisID
        )
    }

    private func requestBody(
        analysisID: String,
        payload: ThemeAIPayload,
        input: ThemeInput,
        semanticFingerprint: String,
        factsHash: String,
        language: AppLanguage
    ) throws -> Data {
        let identity = try identity(payload: payload, input: input)
        guard identity.semanticFingerprint == semanticFingerprint,
              identity.factsHash == factsHash
        else {
            throw ThemeAnalysisError.invalidReportContract
        }

        let body: [String: Any] = [
            "userID": CommerceStore.shared.userID.uuidString.lowercased(),
            "requestID": analysisID,
            "reportID": semanticFingerprint,
            "mode": "theme",
            "themeKind": payload.analysis.theme,
            "reportPromptKey": "theme.\(payload.analysis.theme)",
            "profileHash":
                AppAIReportService().profileHash(input.primary.profile),
            "semanticFingerprint": semanticFingerprint,
            "factsHash": factsHash,
            "generationSchemaVersion":
                GeneratedChartArtifact.schemaVersion,
            "params": identity.params,
            "facts": identity.facts,
            "locale": language.reportRequestLanguage.rawValue,
            "clientVersion": "ios-v7-theme-recovery",
        ]

        return try JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )
    }

    private func validate(
        report: ThemeReportResponse,
        evidenceFacts: [ThemeAIFact]
    ) throws {
        let allowedIDs = Set(evidenceFacts.map(\.id))
        guard !report.title.trimmed.isEmpty,
              !report.subtitle.trimmed.isEmpty,
              (4 ... 12).contains(report.sections.count),
              report.sections.allSatisfy({ section in
                  !section.number.trimmed.isEmpty
                      && !section.title.trimmed.isEmpty
                      && !section.body.trimmed.isEmpty
                      && !(section.evidenceFactIDs ?? []).isEmpty
                      && (section.evidenceFactIDs ?? [])
                      .allSatisfy(allowedIDs.contains)
              })
        else {
            throw ThemeAnalysisError.invalidReportContract
        }
    }
}

@MainActor
final class ThemeAnalysisManager: ObservableObject {
    static let shared = ThemeAnalysisManager()

    private let planner = ThemePlanner()
    private let coordinator = ThemeCalculationCoordinator()
    private let factsBuilder = ThemeFactsBuilder()
    private let reportService = ThemeReportService()
    private let store = ThemeAnalysisStore.shared
    private var reportTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func start(input: ThemeInput, model: AppModel) async throws -> ThemeAnalysis {
        let recipe = planner.recipe(for: input)
        let artifacts = try await coordinator.calculate(input: input, recipe: recipe, model: model)
        let payload = factsBuilder.build(input: input, recipe: recipe, artifacts: artifacts)
        let identity = try reportService.identity(payload: payload, input: input)
        if let cached = store.analyses.first(where: {
            $0.semanticFingerprint == identity.semanticFingerprint
                && $0.factsHash == identity.factsHash
                && $0.status == .completed
                && $0.report != nil
        }) {
            return cached
        }
        let analysisID = UUID().uuidString.lowercased()
        let analysis = ThemeAnalysis(
            id: analysisID,
            createdAt: Date(),
            input: input,
            recipe: recipe,
            chartArtifacts: artifacts,
            semanticFingerprint: identity.semanticFingerprint,
            factsHash: identity.factsHash,
            report: nil,
            status: .chartsReady,
            generationError: nil
        )
        guard store.upsert(analysis) else { throw ThemeAnalysisError.invalidRelayResponse }
        beginReportGeneration(analysisID: analysisID, model: model)
        return analysis
    }

    func retry(analysisID: String, model: AppModel) {
        guard reportTasks[analysisID] == nil,
              let analysis = store.analysis(id: analysisID),
              analysis.report == nil
        else { return }

        // Manual retry remains the only Theme path that may submit again.
        beginReportGeneration(analysisID: analysisID, model: model)
    }

    func resumePendingReport(
        analysisID: String,
        model: AppModel
    ) {
        guard reportTasks[analysisID] == nil,
              let analysis = store.analysis(id: analysisID),
              analysis.report == nil,
              analysis.status == .chartsReady
                  || analysis.status == .generatingReport
        else { return }

        // Automatic resume is recovery-only. It must never create a second
        // Relay task.
        reportTasks[analysisID] = Task { [weak self] in
            guard let self else { return }
            defer { self.reportTasks[analysisID] = nil }

            do {
                guard let current = self.store.analysis(id: analysisID)
                else { return }

                let payload = self.factsBuilder.build(
                    input: current.input,
                    recipe: current.recipe,
                    artifacts: current.chartArtifacts
                )
                let identity = try self.reportService.identity(
                    payload: payload,
                    input: current.input
                )
                guard identity.semanticFingerprint
                    == current.semanticFingerprint,
                    identity.factsHash == current.factsHash
                else {
                    throw ThemeAnalysisError.invalidReportContract
                }

                guard let delivery = try await self.reportService.recover(
                    analysisID: analysisID,
                    payload: payload,
                    semanticFingerprint: identity.semanticFingerprint,
                    factsHash: identity.factsHash,
                    language: current.input.locale
                ) else {
                    // chartsReady can legitimately mean the user never
                    // submitted an AI task (offline / no consent).
                    if current.status == .chartsReady {
                        return
                    }

                    var missing = current
                    missing.status = .reportFailed
                    missing.generationError =
                        "The Relay has no Theme report for this request."
                    _ = self.store.upsert(missing)
                    return
                }

                guard var completed = self.store.analysis(id: analysisID)
                else { return }
                completed.report = delivery.report
                completed.status = .completed
                completed.generationError = nil
                guard self.store.upsert(completed) else {
                    throw ThemeAnalysisError.invalidRelayResponse
                }
                await CommerceStore.shared.acknowledgeReport(
                    requestID: delivery.requestID
                )
            } catch is CancellationError {
                // Keep the persisted state recoverable. Never turn a client
                // interruption into a new generation request.
            } catch is URLError {
                // Transport failure is not Relay failure. The next page open
                // can reconcile the same requestID again.
            } catch {
                if var failed = self.store.analysis(id: analysisID) {
                    failed.status = .reportFailed
                    failed.generationError = error.localizedDescription
                    _ = self.store.upsert(failed)
                }
            }
        }
    }

    private func beginReportGeneration(analysisID: String, model: AppModel) {
        guard reportTasks[analysisID] == nil else { return }
        guard var analysis = store.analysis(id: analysisID) else { return }

        guard model.aiConsentGranted else {
            analysis.status = .chartsReady
            analysis.generationError = nil
            store.upsert(analysis)
            return
        }
        guard model.isOnline else {
            analysis.status = .chartsReady
            analysis.generationError = nil
            store.upsert(analysis)
            return
        }

        analysis.status = .generatingReport
        analysis.generationError = nil
        store.upsert(analysis)
        reportTasks[analysisID] = Task { [weak self] in
            guard let self else { return }
            do {
                guard let current = self.store.analysis(id: analysisID) else { return }
                let payload = self.factsBuilder.build(
                    input: current.input,
                    recipe: current.recipe,
                    artifacts: current.chartArtifacts
                )
                let identity = try self.reportService.identity(payload: payload, input: current.input)
                guard identity.semanticFingerprint == current.semanticFingerprint,
                      identity.factsHash == current.factsHash
                else { throw ThemeAnalysisError.invalidReportContract }
                let delivery = try await self.reportService.generate(
                    analysisID: analysisID,
                    payload: payload,
                    input: current.input,
                    semanticFingerprint: identity.semanticFingerprint,
                    factsHash: identity.factsHash,
                    language: current.input.locale
                )
                guard var completed = self.store.analysis(id: analysisID) else { return }
                completed.report = delivery.report
                completed.status = .completed
                completed.generationError = nil
                guard self.store.upsert(completed) else {
                    throw ThemeAnalysisError.invalidRelayResponse
                }
                await CommerceStore.shared.acknowledgeReport(requestID: delivery.requestID)
            } catch is CancellationError {
                if var current = self.store.analysis(id: analysisID) {
                    current.status = .generatingReport
                    current.generationError = nil
                    self.store.upsert(current)
                }
            } catch is URLError {
                if var current = self.store.analysis(id: analysisID) {
                    current.status = .generatingReport
                    current.generationError = nil
                    self.store.upsert(current)
                }
            } catch {
                if var failed = self.store.analysis(id: analysisID) {
                    failed.status = .reportFailed
                    failed.generationError = error.localizedDescription
                    self.store.upsert(failed)
                }
            }
            self.reportTasks[analysisID] = nil
        }
    }
}

// MARK: - Themes UI

private struct ThemePersonChoice: Identifiable {
    let id: String
    let name: String
    let profile: UserProfile
    let savedPersonID: UUID?
}

private struct ThemeFamilySelection: Identifiable, Equatable {
    let personID: String
    var role: ThemeFamilyRole

    var id: String { personID }
}

private enum ThemeNewPersonTarget {
    case relationship
    case family
}

struct ThemesView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var store = ThemeAnalysisStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(localized("themes.title", language: model.language))
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.text)

                        ThemeConstellationHero()
                            .frame(height: 132)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(localized("themes.hero.question", language: model.language))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(localized("themes.subtitle", language: model.language))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink {
                            ThemeSetupView(kind: .loveRelationships)
                        } label: {
                            themeHeroCard(.loveRelationships)
                        }
                        .buttonStyle(ThemeCardPressStyle())
                        .accessibilityIdentifier("theme-card-love_relationships")

                        HStack(alignment: .top, spacing: 12) {
                            NavigationLink {
                                ThemeSetupView(kind: .careerPurpose)
                            } label: {
                                themeHalfCard(.careerPurpose)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-career_purpose")

                            NavigationLink {
                                ThemeSetupView(kind: .selfWellbeing)
                            } label: {
                                themeHalfCard(.selfWellbeing)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-self_wellbeing")
                        }

                        NavigationLink {
                            ThemeSetupView(kind: .familyHome)
                        } label: {
                            themeWideCard(.familyHome)
                        }
                        .buttonStyle(ThemeCardPressStyle())
                        .accessibilityIdentifier("theme-card-family_home")

                        HStack(alignment: .top, spacing: 12) {
                            NavigationLink {
                                ThemeSetupView(kind: .moneyGrowth)
                            } label: {
                                themeHalfCard(.moneyGrowth)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-money_growth")

                            NavigationLink {
                                ThemeSetupView(kind: .creativityExpression)
                            } label: {
                                themeHalfCard(.creativityExpression)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-creativity_expression")
                        }

                        VStack(spacing: 10) {
                            NavigationLink {
                                ThemeSetupView(kind: .learningExploration)
                            } label: {
                                themeCompactRow(.learningExploration)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-learning_exploration")

                            NavigationLink {
                                ThemeSetupView(kind: .lifeDirection)
                            } label: {
                                themeCompactRow(.lifeDirection)
                            }
                            .buttonStyle(ThemeCardPressStyle())
                            .accessibilityIdentifier("theme-card-life_direction")
                        }

                        ThemeHistorySection(analyses: store.analyses)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func themeHeroCard(_ kind: ThemeKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ThemeNodeMotif(kind: kind, density: .hero)
                .frame(height: 88)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title(language: model.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                    Text(kind.cardKeywords(language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                themeChevron
            }
        }
        .frame(maxWidth: .infinity, minHeight: 192, alignment: .topLeading)
        .themeWorldSurface(accent: accent(for: kind), prominence: .hero)
    }

    private func themeHalfCard(_ kind: ThemeKind) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            ThemeNodeMotif(kind: kind, density: .compact)
                .frame(height: 60)

            Text(kind.title(language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Text(kind.cardKeywords(language: model.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
            themeChevron
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .themeWorldSurface(accent: accent(for: kind), prominence: .standard)
    }

    private func themeWideCard(_ kind: ThemeKind) -> some View {
        HStack(spacing: 16) {
            ThemeNodeMotif(kind: kind, density: .compact)
                .frame(width: 92, height: 74)

            VStack(alignment: .leading, spacing: 6) {
                Text(kind.title(language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(kind.cardKeywords(language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            themeChevron
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .themeWorldSurface(accent: accent(for: kind), prominence: .standard)
    }

    private func themeCompactRow(_ kind: ThemeKind) -> some View {
        HStack(spacing: 13) {
            ThemeNodeMotif(kind: kind, density: .row)
                .frame(width: 56, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title(language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(kind.cardKeywords(language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            themeChevron
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .themeWorldSurface(accent: accent(for: kind), prominence: .compact)
    }

    private var themeChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(AppTheme.violet)
            .frame(width: 28, height: 28)
            .background(AppTheme.violet.opacity(0.09), in: Circle())
    }

    private func accent(for kind: ThemeKind) -> Color {
        switch kind {
        case .loveRelationships: AppTheme.coral
        case .careerPurpose: AppTheme.blue
        case .moneyGrowth: AppTheme.mint
        case .familyHome: AppTheme.amber
        case .selfWellbeing: AppTheme.violet
        case .creativityExpression: AppTheme.coral
        case .learningExploration: AppTheme.blue
        case .lifeDirection: AppTheme.violet
        }
    }
}

private extension ThemeKind {
    func cardKeywords(language: AppLanguage) -> String {
        switch self {
        case .loveRelationships: localized("themes.card.love-relationships", language: language)
        case .careerPurpose: localized("themes.card.career-purpose", language: language)
        case .moneyGrowth: localized("themes.card.money-growth", language: language)
        case .familyHome: localized("themes.card.family-home", language: language)
        case .selfWellbeing: localized("themes.card.self-wellbeing", language: language)
        case .creativityExpression: localized("themes.card.creativity-expression", language: language)
        case .learningExploration: localized("themes.card.learning-exploration", language: language)
        case .lifeDirection: localized("themes.card.life-direction", language: language)
        }
    }
}

private struct ThemeConstellationHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let normalized: [CGPoint] = [
                    CGPoint(x: 0.50, y: 0.47),
                    CGPoint(x: 0.23, y: 0.67),
                    CGPoint(x: 0.34, y: 0.23),
                    CGPoint(x: 0.68, y: 0.21),
                    CGPoint(x: 0.79, y: 0.66),
                    CGPoint(x: 0.55, y: 0.83),
                ]
                let accents: [Color] = [
                    AppTheme.violet,
                    AppTheme.coral,
                    AppTheme.blue,
                    AppTheme.mint,
                    AppTheme.amber,
                    AppTheme.violet,
                ]
                let sizes: [CGFloat] = [14, 8, 7, 9, 7, 6]
                let points = normalized.enumerated().map { index, point in
                    let phase = Double(index) * 0.93
                    let dx = reduceMotion ? 0 : CGFloat(sin(time * 0.43 + phase)) * (index == 0 ? 1.2 : 2.4)
                    let dy = reduceMotion ? 0 : CGFloat(sin(time * 0.51 + phase + 0.8)) * (index == 0 ? 1.0 : 2.2)
                    return CGPoint(x: width * point.x + dx, y: height * point.y + dy)
                }
                let pulse = CGFloat((sin(time * 0.78) + 1) / 2)

                ZStack {
                    Circle()
                        .fill(AppTheme.violet.opacity(0.035 + 0.025 * pulse))
                        .frame(width: min(width * 0.72, 230), height: min(width * 0.72, 230))
                        .blur(radius: 18)
                        .position(x: width * 0.5, y: height * 0.52)

                    Canvas { context, _ in
                        let center = points[0]
                        for index in 1 ..< points.count {
                            var path = Path()
                            path.move(to: center)
                            if index == 5 {
                                path.addCurve(
                                    to: points[index],
                                    control1: CGPoint(x: width * 0.42, y: height * 0.68),
                                    control2: CGPoint(x: width * 0.45, y: height * 0.81)
                                )
                            } else {
                                path.addLine(to: points[index])
                            }
                            let wave = CGFloat((sin(time * 0.64 + Double(index) * 0.72) + 1) / 2)
                            context.stroke(
                                path,
                                with: .color(AppTheme.violet.opacity(0.12 + 0.15 * wave)),
                                lineWidth: index == 3 ? 1.2 : 1
                            )
                        }

                        var outerArc = Path()
                        outerArc.move(to: points[1])
                        outerArc.addCurve(
                            to: points[5],
                            control1: CGPoint(x: width * 0.27, y: height * 0.96),
                            control2: CGPoint(x: width * 0.47, y: height * 0.99)
                        )
                        outerArc.move(to: points[3])
                        outerArc.addCurve(
                            to: points[4],
                            control1: CGPoint(x: width * 0.82, y: height * 0.28),
                            control2: CGPoint(x: width * 0.87, y: height * 0.52)
                        )
                        context.stroke(
                            outerArc,
                            with: .color(AppTheme.blue.opacity(0.12 + 0.08 * pulse)),
                            lineWidth: 0.9
                        )
                    }

                    ForEach(points.indices, id: \.self) { index in
                        let nodePulse = CGFloat((sin(time * 0.72 + Double(index) * 1.04) + 1) / 2)
                        ZStack {
                            Circle()
                                .stroke(accents[index].opacity(0.12 + 0.08 * nodePulse), lineWidth: 1)
                                .frame(width: sizes[index] + 15 + 4 * nodePulse, height: sizes[index] + 15 + 4 * nodePulse)
                            Circle()
                                .fill(accents[index].opacity(index == 0 ? 0.88 : 0.72))
                                .frame(width: sizes[index], height: sizes[index])
                        }
                        .position(points[index])
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ThemeCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.965 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private enum ThemeMotifDensity {
    case hero
    case compact
    case row
}

private struct ThemeNodeMotif: View {
    let kind: ThemeKind
    let density: ThemeMotifDensity

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let accent = motifAccent
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.68))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.40))
                    path.addLine(to: CGPoint(x: width * 0.80, y: height * 0.64))
                    path.move(to: CGPoint(x: width * 0.48, y: height * 0.40))
                    path.addLine(to: CGPoint(x: width * 0.62, y: height * 0.18))
                }
                .stroke(accent.opacity(0.26), lineWidth: 1)

                motifNode(size: density == .hero ? 10 : 7, accent: accent)
                    .position(x: width * 0.18, y: height * 0.68)
                motifNode(size: density == .hero ? 14 : 10, accent: accent)
                    .position(x: width * 0.48, y: height * 0.40)
                motifNode(size: density == .hero ? 8 : 6, accent: accent)
                    .position(x: width * 0.80, y: height * 0.64)
                motifNode(size: density == .hero ? 7 : 5, accent: accent)
                    .position(x: width * 0.62, y: height * 0.18)

                Image(systemName: kind.systemImage)
                    .font(density == .hero ? .title2.weight(.light) : .caption.weight(.medium))
                    .foregroundStyle(accent.opacity(0.72))
                    .position(x: width * 0.48, y: height * 0.40)
            }
        }
        .accessibilityHidden(true)
    }

    private var motifAccent: Color {
        switch kind {
        case .loveRelationships: AppTheme.coral
        case .careerPurpose: AppTheme.blue
        case .moneyGrowth: AppTheme.mint
        case .familyHome: AppTheme.amber
        case .selfWellbeing: AppTheme.violet
        case .creativityExpression: AppTheme.coral
        case .learningExploration: AppTheme.blue
        case .lifeDirection: AppTheme.violet
        }
    }

    private func motifNode(size: CGFloat, accent: Color) -> some View {
        Circle()
            .fill(accent.opacity(0.72))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .stroke(accent.opacity(0.14), lineWidth: 1)
                    .frame(width: size + 8, height: size + 8)
            )
    }
}

private enum ThemeWorldProminence {
    case hero
    case standard
    case compact
}

private struct ThemeWorldSurface: ViewModifier {
    let accent: Color
    let prominence: ThemeWorldProminence

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = prominence == .compact ? 18 : 24
        let padding: CGFloat = prominence == .compact ? 13 : 17
        content
            .padding(padding)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelRaised, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background(alignment: .topTrailing) {
                Circle()
                    .fill(accent.opacity(prominence == .hero ? 0.10 : 0.065))
                    .frame(width: prominence == .hero ? 150 : 105, height: prominence == .hero ? 150 : 105)
                    .blur(radius: 7)
                    .offset(x: 32, y: -42)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(prominence == .hero ? 0.18 : 0.12), lineWidth: 1)
            )
    }
}

private extension View {
    func themeWorldSurface(accent: Color, prominence: ThemeWorldProminence) -> some View {
        modifier(ThemeWorldSurface(accent: accent, prominence: prominence))
    }
}

struct ThemeHistorySection: View {
    @EnvironmentObject private var model: AppModel
    let analyses: [ThemeAnalysis]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("themes.recent", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if analyses.isEmpty {
                Text(localized("themes.no-recent", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(analyses.prefix(6).enumerated()), id: \.element.id) { index, analysis in
                        NavigationLink {
                            ThemeResultView(analysisID: analysis.id)
                        } label: {
                            historyRow(analysis)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("theme-history-\(analysis.id)")
                        if index < min(analyses.count, 6) - 1 {
                            Divider().overlay(AppTheme.line)
                        }
                    }
                }
                .cardSurface()
            }
        }
    }

    private func historyRow(_ analysis: ThemeAnalysis) -> some View {
        HStack(spacing: 12) {
            Image(systemName: analysis.input.theme.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 34, height: 34)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(analysis.input.theme.title(language: model.language))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(historySubtitle(analysis))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                Text(LocalizedFormatters.shortDateWithYear(analysis.createdAt, language: model.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                if analysis.status == .generatingReport || analysis.status == .chartsReady {
                    Label(localized("themes.report.preparing", language: model.language), systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppTheme.violet)
                } else if analysis.status == .reportFailed {
                    Label(localized("themes.report.retry", language: model.language), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(AppTheme.coral)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func historySubtitle(_ analysis: ThemeAnalysis) -> String {
        if analysis.input.theme == .loveRelationships,
           analysis.input.analysisMode == .specificRelationship,
           let other = analysis.input.otherPerson
        {
            return "\(analysis.input.primary.name) & \(other.name)"
        }
        if analysis.input.theme == .familyHome, !analysis.input.familyMembers.isEmpty {
            return "\(analysis.input.primary.name) · " + localizedTemplate(
                "themes.history.members",
                substitutions: ["value": String(analysis.input.familyMembers.count)],
                language: model.language
            )
        }
        return analysis.input.horizon.title(language: model.language)
    }
}

struct ThemeSetupView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared

    let kind: ThemeKind

    @State private var primaryPersonID = "self"
    @State private var loveMode: ThemeLoveAnalysisMode = .myLoveLife
    @State private var otherPersonID: String?
    @State private var familySelections: [ThemeFamilySelection] = []
    @State private var horizon: ThemeHorizon = .now
    @State private var location: ChartLocationSelection?
    @State private var focus = "overall"
    @State private var relationshipStatus = "prefer_not"
    @State private var relationshipType = "romantic"
    @State private var careerStage = "working"
    @State private var showsLocationSearch = false
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var resultAnalysisID: String?
    @State private var showsResult = false
    @State private var editingNewPerson: SavedPerson?
    @State private var newPersonTarget: ThemeNewPersonTarget?
    @State private var showsAIConsentReminder = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(
                        eyebrow: localized("themes.title", language: model.language).uppercased(),
                        title: kind.title(language: model.language),
                        subtitle: kind.subtitle(language: model.language)
                    )

                    if kind == .loveRelationships {
                        setupSection(localized("themes.analysis", language: model.language)) {
                            Picker("", selection: $loveMode) {
                                ForEach(ThemeLoveAnalysisMode.allCases) { mode in
                                    Text(mode.title(language: model.language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: loveMode) { _, _ in
                                focus = "overall"
                                if loveMode == .myLoveLife { otherPersonID = nil }
                            }
                        }
                    }

                    setupSection(localized("themes.you", language: model.language)) {
                        Menu {
                            ForEach(primaryChoices) { choice in
                                Button(choice.name) {
                                    selectPrimary(choice.id)
                                }
                            }
                        } label: {
                            selectionRow(primaryChoice?.name ?? model.profile.name, systemImage: "person.crop.circle")
                        }
                    }

                    if kind == .loveRelationships {
                        if loveMode == .specificRelationship {
                            relationshipPersonSection
                            relationshipTypeSection
                        } else {
                            relationshipStatusSection
                        }
                    }

                    if kind == .familyHome {
                        familyMembersSection
                    }

                    if kind == .careerPurpose {
                        careerStageSection
                    }

                    setupSection(localized("themes.time-period", language: model.language)) {
                        Picker("", selection: $horizon) {
                            ForEach(ThemeHorizon.allCases) { value in
                                Text(value.title(language: model.language)).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    setupSection(localized("themes.current-location", language: model.language)) {
                        Button {
                            showsLocationSearch = true
                        } label: {
                            selectionRow(
                                location?.placeName ?? primaryChoice?.profile.placeName ?? model.profile.placeName,
                                systemImage: "mappin.and.ellipse"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    focusSection

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
                            if isCalculating {
                                ProgressView().tint(.white)
                            }
                            Text(isCalculating
                                 ? localized("themes.calculating", language: model.language)
                                 : localized("themes.analyze", language: model.language))
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("theme-analyze-button")
                    .disabled(isCalculating || !canAnalyze)
                    .opacity((isCalculating || !canAnalyze) ? 0.55 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 80)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if location == nil { location = locationForPrimary() }
        }
        .sheet(isPresented: $showsLocationSearch) {
            LocationSearchView(language: model.language) { selection in
                location = ChartLocationSelection(
                    placeName: selection.name,
                    timezoneID: selection.timezoneID,
                    latitude: selection.latitude,
                    longitude: selection.longitude
                )
            }
        }
        .sheet(item: $editingNewPerson) { person in
            SavedPersonEditorView(
                person: person,
                language: model.language,
                onSave: { saved in
                    model.savePerson(saved)
                    applyNewPerson(saved)
                }
            )
        }
        .navigationDestination(isPresented: $showsResult) {
            if let resultAnalysisID {
                ThemeResultView(analysisID: resultAnalysisID)
            }
        }
        .alert(
            localized("ai.network-consent.title", language: model.language),
            isPresented: $showsAIConsentReminder
        ) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                Task { await analyze() }
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {}
        } message: {
            Text(localized("themes.ai-consent.message", language: model.language))
        }
    }

    private var primaryChoices: [ThemePersonChoice] {
        [
            ThemePersonChoice(id: "self", name: model.profile.name, profile: model.profile, savedPersonID: nil),
        ] + model.savedPeople.map {
            ThemePersonChoice(
                id: $0.id.uuidString,
                name: $0.profile.name,
                profile: $0.profile,
                savedPersonID: $0.id
            )
        }
    }

    private var primaryChoice: ThemePersonChoice? {
        primaryChoices.first { $0.id == primaryPersonID }
    }

    private var secondaryChoices: [ThemePersonChoice] {
        model.savedPeople.compactMap { person in
            let id = person.id.uuidString
            guard id != primaryPersonID else { return nil }
            return ThemePersonChoice(
                id: id,
                name: person.profile.name,
                profile: person.profile,
                savedPersonID: person.id
            )
        }
    }

    private var availableFamilyChoices: [ThemePersonChoice] {
        let used = Set(familySelections.map(\.personID))
        return secondaryChoices.filter { !used.contains($0.id) }
    }

    @ViewBuilder
    private var relationshipPersonSection: some View {
        setupSection(localized("themes.other-person", language: model.language)) {
            Menu {
                ForEach(secondaryChoices) { choice in
                    Button(choice.name) { otherPersonID = choice.id }
                }
                Divider()
                Button {
                    beginNewPerson(for: .relationship)
                } label: {
                    Label(localized("themes.new-person", language: model.language), systemImage: "person.badge.plus")
                }
            } label: {
                selectionRow(
                    secondaryChoices.first(where: { $0.id == otherPersonID })?.name
                        ?? localized("themes.select-other-person", language: model.language),
                    systemImage: "person.2"
                )
            }
        }
    }

    @ViewBuilder
    private var relationshipStatusSection: some View {
        setupSection(localized("themes.relationship-status", language: model.language)) {
            Menu {
                ForEach(relationshipStatusOptions) { option in
                    Button(option.title(language: model.language)) { relationshipStatus = option.id }
                }
            } label: {
                selectionRow(
                    relationshipStatusOptions.first(where: { $0.id == relationshipStatus })?.title(language: model.language)
                        ?? relationshipStatus,
                    systemImage: "heart"
                )
            }
        }
    }

    @ViewBuilder
    private var relationshipTypeSection: some View {
        setupSection(localized("themes.relationship-type", language: model.language)) {
            Menu {
                ForEach(relationshipTypeOptions) { option in
                    Button(option.title(language: model.language)) { relationshipType = option.id }
                }
            } label: {
                selectionRow(
                    relationshipTypeOptions.first(where: { $0.id == relationshipType })?.title(language: model.language)
                        ?? relationshipType,
                    systemImage: "heart.circle"
                )
            }
        }
    }

    @ViewBuilder
    private var careerStageSection: some View {
        setupSection(localized("themes.current-stage", language: model.language)) {
            Menu {
                ForEach(careerStageOptions) { option in
                    Button(option.title(language: model.language)) { careerStage = option.id }
                }
            } label: {
                selectionRow(
                    careerStageOptions.first(where: { $0.id == careerStage })?.title(language: model.language)
                        ?? careerStage,
                    systemImage: "briefcase"
                )
            }
        }
    }

    @ViewBuilder
    private var familyMembersSection: some View {
        setupSection(localized("themes.family-members", language: model.language)) {
            VStack(spacing: 10) {
                ForEach($familySelections) { $selection in
                    if let choice = secondaryChoices.first(where: { $0.id == selection.personID }) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Menu {
                                    ForEach(ThemeFamilyRole.allCases) { role in
                                        Button(role.title(language: model.language)) { selection.role = role }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selection.role.title(language: model.language))
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.violet)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                familySelections.removeAll { $0.personID == selection.personID }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.line))
                    }
                }

                if familySelections.count < ThemeDefinitionRegistry.maxFamilyMembers {
                    Menu {
                        ForEach(availableFamilyChoices) { choice in
                            Button(choice.name) { addFamilyMember(choice.id) }
                        }
                        Divider()
                        Button {
                            beginNewPerson(for: .family)
                        } label: {
                            Label(localized("themes.new-person", language: model.language), systemImage: "person.badge.plus")
                        }
                    } label: {
                        Label(localized("themes.add-family-member", language: model.language), systemImage: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                    }
                }

                Text(localized("themes.family-member-limit", language: model.language))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var focusSection: some View {
        setupSection(localized("themes.focus", language: model.language)) {
            Menu {
                ForEach(currentFocusOptions) { option in
                    Button(option.title(language: model.language)) { focus = option.id }
                }
            } label: {
                selectionRow(
                    currentFocusOptions.first(where: { $0.id == focus })?.title(language: model.language)
                        ?? currentFocusOptions.first?.title(language: model.language)
                        ?? focus,
                    systemImage: "scope"
                )
            }
        }
    }

    private var currentFocusOptions: [ThemeOption] {
        if kind == .loveRelationships, loveMode == .specificRelationship {
            return [
                ThemeOption(id: "overall", titleKey: "themes.focus.love-relationships.overall"),
                ThemeOption(id: "emotional_connection", titleKey: "themes.focus.love-relationships.emotional-connection"),
                ThemeOption(id: "communication", titleKey: "themes.focus.love-relationships.communication"),
                ThemeOption(id: "attraction_intimacy", titleKey: "themes.focus.love-relationships.attraction-intimacy"),
                ThemeOption(id: "stability_tension", titleKey: "themes.focus.love-relationships.stability-tension"),
                ThemeOption(id: "current_phase", titleKey: "themes.focus.love-relationships.current-phase"),
            ]
        }
        return kind.definition.focusOptions
    }

    private var relationshipStatusOptions: [ThemeOption] {
        [
            ThemeOption(id: "single", titleKey: "themes.relationship-status.single"),
            ThemeOption(id: "dating", titleKey: "themes.relationship-status.dating"),
            ThemeOption(id: "in_relationship", titleKey: "themes.relationship-status.in-relationship"),
            ThemeOption(id: "complicated", titleKey: "themes.relationship-status.complicated"),
            ThemeOption(id: "prefer_not", titleKey: "themes.relationship-status.prefer-not"),
        ]
    }

    private var relationshipTypeOptions: [ThemeOption] {
        [
            ThemeOption(id: "romantic", titleKey: "themes.relationship-type.romantic"),
            ThemeOption(id: "dating", titleKey: "themes.relationship-type.dating"),
            ThemeOption(id: "friendship", titleKey: "themes.relationship-type.friendship"),
            ThemeOption(id: "ex_partner", titleKey: "themes.relationship-type.ex-partner"),
            ThemeOption(id: "other", titleKey: "themes.relationship-type.other"),
        ]
    }

    private var careerStageOptions: [ThemeOption] {
        [
            ThemeOption(id: "working", titleKey: "themes.career-stage.working"),
            ThemeOption(id: "job_searching", titleKey: "themes.career-stage.job-searching"),
            ThemeOption(id: "changing_direction", titleKey: "themes.career-stage.changing-direction"),
            ThemeOption(id: "studying", titleKey: "themes.career-stage.studying"),
            ThemeOption(id: "self_employed", titleKey: "themes.career-stage.self-employed"),
            ThemeOption(id: "other", titleKey: "themes.career-stage.other"),
        ]
    }

    private var canAnalyze: Bool {
        guard primaryChoice != nil, location != nil else { return false }
        if kind == .loveRelationships, loveMode == .specificRelationship {
            return otherPersonID != nil
        }
        return true
    }

    private func selectPrimary(_ id: String) {
        primaryPersonID = id
        if otherPersonID == id { otherPersonID = nil }
        familySelections.removeAll { $0.personID == id }
        location = locationForPrimary()
    }

    private func locationForPrimary() -> ChartLocationSelection {
        let profile = primaryChoice?.profile ?? model.profile
        return ChartLocationSelection(
            placeName: profile.placeName,
            timezoneID: profile.timezoneID,
            latitude: profile.latitude,
            longitude: profile.longitude
        )
    }

    private func addFamilyMember(_ id: String) {
        guard familySelections.count < ThemeDefinitionRegistry.maxFamilyMembers,
              !familySelections.contains(where: { $0.personID == id })
        else { return }
        let relationship = model.savedPeople.first(where: { $0.id.uuidString == id })?.relationship
        let role: ThemeFamilyRole = switch relationship {
        case .partner?: .partnerSpouse
        case .family?: .relative
        default: .other
        }
        familySelections.append(ThemeFamilySelection(personID: id, role: role))
    }

    private func beginNewPerson(for target: ThemeNewPersonTarget) {
        newPersonTarget = target
        editingNewPerson = SavedPerson.new(using: primaryChoice?.profile ?? model.profile)
    }

    private func applyNewPerson(_ person: SavedPerson) {
        let id = person.id.uuidString
        switch newPersonTarget {
        case .relationship:
            otherPersonID = id
        case .family:
            addFamilyMember(id)
        case nil:
            break
        }
        newPersonTarget = nil
    }

    @MainActor
    private func requestAnalysis() {
        guard !isCalculating, canAnalyze else { return }
        guard model.aiConsentGranted else {
            showsAIConsentReminder = true
            return
        }
        Task { await analyze() }
    }

    @MainActor
    private func analyze() async {
        guard !isCalculating, canAnalyze, let input = buildInput() else { return }
        if commerce.account != nil && commerce.totalCredits < 2 {
            commerce.showsCredits = true
            return
        }
        isCalculating = true
        errorMessage = nil
        defer { isCalculating = false }
        do {
            let analysis = try await ThemeAnalysisManager.shared.start(input: input, model: model)
            resultAnalysisID = analysis.id
            showsResult = true
        } catch {
            errorMessage = localized("themes.calculation-failed", language: model.language)
        }
    }

    private func buildInput() -> ThemeInput? {
        guard let primaryChoice, let location else { return nil }
        let primary = ThemePersonSnapshot(
            id: primaryChoice.id,
            ref: "primary",
            name: primaryChoice.name,
            role: "self",
            profile: primaryChoice.profile
        )

        var other: ThemePersonSnapshot?
        if kind == .loveRelationships,
           loveMode == .specificRelationship,
           let otherPersonID,
           let choice = secondaryChoices.first(where: { $0.id == otherPersonID })
        {
            other = ThemePersonSnapshot(
                id: choice.id,
                ref: "person_b",
                name: choice.name,
                role: relationshipType,
                profile: choice.profile
            )
        }

        let family: [ThemePersonSnapshot] = familySelections.enumerated().compactMap { index, selection in
            guard let choice = secondaryChoices.first(where: { $0.id == selection.personID }) else { return nil }
            return ThemePersonSnapshot(
                id: choice.id,
                ref: "member_\(index + 1)",
                name: choice.name,
                role: selection.role.rawValue,
                profile: choice.profile
            )
        }

        let presetSnapshot = Dictionary(uniqueKeysWithValues: ChartKind.allCases.map {
            ($0.rawValue, model.preset(for: $0).rawValue)
        })

        return ThemeInput(
            theme: kind,
            analysisMode: kind == .loveRelationships ? loveMode : nil,
            analysisDate: Date(),
            primary: primary,
            otherPerson: other,
            familyMembers: family,
            horizon: horizon,
            location: location,
            focus: focus,
            optionalContext: "",
            relationshipType: kind == .loveRelationships && loveMode == .specificRelationship ? relationshipType : nil,
            relationshipStatus: kind == .loveRelationships && loveMode == .myLoveLife ? relationshipStatus : nil,
            careerStage: kind == .careerPurpose ? careerStage : nil,
            presets: presetSnapshot,
            locale: model.language
        )
    }

    private func setupSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.footnote.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func selectionRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 22)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .contentShape(Rectangle())
    }
}

private struct ThemeChartDisplayGroup: Identifiable {
    let id: String
    let label: String
    let artifacts: [ThemeChartArtifact]
}

struct ThemeChartSelector: View {
    let analysis: ThemeAnalysis
    let language: AppLanguage

    @State private var selectedGroupID: String?
    @State private var directionIndex = 0

    private var groups: [ThemeChartDisplayGroup] {
        var result: [ThemeChartDisplayGroup] = []
        var synastryBuckets: [String: [ThemeChartArtifact]] = [:]
        for artifact in analysis.chartArtifacts where artifact.task.displayInResult {
            if case let .relationship(kind) = artifact.task.technique, kind.isSynastry {
                let otherRef = artifact.task.participants.last?.ref ?? "relationship"
                synastryBuckets[otherRef, default: []].append(artifact)
            } else {
                result.append(
                    ThemeChartDisplayGroup(
                        id: artifact.id,
                        label: localized(artifact.task.displayLabelKey, language: language),
                        artifacts: [artifact]
                    )
                )
            }
        }
        for (ref, artifacts) in synastryBuckets.sorted(by: { $0.key < $1.key }) {
            let otherName = artifacts.first?.task.participants.last?.name
            let base = localized("themes.chart.synastry", language: language)
            result.insert(
                ThemeChartDisplayGroup(
                    id: "synastry.\(ref)",
                    label: otherName.map { "\(base) · \($0)" } ?? base,
                    artifacts: artifacts.sorted { $0.id < $1.id }
                ),
                at: min(result.count, ref == "person_b" ? 0 : result.count)
            )
        }
        return result
    }

    private var selectedGroup: ThemeChartDisplayGroup? {
        let id = selectedGroupID ?? groups.first?.id
        return groups.first { $0.id == id } ?? groups.first
    }

    private var selectedArtifact: ThemeChartArtifact? {
        guard let selectedGroup else { return nil }
        let index = min(directionIndex, max(0, selectedGroup.artifacts.count - 1))
        return selectedGroup.artifacts[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups) { group in
                        Button {
                            selectedGroupID = group.id
                            directionIndex = 0
                        } label: {
                            Text(group.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(selectedGroup?.id == group.id ? .white : AppTheme.violet)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(
                                    selectedGroup?.id == group.id ? AppTheme.violet : AppTheme.violet.opacity(0.09),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedGroup, selectedGroup.artifacts.count > 1 {
                Picker(localized("themes.chart.direction", language: language), selection: $directionIndex) {
                    ForEach(Array(selectedGroup.artifacts.enumerated()), id: \.offset) { index, artifact in
                        Text(directionLabel(artifact)).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let artifact = selectedArtifact, let frame = artifact.displayFrame {
                ChartWheelView(
                    snapshot: frame.snapshot,
                    reference: frame.reference,
                    comparisonAspects: frame.comparisonAspects,
                    language: language,
                    presentation: .theme
                )
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 360)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
                .accessibilityIdentifier("theme-result-wheel")

                NavigationLink {
                    ThemeChartDetailView(
                        title: selectedGroup?.label ?? localized(artifact.task.displayLabelKey, language: language),
                        frame: frame,
                        language: language
                    )
                } label: {
                    Label(localized("themes.chart.view-details", language: language), systemImage: "chart.xyaxis.line")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("theme-view-chart-details")
            } else {
                Text(localized("themes.chart.no-data", language: language))
                    .font(.body)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .onAppear {
            if selectedGroupID == nil { selectedGroupID = groups.first?.id }
        }
    }

    private func directionLabel(_ artifact: ThemeChartArtifact) -> String {
        guard artifact.task.participants.count >= 2 else {
            return localized(artifact.task.displayLabelKey, language: language)
        }
        let first = artifact.task.participants[0].name
        let second = artifact.task.participants[1].name
        if case .relationship(.synastryB) = artifact.task.technique {
            return "\(second) → \(first)"
        }
        return "\(first) → \(second)"
    }
}

private struct ThemeChartDetailView: View {
    let title: String
    let frame: ThemeChartFrame
    let language: AppLanguage
    @State private var viewMode: ChartViewMode = .wheel

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Picker("", selection: $viewMode) {
                        Text(localized("charts.wheel", language: language)).tag(ChartViewMode.wheel)
                        Text(localized("charts.aspects", language: language)).tag(ChartViewMode.aspects)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("theme-chart-view-mode")

                    if viewMode == .wheel {
                        ChartWheelView(
                            snapshot: frame.snapshot,
                            reference: frame.reference,
                            comparisonAspects: frame.comparisonAspects,
                            language: language,
                            presentation: .theme
                        )
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 410)
                        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("theme-detail-wheel")
                    } else {
                        AspectChartView(
                            aspects: frame.reference == nil ? frame.snapshot.aspects : frame.comparisonAspects,
                            movingPoints: frame.snapshot.points,
                            referencePoints: frame.reference?.points ?? [],
                            language: language,
                            comparison: frame.reference != nil
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("theme-detail-aspects")
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThemeResultView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var store = ThemeAnalysisStore.shared

    let analysisID: String
    @State private var showsAIConsentReminder = false

    private var analysis: ThemeAnalysis? {
        store.analysis(id: analysisID)
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            if let analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenTitle(
                            eyebrow: localized("themes.title", language: model.language).uppercased(),
                            title: analysis.input.theme.title(language: model.language),
                            subtitle: resultSubtitle(analysis)
                        )

                        reportSummary(analysis)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeading("themes.result.charts")
                            ThemeChartSelector(analysis: analysis, language: model.language)
                        }

                        reportState(analysis)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let report = analysis.report {
                            reportContent(report)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text(localized("themes.disclaimer", language: model.language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 80)
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resumePendingReport()
            presentConsentReminderIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            resumePendingReport()
            presentConsentReminderIfNeeded()
        }
        .alert(
            localized("ai.network-consent.title", language: model.language),
            isPresented: $showsAIConsentReminder
        ) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                ThemeAnalysisManager.shared.retry(analysisID: analysisID, model: model)
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {}
        } message: {
            Text(localized("themes.ai-consent.message", language: model.language))
        }
    }

    @ViewBuilder
    private func reportSummary(_ analysis: ThemeAnalysis) -> some View {
        if let report = analysis.report {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("themes.result.summary")
                Text(report.subtitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardSurface()
        } else {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.mint)
                Text(localized("themes.result.charts-ready", language: model.language))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
    }

    @ViewBuilder
    private func reportContent(_ report: ThemeReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(report.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(report.subtitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            VStack(alignment: .leading, spacing: 9) {
                Text(localized("reports.contents", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                ForEach(Array(report.sections.enumerated()), id: \.offset) { index, section in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(section.number.isEmpty ? String(format: "%02d", index + 1) : section.number)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(AppTheme.violet)
                        Text(section.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if index < report.sections.count - 1 {
                        Divider().overlay(AppTheme.line.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            VStack(alignment: .leading, spacing: 10) {
                sectionHeading("themes.result.detailed-analysis")
                ForEach(Array(report.sections.enumerated()), id: \.offset) { index, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(section.number.isEmpty ? String(format: "%02d", index + 1) : section.number) · \(section.title.uppercased())")
                            .font(.footnote.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.violet)
                        Text(section.body)
                            .font(.body)
                            .foregroundStyle(AppTheme.text)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        if let callout = section.callout, !callout.trimmed.isEmpty {
                            Text(callout)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.violet)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                }
            }
            .accessibilityIdentifier("theme-report-sections")
        }
    }

    @ViewBuilder
    private func reportState(_ analysis: ThemeAnalysis) -> some View {
        if analysis.report == nil {
            if !model.aiConsentGranted {
                EmptyView()
            } else if analysis.status == .generatingReport ||
                (analysis.status == .chartsReady && analysis.generationError == nil)
            {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(localized("themes.report.preparing", language: model.language))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                    }
                    Text(localized("themes.report.preparing-detail", language: model.language))
                        .font(.body)
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theme-report-preparing-card")
            } else if analysis.status == .reportFailed || analysis.status == .chartsReady {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        localized("themes.report.failed-title", language: model.language),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.headline)
                    .foregroundStyle(AppTheme.coral)
                    Text(analysis.generationError ?? localized("themes.report.failed-detail", language: model.language))
                        .font(.body)
                        .foregroundStyle(AppTheme.muted)
                    Button {
                        ThemeAnalysisManager.shared.retry(analysisID: analysis.id, model: model)
                    } label: {
                        Text(localized("themes.report.retry", language: model.language))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppTheme.violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            }
        }
    }

    private func presentConsentReminderIfNeeded() {
        guard let analysis,
              analysis.report == nil,
              !model.aiConsentGranted
        else { return }
        showsAIConsentReminder = true
    }

    private func resumePendingReport() {
        ThemeAnalysisManager.shared.resumePendingReport(analysisID: analysisID, model: model)
    }

    private func sectionHeading(_ key: String) -> some View {
        Text(localized(key, language: model.language))
            .font(.footnote.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(AppTheme.muted)
    }

    private func resultSubtitle(_ analysis: ThemeAnalysis) -> String {
        let people: String
        if analysis.input.theme == .loveRelationships,
           analysis.input.analysisMode == .specificRelationship,
           let other = analysis.input.otherPerson
        {
            people = "\(analysis.input.primary.name) & \(other.name)"
        } else if analysis.input.theme == .familyHome, !analysis.input.familyMembers.isEmpty {
            people = "\(analysis.input.primary.name) · " + localizedTemplate(
                "themes.history.members",
                substitutions: ["value": String(analysis.input.familyMembers.count)],
                language: model.language
            )
        } else {
            people = analysis.input.primary.name
        }

        let tz = TimeZone(identifier: analysis.input.location.timezoneID) ?? .current
        let start = LocalizedFormatters.shortDate(analysis.input.period.start, language: model.language, timeZone: tz)
        if analysis.input.horizon == .now { return "\(people) · \(start)" }
        let end = LocalizedFormatters.shortDate(analysis.input.period.end, language: model.language, timeZone: tz)
        return "\(people) · \(start) – \(end)"
    }
}
