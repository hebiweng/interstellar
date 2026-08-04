enum SolarReturnChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        try InsightCardAssembler.assemble(SolarReturnLegacyCardFactory.make(context), context: context)
    }
}
