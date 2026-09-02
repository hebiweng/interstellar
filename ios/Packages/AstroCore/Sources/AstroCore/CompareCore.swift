import Foundation

/// Stable identity for one deterministic astrology fact across snapshots.
/// Mutable state such as orb, phase, sign, house, motion and sample time is
/// deliberately excluded so the same underlying fact can be diffed over time.
public struct DeterministicFactIdentity: Codable, Equatable, Hashable, Sendable {
    public let technique: String
    public let factType: String
    public let sourceObject: String
    public let targetObject: String?
    public let relation: String?
    public let referenceChart: String?

    public init(
        technique: String,
        factType: String,
        sourceObject: String,
        targetObject: String? = nil,
        relation: String? = nil,
        referenceChart: String? = nil
    ) {
        self.technique = technique
        self.factType = factType
        self.sourceObject = sourceObject
        self.targetObject = targetObject
        self.relation = relation
        self.referenceChart = referenceChart
    }

    public var key: String {
        [technique, factType, sourceObject, targetObject, relation, referenceChart]
            .map(Self.canonicalComponent)
            .joined(separator: "|")
    }

    private static func canonicalComponent(_ value: String?) -> String {
        guard let value else { return "_" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "_" }
        let whitespaceCollapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: "_")
        return whitespaceCollapsed.replacingOccurrences(of: "|", with: "%7c")
    }
}

/// Mutable state attached to a stable fact identity.
public struct CompareFactState: Codable, Equatable, Sendable {
    public let orb: Double?
    public let phase: String?
    public let strength: Double?
    public let sign: String?
    public let house: Int?
    public let motion: String?
    public let numericValue: Double?
    public let textValue: String?
    public let sampledAt: Date?

    public init(
        orb: Double? = nil,
        phase: String? = nil,
        strength: Double? = nil,
        sign: String? = nil,
        house: Int? = nil,
        motion: String? = nil,
        numericValue: Double? = nil,
        textValue: String? = nil,
        sampledAt: Date? = nil
    ) {
        self.orb = orb
        self.phase = phase
        self.strength = strength
        self.sign = sign
        self.house = house
        self.motion = motion
        self.numericValue = numericValue
        self.textValue = textValue
        self.sampledAt = sampledAt
    }
}

public struct CompareFact: Codable, Equatable, Identifiable, Sendable {
    public let identity: DeterministicFactIdentity
    public let state: CompareFactState
    public let metadata: [String: String]

    public var id: String { identity.key }

    public init(
        identity: DeterministicFactIdentity,
        state: CompareFactState = CompareFactState(),
        metadata: [String: String] = [:]
    ) {
        self.identity = identity
        self.state = state
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case identity, state, metadata, id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(DeterministicFactIdentity.self, forKey: .identity)
        state = try container.decode(CompareFactState.self, forKey: .state)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity, forKey: .identity)
        try container.encode(state, forKey: .state)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(id, forKey: .id)
    }
}

public enum CompareFactChangeKind: String, Codable, Equatable, Sendable {
    case added
    case removed
    case strengthened
    case weakened
    case exactOrPeaked = "exact_or_peaked"
    case structuralChange = "structural_change"
    case stable
}

public struct CompareFactChange: Codable, Equatable, Identifiable, Sendable {
    public let kind: CompareFactChangeKind
    public let before: CompareFact?
    public let after: CompareFact?
    public let structuralFields: [String]

    public var id: String { after?.id ?? before?.id ?? "invalid" }

    public init(
        kind: CompareFactChangeKind,
        before: CompareFact?,
        after: CompareFact?,
        structuralFields: [String] = []
    ) {
        self.kind = kind
        self.before = before
        self.after = after
        self.structuralFields = structuralFields.sorted()
    }
}

public struct CompareDiff: Codable, Equatable, Sendable {
    public let added: [CompareFactChange]
    public let removed: [CompareFactChange]
    public let strengthened: [CompareFactChange]
    public let weakened: [CompareFactChange]
    public let exactOrPeaked: [CompareFactChange]
    public let structuralChanges: [CompareFactChange]
    public let stable: [CompareFactChange]

