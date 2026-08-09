import AstroCore
import Foundation

enum InsightCardAssembler {
    static func assemble(
        _ cards: [InsightCardModel],
        context: ChartCardFactoryContext,
        transitPlan: TransitContentPlan? = nil,
        synastryPlan: SynastryContentPlan? = nil
    ) throws -> [InsightCardModel] {
        let renderedCards = try cards.map { draft in
            let cardAspects: [ChartAspect]
            let aspectsAreCross: Bool
            switch context.chart {
            case .solarReturn:
                aspectsAreCross = draft.id == "natal-overlay"
                cardAspects = aspectsAreCross ? context.aspects : context.snapshot.aspects
            case .transit, .secondary, .synastry:
                aspectsAreCross = true
                cardAspects = context.aspects
            case .natal, .currentSky:
                aspectsAreCross = false
                cardAspects = context.snapshot.aspects
            }
            let interpretationContext = InterpretationContextFactory.make(
                chart: context.chart,
                cardID: draft.id,
                snapshot: context.snapshot,
                natal: context.natal,
                aspects: cardAspects,
                language: context.language,
                transitCalendar: context.transitCalendar.map(\.score),
                preset: context.preset,
                aspectsAreCross: aspectsAreCross,
                events: context.events
            )
            let interpretation = try? context.content?.interpret(interpretationContext)
            let cardText: CardTextModel?
            if let plan = transitPlan?.card(draft.id) {
                cardText = plan.evidence.isEmpty || plan.copySlot == nil
                    ? nil
                    : try context.copyCatalog?.transitCardText(plan: plan)
            } else if let plan = synastryPlan?.card(draft.id) {
                cardText = plan.evidence.isEmpty
                    ? nil
                    : try context.copyCatalog?.synastryCardText(
                        plan: plan,
                        firstName: synastryPlan?.firstName ?? "Person A",
                        secondName: synastryPlan?.secondName ?? "Person B"
                    )
            } else {
                cardText = context.copyCatalog?.cardText(
                    chart: context.chart,
                    cardID: draft.id,
                    snapshot: context.snapshot,
                    natal: context.natal,
                    aspects: cardAspects,
                    preset: context.preset
                )
            }
            let plannedEvidenceAvailable = transitPlan?.card(draft.id).map { !$0.evidence.isEmpty }
                ?? synastryPlan?.card(draft.id).map { !$0.evidence.isEmpty }
                ?? true
            if context.copyCatalog != nil, cardText == nil, plannedEvidenceAvailable,
               context.copyCatalog?.copyRequired(chart: context.chart, cardID: draft.id) == true {
                throw InsightFactoryError.invalidCardContract(
                    "\(context.chart.rawValue).\(draft.id) has no valid approved copy selection"
                )
            }
            let conclusion: String
            if let transitCardPlan = transitPlan?.card(draft.id), transitCardPlan.copySlot == nil {
                conclusion = ""
            } else {
                conclusion = cardText?.headline ?? cardText?.body ?? interpretation?.summary ?? localized(
                    "Reviewed interpretation unavailable",
                    "已审核解读暂不可用",
                    language: context.language
                )
            }
            return InsightCardModel(
                id: draft.id,
                title: draft.title,
                icon: draft.icon,
                visual: draft.visual,
                facts: draft.facts.map { fact in
                    guard draft.id == "emotional-needs", fact.interpretation == nil else { return fact }
                    return InsightFact(
                        id: fact.id,
                        metricLabel: fact.metricLabel,
                        calculatedValue: fact.calculatedValue,
                        interpretationKey: fact.interpretationKey,
                        interpretationVariables: fact.interpretationVariables,
                        sourceFactIDs: fact.sourceFactIDs,
                        visualRole: fact.visualRole,
                        interpretation: conclusion,
                        emphasis: fact.emphasis,
                        progress: fact.progress,
                        symbol: fact.symbol,
                        category: fact.category,
                        markers: fact.markers
                    )
                },
                conclusionKey: "\(context.chart.contentPrefix).\(draft.id)",
                conclusion: conclusion,
                text: cardText,
                scopeID: transitPlan?.scopeID ?? synastryPlan?.scopeID
            )
        }
        if let transitPlan {
            try TransitCardContractValidator.validate(cards: renderedCards, plan: transitPlan)
        }
        if let synastryPlan {
            try SynastryCardContractValidator.validate(cards: renderedCards, plan: synastryPlan)
        }
        try CardContractValidator.validate(renderedCards, for: context.chart)
        return renderedCards
    }
}
