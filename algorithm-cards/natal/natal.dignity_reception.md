---
card_id: ALG-NATAL-004
capability_id: natal.dignity_reception
status: review
phase: beta
calculation_ids: [natal.rulership_reception.v1, classical.essential_dignity.v1, classical.accidental_dignity.v1, classical.condition.v1, classical.life_points.v1]
result_contracts: [EssentialDignityResult, ReceptionResult, DispositorGraphResult, SolarConditionResult, LifePointResearchResult]
---

# 尊贵、接纳与古典状态

## 1. 明确流派和适用对象

`classical.essential.traditional_seven.v1`只对太阳、月亮、水星、金星、火星、木星、土星计算本质尊贵。默认表为：七曜本垣与擢升采用托勒密/传统表；三分性采用Dorothean昼、夜、参与主；界采用Egyptian Terms；面采用Chaldean faces。每张表必须带稳定ID、版本、来源ID和内容哈希。

天王星、海王星、冥王星的现代共同守护只能放在`modern rulership`层，不能显示为古典入庙；月交点、Lots、Vertex、小行星、半人马体、汉堡TNP和来源不明特殊点没有默认古典本质尊贵。它们返回`applicable=false`和`POINT_OUTSIDE_TRADITIONAL_SEVEN`，不得因为竞品存在标签而复制其表。

## 2. 输入、计算与确定性输出

输入：稳定`point_id`、回归或已明确转换后的0°—360°黄经、显式`Sect.DAY|Sect.NIGHT`和尊贵Profile。未知Sect不能猜测；需要由上游根据太阳相对地平线和版本化昼夜规则求得，或返回不可用。

输出至少包含：

- `profile_id`、`applicable`、`unavailable_reason`；
- `sign_id`、`degree_in_sign`、`sect`；
- `dignities[]`：本垣、擢升、三分、界、面及表/规则来源；
- `debilities[]`：失势、落陷及表/规则来源；
- `peregrine`：没有任何当前有效的正向本质尊贵；
- `status_facts[]`：供表格和详情直接消费的语言无关投影，字段为`status_id`、`polarity`、`level`、`active`、`label_key`、`role`、`table_ref`、`rule_id`；
- `algorithm_card_id`、全部`rule_ids/source_ids`和显式排除能力。

三分性非当值角色仍保存在`dignities[]`，但其`is_active_for_sect=false`，对应`status_facts[].active=false`。游走只由当前有效的正向本质尊贵为空推出；失势或落陷不会让一颗行星自动“不游走”。紧凑表格不得只选一个标签：水星双鱼必须同时保留`detriment`与`fall`，需要压缩时使用“落陷 + 失势”等多标签或“2项主要弱势”，详情可见全部证据。

## 3. 展示规则

| 状态 | 中文规范词 | 极性 | 层级 | 紧凑表格默认 |
|---|---|---|---|---|
| `domicile` | 入庙 | dignity | major | 显示 |
| `exaltation` | 擢升 | dignity | major | 显示 |
| `detriment` | 失势（部分产品称相害） | debility | major | 显示 |
| `fall` | 落陷 | debility | major | 显示 |
| `triplicity` | 三分性 | dignity | minor | 当值时显示；非当值只在详情显示 |
| `term` | 界 | dignity | minor | 详情显示 |
| `face` | 面 | dignity | minor | 详情显示 |
| `peregrine` | 游走 | neutral | derived | 显示并说明定义 |

每个标签后可展开“规则与来源”。现代共同守护、古典本质尊贵、运动/逆行、太阳关系和偶然尊贵必须分列，不能合并成一个无来源的“尊贵”字符串。解释模板只能读取这些事实，不得从中文标签反推计算。

## 4. 已实现与尚未实现

| 子能力 | 当前状态 | 成熟度 | 发布条件 |
|---|---|---|---|
| 传统七曜本垣/擢升/失势/落陷 | 已实现并有竞品夹具回归 | Beta | 增加独立引擎差异样本后可评Stable |
| Dorothean三分性、Egyptian界、Chaldean面、游走 | 已实现并有边界测试 | Beta | 锁定更多出版样盘与表版本差异 |
| 传统/现代宫主与传统定位星链 | 已实现，现代表与古典表分离 | Beta | 不将现代共同守护包装为古典尊贵 |
| 接纳/互容 | 已实现尊贵接纳，不要求相位 | Beta | 需要另一个要求相位/完成的Rule Pack，不可静默切换 |
| 日核/燃烧/光束下 | 已实现Lilly阈值Profile | Beta | 物理可见性、晨昏、纬度条件另算 |
| 昼夜成员 | 已实现显式Sect事实 | Beta | 自动昼夜判定与水星昼夜归属另行算法卡 |
| Almuten与尊贵总分 | 未实现；现有结果明确排除 | Experimental | 必须版本化计分Preset、并列处理与用途，禁止单一吉凶分 |
| 宫位角续果、速度、站点、逆行、喜乐宫、Hayz、东西方 | 未形成统一`AccidentalDignityResult` | Experimental | 每项锁来源、输入门槛、阈值和不适用语义后分项实现 |
| 围困、夹制、Bonification/Maltreatment、光线传递/收集、禁止、挫败、返回、完成 | 未实现 | Experimental | 分卜卦/本命语境与相位应用规则，不可复用一个布尔值 |
| Hyleg/Alcocoden等生命点 | 默认关闭 | Experimental | 仅研究工具；不得输出寿命、死亡或灾祸结论 |

过去卡片中的“本垣+5、擢升+4……”只是候选Preset，不是当前已实现字段。完成`score_profile_id`、逐项权重、并列规则、回归样本和用途限制前，API不得返回`dignity_score`或总分。

## 5. 竞品66点位审计夹具

用户提供的66点位导出中有12个真正附带“入庙/相害/陷落”标签：

- 可由传统七曜表复现：月亮摩羯=`detriment`；水星双鱼=`detriment + fall`；火星白羊=`domicile`。
- 可由独立现代守护层表达但不是古典尊贵：天王星水瓶=`modern co-ruler`。
- 无默认权威表，不进入古典输出：北交点狮子、智神星巨蟹、婚神星水瓶、丘比特射手、宙斯天秤、克洛诺斯双子、阿得门图斯金牛、人龙星天蝎。

竞品把水星双鱼压缩为单一“陷落”，本系统保留失势和落陷两个事实，因此信息颗粒度更高。竞品文字仅作为字段覆盖夹具，不作为公式或翻译来源。

## 6. 测试与允许误差

- 星座、尊贵和标签为离散规则，允许误差为零；0°/30°边界使用半开区间。
- Egyptian Terms每宫连续覆盖0°—30°；面按0°/10°/20°边界测试。
- 昼夜切换必须验证当值/非当值三分主和游走变化。
- 竞品夹具必须验证月亮摩羯、水星双鱼、火星白羊，并验证外行星、节点、小行星和TNP不会被提升为古典尊贵。
- 每个`status_fact`必须有label key、极性、层级、激活状态、规则ID；有表的状态必须带表版本和哈希。
- Stable门禁仍需生产实现与不共享表/逻辑的参考实现差异测试、算法卡主责签署和API/Schema契约测试。
