---
card_id: ALG-NATAL-006
capability_id: natal.midpoints
status: review
phase: beta
calculation_ids: [midpoint.direct_indirect.v1, uranian.dials.v1, uranian.tnp.v1]
result_contracts: [MidpointResult, ChartPoint]
---

# 中点与乌拉诺刻度盘

两黄经直接中点采用最短弧；相差180°时返回两个等价候选并要求策略。间接中点为直接中点+180°。模数盘位置为`longitude mod modulus`，支持360/90/45/22.5。中点树只列入指定容许度内被第三点触发的轴，默认中点容许度1°、事件触发0.5°，由Preset覆盖。TNP只作为版本化假想点公式，必须标记非真实天体和Experimental。测试覆盖0/360、对冲歧义、点交换对称、模数往返和同名轴去重。
