---
card_id: ALG-RELATIONSHIP-004
capability_id: relationship.dynamic_forecast
status: review
phase: v1
calculation_ids: [relationship.dynamic.v1, relationship.event_charts.v1]
result_contracts: [RelationshipResult, ForecastResult]
---

# 动态关系预测

动态关系是Recipe编排：A行运→B本命、B行运→A本命、双方推运比较、行运→组合、行运→Davison及可选关系事件盘。每条命中保存source chart、target chart、方向和对象角色；同一时间窗只在主题层聚合，不合并原始相位。只有双方时间都满足技法门槛才运行精确动态关系；否则按组件降级。初见、承诺、婚姻等事件必须由用户提供来源，不从报告反推。测试组件结果等于单独运行、DAG去重、A/B方向和部分失败OutputManifest。
