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

## M4实现与验证

- 六类入口保留各自`entry_point_id`与预填上下文，最终进入同一个确定性解析器；
- 解析器输出去重后的节点DAG、阻断原因、重用计划、输出清单、警告与资源预算；
- 浏览器只提交目录ID和入口上下文，服务端返回 Recipe 后才允许确认；HTML或非JSON响应被前端明确拒绝；
- M4确认接口创建真实Job并返回`202`，不使用定时器伪造计算完成；
- M4状态为`Experimental`：Recipe与Job链路已验证，真实对象输入、可编辑参数、可选输出和持久化队列分别在M5—M6接通。
