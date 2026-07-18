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

## M2实现记录（2026-07-18）

- `pysweph==2.10.3.6`适配器已实现太阳、月亮及八颗主要行星的黄道/赤道位置、距离、速度、运动状态、JD UT、JD TT和Delta-T；
- 当前仓库未随附Swiss星历文件，真实烟测会显式回退Moshier并逐天体输出`EPHEMERIS_FALLBACK_MOSHIER`，不会静默声称使用Swiss文件；
- IAU SOFA公开常量夹具和差异报告框架已通过；JPL DE442位置夹具与SPICE内核仍缺失，因此本卡保持`review/implemented`和`experimental`，不得升级Stable；
- 宫位、轴点、相位、站点求根、特殊月相标签和行星时不属于M2已实现范围，分别由后续能力卡接续。
