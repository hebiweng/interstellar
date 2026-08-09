# Transit 收口与整盘 AI 报告实施计划

| 字段 | 值 |
|---|---|
| 状态 | 核心改造已完成，真机验收与 P1 边界待收口 |
| 日期 | 2026-08-09 |
| 范围 | iOS Transit、整盘 AI Report、Go Relay、Classical 边界与验证 |
| 明确排除 | Today、新增六卡语料、其他盘型迁移、独立 AI 报告规划架构 |

本文整理当前 Transit 收口工作的最终实施口径。它记录最新产品决定和代码核对结论；实施完成后必须同步 `AGENTS.md`、`docs/ios-v6-rebuild-plan.md`、`docs/ios-card-implementation-matrix.md` 与 `docs/agent-handoff.md`，消除现有旧合同冲突。

## 1. 已确认的产品决定

1. Transit 六张卡、现有 `TransitContentPlanner`、UI 和 Copy Catalog 保持不变。
2. 永久取消单卡约 100 字 AI 详情；AI 只生成一份完整整盘报告。
3. 整盘报告尽可能解释程序已经计算的完整 Transit 与 Natal 结果，不以六卡容量作为证据边界。
4. AI 只负责归纳、组合和解释；不得重新计算星体位置、宫位、相位、orb、日期、strength、score、Modern role/theme 或 Classical condition/reception/score。
5. 继续复用现有 AI `facts`、request、`factsHash`、`semanticFingerprint`、`GeneratedChartArtifact` 和 Relay `evidenceFactIDs` 验证。
6. Today 本轮不处理；其他盘型在 Transit 冻结后再迁移。
7. 六盘报告统一按需生成：只有用户在 Reports 中明确点击才请求；同语义默认复用，重新生成成功后覆盖，失败保留旧报告。

## 2. 明确不新增的架构

本轮不新增：

- `TransitAIReportPayload`
- `TransitReportPlan`
- `TransitInterpretationPlan`
- Report Planner
- Reference Closure Resolver
- topic → fact 映射
- must-cite / available-facts 体系
- AI 层 Top N、强弱过滤或 Modern/Classical 二次判断
- AI 层 assessment 推导
- 独立 `natalReferences`
- `reportPayloadHash`
- 独立 `contractVersion`
- AI 层第二套排序或去重系统
- Artifact evidence manifest

目标链路保持为：

```text
Transit Snapshot / Comparison / Events
                ↓
       TransitFactBundle
          ├─→ Existing Card Planner → 六卡 + Copy Catalog
          └─→ 现有 AI facts 稳定序列化
                         ↓
                     Go Relay
                         ↓
                  整盘 AI Report
                         ↓
              GeneratedChartArtifact
                         ↓
                     App 渲染
```

## 3. 当前代码基线

### 3.1 已进入 AI 请求的数据

当前 Transit AI 请求已经包含：

- 完整移动盘 Snapshot：时间、Julian Day、四轴、十二宫宫头、点位、速度、逆行、移动盘内部相位；
- 完整 `reference` 本命盘：时间、四轴、十二宫、本命点位、落座落宫、本命内部相位；
- `comparisonAspects`：moving body、natal body、aspect kind、phase、orb、strength；
- Transit windows、planet placements、planet events、十二 Life Areas 和 Calendar facts；
- preset、人物 hash、参数、locale、`factsHash`、`semanticFingerprint` 和 `generationSchemaVersion`。

完整本命资料已能通过 `comparisonAspects[].second` 与 `reference.points[].id` 关联，因此不新增 `natalReferences`。当前 AstroCore comparison 只计算移动点 × 本命点，不计算移动点对本命 ASC/MC 的相位；若未来需要该能力，应扩展 AstroCore，而不是补 AI 数据类型。

### 3.2 本轮已完成

