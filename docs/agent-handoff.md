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

> 更新时间：2026-09-02。本文件只记录当前工作区、构建、环境、验证证据和立即下一步。产品需求见 `docs/ios-product-backlog.md`，正式上架门禁见 `docs/ios-release-readiness.md`，历史过程查 Git。

## 0.0 Phase R5 ZIP 接收与 Relay 补齐（2026-09-01）

- 2026-09-02 已补 Ask / Compare 报告恢复状态机：App 启动或进入相关页面只用原 requestID 查询 Relay；generating 继续显示分析中，completed 取回/校验/保存/ACK，Relay 明确 failed 落为终态；网络、App Attest、取回和中断落为 `deliveryFailed`，不会自动创建 AI 请求。用户手动重试也先取回，只有 Relay 明确失败才用同一 requestID 重新提交。轮询由 3 秒降到 10 秒。旧 Compare `chartsReady` 记录在打开具体结果页时也会查 Relay；旧 Ask 缺 session 的记录须先打开结果页补齐上下文。
- Relay build23 代码把 Ask / Compare 模型格式或证据校验失败改为首次后最多 3 次静默修复（总调用上限 4）；HTTP、网络、鉴权、超时不自动重试。`interstellar-relay:v6-20260902-build23-report-recovery` 已构建并上传服务器，镜像 ID `sha256:f3bbc11e18d5de2c1290df17ad30b677837da9519d17edd0a6b6f25738b48e2d`。部署前备份 `/opt/interstellar/backups/relay-before-build23-report-recovery-20260902T000352Z.db`，SHA-256 `68153f7b1e5a0c74a39a93814bc264ef0bcff5db236190a4caaa223d2537d1f4`、integrity `ok`。生产 `.env` 缺 `RELAY_APP_STORE_ISSUER_ID` / `RELAY_APP_STORE_KEY_ID`，安全策略禁止自行从运行容器提取凭据，因此尚未切换，生产仍为健康的 build22。
- 最终 Debug 客户端已于 2026-09-02 覆盖安装并启动到 iPhone 12 mini。定向 Ask / Compare 回归 87/87、AstroCore 126/126、ContentKit 6/6、Relay 全量测试/vet、真机编译和全部适用门禁通过。详细状态与未处理问题见 `docs/phase-r5-delivery-status-20260902.md`。
- 完整 iOS / Relay / 私有语料源交付 ZIP 已上传到 Private 仓库 `hebiweng/interstellar` 的独立 `zip` 分支，提交 `ee468b0e25e5adffb7a6924ca35b108bf37adf7c`。ZIP SHA-256 为 `a4db30007836f10215e47421a7e5879974670eb7bd0cfd66e0701b7922f69930`；`charts` 分支未推送、未污染。

- 本轮权威输入为公开 `charts` 分支的 `phase-r5-postaudit-professional-evidence.zip`，本地下载 SHA-256 为 `0d1e75dba225422a79a1c142d0544d15efcf5038363565db485eff0c9a081b7d`。ZIP 的 iOS、Charts、Themes、Ask、Compare、AstroCore、固定 UI、本地化和专项测试作为产品/业务基线；未采用 `iosv0.1` 分支的其他内容。旧单文件 `ios/App/SynastryView.swift` 已按 ZIP 的模块拆分结果删除。
- Phase R5 新增四种 Compare、Ask 四模式与免费确定性结果、1 Credit Deep Analysis、Lilly considerations/fortitudes/perfection/timing、独立 Electional Core、Ask / Themes / Compare / Charts / Profile 五标签，以及 Charts/Themes/轮盘/固定 UI 调整。ZIP 外只补了实际 Xcode 构建暴露的兼容缺口：Best Time 不再读取 Horary `analysis`，旧 When 历史只读 `legacyHoraryAnalysis`，缺失主题色改用现有 amber，固定字号改为 Dynamic Type，Compare Swift 6 分支补显式返回，旧 Today 根标签观察移除。
- Relay 已补齐 `compare.me_over_time / two_people / two_places / relationship_over_time` 与 `ask.deep_analysis` scope、默认提示词初始化和管理端覆盖链路，分别生成客户端要求的严格 JSON；提示词要求只解释不可变事实、只引用稳定 Evidence ID、禁止重算或编造。未知引用被清理，summary/required section 全无有效证据时由 Relay 自动修复一次后失败并释放 Credit。Compare facts 编码现在显式携带稳定 `id`，且请求的 `compare_type` 必须与路由一致。Relay 会递归拒绝坐标、时区、出生时间、Profile、Snapshot、ChartSnapshot、渲染轮盘等禁止字段。
- Compare 与 Ask Deep Analysis 均为 1 Credit；失败、超时或持久化失败释放原预留，同一 requestID/相同请求哈希可以重新预留并重试，最终只在客户端完成原子本地保存后 ACK/消费一次。Relay 发放政策已与客户端文案对齐为首个 Free 周期总计 5、后续 Free 月 2、Pro 月 15；Annual 首购 20 bonus 保持不变。
- 2026-09-01 已修复 Phase R5 真机反馈：Compare 本地计算后立即进入历史并由 manager 持有后台报告任务；双人对比从关系事实生成最多 8 条“主要对比”，其他模式按确定性优先级显示最多 8 条“主要变化”，数量与列表一致；依据使用单一 sheet payload 立即读取本地事实；日期预设保持所选高亮；A/B 星盘使用分段标签切换。Ask Deep 任务改由持久 manager 持有，Ask 历史显示分析中/可重试；Themes 历史显示生成状态，结果页直接展示轮盘并保留详情入口。
- 生产 Relay 已切换到 `interstellar-relay:v6-20260901-build22-phase-r5`（`linux/amd64`，镜像 ID `sha256:1a8491142f73cdf2951f726c781afa4e458f83e90349aabec6332795afeac3f3`）。切换前 SQLite 在线 backup API 备份为 `/opt/interstellar/backups/relay-before-build22-phase-r5-20260901T141849Z.db`，SHA-256 为 `0ebec8acdaaebe7e495ba868122848a7b13c80bbd5fda0fe73074feda94898a7`；备份与切换后 integrity 均为 `ok`。四个 Compare scope 与 `ask.deep_analysis` 已在生产库注册，容器 healthy、RestartCount=0，公开 `/v1/health` 正常；Edge 自 2026-08-13 起未重建且 RestartCount=0。
- 当前 Phase R5 修复版已于 2026-09-01 以签名 Release 包再次覆盖安装到 `HUAWEI PURA 70`（iPhone 12 mini，设备 ID `F492A359-E624-5D05-8C41-B99A5B0B3926`），未卸载 App。安装包为 `Stelyra 1.0 (17)`、Bundle `com.xiaoguiwk.interstellar`，使用 production App Attest 和 `https://aaadmin.xiaoguiwk.top`；安装查询成功，启动后 `Interstellar` 进程 PID 24835 保持运行。未主动执行会消费 Credit 的 Compare / Ask 生产 smoke。
- 已验证：Phase R5 聚焦 Ask/Compare/Themes 合同 70/70；AstroCore 126/126；ContentKit 6/6；Relay 全量测试与 `go vet`；iPhone 12 mini Simulator 与签名 Release 真机构建；卡片合同、私有内容边界、Copy、本地化、架构、lint 和 `git diff --check`。仓库全量 Python 为 678 passed / 3 skipped / 17 failed；失败均为 ZIP 外既存后端数据或已被 Phase R5 取代的旧分支断言，包括 JPL 本地 artifact 缺失、旧 Charts/Reports 结构、旧八语假设和仍要求已拆除的 `SynastryView.swift`，未用旧断言覆盖 ZIP。
- 下一步只剩用户在真机进行视觉/交互和主动 Compare/Ask ACK smoke；消费型 smoke 必须由用户明确操作。

