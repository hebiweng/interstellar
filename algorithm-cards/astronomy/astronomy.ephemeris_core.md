---
card_id: ALG-ASTRONOMY-001
capability_id: astronomy.ephemeris_core
status: review
phase: alpha
calculation_ids: [time.scales.v1, time.julian.v1, astronomy.position.v1, coordinate.geocentric.v1, moon.phase.v1, moon.special_labels.v1, planetary.hours.v1]
result_contracts: [AstronomicalContext, CelestialPosition, LunarPhaseResult, PlanetaryHourResult]
---

# 星历核心

## 实现

- 使用pyswisseph固定版本和本地星历目录；默认`FLG_SWIEPH|FLG_SPEED`，地心、视位置、回归黄道。真位置、日心、恒星黄道和拓扑中心必须以独立参数请求。
- 当地时间先由TimeSpec解析为UTC；`swe_julday`生成UT JD，Delta T生成ET/JDE。保存调用标志、返回标志、内核与文件哈希。
- 运动状态以黄经速度符号判断；停滞阈值不硬编码，由对象类别Preset定义，并以站点求根校验。
- 月相为规范化日月黄经差，照明比例采用`(1-cos(elongation))/2`；特殊“蓝月/黑月”只作为日历标签并声明采用的月界定义。
- 行星时按当地日出到日落和日落到次日日出各分12段；极昼/极夜返回不可计算。

## 验证

主要行星对JPL SPICE按同一参考系差异验证；Alpha容差太阳/行星`1 arcsec`、月亮`3 arcsec`、速度`1e-5°/day`。超出只阻断Stable，不用舍入掩盖。
