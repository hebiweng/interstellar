---
card_id: ALG-SPECIAL-001
capability_id: special.horary
status: review
phase: pro
calculation_ids: [horary.judgement.v1]
result_contracts: [HoraryResult]
---

# 卜卦判定

默认Lilly/传统七曜Preset：提问时刻与地点起盘；提问者为ASC主星和Moon，事项宫由用户选分类/派生宫并允许人工修正。早晚度、Moon空亡、Saturn七宫等作为considerations before judgement警告，不自动判盘无效。完成判断按象征星入相、接纳、禁止、挫败、返回、光线传递/收集的有序规则；规则命中保留双方速度、相位完成时间和中断原因。时间单位根据角/续/果宫与基本/固定/变动组合从候选单位表输出范围，不伪装精确日期。问题文本不由AI自动选宫。测试用公开领域Lilly案例、反例、转宫、禁止和多重接纳；报告必须展示证据链和规则版本。
