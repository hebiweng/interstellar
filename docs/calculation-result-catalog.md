# Interstellar V1 全量计算与结果目录

> 状态：V1 开发说明书的规范性附件  
> 适用范围：现代、古典、希腊化西方占星；本命、预测、关系、事件、项目、卜卦、择时、地理与世运  
> 对应来源：产品讨论中“二、需要计算的完整指标”至“七、地理占星和世运占星”  
> 机器可读ID与阶段：[`calculation-catalog.yaml`](./calculation-catalog.yaml)  
> 图形目录：[`render-catalog.yaml`](./render-catalog.yaml)

本目录把“覆盖所有计算”收敛为可开发、可测试的封闭基线。本文件定义字段与算法边界，`calculation-catalog.yaml`定义唯一ID、能力归属、阶段和结果契约；两者必须同步。V1 必须实现其中 `target_release` 为 `alpha`、`beta`、`pro` 或 `v1` 的条目；标为 `post_v1` 的条目必须保留接口和扩展点，但不阻塞 V1 发布。新增流派或变体必须新增稳定 ID，不得静默改变已有结果。

## 1. 目录规则

### 1.1 发布阶段与成熟度

| 字段 | 可选值 | 含义 |
|---|---|---|
| `target_release` | `alpha` / `beta` / `pro` / `v1` / `post_v1` | 首次进入可用目录的阶段 |
| `target_maturity` | `stable` / `beta` / `experimental` | V1 结束时允许达到的成熟度 |
| `audience` | `professional` / `consumer` / `internal` | 默认可见范围 |
| `time_requirement` | `exact` / `interval_ok` / `date_ok` | 对输入时间精度的最低要求 |

每个计算条目必须同时具有：

- 稳定的 `calculation_id`；
- 输入和输出 Schema；
- 单位、坐标系、历元、中心和真/视位置说明；
- 数据源与算法版本；
- 算法卡、金标准、差异测试和允许误差；
- 依赖能力、错误码和降级方式；
- 至少一个消费该结果的 API、表格或图形视图。

### 1.2 通用数值约定

- 角度内部统一为十进制度 `degree`，范围按字段定义为 `[0,360)`、`[-180,180)` 或 `[-90,90]`；UI 可转度分秒。
- 时间戳使用 ISO 8601；天文时间另存 JD/JDE；持续时间使用秒。
- 距离必须带单位，默认天文单位 `au`；月球、近地天体允许 `km`。
- 速度必须标注分量和单位，不允许只有无语义的 `speed`。
- 所有计算值必须记录 `frame`、`center`、`epoch`、`position_kind`、`engine_version` 和 `dataset_versions`。
- `unknown`、`not_applicable`、`not_computable` 和 `not_requested` 是不同状态，不得都序列化为 `null`。

## 2. 完整基础计算指标

### 2.1 时间、历法与地点标准化

| calculation_id | 必须计算或保存的结果 | 对应能力 | target_release | target_maturity |
|---|---|---|---|---|
| `time.input.v1` | 原始公历/儒略历日期、当地时间、时间精度、可信度、来源、未知时间区间 | `platform.time_spec` | alpha | stable |
| `time.timezone.v1` | IANA 时区、tzdb 版本、历史 UTC 偏移、DST、重复/空洞时间、全部 UTC 候选、人工修正 | `platform.time_spec` | alpha | stable |
| `time.scales.v1` | UTC、UT1、TAI、TT、TDB、历书时、`UT1-UTC`、Delta T、闰秒来源 | `astronomy.ephemeris_core` | beta | stable |
| `time.julian.v1` | JD、JDE、儒略世纪、历法转换中间值 | `astronomy.ephemeris_core` | alpha | stable |
| `time.solar_sidereal.v1` | 地方平太阳时、地方真太阳时、GST、LST、RAMC/ARMC | `astronomy.coordinate_systems` | beta | stable |
| `time.earth_orientation.v1` | 黄赤交角、岁差、章动、极移、大气折射和所用模型 | `astronomy.coordinate_systems` | beta | stable |
| `location.normalized.v1` | 地名、国家、行政区、WGS84 经纬度、海拔、IANA 时区、地名来源与版本 | `platform.location` | foundation | stable |
| `time.quality.v1` | A–E 时间质量、可用/禁用能力、候选分支、历史时区警告 | `natal.unknown_time_mode` | alpha | stable |

