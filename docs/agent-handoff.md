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

### 4.6 iOS V1（`ios` 分支工作区）

iOS 首版已完成可构建的纵向实现，尚未提交或推送：

- SwiftUI 四栏：Today / Charts / Ask / Profile；
- 本命、天象、行运、次限四盘；
- Modern / Classical 两个消费者预设；旧 Special 仅保留持久化数据解码兼容；
- 单轮、双轮、单盘三角相位矩阵、跨盘交叉相位矩阵和固定解析卡片；
- Today 本地自然日事件扫描、本周 7 天行运信号密度，以及今日事件到精确事件时刻盘面的跳转；
- 英文默认、设置中切换简体中文；
- MapKit 地点搜索、手动经纬度和用户主动定位；
- 本地 Swiss Ephemeris 计算，不依赖 HTTP API；
- 私有中英文解析包通过 Git ignore 和泄漏脚本隔离；
- 新 App 图标、许可全文与内容版权声明。

验证证据：

- AstroCore 8 项测试通过，其中代表性星盘覆盖 8 个跨地区/年代实例；
- 通用 iPhoneOS 构建通过；
- 移除私有内容包后的临时公开工程仍可构建；
- `npm run architecture:check` 通过；
- `npm run lint -- --quiet` 通过；
- `scripts/check-private-content.sh` 通过。

当前剩余：飞行模式、小屏/无障碍、冷启动性能、英文完整翻译和发布前许可复核。

2026-07-29 消费者评审确认纵向骨架不能视为视觉完成，新增以下最高优先级返工：

- Today 不显示参数和四盘摘要，改为“今日主线 + 日内波形 + 感情/事业/财富/状态四领域雷达 + 信号驱动的接下来节奏”；四盘仅作为内部计算依据；
- 消费者文案不得把 Obsidian 的编写说明、图表解释或边界声明改写成正文；运行时从项目内私有 corpus/rules 选择通俗成品文案；
- 当前临时 28 条中文约 100 字内容未经人工审核，不能标记为 approved，需废弃或重做；
- 各盘卡片按 Obsidian 视觉示意逐张实现，不能继续以通用进度条、列表或雷达代替；
- `Aspects` 改为单盘三角矩阵、双盘交叉矩阵；
- 轮盘增加刻度、宫位编号、四轴、星体度数和状态层级，但保持 iPhone 12 mini 可读。

2026-07-29 消费者视觉首轮代码实现：

- Today 已改为今日主线、真实事件聚合的日内波形、四生活领域雷达、可切换领域摘要、信号驱动的接下来节奏和底部七天综合进展；四盘依据区已删除；
- Today 雷达与主线使用真实行运/次限跨盘相位强度及本命宫位映射，波形使用本地 `DailySignal` 的事件时间与强度；当前映射仍需补齐书面公式和黄金夹具；
- 轮盘已增加 1°/5°/10° 刻度、十二宫编号、ASC/DSC/MC/IC、星体度数、逆行标记和拥挤点引线；
- `Aspects` 节点网络已替换：本命/天象为下三角矩阵，行运/次限为移动点 × 本命点交叉矩阵；
- Today 正式标题和摘要通过私有内容键读取；公开 Swift 只保留最小事实降级句；
- Today 的领域映射、行运/次限权重、强度归一化和方向阈值采用公开 Schema + `PrivateRules-Today.json` 私有规则包；公共源码只保留可运行样例规则；
- 新增 Today 中英文示例均标记为 `sample`，旧的 28 条临时中文内容全部标记为 `draft`，`ContentProvider` 不加载 draft；
- 上述改动已通过通用 iPhone Debug 构建、AstroCore 8 项测试、架构检查、lint、JSON 校验和私有内容泄漏检查；
- 仍未完成 iPhone 12 mini 真机视觉、Dynamic Type、VoiceOver 和中英文逐屏验收，因此不能把消费者视觉标记为最终完成。

2026-07-29 四盘解析卡片专项实现：

- 新增 `docs/ios-card-implementation-matrix.md`，固定本命 5、天象 8、行运日指数 + 9、次限 5 张卡的顺序、ID、视觉与必显内容；
- `InsightVisual` 和 `InsightCards.swift` 已由通用模板改为 25 种专用视觉：三点人格结构、主题排行、优势环、盲点、成长路径、月相三周期、相位结构、八领域条形、演进叙事、半圆指数、节奏波形、甘特条、三段环、十二领域雷达、行动分区、三段弧线、双圈触发、本周 7 天热力格、长期阶段与本命对照等；
- 天象行星表和行运行星表不再截取前 6 个点，展示完整点集，并包含星座度数、顺逆行、速度；行运表另含本命宫位与最强触发；
- 所有卡片始终含摘要、展开详情和消费者可读空状态；私有内容包缺失时不显示内部加载说明；
- 新增 Debug 运行时卡片契约和 `scripts/check-ios-card-contract.sh`，检查 28 个固定卡片 ID、顺序、最低卡内事实数、8 个天象领域、12 个生活领域、完整星体表与本周 7 天；
- 通用 iPhone Debug 构建与卡片契约检查已通过；尚未做 iPhone 12 mini 真机视觉、长英文、中文、Dynamic Type、VoiceOver 和正式语料逐卡审核。

