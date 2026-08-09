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

本文件只保留跨任务强制规则。当前进度见 `docs/agent-handoff.md`，产品与卡片细节分别以 v6 执行合同和卡片矩阵为准。

## 1. 接手顺序与权威源

按顺序阅读：

1. `AGENTS.md`
2. `docs/ios-v6-rebuild-plan.md` — 当前 iOS 产品与实施合同
3. `docs/ios-card-implementation-matrix.md` — 六盘卡片数量、顺序、事实与视觉合同
4. `docs/agent-handoff.md` — 当前分支状态、验证证据和下一步
5. 当前代码、测试、Schema 与私有内容构建说明

权威优先级：真实计算和不可变 Snapshot → v6 合同 → 卡片矩阵 → 当前代码与测试 → 原型视觉参考。`docs/ios-v1-development-plan.md` 和交接历史只作背景，不能覆盖 v6 决策。

`docs/chart-insight-design-standard.md` 仅在维护旧 Web 跨盘型架构时阅读。现阶段不得默认遍历 Obsidian。

## 2. 冻结产品范围

- 六盘固定为：本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8 张卡；Composite 延期。
- Today 固定为：`Current Chapter / Active Today / Coming Next / Moon Today / Timeline / Upcoming Sky / Retrogrades / Current Sky`。
- Ask 与 Profile 是正式能力，不得因 v6 原型未覆盖而删除或降级。
- 消费者预设只提供 Modern / Classical；旧 `Special` 仅允许兼容历史数据。
- 英文为默认语言；正式短语料交付英文和简体中文。西班牙语、法语的消费者正文未审核时明确回退英文。
- 支持 System / Light / Dark；所有关键页面必须在 iPhone 12 mini、长文本和 Dynamic Type 下可用。
- 跨设备报告同步、Web 消费端改造和旧 `/admin` 迁移均延期。

## 3. 消费者体验红线

1. **先给结论，再给参数**：首屏先回答生活问题，精确度数、容许度和技术参数进入事实层或展开层。
2. **单语且自然**：同一界面只显示当前语言；禁止研究报告口吻、内部设计说明、AI 套话和机械拼句。
3. **真实数据驱动**：评分、波形、雷达、时间线、轮盘、矩阵和状态都必须映射真实计算事实；不得补示例分数、虚构事件或估算日期。
4. **原型不是字段合同**：原型只校准层级、密度、构图和交互感；最终字段遵守真实计算能力、当前产品设计和 `InsightCard` 合同。
5. **轮盘可读**：保留刻度、十二宫、ASC/DSC/MC/IC、星体名称、度数、引线和逆行状态；双轮明确区分内外盘，拥挤文本必须避让。
6. **相位使用矩阵**：单盘用三角矩阵；比较盘用移动点 × 本命点交叉矩阵。节点网络不能作为正式 `Aspects` 主视图。
7. **完成不等于能运行**：骨架、占位卡、通用图表和临时文案只能算接线完成；视觉、内容、真实数据、小屏、无障碍与空状态均需验收。

## 4. 事实、展示与 AI 边界

权威事实链路：

```text
Web: 服务器计算 → 不可变 Snapshot → 展示层
iOS: AstroCore 本地计算 → 不可变 Snapshot → 展示层
```

- 权威事实包括星历、黄道与宫位、点位、相位、跨盘相位、ingress/egress/exact、地点、时区、经纬度和计算版本。
- 展示层只做排序、过滤、主题映射、空状态和不改变事实的可视化派生；不能补算、伪造或强化不存在的信号。
- AI 只能解释请求中已计算的事实，不能计算星盘、覆盖 Snapshot 或新增事实、相位、宫位和日期。
- Today 只消费注册 provider 输出的标准信号与已计算事件；新增盘型通过 provider 注册，不在 Today 页面增加盘型分支。
- 行运和次限的移动盘与本命参照必须使用同一所选预设；本命页自己的预设不能污染其他盘。

iOS 内容链路固定为：

```text
ChartSnapshot / Aspect / Event
→ StandardSignalBuilder
→ CardEvidencePlanner
→ ThemeMapper
→ CopyCatalogMatcher
→ CardTextModel
→ InsightCard / Today
→ GeneratedChartArtifact
```

## 5. 卡片、内容与本地化

- 每个可见事实固定呈现“计算结果 + 一句自然解读”。短解读只能来自私有、已审核 Copy Catalog，Swift 不得拼解释句。
- 技术事实模板最多 3 个已声明的强类型变量且只陈述事实；消费者标题、正文和建议原则上 0 个、确有必要最多 2 个变量。
- `approved` 只代表文案审核通过。正式条目还必须通过 JSON Schema、类型、selector、事实引用和卡片合同完整性校验；任一失败必须阻断构建和 CI。
- 公开 Git 只放 Schema、布局、选择接口与渲染逻辑。完整原创摘要、详情、规则、运行时私有包和翻译交付不得进入公共 Git、日志、测试附件或示例截图。
- 六盘 AI 永久只生成 4–8 节整盘报告，不生成单卡 AI 详情。报告只在 Reports 中由用户明确点击生成后请求，不得在星盘计算或页面打开时自动生成；同一语义指纹默认复用本机 `GeneratedChartArtifact`，用户明确点击重新生成时才覆盖现有报告。
- 本机 Artifact 不设 TTL；同语义指纹命中时禁止联网。Relay 只允许最长 24 小时加密幂等缓存。
- 撤回 AI 授权后仍可读已有报告，但不得发起新请求；删除人物必须清理关联 Artifact。
- 固定 UI 使用 `Localizable.xcstrings`；占星术语使用四语 `AstroTerms`；消费者正文只进 Copy Catalog；日期、时间、数量和语序使用 Locale-aware formatter。
- 内容键缺失必须明确失败，不能在 Swift 中加入解释性降级句。