## 0.0 GitHub Pages 独立站（2026-08-31）

- GitHub 组织级 Pages 仓库 `Stelyra-Astro/Stelyra-Astro.github.io` 已发布独立静态站，不以 README 作为网页内容。营销首页、Privacy Policy、Terms of Use 分别位于 `https://stelyra-astro.github.io/`、`/privacy/`、`/terms/`。
- 营销首页包含产品定位、计算优先的事实链、Charts / Today / Themes / Reports / Relationships、隐私优势、辅助功能与联系邮箱。Privacy Policy 与 Terms of Use 提供 en / zh-Hans / es / fr 下拉切换；首页只保留一个正式 Privacy Policy 导航入口，隐私优势区不再伪装成第二份政策页面。
- Pages 发布源为 `main:/`，HTTPS 强制开启，部署状态为 `built`；提交为 `dcaf5bd`。三个公开地址均在线返回 HTTP 200，375 × 812 手机布局、语言切换、站内链接、控制台错误、敏感信息扫描及 `git diff --check` 已验证。
- iOS 的 Privacy / Terms 已从 Relay 静态页切换到 `https://stelyra-astro.github.io/privacy/` 与 `https://stelyra-astro.github.io/terms/`。许可协议继续使用 Apple Standard EULA，不设置自定义 EULA；Relay 域名只保留账户、购买、报告等动态 API 与旧版本兼容。
- iOS 营销版本已恢复为 `1.0`，下一构建号按 App Store Connect 当前最高 Build 16 设为 Build 17。签名 Release Archive `/private/tmp/Interstellar-1.0-17.xcarchive` 已生成并核对 Bundle、Team、arm64、production App Attest、Privacy manifest 与 Pages 基础 URL；上传尚未发生，Xcode 分发日志显示本机当前没有登录具备团队 App Store Connect 权限的账户。
- 本轮未修改 Relay 报告提示词面板，也未变更或部署 Relay。

## 0. Themes 结果视觉与 AI 授权修复（2026-08-30）

- Themes 结果页不再直接展开轮盘和相位矩阵；结果页只保留盘型/方向选择与 `View chart details`。详情页内使用 `Wheel / Aspects` 分段标签互斥切换，Aspects 展示真实相位矩阵。
- AI 授权在用户点击 Analyze 时前置检查。未授权时弹出 Theme 专用的 2 Credits 数据发送与扣费说明，允许后才开始本地计算和联网生成；取消后停留在设置页。兼容旧本地分析时，结果页也会弹授权提醒，授权缺失不再写入 `generationError` 或显示 `Written analysis unavailable`。
- `Preparing your analysis` 状态卡先按父容器扩宽再绘制卡片表面，左右边界与详情轮盘一致。iPhone 12 mini（`HUAWEI PURA 70`，iOS 26.6）真机专项验证：授权提醒 1/1 通过；Preparing 宽度、结果页视觉隔离、详情 Wheel/Aspects 切换、生产生成及重启本地恢复 1/1 通过。
- 签名 iPhoneOS Debug 构建、Themes/Charts 合同 29/29、卡片合同、Copy、本地化、架构、lint、私有内容边界与 `git diff --check` 均通过。本轮按用户要求不制作或上传新 Archive，既有 `1.0.1 (2)` 上传记录不变。

## 0.1 Stelyra 1.0.1 (2) Themes 与生产 Relay（2026-08-30）

