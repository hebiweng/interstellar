---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '34494ccb-cc28-432e-b94d-0fa46b12e4b2'
  PropagateID: '34494ccb-cc28-432e-b94d-0fa46b12e4b2'
  ReservedCode1: 'ebc985ef-ad99-4eb5-a2a8-77272cfb7a51'
  ReservedCode2: 'ebc985ef-ad99-4eb5-a2a8-77272cfb7a51'
---

# Interstellar — 上下文交接文档

> 每次重要任务完成后必须更新此文件。接手者先读此文件了解当前状态。

---

## 1. 项目概况

- **仓库**：`github.com/hebiweng/interstellar`
- **定位**：专业占星计算、研究、可视化与解读平台
- **技术栈**：Next.js / React / TypeScript / Tailwind CSS / Docker
- **当前主分支**：`dev`
- **远程仓库**：`origin` → `https://github.com/hebiweng/interstellar.git`

---

## 2. 部署信息

| 环境 | 配置 |
|---|---|
| 开发 | `compose.yaml` + `compose.app.yaml`，volume mount 热更新 |
| 生产 | `infra/deploy/compose.production.yaml` + `infra/deploy/Dockerfile.web` |
| 反向代理 | `infra/deploy/Caddyfile.fate` |

注意：不是 `docker-compose.yml`，是 `compose.yaml` + `compose.app.yaml`。

---

## 3. 最新重要提交

| 提交 | 说明 |
|---|---|
| `421b0d3` | docs: add cross-chart handoff plan |
| `dee5482` | fix: declare web runtime api arg |
| `612ed91` | fix: align production geonames paths |
| `31a78a5` | feat: stabilize secondary progression workspace |
| `538b186` | refactor: extract secondary progression logic into insight/secondary.ts, add shared.ts, split CSS |
| `1b51e76` | fix: graceful AI analysis error handling |
| `3f7a816` | fix: secondary progressions mobile layout + AI model_id |
| `0c2f02d` | feat: secondary progressions UI overhaul |

---

## 4. 已完成能力

### 4.1 次限盘（参考样板）

次限盘右侧即时解读已完整实现，是后续盘型的参考样板。

已固化内容：
- 右侧五张卡片（current-stage / change-themes / turning-points / stage-advice / natal-link）
- 卡片模块规则（`secondary-presentation-rules.ts`，60 行）
- 项目内语料（`secondary-corpus.ts`，561 行）
- 组合句模板（`secondary-corpus-combinations.ts`）
- 事实选择逻辑（`secondary.ts`，484 行）
- 共享工具（`shared.ts`，268 行）
- React 组件（`secondary-instant-insight.tsx`）
- 独立 CSS
- 月亮/太阳星座阶段进度
- 月相圆盘
- 支持/挑战/中性堆叠条
- 核心转折点固定三行
- 阶段建议固定三条
- 与本命关系固定两列
- AI 深度分析入口
- 架构检查（待实现为自动化脚本）

关键文件路径：
```text
app/lib/insight/secondary.ts
app/lib/insight/secondary-corpus.ts
app/lib/insight/secondary-corpus-combinations.ts
app/lib/insight/secondary-presentation-rules.ts
app/lib/insight/shared.ts
app/components/workspaces/secondary-instant-insight.tsx
app/components/workspaces/secondary-progressions-workspace.tsx
```

### 4.2 天象盘 Obsidian 设计文档

天象盘的 Obsidian 调研和设计文档已完成：

- `5-语料设计.md`：V3.0（iOS App 适配），8 卡片 A—H 专用语料，覆盖 22 章，新增 card_summary（20—30字底部摘要）和 card_detail（约100字展开解读）字段，语料质量标准增加 iOS App 文字层字数规范
- `6-解读设计.md`：V3.0（iOS App 适配），8 卡片 A—H 可视化设计，含平台设计原则、卡片文字层设计、卡片G天象演进、卡片H行星速览

### 4.3 行运盘 Obsidian 设计文档

行运盘的 Obsidian 设计文档已完成 V4.0 升级（iOS App 适配）：

- `5-语料设计.md`：V4.0（iOS App 适配），21 章，9 卡片 A—I 专用语料，新增：
  - **card_summary 字段**（20—30字底部摘要，始终可见）
  - **card_detail 字段**（约100字展开解读，解释视觉图表含义）
  - iOS App 文字层字数规范和质量标准
  - 保留四大语料体系（日活跃度指数、敏感度指标、趋势条件句、行运强度日历）
