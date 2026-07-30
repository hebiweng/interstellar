import Foundation
import Testing
@testable import ContentKit

@Suite("Interpretation content engine")
struct InterpretationEngineTests {
    private let entry = CorpusEntry(
        id: "transit.mars.moon.square.applying",
        locale: "zh-Hans",
        layer: .pressure,
        selector: CorpusSelector(
            techniques: [.transit],
            pointIDs: ["mars"],
            referencePointIDs: ["moon"],
            aspectIDs: ["square"],
            phaseIDs: ["applying"]
        ),
        summary: "{{signal.pointName}}正在触发{{signal.referenceName}}，行动与情绪之间的拉扯正在增强。",
        detail: "{{signal.pointName}}与{{signal.referenceName}}形成{{signal.aspectName}}，当前处于{{signal.phaseName}}。先处理已经出现的具体分歧，再决定是否加快节奏。",
        priority: 100,
        deduplicationGroup: "mars-moon-pressure",
        sourceRevision: "test",
        status: "approved"
    )

    private let rule = CompositionRule(
        id: "transit.trigger-themes.v1",
        technique: .transit,
        cardID: "trigger-themes",
        summaryTemplate: "{{primary.1.summary}}",
        detailTemplate: "{{primary.1.detail}}",
        bindings: [
            CompositionBinding(
                name: "primary",
                query: CorpusQuery(layers: [.pressure], signalRanks: [1])
            ),
        ]
    )

    private var context: InterpretationContext {
        InterpretationContext(
            technique: .transit,
            cardID: "trigger-themes",
            locale: "zh-Hans",
            signals: [
                InterpretationSignal(
                    id: "mars-square-moon",
                    rank: 1,
                    strength: 0.9,
                    pointID: "mars",
                    referencePointID: "moon",
                    aspectID: "square",
                    phaseID: "applying",
                    tone: .challenging,
                    values: [
                        "pointName": "行运火星",
                        "referenceName": "本命月亮",
                        "aspectName": "刑相",
                        "phaseName": "入相",
                    ]
                ),
            ]
        )
    }

    @Test("Selects corpus by chart facts and renders templates")
    func selectsAndRenders() throws {
        let pack = InterpretationContentPack(
            schemaVersion: 1,
            contentVersion: "test",
            locale: "zh-Hans",
            entries: [entry],
            rules: [rule]
        )
        let result = try InterpretationEngine(pack: pack).interpret(context)
        #expect(result.summary.contains("行运火星"))
        #expect(result.detail.contains("入相"))
        #expect(result.evidenceIDs == [entry.id])
    }

    @Test("Missing corpus binding fails instead of using fallback copy")
    func missingBindingFails() throws {
        let pack = InterpretationContentPack(
            schemaVersion: 1,
            contentVersion: "test",
            locale: "zh-Hans",
            entries: [],
            rules: [rule]
        )
        let engine = try InterpretationEngine(pack: pack)
        #expect(throws: InterpretationEngineError.self) {
            try engine.interpret(context)
        }
    }

    @Test("Missing card rule fails coverage validation")
    func missingRuleFailsCoverage() throws {
        let pack = InterpretationContentPack(
            schemaVersion: 1,
            contentVersion: "test",
            locale: "zh-Hans",
            entries: [entry],
            rules: [rule]
        )
        let engine = try InterpretationEngine(pack: pack)
        #expect(throws: InterpretationEngineError.self) {
            try engine.validateCoverage(requiredCards: [.natal: ["core-structure"]])
        }
    }

    @Test("Repeated semantic subjects collapse without changing distinct subjects")
    func repeatedSemanticSubjectsCollapse() throws {
        let duplicateEntry = CorpusEntry(
            id: "transit.duplicate.subject",
            locale: "en",
            layer: .pressure,
            selector: CorpusSelector(
                techniques: [.transit],
                pointIDs: ["sun"],
                referencePointIDs: ["sun"]
            ),
            summary: "{{signal.consumerFirst}} and {{signal.consumerSecond}} will need time.",
            detail: "{{signal.consumerFirst}} and {{signal.consumerSecond}} are active. {{signal.consumerFirst}} and {{signal.consumerSecond}} are active.",
            priority: 100,
            deduplicationGroup: "duplicate-subject",
            sourceRevision: "test",
            status: "approved"
        )
        let duplicateRule = CompositionRule(
            id: "transit.duplicate.v1",
            technique: .transit,
            cardID: "trigger-themes",
            summaryTemplate: "{{primary.1.summary}}",
            detailTemplate: "{{primary.1.detail}}",
            bindings: [
                CompositionBinding(
                    name: "primary",
                    query: CorpusQuery(layers: [.pressure], signalRanks: [1])
                ),
            ]
        )
        let pack = InterpretationContentPack(
            schemaVersion: 1,
            contentVersion: "test",
            locale: "en",
            entries: [duplicateEntry],
            rules: [duplicateRule]
        )
        let context = InterpretationContext(
            technique: .transit,
            cardID: "trigger-themes",
            locale: "en",
            signals: [
                InterpretationSignal(
                    id: "sun-sun",
                    rank: 1,
                    strength: 1,
                    pointID: "sun",
                    referencePointID: "sun",
                    values: [
                        "consumerFirst": "Identity",
                        "consumerSecond": "Identity",
                    ]
                ),
            ]
        )

        let result = try InterpretationEngine(pack: pack).interpret(context)
        #expect(result.summary == "Identity will need time.")
        #expect(result.detail == "Identity is active.")
        #expect(!result.summary.contains("Identity and Identity"))
    }
}
