---
card_id: ALG-GEOGRAPHY-004
capability_id: geography.parans
status: review
phase: pro
calculation_ids: [geography.paran.v1]
result_contracts: [GeographyResult]
---

# Paran

Paran定义为同一地点同一恒星日内两个对象分别处于rise/set/MC/IC角事件的时间差不超过阈值。升落采用含视半径/折射的高度阈值并由对象类型Preset声明；MC/IC用时角。对每个纬度求所有角事件UTC，按阈值默认4分钟配对并保存实际差。无升落的拱极对象只保留可发生角事件。Paran地图寻找配对时间差为0的纬度根并生成纬线/曲线段。固定星先传播自行。测试拱极、多个日事件、阈值边界和与Swiss rise_trans结果差异，事件时刻目标60秒。
