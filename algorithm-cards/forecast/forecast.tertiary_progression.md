---
card_id: ALG-FORECAST-004
capability_id: forecast.tertiary_progression
status: review
phase: beta
calculation_ids: [progression.tertiary.v1, progression.minor_quartary.v1]
result_contracts: [ForecastResult, ChartResult]
---

# 三限、小限和四限推运

卡内只把换算钥匙明确且可复现的变体纳入可执行范围。`tertiary_synodic`定义为出生后1平均太阳日对应生命中1平均朔望月`29.530588861d`，因此`progressed_days = elapsed_life_days / 29.530588861`。`tertiary_sidereal`是显式非默认变体，使用恒星月`27.321661d`。`minor_synodic`定义为出生后1平均朔望月对应生命中1回归年`365.2421897d`，因此`progressed_days = elapsed_life_days * 29.530588861 / 365.2421897`。名为`Tertiary II`和`Quartary`的做法在文献与软件中命名不统一；V1在没有完成来源锁定、手算夹具与独立实现前返回`BLOCKED_RESEARCH_VARIANT`，不得猜测公式。每种方法使用独立`variant_id`、时间尺度和缓存键，禁止只写“tertiary”。目标时刻先换算elapsed TT days，再计算progressed TT；轴点默认不提供，除非另选明确方向法。所有变体保持Beta/Experimental，结果页面始终显示换算钥匙、来源和阻断状态。
