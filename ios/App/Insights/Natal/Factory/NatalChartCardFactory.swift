enum NatalChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        try InsightCardAssembler.assemble(NatalLegacyCardFactory.make(context), context: context)
    }
}
