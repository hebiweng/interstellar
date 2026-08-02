---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: 'd1edba42-7ee5-470d-bd3a-c49398d28540'
  PropagateID: 'd1edba42-7ee5-470d-bd3a-c49398d28540'
  ReservedCode1: '2d3aa5d3-b310-48c8-9246-8b7fae9ba55f'
  ReservedCode2: '2d3aa5d3-b310-48c8-9246-8b7fae9ba55f'
---

# Interstellar — Agent 入口规范

> 任何 agent 或工程师接手本项目时，先读此文件，再读 `docs/ios-v6-rebuild-plan.md`、`docs/ios-card-implementation-matrix.md` 和 `docs/agent-handoff.md`。

---

## 1. 接手前必读顺序

```text
1. AGENTS.md（本文件）
2. docs/ios-v6-rebuild-plan.md ← 当前 iOS 产品与实施合同
3. docs/ios-card-implementation-matrix.md ← 六盘卡片合同
4. docs/agent-handoff.md       ← 当前状态与交接
5. 当前代码、测试和私有内容 Schema
```

`docs/chart-insight-design-standard.md` 仅在处理仍沿用旧 Web 跨盘型架构时阅读。Obsidian 不在现阶段默认阅读链路中。

---

## 2. 产品体验红线

以下不是建议，而是所有 Web / iOS 消费者界面的强制产品标准。实现、评审和验收都必须逐项检查。

1. **先给结论，再给参数**：首屏先回答用户关心的生活问题，专业事实进入展开层；不能用参数列表代替产品设计。
2. **消费者语言**：中文就只显示中文，英文就只显示英文；默认英文。文案必须通俗、自然、具体，禁止研究报告口吻、内部设计说明和明显 AI 套话。
3. **真实数据驱动**：评分、波形、雷达、时间线、轮盘和卡片状态必须由真实计算事实映射；不得为了视觉效果填示例分数或伪造事件。
4. **设计稿是视觉参考，不是字段合同**：v6 原型用于校准信息密度、层级、构图和交互感受；最终字段以真实计算能力、当前产品设计和 `InsightCard` 合同为准。原型中重复、较弱或与现有设计冲突的内容可以合并或舍弃；不得退化成通用进度条、普通列表或任意图表。
5. **Today 是消费者首页**：v6 Today 固定采用 `Current Chapter / Active Today / Coming Next / Moon Today / Timeline / Upcoming Sky / Retrogrades / Current Sky` 导航结构。Today 只消费标准信号和私有短语料，不自行调用 AI，不显示盘型参数或“解读依据”。
6. **星盘可读性**：轮盘需要刻度、十二宫编号、上升/下降/天顶/天底、星体名称、度数、引线和回顾调整状态；不能只用消费者难以识别的占星符号。双轮区分内外盘，拥挤文字必须避让，增加信息后仍须在 iPhone 12 mini 可读。
7. **相位使用矩阵**：单盘采用三角相位矩阵；行运/次限等比较盘采用移动点 × 本命点交叉矩阵。节点网络不能作为正式 `Aspects` 主视图。
8. **卡片内容与版权分离**：公开代码可以包含布局、Schema 和渲染逻辑；完整原创摘要、详情和选择规则使用私有内容包，不能进入公共 Git、日志、测试附件或示例截图文本。
9. **短解读与 AI 详情分层**：每个可见事实固定呈现“计算结果 + 一句自然解读”。短解读来自私有、已审核内容包，不能由 Swift 拼句。约 100 字详情和整盘专业报告由 AI 基于当前整盘事实一次生成并保存在本机，不属于固定 corpus，也不能写回 Snapshot。
10. **不以能运行代替完成**：骨架、占位卡、通用图表和临时文案只能算接线完成；只有通过视觉、内容、数据、小屏、无障碍和私有内容边界验收才算产品完成。
11. **Today 只消费标准信号**：Today 只能接收盘型 provider 输出的标准化信号与已计算事件，不能直接判断盘型。新增盘型必须通过注册 provider 接入，不能在 Today 页面增加盘型分支。
12. **Today 文案只来自私有内容系统**：当前章节、今日活跃、接下来、时间线和天空事件的消费者解释不得在 Swift 中写解释性降级句；内容键缺失必须明确失败。
13. **预设语义一致**：消费者界面只提供 Modern / Classical。行运和次限是比较盘；选择任一预设后，移动盘和作为参照的本命盘必须按同一预设重新计算。本命页自己的预设不得偷偷影响其他盘；旧版 `Special` 只允许作为数据解码兼容值存在，不能重新出现在首版界面。
14. **人物与地点是正式能力**：Profile 必须能管理本人及其他人物，人物包含关系、头像、出生时间、地点、时区和可编辑经纬度。选址必须请求当前位置、打开 Apple 地图、支持搜索/点选、反向地理编码并自动匹配时区。
15. **专业事实与消费者正文分层**：精确度数、相位种类和矩阵参数可以保留在轮盘/相位事实层；摘要、详情、Today 和卡片解释必须在内容包构建阶段映射为通俗语言，例如明显程度、正在增强/缓和、生活领域和回顾调整期。
16. **六盘范围冻结**：本轮实现本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8 张卡。Composite、跨设备报告同步、Web 消费端改造和旧 `/admin` 迁移延期。Ask 与 Profile 的既有产品能力继续保留，不因 v6 原型未覆盖而删除。
17. **AI 本机长期权威**：同一语义指纹命中本地 `GeneratedChartArtifact` 时禁止联网。本机产物不设 TTL；Relay 只允许保留最长 24 小时的加密幂等缓存。撤回授权后仍可读已有报告，人物删除必须清理关联产物。
18. **语料上线双门禁**：`approved` 只表示文案审核通过，不代表结构合法。正式包中的每条内容必须同时为 `approved` 且通过 JSON Schema、强类型变量、稳定 selector、事实引用和卡片合同完整性校验；失败时禁止构建、测试和 CI 继续，不得静默忽略。
19. **变量上限按职责区分**：技术事实模板允许最多 3 个已声明的强类型变量，例如 `planet + sign + house` 或 `bodyA + aspect + bodyB`；技术模板只能陈述事实。消费者标题、解释正文和建议句原则上 0 个变量，确有必要最多 2 个，不得依赖多变量机械拼接承担解释。
20. **语言交付边界**：英文和简体中文的正式短语料必须随版本上线。西班牙语和法语先提供语言切换与必要组件翻译，尚未交付审核语料的消费者正文明确回退到英文，不回退到中文或临时机器翻译。
21. **本地化资源分层**：按钮、Tab、页面标题、设置、权限、加载和错误等固定 UI 进入 `Localizable.xcstrings`；行星、星座、宫位、相位、月相和盘型等进入四语 `AstroTerms`；卡片与 Today 消费者正文只进 Copy Catalog。动态日期、时间、数量、单复数和语序通过 Locale-aware formatter 处理；禁止继续新增 Swift 双语硬编码或按英文词序机械插值。

