---
card_id: ALG-FUTURE-003
capability_id: future.non_western_plugins
status: review
phase: post_v1
calculation_ids: []
result_contracts: [PluginManifest, PluginSnapshot]
---

# 非西方占术插件扩展契约

八字、紫微、奇门与印度占星使用各自强类型Schema、算法卡、数据版本和视图命名空间，不复用西方占星House/Aspect语义。仅共享Subject、TimeSpec、Location、Job、Evidence、ReportDocument、Artifact和版本协议。插件不得向核心Schema注入未命名字段，跨体系综合必须显式新模型。M24只定义接口，不实现算法。
