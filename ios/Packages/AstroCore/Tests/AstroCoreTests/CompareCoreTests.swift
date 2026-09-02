import AstroCore
import Foundation
import Testing

@Suite("Compare deterministic facts")
struct CompareCoreTests {
    @Test("Fact identity excludes sampled time and mutable state")
    func stableIdentity() {
        let identity = DeterministicFactIdentity(
            technique: "transit",
            factType: "aspect",
            sourceObject: "saturn",
            targetObject: "venus",
            relation: "square",
            referenceChart: "natal"
        )
        let first = CompareFact(identity: identity, state: CompareFactState(orb: 2.4, phase: "applying", sampledAt: Date(timeIntervalSince1970: 1)))
        let second = CompareFact(identity: identity, state: CompareFactState(orb: 0.8, phase: "applying", sampledAt: Date(timeIntervalSince1970: 999)))

        #expect(first.id == second.id)
        #expect(first.id == "transit|aspect|saturn|venus|square|natal")
    }

    @Test("Encoded AI facts expose their stable evidence ID")
    func encodedFactContainsStableID() throws {
        let value = fact(orb: 1.0)
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
        #expect(object["id"] as? String == value.id)
        let decoded = try JSONDecoder().decode(CompareFact.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
    }

    @Test("Same aspect with smaller orb is strengthened")
    func smallerOrbStrengthens() {
        let a = fact(orb: 2.0)
        let b = fact(orb: 1.0)
        let diff = CompareDiffEngine.diff(from: [a], to: [b])
        #expect(diff.strengthened.map(\.id) == [a.id])
        #expect(diff.added.isEmpty)
        #expect(diff.removed.isEmpty)
    }

    @Test("Same aspect with larger orb is weakened")
    func largerOrbWeakens() {
        let a = fact(orb: 0.8)
        let b = fact(orb: 1.7)
        let diff = CompareDiffEngine.diff(from: [a], to: [b])
        #expect(diff.weakened.map(\.id) == [a.id])
    }

    @Test("Fact only in B is added")
    func added() {
        let b = fact(orb: 1.0)
        let diff = CompareDiffEngine.diff(from: [], to: [b])
        #expect(diff.added.map(\.id) == [b.id])
    }

    @Test("Fact only in A is removed")
    func removed() {
        let a = fact(orb: 1.0)
        let diff = CompareDiffEngine.diff(from: [a], to: [])
        #expect(diff.removed.map(\.id) == [a.id])
    }

    @Test("Crossing the exact threshold is exact or peaked")
    func exactOrPeaked() {
        let a = fact(orb: 0.9)
        let b = fact(orb: 0.1)
        let diff = CompareDiffEngine.diff(from: [a], to: [b])
        #expect(diff.exactOrPeaked.map(\.id) == [a.id])
        #expect(diff.strengthened.isEmpty)
    }

    @Test("House, sign and motion changes are structural")
    func structuralStateChanges() {
        let identity = DeterministicFactIdentity(
            technique: "secondary_progression",
            factType: "body_state",
            sourceObject: "moon",
            targetObject: nil,
            relation: nil,
            referenceChart: "natal"
        )
        let a = CompareFact(identity: identity, state: CompareFactState(sign: "aries", house: 6, motion: "direct"))
        let b = CompareFact(identity: identity, state: CompareFactState(sign: "taurus", house: 7, motion: "retrograde"))
        let diff = CompareDiffEngine.diff(from: [a], to: [b])

        let change = diff.structuralChanges.first!
        #expect(change.id == a.id)
        #expect(change.structuralFields == ["house", "motion", "sign"])
    }

    @Test("Only sampling time changing remains stable")
    func samplingTimeDoesNotCreateChange() {
        let identity = DeterministicFactIdentity(
            technique: "transit",
            factType: "aspect",
            sourceObject: "saturn",
            targetObject: "venus",
            relation: "square",
            referenceChart: "natal"
        )
        let a = CompareFact(identity: identity, state: CompareFactState(orb: 1.0, phase: "applying", sampledAt: Date(timeIntervalSince1970: 1)))
        let b = CompareFact(identity: identity, state: CompareFactState(orb: 1.0, phase: "applying", sampledAt: Date(timeIntervalSince1970: 999)))
        let diff = CompareDiffEngine.diff(from: [a], to: [b])
        #expect(diff.stable.map(\.id) == [a.id])
    }

    @Test("Unchanged fact appears once in stable diff")
    func stableFactAppearsOnce() {
        let a = fact(orb: 1.0)
        let b = fact(orb: 1.0)
        let diff = CompareDiffEngine.diff(from: [a], to: [b])
        #expect(diff.stable.count == 1)
        #expect(diff.stable.first?.id == a.id)
    }

    @Test("Duplicate identities resolve deterministically to the strongest fact")
    func duplicateIdentityDedupesByStrength() {
        let weak = fact(orb: 2.0, strength: 0.3)
        let strong = fact(orb: 1.0, strength: 0.8)
        let diff = CompareDiffEngine.diff(from: [], to: [weak, strong])
        #expect(diff.added.count == 1)
        #expect(diff.added.first?.after?.state.orb == 1.0)
    }

    @Test("Primary changes cap noisy diffs and keep deterministic professional priorities")
    func primaryChangesAreFilteredAndRanked() {
        let fixtures: [(CompareFactChangeKind, String, String, Double?, Double?)] = [
            (.weakened, "weak-body", "body_state", nil, 0.2),
            (.added, "new-body", "body_state", nil, 0.4),
            (.strengthened, "tightening", "aspect", 0.8, 0.7),
            (.removed, "lost-aspect", "aspect", 1.1, 0.6),
            (.added, "new-angle", "angle_aspect", 1.0, 0.8),
            (.structuralChange, "house-shift", "body_state", nil, nil),
            (.exactOrPeaked, "exact-aspect", "aspect", 0.1, 0.9),
            (.weakened, "wide-aspect", "aspect", 2.4, 0.3),
            (.added, "house-emphasis", "house_emphasis", nil, nil),
            (.strengthened, "secondary-tightening", "aspect", 1.7, 0.5),
        ]
        let changes = fixtures.map { kind, source, factType, orb, strength in
            let value = selectionFact(source: source, factType: factType, orb: orb, strength: strength)
            return CompareFactChange(
                kind: kind,
                before: kind == .added ? nil : value,
                after: kind == .removed ? nil : value,
                structuralFields: kind == .structuralChange ? ["house"] : []
            )
        }

        let selected = ComparePrimaryResultSelector.changes(from: changes, limit: 8)

        #expect(selected.map(\.id) == [
            selectionFactID(source: "exact-aspect", factType: "aspect"),
            selectionFactID(source: "house-shift", factType: "body_state"),
            selectionFactID(source: "new-angle", factType: "angle_aspect"),
            selectionFactID(source: "lost-aspect", factType: "aspect"),
            selectionFactID(source: "new-body", factType: "body_state"),
            selectionFactID(source: "tightening", factType: "aspect"),
            selectionFactID(source: "secondary-tightening", factType: "aspect"),
            selectionFactID(source: "wide-aspect", factType: "aspect"),
        ])
    }

    @Test("Two People primary comparisons come from relationship facts")
    func primaryComparisonsUseRelationshipEvidence() {
        let facts = [
            selectionFact(source: "moon", factType: "house_overlay", strength: 0.3),
            selectionFact(source: "venus", factType: "angle_aspect", orb: 2.0, strength: 0.8),
            selectionFact(source: "mars", factType: "angle_aspect", orb: 0.4, strength: 0.9),
            selectionFact(source: "sun", factType: "body_state", strength: 1.0),
        ]

        let selected = ComparePrimaryResultSelector.comparisons(from: facts, limit: 3)

        #expect(selected.map(\.id) == [
            selectionFactID(source: "mars", factType: "angle_aspect"),
            selectionFactID(source: "venus", factType: "angle_aspect"),
            selectionFactID(source: "moon", factType: "house_overlay"),
        ])
    }

    private func fact(orb: Double, strength: Double = 0.5) -> CompareFact {
        CompareFact(
            identity: DeterministicFactIdentity(
                technique: "transit",
                factType: "aspect",
                sourceObject: "saturn",
                targetObject: "venus",
                relation: "square",
                referenceChart: "natal"
            ),
            state: CompareFactState(orb: orb, phase: "applying", strength: strength)
        )
    }

    private func selectionFact(
        source: String,
        factType: String,
        orb: Double? = nil,
        strength: Double? = nil
    ) -> CompareFact {
        CompareFact(
            identity: DeterministicFactIdentity(
                technique: "relationship.synastry-a",
                factType: factType,
                sourceObject: source,
                targetObject: factType == "body_state" ? nil : "reference",
                relation: factType.contains("aspect") ? "conjunction" : nil,
                referenceChart: "relationship_reference"
            ),
            state: CompareFactState(orb: orb, strength: strength)
        )
    }

    private func selectionFactID(source: String, factType: String) -> String {
        selectionFact(source: source, factType: factType).id
    }
}

