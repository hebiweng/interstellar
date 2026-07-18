---
card_id: ALG-RENDER-001
capability_id: rendering.wheels
status: review
phase: alpha
calculation_ids: []
result_contracts: [RenderSpec, RenderArtifact]
---

# 轮盘渲染

轮盘坐标以ASC置于左侧（180°屏幕角）为默认，转换`screen_angle=180-(longitude-asc_longitude)`；无ASC盘以0°白羊点置左并明确标识。环半径比例由RenderTheme定义，SVG viewBox为1000×1000。行星标签先按黄经排序，再用受限迭代沿环避碰；真实黄经刻度线不移动，标签位移用引线。相位线只消费AspectResult。双/三/四轮共享同一角基准，各层独立点集和图例。导出嵌入许可字体，所有颜色有非颜色编码。视觉金标准固定视口差异阈值0.1%，几何点误差1 CSS px。