- `6-解读设计.md`：V4.0（iOS App 适配），22 章，9 卡片 + 顶部固定指数区 + 7 种多元视觉图表：
  - 仪表盘、波形线、甘特条、环形图、雷达图、双圈触发图、三段弧线、热力日历格
  - 卡片从天象盘的 5 张扩展到 9 张（新增 I 行运强度日历）
  - 平台设计原则（〇章）、卡片文字层设计

**行运盘与天象盘的核心差异**：
- 天象盘关注集体环境（8 类集体领域），行运盘关注个人影响（12 宫位个人领域）
- 天象盘是单盘，行运盘永远双盘（内圈本命 + 外圈行运）
- 天象盘语料视角是"集体环境中 XX 主题活跃"，行运盘是"你近期 XX 领域更容易出现变化"
- 行运盘新增了运势评分/概率/预测类功能（采用折中方案：数字可追溯到行运信号计算，点击可查看底层拆解）

### 4.4 跨盘型规范体系

三个规范入口文件已建立：
- `AGENTS.md`：Agent 入口规范
- `docs/chart-insight-design-standard.md`：跨盘型解读设计标准
- `docs/agent-handoff.md`：上下文交接文档（本文件）

### 4.6 七个主盘型全栈实现

三限盘、日返盘、月返盘、日弧盘、重置盘、12分盘、13分盘已实现完整前后端全栈。

后端（Python FastAPI）已完成：
- 7 个 Payload 模型（TertiaryProgressionPayload、SolarReturnPayload、LunarReturnPayload、SolarArcPayload、RelocationPayload、HarmonicChartPayload 等）
- ~12 个共享辅助函数（_natal_subject_context、_find_return_instant、_shifted_snapshot、_store_comparison、_residence_location 等）
- 7 个路由处理器（/calculations/tertiary-progressions、solar-return、lunar-return、solar-arc、relocation、dodecatemoria、tridecatemoria）
- Docker 环境全部 7 个端点已验证返回 HTTP 201

前端 API 客户端（interstellar-api.ts）已完成：
- 7 个 Result 类型（TertiaryProgressionResult、SolarReturnResult、LunarReturnResult、SolarArcResult、RelocationResult、HarmonicChartResult）
- 7 个 create 函数（createTertiaryProgression、createSolarReturn、createLunarReturn、createSolarArc、createRelocation、createDodecatemoria、createTridecatemoria）
- ensureReusableSnapshot() 共享辅助函数提取

前端 Workspace 组件已完成（全部重写为 API 集成版本）：
- 7 个 workspace 组件（左侧参数面板 + 计算 API 调用 + 中间轮盘/相位图渲染 + 右侧解读占位）
- `home-workspace.tsx` 中 7 个 `dynamic()` 导入 + 渲染分支
- `chart-constants.ts` 中 7 个盘型 status 改为 `"active"`
- 自动计算（部分盘型）和手动计算按钮（重置盘、月返盘）
- ComparisonWheel/NatalWheel/AspectGrid 渲染（根据盘型决定单盘/双盘）
- import 修复：NatalPointGroups/NatalPresetId 统一从 natal-presets 导入

盘型特定差异已正确实现：
- 三限盘：target_date + 双盘（内本命+外推运）+ 自动计算
- 日返盘：target_year + latitude/longitude + 双盘 + 自动计算 + A/B族预设切换 + 消除岁差开关 + 返照双盘内盘选择
- 月返盘：latitude/longitude + 双盘 + 手动计算 + A/B族预设切换 + 消除岁差开关 + 返照双盘内盘选择
- 日弧盘：target_date + 单盘 + 显示 arc_deg + 自动计算
- 重置盘：latitude/longitude + 单盘（无 comparison）+ 手动计算 + A族预设（与本命盘一致）
- 12分盘：最小参数 + 双盘 + 自动计算 + A/B族预设切换
- 13分盘：最小参数 + 双盘 + 自动计算 + A/B族预设切换

关键文件路径：
```text
# 后端
apps/api/interstellar_api/routers/m2_calculations.py（1833行）

# 前端 API
app/lib/interstellar-api.ts（~1350行，7个新 Result 类型 + 7个 create 函数）

# 前端 Workspace
app/components/workspaces/tertiary-progressions-workspace.tsx
app/components/workspaces/solar-return-workspace.tsx
app/components/workspaces/lunar-return-workspace.tsx
app/components/workspaces/solar-arc-workspace.tsx
app/components/workspaces/relocation-workspace.tsx
app/components/workspaces/dodecatemoria-workspace.tsx
app/components/workspaces/tridecatemoria-workspace.tsx
```