### 2.2 天体注册表

`body_id` 必须可扩展；默认注册下列对象，任何对象都不得以 UI 文案作为主键。

| 分组 | V1 默认对象 |
|---|---|
| 发光体与行星 | Sun、Moon、Mercury、Venus、Mars、Jupiter、Saturn、Uranus、Neptune、Pluto |
| 月球轨道点 | True/Mean North Node、True/Mean South Node、Perigee、Apogee、Mean/True/Osculating Black Moon Lilith |
| 矮行星/半人马体/常用小行星 | Chiron、Ceres、Pallas、Juno、Vesta、Pholus、Nessus、Eris、Sedna、Makemake、Haumea、Eros、Psyche |
| 轴点与敏感点 | ASC、DSC、MC、IC、Vertex、Anti-Vertex、East/West Point、Equatorial/Co-/Polar Ascendant、Zenith、Nadir、RAMC、ARMC |
| 可扩展对象 | MPC 编号小行星、彗星、固定星、阿拉伯点、用户公式点、乌拉诺假想星/TNP |

### 2.3 每个天体和敏感点的原始位置

`calculation_id=astronomy.position.v1`，对应 `astronomy.ephemeris_core` 与 `astronomy.coordinate_systems`。每个 `body_id` 必须返回：

| 字段组 | 必须字段 |
|---|---|
| 身份 | `body_id`、类别、显示名键、星历对象号、是否真实天体 |
| 黄道坐标 | 黄经、黄纬、星座、星座内度数、岁差值/Ayanamsa |
| 赤道坐标 | 赤经、赤纬、是否越界、太阳最大赤纬参考值 |
| 地平坐标 | 高度角、方位角、折射前后值、是否在地平线上 |
| 距离 | 距观察中心距离、日心距离、视直径（可得时） |
| 速度 | 黄经/黄纬/距离/赤经/赤纬速度及单位 |
| 运动状态 | 顺行、逆行、停滞、即将逆行、即将顺行、最近/下一站点时间 |
| 日照关系 | 与太阳角距、日核、燃烧、光束下、东方/西方、晨星/昏星、可见性 |
| 盘内位置 | 宫位、距前后宫头、距轴点、是否接近角宫 |
| 计算语境 | 地心/日心/拓扑中心、真/视位置、黄道/赤道/地平参考系、历元 |
| 溯源 | 引擎、内核、数据版本、计算标志、误差估计、警告 |

### 2.4 坐标与观察视角

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `coordinate.ecliptic.v1` | 真/平黄道坐标、回归/恒星黄道 | alpha | stable |
| `coordinate.equatorial.v1` | 真/平赤道坐标、赤纬相位基础 | beta | stable |
| `coordinate.horizontal.v1` | 高度、方位、升落、中天与下中天 | beta | stable |
| `coordinate.geocentric.v1` | 地心坐标 | alpha | stable |
| `coordinate.heliocentric.v1` | 日心坐标与日心黄道盘 | beta | beta |
| `coordinate.topocentric.v1` | 拓扑中心坐标、海拔与视差 | beta | stable |
| `coordinate.local_space.v1` | 本地空间方位和方位线 | pro | beta |
| `coordinate.latitude_declination.v1` | 黄纬、赤纬、平行/反平行基础 | beta | beta |

### 2.5 黄道、Ayanamsa 与盘面转换

| calculation_id | 必须支持的变体 | target_release | maturity |
|---|---|---|---|
| `zodiac.tropical.v1` | 回归黄道 | alpha | stable |
| `zodiac.sidereal.v1` | Lahiri、Fagan-Bradley、Raman、Krishnamurti、Yukteshwar、True Chitrapaksha、True Revati、De Luce、自定义值 | beta | beta |
| `chart.draconic.v1` | 龙首盘 | beta | beta |
| `chart.solar_lunar.v1` | 太阳盘、月亮盘、自然宫位盘、等宫太阳盘 | beta | beta |
| `chart.zodiac_comparison.v1` | 回归/恒星黄道同参数比较 | v1 | beta |

### 2.6 四轴、敏感点和宫位