- `charts` 已定向合入用户提供的 Themes iOS 改动并按现有事实链重构：每个 Theme 在本机计算所需的多个盘，合并并去重为一组带稳定 ID 的 facts，再只发起一次 AI 生成；同语义 `semanticFingerprint + factsHash` 命中时直接读取本地报告，不联网。客户端成功原子保存报告后才 ACK，Relay 在 ACK 时一次消费 2 Credits。
- Themes 共 8 个独立 scope 与提示词。生产提示词明确把请求中的 `params.focus` 作为首要分析重点，同时保留全部已提供证据；Themes 单次输出上限为 16,000 tokens，首次生成超时为 90 秒。现有旧默认提示词只在内容精确匹配时迁移，管理员手工修改的提示词不会被覆盖。
- Themes 结果页的总结卡和生成状态卡已按页面可用宽度铺满；AI 结果统一为标题、副标题、目录、编号正文分节及每节 callout，并显示轮盘和真实相位矩阵。底部追问按本轮决定未实现；后续需要独立的一 Credit 预约、原报告上下文合同、本地持久化与 ACK 流程。
- Charts 顶部保持三项固定快捷入口加 More，并在 iPhone 12 mini 真机加入不重叠、不越界断言。`HUAWEI PURA 70`（iPhone 12 mini，iOS 26.6）上的 Charts 紧凑布局专项与 Themes 生产生成/重启本地读取专项均为 1/1 通过；最新生产 Theme 请求为 `theme.life_direction / success / consumed / credit_cost=2`。
- 生产 Relay 最终切换为 `interstellar-relay:v6-20260830-build21-themes-focus`（`linux/amd64`，镜像 ID `sha256:d35adf75145f7d4ac514e3e8daacecd5fca84d6f9e0878c5df28139c23b9225e`）。切换前 SQLite 在线 backup API 备份为 `/opt/interstellar/backups/relay-before-build21-themes-focus-20260830T141658Z.db`，SHA-256 为 `db29748ad5d09c26cc118be9a152f9bc2df3eb18c6f03a323a3724fe73abde52`；备份与切换后 integrity 均为 `ok`，8/8 Theme 提示词均包含 focus 约束，容器 healthy、RestartCount=0，公开 `/v1/health` 正常，Edge/Caddy 未重建。
- `Stelyra 1.0.1 (2)` Archive 为 `/private/tmp/Interstellar-1.0.1-2.xcarchive`，arm64 UUID `03F05895-F9E5-38C8-A146-2B436B7F4F5A`，实际版本、Bundle、Team、production App Attest 与 Privacy manifest 已核对。2026-08-30 22:09 Xcode 对该 Archive 返回 `Upload succeeded`，已上传 App Store Connect 等待处理。
- 代码提交为 `e1c4b72`、`fc25260` 与 `8492d5d`。Relay 全量测试、`go vet`、Themes/Charts 合同测试 27/27、AstroCore 63/63、ContentKit 6/6、iPhoneOS Debug/Release Archive、卡片合同、私有内容边界、本地化、架构、lint 与 `git diff --check` 均通过。

## 0.2 Stelyra 1.0.1 (1) You / Bonds 与生产 Relay（2026-08-30）

- `charts` 已从 `interstellar-ios-charts-you-bonds-final-2026-08-29.zip` 定向合入 You / Bonds：16 种关系盘继续消费 AstroCore 权威 Artifact，不进入公开 `ChartKind` 或现有十二盘卡片合同。Synastry 继续路由既有解读卡片；其余新增关系盘没有私有语料时不渲染解读卡片，也不显示缺失语料占位，未新增或公开 Copy Catalog 正文。
- 消费者内容运行时已从旧混合资源拆为 Charts / Today / Week / Ask 四域。Today、Week 与 Ask 按 `area + locale + schemaVersion` 校验，Charts 只消费强校验 Copy Catalog，不再走旧 PrivateCorpus；私有构建器生成 10 个分域运行时文件。ZIP 原方案漏掉 Week 并会在周内容缺失时失败，现已补为独立 Week 域；真机 83 项 iOS 单元测试和新增分域合同测试通过。
- 固定 UI 已注册第九种 `pt-BR` 路由、地区、术语与帮助资源。当前 ZIP 仅提供葡语翻译骨架：1113 条固定 UI 中 1082 条仍为英文，AstroTerms 与帮助文档也仍为英文，因此不得把它标记为完整葡语内容交付；缺少对应 Charts / Today / Week / Ask 私有正文时明确显示内容不可用，不隐式借用英文解读。
- 压缩包没有账户、Keychain、App Attest 或 Relay endpoint 改动；Debug / Release 仍使用 production App Attest 与 `https://aaadmin.xiaoguiwk.top`。`Stelyra 1.0.1 (1)` 已直接覆盖安装到 `HUAWEI PURA 70`（iPhone 12 mini），未卸载 App；普通启动的 production challenge/token 为 200，既有 Apple identity 冲突按原精确兼容路径重试后 `/v1/account/sync` 为 200。
- Relay 已为 16 种关系盘加入独立 canonical English 整盘报告提示词与严格 `reportPromptKey == relationship.<kind>` 校验。管理端提示词页新增 You / Bonds / period 空间、技术族、精确 scope 和名称/scope 搜索筛选；生产库现有 31 个 canonical English 模板，其中 16 个为 relationship，保留 9 个不再使用的旧 locale 模板，总计 40 条。
- 生产 Relay 已切换到 `interstellar-relay:v6-20260829-build18-bonds-prompts`（`linux/amd64`，镜像 ID `sha256:9dd31ba9935eaa357ae1e4becf4aeadb1f14ecba5a083da7ecd81027882aaf08`）。切换前 SQLite 在线 backup API 备份为 `/opt/interstellar/backups/relay-before-build18-bonds-prompts-20260829T143300Z.db`，SHA-256 为 `a3d3e8edd968ed1f2ffbc96b510cf7d4f29faf838b36fae209f9c44aa4f5db2b`；备份与切换后 integrity 均为 `ok`。容器 healthy、RestartCount=0，公开 `/v1/health` 正常，Edge/Caddy 和其他服务未重建。
- 验证证据：Relay 全量测试与 `go vet`、iOS 83 项单元测试、AstroCore 63/63、ContentKit 6/6、Stage 9 与内容分域 Python 合同 12/12、iPhone 12 mini 真机 Composite 计算和无解读卡 UI 专项 1/1、签名真机构建、卡片合同、私有内容边界、四语 Copy Catalog、九语固定 UI、本地化、架构、lint 和 `git diff --check` 均通过。未主动生成新的 AI 报告或消耗 Credits。

## 0.3 Build 17 报告与布局修复（2026-08-29）

