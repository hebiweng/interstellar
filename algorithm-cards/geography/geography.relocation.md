---
card_id: ALG-GEOGRAPHY-001
capability_id: geography.relocation
status: review
phase: pro
calculation_ids: [geography.relocation.v1, geography.city_compare.v1, geography.travel.v1]
result_contracts: [GeographyResult, ChartResult]
---

# 迁移盘与城市比较

迁移盘保持原事件UTC和天体地心位置，仅替换Location并重算地方恒星时、ASC/MC、宫头、地平坐标和宫位落点。不得把出生当地钟表时间复制到新时区。城市比较对同一Snapshot和同一宫制运行迁移盘，按结构化差异输出轴点、落宫和角线距离，不使用单一好坏排名；主题排序只能由明确Rule Pack完成。高纬降级遵循宫位卡。测试同经度不同纬度、同纬度不同经度、跨日期线和原地点迁移恒等。