| calculation_id | 必须返回 | target_release | maturity |
|---|---|---|---|
| `angles.primary.v1` | ASC、DSC、MC、IC 的黄经、赤经、赤纬、星座、宫位和速度 | alpha | stable |
| `angles.sensitive.v1` | Vertex/Anti-Vertex、East/West Point、Equatorial/Co-/Polar Ascendant、Zenith/Nadir、RAMC/ARMC | beta | beta |
| `houses.systems.v1` | Placidus、Whole Sign、Equal、Equal MC、Koch、Porphyry、Regiomontanus、Campanus、Alcabitius、Topocentric、Morinus、Vehlow、Meridian、Horizontal、Krusinski、Gauquelin、APC、Axial Rotation | alpha | stable |
| `houses.results.v1` | 12 宫头、宫头星座/度数、跨度、截夺/重复星座、古典/现代宫主、宫内天体、距宫头、宫位强度 | alpha | stable |
| `houses.derived.v1` | 衍生宫位/转宫映射及来源宫 | pro | beta |
| `houses.polar.v1` | 高纬不可计算、畸变和上升速度警告；仅经用户同意切换宫制 | alpha | stable |

### 2.7 相位

| calculation_id | 内容 | target_release | maturity |
|---|---|---|---|
| `aspect.major.v1` | 0°、60°、90°、120°、180° | alpha | stable |
| `aspect.minor.v1` | 30°、36°、40°、45°、72°、135°、144°、150° | beta | beta |
| `aspect.harmonic.v1` | 七分、双七分、三七分、十一分及任意 N 分相位 | beta | beta |
| `aspect.declination.v1` | 平行、反平行 | beta | beta |
| `aspect.latitude.v1` | 黄纬平行、黄纬反平行 | v1 | experimental |
| `aspect.mirror.v1` | Antiscia、Contra-antiscia、Solstice/Equinox points | beta | beta |

每个 `AspectResult` 必须包含：双方点、理论角、实际角距、规范化角差、容许度、容许度百分比、入相/出相、形成方向、开始/精确/结束时间、逆行重复命中、持续时间、强度、双方权重、跨星座标志、盘内/跨盘/行运/推运语境、互容/接纳引用。

### 2.8 元素、模式和盘面结构

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `distribution.elements.v1` | 火土风水数量、加权分、百分比、过强/缺失 | alpha | stable |
| `distribution.modalities.v1` | 基本、固定、变动数量和权重 | alpha | stable |
| `distribution.polarity.v1` | 阴阳分布 | alpha | stable |
| `distribution.hemisphere.v1` | 东西、上下半球、四象限、角/续/果宫 | beta | beta |
| `pattern.jones.v1` | 碗、桶、束、火车头、跷跷板、散点、飞溅、扇、单边/半球集中 | beta | beta |
| `pattern.geometry.v1` | 群星、大三角、T三角、大十字、风筝、摇篮、神秘矩形、Yod、Thor's Hammer、大五分、五角星、近似格局、中心与主导星 | beta | beta |

### 2.9 守护、接纳与定位星链

`calculation_id=natal.rulership_reception.v1` 必须输出：古典/现代星座守护、宫位守护、最终/单一定位星、定位星链、循环定位、单向/双向接纳、星座/擢升/三分性/界/面接纳、互容、宫主星链、关系盘交叉守护及主题传递路径。目标阶段 `beta`，目标成熟度 `beta`。

### 2.10 古典尊贵和状态

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `classical.essential_dignity.v1` | 入庙、擢升、失势、落陷、三分性、界、面、游走、Almuten、分项与总分 | beta | beta |
| `classical.accidental_dignity.v1` | 宫位、速度、顺逆、日核/燃烧/光束下、喜乐宫、昼夜、Hayz、东西方、吉凶相位、可见性 | beta | beta |
| `classical.condition.v1` | 夹制、围困、Bonification、Maltreatment、光线传递/收集、禁止、挫败、返回、完成 | pro | beta |
| `classical.life_points.v1` | Hyleg、Alcocoden、Anareta、Prorogator、Apheta、生命主星与年限分配 | v1 | experimental |

`classical.life_points.v1` 仅供专业研究，必须默认关闭，不得生成寿命、死亡日期或灾祸断言；未通过专业评审时可随 V1 发布为 Experimental，但不得伪装成 Stable。

### 2.11 阿拉伯点

`calculation_id=classical.lots.v1` 至少预置福点、精神点、爱情点、婚姻点、子女点、事业点、财富点、父亲点、母亲点、兄弟姐妹点、疾病点、必然点、胜利点、勇气点、报应点、基础点、成功点；支持昼夜公式、自定义三点公式、守护星、相位和释放引用。目标阶段 `beta`，成熟度 `beta`。

