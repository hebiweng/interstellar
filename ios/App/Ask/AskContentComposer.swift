import AstroCore
import Foundation

enum AskContentComposer {
    static func cards(
        for session: HorarySession,
        language: AppLanguage
    ) throws -> [AskResultCard] {
        let content = ContentProvider(area: .ask, language: language)
        switch session.mode {
        case .yesNo:
            guard let analysis = session.analysis else { return [] }
            return try [
                relationshipCard(analysis, content: content),
                moonCard(analysis, content: content),
                obstacleCard(analysis, content: content),
            ]
        case .choice:
            guard let first = session.choices.first else { return [] }
            return try [
                relationshipCard(first.analysis, content: content),
                moonCard(first.analysis, content: content),
                obstacleCard(first.analysis, content: content),
            ]
        case .timing:
            if let timing = session.timingResult, let analysis = session.analysis {
                return try [
                    timingCard(timing, language: language),
                    relationshipCard(analysis, content: content),
                    moonCard(analysis, content: content),
                    obstacleCard(analysis, content: content),
                ]
            }
            guard let first = session.timingCandidates.first else { return [] }
            var cards = [
                AskResultCard(
                    id: "timing-result-legacy",
                    icon: "calendar.badge.checkmark",
                    summary: localized("ask.recommended-window", language: language),
                    detail: localized("ask.timing-consumer-note", language: language)
                )
            ]
            // Only schema v1-v3 election-style When history carries a Horary
            // analysis. New Electional candidates intentionally do not.
            if let legacy = first.legacyHoraryAnalysis {
                cards.append(try relationshipCard(legacy, content: content))
                cards.append(try moonCard(legacy, content: content))
                cards.append(try obstacleCard(legacy, content: content))
            }
            return cards
        case .bestTime:
            guard !session.electionCandidates.isEmpty else { return [] }
            return [
                AskResultCard(
                    id: "best-time-result",
                    icon: "calendar.badge.checkmark",
                    summary: localized("ask.best-time-result-summary", language: language),
                    detail: localized("ask.best-time-result-detail", language: language)
                ),
            ]
        }
    }

    private static func timingCard(
        _ timing: HoraryTimingResult,
        language: AppLanguage
    ) -> AskResultCard {
        let summary: String
        switch timing.status {
        case .indicated: summary = localized("ask.timing-indicated", language: language)
        case .prevented: summary = localized("ask.timing-prevented", language: language)
        case .notIndicated: summary = localized("ask.timing-not-indicated", language: language)
        case .ambiguous: summary = localized("ask.timing-ambiguous", language: language)
        }

        let detail: String
        if timing.status == .indicated {
            let unitText = timing.symbolicUnits.map { String(format: "%.1f°", $0) } ?? "—"
            let scaleText = timing.scales.map { scale in
                switch scale {
                case .days: localized("ask.timing-days", language: language)
                case .weeksOrMonths: localized("ask.timing-weeks-months", language: language)
                case .monthsOrYears: localized("ask.timing-months-years", language: language)
                }
            }.joined(separator: " · ")
            detail = timing.isMixed
                ? "\(unitText) \(localized("ask.to-perfection", language: language)). \(localized("ask.timing-mixed-explanation", language: language))"
                : "\(unitText) \(localized("ask.to-perfection", language: language)). \(scaleText)"
        } else {
            detail = localized("ask.timing-no-promise", language: language)
        }
        return AskResultCard(
            id: "timing-result",
            icon: "clock",
            summary: summary,
            detail: detail
        )
    }

    private static func relationshipCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let key: String
        if let perfection = analysis.judgment?.perfection {
            if perfection.status == .completes, perfection.primaryPath?.kind == .translation {
                key = "ask.connection.translation"
            } else if perfection.status == .completes, perfection.primaryPath?.kind == .collection {
                key = "ask.connection.collection"
            } else if perfection.status == .prevented {
                key = "ask.connection.prevented"
            } else if perfection.status == .delayed {
                key = "ask.connection.delayed"
            } else if let relationship = analysis.relationship {
                if relationship.phase == .separating {
                    key = "ask.connection.separating"
                } else if relationship.kind.supportive || relationship.kind == .conjunction {
                    key = "ask.connection.supportive"
                } else {
                    key = "ask.connection.challenging"
                }
            } else {
                key = "ask.connection.none"
            }
        } else if let relationship = analysis.relationship {
            if relationship.phase == .separating {
                key = "ask.connection.separating"
            } else if relationship.kind.supportive || relationship.kind == .conjunction {
                key = "ask.connection.supportive"
            } else {
                key = "ask.connection.challenging"
            }
        } else {
            key = "ask.connection.none"
        }
        return card(
            id: "connection",
            icon: "link",
            copy: try content.requiredCopy(key: key)
        )
    }

    private static func moonCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        card(
            id: "moon",
            icon: "moon.stars",
            copy: try content.requiredCopy(
                key: analysis.moon.isVoidOfCourse
                    ? "ask.moon.void"
                    : "ask.moon.next"
            )
        )
    }

    private static func obstacleCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let hasInterruption = !(analysis.judgment?.perfection.interruptions.isEmpty ?? true)
        let hasConditionRisk = analysis.querent.conditions.contains(.combust)
            || analysis.querent.conditions.contains(.retrograde)
            || analysis.target.conditions.contains(.combust)
            || analysis.target.conditions.contains(.retrograde)
        return card(
            id: "obstacle",
            icon: hasInterruption || hasConditionRisk ? "exclamationmark.triangle" : "shield.checkered",
            copy: try content.requiredCopy(
                key: hasInterruption || hasConditionRisk ? "ask.risk.present" : "ask.risk.limited"
            )
        )
    }

    private static func card(
        id: String,
        icon: String,
        copy: (summary: String, detail: String)
    ) -> AskResultCard {
        AskResultCard(
            id: id,
            icon: icon,
            summary: copy.summary,
            detail: copy.detail
        )
    }
}
