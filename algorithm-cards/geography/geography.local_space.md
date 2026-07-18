---
card_id: ALG-GEOGRAPHY-003
capability_id: geography.local_space
status: review
phase: pro
calculation_ids: [coordinate.local_space.v1, geography.local_space.v1]
result_contracts: [GeographyResult, CelestialPosition]
---

# Local Space

用指定时刻地点的拓扑地平坐标，方位角从真北顺时针。每个对象从中心沿初始方位生成WGS84大圆线；相反方向单独标记，不把地下天体自动翻转到对面。真北/磁北必须分开，V1默认真北，不依赖地磁模型。地图缩放时按大圆重新投影，不在Web Mercator直线外推。测试四方位基准、极点、日期线、中心点移动和地平坐标回代。
