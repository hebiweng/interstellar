import AstroCore
import ContentKit
import Foundation

struct InsightContentEntry: Codable, Equatable {
    let contentKey: String
    let summary: String
    let detail: String
    let sourceRevision: String?
    let translationStatus: String?
}

private struct InsightContentPack: Codable {
    let version: String
    let locale: String
    let entries: [InsightContentEntry]
}

struct ContentProvider {
    private let entries: [String: InsightContentEntry]

    init(language: AppLanguage, bundle: Bundle = .main) {
        let resourceName = "PrivateContent-\(language.corpusLanguage.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        var loaded: [InsightContentEntry] = []
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let pack = try? JSONDecoder().decode(InsightContentPack.self, from: data)
            {
                loaded = pack.entries.filter {
                    $0.translationStatus == "approved"
                        || $0.translationStatus == "sample"
                }
                break
            }
        }
        entries = Dictionary(uniqueKeysWithValues: loaded.map { ($0.contentKey, $0) })
    }

    func requiredCopy(
        key: String,
        variables: [String: String] = [:]
    ) throws -> (summary: String, detail: String) {
        guard let entry = entries[key] else {
            throw ConsumerContentError.missingEntry(key)
        }
        return (
            interpolate(entry.summary, variables: variables),
            interpolate(entry.detail, variables: variables)
        )
    }

    private func interpolate(
        _ template: String,
        variables: [String: String]
    ) -> String {
        variables.reduce(template) { result, item in
            result.replacingOccurrences(of: "{{\(item.key)}}", with: item.value)
        }
    }
}

private struct RuntimeCopyVariable: Codable {
    let name: String
    let type: String
}

private struct RuntimeCopyEntry: Codable {
    let id: String
    let locale: String
    let status: String
    let kind: String
    let sourcePath: String
    let value: String
    let variables: [RuntimeCopyVariable]
}

private struct RuntimeThemeRule: Codable {
    let id: String
    let pair: [String]
    let tone: String
    let themeID: String
}

private struct RuntimeCopyCatalog: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let status: String
    let entries: [RuntimeCopyEntry]
    let themeRules: [RuntimeThemeRule]
}

enum CopyCatalogError: LocalizedError {
    case resourceMissing(String)
    case invalidPack(String)
    case missingCopy(String)
    case unknownVariable(String)
    case unresolvedVariable(String)

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(name): "Reviewed copy catalog \(name) is missing."
        case let .invalidPack(reason): "Reviewed copy catalog is invalid: \(reason)"
        case let .missingCopy(path): "Reviewed copy is missing: \(path)"
        case let .unknownVariable(name): "Copy uses an undeclared variable: \(name)"
        case let .unresolvedVariable(name): "Copy variable was not replaced: \(name)"
        }
    }
}

/// Normalized, chart-agnostic signals derived only from authoritative facts.
/// This layer never selects consumer wording.
private struct StandardCopySignals {
    let primaryAspect: ChartAspect?
    let moonSignIndex: Int
    let sunSignIndex: Int
    let ascendantSignIndex: Int
}

private enum StandardSignalBuilder {
    static func build(snapshot: ChartSnapshot, aspects: [ChartAspect]) -> StandardCopySignals {
        StandardCopySignals(
            primaryAspect: aspects.max(by: { $0.strength < $1.strength })
                ?? snapshot.aspects.max(by: { $0.strength < $1.strength }),
            moonSignIndex: snapshot.point(.moon)?.signIndex ?? 0,
            sunSignIndex: snapshot.point(.sun)?.signIndex ?? 0,
            ascendantSignIndex: Int(snapshot.angles.ascendantDegrees / 30) % 12
        )
    }
}

/// Declares which stable facts a card is allowed to carry into copy matching.
private struct CardEvidencePlan {
    let primaryAspect: ChartAspect?
    let sourceFactIDs: [String]
}

private enum CardEvidencePlanner {
    static func plan(cardID _: String, signals: StandardCopySignals) -> CardEvidencePlan {
        CardEvidencePlan(
            primaryAspect: signals.primaryAspect,
            sourceFactIDs: signals.primaryAspect.map { [$0.id] } ?? []
        )
    }
}

