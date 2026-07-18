---
card_id: ALG-TIMING-001
capability_id: timing.annual_profections
status: review
phase: pro
calculation_ids: [timelord.profection.v1, timelord.decennials.v1, timelord.planetary_periods.v1, timelord.return_lord.v1]
result_contracts: [ForecastResult]
---

# 年度小限与年度主星

年度Whole Sign小限以已经完成的周岁`age`计算激活宫=`(age mod 12)+1`。V1默认周期边界为出生地历法与时区中的民用生日周年；精确太阳回归同步属于独立`solar_return_synchronized`变体，不能替换默认生日边界或共享缓存键。月小限把当前周年区间按12个等长时间段切分，日小限再按12段切分；每段保留起止UTC、当地显示时间和所用边界变体。年主星取激活整宫的传统守护星，现代守护只作为并列附加值。十年主星、七曜年限和返照主星必须使用独立variant表，不与小限权重相加。出生时间未知但出生日期可靠时，只能输出从第一宫开始的序号周期；由于ASC未知，不输出实际激活星座、宫主或主题证据。测试年龄0/11/12、生日瞬间前后、2月29日周年政策、DST边界和昼夜守护差异。
