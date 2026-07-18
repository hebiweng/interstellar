---
card_id: ALG-TIMING-003
capability_id: timing.zodiacal_releasing
status: review
phase: pro
calculation_ids: [timelord.zodiacal_releasing.v1]
result_contracts: [ForecastResult]
---

# 黄道释放

从Fortune、Spirit、Eros或Necessity所在整宫星座开始。V1标准星座年表为：Leo19、Cancer25、Gemini/Virgo20、Taurus/Libra8、Aries/Scorpio15、Sagittarius/Pisces12、Capricorn27、Aquarius30；Aquarius的30年不是可替换变体，而是该星座的标准周期。默认Egyptian year=`360d`、month=`30d`；回归年`365.2421897d`换算属于独立Preset且不得共享缓存键。L2—L4按照父层的时间单位递归展开同一十二星座周期，子段必须完全落在父段内。Loosing of the Bond、Peak与Angular标记使用独立版本化规则表，并保存触发条件，禁止只输出布尔值。显示精度不得高于出生时间可信度。测试使用逐层手算夹具、Capricorn/Aquarius不同时长、父子段无越界、循环序列和两种年长换算差异。
