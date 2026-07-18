---
card_id: ALG-NATAL-003
capability_id: natal.patterns_distributions
status: review
phase: alpha
calculation_ids: [distribution.elements.v1, distribution.modalities.v1, distribution.polarity.v1, distribution.hemisphere.v1, pattern.jones.v1, pattern.geometry.v1]
result_contracts: [DistributionResult, PatternResult]
---

# 分布与格局

数量与权重分开返回。现代默认权重：Sun/Moon=2，Mercury—Saturn=1，外行星=1，ASC/MC=1；古典Preset只统计七曜且Sun/Moon=2。百分比以参与权重总和为分母，0分母为不可计算。半球按黄道宫位/轴定义并记录坐标方向。Jones形态用行星黄经最大空隙和聚类阈值判定，阈值来自Preset。几何格局从已命中的AspectResult构图，格局必须满足指定边集合；近似格局单独标记。不要把统计直接当人格分数。金标准包含边界黄经、相同度数、缺失时间、多个可同时成立格局和权重Preset切换。

## M3实现记录（2026-07-18）

- 已实现现代十体和古典七曜两个不可变Profile，分别返回元素、模式、阴阳的原始计数、加权值、百分比及缺失/过强阈值标志；
- 缺少Profile参与点时保留可计算的计数和权重，但百分比与阈值标志返回不可用，不用剩余点重新归一化；
- 返回Profile内容哈希、算法卡、参与点、缺失点、排除能力与解释边界；所有30°边界、重复/未知点、零分母均有测试；
- 半球、Jones形态和几何格局尚未实现且不得出现在M3结果，本卡继续为`review/in_progress/experimental`。
