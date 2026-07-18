---
card_id: ALG-FORECAST-003
capability_id: forecast.secondary_progression
status: review
phase: beta
calculation_ids: [progression.secondary.v1, progression.cross.v1]
result_contracts: [ForecastResult, ChartResult]
---

# 次限推运

默认Mean Solar Day for a Tropical Year：`age_years=(target_tt-birth_tt)/365.2421897`，`progressed_tt=birth_tt+age_years days`。真太阳生日比例作为显式`true_solar`变体，不能与默认混算。推运行星按progressed TT星历位置；推运月相由推运日月角距计算。推运轴点默认采用Solar Arc in Right Ascension/Naibod两种独立Preset，结果标记方法；不把出生地当地钟表日期重新解释为时区。推运对本命、推运对推运和行运对推运分别生成上下文。测试年龄0恒等、闰年无跳变、推运月亮月相、逆行和两种轴法差异；行星位置容差2 arcsec。
