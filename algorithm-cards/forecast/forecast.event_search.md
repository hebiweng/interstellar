---
card_id: ALG-FORECAST-007
capability_id: forecast.event_search
status: review
phase: beta
calculation_ids: [astronomy.phenomena.v1, moon.void_of_course.v1, forecast.event_search.v1]
result_contracts: [ForecastResult]
---

# 统一事件搜索器

查询DSL只允许注册事件：星座/宫位进入、相位窗口、站点、返照、月相/食相、升落中天、中点/Lot触发及条件交集。每个事件插件声明连续函数、最大角速度、粗扫步长上限、求根容差和取消点。统一使用半开时间区间，事件按UTC、类型、参与点稳定排序。月亮空亡定义必须由Preset选择：现代“离开星座前无主要入相”或传统“离开星座前无托勒密相位完成”，不能混用。多条件交集对窗口做区间运算，不把抽样点当精确区间。输出包含扫描参数、求根次数、被取消位置和误差。