### 4.7 法达盘（Firdaria）右侧即时解读

法达盘右侧即时解读已完整实现，遵循次限盘样板架构模式。

已固化内容：
- 右侧五张卡片（current-period / period-combination / sect-context / transition / stage-advice）
- 项目内语料（`firdaria-corpus.ts`，7行星主题 + 昼夜起序 + 8主次组合 + 右侧展示语料）
- 事实选择逻辑（`firdaria.ts`，buildFirdariaRightPanel）
- React 组件（`firdaria-instant-insight.tsx`）
- workspace 组件已集成 `<FirdariaInstantInsight>` 替换原占位

关键文件路径：
```text
app/lib/insight/firdaria.ts
app/lib/insight/firdaria-corpus.ts
app/components/workspaces/firdaria-instant-insight.tsx
app/components/workspaces/firdaria-workspace.tsx
```

注意事项：
- 法达数据来自本命快照的 `result.firdaria`，无需独立 API 调用
- 语料中使用「」替代中文引号，因 TS 解析器会混淆中文引号与字符串定界符
- `FirdariaRightPanel` 类型从 `firdaria.ts` 重导出，React 组件从 builder 文件导入

### 4.8 小限盘（Annual Profections）右侧即时解读

小限盘右侧即时解读已完整实现，遵循次限盘样板架构模式。

已固化内容：
- 右侧五张卡片（current-year / year-lord / house-lord-combo / year-transition / stage-advice）
- 项目内语料（`annual-profections-corpus.ts`，12宫位领域 + 7时间主星主题 + 右侧展示语料）
- 事实选择逻辑（`annual-profections.ts`，buildProfectionsRightPanel）
- React 组件（`annual-profections-instant-insight.tsx`）
- workspace 组件已集成 `<ProfectionsInstantInsight>` 替换原占位

关键文件路径：
```text
app/lib/insight/annual-profections.ts
app/lib/insight/annual-profections-corpus.ts
app/components/workspaces/annual-profections-instant-insight.tsx
app/components/workspaces/annual-profections-workspace.tsx
```

注意事项：
- 小限数据来自本命快照的 `result.profections`，无需独立 API 调用
- `ProfectionsRightPanel` 类型从 `annual-profections.ts` 重导出

### 4.9 基础设施修复

本次会话修复了多个 TypeScript 编译错误：
- `secondary.ts`：11个错误（Set<string>、double asRecord()、: string 类型注解）
- `cloudflare.d.ts`：创建 Cloudflare Workers 环境类型声明
- `db/index.ts`：`env.DB as unknown as D1Database` 类型转换
- `next.config.ts`：`as NextConfig` 类型断言避免 `serverSourceMaps` 未识别

### 4.10 日返盘（Solar Return）右侧即时解读

日返盘右侧即时解读已完整实现，遵循六层架构模式，10 张视觉卡片。

已固化内容：
- 右侧10张卡片（A年度主轴罗盘 / B 12个月节律环 / C四季度地形图 / D年度领域天际线 / E关系气候带 / F事业定位阶梯 / G资源蓄水池 / H压力—机会桥 / I年度承诺追踪 / J年度行动路线书）
- 顶部固定区（年度主轴指数 0-100、状态标签、方向指示、Top3 信号）
- 项目内语料（`solar-return-corpus.ts`，406行，12节）
- 事实选择逻辑（`solar-return.ts`，563行，buildSolarReturnRightPanel + buildSolarReturnConsumerInsight + buildSolarReturnInterpretationSections）
- 展示规则（`solar-return-presentation-rules.ts`，10模块spec + 优先级 + 禁忌）
- React 组件（`solar-return-instant-insight.tsx`，340行，10个独立视觉卡片组件）
- 独立 CSS（`solar-return.css`）
- workspace 组件已集成 `<SolarReturnInstantInsight>` + `<NonNatalInterpretationSection>`

关键文件路径：
```text
app/lib/insight/solar-return.ts
app/lib/insight/solar-return-corpus.ts
app/lib/insight/solar-return-presentation-rules.ts
app/components/workspaces/solar-return-instant-insight.tsx
app/components/workspaces/solar-return-workspace.tsx
app/styles/solar-return.css
```

