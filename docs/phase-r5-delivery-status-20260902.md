# Phase R5 交付状态、AI 报告恢复逻辑与已知问题

日期：2026-09-02
工作分支：本地 `charts` 工作区（未推送到远端 `charts`）
交付分支：`hebiweng/interstellar` 的 `zip` 分支
上游工作包：`phase-r5-postaudit-professional-evidence.zip`
上游包 SHA-256：`0d1e75dba225422a79a1c142d0544d15efcf5038363565db485eff0c9a081b7d`

## 1. 本次只完成的问题

本次范围只处理 Ask / Compare AI 报告“Relay 已生成，但客户端拿不到、失败后又自动进入准备中”的问题，以及 Relay 对 AI 格式错误的有限修复重试。其他产品问题不再继续修改，统一记录在本文后半部分。

### 1.1 客户端状态对账

Ask 与 Compare 现在按 Reports 的语义，用原 requestID 查询 Relay，不通过状态恢复流程创建新的 AI 请求：

| 本地情况 | Relay 状态 | 客户端行为 | 是否重新请求 AI |
|---|---|---|---|
| App 启动或进入相关页面 | generating | 显示“正在分析”，继续查询原任务 | 否 |
| App 启动或进入相关页面 | completed | 取回、校验、原子保存，随后 ACK | 否 |
| App 启动或进入相关页面 | failed | 保持失败状态，等待用户操作 | 否 |
| App 启动或进入相关页面 | requestID 不存在 | 保留未提交的本地结果；旧失败记录落为明确失败 | 否 |
| 网络、App Attest 或取回中断 | 无法确认 | 保存为“待取回失败”，不伪装成正在准备 | 否 |
| 用户主动点“重试” | completed / generating | 优先取回或等待原任务 | 否 |
| 用户主动点“重试” | Relay 明确 failed | 使用同一 requestID 重新提交 | 是，且仅由用户触发 |

新增区分了三类失败：

- `deliveryFailed`：客户端无法确认或取回，启动/进页可自动对账，但不会创建 AI 请求。
- `relayFailed`：Relay 已明确失败，是终态；不会自动对账或自动重新生成。
- 旧版本的 `failed/reportFailed`：作为一次性兼容状态，最近记录会对账；确认后转换成上述明确状态，避免每次启动重复查询大量历史失败记录。

Compare 旧版本可能把中断任务保存成 `chartsReady`。这类记录不会在首页批量查询，但打开具体结果页时会查询原 requestID；Relay 查不到时仍保留本地计算结果，不会误判为失败。

Ask 新记录会保存恢复所需的 session 与语言，因此 App 启动即可对账。旧版 Ask 记录没有这两个字段，必须先打开对应 Ask 结果页面，由页面补齐上下文后才能取回。

### 1.2 不自动重新生成

- 打开 Compare 首页、Compare 结果页或 Ask 结果页不再调用生成入口。
- 网络、App Attest、状态查询、取回或 App 中断都不会触发新的 AI 生成。
- 手动重试先查 Relay；只有 Relay 明确返回失败，才会重新提交。
- 状态查询与取回轮询由 3 秒改为 10 秒，降低多个并行报告耗尽 App Attest challenge / API 频率限制的风险。

### 1.3 Relay 格式修复

Ask / Compare 的 AI 返回若已收到、但 JSON 或证据结构校验失败，Relay 会静默修复：

- 首次请求后最多再修复重试 3 次，总调用上限 4 次。
- 只有模型输出格式错误或证据结构校验失败才重试。
- HTTP、网络、鉴权、超时等非格式错误不自动重试。
- 超过上限才把任务标为失败并释放 Credit；不会把内部格式错误直接显示给用户。

## 2. 根因证据

- 生产 Relay 中 Ask / Compare 任务曾经已经到达 `awaiting_ack` 或 `success`，说明 AI 生成本身完成。
- iPhone 本地 Ask 记录保存的错误为“暂时无法验证 App，请稍后重试”，说明失败发生在后续状态查询或取回的 App Attest 授权阶段。
- 旧客户端每 3 秒查询一次；每次授权请求还需要一个 App Attest challenge。多个 Ask / Compare 并行时，会快速接近 Relay 的 challenge 与通用 API 限流。
- Compare 旧代码把 `reportFailed` 也视为可自动恢复，并在页面 `.task` 中直接调用生成入口，因此用户看到“已经失败 → 打开页面先显示准备中 → 再失败”。

## 3. 当前部署状态

### iOS

- 最终 Debug 真机构建已通过 warnings-as-errors 编译。
- 已于 2026-09-02 覆盖安装并成功启动到 iPhone 12 mini。
- Bundle ID：`com.xiaoguiwk.interstellar`。
- Credits 政策已统一为新用户首月 Free 5、后续每月 Free 2、Pro 每月额外 10；Annual Pro 首购另送 20，首月年付 Pro 新用户总额为 35。Guide、付费墙、法律条款、StoreKit 描述与客户端 `CreditPolicy` 已同步。
- Build 18 `1.0 (18)` 签名 Release Archive：`/private/tmp/Interstellar-1.0-18-credits.xcarchive`，Bundle `com.xiaoguiwk.interstellar`，arm64；已通过 Xcode `app-store-connect` 分发流程上传成功，App Store Connect 返回 `Upload succeeded` / `EXPORT SUCCEEDED`，当前等待处理。

