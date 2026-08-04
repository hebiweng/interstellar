enum SynastryChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        try InsightCardAssembler.assemble(SynastryLegacyCardFactory.make(context), context: context)
    }
}