注意事项：
- `scoringRules` 使用 `as const`，调用处需类型转换
- 日返盘不需要 corpus-combinations 文件（Obsidian 设计未要求）
- 月份强度估算使用简易启发式，待后端提供月份触发器后替换

### 4.5 其他已上线功能

- 行运盘基础框架（`transit-workspace.tsx`）
- 天象盘基础框架（`current-sky-workspace.tsx`）
- API 基础设施统一（`caedd92` refactor(api) commit）
- 客户端 bundle 优化和 page.tsx 分拆
- AI 分析错误处理和友好提示
- 生产部署配置

---

## 5. 未完成能力

### 5.1 天象盘项目内实现

天象盘 Obsidian 设计已完成 V2.0，但尚未进入项目代码实现。注意：天象盘目前仍为纯文字 + 条形图方案，行运盘已升级为多元视觉 + 指数体系，天象盘可能需要同步升级（待确认）。需要：
- `app/lib/insight/current-sky.ts` — insight builder
- `app/lib/insight/current-sky-corpus.ts` — 语料库
- `app/lib/insight/current-sky-corpus-combinations.ts` — 组合句
- `app/lib/insight/current-sky-presentation-rules.ts` — 展示规则
- `app/components/workspaces/current-sky-instant-insight.tsx` — React 组件
- `app/components/workspaces/current-sky.css` — 独立样式

### 5.2 行运盘项目内实现

行运盘 Obsidian 设计已完成 V3.0（9 卡片 + 指数体系 + 7 种多元视觉），但尚未进入项目代码实现。需要：
- `app/lib/insight/transit.ts` — insight builder（含日活跃度指数计算、敏感度计算、趋势条件句生成、强度日历生成）
- `app/lib/insight/transit-corpus.ts` — 语料库（含四大新语料体系）
- `app/lib/insight/transit-corpus-combinations.ts` — 组合句
- `app/lib/insight/transit-presentation-rules.ts` — 展示规则（9 卡片 + 7 种视觉图表规则）
- `app/components/workspaces/transit-instant-insight.tsx` — React 组件（含仪表盘、波形线、甘特条、环形图、雷达图、双圈触发图、三段弧线、热力日历格）
- `app/components/workspaces/transit.css` — 独立样式

### 5.3 次限盘底部展开解读

次限盘右侧已完成，底部展开解读仍需后续专项设计。

### 5.4 其他盘型实现

7 个主盘型的前后端全栈已实现（见 4.6），Docker 环境验证通过。

法达盘和小限盘的右侧即时解读已完成（见 4.7、4.8）。

日返盘的右侧即时解读已完成（见 4.10）。

以下内容尚未实现：
- 右侧即时解读：4个盘型仍显示占位（三限/月返/日弧/重置，12分盘和13分盘无解读设计）
- 底部展开解读
- presentation-rules 文件：法达盘和小限盘尚未创建，当前功能正常但不影响运行
（行运盘已有完整 V3.0 设计，见 5.2）

### 5.5 架构检查自动化

`scripts/check-architecture.mjs` 尚未创建。计划检查项：
- 规范文件存在检查（AGENTS.md / docs/ 下两个文件）
- 运行时代码不依赖 Obsidian
- 消费者代码禁忌词检查
- 次限盘样板不退化
- page.tsx 保持薄入口

### 5.6 Obsidian 目录重组

当前 Obsidian 目录结构存在新旧两套路径（旧 `01-本命盘/` 格式和新的 `1-主盘型/01-本命盘/` 格式），git diff 显示大量删除和新增，需要完成目录结构统一并提交。

---

## 6. 接手前必读

1. `AGENTS.md` — 入口规范
2. `docs/chart-insight-design-standard.md` — 设计标准
3. 本文件 — 当前状态
4. 对应盘型 Obsidian 目录
5. 次限盘代码（作为样板）

---

## 7. 当前设计样板

次限盘是当前唯一完整实现的右侧即时解读样板。关键架构模式：

```text
服务器返回权威计算事实
→ 前端 insight builder 根据事实选择语料
→ 项目内 corpus 提供可复用文案
→ presentation rules 固定模块、视觉和禁忌
→ React 组件渲染固定卡片
→ CSS 独立控制盘型样式
```

天象盘和行运盘是下两个待实现的盘型：
- 天象盘：Obsidian V2.0（8 卡片，纯文字 + 条形图），可直接作为项目实现的输入
- 行运盘：Obsidian V3.0（9 卡片 + 指数体系 + 7 种多元视觉），需要更多前端图表组件支持

