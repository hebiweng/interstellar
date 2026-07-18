---
card_id: ALG-ASTRONOMY-007
capability_id: astronomy.eclipse_events
status: review
phase: v1
calculation_ids: [astronomy.eclipse.v1]
result_contracts: [EclipseResult]
---

# 日月食

日食和月食使用Swiss全局搜索与地点搜索接口，结果保存类型、接触时刻、最大食、食分、沙罗号（有来源时）、可见区域和Delta T模型。地理路径由接触几何采样后生成GeoJSON，跨日期变更线分段。搜索采用UTC半开区间`[start,end)`避免重复。古代结果必须显示Delta T不确定性，不把秒级表示当作秒级可信度。NASA Five Millennium目录作为验证集，不作为运行时计算源；现代事件最大食时刻目标误差`<=60秒`，路径中心线在同Delta T下目标`<=10km`。