---

## 3. Obsidian 使用规则

```text
Obsidian = 可选历史调研与旧语料素材
项目内 v6 文档、Schema、代码和测试 = 产品 / 运行时 / 工程 / 验收权威源
```

1. 当前 v6 任务默认不读取 Obsidian，不从 Obsidian 推导卡片字段、数量、顺序或视觉。
2. 只有项目内 v6 合同、代码和私有内容素材都无法解决明确缺口时，才允许定向查询 Obsidian；查询前必须先确认缺口。
3. Obsidian 内容只能作为候选素材，不能覆盖当前产品决策；有用内容必须重写进项目内私有 corpus / rules 或正式文档。
4. 运行时代码不能直接依赖 Obsidian；Obsidian 原文不能直接成为消费者文案。
5. Obsidian 与 `docs/ios-v6-rebuild-plan.md`、卡片矩阵或当前代码合同冲突时，一律以后者为准。
6. 不得因为 Obsidian 或原型未覆盖 Ask、Profile 等既有设计而删除、降级或阻止实现。

正确流程：

```text
确认项目内存在明确缺口
→ 定向查询 Obsidian（可选）
→ 筛选并重写候选素材
→ 写入项目内 corpus / presentation-rules / docs
→ UI 只消费项目内内容
```

错误流程：

```text
默认遍历 Obsidian 后再开始实现  ← 禁止
读 Obsidian → 直接写 UI         ← 禁止
运行时代码 import Obsidian     ← 禁止
把 Obsidian 讨论口吻给用户看   ← 禁止
```

---

## 4. 计算层、客户端与 AI 的职责边界

### 服务器或本地 AstroCore 负责权威事实

Web 以服务器返回的 Snapshot 为权威；离线 iOS 以本地 AstroCore 生成的不可变 Snapshot 为权威。权威事实包括星历计算、黄道与宫位、点位、相位、跨盘相位、ingress/egress/exact 日期、地点/时区/经纬度和可审计计算版本。

### 客户端负责展示层派生

浏览器端可以做：右侧即时解读卡片、可视化组件、根据服务器事实选择语料、空状态、排序和过滤、不改变事实的文案组织。

