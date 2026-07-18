---
card_id: ALG-FORECAST-006
capability_id: forecast.primary_directions
status: review
phase: pro
calculation_ids: [direction.primary.v1, direction.time_keys.v1, direction.bounds.v1]
result_contracts: [ForecastResult]
---

# 主限

V1实现按变体隔离：Ptolemaic zodiacal、Placidus semi-arc mundane、Regiomontanus与through-the-bounds。Promissor和Significator使用出生时赤经/赤纬；有纬/无纬分别计算。Placidus方法根据出生纬度计算半昼/半夜弧、比例时和点的pole，再求promissor到significator的赤道弧；circumpolar或反三角函数域外返回不可计算。时间钥匙Ptolemy=1°/year、Naibod=0°59′08.33″/year，自定义钥匙另存版本。顺/逆主限分别保留，不通过取绝对值合并。实现依据Ptolemy《Tetrabiblos》与Martin Gansten《Primary Directions》所述公式，卡内测试夹具固定每个中间量（RA、OA、AD、pole、arc）。目标差异：弧`<=1 arcmin`、换算日期`<=1 day`；未达标保持Experimental。