- Today Current Chapter 的标题/徽章和长标签改为按可用宽度切换布局，共享 `TagChip` 不再强制撑开父卡片；iPhone 12 mini 浅色 UI 回归已核对首卡右边界留在屏幕内。Ask History 打开完整会话改为一次无动画事务切换，真机等价模拟器流程验证保存后从 History 点入会在 2 秒内直接显示 `Your answer`。
- Charts 右上 Reports 统一进入 Reports 主页面；Reports 按 `ChartKind.allCases` 展示 12 盘，并继续观察 Snapshot、PendingReportManager 和本地 SavedReport 的实时状态。三级推运、月返、太阳弧、迁移盘、十二分盘、十三分盘均有 UI 可访问性回归。
- Relay 管理端已为 6 个新增盘加入独立英语提示词面板，正文来自 2026-08-28 用户提供的提示词文件。生产库现有 15 个 canonical English 模板，其中新增盘 6 个；旧翻译模板不删除但不再展示或用于生成。
- iOS 新报告请求发送实际 App 语言 `en / zh-Hans / es / fr / tr / de / it / ko`；Relay 统一读取英语提示词并附加目标输出语言约束，未知语言回退英语。首次安装按 `Locale.preferredLanguages.first` 匹配八语，匹配不到回退英语；已保存报告身份不含语言，因此切换语言不会翻译、失效或重新联网生成旧报告。
- 生产 Relay 已切换到 `interstellar-relay:v6-20260829-build17-reports-language`。切换前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build17-reports-language-20260828T162206Z.db`，SHA-256 为 `359a6ddd2970e3745c07fd3e0ee165a824955b1f8613e3ed9982039f653a7490`；备份与切换后 integrity 均为 `ok`。容器 healthy、RestartCount=0，公开 `/v1/health` 正常，Edge/Caddy 和其他服务未重建。
- Build 17 已覆盖安装到 `HUAWEI PURA 70`（iPhone 12 mini），设备显示 `Stelyra 1.0 (17)`。真机通过 production App Attest/Relay 实际生成 `chart.tertiary` 英语报告：Relay 审计为 `requested_locale=en / effective_locale=en / report_status=success / credit_status=consumed / credit_cost=1`；客户端打开报告后可见 Regenerate，终止并重启 App 后仍从 Reports 主页面本地打开同一报告。
- 验证证据：Relay 全量测试与 `go vet`、iOS 83 项单元测试、AstroCore 63/63、ContentKit 6/6、Today/Reports/Ask UI 专项、卡片合同、私有内容边界、四语 Copy Catalog、八语固定 UI、本地化、架构、lint 和 `git diff --check` 均通过。

## 0.4 charts / Build 16 恢复（2026-08-28）

- 当前工作分支为 `charts`。权威恢复源是第二个修订包 `interstellar-ios-stage9-relationship-techniques-xcodeproj-fix.zip`；它与第一个包的 App、AstroCore、十二盘和 Ask 源码相同，差异仅为生成后的 Xcode 工程、Stage 9 报告及工程源文件同步测试。
- Charts 已恢复 12 个公开盘型：原 6 个核心盘加三级推运、月返、太阳弧、迁移盘、十二分盘、十三分盘。Stage 9 的 16 种关系盘 technique 仍是 Themes 内部计算能力，不进入公开 `ChartKind`。
- Ask History 已恢复 schema v2 完整会话持久化；新记录可离线还原 Your Answer 和完整专业分析，旧 summary-only 记录继续兼容。
- 私有四语 Copy Catalog 已从 `ios/PrivateContent/copy-catalog-v2` 重建并验证：en / zh-Hans 各 2506 条，es / fr 各 2399 条，均为 51 个合同。八语固定 UI 与 AstroTerms 已进入 Build 16。
- Debug 与 Release 都使用 production App Attest 和 `https://aaadmin.xiaoguiwk.top`。客户端 App Attest Keychain key 按实际签名环境分 namespace；DEBUG 日志只输出 endpoint、HTTP status、server code 和 environment。
- 真机根因证据：production challenge/token 均为 200；带 Apple App Transaction 的 account sync 因历史 Apple identity 已绑定另一 active account 返回 `409 account_sync_failed`。客户端仅对该精确错误去掉 Apple identity 重试一次，仍保留 App Attest、installation 和 userID 全部 Relay 校验；真机重试后的 `/v1/account/sync` 连续返回 200。Relay 源码、配置、镜像和数据库均未修改。
- Build 16 已覆盖安装到 `HUAWEI PURA 70`（Bundle `com.xiaoguiwk.interstellar`），未卸载 App；设备由 Build 14 升级到 `Stelyra 1.0 (16)`。启动计算刷新完成且未崩溃。
- 验证证据：AstroCore 63/63、ContentKit 6/6、Stage 2–9 合同 59/59、第二包 Xcode 源同步测试 2/2、合并后的 iOS 单元测试退出 0、账户策略专项测试退出 0、真机签名 Debug build 退出 0；卡片合同、私有内容边界、本地化、架构、lint 和 `git diff --check` 通过。
- 未主动生成 AI Report，避免未经用户明确操作消耗 Credits；Reports 与账户同步共用的 App Attest/production Relay 鉴权链已经通过，实际报告生成仍需用户从 UI 发起一次消费型验收。

## 1. 当前快照

| 项目 | 当前值 |
|---|---|
| 分支 | `charts` |
| 源码基线提交 | `e1c4b72`、`fc25260`、`8492d5d`；Stelyra 1.0.1 (2) Themes 为当前交付 |
| Bundle / Team | `com.xiaoguiwk.interstellar` / `KCC8FFFAA5` |
| 测试设备 | iPhone 12 mini、iPhone 17 Pro Max |
| Relay | `https://aaadmin.xiaoguiwk.top` |
| 生产 Relay 镜像 | `interstellar-relay:v6-20260901-build22-phase-r5`；2026-09-01 22:19 部署，健康且 RestartCount=0 |

Build 8 Archive 已成功生成：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-20/Interstellar 2026-08-20 22.35.xcarchive
```

该 Archive 为 `1.0 (8)`、正式 Team 签名和 production App Attest。两台设备从 TestFlight 卸载重装后均能恢复并展示原有账户信息。

Build 9 Archive 已从干净提交 `e6fc5c3` 成功生成并上传：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-22/Interstellar 2026-08-22 17.16.xcarchive
```

该 Archive 为 `1.0 (9)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement，且包含 `PrivacyInfo.xcprivacy`。2026-08-22 Xcode 对同一 Archive 返回 `Upload succeeded` 与 `EXPORT SUCCEEDED`；当前等待 App Store Connect 处理。

Build 10 Archive 已于 2026-08-22 生成并以 TestFlight Internal Only 上传，账户所有者确认内部测试通过：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-22/Interstellar 2026-08-22 20.35.xcarchive
```

