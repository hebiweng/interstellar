---
card_id: ALG-ASTRONOMY-006
capability_id: astronomy.minor_bodies
status: review
phase: beta
calculation_ids: [astronomy.position.v1]
result_contracts: [CelestialPosition]
---

# 小行星与半人马体

V1预装Chiron、Ceres、Pallas、Juno、Vesta、Pholus、Nessus、Eris、Sedna、Makemake、Haumea、Eros、Psyche。优先使用锁版本Swiss文件；长尾MPC对象按编号缓存轨道根数并记录历元、协方差/不确定度（可得时）和获取时间。轨道不确定或超出有效传播区间标记Experimental，不能与主要行星同成熟度。不存在文件返回`BODY_DATA_UNAVAILABLE`而非零坐标。对常用对象与JPL Horizons/MPC同历元差异验证；允许误差由对象不确定度上限决定并随结果返回。
