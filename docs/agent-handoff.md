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

# Interstellar — 当前交接

> 更新时间：2026-08-09。这里只记录当前有效状态、证据和下一步；历史决策以 Git 记录为准。

## 0. 2026-08-09 合盘八卡 v3 收口状态

- Synastry 已走专属 `FactBundle → ContentPlanner → EvidencePlan → CopyMatcher → CardFactory`；Modern/Classical 共用卡片容器但选择与 Copy key 按 preset 隔离。
- 八张卡已按 v6 原型重构。`perspectives` 的两页分别绑定 B→A / A→B 落宫证据，标签为真实姓名 `feels`，语料正文合同使用第二人称 `you/your + {{otherName}}`。House Overlay 与 Key Inter-Aspects 强制保留 source/receiver 和 personA/personB 的有序姓名。
- Emotional / Communication / Chemistry / Commitment / House Overlays / Key Inter-Aspects 均使用动态筛选，不固定原型示例信号。Classical Chemistry 不含 Pluto；Classical Bundle 继续严格七曜且排除 Node。
- 2026-08-09 真机视觉反馈已收口：Synastry 专属视图不再使用固定深色 RGB，Relationship Overview 与抽屉跟随 Light/Dark；Emotional 与 Commitment 固定保留双栏，缺少合法角色事实时显示明确空信号而非删除整格；Commitment 会优先用 Saturn/Jupiter 跨盘相位，并允许回退到对应真实宫位落入。
- Communication 三节点已恢复原型合同：仅使用双方共同、无方向人称的短流程词；Modern/Classical 各四主题的英中 `step1/step2/step3` 已重写，英文最多 3 词、中文最多 4 字，均不含 `you/你`。导入脚本新增长度与人称阻断，后续不合格语料包会直接失败。
- 原型标记 clickable 的 Relationship Overview、Emotional、Communication、Chemistry、Commitment 已有卡片抽屉；Key Inter-Aspects 为逐行事实抽屉。第一张抽屉固定使用 `How to read this`。
- 最新语料合同位于 `artifacts/modern-synastry/` 与 `artifacts/classical-synastry/`。用户交付的 `synastry-bilingual-copy-v3.zip` 已接入正式私有 Copy Catalog：Modern 30/30、Classical 33/33，英中 missing/unknown/unobserved/unreachable/cross-preset fallback 均为 0，两套 validation passed。西法按合同使用英文回退。Perspectives 的 `{{otherName}}` 已升级为 Copy Schema 强类型 `personName`；旧 Synastry contract 已换成 v3 preset-specific source，古典旧合同中的 trueNode 已移除。
- 已完成的 Modern Transit 语料成品已从旧的 `ios/ContentSchema` + `ios/TranslationExports` 无重算整理到 `artifacts/modern-transit/`，与其他 preset/盘型统一为 10 文件结构。原 7 个成品保持字节一致；fixtures/validation/unobserved 仅从既有元数据拆分汇总。现有门禁为 requirements 219、reachable/observed 216、unreachable 3、missing/unknown/unobserved 0，validation passed。
- Synastry AI 请求已核对：传两人真实姓名、双方本命点/四轴、双向落宫、跨盘相位及当前 preset；Classical 额外传七曜 condition 与明确 cross-chart reception。证据按 ID 排序、有限且无重复根字段。Relay 合盘专用提示词要求双方视角、姓名、情绪/沟通/吸引/长期结构/摩擦/落宫/跨盘相位，并禁止评分、裁决、结局预测和跨 preset 推导；本轮增加了 4–8 节及中英篇幅上限，尚未部署该提示词增量。
- 验证：四语 Copy Catalog build/validate 通过；Modern/Classical Synastry validation passed；最新 Simulator Debug 与真机 Debug build 均通过；Relay `go test ./...` 通过；`git diff --check` 通过。视觉修复已覆盖安装到当前连接设备；首次启动需在设备的“VPN与设备管理”中信任免费开发者签名。当前 Xcode 免费 Personal Team 的实际 Team ID 为 `YD3FY9ZB52`；旧 `M2A7RHP7MT` 不是可选 Team，已从工程配置移除。

