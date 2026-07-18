# Interstellar M0—M24 开发资产与开工说明

本文件回答一个具体问题：当前仓库中的文档是否足以让唯一主责开发者从 M0 开始持续开发到 M24，以及每类实现应当以哪个文件为准。

结论：**范围、稳定 ID、核心数据契约、API 基线、模型/规则/报告配置、算法规格、数据清单、测试门禁和月度任务已经形成可开工基线；业务代码尚未实现。** 当前状态不是“V1 已完成”，而是“开发输入已经落盘，可以按 M0 工作包开始编码”。

## 1. 开发事实

| 资产 | 数量/范围 | 当前状态 | 实现含义 |
|---|---:|---|---|
| AnalysisModel | 12 | 已登记并有官方 Preset | 可开发注册表、Recipe Resolver 和执行 DAG |
| TopicModel | 24 | 已登记并有规则绑定 | 可开发专题证据选择与报告包 |
| AnalysisIntent | 35 | 已登记 | 可开发目的入口与默认 Recipe |
| 确定性计算 | 99 | 稳定 `calculation_id` 已登记 | 逐项实现，不代表当前已经可计算 |
| 图形视图 | 146 | 1—128 为专业 V1，129—146 为 V1 后 | 逐 `view_id` 实现和验收 |
| 算法卡 | 50 | `review/not_started` | 规格可进入实现；通过双实现差异后才可批准 |
| Canonical JSON Schema | 15 | 首版契约已落盘 | 先生成 TS/Python 类型，再写业务实现 |
| OpenAPI | 45 paths / 51 operations | 3.1 基线已落盘 | 服务端和 SDK 共同遵循 |
| 数据 Manifest | 14 | 来源、许可、同步、失败策略已登记 | 下载后还必须锁版本和 SHA-256 |
| M0—M24 月份/任务 | 25 / 100 | 单一主责任务台账已落盘 | 每月按验收关闭，不按“写过代码”关闭 |

## 2. 唯一权威路径

| 开发问题 | 唯一权威文件 |
|---|---|
| 用户从哪里进入、选择什么、默认算什么 | [`analysis-catalog.yaml`](./analysis-catalog.yaml) |
| 要实现哪些能力、阶段和依赖 | [`capabilities.yaml`](./capabilities.yaml) |
| 具体有哪些计算 ID | [`calculation-catalog.yaml`](./calculation-catalog.yaml) |
| 每项计算返回什么字段 | [`calculation-result-catalog.md`](./calculation-result-catalog.md) |
| 要画哪些图以及消费什么结果 | [`render-catalog.yaml`](./render-catalog.yaml) |
| API 和领域对象字段 | [`../openapi/openapi.yaml`](../openapi/openapi.yaml) 与 [`../packages/canonical-schema/README.md`](../packages/canonical-schema/README.md) |
| 模型默认组件和覆盖项 | [`../presets/official/analysis-model-presets.yaml`](../presets/official/analysis-model-presets.yaml) |
| 基础模型和专题规则 | [`../rules/official/base-model-rules.yaml`](../rules/official/base-model-rules.yaml)、[`../rules/official/topic-model-rules.yaml`](../rules/official/topic-model-rules.yaml) |
| 报告结构和双语模板 | [`../reports/report-profiles.yaml`](../reports/report-profiles.yaml)、[`../reports/templates.zh-CN.yaml`](../reports/templates.zh-CN.yaml)、[`../reports/templates.en-US.yaml`](../reports/templates.en-US.yaml) |
| 公式、变体、默认参数和阻断条件 | [`../algorithm-cards/catalog.yaml`](../algorithm-cards/catalog.yaml) |
| 数据从哪里来、能否爬取、如何降级 | [`../data-manifests/catalog.yaml`](../data-manifests/catalog.yaml) |
| 每个月具体交付什么 | [`backlog/m24-single-owner.yaml`](./backlog/m24-single-owner.yaml) |

冲突处理顺序：稳定 ID 和目录字段以对应 YAML 目录为准；HTTP/Schema 以 OpenAPI 与 Canonical Schema 为准；算法细节以具体算法卡为准；工程与产品行为以 V1 开发说明书为准。发现冲突时先修订规范并提升版本，不允许在代码里建立第二套隐式事实。

## 3. 主责与并行方式

项目只有一个责任主体：主代理。主代理可以把互不覆盖的生产实现、独立参考实现、渲染器或测试夹具交给多个子代理并行完成，但必须亲自完成以下工作：

1. 冻结当前工作包的 Schema、算法卡和验收条件；
2. 确保生产实现与参考实现不共享关键领域逻辑；
3. 审查差异、边界、许可证和性能结果；
4. 合并公共契约并更新能力状态；
5. 对发布结果承担唯一验收责任。

子代理不能自行新增公共 ID、修改 Canonical Schema、批准自己的算法卡或把能力标为 Stable。

## 4. 开工顺序

第一批开发严格按以下顺序执行：

1. M0：重组 Monorepo、Compose、CI，并让 Schema/OpenAPI 校验成为合并门禁；
2. M1：实现数据库、RLS、不可变对象版本、TimeSpec、Location 和 DatasetVersion；
3. M2：实现 Swiss Ephemeris Adapter、JPL 独立校验与 CalculationSnapshot；
4. M3：实现宫位、轴点、相位、统计及专业数据表；
5. M4：实现六类入口、Draft、Recipe Resolver、Job/SSE 和 SDK；
6. M5—M6：实现 Alpha 行运、返照、关系、轮盘、报告和导出闭环。

M7—M24 的逐月交付与验收不在本文重复，直接执行机器可读 Backlog。任何月度任务如果缺 Schema、算法卡、数据许可或测试夹具，先补齐该输入，不允许用临时代码绕过。

## 5. 测试与发布证据

| 测试类型 | 规范 |
|---|---|
| 金标准 | [`../tests/gold/specs/fixture-contract.yaml`](../tests/gold/specs/fixture-contract.yaml)、[`../tests/gold/specs/seed-cases.yaml`](../tests/gold/specs/seed-cases.yaml) |
| 独立差异 | [`../tests/differential/specs/matrix.yaml`](../tests/differential/specs/matrix.yaml) |
| API/Schema 契约 | [`../tests/contracts/specs/matrix.yaml`](../tests/contracts/specs/matrix.yaml) |
| 视觉目录覆盖 | [`../tests/visual/specs/catalog-coverage.yaml`](../tests/visual/specs/catalog-coverage.yaml) |
| 性能预算 | [`../tests/performance/specs/budgets.yaml`](../tests/performance/specs/budgets.yaml) |
| 备份与故障恢复 | [`../tests/operations/specs/recovery-matrix.yaml`](../tests/operations/specs/recovery-matrix.yaml) |

`Stable`不是计划标签。只有实现、算法卡批准、金标准、独立差异、契约、边界、性能、文档和复现门禁都通过后，能力才能升级为 Stable。

## 6. 当前仍然阻断的事项

- 所有外部数据包在实际下载前仍缺精确版本、文件清单与 SHA-256，不能发布生产数据集；
- `Tertiary II`、`Quartary`等命名不统一的推运变体必须先锁定原始来源与独立夹具，当前按研究阻断返回；
- 1970 年前部分历史时区、唯一出生时间校正、公众人物精确出生时间和事件客观概率没有可靠统一答案；
- 商业专有报告、权重或计算方法没有书面许可时不得进入规则库；
- 当前前端仍是交互原型，`db/`和`worker/`仍是脚手架，不是后端实现。

这些阻断项已经有显式降级或未来路线，不影响从 M0 开始实现可验证的专业平台基线。
