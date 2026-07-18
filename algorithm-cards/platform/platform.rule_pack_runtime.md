---
card_id: ALG-PLATFORM-005
capability_id: platform.rule_pack_runtime
status: review
phase: beta
calculation_ids: []
result_contracts: [RulePack, Evidence]
---

# Rule Pack运行时

规则包为受Schema约束的JSON/YAML声明，不支持脚本、正则回溯、网络、文件、系统时间或随机数。表达式只允许类型化路径读取、比较、集合、布尔、区间和有限聚合；数字比较必须显式单位。执行顺序按`priority`降序、规则ID升序；相同Evidence ID去重，极性不互相抵消。默认预算：每包2000规则、表达式深度32、集合10000项、单次100ms；超过返回`RULE_BUDGET_EXCEEDED`。继承只允许单向无环，子包覆盖必须显式`replaces`。规则命中保存输入快照路径、规则版本、权重和模板键。测试覆盖类型错误、循环、注入、资源耗尽、确定性和版本复现。
