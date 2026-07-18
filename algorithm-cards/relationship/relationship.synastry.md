---
card_id: ALG-RELATIONSHIP-001
capability_id: relationship.synastry
status: review
phase: alpha
calculation_ids: [relationship.synastry.v1]
result_contracts: [RelationshipResult]
---

# 比较盘

分别保留A、B各自本命设置和对象版本。跨盘相位生成有向记录`source=A,target=B`，角距本身对称但宫位覆盖、宫主触发和体验角色不对称。A点落B宫使用B的宫头，反向另算；时间不足时仅保留不依赖宫位的相位并降级。默认主要相位与关系OrbProfile，不输出单一匹配分。主题维度为吸引、情绪安全、沟通、亲密、承诺、权力、自由、边界、共同方向，每条维度只能由Rule Pack映射Evidence。测试交换A/B后对称相位集合相同而方向字段翻转、跨0°、不同宫制和未知时间。