## 1. 接手快照

| 项目 | 当前值 |
|---|---|
| 开发分支 | `codex/ios-v6-rebuild` |
| 当前提交 | `f679a87 feat(ios): modularize insights and migrate classical transit` |
| 远端差异 | 清理前相对 `origin/dev` 超前 9 个提交 |
| 产品合同 | `docs/ios-v6-rebuild-plan.md` |
| 卡片合同 | `docs/ios-card-implementation-matrix.md` |
| Relay 域名 | `https://aaadmin.xiaoguiwk.top` |
| 当前主线 | iOS 六盘 v6、Today、Copy Catalog v2、AI Artifact、Go Relay |
| 明确延期 | Composite、跨设备报告同步、Web 消费端、旧 `/admin` 迁移 |

DeepSeek 原始实现保存在 `codex/deepseek-v6-snapshot`（提交 `a42f1d6`），v6 重构基线为 `7d5b115`。当前工作区包含 Transit report-only、Reports 按需生成、Relay、提示词和合同文档的未提交改造；不得丢弃或覆盖这些改动。

接手时先读 `AGENTS.md`、v6 执行合同和卡片矩阵。不要按本文旧版本中的 iOS V1、四盘、固定 `summary + detail + note`、Web 次限样板或 Obsidian 默认流程继续开发。

## 2. 当前产品与架构

### 2.1 冻结范围

- 六盘 44 卡：本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8；Composite 不在本轮。
- Today 八模块：`Current Chapter / Active Today / Coming Next / Moon Today / Timeline / Upcoming Sky / Retrogrades / Current Sky`。
- Ask 保留三流程、历史和专业事实；Profile 保留多人物、关系、头像、地图、时区、经纬度、预设、主题、字体、AI 授权和本地数据管理。
- Modern / Classical、en / zh-Hans / es / fr、System / Light / Dark 已接线。英文为默认；西法未审核消费者正文按合同回退英文。

### 2.2 权威链路

```text
AstroCore Snapshot / Aspect / Event
→ StandardSignalBuilder
→ CardEvidencePlanner
→ ThemeMapper
→ CopyCatalogMatcher
→ CardTextModel
→ InsightCard / Today
→ GeneratedChartArtifact
```

iOS 由本地 AstroCore 计算权威事实；展示层不能补算或伪造。AI 只解释请求中的事实，并通过 `evidenceFactIDs` 受限引用。

### 2.3 六盘迁移状态

| 盘型 | 卡片 | 当前实现状态 | 下一步 |
|---|---:|---|---|
| 行运 | 6 | Modern 与 Classical 均已迁入独立 Planner/Factory/Copy/Validation 链路 | 保持冻结，先修测试和性能问题 |
| 天象 | 7 | 已按模块归位，业务仍由 `Legacy` factory 转发 | 下一个迁移目标 |
| 本命 | 10 | 已按模块归位，业务仍由 `Legacy` factory 转发 | 天象之后迁移 |
| 日返 | 7 | 已按模块归位，业务仍由 `Legacy` factory 转发 | 本命之后迁移 |
| 次限 | 6 | 已按模块归位，业务仍由 `Legacy` factory 转发 | 日返之后迁移；不得退化六模块 |
| 合盘 | 8 | Modern/Classical 已迁入专属 FactBundle/Planner/Copy/Factory/Validator；`Legacy` 文件名仅为待清理的物理路径 | 完成真机视觉验收后冻结 |

共享路由位于 `ios/App/Insights/Shared/Routing/InsightFactory.swift`。非行运盘的 `Legacy` 目录是迁移过渡层，不代表旧合同重新成为权威。

## 3. 已完成的关键能力

### 3.1 Modern Transit