### 2.12 中点、谐波与乌拉诺体系

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `midpoint.direct_indirect.v1` | 直接/间接/近中点、中点轴、反中点、45°/90°/360°模数、中点树和触发时间 | beta | beta |
| `harmonic.chart.v1` | 任意 N 次谐波；默认 2/3/4/5/7/9；盘内相位、与本命叠加 | beta | beta |
| `uranian.dials.v1` | 22.5°、45°、90°、360°盘、对称轴、中点公式、指针和外圈 | v1 | experimental |
| `uranian.tnp.v1` | 可配置 TNP/假想星注册表和行星图式 | v1 | experimental |

### 2.13 固定星、月相与天文现象

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `fixed_star.position.v1` | 黄经、赤经、赤纬、自行修正、星等、星座、历元、别名与数据来源 | beta | beta |
| `fixed_star.contact.v1` | 与天体/四轴合相及容许度；Paran 升落中天事件 | pro | beta |
| `moon.phase.v1` | 日月角距、八相、月龄、照明比例、距离、近/远地点、新上满下弦 | alpha | stable |
| `moon.special_labels.v1` | 超级月亮、蓝月、黑月；定义必须版本化 | beta | beta |
| `astronomy.eclipse.v1` | 日/月食类型、食分、食甚、沙罗、可见区和路径 | v1 | beta |
| `astronomy.phenomena.v1` | 合、冲、站点、逆行、进入星座/宫位、升落、中天、朔望 | beta | stable |
| `moon.void_of_course.v1` | 空亡规则包、开始/结束和下一主要相位 | pro | beta |
| `planetary.hours.v1` | 日出日落、昼夜时长、行星时 | pro | beta |

## 3. 预测类计算与结果

### 3.1 行运

`forecast.transit.v1` 必须覆盖：行运对本命、行运对行运、行运对推运、行运对太阳弧、行运对返照、行运对组合盘、行运对戴维森、行运对事件/公司/国家盘、经过本命宫位、触发宫主/中点/阿拉伯点、平行/反平行、逆行多次触发以及进入—精确—离开时间。

每个结果输出 `TransitEvent`：移动点、目标点/宫位、相位或进入类型、容许度、开始、全部精确命中、结束、运行方向、重复次数、持续时间、相关盘版本和证据引用。阶段 `alpha`，成熟度 `stable`。

### 3.2 推运

| calculation_id | 变体 | target_release | maturity |
|---|---|---|---|
| `progression.secondary.v1` | 次限；真/平太阳变体；行星、月亮、轴点、宫位、相位和推运月相 | beta | beta |
| `progression.tertiary.v1` | 三限 | beta | beta |
| `progression.minor_quartary.v1` | 小限推运、四限推运及变体 | v1 | experimental |
| `progression.cross.v1` | 推运对本命、推运对推运、行运对推运 | beta | beta |

### 3.3 弧向与主限

| calculation_id | 变体 | target_release | maturity |
|---|---|---|---|
| `direction.solar_arc.v1` | 太阳弧、Naibod 键、真太阳键 | beta | beta |
| `direction.other_arcs.v1` | 月亮、上升、Vertex、宫主、Sect 和自定义弧 | pro | beta |
| `direction.primary.v1` | 黄道、赤道、世俗、Placidus、Van Dam 主限 | pro | beta |
| `direction.time_keys.v1` | Ptolemy、Naibod、自定义时间钥匙 | pro | beta |
| `direction.bounds.v1` | 通过界的主限/分配、Promissor 与 Significator 组合 | pro | experimental |

### 3.4 返照盘

`forecast.return.v1` 必须支持太阳、月亮、水星、金星、火星、木星、土星、天王星、海王星、冥王星和节点返照；反向返照、月相返照；出生地、现居地和旅行地策略；返照自身、返照对本命、行运触发返照；年度盘月度/日度划分。阶段 `alpha→v1`，核心返照 Stable，高级变体 Beta/Experimental。

### 3.5 时间主星体系

