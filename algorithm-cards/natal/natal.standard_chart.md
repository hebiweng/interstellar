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

## M3实现记录（2026-07-18）

- 回归黄道、地心本命盘已把M2天体位置与M3宫位、落宫、主要相位和描述性分布组合成Canonical Chart和不可变CalculationSnapshot；
- 每个子能力拥有独立OutputManifest、算法卡、数据版本、规则包哈希、输入指纹与降级状态；所选点投影不会改变底层星历事实；
- 高纬宫制不可用、显式Whole Sign降级、分布参与点不完整均形成`partial`快照，不会伪装成功；
- 恒星黄道、龙首盘、太阳/月亮盘、黄道对比和事件对象语义仍待后续阶段，因此本卡为`review/in_progress/experimental`。
