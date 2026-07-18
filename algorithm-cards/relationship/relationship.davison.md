---
card_id: ALG-RELATIONSHIP-003
capability_id: relationship.davison
status: review
phase: beta
calculation_ids: [relationship.davison.v1]
result_contracts: [RelationshipResult, ChartResult]
---

# Davison关系盘

时间中点在两个UTC/TT时刻的连续时间尺度上取算术平均；地点中点将双方WGS84坐标转单位球面向量求和归一化，反足点导致向量近零时返回歧义并要求参考地点。用时间/空间中点计算真实星盘。`corrected_mc`变体保持时间中点行星位置并旋转地方恒星时使MC符合参考策略；未校正版不得混用。参考地Davison只改变宫位/轴点。测试A/B交换、跨日期变更线、反足点、时间跨历法和与独立实现差异。