| calculation_id | 结果 | target_release | maturity |
|---|---|---|---|
| `timelord.profection.v1` | 年/月/日小限、激活宫和主星 | pro | beta |
| `timelord.firdaria.v1` | 法达主/次周期与昼夜变体 | pro | beta |
| `timelord.zodiacal_releasing.v1` | Fortune/Spirit/Eros/Necessity，L1–L4、Peak、Loosing of Bond、Angular | pro | beta |
| `timelord.decennials.v1` | 十年主星 | v1 | experimental |
| `timelord.planetary_periods.v1` | 七曜年限、行星周期、年/月/日主星 | v1 | experimental |
| `timelord.return_lord.v1` | 太阳返照主星和年度主星 | pro | beta |

### 3.6 周期与事件搜索

`calculation_id=forecast.event_search.v1`。统一事件搜索器必须支持：进入星座/宫位、精确相位及容许度区间、逆行/顺行/停滞、返照、中点/阿拉伯点触发、食相、升落中天、过去相同配置、未来复现、多条件同时满足和择时候选排序。结果必须输出查询条件、采样步长、求根方式、全部命中、误差和取消/超时状态。

## 4. 关系与伴侣计算

| calculation_id | 必须结果 | target_release | maturity |
|---|---|---|---|
| `relationship.synastry.v1` | A→B、B→A 跨盘相位、宫位覆盖、轴点、宫主、中点、Lots、节点/Vertex、平行/反平行及方向性 | alpha | stable |
| `relationship.composite.v1` | 对应点中点、短/长弧策略、组合四轴/宫位/相位、与双方本命关系 | alpha | stable |
| `relationship.davison.v1` | 时间中点、球面地理中点、参考地、MC 校正/非校正变体 | beta | beta |
| `relationship.dynamic.v1` | A 行运对 B、B 行运对 A、双方推运比较、推运合盘、行运对组合/Davison、返照交叉 | v1 | beta |
| `relationship.event_charts.v1` | 初见、关系开始、结婚、分手、复合和共同迁移事件盘 | v1 | experimental |

关系结果不得只返回总分。至少输出吸引、情绪安全、沟通、亲密、承诺稳定、权力冲突、自由距离、理想化边界、共同方向和当前周期的双向证据。

## 5. 项目、事件和择时计算

### 5.1 项目与事件对象

项目/组织允许以立项、合同签署、注册、产品发布、首次上线、开业、首笔交易和首个客户签约等事件创建独立 `SubjectVersion`。必须保存所选“起盘事件”的类型、理由、来源和可信度，不得默认某一种事件天然正确。

| calculation_id | 必须结果 | target_release | maturity |
|---|---|---|---|
| `project.base_chart.v1` | 项目事件盘、宫位/宫主、强弱、相位和关键周期 | v1 | beta |
| `project.forecast.v1` | 行运、返照、推运、阶段、风险/支持时间窗 | v1 | beta |
| `project.cross_subject.v1` | 项目与创始人、负责人、公司、合作方、客户、融资事件的跨盘关系 | v1 | experimental |
| `event.chart.v1` | 通用事件盘与事件前后时间窗口 | alpha | stable |

### 5.2 择时约束优化

`electional.search.v1` 支持硬性排除、必要条件、加分条件、时间地点约束和多条件排序。预置条件至少包括：月亮空亡/受克、ASC/ASC 主星、目标宫主、逆行、燃烧、食相、吉凶星角宫、目标宫主相位、行星进入、行星时、工作时间与排除日期。必须同时返回候选、拒绝候选、逐规则证据和不透明评分禁令。阶段 `pro`，成熟度 `beta`。

## 6. 卜卦占星计算

`horary.judgement.v1` 必须分层返回，禁止只输出“是/否”：

1. 提问时刻、地点、问题原文、问题分类和宫位映射；
2. 盘有效性与警示：ASC 过早/过晚、月亮空亡、土星第七宫等；
3. 提问者、对方/事项象征星和转宫链；
4. 象征星本质/偶然尊贵、接纳、互容、速度和宫位；
5. 入相/出相与完成；光线传递、光线收集、禁止、挫败、返回；
6. 月亮下一相位、事件完成单位与候选时间；
7. 支持、压力、反证、限制和 Rule Pack trace。

阶段 `pro`，成熟度 `beta`；问题语义到宫位映射必须允许人工确认。

## 7. 地理占星与世运计算

### 7.1 地理占星