- iOS 与 Relay 已切换为 report-only，删除单卡请求、响应、状态、精确覆盖和长度合同；
- 六盘均改为 Reports 内用户明确触发，支持本机复用和显式重新生成；
- Transit 直接序列化六类 preset-specific Bundle facts，不再以六卡 `TransitContentPlan` 为证据边界；
- 已补齐 aspect/window/placement 的已有字段和 Classical assessment；
- 已删除 `source-reference` 占位，Calendar contributor 解析为正式、可引用的 evidence；
- Transit 请求不再混入通用 progressed/solar-return events；
- Relay Prompt 已优化为整盘综合分析，报告为 4–8 节，并禁止重新计算；
- Classical 五种角色已使用独立 label/tone/icon/accessibility 映射。

### 3.3 尚未完成

- trueNode policy 与聚合前边界；
- Classical contract validator 的 body/fact/role/theme/aggregation 完整约束；
- 7/30/365 实现与 7/30/90 合同的 Horizon 决策；
- focused Transit 是否补完整 events/calendar；
- iPhone 12 mini 的 App → Relay → DeepSeek → 本地 Artifact 实际 UI 闭环。

### 3.3 当前 ID、排序和重复事实

- 六类正式 Transit fact 都已有稳定 `factID`；
- Relay 实际验证 `facts.evidenceFacts[].id`，AI response 的 `evidenceFactIDs` 必须来自该集合；
- 当前 `transitEvidenceFacts` 已按 ID 排序；Planner 的主要排序有稳定 tie-breaker；
- 正常生产 Bundle 未发现重复事实；现有字典去重主要合并同一 fact 被多个卡片引用的情况；
- 当前请求存在同一事实的多种表示，例如 `chart.points` 与 placement evidence、`comparisonAspects` 与 aspect evidence，第一版允许保留。

## 4. 优先级总览

| 优先级 | 工作 | 目标 |
|---|---|---|
| P0-1 | 整盘 report-only 切换 | 永久删除单卡 AI 请求、响应、状态和缓存合同 |
| P0-2 | Classical AI Evidence | 将 Bundle 已有古典计算结果完整传入 AI |
| P0-3 | Classical Role Presentation | 修复五种古典角色全部落入 `SUPPORTING` 的错误 |
| P1-1 | 正式 Bundle evidence | 直接序列化六类 Bundle fact，退出六卡 AI evidence 边界 |
| P1-2 | source-reference 清理 | 只允许正式 fact 成为可引用 evidence |
| P1-3 | Transit events 清洁 | 排除其他盘型事件，避免 focused context 污染 |
| P1-4 | Classical Node Policy | 在聚合前落实 trueNode 边界 |
| P1-5 | Classical Validator | 验证 body、fact、role、theme、聚合来源与 preset |
| P1-6 | Horizon 合同 | 统一 7/30/365 与文档 7/30/90 冲突 |
| P2-1 | 缓存隔离测试 | 保证 Modern/Classical 不能串缓存 |
| P2-2 | 稳定性与唯一性测试 | 保证相同输入产生稳定 IDs、顺序和 `factsHash` |
| P2-3 | Artifact 兼容测试 | 新 report-only Artifact 不误读或破坏旧报告 |

Today 的旧行运解释链路问题仍存在，但按当前决定不纳入本轮。

## 5. P0 实施任务

### P0-1：永久删除单卡 AI 合同

#### iOS 删除

- `AIGenerateResponse.CardDetail`
- `AIGenerateResponse.cards`
- `AIChartContent.cardDetails`
- `AIChartContent.statusByCard`
- `AIDetailStatus`（确认无其他用途后）
- `aiCardDetail(...)`
- AI 生成函数中的 `cardIDs`
- `allowedEvidenceByCard(...)`
- AI 专用 `cardContractVersion`
- 单卡生成中、失败、ready 状态循环
- `applyArtifact` 中的 card detail 处理
- `semanticFingerprint` 中的 `cardIDs` 与旧 card contract 身份
- `facts.cardIDs`
- AI 请求中的 `transitContentPlan`

`TransitContentPlan` 本地类型和六卡运行时用途必须保留，只从 AI facts/request 中退出。

#### Relay 删除

