---
card_id: ALG-RENDER-002
capability_id: rendering.timelines_ephemeris
status: review
phase: beta
calculation_ids: []
result_contracts: [RenderSpec, RenderArtifact]
---

# 时间线与图形星历

时间轴内部统一UTC毫秒，显示层按用户时区格式化。窗口条使用进入/结束，精确点单独绘制；重复命中同组同轨。图形星历使用计算结果采样点并在0/360处断线，不在渲染层插值求天文事件。Canvas/WebGL用于高密度交互，SVG用于打印简化版，二者读取同一LayoutModel。缩放只请求更高分辨率数据，不把低分辨率曲线伪装精确。无障碍替代为同序事件表。测试DST标签、日期线、十年范围抽样、取消后的部分数据和像素回归。
