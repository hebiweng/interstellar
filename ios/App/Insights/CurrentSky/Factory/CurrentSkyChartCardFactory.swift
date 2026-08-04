enum CurrentSkyChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        try InsightCardAssembler.assemble(CurrentSkyLegacyCardFactory.make(context), context: context)
    }
}