- `generateRequest.CardIDs`
- `generateRequest.AllowedEvidenceByCard`
- `chartCardContract(...)`
- card exact coverage validation
- card allowed-evidence validation
- `GenerationResult.Cards`
- Card detail 长度验证
- Prompt 中的 `cards` response schema
- `buildUserContent` 中 card IDs / allowed evidence
- Relay cache key 中 card evidence contract
- 相关 card AI fixtures/tests

#### 保留

- `AIReport` 和 4–8 节限制；
- 每节 `evidenceFactIDs`；
- 语言纯度、安全边界和一次非法 JSON 修复；
- report 的 title、subtitle、section number/title/body/callout，除非 UI 合同另行决定。

### P0-2：补齐 Classical AI Evidence

只序列化 Bundle 已有计算结果，不新建 AI 专用古典模型。

Aspect 必须补：

```text
cycleBand
classicalContext.movingScore
classicalContext.movingConditions
classicalContext.receptionFromMoving
classicalContext.receptionFromReference
```

Placement 必须补：

```text
classicalScore
classicalConditions
```

以下字段属于六卡 Planner 语义，不作为本轮整盘报告的必传字段：

```text
classicalSignalRoles
classicalIntegratedThemeID
classicalThemeID
```

Modern 的 `integratedThemeID`、`signalRoles` 和 `themeInputs` 同样继续服务六卡，不要求随 report-only 请求传入。

### P0-3：修复 Classical Role Presentation

Modern 与 Classical 使用独立 presentation mapper。至少保证：

```text
beneficSupport   → SUPPORT
maleficPressure  → PRESSURE
fortified        → FORTIFIED
impaired         → IMPAIRED
received         → RECEIVED
```

测试必须覆盖：

- label
- semantic tone
- icon
- accessibility meaning

## 6. P1 实施任务

### P1-1：直接序列化完整 TransitFactBundle

新增一个小型内部 helper 让 AI facts 构建能拿到与六卡相同的 `TransitFactBundle`，不新增 AI Payload 类型。

```text
当前：Bundle → ContentPlan.cards.flatMap(evidence) → evidenceFacts
目标：Bundle 六类事实 → transitEvidenceDocument → evidenceFacts
```

六类事实：

- aspect
- window
- planet event
- placement
- life area
- calendar

Window 需要补齐已有字段：

```text
movingID
referenceID
aspect
movingLongitude
natalHouse
cycleBand
```

AI 层不新增强弱筛选、Top N 或 assessment 推导。AstroCore 已有 orb 门槛，AI 根据提供的 strength、orb、phase、score、timing 和 assessment 判断篇幅。

### P1-2：清理 source-reference

- 不再生成 `{ id, kind: "source-reference" }` 占位 evidence；
- 正式 Bundle fact 才能进入 Relay 可引用 evidence 集合；
- window 的 source aspect 和 Life Area contributor 应引用正式 Bundle fact；
- Calendar 的每日 contributor key 可以保留为内部 provenance，但不得升级为可引用 evidence，也不为本轮生成数千个每日 aspect fact；
- AI 引用 Calendar 时使用 Calendar fact 自身的 `factID`。

### P1-3：清理 Transit events 数据

- Transit AI 不再消费含 progressed/solar-return 内容的通用 `facts.events`；
- 使用 Bundle 的 `TransitWindowFact`、`TransitPlanetEventFact` 与 `TransitCalendarFact`；
- 验证 windows、sign/house ingress、station 和 calendar 在默认 Transit 上正常生成；
- focused Transit 不得错误复用主上下文的事件。

focused 任意探索日期是否重新扫描完整一年事件，作为独立性能决策：

- 最小方案：缺少对应计算时明确为空，只报告即时 Snapshot/comparison；
- 完整方案：按 focused 日期重新计算并缓存 windows/events/calendar，同时验证任务取消和真机性能。

未完成性能验证前，不默认采用完整方案。

### P1-4：Classical Node Policy

先确定正式合同，再改代码。当前建议 MVP：