该 Archive 为 `1.0 (10)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement，包含 `PrivacyInfo.xcprivacy` 和 About 的 GitHub 源代码链接。arm64 UUID 为 `49B30C71-245A-3DF6-B8B2-09D1BF54F130`；归档与源码隐私清单 SHA-256 均为 `d4db607b85ebcfbdf526011f32aa5c5754422aab992624ae28b2f5974e488aa7`。

由于 Internal Only 构建不能用于外部 TestFlight 或正式提交，Build 11 App Store Connect 候选 Archive 已生成，尚未上传：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-22/Interstellar 2026-08-22 21.31.xcarchive
```

该 Archive 为 `1.0 (11)`，除构建号外功能源码与 Build 10 相同；Bundle、Team、production App Attest、无 Push Entitlement 和 `PrivacyInfo.xcprivacy` 均已从 Archive 本体核对，隐私清单与源码 SHA-256 同为 `d4db607b85ebcfbdf526011f32aa5c5754422aab992624ae28b2f5974e488aa7`，arm64 UUID 仍为 `49B30C71-245A-3DF6-B8B2-09D1BF54F130`。

Build 12 加入无感全球城市搜索与地图附近城市回退，最终候选 Archive 已生成但未上传：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 13.44.xcarchive
```

该 Archive 为 `1.0 (12)`，包含全部 234,994 个 GeoNames 城市和 394 个去重 IANA 时区。App 内 `OfflineLocations.sqlite3` 为 32,722,944 字节（约 31.2 MiB），SHA-256 为 `58e0cdc8cf02a115b44d2c49a95c089eec46011dda0ff487430cd98e8d5fbbe0`；约 48 MiB 的时区边界 ZIP 只作构建时补齐输入，没有进入 App Bundle。Archive App 为约 46 MiB，Archive 为约 77 MiB，arm64 UUID 为 `A9AE6373-DABE-3425-BF6A-4BFD18964661`。

Build 13 修复账户删除后客户端继续持有停用祖先 ID、删除重试只返回中间 successor，以及已有订阅落入通用购买失败的问题。Relay 仅允许已验证 installation 沿真实 successor 链恢复到该安装绑定的最新 active 账户；iOS 以 Relay 响应的 `userID` 更新 Keychain；订阅购买前将 subscribed、grace 和 billing retry 状态引导到 Restore。生产 Relay 已在 SQLite backup API 备份后切换，备份为 `/opt/interstellar/backups/relay-before-build13-account-recovery-20260823T062630Z.db`，切换前后 integrity 均为 `ok`、核心记录数一致。

Build 13 Archive 已生成、上传，并已安装到 iPhone 17 Pro Max：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 14.29.xcarchive
```

该 Archive 为 `1.0 (13)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement，包含与源码 SHA-256 一致的 `PrivacyInfo.xcprivacy`。城市库仍为 32,722,944 字节且 SHA-256 未变，时区边界 ZIP 未进入 App；Archive App 约 46 MiB、Archive 约 77 MiB，arm64 UUID 为 `07C2C164-4512-3D0F-AFAD-7ED6224B6D21`。Relay 全量测试、iOS 71 项单元测试、AstroCore 26 项、ContentKit 6 项和适用发布门禁均已通过。Build 13 真机暴露的剩余问题位于 Relay：账户同步已解析到 active successor 后，Apple 身份绑定仍误用请求中的 inactive ancestor，导致响应 409、客户端无法更新 Keychain。该问题已由 Relay 热修复，现有 Build 13 无需重新构建；17 Pro Max 仍需完成最终恢复/删除验收。

Build 14 修复消耗型 Credits 的未完成交易阻断，并在删除账户前强制取得有效的“媒体与购买项目”凭据。iOS 会在启动、交易更新和下一次购买前重试 unfinished 消耗品；Relay 根据 Apple 签名 token 将交易记到真实购买归属，缺失 token 时仅允许当前已验证 installation 入账，旧/其他账户交易只结算原归属而不误发给当前账户，永久拒绝也返回可 finish 的终态；网络或服务端暂时失败仍保留重试。Relay 只保存 JWS SHA-256 与终态元数据，不保存 JWS 正文。Settings 已在 About 下方、Show Welcome Guide Again 上方增加常驻 Terms of Use 与 Privacy Policy 入口，继续复用付费墙的四语法律页面和离线降级正文；入口顺序和两页打开行为已有 UI 回归测试。生产镜像已部署为 `interstellar-relay:v6-20260823-build14-storekit-terminal-reconciliation`；部署前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build14-storekit-terminal-reconciliation-20260823T082439Z.db`，SHA-256 为 `fc2529302b34974c1d1ad596f9e1f10e89196fa8bc2b25864b4a06eacdd8ef43`。切换前后 integrity 均为 `ok`，账户、交易、grant、账本和 Apple 身份计数一致，容器 healthy、RestartCount=0，Edge/Caddy 未重建。

Build 14 最终 Archive 已生成并上传：

```text
/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 16.46.xcarchive
```

Archive 实际为 `1.0 (14)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement；隐私清单与源码 SHA-256 同为 `d4db607b85ebcfbdf526011f32aa5c5754422aab992624ae28b2f5974e488aa7`。城市库仍为 32,722,944 字节，SHA-256 为 `58e0cdc8cf02a115b44d2c49a95c089eec46011dda0ff487430cd98e8d5fbbe0`，时区 ZIP/GeoJSON 未进入 App。Archive App 约 46 MiB、Archive 约 77 MiB，arm64 UUID 为 `06766184-B17E-3EDC-BAEA-CAD849B84FC7`。Xcode 对同一 Archive 返回 `Upload succeeded` 与 `EXPORT SUCCEEDED`，当前由 App Store Connect 处理。iPhone 12 mini 安装并打开 TestFlight Build 14 后，必须以 Relay 对账审计和后续 `credits_10` 购买流程验证旧阻断已清除；完成前不得标记真机问题已解决。

公开 iOS 源码已按白名单导出为独立、无混合仓库历史的公开仓库：`https://github.com/Stelyra-Astro/interstellar-ios`。导出不含 Web、Relay、私有语料/规则、运行时私有 Catalog、凭据、用户数据或构建缓存；README 只说明源码性质、不展示 Build 号，公开工程内部构建设置已同步到 11。

## 2. Build 8 后已合入 Build 9 的源码改动

### StoreKit 交易归属

