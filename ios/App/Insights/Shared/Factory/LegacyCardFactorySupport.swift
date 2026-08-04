import AstroCore
import Foundation

extension InsightFactory {
    static func card(
        id: String,
        title: String,
        icon: String,
        visual: InsightVisual,
        facts: [InsightFact],
        language: AppLanguage
    ) -> InsightCardModel {
        return InsightCardModel(
            id: id,
            title: title,
            icon: icon,
            visual: visual,
            facts: facts,
            conclusionKey: nil,
            conclusion: ""
        )
    }

    static func fact(
        _ label: String,
        _ value: String,
        _ emphasis: InsightTone = .neutral,
        stableID: String? = nil,
        interpretationKey: String? = nil,
        sourceFactIDs: [String] = [],
        note: String? = nil,
        progress: Double? = nil,
        symbol: String? = nil,
        category: String? = nil,
        markers: [Double]? = nil
    ) -> InsightFact {
        let rawID = [label, value, symbol ?? "", category ?? ""].joined(separator: "|")
        let resolvedID = stableID ?? "fact." + String(SHA256Digest.hash(Data(rawID.utf8)).hex.prefix(20))
        return InsightFact(
            id: resolvedID,
            metricLabel: label,
            calculatedValue: value,
            interpretationKey: interpretationKey ?? "insight.\(resolvedID)",
            interpretationVariables: ["metric": label, "value": value],
            sourceFactIDs: sourceFactIDs.isEmpty ? [resolvedID] : sourceFactIDs,
            visualRole: category,
            interpretation: note,
            emphasis: emphasis,
            progress: progress,
            symbol: symbol,
            category: category,
            markers: markers
        )
    }

    static func normalized(_ degree: Double?) -> Double {
        (degree ?? 0) / 30
    }

