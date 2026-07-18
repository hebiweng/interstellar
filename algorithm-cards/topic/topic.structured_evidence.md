---
card_id: ALG-TOPIC-001
capability_id: topic.structured_evidence
status: review
phase: pro
calculation_ids: []
result_contracts: [Evidence, TopicScore]
---

# 结构化主题证据

主题模型按版本化selector读取Canonical事实并生成Evidence，不重新算星历。每条Evidence含主题/子主题、极性、配置、时间窗、规则、权重、成熟度和Snapshot路径。`activity`按命中强度与时间精确度聚合；`support`和`pressure`分别聚合且不相减；`confidence`由独立技法数、时间质量、证据一致性和成熟度计算，绝不解释为现实概率。重复配置按语义键去重，多技法印证只增加confidence上限。反证单独返回。主题房宫/宫主/自然象征星映射以`rules/official`为唯一来源。测试无证据、互相矛盾、同源重复、时间质量降级和权重版本升级。