- `Transaction.updates`、Restore 和 unfinished retry 只提交 `appAccountToken` 精确等于当前 Commerce user ID 的交易。
- 外来或缺失 token 的交易只跳过，不 finish、不入账、不显示 pending，也不阻断后续属于当前用户的交易。
- 用户主动购买若返回外来或缺失 token，显示普通购买失败；Relay 的严格 token 校验没有放宽。
- 这些改动必须进入 Build 9 或更高版本后再做 TestFlight 验证。

### Today 与长文本

- 移除了 Current Chapter 上方多余间距。
- Current Chapter 及相关长标题支持自然换行。
- Today 说明文字字号已与其他页面的对应层级统一。
- Today、Profile 和合盘中的适用长文本已取消不必要的单行截断。

### backlog P0/P1 实施（2026-08-21）

P0 四项全部完成：

- Retrogrades 计数与列表统一：TodayView 逆行列表去掉 `prefix(3)`，计数和列表消费同一事实集合。
- 报告 pending 杀进程恢复：新增 `PendingReportManager.hasPendingChartReport(chartPrefix:)`，`aiReportStatus` / `refreshAIReportStates` / `generateAIReport` 均消费持久化 pending；ReportsView 通过 `@ObservedObject PendingReportManager.shared` 观察变化，重开 App 立即恢复"生成中"状态。
- Settings Reset 全链路删除：ProfileView 的 Reset section、`Commerce.resetAccount()`、`project.yml` 与 `project.pbxproj` 的 `ACCOUNT_RESET_TESTING`、三个本地化键；Relay 删除 `/v1/account/reset` 路由、`handleAccountReset`、`ResetCommerceUser` 及三个相关测试。`account_resets` 历史记录保留只读展示。Relay 端已随 `v6-20260821-provider-presets` 部署到生产（release readiness 已核销）。
- Today Timeline 空态修复：AppModel 新增 `todayEventsDayKey`（记录扫描成功的本地日）与 `refreshTodayEventsIfNeeded()`；Timeline 只在"当前本地日扫描成功且无事件"时显示"安静的一天"，数据陈旧时显示"正在更新"并在 Today 出现 / 回到前台时重扫；扫描失败保留旧数据。

P1 完成项：

- Ask `Choose one path` 页删除"Your question is calculated..."，四语只保留"Choose one path."。
- Support 入口直达 Feedback 表单，删除 `SupportSettingsView` 中间页。
- Feedback 页脚删除 AI 联网后半句；新增"被采纳的优质创意可能获得 Bonus Credits"提示。
- Reports 卡片状态改用最新报告时间（精确到分钟、Locale-aware）；删除底部 Saved 模块；清理周期报告残留代码（`ReportScope` / `AvailableReport` / `ReportUnlock` / `generatePeriodReport` / `refreshAvailableReports` / `availableRow` / `PeriodReportGenerationSheet` / `AIFactsBuilder.periodDocument` / `remainingDays/Hours`）。`PendingGeneration.periodScope` 与 `deliver` 的 period 分支保留以兼容旧数据。
- Local Data 的 `Local-first Calculations` 宣传文案替换为 AI 开关旁的 ChatGPT 披露（`profile.ai-assistance-disclosure`：报告的某些措辞借用 ChatGPT 优化、所需计算事实经 Interstellar Relay 发送、关闭开关只阻止未来生成且本机已有报告仍可阅读）。
- Relay provider 预设：`main.go` 新增 `providerPresets`（deepseek + openai）与 `seedProviderPresets`，`RELAY_SEED_PROVIDERS`（默认 1）取代 `RELAY_SEED_DEEPSEEK`；`handlers.go` 删除 BaseURL 的 DeepSeek 硬编码回退（空则 400）；admin.html 文案中性化、添加 Provider 支持按 ID 预填预设。LLM 调用本身为 OpenAI 兼容（`/chat/completions` + Bearer），切换 GPT 无需改请求代码。
- 本地化源 `ui-translations.json`：删 23 个废弃键、改 2 个、增 3 个；`Localizable.xcstrings` 由 `scripts/build-ios-localization.mjs` 重新生成（不要手工编辑 xcstrings）。

Ask History 保存完整结果按用户决定本轮不做，仍留在 backlog。

## 3. 账户和购买结论

- 卸载重装后的账户读取故障已修复。根因是容器清空后 Keychain 仍保留失效的 App Attest key ID；新容器现在只轮换 App Attest key ID，保留 Commerce user ID 和 installation ID。
- 旧 Sandbox Apple Account 的订阅/交易状态会造成异常：17 Pro Max 点击 Annual 没有产生 transaction；换用新的 Sandbox Apple Account 后购买立即恢复。因此不得通过 Reset 或更换 App user ID 处理这类 Apple 账户问题。
- Relay 已确认新 Apple 测试账户购买的是 `credits_10`，并产生 `PURCHASE +10` Ledger。Annual 仍为原有效订阅，没有第二条 Annual 交易。
- Monthly 和 Annual 都是自动续期订阅；首版不实现 App 内 Monthly → Annual 主动切换，该能力已转入产品 backlog，不阻塞 Build 9。

## 4. 当前工作区

Build 9 的功能代码已全部完成并冻结于 `e6fc5c3`：iOS 删除本机/iCloud 个人数据和全部可用 Credits，Relay 停用旧 User ID 并自动创建空的新 ID；旧 ID 卡只保留根/前后继关联以及购买、订阅、Credit 财务历史。仍生效的 Apple 订阅由 Restore 触发 Relay 校验同一 ID 链并调用 App Store Server API 重绑 `appAccountToken`；同一 Apple 购买身份的月度 2 Credits、当期 Pro 10 Credits 和 Annual 首次 20 Credits 均防重复。

Build 9 同时包含 PrivacyInfo、移除未使用 Push Entitlement、ChatGPT 报告辅助披露和双层出站最小化：ChatGPT 只接收名字/昵称、适用时的关系类型与计算结果，不接收 Profile 出生日期、出生时间、出生地点或明文地点/时区参数；报告 ACK 后 Relay 删除 payload。生产 Relay 已部署对应提交的镜像，Build 9 已上传；除 TestFlight 或 Privacy Report 暴露必须修复的问题外，当前没有计划中的代码改动。

