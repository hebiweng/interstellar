---
card_id: ALG-FORECAST-002
capability_id: forecast.returns
status: review
phase: alpha
calculation_ids: [forecast.return.v1]
result_contracts: [ForecastResult, ChartResult]
---

# 返照

返照精确时刻解`wrap_signed(transit_longitude - natal_longitude)=0`。搜索窗口按对象平均周期设置并允许用户指定序号；逆行导致多个解时全部返回，由Recipe选择最近、前一个或后一个，不能静默丢弃。默认采用与本命相同的中心、黄道和真/视位置。返照地点策略为出生地、指定现居地或指定旅行地，地点只影响轴点/宫位不影响返照精确UTC。行星返照覆盖Sun—Pluto及节点；月相/反向返照为独立变体。返照图与本命跨盘相位、后续行运触发分开保存。与Swiss/Kerykeion独立实现比较，精确时刻目标60秒。