## 6. 人物、地点与上下文

- Profile 必须支持本人和其他人物、关系、头像、出生时间、地点、时区和可编辑经纬度。
- 地点流程必须支持当前位置、Apple 地图、搜索/点选、反向地理编码和自动匹配时区。
- 参数变化先重算权威 Snapshot，再按新指纹读取或生成 Artifact。
- Today 始终使用当前实际上下文，不受 Charts 中探索日期、地点或人物参数污染。

## 7. Obsidian 与旧 Web

Obsidian 只允许在项目内合同、Schema、代码、测试和私有内容都无法解决明确缺口时定向查询。候选内容必须筛选、重写并进入项目内私有 corpus/rules 或正式文档；运行时不得读取 Obsidian，原文不得直接进入消费者 UI。

如确需新建或修改 Obsidian Markdown，frontmatter 必须包含 `created`、`updated`、`author`、`modified_by`；`created` 保持首次创建日期，其他字段随修改正确更新。

维护旧 Web 解读时继续遵守分层：

```text
服务器事实 → insight builder → corpus → presentation rules → React 固定组件 → 独立 CSS
```

`page.tsx` 必须保持薄入口：不能加入 `"use client"`、持有 React state 或直接 fetch。

## 8. 实现与验收

重要任务按以下顺序完成：

1. 核对 v6 合同、卡片矩阵、当前代码、测试和私有内容 Schema。
2. 为每个视觉记录计算输入、映射、空状态和降级方式。
3. 建立稳定内容键、selector、事实引用和审核状态。
4. 按事实 → planner/builder → 私有内容 → 固定组件分层实现。
5. 对照卡片矩阵检查数量、顺序、独立视觉、短解读、AI 状态和空状态。
6. 在 iPhone 12 mini 检查英中、长英文、浅深色、Dynamic Type 与 VoiceOver。
7. 运行适用门禁：

```sh
scripts/check-ios-card-contract.sh
npm run ios:copy:validate
npm run ios:localization:validate
npm run architecture:check
npm run lint -- --quiet
scripts/check-private-content.sh
git diff --check
```

同时运行相关 AstroCore、ContentKit、iOS、Relay 单元测试和构建。构建通过不能替代人工视觉验收。

8. 只在有证据时更新计划完成项；随后更新 `docs/agent-handoff.md`，记录完成内容、验证、未完成项和下一步。

## 9. 部署与安全

- 开发环境：`compose.yaml` + `compose.app.yaml`。
- 生产环境：`infra/deploy/compose.production.yaml`、`infra/deploy/Dockerfile.web`、`infra/deploy/Caddyfile.fate`。
- Relay-only：`infra/deploy/compose.relay-only.yaml`，只启动 Caddy 与 Relay；旧 Web/API 容器保持停止但不删除。
- iOS Relay 权威域名：`https://aaadmin.xiaoguiwk.top`；根路径和 `/xiaoguiwk` 使用 Relay 内嵌管理端。
- `linux/amd64` 镜像必须在本机或 CI 构建后传输；低内存服务器只加载镜像并切换 Compose，不现场编译。
- 不得把管理员凭据、API Key、出生资料、事实正文、提示词正文或 AI 正文写入 Git、日志、Bark 或截图。

### App Attest 临时状态

当前因未购买 Apple Developer Program，真机开发暂时使用以下例外：

- `infra/deploy/compose.production.yaml` 与 `infra/deploy/compose.relay-only.yaml` 的 `RELAY_ALLOW_DEV_BYPASS` 为 `"1"`；
- Debug/Simulator 构建由 `ios/App/AIGeneration.swift` 发送 `X-App-Attest-Development-Bypass: 1`；
- 当前 Xcode 免费 Personal Team 的实际 Team ID 为 `YD3FY9ZB52`，entitlements 中未启用 App Attest；`M2A7RHP7MT` 是旧签名身份标识，不得再作为 `DEVELOPMENT_TEAM`。

发布前必须购买/恢复 Apple Developer Program，届时从 Xcode/Developer Portal 重新确认正式 Team ID（不得沿用历史猜测），恢复 `com.apple.developer.devicecheck.appattest-environment`，把 `RELAY_ALLOW_DEV_BYPASS` 改回 `"0"`，并完成生产 App Attest 端到端验证。

> AI生成