    static func phaseAngle(_ snapshot: ChartSnapshot) -> Double {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return 0 }
        let raw = (moon.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    static func dominantBodies(_ aspects: [ChartAspect], language: AppLanguage) -> String? {
        var scores: [String: Double] = [:]
        for aspect in aspects {
            scores[aspect.firstID, default: 0] += aspect.strength
            scores[aspect.secondID, default: 0] += aspect.strength * 0.6
        }
        let names = scores
            .sorted { $0.value > $1.value }
            .prefix(2)
            .compactMap { CelestialBody(rawValue: $0.key).map { bodyName($0, language: language) } }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    static func motionLabel(_ point: ChartPoint, language: AppLanguage) -> String {
        motionLabel(retrograde: point.retrograde, language: language)
    }

    static func motionLabel(retrograde: Bool, language: AppLanguage) -> String {
        retrograde
            ? localized("insight.reviewing.status", default: "Reviewing", chinese: "回顾调整中", language: language)
            : localized("Moving forward", "稳定向前", language: language)
    }

    static func elementBalance(_ snapshot: ChartSnapshot) -> [Double] {
        let elementBySign: [String: Int] = [
            "aries": 0, "leo": 0, "sagittarius": 0,
            "taurus": 1, "virgo": 1, "capricorn": 1,
            "gemini": 2, "libra": 2, "aquarius": 2,
            "cancer": 3, "scorpio": 3, "pisces": 3,
        ]
        var counts = [Double](repeating: 0, count: 4)
        for point in snapshot.points {
            let sign = Zodiac.englishNames[point.signIndex].lowercased()
            counts[elementBySign[sign] ?? 0] += 1
        }
        guard let maximum = counts.max(), maximum > 0 else {
            return [Double](repeating: 0, count: 4)
        }
        return counts.map { $0 / maximum }
    }

    static func elementFacts(_ scores: [Double], orientation: String, language: AppLanguage) -> [InsightFact] {
        // Prototype order: Air, Earth, Fire, Water. scores = [fire, earth, air, water].
        let order = [2, 1, 0, 3]
        let labels = language == .english
            ? ["Air", "Earth", "Fire", "Water"]
            : ["风", "土", "火", "水"]
        return order.enumerated().map { index, sourceIndex in
            let score = scores[min(max(0, sourceIndex), scores.count - 1)]
            let percent = Int(score * 100)
            let value: String
            if percent > 66 {
                value = language == .english ? "High" : "高"
            } else if percent > 35 {
                value = language == .english ? "Strong" : "强"
            } else {
                value = language == .english ? "Light" : "轻"
            }
            return fact(
                labels[index],
                value,
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: score
            )
        } + [
            fact(localized("Emphasis", "主导", language: language), orientation, .transition)
        ]
    }

    static func elementOrientation(_ scores: [Double], language: AppLanguage) -> String {
        guard let maximum = scores.max(), maximum > 0 else {
            return localized("Balanced", "均衡", language: language)
        }
        let index = scores.firstIndex(of: maximum) ?? 0
        return [
            localized("Fire emphasis", "火象主导", language: language),
            localized("Earth emphasis", "土象主导", language: language),
            localized("Air emphasis", "风象主导", language: language),
            localized("Water emphasis", "水象主导", language: language),
        ][index]
    }

    static func houseValues(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> [Double] {
        var values = [Double](repeating: 0, count: 12)
        for point in snapshot.points {
            let house = (natal?.house(containing: point.longitudeDegrees) ?? snapshot.house(containing: point.longitudeDegrees))
            let index = max(0, min(11, house - 1))
            values[index] += point.retrograde ? 0.75 : 0.5
        }
        for aspect in aspects {
            let house = natal?.house(containing: aspect.firstLongitude) ?? snapshot.house(containing: aspect.firstLongitude)
            let index = max(0, min(11, house - 1))
            values[index] += max(0.1, aspect.strength)
        }
        guard let maximum = values.max(), maximum > 0 else { return values }
        return values.map { $0 / maximum }
    }

    static func activeHouseFacts(_ values: [Double], language: AppLanguage, limit: Int = 12) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .filter { $0.element > 0.001 }
            .sorted { $0.element > $1.element }
            .prefix(limit)
        return ranked.map { index, value in
            let percent = Int(value * 100)
            return fact(
                ConsumerCopy.lifeArea(index + 1, language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: value,
                symbol: "\(index + 1)"
            )
        }
    }

    static func calendarFacts(_ values: [Int], language: AppLanguage) -> [InsightFact] {
        let ranked = values
            .enumerated()
            .sorted { $0.element > $1.element }
            .prefix(3)
        return ranked.map { index, value in
            let percent = value
            return fact(
                LocalizedFormatters.day(index + 1, language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                progress: Double(percent) / 100
            )
        }
    }

    static func timelineFacts(_ aspects: [ChartAspect], language: AppLanguage) -> [InsightFact] {
        let separating = aspects.first { $0.phase == .separating }
        let current = aspects.first { $0.phase == .exact } ?? aspects.first
        let applying = aspects.first { $0.phase == .applying }
        return [
            separating.map { aspect in fact(
                localized("Just passed", "刚刚经过", language: language),
                aspectTitle(aspect, language: language),
                tone(aspect.kind),
                progress: aspect.strength,
                symbol: "✓"
            ) },
            current.map { aspect in fact(
                localized("Current", "当前", language: language),
                aspectTitle(aspect, language: language),
                .transition,
                progress: aspect.strength,
                symbol: "●"
            ) },
            applying.map { aspect in fact(
                localized("Next", "接下来", language: language),
                aspectTitle(aspect, language: language),
                tone(aspect.kind),
                progress: aspect.strength,
                symbol: "→"
            ) },
        ].compactMap { $0 }
    }

    static func progressedPhaseName(_ angle: Double, language: AppLanguage) -> String {
        switch angle {
        case 0 ..< 90: localized("New phase", "新月阶段", language: language)
        case 90 ..< 180: localized("Building phase", "上弦阶段", language: language)
        case 180 ..< 270: localized("Review phase", "满月阶段", language: language)
        default: localized("Integration phase", "下弦阶段", language: language)
        }
    }

    static func ruler(ofSign sign: Int) -> CelestialBody {
        switch sign {
        case 0: .mars
        case 1: .venus
        case 2: .mercury
        case 3: .moon
        case 4: .sun
        case 5: .mercury
        case 6: .venus
        case 7: .mars
        case 8: .jupiter
        case 9: .saturn
        case 10: .saturn
        default: .jupiter
        }
    }
}