当前未提交的 Build 10 工作区包含 Today 时间线/标签/抽屉、默认深色、删除账户入口移动到 Local Data、About 的 GitHub 源代码链接与 Support 邮箱 `Stelyra-Astro@proton.me`。Ask History 完整结果和 GitHub Pages 均已按用户决定延期，半成品代码及链接已撤回；Terms / Privacy 继续使用现有 Relay 页面。

## 5. 已有验证与缺口

已验证：

- iPhone 17 Pro Max 的 TestFlight Build 9 已完成账户面向用户的关键路径：删除账户与数据后自动创建新的 Free User ID，旧个人数据清除；有有效订阅的 Apple 购买账户 Restore 后恢复 Pro，无购买记录的全新 Sandbox Apple Account Restore 后仍保持 Free。2026-08-22 由账户所有者确认全部通过。
- Relay 管理端的旧 ID Inactive、lineage、财务历史保留、订阅重绑和周期 Credits 防重复已核对；Build 9 卸载重装、App Attest、生产 Relay 连通性以及报告生成、保存、ACK smoke 均通过。生产 ChatGPT Provider 也已完成配置；2026-08-22 由账户所有者确认。
- 账户删除/重建/恢复实现已通过 Relay 全量测试：覆盖旧 ID Inactive、新 ID 自动创建、根/前任/后继链、报告元数据删除、购买/订阅/Credit 财务历史保留、停用账户禁止后台调整或未来发放 Credits、在途消耗品只记财务流水不恢复可用余额、App Store Server API `appAccountToken` PUT 请求，以及恢复时当月免费 2、当期 Pro 10、Annual 首次 20 Credits 不重复。
- ChatGPT 四语授权弹窗、Settings 披露与 Privacy Policy 已统一为“只辅助优化用户主动请求的报告”；iOS 出站请求和 Relay 防御性过滤都会删除地点、经纬度、时区、原始星盘 `utcDate/julianDay` 和其他请求范围参数，只保留关系类型、名字/昵称和计算事实，计算事件日期/窗口继续作为结果证据。相关本地化校验、1 个 iOS 定向测试及 3 个 Relay 定向测试通过。
- iPhone 12 mini 模拟器的 `InterstellarTests` 61/61 通过，新增账户删除 UI/StoreKit/AppTransaction 代码以 warnings-as-errors 编译通过；测试结果位于 `/Users/xiaoguiwk/Library/Developer/Xcode/DerivedData/Interstellar-eshzmcxczhiwkmbqyhrenozmqdfg/Logs/Test/Test-Interstellar-2026.08.22_15-56-15-+0800.xcresult`。AstroCore 26/26、ContentKit 6/6、Go vet、管理端 JavaScript 语法检查和全部项目门禁通过。

- Build 8 Archive 返回 `ARCHIVE SUCCEEDED`，签名、Bundle、Team 和 production App Attest 已核对。
- iPhone 12 mini 的 Build 8 Release 账户恢复通过；用户随后确认两台 TestFlight 重装后的账户信息都正确。
- CommerceTests 19/19 通过，包含新容器轮换、同容器保留 App Attest key、Relay 权威状态和客户端缓存到期测试。
- Build 8 后的 StoreKit ownership 改动及 UI 改动通过 iPhoneOS 无签名 `build-for-testing` 编译。
- 生产购买诊断只读进行，未修改生产数据库；诊断前已有数据库备份。
- 本轮 backlog 改动门禁全过：`npm run ios:copy:validate`、`npm run ios:localization:validate`（1020 键、915 个代码引用，es/fr 各 1020）、`scripts/check-ios-card-contract.sh`、`npm run architecture:check`、`npm run lint -- --quiet`、`scripts/check-private-content.sh`、`git diff --check`。
- Relay 改动后 `go build ./... && go vet ./... && go test ./...` 通过；App Store Server API 凭据已通过 Sandbox 官方端点验证，Production 在首个正式版发布前按 Apple 限制返回 401。
- AstroCore 26/26、ContentKit 6/6 通过；InterstellarTests 57/57 通过（iPhone 12 mini 模拟器），结果包为 `/private/tmp/interstellar-unit-final.xcresult`。
- iOS generic iPhoneOS 无签名完整 `build` 返回 `BUILD SUCCEEDED`。
- UI 测试 `testLightModeScreensAndChartsSmokeTest` 在删除 Support 中间页断言后通过。
- 原 4 个 VisualRegression 失败均已修复并在 iPhone 12 mini 模拟器单独通过：`testCommerceEntryButtonsOpenPurchaseSheets`、`testEventDrivenCardsRender`、`testModernTransitPrototypeCards`、`testSynastryPrototypeCardsAndDrawer`。根因分别为 sheet 的 Cancel 按钮未滚入可点击区域、付费卡测试依赖残留购买状态、合盘断言仍使用旧 `THE BOND`/旧抽屉文案，以及测试点击了外层标题而不是卡片。全卡测试现在使用 DEBUG-only premium fixture，合盘卡有稳定 accessibility identifier/action；没有回退长文本换行修复。
- 三套部署 Compose 已用 `docker-compose config --quiet` 和非敏感占位变量校验通过。
- 生产 Relay 已部署 `linux/amd64` 镜像 `interstellar-relay:v6-20260822-app-store-sync`（镜像 ID `sha256:91234e32c8a6cc1142aa56b1f194a00ee3a55bbb427435d49e64cb5c31bfeb89`）；切换前通过 SQLite backup API 备份权威 Docker volume 数据库到 `/opt/interstellar/backups/relay-20260822-1335-before-app-store-sync.db`，SHA-256 为 `03314fedb70e8dcf08734796e093a9aa3b53166265dfb9cf1466b64c49ac5043`，切换前后 integrity 均为 `ok`。部署后 `/v1/health` 正常、容器 healthy、RestartCount=0；2 条现有订阅已通过 Sandbox Server API 对账并标记环境，Sandbox notification history checkpoint 已写入；Provider 仍为 3 个且原 `DeepSeek` 保持默认。
- 账户生命周期版生产 Relay 已部署为 `interstellar-relay:v6-20260822-account-lifecycle-e6fc5c3`（镜像 ID `sha256:fbc5deed2cbf2cd57cfc71a44f848bdbdb6867de6218c5c76ad52ddb52b48915`）。部署前 SQLite backup API 备份位于 `/opt/interstellar/backups/relay-20260822-before-account-lifecycle-e6fc5c3.db`，SHA-256 为 `fa9e2938dbf7361327a68115907d5dc6769a537e6488dafb1e059dce80c1222f`；切换前后 integrity 为 `ok`，核心财务记录数一致。账户 lifecycle 字段、`apple_identities` 和 `apple_credit_claims` 均已落库；容器 healthy、RestartCount=0，`/v1/health`、`/privacy`、`/terms` 通过，Edge/Caddy 未重建。
- Build 9 Archive 返回 `ARCHIVE SUCCEEDED`；实际版本、Bundle、Team、production App Attest、无 Push Entitlement 和隐私清单已核对。同一 Archive 上传后返回 `Upload succeeded` 与 `EXPORT SUCCEEDED`。
- 同一 Build 9 Archive 的 Xcode Privacy Report 已生成并完成文本及渲染检查：1 页、7 类数据，全部为 App Functionality、Linked、Not Tracking；Archive 和源码隐私清单 SHA-256 同为 `d4db607b85ebcfbdf526011f32aa5c5754422aab992624ae28b2f5974e488aa7`，PDF SHA-256 为 `b8e45adbe909b383fee32311c544482dbbf23b80694299f6379d79bdf3792b84`，没有需要修改 Build 9 的差异。
- 生产 Provider 预设部署未覆盖原配置；随后账户所有者已完成 ChatGPT Provider 配置。
- Build 10 工作区重新生成工程与四语固定 UI 后，iPhone 12 mini 模拟器 `build-for-testing` 通过；此前失败的 `testChartsCompactHeaderAndParametersSheet` 与 `testChineseCardsRender` 已改为断言稳定结构并分别通过。卡片合同、Copy Catalog、本地化、架构、lint、私有内容和 `git diff --check` 门禁通过；Build 10 已以 Internal Only 上传并完成内部测试。
- Build 11 只提升构建号；卡片合同、私有内容、四语固定 UI、四语 Copy Catalog、架构、lint 与 diff 门禁通过，Archive 返回 `ARCHIVE SUCCEEDED`，实际版本、Bundle、Team、production App Attest、无 Push Entitlement、隐私清单和 UUID 均已核对。
- Build 12 的离线地点生成器 fixture 测试、生产数据库可重复生成与 `PRAGMA integrity_check` 通过；iPhone 12 mini 模拟器 `InterstellarTests` 67/67、真机地点专项测试通过，覆盖巴黎搜索、巴黎地图点选得到 `Europe/Paris` 和远洋点不猜时区。AstroCore 26/26、ContentKit 6/6、全部项目门禁和通用 iPhoneOS Release 构建通过。
- 真机测试期间 Debug 包因 development App Attest 被严格生产 Relay 拒绝，表现为账户信息无法刷新；服务器日志确认原因后已用 Build 12 Release 覆盖安装并保持同一应用容器，之后未再出现 App Attest 拒绝。此问题是测试签名环境切换，不是地点改动或账户数据变化。
- 公开 iOS 仓库已完成暂存清单级审计：私有目录与运行时 Catalog、凭据特征、本机路径、日志/数据库、Archive/IPA、SwiftPM `.build` 缓存均未进入提交；生成的 Xcode 工程不存在私有资源引用。远端 `main` 已可回读，仓库为 Public 且非空。

