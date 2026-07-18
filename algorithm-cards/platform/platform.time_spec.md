---
card_id: ALG-PLATFORM-001
capability_id: platform.time_spec
status: review
phase: foundation
calculation_ids: [time.input.v1, time.timezone.v1]
result_contracts: [TimeSpec, TimeNormalization]
---

# TimeSpec与历史时区

## 决策

- 默认历法为公历；1582年前不静默切换儒略历，用户必须显式选择`gregorian`、`julian`或`historical_region`。
- 时区规则使用仓库锁定的IANA tzdb；运行时禁止依赖宿主机未锁版本。
- 当地时间通过时区规则枚举UTC候选：正常时间1个、DST重叠2个、DST空洞0个。重叠必须选择或分支计算；空洞返回`TIME_NONEXISTENT_LOCAL`。
- `unknown`、仅日期和时间区间保留原精度，不补午夜。地方平太阳时为`UTC + longitude/15h`；真太阳时在其上加当日均时差并记录模型。
- 时间质量A/B/C/D/E只表达输入可靠程度，不修改时间值。

## 边界与测试

- 覆盖上海1986—1991夏令时、纽约DST重叠/空洞、国际日期变更线、负年份、儒略/公历转换和1970年前低可信度。
- UTC往返在非歧义时间必须恒等；候选必须按UTC升序且不可重复。
- 参考：IANA tzdb theory、ISO 8601、Swiss Ephemeris时间说明。允许误差：时间转换0秒；历史不确定性通过候选和警告表达。
