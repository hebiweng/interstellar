---
card_id: ALG-PLATFORM-003
capability_id: platform.analysis_model_registry
status: review
phase: foundation
calculation_ids: []
result_contracts: [AnalysisModel, AnalysisModelVersion]
---

# AnalysisModel注册表

模型源文件使用YAML，进入运行时前按Schema校验、展开默认值、键排序并采用RFC 8785 JCS生成SHA-256内容哈希。`id + semver`不可变；核心组件、默认规则或结果语义变化至少提升Minor，删除/改名公共字段提升Major。模型只引用稳定Capability/Calculation/View/RulePack ID，不嵌入算法代码。启动时未知引用、循环extends、阶段倒挂或输出不可达必须失败。目录排序和翻译不进入算法内容哈希；计算相关文案和证据语义进入哈希。测试覆盖12个内置模型、旧版本复现、升级不覆盖以及自定义模型资源预算。

## M4实现与验证

- 运行时目录位于`python/interstellar_core/analysis/registries`，内置数量固定为12个基础模型、24个专题模型和35个分析目的；
- 所有引用在加载时完成交叉校验，阶段不可用能力保留在目录中并返回明确可用性，不伪装为可执行；
- API目录只读取同一注册表，不维护第二份手工计数；
- M4状态为`Experimental`：目录完整性和引用规则已验证，但模型内的占星语义仍须在各自阶段通过专业评审后才能提升成熟度。