仍需验证：

- 最终包仍需验证外来或缺失 `appAccountToken` transaction 队列不会错误入账、finish 或阻塞当前账户交易；两项对应 StoreKit ownership 测试已编译但尚未在真机执行，不机械重跑未受影响的完整测试套件。
- 在 App Store Connect 按已生成的 Xcode Privacy Report 核对并同步 App Privacy Answers。
- Build 12 尚未通过 App Store Connect 上传；公开 iOS 仓库尚未同步本轮地点源码与数据许可，外部 TestFlight 人工视觉、长文本和 Dynamic Type smoke 尚未执行。
- 完整 TestFlight、隐私和 App Store Connect 门禁见 release readiness。
- App Store Connect 的 Production/Sandbox Server URL 均已配置；2026-08-22 通过 App Store Server API 发送 V2 Sandbox `TEST`，Apple 投递状态为 `SUCCESS`，Relay 审计表记录 `TEST / Sandbox`。

## 6. Relay 当前边界

- 报告链路为 create → poll → fetch → 本机保存 → ACK；Relay 只在交付期间持有 payload，ACK 后删除。
- 生产 App Attest 已使用严格配置：开发绕过和 development 环境均关闭，Bundle/Team App ID 与最低版本要求已核对。
- provider 预设版已部署；现有大写 `DeepSeek` ID 保持默认，新建的小写 `deepseek`/`openai` 仅作预设。切换 OpenAI 前必须由管理员填 Key、拉模型并完成连接测试，不得在无验证时改默认路由。
- App Store V2 通知会校验 Apple 签名并审计事件元数据，不保存 JWS 正文；不带交易信息的有效 `TEST` 会返回 2xx。Server API 每 6 小时补偿同步订阅状态和通知历史，不依赖用户打开 App。
- App Store Server API 的 Sandbox 查询和 V2 `TEST` 通知投递已验证；Production 查询在首个正式版发布前返回 Apple 401，首发后必须重新验证。
- 修改或再次部署 Relay 前按 `AGENTS.md` 路由阅读 `infra/deploy/` 合同，先备份数据库并核对目标镜像和环境。

## 7. 建议接手顺序

1. 先把 Build 12 本轮公开 iOS 源码、生成脚本和数据许可同步到公开仓库，不得上传私有 Catalog 或时区构建缓存。
2. 在 Xcode Organizer 对 Build 12 最终 Archive 选择 `App Store Connect` → `Upload`，并确保未勾选 `TestFlight internal testing only`。不得选择会生成 Ad Hoc Profile 的 `Release Testing`，也不得再次选择 `TestFlight Internal Only`。
3. 处理完成后把 Build 12 加入 External Testing 群组并提交 Beta App Review；审核通过后创建 Public Link。正式版 `1.0` 可并行选择同一 Build 12 提交 App Review，发布方式建议选择手动发布。
4. 在 App Store Connect 按已生成的 Privacy Report 同步核对 App Privacy Answers，并补齐正式版元数据、内购/订阅审核关联和审核说明。

> AI生成
