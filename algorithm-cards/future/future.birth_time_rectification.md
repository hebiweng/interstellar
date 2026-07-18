---
card_id: ALG-FUTURE-001
capability_id: future.birth_time_rectification
status: review
phase: post_v1
calculation_ids: []
result_contracts: [RectificationCandidateSet]
---

# 出生时间校正扩展契约

M24只保留插件契约，不承诺唯一答案。未来实现对用户给定时间区间采样候选盘，以已知事件对应的行运/推运/方向命中生成分项证据，输出候选区间、敏感参数和反证，不输出单一“正确时间”。评分规则、事件选择偏差和验证集必须单独版本化；未经盲测只可Experimental。
