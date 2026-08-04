import Foundation

enum CardContractValidator {
    static func validate(_ cards: [InsightCardModel], for chart: ChartKind) throws {
        #if DEBUG
        let expected: [ChartKind: [String]] = [
            .natal: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"],
            .currentSky: ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"],
            .transit: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"],
            .secondary: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"],
            .solarReturn: ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"],
            .synastry: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"],
        ]
        let expectedIDs = expected[chart] ?? []
        guard cards.map(\.id) == expectedIDs else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) card set is incomplete")
        }
        guard cards.allSatisfy({ card in
            guard !card.title.isEmpty else { return false }
            return chart == .transit && card.id == "transit-timeline"
                ? card.text == nil && card.summary.isEmpty
                : !card.summary.isEmpty
        }) else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) contains empty card copy")
        }
        #endif
    }
}
