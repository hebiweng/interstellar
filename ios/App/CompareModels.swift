import AstroCore
import Foundation


enum CompareAnalysisStage: String, Sendable {
    case calculatingCharts
    case comparingChanges
    case preparingAnalysis

    var localizationKey: String {
        switch self {
        case .calculatingCharts: "compare.stage.calculating-charts"
        case .comparingChanges: "compare.stage.comparing-changes"
        case .preparingAnalysis: "compare.stage.preparing-analysis"
        }
    }
}

enum CompareRelationshipContext: String, CaseIterable, Codable, Identifiable, Sendable {
    case romantic
    case friend
    case family
    case work
    case other
    case skip

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .romantic: localized("compare.relationship-context.romantic", language: language)
        case .friend: localized("compare.relationship-context.friend", language: language)
        case .family: localized("compare.relationship-context.family", language: language)
        case .work: localized("compare.relationship-context.work", language: language)
        case .other: localized("compare.relationship-context.other", language: language)
        case .skip: localized("compare.relationship-context.skip", language: language)
        }
    }
}

struct CompareSubject: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let profile: UserProfile

    static func owner(_ profile: UserProfile) -> CompareSubject {
        CompareSubject(id: "self", displayName: profile.name, profile: profile)
    }

    static func saved(_ person: SavedPerson) -> CompareSubject {
        CompareSubject(
            id: person.id.uuidString.lowercased(),
            displayName: person.profile.name,
            profile: person.profile
        )
    }
}

struct ComparePlace: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let location: ChartLocationSelection

    init(displayName: String, location: ChartLocationSelection) {
        self.displayName = displayName
        self.location = location
        id = Self.identity(for: location)
    }

    init(_ selection: LocationSelection) {
        self.init(
            displayName: selection.name,
            location: ChartLocationSelection(
                placeName: selection.name,
                timezoneID: selection.timezoneID,
                latitude: selection.latitude,
                longitude: selection.longitude
            )
        )
    }

    static func profileLocation(_ profile: UserProfile) -> ComparePlace {
        ComparePlace(
            displayName: profile.placeName,
            location: ChartLocationSelection(
                placeName: profile.placeName,
                timezoneID: profile.timezoneID,
                latitude: profile.latitude,
                longitude: profile.longitude
            )
        )
    }

    var validationIdentity: String { Self.identity(for: location) }

    private static func identity(for location: ChartLocationSelection) -> String {
        String(format: "%.6f|%.6f", location.latitude, location.longitude)
    }
}

struct CompareFocus: Codable, Equatable, Hashable, Identifiable, Sendable {
    static let maximumSelectionCount = CompareFocusPolicy.maximumSelectionCount

    let id: String
    let titleKey: String

    func title(language: AppLanguage) -> String {
        localized(titleKey, language: language)
    }
}