/// Maps evidence to a reviewed theme selector. It deliberately returns only a
/// theme ID; complete consumer sentences remain owned by CopyCatalogMatcher.
private enum ThemeMapper {
    static func themeID(
        for aspect: ChartAspect?,
        house: Int,
        rules: [RuntimeThemeRule],
        houseFallback: (Int, String) -> String?
    ) -> String {
        let tone = aspect.map {
            $0.kind.supportive ? "supportive" : ($0.kind.challenging ? "challenging" : "neutral")
        } ?? "neutral"
        if let aspect {
            let pair = Set([aspect.firstID, aspect.secondID])
            if let rule = rules.first(where: { Set($0.pair) == pair && $0.tone == tone }) {
                return rule.themeID
            }
        }
        if let fallback = houseFallback(house, tone) { return fallback }
        return tone == "supportive"
            ? "confidence.expansion"
            : (tone == "challenging" ? "responsibility.pressure" : "structure.building")
    }
}

/// Runtime access to the normalized project catalog. Source attachments are
/// converted by build-ios-copy-catalog.mjs and are never read by the App.
struct CopyCatalogMatcher {
    private let pack: RuntimeCopyCatalog
    private let entriesByPath: [String: RuntimeCopyEntry]

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let locale = language.corpusLanguage.rawValue
        let resourceName = "CopyCatalog-\(locale)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CopyCatalogError.resourceMissing(resourceName)
        }
        do {
            let decoded = try JSONDecoder().decode(RuntimeCopyCatalog.self, from: Data(contentsOf: url))
            guard decoded.schemaVersion == 1,
                  decoded.locale == locale,
                  decoded.status == "approved"
            else {
                throw CopyCatalogError.invalidPack("version, locale or approval state")
            }
            let approved = decoded.entries.filter { $0.status == "approved" }
            guard approved.count == decoded.entries.count else {
                throw CopyCatalogError.invalidPack("non-approved entries reached the runtime pack")
            }
            let pairs = approved.map { ($0.sourcePath, $0) }
            guard Dictionary(grouping: pairs, by: \.0).values.allSatisfy({ $0.count == 1 }) else {
                throw CopyCatalogError.invalidPack("duplicate source path")
            }
            pack = decoded
            entriesByPath = Dictionary(uniqueKeysWithValues: pairs)
        } catch let error as CopyCatalogError {
            throw error
        } catch {
            throw CopyCatalogError.invalidPack(String(describing: error))
        }
    }

    func value(at sourcePath: String, variables: [String: String] = [:]) throws -> String {
        guard let entry = entriesByPath[sourcePath] else { throw CopyCatalogError.missingCopy(sourcePath) }
        let declared = Set(entry.variables.map(\.name))
        let supplied = Set(variables.keys)
        guard supplied.isSubset(of: declared) else {
            throw CopyCatalogError.unknownVariable(supplied.subtracting(declared).sorted().joined(separator: ","))
        }
        var rendered = entry.value
        for variable in entry.variables {
            guard let replacement = variables[variable.name] else {
                throw CopyCatalogError.unresolvedVariable(variable.name)
            }
            rendered = rendered.replacingOccurrences(of: "{{\(variable.name)}}", with: replacement)
        }
        if let unresolved = rendered.firstMatch(of: /\{\{([A-Za-z][A-Za-z0-9]*)\}\}/)?.1 {
            throw CopyCatalogError.unresolvedVariable(String(unresolved))
        }
        return rendered
    }

    func cardText(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> CardTextModel? {
        let selection = copySelection(chart: chart, cardID: cardID, snapshot: snapshot, natal: natal, aspects: aspects)
        return textModel(from: selection, cardID: cardID)
    }

    func todayText(
        cardID: String,
        sky: ChartSnapshot,
        transit: ChartSnapshot,
        natal: ChartSnapshot,
        transitAspects: [ChartAspect]
    ) -> CardTextModel? {
        let selection: CopySelection?
        switch cardID {
        case "current-chapter":
            selection = copySelection(chart: .transit, cardID: "current-story", snapshot: transit, natal: natal, aspects: transitAspects)
        case "active-today":
            selection = copySelection(chart: .transit, cardID: "active-transits", snapshot: transit, natal: natal, aspects: transitAspects)
        case "coming-next":
            selection = copySelection(chart: .transit, cardID: "transit-timeline", snapshot: transit, natal: natal, aspects: transitAspects)
        case "moon-today":
            selection = copySelection(chart: .currentSky, cardID: "moon-now", snapshot: sky, natal: natal, aspects: sky.aspects)
        case "today-timeline":
            let strongest = sky.aspects.max(by: { $0.strength < $1.strength })
            selection = strongest.flatMap(aspectCopyPath).map {
                CopySelection(headline: nil, body: $0, secondary: nil, themeID: nil, signalIDs: strongest.map { [$0.id] } ?? [])
            }
        case "upcoming-sky-events":
            selection = copySelection(chart: .currentSky, cardID: "upcoming-7-days", snapshot: sky, natal: natal, aspects: sky.aspects)
        case "retrogrades":
            selection = copySelection(chart: .currentSky, cardID: "planetary-motion", snapshot: sky, natal: natal, aspects: sky.aspects)
        default:
            selection = nil
        }
        return textModel(from: selection, cardID: cardID)
    }

    private func textModel(from selection: CopySelection?, cardID: String) -> CardTextModel? {
        guard let selection else { return nil }
        let headline = selection.headline.flatMap { try? value(at: $0) }
        let body = selection.body.flatMap { try? value(at: $0) }
        let secondary = selection.secondary.flatMap { try? value(at: $0) }
        guard headline != nil || body != nil || secondary != nil else { return nil }
        return CardTextModel(
            sectionLabel: nil,
            cardLabel: cardID,
            headline: headline,
            body: body,
            secondaryBody: secondary,
            areaLabel: nil,
            statusLabel: nil,
            technicalLabel: nil,
            startLabel: nil,
            endLabel: nil,
            themeID: selection.themeID,
            sourceSignalIDs: selection.signalIDs,
            copyPackID: "\(pack.contentVersion):\(selection.body ?? selection.headline ?? cardID)"
        )
    }

    private func copySelection(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> CopySelection? {
        let signals = StandardSignalBuilder.build(snapshot: snapshot, aspects: aspects)
        let evidence = CardEvidencePlanner.plan(cardID: cardID, signals: signals)
        let primaryAspect = evidence.primaryAspect
        let copyableAspect = (aspects + snapshot.aspects)
            .sorted { $0.strength > $1.strength }
            .first { aspect in
                guard let path = aspectCopyPath(aspect) else { return false }
                return entriesByPath[path] != nil
            }
        let aspectPath = copyableAspect.flatMap(aspectCopyPath)
        let aspectSignalIDs = copyableAspect.map { [$0.id] } ?? evidence.sourceFactIDs
        let moonSign = signKey(signals.moonSignIndex)
        let sunSign = signKey(signals.sunSignIndex)
        let ascSign = signKey(signals.ascendantSignIndex)
        let leadingHouse = leadingHouse(in: snapshot, aspects: aspects)
        let atmosphere = skyAtmosphere(snapshot)

        switch chart {
        case .natal:
            let signature = temperament(snapshot)
            switch cardID {
            case "natal-interpretation", "element-balance":
                return pair("natal.bigThree.\(signature.element).\(signature.mode)", signalIDs: snapshot.points.prefix(3).map(\.id))
            case "emotional-needs": return pair("natal.moonNeeds.\(moonSign)", signalIDs: ["moon.sign"])
            case "love-connection":
                let venusSign = snapshot.point(.venus).map { signKey($0.signIndex) } ?? "aries"
                let base = "natal.loveElementMatrix.\(element(for: venusSign)).\(element(for: moonSign))"
                return CopySelection(headline: nil, body: base, secondary: "natal.venusGives.\(venusSign)", themeID: nil, signalIDs: ["venus.sign", "moon.sign"])
            case "career-direction": return pair("natal.mcDirection.\(signKey(Int(snapshot.angles.midheavenDegrees / 30) % 12))", signalIDs: ["mc.sign"])
            case "strengths-growth", "key-aspects": return aspectPath.map { CopySelection(headline: nil, body: $0, secondary: nil, themeID: nil, signalIDs: aspectSignalIDs) }
            case "house-emphasis": return CopySelection(headline: nil, body: "shared.maturingArea.\(leadingHouse)", secondary: nil, themeID: nil, signalIDs: ["house.\(leadingHouse)"])
            case "chart-signature": return CopySelection(headline: nil, body: "shared.chartRulerCopy.\(ruler(for: ascSign))", secondary: nil, themeID: nil, signalIDs: ["ascendant.sign"])
            case "planet-placements": return CopySelection(headline: nil, body: "natal.placement.sun.\(sunSign)", secondary: nil, themeID: nil, signalIDs: ["sun.sign"])
            default: return nil
            }
        case .currentSky:
            switch cardID {
            case "moon-now": return pair("shared.lunarPhase.\(lunarPhaseKey(snapshot)).", trailingDot: true, signalIDs: ["moon.phase", "moon.sign"])
            case "planetary-motion":
                let point = snapshot.points.first(where: \.retrograde) ?? snapshot.points.first
                guard let point else { return nil }
                let state = point.retrograde ? "retrograde" : "direct"
                return CopySelection(headline: nil, body: "shared.bodyMotion.\(point.body.rawValue).\(state)", secondary: nil, themeID: nil, signalIDs: [point.id])
            case "sign-changes":
                return CopySelection(headline: nil, body: "shared.signStyle.\(moonSign)", secondary: nil, themeID: nil, signalIDs: ["moon.sign"])
            case "sky-overview", "aspect-pattern", "element-climate", "upcoming-7-days":
                return pair("currentSky.skyAtmosphere.\(atmosphere)", signalIDs: snapshot.aspects.prefix(3).map(\.id))
            default: return nil
            }
        case .transit:
            let themeID = ThemeMapper.themeID(
                for: primaryAspect,
                house: leadingHouse,
                rules: pack.themeRules,
                houseFallback: { house, tone in try? value(at: "transit.houseFallback.\(house).\(tone)") }
            )
            let slot = cardID == "active-transits" ? "active" : (cardID == "transit-timeline" ? "coming" : "chapter")
            return pair("transit.themePacks.\(themeID).\(slot)", themeID: themeID, signalIDs: aspectSignalIDs)
        case .secondary:
            switch cardID {
            case "developmental-chapter", "timeline": return pair("secondary.progressedPhase.\(progressedPhaseKey(snapshot))", signalIDs: ["progressed.phase"])
            case "progressed-moon": return pair("natal.moonNeeds.\(moonSign)", signalIDs: ["progressed.moon.sign"])
            case "identity-development": return CopySelection(headline: nil, body: "secondary.progressedSun.\(sunSign)", secondary: nil, themeID: nil, signalIDs: ["progressed.sun.sign"])
            case "areas-maturing": return CopySelection(headline: nil, body: "shared.maturingArea.\(leadingHouse)", secondary: nil, themeID: nil, signalIDs: ["house.\(leadingHouse)"])
            case "turning-points": return aspectPath.map { CopySelection(headline: nil, body: $0, secondary: nil, themeID: nil, signalIDs: aspectSignalIDs) }
            default: return nil
            }
        case .solarReturn:
            switch cardID {
            case "year-theme", "year-anchors", "priority-areas", "natal-overlay": return pair("solarReturn.solarAsc.\(ascSign)", signalIDs: ["solar.ascendant.sign"])
            case "year-timeline": return pair("solarReturn.solarQuarters.1", signalIDs: ["solar.quarter.1"])
            case "year-dynamics", "year-aspects": return aspectPath.map { CopySelection(headline: nil, body: $0, secondary: nil, themeID: nil, signalIDs: aspectSignalIDs) }
            default: return nil
            }
        case .synastry:
            let overview = synastryOverview(aspects)
            switch cardID {
            case "relationship-overview", "perspectives": return pair("synastry.overview.\(overview)", signalIDs: aspects.prefix(3).map(\.id))
            case "house-overlays": return CopySelection(headline: nil, body: "synastry.houseOverlay.\(leadingHouse)", secondary: nil, themeID: nil, signalIDs: ["overlay.house.\(leadingHouse)"])
            case "emotional-connection", "communication", "chemistry", "commitment", "key-inter-aspects":
                return aspectPath.map { CopySelection(headline: nil, body: $0, secondary: nil, themeID: nil, signalIDs: aspectSignalIDs) }
            default: return nil
            }
        }
    }

    private func pair(_ base: String, trailingDot: Bool = false, themeID: String? = nil, signalIDs: [String]) -> CopySelection {
        let normalized = trailingDot ? String(base.dropLast()) : base
        return CopySelection(headline: "\(normalized).headline", body: "\(normalized).body", secondary: nil, themeID: themeID, signalIDs: signalIDs)
    }

    private func aspectCopyPath(_ aspect: ChartAspect) -> String? {
        let allowed = Set(CelestialBody.allCases.filter { $0 != .trueNode }.map(\.rawValue))
        guard allowed.contains(aspect.firstID), allowed.contains(aspect.secondID) else { return nil }
        let order = CelestialBody.allCases.map(\.rawValue)
        let pair = [aspect.firstID, aspect.secondID].sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
        let tone = aspect.kind.supportive ? "supportive" : (aspect.kind.challenging ? "challenging" : "neutral")
        return "natal.aspectCopy.\(pair[0]).\(pair[1]).\(tone)"
    }

    private func temperament(_ snapshot: ChartSnapshot) -> (element: String, mode: String) {
        let signs = snapshot.points.filter { $0.body != .trueNode }.map { signKey($0.signIndex) }
        let elementCounts = Dictionary(grouping: signs.map(element), by: { $0 }).mapValues(\.count)
        let modeCounts = Dictionary(grouping: signs.map(mode), by: { $0 }).mapValues(\.count)
        let element = uniqueLeader(elementCounts) ?? "balanced"
        let mode = uniqueLeader(modeCounts) ?? "mixed"
        return (element, mode)
    }

    private func leadingHouse(in snapshot: ChartSnapshot, aspects: [ChartAspect]) -> Int {
        let pointByID = Dictionary(uniqueKeysWithValues: snapshot.points.map { ($0.id, $0) })
        let weighted = aspects.reduce(into: [Int: Double]()) { result, aspect in
            for id in [aspect.firstID, aspect.secondID] {
                if let point = pointByID[id] { result[snapshot.house(containing: point.longitudeDegrees), default: 0] += aspect.strength }
            }
        }
        return weighted.max(by: { $0.value < $1.value })?.key ?? snapshot.point(.sun).map { snapshot.house(containing: $0.longitudeDegrees) } ?? 1
    }

    private func skyAtmosphere(_ snapshot: ChartSnapshot) -> String {
        let supportive = snapshot.aspects.filter(\.kind.supportive).count
        let challenging = snapshot.aspects.filter(\.kind.challenging).count
        let retrogrades = snapshot.points.filter(\.retrograde).count
        if retrogrades >= 4 { return "review" }
        if snapshot.aspects.count <= 2 { return "quiet" }
        if supportive > challenging * 2 { return "supportive" }
        if challenging > supportive * 2 { return "challenging" }
        return "mixed"
    }

    private func lunarPhaseKey(_ snapshot: ChartSnapshot) -> String {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return "new-moon" }
        let angle = (moon.longitudeDegrees - sun.longitudeDegrees + 360).truncatingRemainder(dividingBy: 360)
        return ["new-moon", "waxing-crescent", "first-quarter", "waxing-gibbous", "full-moon", "waning-gibbous", "last-quarter", "waning-crescent"][Int((angle + 22.5) / 45) % 8]
    }

    private func progressedPhaseKey(_ snapshot: ChartSnapshot) -> String {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return "new" }
        let angle = (moon.longitudeDegrees - sun.longitudeDegrees + 360).truncatingRemainder(dividingBy: 360)
        if angle < 90 { return "new" }
        if angle < 180 { return "building" }
        if angle < 270 { return "review" }
        return "integration"
    }

    private func synastryOverview(_ aspects: [ChartAspect]) -> String {
        guard !aspects.isEmpty else { return "quiet" }
        let supportive = aspects.filter(\.kind.supportive).count
        let challenging = aspects.filter(\.kind.challenging).count
        let intense = aspects.filter { $0.strength >= 0.78 }.count >= 2
        if supportive > challenging * 2 { return intense ? "supportive-intense" : "supportive-balanced" }
        if challenging > supportive * 2 { return intense ? "challenging-intense" : "challenging-growth" }
        return "mixed"
    }

    private func uniqueLeader(_ counts: [String: Int]) -> String? {
        let sorted = counts.sorted { $0.value > $1.value }
        guard let first = sorted.first, sorted.dropFirst().first?.value != first.value else { return nil }
        return first.key
    }

    private func signKey(_ index: Int) -> String {
        ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"][((index % 12) + 12) % 12]
    }

    private func element(for sign: String) -> String {
        if ["aries", "leo", "sagittarius"].contains(sign) { return "fire" }
        if ["taurus", "virgo", "capricorn"].contains(sign) { return "earth" }
        if ["gemini", "libra", "aquarius"].contains(sign) { return "air" }
        return "water"
    }

    private func mode(for sign: String) -> String {
        if ["aries", "cancer", "libra", "capricorn"].contains(sign) { return "cardinal" }
        if ["taurus", "leo", "scorpio", "aquarius"].contains(sign) { return "fixed" }
        return "mutable"
    }

    private func ruler(for sign: String) -> String {
        ["aries": "mars", "taurus": "venus", "gemini": "mercury", "cancer": "moon", "leo": "sun", "virgo": "mercury", "libra": "venus", "scorpio": "pluto", "sagittarius": "jupiter", "capricorn": "saturn", "aquarius": "uranus", "pisces": "neptune"][sign] ?? "sun"
    }
}