2026-07-29 iOS 独立语料系统与主题专项：

- 新增独立 Swift Package `ios/Packages/ContentKit`，包含稳定语义 ID、事实信号、corpus selector、优先级、去重组、composition binding、摘要/详情模板、长度约束和缺失内容失败策略；
- 新增 `InterpretationContextFactory.swift`，把本命、天象、行运、次限的真实点位、落座、落宫、相位、入相/精确/出相、逆行、月相、活跃宫位和行运日历统一为可审计查询上下文；
- 四盘 28 张卡片已全部改为 `AstroCore facts → InterpretationContext → ContentKit → PrivateCorpus`，`InsightFactory` 中旧的卡片级固定摘要和重复详情已删除；缺少必需语料时整盘解读明确不可用，不再伪装为成品文案；
- 本机私有区已按 natal / current-sky / transit / secondary 拆分 corpus 与 composition rules，并建立 Today / Week / Ask 独立消费者内容；运行时只读取编译后的聚合包，不读取 Obsidian；
- `scripts/build-ios-content-pack.mjs` 会验证重复 ID、语言边界、28 卡规则、binding、模板引用、禁用内部话术、必需语料候选和中英 ID 漂移，并输出同 ID 英文缺口清单；
- 私有 corpus、composition rules、运行时内容包和翻译导出均在 Git ignore 与 `scripts/check-private-content.sh` 保护范围内；
- App 新增持久化的 System / Light / Dark 外观设置，默认跟随系统；主题、卡片、轮盘和相位图使用动态浅深色；
- ContentKit 3 项测试、内容包双语覆盖验证、卡片契约、私有边界、架构检查、lint 和完整 iPhoneOS 构建通过；
- 已在连接的 iPhone 12 mini（设备名 `HUAWEI PURA 70`）完成签名、安装、启动，并确认进程持续运行；
- 尚未完成中文 297 条逐条人工内容审核、英文完整同 ID 翻译、iPhone 12 mini 逐屏视觉截图、Dynamic Type、VoiceOver、飞行模式和冷启动性能验收。

2026-07-29 iOS Today、人物与消费者语料收口：

- Today 保留今日主线、日内波形、四生活领域和信号驱动的接下来节奏，删除“四张星盘/今日解读的依据”，只在页面最底部增加七天综合进展；
- 七天视图由 `WeeklySignalProviding` 注册表接收标准化信号，当前已注册本命、天象、行运、次限；未来盘型只新增 provider，不修改 Today 页面；
- 七天逐日卡只展示当日重点、最忙节点在前/当前/已过和下一重点，全部正文来自 `PrivateContent-<locale>.json`；
- Today 四领域与接下来节奏改为必需内容键，删除 Swift 解释文案降级路径；私有包缺项会明确失败；
- 行运与次限分别使用自己的 Modern / Classical 预设重算移动盘和本命参照，本命页预设只影响本命页；
- Profile 已支持多人物、与本人关系、本人和其他人物头像、地图自动定位/搜索/点选、反向地理编码、自动时区及可编辑经纬度；
- 行运强度日历由 30 天改为本周 7 天；详情整行具有至少 44pt 点击区域；
- 轮盘改用星座和星体文字并扩大拥挤点间距；专业精度仍保留在轮盘/相位矩阵，解读事实改用消费者语言；
- 内容包构建会把技术占位符映射为消费者占位符，运行时中文包正文不再出现容许度、入相、出相、精确相位、行运、次限、逆行、宫位等术语；
- `scripts/export-ios-translation-worklist.mjs` 已生成 339 条翻译工作项：Today/周内容 42 条、四盘 corpus 297 条，含稳定 ID、优先级、占位符和长度/语气要求；
- 真机 UI 自动回归曾通过 2 项测试（0 失败）；依用户后续要求，不再重复做亮/暗污染检查，视觉问题按用户反馈专项处理；
- 最新通用 iPhoneOS 构建、AstroCore 8 项测试、ContentKit 3 项测试、卡片契约和私有内容边界检查均通过。

2026-07-30 iOS Ask、可读性与反馈：