| Node 能力 | MVP |
|---|---|
| technical placement | 允许 |
| Life Area contribution | 禁止 |
| classicalScore | 不计算 |
| dignity | 不计算 |
| reception | 不计算 |
| Current Story primary | 禁止 |
| conjunction technical evidence | 待产品确认 |
| 其他 aspects/events/narrative | 暂不进入 Classical |

Policy 必须在 Life Area、event 和 calendar 聚合前生效；Planner 下游过滤不能替代上游聚合边界。

### P1-5：加强 Classical Validator

Planning Validator 至少检查：

- `preset == classical`
- allowed bodies
- allowed fact types
- Node policy
- 十二 Life Areas 完整性
- Life Area contributor 合法性
- `sourceFactIDs` 合法性
- evidence ownership
- role/theme domain
- claim mode/card scope
- 无 Modern-only semantic fields

AI/Relay 继续独立验证 `evidenceFactIDs`，不把 AI JSON 结构塞进 Planner Validator。

### P1-6：统一 Horizon 合同

当前代码为 7/30/365，主合同和卡片矩阵仍写 7/30/90。产品若最终采用 Week/Month/Year，则定义为：

```text
week  = [anchor, anchor + 1 calendar week)
month = [anchor, anchor + 1 calendar month)
year  = [anchor, anchor + 1 calendar year)
```

需要写死：

- Gregorian Calendar 或产品指定 Calendar；
- Transit 显示时区；
- anchor 的本地日历边界；
- 半开区间 `[start, end)`；
- DST、闰年和 end boundary 测试；
- Bundle 最大计算范围覆盖 year。

不得继续以 `365 * 86_400` 定义产品语义上的 Year。

## 7. AI Prompt 与 Relay 最终合同

Transit Prompt 要求整盘综合，而非逐条复述：

- 当前整体趋势；
- 长期与中期影响；
- 近期关键变化；
- 事业与财务；
- 感情与人际；
- 个人成长与状态；
- 机会与支持；
- 压力与调整；
- 后续阶段变化。

AI 应根据已有 strength、orb、phase、score、timing、motion 和 assessment 判断轻重；同类事实可以综合，弱信号可以简略或忽略，没有明显信号的领域不得编造。

Relay 保留：

- response schema；
- report 必须存在；
- 4–8 sections；
- 每节 `evidenceFactIDs` 来自本次 `evidenceFacts`；
- locale 的 Prompt 选择和语言纯度验证；
- 请求顶层 preset 与 `facts.preset` 一致性；
- 一次非法 JSON 修复；
- Provider/model、App Attest、配额、审计和 24 小时缓存。

AI response 不需要重复返回 preset 或 locale。

## 8. Artifact 与缓存

继续复用：

```text
semanticFingerprint
chartKind
subjectHashes
parameters
locale
preset
factsHash
provider
model
promptVersion
generationSchemaVersion
generatedAt
report
```

report-only Schema 变化通过提升 `GeneratedChartArtifact.schemaVersion` / `generationSchemaVersion` 处理。

- `factsHash` 继续作为完整 AI facts 的输入 Hash；
- 不新增 `reportPayloadHash`；
- 不新增独立 contract version；
- semantic fingerprint 删除 `cardIDs` 和旧 `contract=3` 依赖；
- preset、locale 和现有参数继续参与身份；
- 旧 Artifact 中多余的 cards 字段可以忽略，已有合法 report 可兼容读取；
- Modern 与 Classical 必须生成不同缓存身份。

## 9. P2 测试与门禁

### 9.1 AI / Relay

- report-only request/response；
- 4–8 节与语言纯度；
- response evidence 全部来自 request evidence；
- 非法 evidence 拒绝；
- 非法 JSON 最多修复一次；
- preset 与 `facts.preset` 不一致时拒绝；
- 旧 cards 字段不再是必需合同；
- `factsHash` 往返一致；
- generation schema 往返一致。

### 9.2 Transit facts