    public init(
        added: [CompareFactChange] = [],
        removed: [CompareFactChange] = [],
        strengthened: [CompareFactChange] = [],
        weakened: [CompareFactChange] = [],
        exactOrPeaked: [CompareFactChange] = [],
        structuralChanges: [CompareFactChange] = [],
        stable: [CompareFactChange] = []
    ) {
        self.added = added
        self.removed = removed
        self.strengthened = strengthened
        self.weakened = weakened
        self.exactOrPeaked = exactOrPeaked
        self.structuralChanges = structuralChanges
        self.stable = stable
    }

    public var changedCount: Int {
        added.count + removed.count + strengthened.count + weakened.count
            + exactOrPeaked.count + structuralChanges.count
    }

    public var allChanges: [CompareFactChange] {
        added + removed + strengthened + weakened + exactOrPeaked + structuralChanges + stable
    }
}

/// Selects a small, deterministic set of locally calculated facts for the
/// consumer result page. This ranks existing evidence only; it never creates
/// or recalculates astrology facts.
public enum ComparePrimaryResultSelector {
    public static func changes(
        from changes: [CompareFactChange],
        limit: Int = 8
    ) -> [CompareFactChange] {
        guard limit > 0 else { return [] }
        return changes
            .filter { change in
                guard change.kind != .stable, let value = fact(for: change) else { return false }
                if change.kind == .exactOrPeaked || change.kind == .structuralChange { return true }
                return factTypePriority(value.identity.factType) < 5
            }
            .sorted(by: changePrecedes)
            .prefix(limit)
            .map { $0 }
    }

    public static func comparisons(
        from facts: [CompareFact],
        limit: Int = 8
    ) -> [CompareFact] {
        guard limit > 0 else { return [] }
        return facts
            .sorted(by: factPrecedes)
            .prefix(limit)
            .map { $0 }
    }

    private static func changePrecedes(_ lhs: CompareFactChange, _ rhs: CompareFactChange) -> Bool {
        let lhsStage = changeStage(lhs.kind)
        let rhsStage = changeStage(rhs.kind)
        if lhsStage != rhsStage { return lhsStage < rhsStage }
        guard let lhsFact = fact(for: lhs), let rhsFact = fact(for: rhs) else {
            return lhs.id < rhs.id
        }
        if factPrecedes(lhsFact, rhsFact) { return true }
        if factPrecedes(rhsFact, lhsFact) { return false }
        return lhs.id < rhs.id
    }

    private static func changeStage(_ kind: CompareFactChangeKind) -> Int {
        switch kind {
        case .exactOrPeaked: 0
        case .structuralChange: 1
        case .added, .removed: 2
        case .strengthened, .weakened: 3
        case .stable: 4
        }
    }

    private static func fact(for change: CompareFactChange) -> CompareFact? {
        change.after ?? change.before
    }

    private static func factPrecedes(_ lhs: CompareFact, _ rhs: CompareFact) -> Bool {
        let lhsType = factTypePriority(lhs.identity.factType)
        let rhsType = factTypePriority(rhs.identity.factType)
        if lhsType != rhsType { return lhsType < rhsType }

        let lhsStrength = lhs.state.strength ?? -.infinity
        let rhsStrength = rhs.state.strength ?? -.infinity
        if lhsStrength != rhsStrength { return lhsStrength > rhsStrength }

        let lhsOrb = lhs.state.orb ?? .infinity
        let rhsOrb = rhs.state.orb ?? .infinity
        if lhsOrb != rhsOrb { return lhsOrb < rhsOrb }
        return lhs.id < rhs.id
    }

    private static func factTypePriority(_ value: String) -> Int {
        switch value.lowercased() {
        case "angle_aspect": 0
        case "aspect": 1
        case "house_overlay": 2
        case "body_state": 3
        case "angle": 4
        case "house_emphasis", "house_cusp": 5
        default: 6
        }
    }
}

