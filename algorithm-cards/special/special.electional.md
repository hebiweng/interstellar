---
card_id: ALG-SPECIAL-002
capability_id: special.electional
status: review
phase: pro
calculation_ids: [electional.search.v1]
result_contracts: [ElectionalResult]
---

# 择时约束优化

输入分硬约束、必要条件、加分条件和日历约束。先用事件搜索生成状态改变边界，将时间范围分为状态稳定区间；每区间选择边界内代表点验证，候选峰值再求精确相位/轴点。硬约束不满足即拒绝并保存原因；软条件分别返回支持/压力，不汇总成不透明“成功率”。默认预置包含Moon空亡、Moon下一相位、ASC及其主星、目标宫主、燃烧/逆行/食相、吉凶星角宫和工作时段，具体启用由场景Preset决定。候选按硬约束通过→支持权重→压力权重→时间升序稳定排序。测试短窗口无解、多地点、DST、取消和每条拒绝证据。
