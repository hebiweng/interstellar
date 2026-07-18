# Interstellar 算法卡模板

算法卡是复杂计算能力进入开发的前置条件，也是`Stable`发布门禁的一部分。每项技法、流派变体、时间转换、关键渲染算法或分析模型组合各自维护一张卡，存放于仓库`algorithm-cards/<category>/<capability-or-model-id>.md`。

算法卡必须让另一名开发者在不自行选择流派、公式、默认参数和误差口径的情况下完成实现。未知内容不得留空或用“常见做法”代替，应标记为`BLOCKED`并停止进入正式开发。

---

## 可复制模板

```markdown
---
schema_version: 1.3.0
card_id: ALG-<CATEGORY>-<NUMBER>
card_kind: technique # technique | analysis_model | topic_model | analysis_recipe | report_rule_pack | time_location | rendering
capability_id: <capabilities.yaml中的能力ID；analysis_model时可为null>
analysis_model_id: <capabilities.yaml中的analysis_models.id；非模型卡时为null>
topic_model_id: <analysis-catalog.yaml中的topic_models.id；非专题模型卡时为null>
report_profile_ids: [] # analysis-catalog.yaml中的报告类型
calculation_ids: [] # calculation-catalog.yaml中的稳定ID
result_contracts: [] # 例如ChartResult、AspectResult、ForecastResult
view_ids: [] # render-catalog.yaml中直接消费本算法结果的视图
title_zh: <中文名称>
title_en: <English name>
card_version: 0.1.0
status: draft # draft | review | approved | superseded
maturity_target: beta # stable | beta | experimental
work_package: V1-XXX-001
owners:
  engineering: <name-or-tbd>
  astrology_review: <name-or-tbd>
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
supersedes: null
---

# <算法名称>

## 1. 决策摘要

- 采用流派/变体：
- 不采用的变体：
- 选择原因：
- 适用范围：
- 明确非目标：
- 当前成熟度：

## 2. 术语与符号

| 符号/术语 | 定义 | 单位/范围 |
|---|---|---|
| | | |

必须明确角度方向、0°基准、时间尺度、历法、坐标系、观察中心、黄道体系和正负号约定。

## 3. 权威来源

| ID | 类型 | 作者/机构 | 标题/版本 | URL/ISBN | 使用章节 | 许可/引用要求 |
|---|---|---|---|---|---|---|
| SRC-01 | primary | | | | | |

来源优先级：原始文献或官方算法说明 > 学术/专业权威实现 > 独立参考实现 > 二手说明。商业软件输出只能用于人工观察，除非许可明确允许自动化测试。

## 4. 输入契约

| 字段 | 类型 | 必填 | 单位/枚举 | 默认值 | 校验 | 来源 |
|---|---|---:|---|---|---|---|
| | | | | | | |

### 4.1 前置条件

- 所需出生时间精度：
- 所需地点精度：
- 所需数据集及最低版本：
- 所需上游能力：
- 不兼容配置：

### 4.2 默认参数

所有默认参数必须显式列出，并在规范化请求中落盘。禁止只存在于代码常量中的领域默认值。

## 5. 输出契约

| 字段 | 类型 | 单位/枚举 | 是否可空 | 语义 | 排序/稳定性 |
|---|---|---|---:|---|---|
| | | | | | |

列出输出对应的Canonical Schema路径，例如：

```text
result.charts[]
result.points[]
result.periods[]
result.events[]
result.topic_evidence[]
warnings[]
```

## 6. 数学定义与公式

### 6.1 时间与坐标约定

- 输入时间尺度：UTC/UT1/TT/TDB：
- Delta T模型：
- 历元与参考系：
- 黄道：回归/恒星及Ayanamsa：
- 坐标：黄道/赤道/地平：
- 观察中心：地心/日心/拓扑中心：

### 6.2 公式

逐步写出公式、变量、单位、归一化和舍入。示例：

```text
raw_delta = longitude_b - longitude_a
normalized_delta = ((raw_delta + 180°) mod 360°) - 180°
orb = abs(abs(normalized_delta) - aspect_angle)
```

### 6.3 算法步骤

1. 校验输入；
2. 规范化时间、地点和参数；
3. ……；
4. 生成Canonical结果；
5. 附加来源、成熟度和警告。

### 6.4 伪代码

```text
function calculate(input, settings) -> Result:
    ...
