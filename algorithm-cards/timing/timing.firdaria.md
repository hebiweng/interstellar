---
card_id: ALG-TIMING-002
capability_id: timing.firdaria
status: review
phase: pro
calculation_ids: [timelord.firdaria.v1]
result_contracts: [ForecastResult]
---

# 法达

昼盘主周期顺序为Sun10→Venus8→Mercury13→Moon9→Saturn11→Jupiter12→Mars7→NorthNode3→SouthNode2；夜盘为Moon9→Saturn11→Jupiter12→Mars7→Sun10→Venus8→Mercury13→NorthNode3→SouthNode2，总长均为75年。主周期从出生TT开始，以回归年`365.2421897d`换算。七曜主周期的子周期从主周期主星开始，按七曜顺序循环并把该主周期平均分为7段；南北交点周期不再细分。不同文献的交点处理或顺序必须作为新Preset ID，不能静默替换。输出主/次主星、周期层级、起止TT/UTC、昼夜判定来源及Preset。测试完整75年覆盖无空洞/重叠、两段交点、昼夜首段、子周期闭合和边界瞬间。
