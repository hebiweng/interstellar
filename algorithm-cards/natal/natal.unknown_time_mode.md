---
card_id: ALG-NATAL-002
capability_id: natal.unknown_time_mode
status: review
phase: alpha
calculation_ids: [time.quality.v1]
result_contracts: [TimeQualityResult]
---

# 未知出生时间模式

未知时间绝不创建虚假单盘。仅日期时计算UTC日界内候选区间：慢速点给区间，月亮等可能跨星座的点给候选，宫位、轴点、Vertex、Paran、精确落宫和依赖它们的模型标记`not_computable`。部分时段输入按15分钟或Recipe指定步长采样，合并在全区间恒定的结果并列出变化点。时间质量A=官方分钟、B=约15分钟、C=约1小时、D=时段/仅日期、E=未知/冲突；来源可降低但不能提高质量。测试确保不出现00:00默认值，受阻视图仍可发现且说明原因。
