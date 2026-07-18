---
card_id: ALG-GEOGRAPHY-002
capability_id: geography.astrocartography
status: review
phase: pro
calculation_ids: [geography.astrocartography.v1]
result_contracts: [GeographyResult]
---

# Astrocartography

在出生UTC固定天体赤经赤纬。MC线由当地恒星时等于天体RA求经度，IC线相差180°；ASC/DSC线对每个采样纬度求解天体高度=0且上升/下降导数符号符合，使用球面天文公式与数值求根。接近极圈无解或多解时分段并标记。经度在日期变更线切断GeoJSON，不跨图直连。默认采样纬度0.25°，随后按屏幕误差自适应简化；导出保留原精度。角线交叉点通过大圆/折线空间索引求解并回代验证。与Swiss角事件和Astrodienst公开样例手工点差异，目标线位置`<=0.25°`经度或25km（取较宽者）。