@Suite("Compare validation and evidence")
struct CompareValidationTests {
    @Test("Me Over Time rejects equal dates")
    func rejectsEqualDates() {
        let date = Date(timeIntervalSince1970: 100)
        let request = CompareValidationInput(
            type: .meOverTime,
            subjectAID: "me",
            dateA: date,
            dateB: date,
            focusIDs: ["overall"]
        )
        #expect(throws: CompareValidationError.sameDate) {
            try CompareValidator.validate(request)
        }
    }

    @Test("Two People rejects the same person")
    func rejectsSamePerson() {
        let request = CompareValidationInput(
            type: .twoPeople,
            subjectAID: "me",
            subjectBID: "me",
            focusIDs: ["overall"]
        )
        #expect(throws: CompareValidationError.samePerson) {
            try CompareValidator.validate(request)
        }
    }

    @Test("Two Places rejects the same place")
    func rejectsSamePlace() {
        let request = CompareValidationInput(
            type: .twoPlaces,
            subjectAID: "me",
            placeAIdentity: "paris|48.8566|2.3522",
            placeBIdentity: "paris|48.8566|2.3522",
            focusIDs: ["overall"]
        )
        #expect(throws: CompareValidationError.samePlace) {
            try CompareValidator.validate(request)
        }
    }

    @Test("More than three focuses is rejected")
    func rejectsTooManyFocuses() {
        let request = CompareValidationInput(
            type: .twoPeople,
            subjectAID: "me",
            subjectBID: "other",
            focusIDs: ["a", "b", "c", "d"]
        )
        #expect(throws: CompareValidationError.tooManyFocuses) {
            try CompareValidator.validate(request)
        }
    }

    @Test("Focus normalization restores Overall and makes it exclusive")
    func focusNormalization() {
        #expect(CompareFocusPolicy.normalized([]) == ["overall"])
        #expect(CompareFocusPolicy.normalized(["career", "overall", "growth"]) == ["overall"])
        #expect(CompareFocusPolicy.normalized(["career", "growth"]) == ["career", "growth"])
    }

    @Test("Evidence validator removes unknown IDs but keeps valid evidence")
    func filtersUnknownEvidence() throws {
        let response = CompareNarrativeResponse(
            version: "1",
            compareType: .meOverTime,
            summary: CompareNarrativeSection(title: "Shift", text: "Text", evidence: ["known", "unknown"]),
            sections: [
                CompareNarrativeSection(type: "key_change", focus: nil, title: "Change", text: "Text", evidence: ["known"]),
                CompareNarrativeSection(type: "short_term", title: "Short term", text: "Text", evidence: ["known"]),
                CompareNarrativeSection(type: "longer_term", title: "Longer term", text: "Text", evidence: ["known"]),
                CompareNarrativeSection(type: "stable", title: "Stable", text: "Text", evidence: ["known"]),
            ]
        )
        let validated = try CompareNarrativeValidator.validate(
            response,
            expectedType: .meOverTime,
            validFactIDs: ["known"]
        )
        #expect(validated.summary.evidence == ["known"])
    }

    @Test("All-invalid evidence invalidates the AI response")
    func rejectsAllInvalidEvidence() {
        let response = CompareNarrativeResponse(
            version: "1",
            compareType: .twoPeople,
            summary: CompareNarrativeSection(title: "Summary", text: "Text", evidence: ["missing"]),
            sections: []
        )
        #expect(throws: CompareNarrativeValidationError.missingValidEvidence) {
            try CompareNarrativeValidator.validate(
                response,
                expectedType: .twoPeople,
                validFactIDs: ["known"]
            )
        }
    }

    @Test("Missing required narrative sections invalidates the AI response")
    func rejectsMissingRequiredSections() {
        let response = CompareNarrativeResponse(
            version: "1",
            compareType: .meOverTime,
            summary: CompareNarrativeSection(title: "Summary", text: "Text", evidence: ["known"]),
            sections: [
                CompareNarrativeSection(type: "key_change", title: "Change", text: "Text", evidence: ["known"]),
            ]
        )
        #expect(throws: CompareNarrativeValidationError.missingRequiredSection) {
            try CompareNarrativeValidator.validate(
                response,
                expectedType: .meOverTime,
                validFactIDs: ["known"]
            )
        }
    }

    @Test("Wrong compare type invalidates the AI response")
    func rejectsWrongType() {
        let response = CompareNarrativeResponse(
            version: "1",
            compareType: .twoPlaces,
            summary: CompareNarrativeSection(title: "Summary", text: "Text", evidence: ["known"]),
            sections: []
        )
        #expect(throws: CompareNarrativeValidationError.compareTypeMismatch) {
            try CompareNarrativeValidator.validate(
                response,
                expectedType: .twoPeople,
                validFactIDs: ["known"]
            )
        }
    }
}

@Suite("Relocation angle aspects")
struct RelocationAngleAspectTests {
    @Test("Angle aspect matcher derives deterministic major aspects to ASC and MC")
    func matchesAngles() {
        let matches = ChartAngleAspectCalculator.matches(
            bodyID: "venus",
            bodyLongitude: 101,
            ascendantLongitude: 10,
            midheavenLongitude: 190,
            orbDegrees: 2
        )
        #expect(matches.count == 2)
        #expect(matches.map(\.angle) == [.ascendant, .midheaven])
        #expect(matches.allSatisfy { $0.kind == .square })
        #expect(matches.allSatisfy { abs($0.orbDegrees - 1) < 0.000_001 })
    }

    @Test("Angle aspect IDs are stable and do not contain location or sample time")
    func stableIDs() {
        let match = ChartAngleAspectCalculator.matches(
            bodyID: "mars",
            bodyLongitude: 1,
            ascendantLongitude: 0,
            midheavenLongitude: 90,
            orbDegrees: 2
        ).first
        #expect(match?.id == "mars-conjunction-ascendant")
    }
}