/// Compatibility name for call sites while the v6 content pipeline migrates.
typealias CopyCatalogProvider = CopyCatalogMatcher

private struct CopySelection {
    let headline: String?
    let body: String?
    let secondary: String?
    let themeID: String?
    let signalIDs: [String]
}

enum ConsumerContentError: Error, LocalizedError {
    case missingEntry(String)

    var errorDescription: String? {
        switch self {
        case let .missingEntry(key):
            "Required consumer content is missing: \(key)"
        }
    }
}

enum CorpusContentProviderError: Error, LocalizedError {
    case resourceMissing(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(name):
            "Required interpretation pack \(name) is missing."
        case let .unreadable(reason):
            "Interpretation content could not be loaded: \(reason)"
        }
    }
}

struct CorpusContentProvider {
    private let engine: InterpretationEngine

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let corpusLanguage = language.corpusLanguage
        let resourceName = "PrivateCorpus-\(corpusLanguage.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CorpusContentProviderError.resourceMissing(resourceName)
        }

        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(InterpretationContentPack.self, from: data)
            #if DEBUG
            engine = try InterpretationEngine(
                pack: pack,
                allowedStatuses: ["approved", "sample"]
            )
            #else
            engine = try InterpretationEngine(pack: pack)
            #endif
            try engine.validateCoverage(requiredCards: Self.requiredCards)
        } catch {
            throw CorpusContentProviderError.unreadable(String(describing: error))
        }
    }

    func interpret(_ context: InterpretationContext) throws -> InterpretationResult {
        try engine.interpret(context)
    }

    private static let requiredCards: [InterpretationTechnique: Set<String>] = [
        .natal: [
            "natal-interpretation",
            "emotional-needs",
            "love-connection",
            "career-direction",
            "strengths-growth",
            "element-balance",
            "house-emphasis",
            "chart-signature",
            "planet-placements",
            "key-aspects",
        ],
        .currentSky: [
            "sky-overview",
            "moon-now",
            "aspect-pattern",
            "planetary-motion",
            "sign-changes",
            "element-climate",
            "upcoming-7-days",
        ],
        .transit: [
            "current-story",
            "current-cycles",
            "transit-timeline",
            "planet-paths",
            "life-areas",
            "active-transits",
        ],
        .secondary: [
            "developmental-chapter",
            "progressed-moon",
            "identity-development",
            "turning-points",
            "areas-maturing",
            "timeline",
        ],
        .solarReturn: [
            "year-theme",
            "year-anchors",
            "priority-areas",
            "year-dynamics",
            "year-timeline",
            "natal-overlay",
            "year-aspects",
        ],
        .synastry: [
            "relationship-overview",
            "perspectives",
            "emotional-connection",
            "communication",
            "chemistry",
            "commitment",
            "house-overlays",
            "key-inter-aspects",
        ],
    ]
}