- 唯一决策链路为 `TransitFactBundle → TransitContentPlanner → TransitContentPlan → UI / Copy / GeneratedChartArtifact`。
- 六卡 UI 与 Copy 使用同一 scope 的证据计划；AI 报告直接消费同 preset 的完整合法 Bundle facts，不受六卡容量限制。Timeline 只消费技术事实，不请求消费者正文。
- 支持真实相位窗口、重复精确、换座、换宫、转逆/转顺、完整路径、十二宫聚合，以及 7/30/365 天 Timeline。
- Modern Copy 合同共 219 条 requirement：216 条可达、3 条因周期行星约束结构不可达；unknown 0、reachable missing 0。
- 14 组 fixture、20 个真实盘日期和 4623 个系统探针已用于可达性门禁。

### 3.2 Classical Transit

- `preset == classical` 明确进入 `ClassicalTransitPlanningStrategy`，无 Legacy/Modern runtime fallback。
- 只使用七曜尊贵/失势、角续果宫、逆行、燃烧/日光下、真实接纳、相位阶段、窗口和行星事件；外行星不进入古典证据选择。
- 有限语义域共 71 条静态可达 requirement：reachable/observed 71，missing/unknown/unobserved/unreachable 0，Classical → Modern fallback 0。
- 24 个固定 fixture、68 个有限域探针和 9 个真实盘/日期组合已通过。
- AstroCore 尚未提供 Transit 可用的昼夜 sect、prohibition、frustration 或 prevented-perfection；当前 Planner 与文案均未猜测这些事实。

### 3.3 内容、本地化与 UI

- Copy Catalog 已迁移到 schemaVersion 2，按 `shared / modern / classical` 和 preset 管理；运行时读取 Git 忽略的 `CopyCatalog-<locale>.json`。
- 正式 Schema 校验卡片合同、selector、factRefs/evidence、变量类型与上限、重复路径和引用完整性。
- `Localizable.xcstrings`、四语 `AstroTerms` 和 `LocalizedFormatters` 已接入；消费者正文与固定 UI/术语分层。
- 六盘统一使用外置卡片标题；Charts 卡片不显示单卡 AI 详情箭头或状态区。整盘 Artifact 仍保留给 Reports 等明确入口。
- 轮盘、三角/交叉相位矩阵、Charts 紧凑参数入口、Today、Ask、Reports 和 Profile 均已有可构建实现。

### 3.4 AI Artifact 与 Relay

- 单卡 AI 已永久退出请求、响应、Artifact 和 Relay 合同；`GeneratedChartArtifact` 只保存整盘报告，并以语义指纹、语言、预设和事实哈希为缓存依据。
- 六盘均改为 Reports 内明确点击后按需生成；盘计算和 Charts 打开不联网。同语义报告直接打开，重新生成成功后覆盖，失败时保留旧报告；生成任务可在用户离开 Reports 页面后继续。
- Transit AI 直接序列化 preset-specific `TransitFactBundle` 的 aspect、window、event、placement、life area 与 calendar facts；已补齐已有 Classical score、conditions、reception、cycle band 和 Current Story 一致性评估，不以六卡计划作为证据边界。
- Relay 提示词已改为 4–8 节整盘综合报告：按 strength、orb、phase、score、窗口、motion 和已有 Modern/Classical assessment 判断轻重，禁止重新计算或编造事实。Relay 仅校验 report Schema、语言和本次 evidence ID，并保留一次非法 JSON 修复。
- Go Relay 已实现 24 小时 AES-GCM 缓存和 `forceRegenerate` 同键覆盖，以及 Provider/模型启停、bcrypt 管理员、可撤销 SameSite 会话、无正文审计、安装配额和 App Attest 断言。
- Relay 内嵌管理端可从根路径和 `/xiaoguiwk` 访问，支持 DeepSeek Key、模型、提示词、连接测试和用量。
- 旧 Web/API 容器保持停止但不删除；Relay-only 使用 `infra/deploy/compose.relay-only.yaml`。
- 当前生产 Relay 镜像为 `interstellar-relay:v6-20260809-report-only`，发布目录为 `/opt/interstellar/releases/v6-relay-v6-20260809-report-only`，切换前数据库备份为 `/opt/interstellar/backups/relay-20260809-1243.db`。只重建了 Relay 容器，Caddy、旧 Web/API 和数据卷未改动。