- 第三栏由 Synastry 改为 `Ask / 问事`，实现会发生吗、选哪个、什么时候做最好三种流程；选择题默认 2 项、最多 5 项并禁止重复领域，择时支持日/周/月与范围上限、进度和取消；
- 新增独立 Horary/Election 计算：Regiomontanus、传统七曜与守护关系、传统相位/力量/接纳、逆行、燃烧、Cazimi、月亮下一相位和空亡；不修改四盘 `ChartKind`；
- 会发生吗显示可追溯的可能性，选择题归一化为 100% 并提供结果接近提示，择时显示独立适合度、第一推荐和两个备选；
- 问事轮盘复用基础单盘渲染并增加相关宫位、代表星和关键相位覆盖层；专业页含相位矩阵、宫主星、力量、接纳、月亮状态与评分拆解；
- 设置增加 Small / Standard / Large / Extra Large 四档字体；消费者正文完成语义字号清理，大屏轮盘文字随宽度放大，9pt 仅保留轮盘宫位短标记；
- 设置增加 Report，分类为 Bug / Feature / Other；只在用户主动提交时联网，不附带出生资料、星盘或私有语料，失败可复制反馈文字；
- ContentKit 与内容构建器增加同一主题、连续重复句、英文冠词、重复占位符和未解析变量检查，修复 `A and A` 与 `an closeness` 类组合；
- AstroCore 12 项、ContentKit 4 项、卡片契约、私有内容边界、架构、lint 和签名 iPhoneOS 构建已通过；
- Ask、字体设置和 Report 的真机 UI 回归已在 iPhone 12 mini 执行通过（1 项，0 失败），覆盖 Today、Charts、Ask 三入口、Profile、字体设置和 Bug / Feature / Other；
- 已在连接的 iPhone 12 mini（设备名 `HUAWEI PURA 70`）覆盖安装最终签名构建并重新启动 `com.xiaoguiwk.interstellar`，随后通过 CoreDevice 进程列表确认 App 进程持续运行（PID 1615）。

2026-07-30 iOS 内容收敛与消费者流程修正：

- Ask 的问题、选项、行动说明和经纬度输入加入明确的 Done / 完成与 Edit / 编辑状态；完成后锁定字段并收起键盘，键盘工具栏也可完成当前输入；
- 四盘消费者预设只显示 Modern / Classical；Classical 是与 Modern 对应的产品标签，Traditional 继续用于内部算法说明；旧 Special 仅做持久化解码迁移；
- 私有 corpus 与 composition rules 按 natal / current-sky / transit / secondary 拆分；Today / Week / Ask 也使用独立 source pack，再由脚本生成 Xcode 运行时聚合包；
- 候选本命中文文件 78 条中只接入 21 条可由现有 `InterpretationContext` 真实命中的内容，未生成的 dominant / repeated / chart-ruler / underused 等标签不伪造；
- 中英文四盘包、Today / Week / Ask 包均构建为 approved；天象盘不再因 Release 排除 sample 而显示“内容不完整”；
- Today 的 `What comes next` 不再直接罗列重复星体主题，改为从真实 `DailySignal` 去重生成整体氛围、个人节奏、长期变化三类视觉节点，标题与详情全部来自私有内容键；
- 通用 iPhoneOS Debug 构建已在 Swift 6 warnings-as-errors 下通过；最终签名版已覆盖安装并启动到 iPhone 12 mini，CoreDevice 首次确认进程 PID 1690；
- 同一签名产物已封装为被 Git 忽略的 `ios/Artifacts/Interstellar-ios-dev.ipa`；这是开发签名包，只能安装到当前 provisioning profile 已登记且信任开发者的设备；
- 真机自动 UI 冒烟测试因 Codex 外部授权额度限制未能启动，本轮证据为编译、签名、安装、启动与进程确认；Git 推送状态以本次任务最终交付为准。

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

`scripts/check-architecture.mjs` 已存在，当前检查 route、retry、corpus、CSS 和生产 API guard。iOS 私有内容另由 `scripts/check-private-content.sh` 检查；两者目前均通过。

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
| 2026-07-29 | 更新：iOS V1 四盘、Today、本地计算、私有内容边界、双语和通用真机构建完成；记录真机回归与许可复核剩余项 |
| 2026-07-29 | 更新：消费者 Today、轮盘和相位矩阵完成首轮代码实现；产品红线和固定验收流程写入 AGENTS；记录真机视觉验收仍未完成 |
| 2026-07-29 | 更新：四盘 28 张解析卡完成专用视觉与卡内要素实现，加入逐卡矩阵、完整点集和自动契约检查；正式内容与真机视觉仍待审核 |
| 2026-07-29 | 更新：建立独立 ContentKit 和私有 corpus/rules 编译流程，四盘 28 卡移除固定降级文案并接入事实驱动语料；加入 System/Light/Dark；完成 iPhone 12 mini 签名安装启动 |
| 2026-07-29 | 更新：Today 七天综合信号、未来盘型 provider、比较盘预设一致性、多人物/关系/头像/Apple 地图、消费者术语转换与 339 条翻译工作表完成；记录最终构建和测试证据 |
| 2026-07-30 | 更新：Ask 三流程与传统问事/择时引擎、概率和专业分析完成；加入字体大小、Report、全局可读性与语料组合去重，记录测试与真机安装状态 |

> AI生成
