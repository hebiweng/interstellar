---
card_id: ALG-REPORT-001
capability_id: reporting.structured_report_engine
status: review
phase: beta
calculation_ids: []
result_contracts: [RawFact, Evidence, Finding, Conclusion, ReportSection, ReportDocument]
---

# 结构化报告引擎

流水线固定为Snapshot→EvidenceSelector→ThemeMapper→FindingRule→语义去重→冲突规则→优先级→Conclusion→Section→ReportDocument。任何层只引用前一层ID，禁止模板读取未声明原始路径。Finding最小单元含statement_key、参数、支持/压力/反证、适用时间和限制；Conclusion至少引用一个Finding。摘要/标准/技术版仅过滤同一ReportDocument，不重新计算。排序按章节、优先级、confidence、稳定ID。无翻译模板时回退结构化字段，不让模型自由生成。测试引用完整性、去重、密度子集、双语参数转义、缺节和版本复现。
