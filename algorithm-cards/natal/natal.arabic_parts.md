---
card_id: ALG-NATAL-005
capability_id: natal.arabic_parts
status: review
phase: beta
calculation_ids: [classical.lots.v1]
result_contracts: [LotResult]
---

# 阿拉伯点

统一公式为`normalize(A + B - C)`，A/B/C只能引用已计算点或宫头。Fortune昼盘=`ASC+Moon-Sun`、夜盘反转；Spirit昼盘=`ASC+Sun-Moon`、夜盘反转。Eros、Necessity及其他预置Lots按版本化公式表保存来源，是否昼夜反转逐条声明，禁止全局猜测。自定义公式先做类型、循环和缺失点校验。结果含公式、展开数值、昼夜状态、守护星和相位引用。无可靠出生时间时依赖ASC的Lots不可计算。边界测试覆盖0/360、昼夜交界、公式引用缺失和自定义循环。
