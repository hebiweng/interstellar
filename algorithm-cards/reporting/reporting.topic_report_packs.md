---
card_id: ALG-REPORT-002
capability_id: reporting.topic_report_packs
status: review
phase: pro
calculation_ids: []
result_contracts: [ReportRulePack, Finding, Conclusion]
---

# 专题报告规则包

24个TopicModel各有独立ReportRulePack；规则包声明可用Evidence主题、章节、收录阈值、互斥/并列、反证处理和模板键。任何未通过规则命中的计算只进入技术附录。默认Finding收录：至少1条核心证据，或2条独立辅助证据；confidence低于0.35只显示限制，不生成肯定Conclusion。心理/职业/关系等报告使用倾向和模式语言；财务、健康、法律、项目均禁止确定性指令。报告规则版本变化生成新ReportDocument。测试每个包至少一个完整、降级、无证据、反证和旧版本复现样本。