### 展示层不能伪造权威事实

Web 展示层不能绕过服务器自行补算；iOS 展示层不能绕过 AstroCore 自行补算。两端都不能补不存在的相位、推断没有计算依据的精确日期、把弱信号包装成强信号或制造 ingress/egress。

### AI 只解释，不计算

AI 只能读取已计算好的事实，生成解释文本。AI 不能：算星盘、改星盘、覆盖服务器事实、生成服务器没返回的相位/宫位/日期、把推测写成计算结果。

---

## 5. 盘型解读分层

每个盘型的解读必须按以下分层实现：

```text
后端事实
→ insight builder（选择事实、填变量、过滤噪声）
→ corpus 语料（提供可复用文案）
→ presentation rules 展示规则（定义模块和禁忌）
→ React 固定模板（只渲染固定结构）
→ CSS 独立样式（只控制视觉）
```

iOS 对应链路为：

```text
ChartSnapshot / Aspect / Event
→ StandardSignalBuilder（标准信号）
→ CardEvidencePlanner（卡片事实与稳定 sourceFactIDs）
→ ThemeMapper（仅映射主题，不生成正文）
→ CopyCatalogMatcher（稳定 selector + 已审核完整句）
→ CardTextModel（计算结果 + 一句自然解读）
→ InsightCard / Today
→ GeneratedChartArtifact（本机 AI 详情与整盘报告）
```

每个分层对应的文件位置：

| 分层 | 文件模式 |
|---|---|
| insight builder | `app/lib/insight/{chart}.ts` |
| corpus 语料 | `app/lib/insight/{chart}-corpus.ts` |
| corpus 组合句 | `app/lib/insight/{chart}-corpus-combinations.ts` |
| presentation rules | `app/lib/insight/{chart}-presentation-rules.ts` |
| 共享工具 | `app/lib/insight/shared.ts` |
| React 组件 | `app/components/workspaces/{chart}-instant-insight.tsx` |
| CSS | 独立 CSS 文件 |

---

## 6. 禁止事项

### 6.1 Obsidian frontmatter 规范

所有 Obsidian `.md` 文件必须包含以下 frontmatter 字段：

```yaml
created: YYYY-MM-DD    # 文件首次创建日期（新建时写入，后续不修改）
updated: YYYY-MM-DD    # 文件最后修改日期（每次修改时更新）
author: 创建者          # teleagent / codefree / codex / human
modified_by: 最后修改者 # 同上
```

详细规范见 `docs/chart-insight-design-standard.md` 第 10 节。

- 运行时代码依赖 Obsidian 目录
- 把内部说明写进消费者 UI
- 硬编码当前样例的特定数值
- 在消费者代码中使用内部话术（"人话""怎么用""别误读""模板回答"等）
- 服务器没返回的事实由客户端伪造
- AI 计算星盘或覆盖服务器事实
- 次限盘样板退化（5 个模块 id 缺失）
- page.tsx 变胖（不能有 `"use client"`、不能持 React state、不能直接 fetch）
- 未经架构检查和 lint 就提交
- 改完不更新 `docs/agent-handoff.md`
- 用占位参数页、节点网络或通用图表宣称产品视觉已完成
- 用示例分数、硬编码波形或虚构时间线增强视觉
- 把未经人工审核的临时摘要/详情标为 approved
- 未做 iPhone 12 mini 小屏检查就验收轮盘、矩阵或卡片

---

## 7. 固定实现与验收流程

每次重要任务完成后：

1. **材料核对**：阅读 v6 执行合同、卡片矩阵、当前代码与测试；只有发现明确缺口时才定向查 Obsidian。
2. **事实映射**：逐个视觉标明计算输入、映射公式、空状态和降级方式；禁止先画假数据再补逻辑。
3. **内容映射**：为一句短解读建立内容键和来源记录；未经审核只能标为 draft/sample。AI 详情只建立事实证据合同，不写进固定 corpus。
4. **实现分层**：事实 → builder → 私有 corpus/rules → 固定组件；运行时不得读取 Obsidian。
5. **视觉核对**：iOS 六盘先逐项核对 `docs/ios-card-implementation-matrix.md`，再参考 v6 原型检查层级与密度；卡片数量、顺序、独立图形、真实事实、短解读、AI 状态和空状态任一缺失都不能通过。
6. **小屏核对**：至少按 iPhone 12 mini 宽度检查轮盘、矩阵、卡片、长英文、中文和 Dynamic Type。
7. **自动验证**：运行适用的单元测试、构建、`scripts/check-ios-card-contract.sh`、`npm run ios:localization:validate`、`npm run architecture:check`、`npm run lint -- --quiet` 和私有内容泄漏检查。
8. **人工验收记录**：在首版计划中勾选有证据的项目，并更新 `docs/agent-handoff.md`；没有证据不得标完成。
9. **翻译交付**：运行 `node scripts/export-ios-translation-worklist.mjs`，按稳定 ID 交付中英摘要、详情、占位符、语气和优先级；译者必须原样保留 `{{...}}` 占位符。