extension CompareType {
    func title(language: AppLanguage) -> String {
        switch self {
        case .meOverTime: localized("compare.type.me-over-time.title", language: language)
        case .twoPeople: localized("compare.type.two-people.title", language: language)
        case .twoPlaces: localized("compare.type.two-places.title", language: language)
        case .relationshipOverTime: localized("compare.type.relationship-over-time.title", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .meOverTime: localized("compare.type.me-over-time.subtitle", language: language)
        case .twoPeople: localized("compare.type.two-people.subtitle", language: language)
        case .twoPlaces: localized("compare.type.two-places.subtitle", language: language)
        case .relationshipOverTime: localized("compare.type.relationship-over-time.subtitle", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .meOverTime: "clock.arrow.2.circlepath"
        case .twoPeople: "person.2"
        case .twoPlaces: "map"
        case .relationshipOverTime: "heart.text.square"
        }
    }

    var focusOptions: [CompareFocus] {
        let overall = CompareFocus(id: "overall", titleKey: "compare.focus.overall")
        switch self {
        case .meOverTime:
            return [
                overall,
                CompareFocus(id: "love_relationships", titleKey: "themes.love-relationships"),
                CompareFocus(id: "career_purpose", titleKey: "themes.career-purpose"),
                CompareFocus(id: "money_growth", titleKey: "themes.money-growth"),
                CompareFocus(id: "family_home", titleKey: "themes.family-home"),
                CompareFocus(id: "self_wellbeing", titleKey: "themes.self-wellbeing"),
                CompareFocus(id: "creativity_expression", titleKey: "themes.creativity-expression"),
                CompareFocus(id: "learning_exploration", titleKey: "themes.learning-exploration"),
                CompareFocus(id: "life_direction", titleKey: "themes.life-direction"),
            ]
        case .twoPeople:
            return [
                overall,
                CompareFocus(id: "communication", titleKey: "compare.focus.communication"),
                CompareFocus(id: "emotional_connection", titleKey: "compare.focus.emotional-connection"),
                CompareFocus(id: "attraction", titleKey: "compare.focus.attraction"),
                CompareFocus(id: "values_priorities", titleKey: "compare.focus.values-priorities"),
                CompareFocus(id: "daily_dynamics", titleKey: "compare.focus.daily-dynamics"),
                CompareFocus(id: "conflict_tension", titleKey: "compare.focus.conflict-tension"),
                CompareFocus(id: "growth", titleKey: "compare.focus.growth"),
                CompareFocus(id: "long_term_dynamics", titleKey: "compare.focus.long-term-dynamics"),
            ]
        case .twoPlaces:
            return [
                overall,
                CompareFocus(id: "career_visibility", titleKey: "compare.focus.career-visibility"),
                CompareFocus(id: "relationships", titleKey: "compare.focus.relationships"),
                CompareFocus(id: "home_belonging", titleKey: "compare.focus.home-belonging"),
                CompareFocus(id: "social_life", titleKey: "compare.focus.social-life"),
                CompareFocus(id: "creativity", titleKey: "compare.focus.creativity"),
                CompareFocus(id: "stability_pressure", titleKey: "compare.focus.stability-pressure"),
                CompareFocus(id: "growth", titleKey: "compare.focus.growth"),
                CompareFocus(id: "inner_life", titleKey: "compare.focus.inner-life"),
            ]
        case .relationshipOverTime:
            return [
                overall,
                CompareFocus(id: "communication", titleKey: "compare.focus.communication"),
                CompareFocus(id: "emotional_closeness", titleKey: "compare.focus.emotional-closeness"),
                CompareFocus(id: "attraction", titleKey: "compare.focus.attraction"),
                CompareFocus(id: "stability", titleKey: "compare.focus.stability"),
                CompareFocus(id: "conflict_pressure", titleKey: "compare.focus.conflict-pressure"),
                CompareFocus(id: "shared_direction", titleKey: "compare.focus.shared-direction"),
                CompareFocus(id: "growth_change", titleKey: "compare.focus.growth-change"),
                CompareFocus(id: "distance_connection", titleKey: "compare.focus.distance-connection"),
            ]
        }
    }
}

struct CompareRequest: Codable, Equatable {
    let type: CompareType
    let subjectA: CompareSubject
    let subjectB: CompareSubject?
    let dateA: Date?
    let dateB: Date?
    let placeA: ComparePlace?
    let placeB: ComparePlace?
    let relationshipContext: CompareRelationshipContext?
    let focus: [CompareFocus]
    let preset: CalculationPreset
    let locale: AppLanguage

    func validated() throws -> CompareRequest {
        let normalizedIDs = CompareFocusPolicy.normalized(focus.map(\.id))
        let allowed = Dictionary(uniqueKeysWithValues: type.focusOptions.map { ($0.id, $0) })
        let normalizedFocus = normalizedIDs.compactMap { allowed[$0] }
        try CompareValidator.validate(
            CompareValidationInput(
                type: type,
                subjectAID: subjectA.id,
                subjectBID: subjectB?.id,
                dateA: dateA,
                dateB: dateB,
                placeAIdentity: placeA?.validationIdentity,
                placeBIdentity: placeB?.validationIdentity,
                focusIDs: normalizedFocus.map(\.id)
            )
        )
        return CompareRequest(
            type: type,
            subjectA: subjectA,
            subjectB: subjectB,
            dateA: dateA,
            dateB: dateB,
            placeA: placeA,
            placeB: placeB,
            relationshipContext: relationshipContext,
            focus: normalizedFocus,
            preset: preset == .special ? .modern : preset,
            locale: locale
        )
    }
}

struct CompareCachedChart: Codable, Equatable, Identifiable {
    let id: String
    let labelKey: String
    let technique: String
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
}

struct CompareAIFactSets: Codable, Equatable, Sendable {
    let baseline: [CompareFact]
    let snapshotA: [CompareFact]
    let snapshotB: [CompareFact]
    let relationship: [CompareFact]

    var all: [CompareFact] { baseline + snapshotA + snapshotB + relationship }
}

struct CompareAILabels: Codable, Equatable, Sendable {
    let dateA: String?
    let dateB: String?
    let placeA: String?
    let placeB: String?
}

struct CompareAIRequest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let compareType: CompareType
    let focus: [String]
    let relationshipContext: String?
    let labels: CompareAILabels
    let facts: CompareAIFactSets
    let diff: CompareDiff

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case compareType = "compare_type"
        case focus
        case relationshipContext = "relationship_context"
        case labels
        case facts
        case diff
    }

    var validFactIDs: Set<String> {
        Set(facts.all.map(\.id))
    }
}

struct CompareCalculationBundle: Codable, Equatable {
    let compareType: CompareType
    let baselineFacts: [CompareFact]
    let snapshotAFacts: [CompareFact]
    let snapshotBFacts: [CompareFact]
    let relationshipFacts: [CompareFact]
    let diff: CompareDiff
    let cachedCharts: [CompareCachedChart]

    var aiFactSets: CompareAIFactSets {
        CompareAIFactSets(
            baseline: baselineFacts,
            snapshotA: snapshotAFacts,
            snapshotB: snapshotBFacts,
            relationship: relationshipFacts
        )
    }

    var validFactIDs: Set<String> {
        Set((baselineFacts + snapshotAFacts + snapshotBFacts + relationshipFacts).map(\.id))
    }
}

enum CompareAIPayloadReducer {
    static func make(request: CompareRequest, bundle: CompareCalculationBundle) -> CompareAIRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let reducedDiff = CompareDiff(
            added: bundle.diff.added,
            removed: bundle.diff.removed,
            strengthened: bundle.diff.strengthened,
            weakened: bundle.diff.weakened,
            exactOrPeaked: bundle.diff.exactOrPeaked,
            structuralChanges: bundle.diff.structuralChanges,
            stable: []
        )
        return CompareAIRequest(
            schemaVersion: 1,
            compareType: request.type,
            focus: request.focus.map(\.id),
            relationshipContext: request.relationshipContext?.rawValue,
            labels: CompareAILabels(
                dateA: request.dateA.map(formatter.string(from:)),
                dateB: request.dateB.map(formatter.string(from:)),
                placeA: request.type == .twoPlaces ? request.placeA?.displayName : nil,
                placeB: request.type == .twoPlaces ? request.placeB?.displayName : nil
            ),
            facts: bundle.aiFactSets,
            diff: reducedDiff
        )
    }
}

extension CompareAIRequest {
    static func make(request: CompareRequest, bundle: CompareCalculationBundle) -> CompareAIRequest {
        CompareAIPayloadReducer.make(request: request, bundle: bundle)
    }
}