| calculation_id | 必须结果 | target_release | maturity |
|---|---|---|---|
| `geography.relocation.v1` | 不同城市 ASC/MC/宫位、迁移盘、本命对比、迁移返照 | pro | beta |
| `geography.astrocartography.v1` | 各天体 ASC/DSC/MC/IC 线、交叉点、距离和误差 | pro | beta |
| `geography.paran.v1` | Paran 事件、线、升落中天下中天组合 | pro | beta |
| `geography.local_space.v1` | 从原点发出的天体方位线 | pro | beta |
| `geography.city_compare.v1` | 城市盘面差异和结构化证据；主观评分必须可解释 | pro | beta |
| `geography.travel.v1` | 旅行时间盘、地点/时间联合比较 | v1 | experimental |

### 7.2 世运占星

| calculation_id | 必须结果 | target_release | maturity |
|---|---|---|---|
| `mundane.subject_charts.v1` | 国家、城市、公司、市场开盘盘及来源可信度 | v1 | beta |
| `mundane.ingress.v1` | 春分及巨蟹/天秤/摩羯进入盘 | v1 | beta |
| `mundane.lunation_eclipse.v1` | 新月、满月、日食、月食及地点投影 | v1 | beta |
| `mundane.outer_cycles.v1` | 木土、土天、土海、土冥及可配置行星周期 | v1 | experimental |
| `mundane.sign_ingress.v1` | 外行星进入星座、站点和周期中点 | v1 | beta |
| `mundane.geo_projection.v1` | 事件地点天象、食相路径和地理覆盖 | v1 | beta |

## 8. Canonical Result Contracts

以下是公共 API 必须稳定的结果边界。具体 JSON Schema 在实现阶段放入 `packages/schema`，字段不得由第三方库结构直接泄漏。

### 8.1 `AstronomicalContext`

```text
time_scales + julian_values + sidereal_values + earth_orientation
+ observer + coordinate_settings + engine/dataset provenance + uncertainty
```

### 8.2 `CelestialPosition`

```text
identity + ecliptic + equatorial + horizontal + distances + velocity_components
+ motion_state + solar_relation + chart_placement + frame/center/epoch/provenance
```

### 8.3 `HouseSet` 与 `ChartPoint`

```text
HouseSet: system + cusps[12] + angles + sensitive_points + rulers + interceptions + polar_warnings
ChartPoint: point_id + position_ref + sign + degree_in_sign + house + cusp_distances + status_refs
```

### 8.4 `AspectResult`

```text
point_a + point_b + context + type + exact_angle + actual_angle + orb + orb_ratio
+ applying_state + direction + strength + entered_at + exact_hits[] + left_at + rule_refs
```

### 8.5 `ChartResult`

```text
chart_id + family + technique + subject_version_refs + time/location + settings
+ astronomical_context + points[] + house_set + aspects[] + distributions[] + patterns[]
+ dignities[] + receptions[] + lots[] + midpoints[] + warnings[] + provenance
```

### 8.6 专项结果

```text
ForecastResult      events[] + periods[] + active_windows[] + exact_hits[]
RelationshipResult charts[] + directional_evidence[] + dimensions[] + dynamic_events[]
HoraryResult        validity + significators + perfection + timing + warnings + evidence
ElectionalResult    candidates[] + rejected[] + rule_trace[]
GeographyResult     relocated_charts[] + lines[] + intersections[] + locations[]
MundaneResult       charts[] + cycles[] + events[] + geographic_overlays[]
TopicResult         baseline + activation + activity + support + pressure + confidence
                    + evidence[] + counter_evidence[]
```

### 8.7 `OutputManifest`

每次计算必须返回 `OutputManifest`，逐项声明：

- 已生成、降级、阻断或未请求的结果 ID；
- 对应 `calculation_id`、结果 JSON Pointer 和成熟度；
- 可用的 `view_id`、表格、导出格式和推荐主视图；
- 缺失输入、警告、算法卡和复现信息。

## 9. 完成与验收

一个计算条目只有同时满足以下条件才算完成：

1. `capabilities.yaml` 中有归属能力和阶段；
2. 有算法卡、公共 Schema 和单位说明；
3. 有金标准、独立实现差异测试及允许误差；
4. API 返回可复现版本信息和 `OutputManifest`；
5. 至少一个 `render-catalog.yaml` 视图或专业数据表消费该结果；
6. 未知时间、高纬度、历史时区和缺失数据有明确降级；
7. Beta/Experimental 不被 UI 或导出伪装成 Stable。

本目录不是占星有效性的科学证明。确定性计算负责可复现的天文与规则结果；主题模型不得输出客观事件概率、保证结果或不透明“好运分”。
