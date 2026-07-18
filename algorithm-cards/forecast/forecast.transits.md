---
card_id: ALG-FORECAST-001
capability_id: forecast.transits
status: review
phase: alpha
calculation_ids: [forecast.transit.v1]
result_contracts: [ForecastResult]
---

# 行运

行运点按目标UTC实时计算，与固定本命点、宫头、Lots和中点分别建立AspectResult。区间搜索先根据最快选中对象与最窄容许度确定自适应粗扫步长，再对进入、精确、离开分别Brent求根。相位误差是圆周有符号函数，求根前必须解除0/360跳变。逆行产生的每次精确命中归入同一`activation_group_id`，但保留独立窗口。行运落宫使用本命宫头，不重算为目标地点宫位。默认短期Preset选Moon—Saturn，年度加入外行星；不按速度重复输出同一结论。测试含水星/火星逆行三击、跨0°、站点贴近精确相位、宫位进入和区间端点去重；慢行星精确时刻目标5分钟，个人行星60秒。
