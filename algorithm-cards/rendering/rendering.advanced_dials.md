---
card_id: ALG-RENDER-004
capability_id: rendering.advanced_dials
status: review
phase: v1
calculation_ids: []
result_contracts: [RenderSpec, RenderArtifact]
---

# 高级刻度盘与网络图

22.5/45/90/360°盘只显示MidpointResult提供的模数位置；渲染层不重算中点。刻度密度按模数和视口确定，指针保留原对象ID。定位星链、宫主链和相位网络使用稳定有向图布局种子；边方向、类型和权重有图例，导出包含邻接表。3D赤纬图只是坐标可视化，不暗示物理距离。复杂图必须提供表格替代。视觉测试固定布局种子、字体和数据夹具，节点重叠率为0。
