---
card_id: ALG-PLATFORM-002
capability_id: platform.location
status: review
phase: foundation
calculation_ids: [location.normalized.v1]
result_contracts: [Location]
---

# 地点与时区边界

## 决策

- 坐标统一WGS84，纬度`[-90,90]`、经度`[-180,180)`；GeoNames实体ID作为可选外键，用户输入原文始终保留。
- 地名搜索顺序：本地GeoNames规范名→别名→行政区消歧；不调用公共Nominatim作为生产依赖。
- 时区通过Timezone Boundary Builder多边形做PostGIS `ST_Covers`；边界多命中时返回全部候选并按最小多边形、行政匹配排序，不静默任选。
- 海域或无覆盖区域允许用户选择IANA时区或固定UTC偏移；固定偏移不得伪装成历史时区。
- 海拔未知为`not_requested`，不得写0；一般盘不因缺海拔阻断，拓扑/地平计算标记降级。

## 验证

测试同名城市、边界点、跨日期变更线、南北极、海上坐标和旧地名。坐标持久化精度至少`1e-6°`，空间匹配不得改变用户坐标。
