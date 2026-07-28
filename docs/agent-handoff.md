---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '3074bf76-23a0-48d3-b468-43b75e4460c8'
  PropagateID: '3074bf76-23a0-48d3-b468-43b75e4460c8'
  ReservedCode1: 'd98d0649-575e-4872-a230-480849902d3b'
  ReservedCode2: 'd98d0649-575e-4872-a230-480849902d3b'
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

日返盘、月返盘、日弧盘、三限盘等均只有 Obsidian 设计文档和基础 workspace 框架，尚未实现右侧即时解读和底部展开解读。（行运盘已有完整 V3.0 设计，见 5.2）

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

- **API 代理**：`compose.app.yaml` 部署缺少 Caddy 反向代理配置，生产环境通过 `infra/deploy/Caddyfile.fate` 解决。需要后续统一处理。
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

> AI生成