每次验收至少确认：

- Today 是否符合 v6 八模块结构，且不以盘型参数或来源说明为主体；
- 可视化是否全部来自真实计算数据；
- 轮盘与相位矩阵是否在 iPhone 12 mini 可读；
- 行运/次限的移动盘与本命参照是否使用同一个所选预设；
- 人物关系、头像、地图点选、自动时区和可编辑经纬度是否成立；
- 卡片是否达到 v6 视觉密度，并在原型字段与当前产品设计冲突时遵守当前卡片合同；
- 消费者代码是否无内部话术、AI 套话和未审核语料；
- 私有摘要、详情、规则是否未进入公共 Git；
- 空状态、数据不足、中文和英文是否各自成立；
- 次限盘既有模块是否没有退化。

---

## 8. 完成后必须做的事

1. 更新 `docs/agent-handoff.md`：记录最近完成、当前状态、未完成能力、下一步注意事项
2. 确认架构检查通过
3. 确认未改无关业务

---

## 9. Docker 与部署

- 开发环境：`compose.yaml` + `compose.app.yaml`（注意不是 `docker-compose.yml`）
- 生产环境：`infra/deploy/` 目录下的 `compose.production.yaml` + `Dockerfile.web` + `Caddyfile.fate`
- 当前 iOS Relay 权威域名：`https://aaadmin.xiaoguiwk.top`；App 生成 API、独立管理页根路径和 `/xiaoguiwk` 共用此域名，不依赖暂停维护的 Web 消费端
- Relay-only 部署使用 `infra/deploy/compose.relay-only.yaml`，只启动 Caddy 与 Relay；旧 Web/API 容器保持停止但不删除
- 开发环境使用 volume mount 热更新，生产环境代码 bake 进镜像
- linux/amd64 镜像必须在本机或 CI 构建并传输，低内存生产服务器只允许加载镜像与切换 Compose，不得现场编译
- API 代理：生产环境通过 Caddy 反向代理解决，不依赖客户端直连

---

## 10. 标准任务提示
### App Attest 临时状态

当前未购买 Apple Developer Program，因此 **App Attest 校验已临时关闭**以便继续真机测试：

1. `infra/deploy/compose.production.yaml` 与 `infra/deploy/compose.relay-only.yaml` 中 `RELAY_ALLOW_DEV_BYPASS` 暂设为 `"1"`；
2. `ios/App/AIGeneration.swift` 中 Debug 构建（`#if DEBUG || targetEnvironment(simulator)`）直接返回 `X-App-Attest-Development-Bypass: 1`；
3. 上线前必须重新启用：购买 Apple Developer Program，恢复 `DEVELOPMENT_TEAM` 为 `YD3FY9ZB52`、在 `ios/App/Interstellar.entitlements` 中恢复 `com.apple.developer.devicecheck.appattest-environment`，并将 `RELAY_ALLOW_DEV_BYPASS` 改回 `"0"`，然后验证生产 App Attest 链路。

以后给任何 agent 任务时，可以使用以下提示：

```text
你现在接手 Interstellar 项目。先阅读 AGENTS.md、docs/ios-v6-rebuild-plan.md、docs/ios-card-implementation-matrix.md 和 docs/agent-handoff.md，再阅读当前代码与测试。现阶段不要默认读取 Obsidian。

任务：按 v6 执行合同推进当前盘型。项目内合同、Schema、代码和测试是权威；只有项目内资料确实不足时才定向查询 Obsidian，并把筛选后的内容重写进私有 corpus/rules；运行时代码不得依赖 Obsidian。

Web 以服务器 Snapshot 为权威，离线 iOS 以本地 AstroCore Snapshot 为权威；展示层只能做不改变事实的派生；AI 只能解释已算事实，不能计算或覆盖事实。

严格遵守本文件“产品体验红线”和“固定实现与验收流程”。不要把内部说明写进消费者 UI。不要改无关业务。完成后运行适用的测试、构建、架构检查、lint 和私有内容泄漏检查，并更新首版计划与 docs/agent-handoff.md。
```

> AI生成
