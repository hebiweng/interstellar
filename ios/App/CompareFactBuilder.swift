import AstroCore
import Foundation

/// Converts renderer-ready deterministic chart artifacts into stable facts for
/// Compare. Identity never includes time, location, orb, sign, house or motion;
/// those values live in state so the same fact can be compared across snapshots.
enum CompareFactBuilder {
    private static let signIDs = [
        "aries", "taurus", "gemini", "cancer", "leo", "virgo",
        "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
    ]

    static func chartFacts(
        technique: String,
        result: ChartDisplayResult,
        referenceChart: String? = nil,
        identityScope: String? = nil,
        includeAngles: Bool = false,
        includeAngleAspects: Bool = false,
        includeHouseEmphasis: Bool = false
    ) -> [CompareFact] {
        let scopedTechnique = identityScope.map { "\(technique).\($0)" } ?? technique
        return snapshotFacts(
            technique: scopedTechnique,
            snapshot: result.snapshot,
            comparisonAspects: result.comparisonAspects,
            hasExternalReference: result.reference != nil,
            referenceChart: referenceChart,
            includeAngles: includeAngles,
            includeAngleAspects: includeAngleAspects,
            includeHouseEmphasis: includeHouseEmphasis
        )
    }

    static func relationshipFacts(
        artifact: RelationshipChartArtifact,
        techniqueOverride: String? = nil
    ) -> [CompareFact] {
        let technique = techniqueOverride ?? "relationship.\(artifact.kind.rawValue)"
        var facts = snapshotFacts(
            technique: technique,
            snapshot: artifact.snapshot,
            comparisonAspects: artifact.comparisonAspects,
            hasExternalReference: artifact.reference != nil,
            referenceChart: artifact.reference == nil ? nil : "relationship_reference",
            includeAngles: artifact.reference == nil,
            includeAngleAspects: false,
            includeHouseEmphasis: artifact.reference == nil
        )
        if let reference = artifact.reference {
            facts += relationshipOverlayFacts(
                technique: technique,
                moving: artifact.snapshot,
                reference: reference
            )
        }
        return facts.sorted { $0.id < $1.id }
    }

    static func snapshotFacts(
        technique: String,
        snapshot: ChartSnapshot,
        comparisonAspects: [ChartAspect],
        hasExternalReference: Bool,
        referenceChart: String?,
        includeAngles: Bool,
        includeAngleAspects: Bool,
        includeHouseEmphasis: Bool
    ) -> [CompareFact] {
        var facts: [CompareFact] = []
        facts.reserveCapacity(snapshot.points.count * 3 + comparisonAspects.count + 20)

        for point in snapshot.points {
            facts.append(bodyStateFact(technique: technique, point: point, snapshot: snapshot))
        }

        for aspect in comparisonAspects {
            facts.append(aspectFact(
                technique: technique,
                aspect: aspect,
                externalReference: hasExternalReference,
                referenceChart: referenceChart
            ))
        }

        if includeAngles {
            facts.append(angleFact(
                technique: technique,
                angle: .ascendant,
                longitude: snapshot.angles.ascendantDegrees
            ))
            facts.append(angleFact(
                technique: technique,
                angle: .midheaven,
                longitude: snapshot.angles.midheavenDegrees
            ))
            facts += snapshot.houses.map { houseCuspFact(technique: technique, house: $0) }
        }

        if includeAngleAspects {
            facts += ChartAngleAspectCalculator.aspects(in: snapshot).map {
                angleAspectFact(technique: technique, aspect: $0)
            }
        }

        if includeHouseEmphasis {
            facts += houseEmphasisFacts(technique: technique, snapshot: snapshot)
        }

        return facts.sorted { $0.id < $1.id }
    }


    private static func relationshipOverlayFacts(
        technique: String,
        moving: ChartSnapshot,
        reference: ChartSnapshot
    ) -> [CompareFact] {
        var facts: [CompareFact] = []
        for point in moving.points {
            let receivingHouse = reference.house(containing: point.longitudeDegrees)
            if (1 ... 12).contains(receivingHouse) {
                facts.append(
                    CompareFact(
                        identity: DeterministicFactIdentity(
                            technique: technique,
                            factType: "house_overlay",
                            sourceObject: point.body.rawValue,
                            targetObject: "reference_chart",
                            relation: "house_overlay",
                            referenceChart: "relationship_reference"
                        ),
                        state: CompareFactState(house: receivingHouse),
                        metadata: [
                            "category": "house_overlay",
                            "body": point.body.rawValue,
                        ]
                    )
                )
            }

            let angleMatches = ChartAngleAspectCalculator.matches(
                bodyID: point.body.rawValue,
                bodyLongitude: point.longitudeDegrees,
                ascendantLongitude: reference.angles.ascendantDegrees,
                midheavenLongitude: reference.angles.midheavenDegrees,
                orbDegrees: 3
            )
            for match in angleMatches {
                facts.append(
                    CompareFact(
                        identity: DeterministicFactIdentity(
                            technique: technique,
                            factType: "angle_aspect",
                            sourceObject: match.bodyID,
                            targetObject: match.angle.rawValue,
                            relation: match.kind.rawValue,
                            referenceChart: "relationship_reference"
                        ),
                        state: CompareFactState(
                            orb: match.orbDegrees,
                            strength: match.strength
                        ),
                        metadata: [
                            "category": "angularity",
                            "angle": match.angle.rawValue,
                            "aspect": match.kind.rawValue,
                        ]
                    )
                )
            }
        }
        return facts
    }

