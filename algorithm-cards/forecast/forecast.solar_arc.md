---
card_id: ALG-FORECAST-005
capability_id: forecast.solar_arc
status: review
phase: beta
calculation_ids: [direction.solar_arc.v1, direction.other_arcs.v1]
result_contracts: [ForecastResult, ChartResult]
---

# 太阳弧与其他弧向

默认真太阳弧为同一目标日期次限太阳黄经减本命太阳黄经的有符号顺行弧，规范化后加到所有本命点；平均Naibod弧`0°59′08.33″ × age_years`作为独立变体。方向点保留本命纬度/赤纬策略；黄经弧默认只移动黄经。月亮弧、ASC弧、Vertex弧和自定义弧必须各自声明source point与时间钥匙。命中以弧向点对本命点相位搜索，默认容许度1°并由Preset覆盖。测试年龄0、跨0°、真/平均弧分离和全部点同弧不变量。