public enum CompareDiffEngine {
    public static func diff(
        from beforeFacts: [CompareFact],
        to afterFacts: [CompareFact],
        exactOrbThreshold: Double = 0.25,
        tolerance: Double = 0.000_001
    ) -> CompareDiff {
        let before = deduplicated(beforeFacts)
        let after = deduplicated(afterFacts)
        let ids = Set(before.keys).union(after.keys).sorted()

        var added: [CompareFactChange] = []
        var removed: [CompareFactChange] = []
        var strengthened: [CompareFactChange] = []
        var weakened: [CompareFactChange] = []
        var exactOrPeaked: [CompareFactChange] = []
        var structural: [CompareFactChange] = []
        var stable: [CompareFactChange] = []

        for id in ids {
            switch (before[id], after[id]) {
            case (nil, let fact?):
                added.append(CompareFactChange(kind: .added, before: nil, after: fact))
            case (let fact?, nil):
                removed.append(CompareFactChange(kind: .removed, before: fact, after: nil))
            case (let lhs?, let rhs?):
                let fields = structuralFields(before: lhs.state, after: rhs.state, tolerance: tolerance)
                if !fields.isEmpty {
                    structural.append(CompareFactChange(
                        kind: .structuralChange,
                        before: lhs,
                        after: rhs,
                        structuralFields: fields
                    ))
                    continue
                }

                if crossedExactness(before: lhs.state, after: rhs.state, threshold: exactOrbThreshold, tolerance: tolerance) {
                    exactOrPeaked.append(CompareFactChange(kind: .exactOrPeaked, before: lhs, after: rhs))
                    continue
                }

                if let direction = intensityDirection(before: lhs.state, after: rhs.state, tolerance: tolerance) {
                    switch direction {
                    case .strengthened:
                        strengthened.append(CompareFactChange(kind: .strengthened, before: lhs, after: rhs))
                    case .weakened:
                        weakened.append(CompareFactChange(kind: .weakened, before: lhs, after: rhs))
                    }
                    continue
                }

                stable.append(CompareFactChange(kind: .stable, before: lhs, after: rhs))
            case (nil, nil):
                break
            }
        }

        return CompareDiff(
            added: added,
            removed: removed,
            strengthened: strengthened,
            weakened: weakened,
            exactOrPeaked: exactOrPeaked,
            structuralChanges: structural,
            stable: stable
        )
    }

    private enum IntensityDirection {
        case strengthened
        case weakened
    }

    private static func intensityDirection(
        before: CompareFactState,
        after: CompareFactState,
        tolerance: Double
    ) -> IntensityDirection? {
        if let lhs = before.orb, let rhs = after.orb, abs(lhs - rhs) > tolerance {
            return rhs < lhs ? .strengthened : .weakened
        }
        if let lhs = before.strength, let rhs = after.strength, abs(lhs - rhs) > tolerance {
            return rhs > lhs ? .strengthened : .weakened
        }
        return nil
    }

    private static func crossedExactness(
        before: CompareFactState,
        after: CompareFactState,
        threshold: Double,
        tolerance: Double
    ) -> Bool {
        if let lhs = before.orb, let rhs = after.orb,
           lhs > threshold + tolerance,
           rhs <= threshold + tolerance
        {
            return true
        }
        let beforeExact = before.phase?.lowercased() == "exact"
        let afterExact = after.phase?.lowercased() == "exact"
        return !beforeExact && afterExact
    }

    private static func structuralFields(
        before: CompareFactState,
        after: CompareFactState,
        tolerance: Double
    ) -> [String] {
        var fields: [String] = []
        if before.sign != after.sign { fields.append("sign") }
        if before.house != after.house { fields.append("house") }
        if before.motion != after.motion { fields.append("motion") }
        if before.textValue != after.textValue { fields.append("value") }
        switch (before.numericValue, after.numericValue) {
        case (nil, nil): break
        case (let lhs?, let rhs?) where abs(lhs - rhs) <= tolerance: break
        default: fields.append("numeric_value")
        }
        return fields.sorted()
    }

