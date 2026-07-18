---
card_id: ALG-RENDER-003
capability_id: rendering.maps
status: review
phase: pro
calculation_ids: []
result_contracts: [RenderSpec, RenderArtifact]
---

# 地图渲染

运行结果使用WGS84 GeoJSON；交互默认Web Mercator，极区视图自动切换等距/方位投影，静态全球图用Natural Earth Robinson。日期变更线几何必须预切分。底图与计算线分层，计算线不依赖瓦片供应商。图例显示对象、角、成熟度、线误差和数据署名；颜色同时配线型。城市比较点不使用无依据红绿等级。PNG/PDF由同一RenderSpec和固定字体生成。测试投影往返、日期线、极区、无底图降级、许可证署名和视觉回归。
