import AstroCore

extension CopyCatalogMatcher {
    func synastryCopySelection(cardID: String, context: LegacyCopySelectionContext) -> CopySelection? {
        let overview = synastryOverview(context.aspects)
        switch cardID {
        case "relationship-overview":
            return pair("shared.synastry.overview.\(overview)", sourceFactIDs: context.aspects.prefix(3).map(\.id))
        case "perspectives":
            return CopySelection(
                basePath: "shared.synastryRoles.sun",
                secondaryPath: "shared.synastryRoles.moon",
                themeID: nil,
                sourceFactIDs: context.aspects.prefix(3).map(\.id)
            )
        case "emotional-connection", "communication", "chemistry", "commitment", "key-inter-aspects":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: context.aspectSignalIDs)
        case "house-overlays":
            return pair("shared.synastry.houseOverlay.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        default:
            return nil
        }
    }
}