    private static func bodyStateFact(
        technique: String,
        point: ChartPoint,
        snapshot: ChartSnapshot
    ) -> CompareFact {
        let house = snapshot.house(containing: point.longitudeDegrees)
        return CompareFact(
            identity: DeterministicFactIdentity(
                technique: technique,
                factType: "body_state",
                sourceObject: point.body.rawValue,
                referenceChart: "snapshot"
            ),
            state: CompareFactState(
                sign: signIDs[point.signIndex],
                house: house == 0 ? nil : house,
                motion: point.retrograde ? "retrograde" : "direct",
                sampledAt: snapshot.utcDate
            ),
            metadata: [
                "category": "placement",
                "body": point.body.rawValue,
            ]
        )
    }

    private static func aspectFact(
        technique: String,
        aspect: ChartAspect,
        externalReference: Bool,
        referenceChart: String?
    ) -> CompareFact {
        let source: String
        let target: String
        if externalReference {
            source = aspect.firstID
            target = aspect.secondID
        } else if aspect.firstID <= aspect.secondID {
            source = aspect.firstID
            target = aspect.secondID
        } else {
            source = aspect.secondID
            target = aspect.firstID
        }

        return CompareFact(
            identity: DeterministicFactIdentity(
                technique: technique,
                factType: "aspect",
                sourceObject: source,
                targetObject: target,
                relation: aspect.kind.rawValue,
                referenceChart: externalReference ? (referenceChart ?? "reference") : "same_chart"
            ),
            state: CompareFactState(
                orb: aspect.orbDegrees,
                phase: aspect.phase.rawValue,
                strength: aspect.strength
            ),
            metadata: [
                "category": "aspect",
                "aspect": aspect.kind.rawValue,
            ]
        )
    }

    private static func angleFact(
        technique: String,
        angle: ChartAngle,
        longitude: Double
    ) -> CompareFact {
        CompareFact(
            identity: DeterministicFactIdentity(
                technique: technique,
                factType: "angle",
                sourceObject: angle.rawValue,
                referenceChart: "local_chart"
            ),
            state: CompareFactState(numericValue: normalized(longitude)),
            metadata: ["category": "angle"]
        )
    }

    private static func houseCuspFact(technique: String, house: ChartHouse) -> CompareFact {
        CompareFact(
            identity: DeterministicFactIdentity(
                technique: technique,
                factType: "house_cusp",
                sourceObject: "house_\(house.number)",
                referenceChart: "local_chart"
            ),
            state: CompareFactState(numericValue: normalized(house.cuspDegrees)),
            metadata: ["category": "house"]
        )
    }

    private static func angleAspectFact(
        technique: String,
        aspect: ChartAngleAspect
    ) -> CompareFact {
        CompareFact(
            identity: DeterministicFactIdentity(
                technique: technique,
                factType: "angle_aspect",
                sourceObject: aspect.bodyID,
                targetObject: aspect.angle.rawValue,
                relation: aspect.kind.rawValue,
                referenceChart: "local_angles"
            ),
            state: CompareFactState(
                orb: aspect.orbDegrees,
                strength: aspect.strength
            ),
            metadata: [
                "category": "angularity",
                "angle": aspect.angle.rawValue,
                "aspect": aspect.kind.rawValue,
            ]
        )
    }

    private static func houseEmphasisFacts(
        technique: String,
        snapshot: ChartSnapshot
    ) -> [CompareFact] {
        var counts = Dictionary(uniqueKeysWithValues: (1 ... 12).map { ($0, 0) })
        for point in snapshot.points {
            let house = snapshot.house(containing: point.longitudeDegrees)
            if (1 ... 12).contains(house) { counts[house, default: 0] += 1 }
        }
        return (1 ... 12).map { house in
            CompareFact(
                identity: DeterministicFactIdentity(
                    technique: technique,
                    factType: "house_emphasis",
                    sourceObject: "house_\(house)",
                    referenceChart: "local_chart"
                ),
                state: CompareFactState(numericValue: Double(counts[house, default: 0])),
                metadata: ["category": "house_emphasis"]
            )
        }
    }

    private static func normalized(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}