```

## 7. 流派和变体决策

| 决策点 | 支持的变体 | V1默认 | API参数 | 是否影响缓存键 | 说明 |
|---|---|---|---|---:|---|
| | | | | | |

不同变体的结果必须并列存在或由参数选择，禁止静默混用。

### 7.1 分析模型组合卡附加要求

当`card_kind=analysis_model`时，本节必须额外填写：

| 字段 | 要求 |
|---|---|
| 对象角色 | 每个角色允许的SubjectKind、数量和是否必需 |
| 兼容主题 | AnalysisTopic白名单，不得用“全部”代替 |
| 输入门槛 | 时间精度、时间范围、地点和第二对象要求 |
| 组件DAG | 每个`capability_id`、执行顺序、依赖和必需/可选标记 |
| 默认参数 | Rule Pack、宫位制、容许度、返照地点等全部默认值 |
| 覆盖范围 | 用户允许覆盖的参数及覆盖后的兼容性影响 |
| 降级计划 | 每个输入不足或可选组件失败场景的明确行为 |
| 证据聚合 | 支持、压力、反证和确定度分别如何聚合；禁止不透明抵消 |
| 输出Manifest | 主要视图、次要视图、表格、地图、时间线和导出格式 |
| 版本策略 | 哪些变化属于Patch、Minor和Major |

模型卡不得重新描述底层公式，而应引用各组件算法卡；模型卡的金标准至少验证一次完整展开、一次降级、一次阻断、一次模型版本升级后旧快照复现。模型卡未批准时，模型最多标记为`Experimental`。

### 7.2 TopicModel与ReportRulePack附加要求

当`card_kind=topic_model`或`report_rule_pack`时，必须额外填写：

| 字段 | 要求 |
|---|---|
| 核心配方 | 引用的AnalysisModel、技法、顺序和锁定项 |
| 允许覆盖 | 用户可修改的有限参数；核心修改必须另存CustomModelSpec |
| EvidenceSelector | 从哪些Canonical结果路径选择原子证据 |
| ThemeMapper | 证据到主题/子主题的显式映射 |
| FindingRule | 形成Finding的充分条件、必要条件和排除条件 |
| AggregationRule | 重复证据去重、多技法印证和时间窗合并 |
| ConflictRule | 支持、压力、反证和矛盾如何保留 |
| PriorityRule | 收录阈值、排序、并列和截断规则 |
| SectionDefinition | 报告章节、适用对象、空章节和推荐图表 |
| Templates | `statement_key`、中英文版本、变量、语气和来源许可 |
| ReportProfile | 可生成的六类报告及不支持原因 |
| 专业复核 | 规则、模板、样本和成熟度的签署状态 |

报告规则卡至少包含：一个正常样本、一个反证样本、一个证据冲突样本、一个无模板回退样本、一个未知出生时间降级样本，以及摘要/标准/完整技术版共享同一Finding集合的测试。

## 8. 边界、异常和降级

| 场景 | 预期行为 | 错误/警告代码 | 是否产生部分结果 |
|---|---|---|---:|
| 输入时间未知 | | | |
| 时间存在多个UTC候选 | | | |
| 高纬度不可计算 | | | |
| 数值求根不收敛 | | | |
| 数据集缺失 | | | |
| 超出支持年代 | | | |

明确：

- 输入支持的年代范围；
- 数值迭代上限、停止条件和失败行为；
- 跨0°/360°、公元前日期、闰秒和历法边界；
- 数据不足时是拒绝、候选分支还是部分结果；
- 哪些警告会导致能力成熟度降级。

## 9. 性能与资源预算

| 指标 | 目标 | 硬上限 | 超限行为 |
|---|---:|---:|---|
| 单次CPU时间 | | | 转异步/拒绝 |
| 内存 | | | |
| 搜索点数量 | | | |
| 输出记录数 | | | 分页/截断/对象存储 |

说明可缓存部分、缓存键组成、并行策略和确定性要求。

## 10. 金标准样本

| Fixture ID | 输入来源 | 预期结果来源 | 关键断言 | 允许误差 | 许可/引用 |
|---|---|---|---|---:|---|
| GOLD-001 | | | | | |

至少包含：

- 一个正常样本；
- 一个跨0°/边界样本；
- 一个逆行或多次命中样本；
- 一个时间或地点不确定样本；
- 一个该技法特有的失败样本。

## 11. 差异测试

| Reference ID | 独立实现 | 版本 | 参数对齐 | 比较字段 | 允许误差 | 不一致处理 |
|---|---|---|---|---|---:|---|
| DIFF-001 | | | | | | |

差异测试必须记录参考实现的黄道、宫位制、岁差、章动、Delta T、观察中心、节点类型、容许度和舍入；参数未对齐时不得判断实现错误。

## 12. 属性与不变量

- [ ] 输出角度位于约定区间；
- [ ] 相同规范化输入和版本得到相同输出；
- [ ] 序列化往返不丢失语义；
- [ ] 对称/周期/单调等技法特有不变量已列明；
- [ ] 所有默认值进入输入指纹；
- [ ] 输出排序稳定；
- [ ] 浮点比较不依赖字符串格式。

补充本算法特有属性：

1. 
2. 

## 13. API、Schema和存储影响

- 对应`calculation_id`：
- 实现的Canonical Result Contract：
- 直接消费结果的`view_id`：
- 新增或复用的Schema：
- 新增枚举：
- `/api/v1`影响：
- 是否同步/异步：
- 快照字段：
- 数据库索引：
- 项目归档兼容性：
- 旧版本迁移策略：

## 14. UI与渲染要求

- 输入位置：
- 参数控件：
- 主输出视图：
- 数据表：
- 证据和来源：
- 警告与空状态：
- 导出格式：
- 键盘和无障碍：
- 中英文术语：

## 15. 安全与隐私

- 是否处理出生资料或用户备注：
- 日志允许字段：
- 缓存是否可跨Workspace共享：
- Rule Pack或用户输入的资源耗尽风险：
- 导出是否包含敏感数据：
- 分享行为：

## 16. 可观测性

- 指标：调用量、耗时、失败率、警告率、差异测试漂移；
- 结构化日志：仅ID、版本、阶段、错误码，不含明文敏感输入；
- Trace阶段：
- 告警阈值：

## 17. 发布和回滚

- 初始成熟度：
- Beta门禁：
- Stable门禁：
- 数据/算法版本升级方式：
- 回滚方式：
- 会导致重新计算的变更：
- 会保留旧结果的兼容策略：

## 18. 未解决问题

没有未解决问题时写`None`。存在会改变公式、输入、输出或验收的问题时，状态必须保持`draft`或`BLOCKED`。

| ID | 问题 | 影响 | 负责人 | 截止条件 | 状态 |
|---|---|---|---|---|---|
| Q-01 | | | | | open |

## 19. 审批

| 角色 | 姓名 | 结论 | 日期 | 备注 |
|---|---|---|---|---|
| 工程负责人 | | approve/reject | | |
| 占星专业评审 | | approve/reject | | |
| 数据/许可评审 | | approve/reject/not-needed | | |

## 20. 完成检查

- [ ] 能力卡的能力ID存在于`docs/capabilities.yaml`；
- [ ] `calculation_ids`存在于`docs/calculation-catalog.yaml`，且`docs/calculation-result-catalog.md`已覆盖输入、单位和输出字段；
- [ ] `view_ids`存在于`docs/render-catalog.yaml`且结果依赖与本卡输出一致；
- [ ] 模型卡的AnalysisModel ID、版本、组件和输出Manifest存在于`docs/capabilities.yaml`；
- [ ] TopicModel、AnalysisIntent和ReportProfile ID存在于`docs/analysis-catalog.yaml`；
- [ ] 报告规则明确EvidenceSelector、Finding、冲突、优先级、章节和双语模板；
- [ ] 公式、单位、坐标和时间尺度无歧义；
- [ ] 流派变体和默认参数已锁定；
- [ ] 输入、输出、错误和降级可直接编码；
- [ ] 金标准样本合法可复用；
- [ ] 差异测试至少包含一个独立实现；
- [ ] 容差有依据且未为通过测试任意放宽；
- [ ] 性能预算和异步边界明确；
- [ ] UI、API、导出和存储影响明确；
- [ ] 数据来源、版本、许可和署名明确；
- [ ] 安全、隐私和日志边界明确；
- [ ] 工程和专业评审已签署；
- [ ] `status: approved`后才进入正式开发。
```

## 算法卡状态规则

| 状态 | 含义 | 允许动作 |
|---|---|---|
| `draft` | 公式或决策正在整理 | 调研、原型；不得合并正式实现 |
| `review` | 内容完整，等待审核 | 可实现隔离分支和测试夹具 |
| `approved` | 工程与专业评审通过 | 可进入正式开发和发布门禁 |
| `superseded` | 已被新版本替代 | 只用于复现旧快照 |

算法卡升级采用语义版本：

- 修正文案但不改变结果：Patch；
- 新增可选参数或兼容输出：Minor；
- 改变公式、默认值或结果语义：Major。

任何Major变更必须生成新的计算快照，不得覆盖旧结果；旧卡、旧Rule Pack和旧数据版本必须保留到其引用快照完成生命周期管理。