---

## 8. 下一步注意事项

1. **天象盘实现**：从 Obsidian 设计文档提取语料和规则，写入项目内 corpus/presentation-rules/builder 文件。注意 8 张卡片比次限盘多 3 张，需要在 presentation-rules 中定义完整模块。需要确认天象盘是否同步升级视觉和指数体系。
2. **行运盘实现**：V3.0 设计完成，需要实现 9 卡片 + 日活跃度指数 + 敏感度指标 + 趋势条件句 + 强度日历 + 7 种多元视觉图表。复杂度显著高于天象盘和次限盘。
3. **Obsidian 目录清理**：当前 git 中存在大量旧目录删除和新目录新增的未提交变更，需要一次性整理提交。
4. **架构检查脚本**：创建 `scripts/check-architecture.mjs`，把手动检查变为自动化。
5. **底部解读设计**：次限盘底部展开解读需要专项设计，当前右侧模块规则末尾注释了"底部解读区本轮暂不实现"。
6. **不要误改部署**：生产环境配置在 `infra/deploy/`，Caddy 配置不在客户端代码中。

---

## 9. 未解决问题

- **API 代理**（已修复 2026-07-30）：Next.js catch-all 代理 `app/api/v1/[...path]/route.ts` 去掉了 `/api/v1/` 前缀导致 404，已恢复。后端所有路由使用 `prefix="/api/v1"`，代理必须包含此前缀。
- **消费者代码禁忌词检查**：目前没有自动化检查，靠人工审查。
- **page.tsx 行数控制**：没有硬性行数限制，但原则是保持薄入口，不持 state、不直接 fetch。
- **语料缺口记录**：没有统一的语料缺口追踪文件，目前靠交接文档记录。

---

## 变更记录

| 日期 | 变更 |
|---|---|
| 2026-07-28 | 初始版本：记录次限盘样板完成、天象盘 Obsidian V2.0 完成、规范体系建立 |
| 2026-07-28 | 更新：补充行运盘 Obsidian V3.0 完成（9 卡片 + 四大新语料体系 + 7 种多元视觉），补充行运盘项目内实现待办，标注天象盘视觉升级待确认 |
| 2026-07-28 | 更新：天象盘 5-语料设计 V3.0、行运盘 5-语料设计 V4.0 完成 iOS App 适配，新增 card_summary/card_detail 字段和文字层规范 |
| 2026-07-30 | 更新：7个主盘型 workspace 框架全部创建并注册（三限/日返/月返/日弧/重置/12分/13分），状态改为 active，修复三限盘 import 顺序 |
| 2026-07-30 | 重大更新：7个主盘型全栈实现完成（后端7个API端点+前端7个API客户端+7个workspace组件重写），TypeScript 编译检查零新增错误，Docker 验证7个端点全部返回 201 |
| 2026-07-30 | 法达盘+小限盘右侧即时解读完整实现（corpus+builder+React组件），修复15个TS编译错误（secondary.ts 11个+基础设施4个），中文引号编码修复（3文件重写），TypeScript 编译零错误 |
| 2026-07-30 | 预设参数 Obsidian 对齐修复：重置盘从B族切回A族（natalCalculationPresets），日返/月返/12分/13分实现A/B族动态切换（单盘→A族、双盘→B族、切轮盘时自动换预设），日返/月返新增消除岁差开关和返照双盘-内盘选择器，badge不再显示族标识 |
| 2026-07-30 | API 代理修复：`app/api/v1/[...path]/route.ts` 恢复 `/api/v1/` 前缀转发，解决 `/subjects` 等端点 404 问题 |
| 2026-07-30 | 逐项选择修复：`SharedAdvancedCalculationFields` 去掉单项 `disabled={!groups[group]}`，改为组关闭时勾选单项自动开启组并仅启用该项。影响所有非本命盘（行运/天象/次限/三限/日返/月返/日弧/重置/12分/13分）。本命盘 `home-workspace.tsx` 仍有独立内联实现待统一 |
| 2026-07-30 | 日返盘右侧即时解读完整实现（10卡片A-J，6层架构），含corpus 406行+builder 563行+presentation-rules+React组件340行+独立CSS。布局修复：NonNatalInterpretationSection从workbench-grid内移出至外部（与次限盘一致），PC三栏布局验证通过（左=参数，中=星盘，右=解读） |

> AI生成