    private static func deduplicated(_ facts: [CompareFact]) -> [String: CompareFact] {
        var result: [String: CompareFact] = [:]
        for fact in facts {
            guard let existing = result[fact.id] else {
                result[fact.id] = fact
                continue
            }
            if preferred(fact, over: existing) {
                result[fact.id] = fact
            }
        }
        return result
    }

    private static func preferred(_ candidate: CompareFact, over current: CompareFact) -> Bool {
        switch (candidate.state.orb, current.state.orb) {
        case (let lhs?, let rhs?) where lhs != rhs:
            return lhs < rhs
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }
        switch (candidate.state.strength, current.state.strength) {
        case (let lhs?, let rhs?) where lhs != rhs:
            return lhs > rhs
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }
        let lhs = candidate.state.sampledAt?.timeIntervalSince1970 ?? -.infinity
        let rhs = current.state.sampledAt?.timeIntervalSince1970 ?? -.infinity
        return lhs > rhs
    }
}

public enum CompareType: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case meOverTime = "me_over_time"
    case twoPeople = "two_people"
    case twoPlaces = "two_places"
    case relationshipOverTime = "relationship_over_time"
}

public struct CompareValidationInput: Equatable, Sendable {
    public let type: CompareType
    public let subjectAID: String
    public let subjectBID: String?
    public let dateA: Date?
    public let dateB: Date?
    public let placeAIdentity: String?
    public let placeBIdentity: String?
    public let focusIDs: [String]

    public init(
        type: CompareType,
        subjectAID: String,
        subjectBID: String? = nil,
        dateA: Date? = nil,
        dateB: Date? = nil,
        placeAIdentity: String? = nil,
        placeBIdentity: String? = nil,
        focusIDs: [String] = ["overall"]
    ) {
        self.type = type
        self.subjectAID = subjectAID
        self.subjectBID = subjectBID
        self.dateA = dateA
        self.dateB = dateB
        self.placeAIdentity = placeAIdentity
        self.placeBIdentity = placeBIdentity
        self.focusIDs = focusIDs
    }
}

public enum CompareValidationError: String, Error, Equatable, Sendable {
    case missingSubject
    case missingSecondSubject
    case missingDates
    case missingPlaces
    case sameDate
    case samePlace
    case samePerson
    case tooManyFocuses
}

public enum CompareFocusPolicy {
    public static let maximumSelectionCount = 3

    public static func normalized(_ focusIDs: [String]) -> [String] {
        let cleaned = focusIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if cleaned.isEmpty { return ["overall"] }
        if cleaned.contains("overall") { return ["overall"] }
        var seen = Set<String>()
        return cleaned.filter { seen.insert($0).inserted }
    }
}

public enum CompareValidator {
    public static func validate(_ request: CompareValidationInput) throws {
        guard !request.subjectAID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompareValidationError.missingSubject
        }
        let focuses = CompareFocusPolicy.normalized(request.focusIDs)
        guard focuses.count <= CompareFocusPolicy.maximumSelectionCount else {
            throw CompareValidationError.tooManyFocuses
        }