## 4. 最近验证证据

以下包含本轮 report-only 改造的最新证据和此前已记录证据：

- Relay `go test ./...` 通过；新增测试覆盖首次生成、同键缓存命中和 `forceRegenerate` 绕过读取后覆盖同键。
- 生产 Relay 健康检查通过。真实合成请求已完成 Relay → DeepSeek：HTTP 200、5 节报告、合法 `evidenceFactIDs`；第二次同请求返回 `cached:true` 且未调用上游。
- 生产曾因大小写不同的重复 Provider 导致默认项指向无密钥 `deepseek` 而返回 503；现已将默认项修正为有 Key 的 `DeepSeek`，并收口重复根因：生产 `RELAY_SEED_DEEPSEEK=0`，无 Key 的小写 `deepseek` 已删除。重建 Relay 后数据库仅保留有 Key 且默认的 `DeepSeek`，期间未读取或修改密钥。生产 `.env` 的镜像标签也已持久化为 `v6-20260809-report-only`。操作前备份为 `/opt/interstellar/backups/relay-before-provider-cleanup-20260809-131614.db`、`/opt/interstellar/backups/compose.relay-only-before-seed-off-20260809-131614.yaml` 和 `/opt/interstellar/backups/env-before-image-tag-fix-20260809-131614`。
- `scripts/check-ios-card-contract.sh`、Copy、Localization、Architecture、Lint、Private Content 和 `git diff --check` 均通过。
- 最新 iPhoneOS Debug 在 `CODE_SIGNING_ALLOWED=NO` 下完整编译、链接、资源校验并 `BUILD SUCCEEDED`；签名构建仅阻塞在 macOS Keychain 的 codesign 私钥授权。授权后仍需增量签名、安装并完成真机 App → Relay → DeepSeek → 本地 Artifact 验收。

- Simulator Debug build 通过；Swift 6 warnings-as-errors 构建曾通过。
- iOS 单元测试 29 项通过，包含 Modern 和 Classical Transit 规划与英/简中实际组装门禁。
- Modern 导出：requirements 219、reachable 216、unreachable 3、unknown 0、missing 0。
- Classical 导出：requirements/reachable/observed 71，missing/unknown/fallback/invalid sourceFactID 均为 0。
- 卡片合同、四语 Copy Catalog、四语 Localization、私有内容边界、架构检查、lint、Xcode project plist 和 `git diff --check` 通过。
- 完整 UI 套件记录为 8 项通过、1 项因生产 App Attest 只支持真机而跳过。
- 独立西/法核心本地化 UI 流程仍在西语 `Parámetros` 按钮导航处失败，尚未形成修复证据。
- Debug 签名包曾覆盖安装并启动到 iPhone 12 mini（设备名 `HUAWEI PURA 70`）。

## 5. 当前未完成与风险

### P0 — 继续开发前优先处理

1. **完成真机报告闭环**：先在 Mac Keychain 放行当前个人开发证书签名，再安装到已连接的 iPhone 12 mini；验证明确点击才生成、等待后返回、同语义直接展示、重新生成覆盖、失败保留旧报告，以及 Modern/Classical 隔离。
2. **保持开发绕过**：当前未购买 Apple Developer Program，本轮不得恢复 App Attest entitlement 或关闭 `RELAY_ALLOW_DEV_BYPASS="1"`。
3. **保持行运六卡冻结**：除修复确定缺陷或性能问题外，不改变 6 卡 ID、顺序、证据范围和 Copy request 集合。

### P1 — 发布前必须完成

