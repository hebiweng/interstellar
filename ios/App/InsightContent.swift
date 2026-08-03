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

private struct RuntimeCopyContract: Codable {
    let id: String
    let technique: String
    let cardID: String
    let selector: String
    let facts: [String]
    let evidenceByPreset: [String: [String]]
    let textFields: [String]
    let copySourceByPreset: [String: [String]]
}

private struct RuntimeCopyCatalog: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let status: String
    let contracts: [RuntimeCopyContract]
    let entries: [RuntimeCopyEntry]
    let themeRulesByPreset: [String: [RuntimeThemeRule]]
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
    let moonSignIndex: Int
    let sunSignIndex: Int
    let ascendantSignIndex: Int
}

private enum StandardSignalBuilder {
    static func build(snapshot: ChartSnapshot, aspects: [ChartAspect]) -> StandardCopySignals {
        StandardCopySignals(
            moonSignIndex: snapshot.point(.moon)?.signIndex ?? 0,
            sunSignIndex: snapshot.point(.sun)?.signIndex ?? 0,
            ascendantSignIndex: Int(snapshot.angles.ascendantDegrees / 30) % 12
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

    static func themeID(
        for input: TransitThemeInput,
        rules: [RuntimeThemeRule],
        houseFallback: (Int, String) -> String?
    ) -> String {
        if let movingID = input.movingID,
           let referenceID = input.referenceID,
           let rule = rules.first(where: {
               Set($0.pair) == Set([movingID, referenceID]) && $0.tone == input.tone
           })
        {
            return rule.themeID
        }
        if let house = input.house,
           let fallback = houseFallback(house, input.tone)
        {
            return fallback
        }
        return input.tone == "supportive"
            ? "confidence.expansion"
            : (input.tone == "challenging" ? "responsibility.pressure" : "structure.building")
    }
}

/// A resolved selection references one or two source paths. The runtime pack
/// stores both flat leaf strings and grouped headline/body maps; `textModel`
/// reads whichever is available.
private struct CopySelection {
    let basePath: String?
    let secondaryPath: String?
    let themeID: String?
    let sourceFactIDs: [String]
}

struct TransitCopyRequest: Codable, Equatable, Sendable {
    let key: String
    let cardID: String
    let copySlot: String
    let themeID: String?
    let integratedThemeID: String?
    let roleID: String?
    let variables: [String: String]
    let sourceFactIDs: [String]

    var identity: String {
        [key, cardID, copySlot].joined(separator: "|")
    }
}

/// Runtime access to the normalized project catalog. Source attachments are
/// converted by build-ios-copy-catalog.mjs and are never read by the App.
struct CopyCatalogMatcher {
    private let pack: RuntimeCopyCatalog
    private let entriesByPath: [String: RuntimeCopyEntry]
    private let contractsByID: [String: RuntimeCopyContract]

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let locale = language.rawValue
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
            guard decoded.schemaVersion == 2,
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
            contractsByID = Dictionary(uniqueKeysWithValues: decoded.contracts.map { ($0.id, $0) })
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

    private func valueIfPresent(at sourcePath: String, variables: [String: String] = [:]) -> String? {
        try? value(at: sourcePath, variables: variables)
    }

    /// Returns true when the card's contract expects consumer-visible headline or body text.
    /// Rows-only or technical-only cards may return nil without breaking the build.
    func copyRequired(chart: ChartKind, cardID: String) -> Bool {
        let technique: String
        switch chart {
        case .natal: technique = "natal"
        case .currentSky: technique = "current-sky"
        case .transit: technique = "transit"
        case .secondary: technique = "secondary"
        case .solarReturn: technique = "solar-return"
        case .synastry: technique = "synastry"
        }
        guard let contract = contractsByID["\(technique).\(cardID)"] else { return true }
        let fields = contract.textFields
        return fields.contains("headline") || fields.contains("body") || fields.contains("allDisplayedFields") || fields.contains("secondary")
    }

    func cardText(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        preset: String? = nil
    ) -> CardTextModel? {
        // Classical preset copy selection is not yet fully implemented; use modern paths as a safe fallback.
        let _ = preset
        let selection = copySelection(
            chart: chart,
            cardID: cardID,
            snapshot: snapshot,
            natal: natal,
            aspects: aspects
        )
        return textModel(from: selection, cardID: cardID)
    }

    func transitCardText(plan: CardEvidencePlan) throws -> CardTextModel {
        let requests = transitCopyRequests(plan: plan)
        let roleTexts = try requests
            .filter { $0.copySlot == TransitCopySlot.signalRole.rawValue }
            .map { request in
                CardRoleText(
                    roleID: request.roleID ?? TransitStorySignalRoleID.supporting.rawValue,
                    text: try value(
                        at: request.key,
                        variables: renderedTransitVariables(request.variables)
                    ),
                    sourceFactIDs: request.sourceFactIDs
                )
            }
        let cycleTexts = try requests
            .filter { $0.copySlot == TransitCopySlot.cycleChapter.rawValue }
            .map { request in
                let headline = try value(at: "\(request.key).headline")
                let body = try value(at: "\(request.key).body")
                return TransitCycleText(
                    roleID: request.roleID ?? "",
                    headline: headline,
                    body: body,
                    sourceFactIDs: request.sourceFactIDs
                )
            }
        guard plan.copySlot != nil,
              let selection = transitCopySelection(plan: plan, requests: requests),
              let model = textModel(
                  from: selection,
                  cardID: plan.cardID,
                  scopeID: plan.scopeID,
                  roleTexts: roleTexts,
                  cycleTexts: cycleTexts
              )
        else {
            throw CopyCatalogError.missingCopy("modern.transit.\(plan.copySlot?.rawValue ?? "technical")")
        }
        return model
    }

    func transitCopyRequests(plan: CardEvidencePlan) -> [TransitCopyRequest] {
        guard !plan.evidence.isEmpty, plan.cardID != "transit-timeline" else { return [] }
        switch plan.copySlot {
        case .integratedStory:
            var requests: [TransitCopyRequest] = []
            if let integratedThemeID = plan.integratedThemeID {
                requests.append(
                    TransitCopyRequest(
                        key: "modern.transit.integratedStory.\(integratedThemeID.rawValue)",
                        cardID: plan.cardID,
                        copySlot: TransitCopySlot.integratedStory.rawValue,
                        themeID: nil,
                        integratedThemeID: integratedThemeID.rawValue,
                        roleID: nil,
                        variables: [:],
                        sourceFactIDs: plan.sourceFactIDs
                    )
                )
            }
            requests += plan.signalRoles.map { assignment in
                TransitCopyRequest(
                    key: "modern.transit.signalRole.\(assignment.signalRole.rawValue)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.signalRole.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: assignment.signalRole.rawValue,
                    variables: [
                        "transitPlanet": assignment.movingID,
                        "lifeAreas": assignment.lifeAreas.map(String.init).joined(separator: ","),
                    ],
                    sourceFactIDs: assignment.sourceFactIDs
                )
            }
            return requests
        case .cycleChapter:
            return plan.themeInputs.compactMap { input in
                transitThemeRequest(
                    input: input,
                    cardID: plan.cardID,
                    slot: .cycleChapter
                )
            }
        case .planetPathShort:
            guard let evidence = plan.evidence.first(where: {
                if case .placement = $0.fact { return true }
                return false
            }),
            case let .placement(placement) = evidence.fact
            else { return [] }
            let state = placement.retrograde ? "retrograde" : "direct"
            var requests = [
                TransitCopyRequest(
                    key: "shared.bodyMotion.\(placement.body.rawValue).\(state)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.planetPathShort.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: "path",
                    variables: [:],
                    sourceFactIDs: evidence.fact.sourceFactIDs
                ),
            ]
            if (1 ... 12).contains(placement.natalHouse) {
                requests.append(
                    TransitCopyRequest(
                        key: "shared.lifeAreas.\(placement.natalHouse)",
                        cardID: plan.cardID,
                        copySlot: TransitCopySlot.planetPathShort.rawValue,
                        themeID: nil,
                        integratedThemeID: nil,
                        roleID: "path",
                        variables: [:],
                        sourceFactIDs: evidence.fact.sourceFactIDs
                    )
                )
            }
            return requests
        case .lifeAreaShort:
            guard let evidence = plan.evidence.first(where: {
                if case .lifeArea = $0.fact { return true }
                return false
            }),
            case let .lifeArea(area) = evidence.fact
            else { return [] }
            return [
                TransitCopyRequest(
                    key: "shared.lifeAreas.\(area.house)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.lifeAreaShort.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: "lifeArea",
                    variables: [:],
                    sourceFactIDs: evidence.fact.sourceFactIDs
                ),
            ]
        case .activeTransitShort:
            return transitThemeRequest(plan: plan, slot: .activeTransitShort).map { [$0] } ?? []
        case .signalRole, nil:
            return []
        }
    }

    func todayText(
        cardID: String,
        sky: ChartSnapshot,
        transit: ChartSnapshot,
        natal: ChartSnapshot,
        transitAspects: [ChartAspect],
        preset: String? = nil
    ) -> CardTextModel? {
        // Classical preset copy selection is not yet fully implemented; use modern paths as a safe fallback.
        let _ = preset
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
            selection = strongest.flatMap { aspectCopyPath($0) }.map {
                CopySelection(basePath: $0, secondaryPath: nil, themeID: nil, sourceFactIDs: strongest.map { [$0.id] } ?? [])
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

    private func textModel(
        from selection: CopySelection?,
        cardID: String,
        scopeID: String? = nil,
        roleTexts: [CardRoleText] = [],
        cycleTexts: [TransitCycleText] = []
    ) -> CardTextModel? {
        guard let selection else { return nil }
        let resolved = selection.basePath.map { resolve(base: $0) }
        let secondaryBody = resolved?.secondary
            ?? selection.secondaryPath.flatMap { resolve(base: $0).body }
        let headline = resolved?.headline
        let body = resolved?.body
        guard headline != nil || body != nil || secondaryBody != nil else { return nil }
        return CardTextModel(
            sectionLabel: nil,
            cardLabel: cardID,
            headline: headline,
            body: body,
            secondaryBody: secondaryBody,
            areaLabel: nil,
            statusLabel: nil,
            technicalLabel: nil,
            startLabel: nil,
            endLabel: nil,
            themeID: selection.themeID,
            sourceFactIDs: selection.sourceFactIDs,
            copyPackID: "\(pack.contentVersion):\(selection.basePath ?? selection.secondaryPath ?? cardID)",
            scopeID: scopeID,
            roleTexts: roleTexts.isEmpty ? nil : roleTexts,
            cycleTexts: cycleTexts.isEmpty ? nil : cycleTexts
        )
    }

    private func resolve(base: String) -> (headline: String?, body: String?, secondary: String?) {
        let headline = valueIfPresent(at: "\(base).headline") ?? valueIfPresent(at: "\(base).label")
        let body = valueIfPresent(at: "\(base).body") ?? valueIfPresent(at: base)
        let secondary = valueIfPresent(at: "\(base).guidance")
            ?? valueIfPresent(at: "\(base).secondary")
        return (headline, body, secondary)
    }

    private func transitCopySelection(
        plan: CardEvidencePlan,
        requests: [TransitCopyRequest]
    ) -> CopySelection? {
        guard let copySlot = plan.copySlot else { return nil }
        switch copySlot {
        case .integratedStory:
            guard let request = requests.first(where: {
                $0.copySlot == TransitCopySlot.integratedStory.rawValue
            }) else { return nil }
            return CopySelection(
                basePath: request.key,
                secondaryPath: nil,
                themeID: request.integratedThemeID,
                sourceFactIDs: request.sourceFactIDs
            )
        case .cycleChapter:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: $0.themeID, sourceFactIDs: $0.sourceFactIDs)
            }
        case .signalRole:
            return nil
        case .planetPathShort:
            guard let request = requests.first(where: { $0.key.hasPrefix("shared.bodyMotion.") }) else { return nil }
            return CopySelection(
                basePath: request.key,
                secondaryPath: requests.first(where: { $0.key.hasPrefix("shared.lifeAreas.") })?.key,
                themeID: nil,
                sourceFactIDs: request.sourceFactIDs
            )
        case .lifeAreaShort:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: nil, sourceFactIDs: $0.sourceFactIDs)
            }
        case .activeTransitShort:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: $0.themeID, sourceFactIDs: $0.sourceFactIDs)
            }
        }
    }

    private func transitThemeRequest(
        plan: CardEvidencePlan,
        slot: TransitCopySlot
    ) -> TransitCopyRequest? {
        guard let input = plan.themeInputs.first else { return nil }
        return transitThemeRequest(input: input, cardID: plan.cardID, slot: slot)
    }

    private func transitThemeRequest(
        input: TransitThemeInput,
        cardID: String,
        slot: TransitCopySlot
    ) -> TransitCopyRequest? {
        let mappedThemeID = ThemeMapper.themeID(
            for: input,
            rules: pack.themeRulesByPreset["modern"] ?? [],
            houseFallback: { house, tone in
                valueIfPresent(at: "shared.transit.houseFallback.\(house).\(tone)")
            }
        )
        guard let themeID = TransitThemeID(rawValue: mappedThemeID) else { return nil }
        let basePath: String
        switch slot {
        case .cycleChapter:
            basePath = "modern.transit.cycleChapter.\(input.roleID).\(themeID.rawValue)"
        case .activeTransitShort:
            basePath = "modern.transit.activeTransitShort.\(input.roleID).\(themeID.rawValue)"
        default:
            return nil
        }
        return TransitCopyRequest(
            key: basePath,
            cardID: cardID,
            copySlot: slot.rawValue,
            themeID: themeID.rawValue,
            integratedThemeID: nil,
            roleID: input.roleID,
            variables: [:],
            sourceFactIDs: input.sourceFactIDs
        )
    }

    private func renderedTransitVariables(_ variables: [String: String]) -> [String: String] {
        guard let language = AppLanguage(rawValue: pack.locale) else { return variables }
        var rendered = variables
        if let bodyID = variables["transitPlanet"] {
            rendered["transitPlanet"] = AstroTerms.value("bodies", bodyID, language: language)
        }
        if let houseIDs = variables["lifeAreas"] {
            let houses = houseIDs.split(separator: ",").compactMap { Int($0) }.map {
                AstroTerms.house($0, language: language)
            }
            let formatter = ListFormatter()
            formatter.locale = language.locale
            rendered["lifeAreas"] = formatter.string(from: houses) ?? houses.joined(separator: ", ")
        }
        return rendered
    }

    private func copySelection(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> CopySelection? {
        let signals = StandardSignalBuilder.build(snapshot: snapshot, aspects: aspects)
        let primaryAspect = aspects.max(by: { $0.strength < $1.strength })
            ?? snapshot.aspects.max(by: { $0.strength < $1.strength })
        let copyableAspect = (aspects + snapshot.aspects)
            .sorted { $0.strength > $1.strength }
            .first { aspect in
                guard let path = aspectCopyPath(aspect) else { return false }
                return hasEntry(under: path)
            }
        let aspectPath = copyableAspect.flatMap(aspectCopyPath)
        let aspectSignalIDs = copyableAspect.map { [$0.id] } ?? primaryAspect.map { [$0.id] } ?? []
        let moonSign = signKey(signals.moonSignIndex)
        let sunSign = signKey(signals.sunSignIndex)
        let ascSign = signKey(signals.ascendantSignIndex)
        let leadingHouse = leadingHouse(in: snapshot, aspects: aspects)
        let atmosphere = skyAtmosphere(snapshot)
        let themeRules = pack.themeRulesByPreset["modern"] ?? []

        switch chart {
        case .natal:
            let signature = temperament(snapshot)
            switch cardID {
            case "natal-interpretation":
                return pair("modern.natal.bigThree.\(signature.element).\(signature.mode)", sourceFactIDs: snapshot.points.prefix(3).map(\.id))
            case "element-balance":
                return pair("modern.natal.bigThree.\(signature.element).\(signature.mode)", sourceFactIDs: snapshot.points.prefix(3).map(\.id))
            case "emotional-needs":
                return pair("shared.natal.moonNeeds.\(moonSign)", sourceFactIDs: ["moon.sign"])
            case "love-connection":
                let venusSign = snapshot.point(.venus).map { signKey($0.signIndex) } ?? "aries"
                let base = "shared.natal.loveElementMatrix.\(element(for: venusSign)).\(element(for: moonSign))"
                return CopySelection(basePath: base, secondaryPath: "shared.natal.venusGives.\(venusSign)", themeID: nil, sourceFactIDs: ["venus.sign", "moon.sign"])
            case "career-direction":
                return pair("shared.natal.mcDirection.\(signKey(Int(snapshot.angles.midheavenDegrees / 30) % 12))", sourceFactIDs: ["mc.sign"])
            case "strengths-growth", "key-aspects":
                guard let aspectPath else { return nil }
                return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: aspectSignalIDs)
            case "house-emphasis":
                return pair("shared.lifeAreas.\(leadingHouse)", sourceFactIDs: ["house.\(leadingHouse)"])
            case "chart-signature":
                return pair("modern.rulership.chartRulerCopy.\(ruler(for: ascSign))", sourceFactIDs: ["ascendant.sign"])
            case "planet-placements":
                let sunPlacement = "modern.natal.placement.sun.\(sunSign)"
                let moonPlacement = "modern.natal.placement.moon.\(moonSign)"
                return CopySelection(basePath: sunPlacement, secondaryPath: moonPlacement, themeID: nil, sourceFactIDs: ["sun.sign", "moon.sign"])
            default:
                return nil
            }
        case .currentSky:
            switch cardID {
            case "moon-now":
                return pair("shared.lunarPhase.\(lunarPhaseKey(snapshot))", sourceFactIDs: ["moon.phase", "moon.sign"])
            case "planetary-motion":
                let point = snapshot.points.first(where: \.retrograde) ?? snapshot.points.first
                guard let point else { return nil }
                let state = point.retrograde ? "retrograde" : "direct"
                return pair("shared.bodyMotion.\(point.body.rawValue).\(state)", sourceFactIDs: [point.id])
            case "sign-changes":
                return pair("shared.signStyle.\(moonSign)", sourceFactIDs: ["moon.sign"])
            case "sky-overview", "aspect-pattern", "element-climate", "upcoming-7-days":
                return pair("shared.currentSky.skyAtmosphere.\(atmosphere)", sourceFactIDs: snapshot.aspects.prefix(3).map(\.id))
            default:
                return nil
            }
        case .transit:
            let themeID = ThemeMapper.themeID(
                for: primaryAspect,
                house: leadingHouse,
                rules: themeRules,
                houseFallback: { house, tone in valueIfPresent(at: "shared.transit.houseFallback.\(house).\(tone)") }
            )
            switch cardID {
            case "current-story", "current-cycles", "active-transits", "transit-timeline":
                let slot = cardID == "current-story" ? "chapter" : (cardID == "transit-timeline" ? "coming" : "active")
                return pair("shared.transit.themePacks.\(themeID).\(slot)", themeID: themeID, sourceFactIDs: aspectSignalIDs)
            case "planet-paths":
                guard let body = prominentMovingBody(in: snapshot) else { return nil }
                let state = body.retrograde ? "retrograde" : "direct"
                return CopySelection(
                    basePath: "shared.bodyMotion.\(body.id).\(state)",
                    secondaryPath: "shared.lifeAreas.\(leadingHouse)",
                    themeID: nil,
                    sourceFactIDs: [body.id]
                )
            case "life-areas":
                return pair("shared.lifeAreas.\(leadingHouse)", sourceFactIDs: ["house.\(leadingHouse)"])
            default:
                return nil
            }
        case .secondary:
            switch cardID {
            case "developmental-chapter":
                return pair("shared.secondary.progressedPhase.\(progressedPhaseKey(snapshot))", sourceFactIDs: ["progressed.phase"])
            case "progressed-moon":
                return pair("shared.natal.moonNeeds.\(moonSign)", sourceFactIDs: ["progressed.moon.sign"])
            case "identity-development":
                return pair("modern.secondary.progressedSun.\(sunSign)", sourceFactIDs: ["progressed.sun.sign"])
            case "areas-maturing":
                return pair("shared.maturingArea.\(leadingHouse)", sourceFactIDs: ["house.\(leadingHouse)"])
            case "turning-points":
                guard let aspectPath else { return nil }
                return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: aspectSignalIDs)
            case "timeline":
                return pair("shared.secondary.progressedPhase.\(progressedPhaseKey(snapshot))", sourceFactIDs: ["progressed.phase"])
            default:
                return nil
            }
        case .solarReturn:
            let ascSign = signKey(Int(snapshot.angles.ascendantDegrees / 30) % 12)
            switch cardID {
            case "year-theme":
                return pair("shared.solarReturn.solarAsc.\(ascSign)", sourceFactIDs: ["solar.ascendant.sign"])
            case "year-dynamics", "year-aspects":
                guard let aspectPath else { return nil }
                return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: aspectSignalIDs)
            case "year-anchors", "year-timeline":
                let quarter = currentQuarter(from: snapshot.utcDate)
                return pair("shared.solarReturn.solarQuarters.\(quarter)", sourceFactIDs: ["solar.quarter.\(quarter)"])
            case "priority-areas":
                return pair("shared.lifeAreas.\(leadingHouse)", sourceFactIDs: ["house.\(leadingHouse)"])
            case "natal-overlay":
                let angle = closestNatalOverlayAngle(solar: snapshot, natal: natal)
                return pair("shared.overlayAngles.\(angle)", sourceFactIDs: ["natal.angle.\(angle)"])
            default:
                return nil
            }
        case .synastry:
            let overview = synastryOverview(aspects)
            switch cardID {
            case "relationship-overview":
                return pair("shared.synastry.overview.\(overview)", sourceFactIDs: aspects.prefix(3).map(\.id))
            case "perspectives":
                return CopySelection(
                    basePath: "shared.synastryRoles.sun",
                    secondaryPath: "shared.synastryRoles.moon",
                    themeID: nil,
                    sourceFactIDs: aspects.prefix(3).map(\.id)
                )
            case "emotional-connection", "communication", "chemistry", "commitment", "key-inter-aspects":
                guard let aspectPath else { return nil }
                return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: aspectSignalIDs)
            case "house-overlays":
                return pair("shared.synastry.houseOverlay.\(leadingHouse)", sourceFactIDs: ["house.\(leadingHouse)"])
            default:
                return nil
            }
        }
    }

    private func pair(_ base: String, themeID: String? = nil, sourceFactIDs: [String]) -> CopySelection {
        CopySelection(basePath: base, secondaryPath: nil, themeID: themeID, sourceFactIDs: sourceFactIDs)
    }

    private func aspectCopyPath(_ aspect: ChartAspect) -> String? {
        let modernOrder = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]
        let order = modernOrder
        let allowed = Set(order)
        guard allowed.contains(aspect.firstID), allowed.contains(aspect.secondID) else { return nil }
        let pair = [aspect.firstID, aspect.secondID].sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
        let tone = aspect.kind.supportive ? "supportive" : (aspect.kind.challenging ? "challenging" : "neutral")
        return "modern.natal.aspectCopy.\(pair[0]).\(pair[1]).\(tone)"
    }

    private func hasEntry(under base: String) -> Bool {
        entriesByPath[base] != nil || entriesByPath.keys.contains { $0.hasPrefix(base + ".") }
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
    private func currentQuarter(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        if month <= 3 { return "1" }
        if month <= 6 { return "2" }
        if month <= 9 { return "3" }
        return "4"
    }

    private func normalizeDegrees(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(normalizeDegrees(a) - normalizeDegrees(b))
        return min(diff, 360 - diff)
    }

    private func closestNatalOverlayAngle(solar: ChartSnapshot, natal: ChartSnapshot?) -> String {
        guard let natal = natal else { return "ASC" }
        let solarLongitude = solar.point(.sun)?.longitudeDegrees ?? solar.angles.ascendantDegrees
        let asc = natal.angles.ascendantDegrees
        let mc = natal.angles.midheavenDegrees
        let dsc = (asc + 180).truncatingRemainder(dividingBy: 360)
        let ic = (mc + 180).truncatingRemainder(dividingBy: 360)
        let candidates = [("ASC", asc), ("DSC", dsc), ("MC", mc), ("IC", ic)]
        let closest = candidates.min { angularDistance(solarLongitude, $0.1) < angularDistance(solarLongitude, $1.1) }
        return closest?.0 ?? "ASC"
    }

    private func prominentMovingBody(in snapshot: ChartSnapshot) -> ChartPoint? {
        let moving: [CelestialBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        if let retro = snapshot.points.first(where: { moving.contains($0.body) && $0.retrograde }) { return retro }
        if let direct = snapshot.points.first(where: { moving.contains($0.body) }) { return direct }
        return snapshot.point(.sun) ?? snapshot.points.first
    }

}

/// Compatibility name for call sites while the v6 content pipeline migrates.
typealias CopyCatalogProvider = CopyCatalogMatcher

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