- 六类 Bundle factID 非空且唯一；
- 相同输入产生相同 scopeID、factIDs、evidence 顺序和 `factsHash`；
- aspect/window/placement 完整字段序列化；
- Classical assessment 与对应 fact 对齐；
- Modern 请求不出现 Classical assessment；
- Classical 请求不出现 Modern-only semantic fields；
- Life Area contributor 符合 preset/Node policy；
- Calendar 不产生可引用的虚假 `source-reference`；
- Transit 请求不含 progressed/solar-return 事件。

### 9.3 UI / Artifact / Cache

- 五种 Classical role 的 label/tone/icon/accessibility；
- same chart + same anchor + different preset → different identity；
- Modern cache 不命中 Classical，反之亦然；
- 本地命中零网络；
- report-only Artifact 保存和恢复；
- 旧 Artifact 兼容读取策略；
- focused Transit 不使用错误事件上下文。

实施完成后运行适用的 iOS/Relay 单元测试、构建和项目门禁；只有修改 UI 时才需要补对应的小屏、浅深色、Dynamic Type 与 VoiceOver 人工验收。

## 10. 推荐实施顺序

为了保持每一步可构建、可回滚，按以下批次推进：

### 批次 A：事实序列化

1. 暴露/复用同一个 `TransitFactBundle`；
2. 直接序列化六类 Bundle fact；
3. 补齐 aspect/window/placement 遗漏字段；
4. 补齐 Classical Bundle assessment；
5. 删除 `source-reference` 占位 evidence；
6. 增加 facts 唯一性和稳定性测试。

### 批次 B：report-only 切换

1. Relay Prompt 改为整盘报告；
2. Relay response/validation 删除 cards；
3. iOS response model 和状态删除单卡内容；
4. AI request 删除 cardIDs/allowedEvidence/transitContentPlan；
5. 提升 generation schema；
6. 调整 fingerprint、Artifact 与兼容测试。

### 批次 C：Classical UI 与数据边界

1. 修复 Classical Role Presentation；
2. 确认 Node Policy；
3. 在聚合前实现 Node 边界；
4. 加强 Classical Validator。

### 批次 D：事件与 Horizon

1. 清理 Transit 请求中的跨盘事件；
2. 确认 focused Transit MVP 行为；
3. 如需完整 focused 事件，先做真机性能基准再实现；
4. 统一 Week/Month/Year Calendar semantics；
5. 同步权威文档。

### 批次 E：冻结

1. 完成 AI、Relay、Classical、缓存和 Artifact 集成测试；
2. 运行适用门禁与构建；
3. 更新 `docs/agent-handoff.md`；
4. 满足冻结条件后，才迁移其他盘型。

## 11. Transit 冻结验收条件

Transit 只有同时满足以下条件才可作为其他盘型的参考实现：

1. 六卡 ID、顺序、Planner、UI 和 Copy Catalog 未被 AI 改造破坏；
2. AI 只生成整盘 report，不再请求、返回或保存单卡详情；
3. Modern 报告能引用完整合法 Transit facts；
4. Classical 报告能读取计算层已有古典 assessment，不自行重算；
5. 所有 AI `evidenceFactIDs` 都来自正式 request evidence；
6. Transit AI 请求不混入其他盘型事件；
7. Classical role 展示语义正确；
8. Node 不通过 Life Area、Calendar 或其他聚合间接污染 Classical；
9. Horizon 合同、时区和日期边界一致；
10. Modern/Classical Artifact 与缓存严格隔离；
11. focused Transit 不使用错误上下文；
12. 相关测试、构建和项目门禁有通过证据。

## 12. 实施前仍需确认的产品决定

1. Classical Node conjunction 是否允许作为 technical evidence；
2. Node technical placement 是否允许进入 Classical 整盘报告；
3. focused Transit MVP 是否允许 windows/events/calendar 为空；
4. Horizon 是否正式定为 Week/Month/Year；
5. 整盘报告的固定主题列表是否只由 Prompt 管理。

除以上决策外，P0 report-only、Classical assessment 和 Classical role 修复均可直接实施。
