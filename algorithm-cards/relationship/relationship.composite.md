---
card_id: ALG-RELATIONSHIP-002
capability_id: relationship.composite
status: review
phase: alpha
calculation_ids: [relationship.composite.v1]
result_contracts: [RelationshipResult, ChartResult]
---

# 组合盘

对应点采用最短弧中点；精确对冲返回两个候选，默认用双方太阳中点所确定的整体半圆一致性策略，并记录选择。节点和轴点按各自圆周中点。组合MC先取MC中点，组合ASC默认由中点MC与参考纬度重建；直接ASC中点作为独立变体。参考纬度默认双方球面地理中点，地点变化需新快照。组合盘不是实际时刻星历，不标记行星速度/逆行。测试A/B交换恒等、对冲歧义、轴重建和中点数值。