1. iPhone 12 mini 的英中/西法、浅深色、标准/大字体、Dynamic Type、VoiceOver、空状态和长文本逐屏验收。
2. 正式决定 Horizon 采用 90 天还是 calendar year，并统一代码、合同和真机性能基准；只能优化计算，不得删减事实合同。
3. Ask 与 Week 仍使用 legacy 私有内容结构；迁移时必须保持私有边界和稳定 ID。
4. 飞行模式、本地 Artifact 零网络命中、授权撤回后只读、人物删除清理和损坏文件恢复测试。
5. 确定并实现 Classical trueNode 的 Snapshot/Aggregation/Selection/Presentation policy，加强 Classical contract validator，并覆盖 life-area/calendar 聚合来源。
6. focused Transit 当前有意保持 events/calendar 为空；产品确认后决定是否补完整扫描。
7. 分支尚未合入 `origin/dev`；推送或 PR 前复跑完整门禁并核对生成 artifacts 是否应进入提交。

### 发布阻断项 — App Attest

当前没有 Apple Developer Program：

- `RELAY_ALLOW_DEV_BYPASS="1"`；
- Debug/Simulator 发送 `X-App-Attest-Development-Bypass: 1`；
- 当前免费 Personal Team 为 `YD3FY9ZB52`；正式 App Attest entitlement 未启用。

上线前必须购买/恢复 Apple Developer Program，从 Developer Portal 重新确认届时的正式 Team ID，恢复 App Attest entitlement 和 `RELAY_ALLOW_DEV_BYPASS="0"`，然后完成生产 App Attest、限流与配额链路验证。

## 6. 推荐推进顺序

```text
完成 iPhone 12 mini 按需报告端到端验收
→ Node Policy / Classical Validator / Horizon 收口
→ 修复西/法 UI 测试导航
→ Current Sky
→ Natal
→ Solar Return
→ Secondary Progressions
→ Synastry
→ 六盘/Today/Ask/Profile 全量真机与无障碍验收
→ 恢复生产 App Attest
→ 发布准备
```

迁移单个盘型时先做行为不变的归位，再建立盘型专属事实 bundle、planner、有限语义 registry、Copy 可达性导出、factory 和 validator。错误旧 Copy key 只能通过构建期 alias/deprecated manifest 审计，不能成为运行时降级路径。

## 7. 常用入口与门禁

关键路径：

```text
ios/App/Insights/                    六盘模块与共享路由
ios/App/Insights/Transit/            Modern/Classical Transit 当前样板
ios/ContentSchema/                   卡片与 Copy 合同
ios/Packages/AstroCore/              本地权威计算
ios/Packages/ContentKit/             内容匹配模型
ios/App/AIGeneration.swift           Artifact 与生成客户端
relay/                               Relay、管理端、App Attest、缓存与审计
infra/deploy/                        生产与 Relay-only 部署
artifacts/classical-transit/         Classical 可达性和验证证据
```

适用门禁：

```sh
scripts/check-ios-card-contract.sh
npm run ios:copy:validate
npm run ios:localization:validate
npm run ios:transit-copy:export
npm run ios:classical-transit-copy:export
npm run architecture:check
npm run lint -- --quiet
scripts/check-private-content.sh
git diff --check

(cd relay && go test ./...)
(cd relay && go vet ./...)
```

另外运行相关 Xcode build、AstroCore/ContentKit/iOS 单元测试和 iPhone 12 mini UI 流程。私有 Catalog 不存在时，`ios:copy:validate` 会失败，这是预期门禁，不得用公开临时文案绕过。

## 8. 最近提交

| 提交 | 内容 |
|---|---|
| `f679a87` | 六盘 Insights 模块化并迁移 Classical Transit |
| `66d9880` | 完成 Modern Transit 卡片体验 |
| `4a606b2` | 完成 Transit Copy 规划与可达性链路 |
| `f8ba1ef` | 建立 Modern Transit 卡片证据计划 |
| `4b403f5` | Copy Catalog 迁移至 v2 |
| `5f200a3` | 临时关闭 App Attest、Relay 部署、真机签名与构建 PATH 修复 |
| `7d5b115` | 保存 DeepSeek v6 实现快照并建立重构基线 |

> AI生成
