---
card_id: ALG-ASTRONOMY-005
capability_id: astronomy.fixed_stars
status: review
phase: beta
calculation_ids: [fixed_star.position.v1, fixed_star.contact.v1]
result_contracts: [CelestialPosition, FixedStarContactResult]
---

# 固定星

默认星表为经人工选择的亮星子集，天文字段来自Gaia DR3/SIMBAD交叉标识；保存历元、赤经赤纬、自行、视差、径向速度和来源。目标时刻先传播自行，再做岁差章动和坐标转换。黄经合相默认只计算合相，不自动加入其他相位；默认容许度1°，与ASC/MC为1°，用户可覆盖。Paran不属于黄经合相，由独立Paran卡处理。传统性质和解释不写入天文结果，只由带文献来源的Rule Pack消费。位置与Swiss固定星接口/ERFA差异验证，亮星目标`<2 arcsec`。
