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
