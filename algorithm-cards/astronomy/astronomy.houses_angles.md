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