        switch request.type {
        case .meOverTime:
            try validateDates(request.dateA, request.dateB)

        case .twoPeople:
            try validateDistinctPeople(request.subjectAID, request.subjectBID)

        case .twoPlaces:
            guard let a = request.placeAIdentity, let b = request.placeBIdentity else {
                throw CompareValidationError.missingPlaces
            }
            if normalizedPlaceIdentity(a) == normalizedPlaceIdentity(b) {
                throw CompareValidationError.samePlace
            }

        case .relationshipOverTime:
            try validateDistinctPeople(request.subjectAID, request.subjectBID)
            try validateDates(request.dateA, request.dateB)
        }
    }

    private static func validateDates(_ a: Date?, _ b: Date?) throws {
        guard let a, let b else { throw CompareValidationError.missingDates }
        if a == b { throw CompareValidationError.sameDate }
    }

    private static func validateDistinctPeople(_ a: String, _ b: String?) throws {
        guard let b, !b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompareValidationError.missingSecondSubject
        }
        if a.caseInsensitiveCompare(b) == .orderedSame {
            throw CompareValidationError.samePerson
        }
    }

    private static func normalizedPlaceIdentity(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public struct CompareNarrativeSection: Codable, Equatable, Sendable {
    public let type: String?
    public let focus: String?
    public let title: String
    public let text: String
    public let evidence: [String]

    public init(
        type: String? = nil,
        focus: String? = nil,
        title: String,
        text: String,
        evidence: [String]
    ) {
        self.type = type
        self.focus = focus
        self.title = title
        self.text = text
        self.evidence = evidence
    }
}

public struct CompareNarrativeResponse: Codable, Equatable, Sendable {
    public let version: String
    public let compareType: CompareType
    public let summary: CompareNarrativeSection
    public let sections: [CompareNarrativeSection]

    public init(
        version: String,
        compareType: CompareType,
        summary: CompareNarrativeSection,
        sections: [CompareNarrativeSection]
    ) {
        self.version = version
        self.compareType = compareType
        self.summary = summary
        self.sections = sections
    }

    enum CodingKeys: String, CodingKey {
        case version
        case compareType = "compare_type"
        case summary
        case sections
    }
}

public enum CompareNarrativeValidationError: String, Error, Equatable, Sendable {
    case unsupportedVersion
    case compareTypeMismatch
    case missingValidEvidence
    case missingRequiredSection
    case emptyTitle
    case emptyText
}

public enum CompareNarrativeValidator {
    public static func validate(
        _ response: CompareNarrativeResponse,
        expectedType: CompareType,
        validFactIDs: Set<String>
    ) throws -> CompareNarrativeResponse {
        guard response.version == "1" else {
            throw CompareNarrativeValidationError.unsupportedVersion
        }
        guard response.compareType == expectedType else {
            throw CompareNarrativeValidationError.compareTypeMismatch
        }

        let summary = try sanitized(response.summary, validFactIDs: validFactIDs)
        let sections = try response.sections.map { try sanitized($0, validFactIDs: validFactIDs) }
        let sectionTypes = Set(sections.compactMap(\.type))
        guard requiredSectionTypes(for: expectedType).isSubset(of: sectionTypes) else {
            throw CompareNarrativeValidationError.missingRequiredSection
        }
        return CompareNarrativeResponse(
            version: response.version,
            compareType: response.compareType,
            summary: summary,
            sections: sections
        )
    }

    public static func requiredSectionTypes(for type: CompareType) -> Set<String> {
        switch type {
        case .meOverTime:
            ["key_change", "short_term", "longer_term", "stable"]
        case .twoPeople:
            ["alignment", "difference", "influence", "strength", "friction"]
        case .twoPlaces:
            ["unchanged", "place_a", "place_b", "trade_off"]
        case .relationshipOverTime:
            ["baseline", "changed", "intensified", "eased", "short_term", "longer_term", "stable"]
        }
    }

    private static func sanitized(
        _ section: CompareNarrativeSection,
        validFactIDs: Set<String>
    ) throws -> CompareNarrativeSection {
        guard !section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompareNarrativeValidationError.emptyTitle
        }
        guard !section.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompareNarrativeValidationError.emptyText
        }
        var seen = Set<String>()
        let evidence = section.evidence.filter { validFactIDs.contains($0) && seen.insert($0).inserted }
        guard !evidence.isEmpty else {
            throw CompareNarrativeValidationError.missingValidEvidence
        }
        return CompareNarrativeSection(
            type: section.type,
            focus: section.focus,
            title: section.title,
            text: section.text,
            evidence: evidence
        )
    }
}