### Relay

- 当前生产运行 `interstellar-relay:v6-20260902-build25-pro-credits`，镜像 ID `sha256:3e6ff9c7ff179d9bb9263f38cbbe9def4f2dfbbc3038afc419d632e5a908ccf4`，平台 `linux/amd64`。
- 部署前生产数据库已通过 SQLite online backup API 备份：`/opt/interstellar/backups/relay-before-build25-pro-credits-20260902T121938Z.db`；SHA-256 `7c23b92dbbf382f0df30bb498a345dc31451d6f71257d050546ca80f521b82e5`，完整性为 `ok`；切换后完整性仍为 `ok`。
- 仅重建 `interstellar-relay`，容器 healthy、RestartCount=0，公开 `/v1/health` 正常；Edge/Caddy 未重建。

## 4. 已完成的验证

- Ask / Compare 定向 Python 回归：87 项通过。
- AstroCore：126 项通过。
- ContentKit：6 项通过。
- Relay：`go test ./...` 与 `go vet ./...` 通过。
- iOS 真机目标编译通过。
- `scripts/check-ios-card-contract.sh` 通过。
- `npm run ios:copy:validate` 通过，10 个私有运行时域可由源重建。
- `npm run ios:localization:validate` 通过。
- `npm run architecture:check` 通过。
- `npm run lint -- --quiet` 通过。
- `scripts/check-private-content.sh` 对公开边界检查通过。
- `git diff --check` 通过。
- Compare 出站 evidence ID 唯一性回归通过；本地 stable fact ID 与 A/B 配对保持不变。
- `compare.*` 与 `ask.deep_analysis` 首次生成超时 90 秒的 Relay 回归通过。
- 真实 iPhone 12 mini Compare smoke 已发起并完成报告交付：Home 后恢复前台，UI 结果包确认从分析中状态进入完整报告并出现证据按钮。临时 UI 测试仅因 `View Charts` 大小写断言错误而返回测试失败，临时代码已移除；不构成产品报告失败。

尚未完成的生产端到端范围：本轮已完成 Compare 一单真实生成与后台/前台恢复；Ask 以及 Compare 其他三种模式仍需单独的用户授权 smoke，不能由这一单推断全部 scope 均成功。

## 5. 其他已报告问题：本次不再继续修改

以下项目已有部分代码或回归覆盖，但按用户要求，本次不继续调整；需要后续人工验收后再决定是否修：

1. Compare 两人物对比曾显示“没有发现可确定计算的变化”。当前代码改为从 relationship facts 提取主要对比，并有单元测试，但最新真机业务结果未重新验收。
2. Compare 历史列表、Ask 历史中的分析中状态已有持久化代码；最新 build 的完整导航、排序和多条并发任务尚未人工验收。
3. Compare 的“66 个变化但只列 8 个”已改为“主要变化”，由确定性筛选器最多选 8 条；总数文案与用户预期是否完全一致尚未真机复核。
4. Compare 依据面板改为使用本地 facts，A/B 星盘改为 Tab；尚未做最终 VoiceOver、Dynamic Type 和 iPhone 12 mini 全路径人工验收。
5. “我的变化”日期预设选择已在选择对应预设时高亮，并在手动改日期后切到自定义；复杂返回路径尚未人工验收。
6. Themes 已保留星盘详情并改为页面内直接显示；最新视觉、长文本和深浅色尚未完整人工验收。
7. Themes 仍使用自己的旧恢复实现和 3 秒轮询，本次没有按 Ask / Compare 的新状态机重构。它仍可能把可恢复状态交给生成入口；需要单独任务处理，不能把本次代码完成误认为 Themes 同步完成。
8. Reports 现有管理器在首次 `createTask` 报错时会用同一幂等 requestID 再 POST 一次，并对 pending 网络错误每 30 秒继续查询。本次仅参考其“持久 pending + 状态查询 + 成功取回”语义，没有修改 Reports。
9. 完整旧 Python 测试集中仍有与 Phase R5 新结构冲突的遗留断言（旧 `SynastryView.swift`、旧语言数量、旧 Charts 结构）。它们不代表本次定向功能失败，但需要后续清理测试合同；本次没有处理。

## 6. ZIP 内容与安全边界

目标仓库 `hebiweng/interstellar` 已确认为 Private。交付 ZIP 包含：

- `ios/` 完整源码、工程、测试、Localization、ContentSchema、`PrivateContent` 与 `PrivateRules` 私有源。
- `relay/` 完整源码、管理端静态资源和测试。
- `artifacts/` 公开语料合同包。
- `scripts/`、`infra/deploy/`、相关测试、项目配置和本文。

ZIP 不包含：

- `.git`、其他分支历史或 worktree 元数据。
- `.env*`、API Key、App Store 私钥、GitHub token、管理员凭据。
- Relay 数据库、备份、用户数据、设备日志。
- Xcode DerivedData、Archive、IPA、SwiftPM/Node 构建缓存。
- 从私有源生成、可重建的 `ios/App/Resources/PrivateContent` / `PrivateRules` 运行时包。

该 ZIP 含私有语料，只能保留在 Private 仓库或受控存储中，不得转发到公开仓库、Issue、日志或附件。
