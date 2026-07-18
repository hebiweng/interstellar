---
card_id: ALG-ASTRONOMY-003
capability_id: astronomy.houses_angles
status: review
phase: alpha
calculation_ids: [angles.primary.v1, angles.sensitive.v1, houses.systems.v1, houses.results.v1, houses.derived.v1, houses.polar.v1]
result_contracts: [HouseSet, DerivedHouseResult]
---

# 宫位与轴点

主轴和Swiss支持宫制通过`swe_houses_ex2`计算；Whole Sign和明确缺失的派生宫制由自研纯函数实现。默认现代Preset为Placidus，古典/希腊化为Whole Sign。宫制代码、算法来源和极区状态进入结果。天体落宫采用沿黄道前闭后开区间；恰在宫头`1e-9°`内标为`on_cusp`并归入下一宫。高纬无法计算时返回`HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE`，只在Recipe已允许时降级为Whole Sign/Equal，不自动替换。衍生宫位以模12索引并保存起始宫。ASC/MC与Swiss官方测试、Astrodienst/第二独立实现做差异，角度容差`2 arcsec`，宫头`5 arcsec`。

## M3实现记录（2026-07-18）

- `HouseCalculator`已适配Placidus、Koch、Porphyry、Regiomontanus、Campanus、Equal、Alcabitius、Topocentric、Morinus、Krusinski和Vehlow，并自研Whole Sign宫头；
- 返回ASC/DSC/MC/IC、八个Swiss敏感点、12宫、宫头速度、天体落宫、宫头命中标志和衍生宫位；
- 高纬失败默认`unavailable`，只在请求显式设置`allow_house_fallback_whole_sign=true`时降级，requested/actual system和警告进入快照；
- 真实J2000上海烟测、0°跨界、前闭后开和高纬策略已测试。本卡实现完成但仍保持`review/experimental`，待独立引擎差异样本后才能升级Stable。
