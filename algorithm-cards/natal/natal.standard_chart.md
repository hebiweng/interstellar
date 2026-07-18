---
card_id: ALG-NATAL-001
capability_id: natal.standard_chart
status: review
phase: alpha
calculation_ids: [zodiac.tropical.v1, zodiac.sidereal.v1, chart.draconic.v1, chart.solar_lunar.v1, chart.zodiac_comparison.v1, event.chart.v1]
result_contracts: [ChartResult, ChartComparisonResult]
---

# 标准星盘组合

标准盘不是第二套星历算法，而是把同一规范化时空下的AstronomicalContext、Points、HouseSet、Aspects和派生统计组合成ChartResult。回归黄道默认；恒星黄道必须记录Ayanamsa ID/值。龙首盘以真北交点黄经平移到0°并对所有点同样平移，宫位策略由Preset声明。太阳/月亮盘以对应发光体所在星座0°或实际度数作为第一宫起点，变体必须不同ID。Chart哈希包含全部子结果哈希；任何子节点失败进入OutputManifest。测试验证组合不改变底层点值、变体可复现和事件盘/本命盘仅对象语义不同。
