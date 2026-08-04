enum SecondaryChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        try InsightCardAssembler.assemble(SecondaryLegacyCardFactory.make(context), context: context)
    }
}
