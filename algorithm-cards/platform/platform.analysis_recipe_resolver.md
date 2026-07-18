---
card_id: ALG-PLATFORM-004
capability_id: platform.analysis_recipe_resolver
status: review
phase: foundation
calculation_ids: []
result_contracts: [AnalysisDraft, AnalysisRecipe, OutputManifest]
---

# AnalysisRecipe解析器

解析顺序固定为：入口预填→对象角色校验→模型/目的展开→必需依赖传递闭包→推荐默认→用户允许覆盖→可选扩展→兼容性与许可→时间精度降级→输出可达性→资源预算→拓扑排序。必需节点锁定；推荐节点可替换；可选节点显式选择；阻断节点不执行。DAG使用Kahn拓扑排序，同一语义缓存键合并节点。Recipe包含所有默认、版本、数据集、规则哈希、降级和成本估计并按JCS哈希；确认后不可变且默认15分钟过期。解析器不得调用星历。测试覆盖六类入口等价性、循环、未知ID、可复用快照、部分输出、许可阻断与预算溢出。
