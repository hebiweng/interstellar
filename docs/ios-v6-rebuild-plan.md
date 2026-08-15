# Interstellar iOS v6 重构执行合同

| 字段 | 值 |
|---|---|
| 生效日期 | 2026-08-01 |
| 当前分支 | `codex/ios-v6-rebuild` |
| 快照分支 | `codex/deepseek-v6-snapshot` |
| 范围 | iOS 六盘、v6 Today、AI Artifact、Go Relay、`/xiaoguiwk` |
| 延期 | Composite、跨设备报告同步、Web 消费端、旧 `/admin` 迁移 |

本文件取代旧 iOS V1 计划；旧计划已从当前工作树删除，只能从 Git 历史查阅，不再作为任何实现依据。

## 1. 决策优先级

1. 真实计算与不可变 Snapshot；
2. 当前产品合同和本文件；
3. `docs/ios-card-implementation-matrix.md`；
4. v6 原型的信息层级、密度和视觉参考；
5. DeepSeek 已实现代码。

原型不是字段权威。Ask、Profile 及已有合理设计即使原型未出现也继续保留。需要新增计算事实时直接补 AstroCore、Snapshot、事件模型或 Relay 契约，展示层不得猜测。

## 2. 冻结合同

- 六盘：本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8；
- Today：`Current Chapter / Active Today / Coming Next / Moon Today / Timeline / Upcoming Sky / Retrogrades / Current Sky`；
- `InsightCard`：卡片级可选结论 + 多个稳定事实；每个事实为“计算结果 + 私有一句自然解读”；
- 永久取消单卡 AI 详情；六盘各自只生成一份 4–8 节整盘报告，并在本机长期保存；
- 星盘计算和 Charts 打开不得自动触发 AI。用户进入 Reports 后明确点击“生成报告”才联网；同语义再次进入直接展示已有报告，“重新生成”成功后覆盖原报告；
- 同语义指纹命中本地 Artifact 时网络请求数必须为零；
- Relay 永不保存报告正文或报告结果缓存，只保留请求、验证、交付和 Credit 元数据；AI 只能解释并引用请求事实；
- 生成前预留 Credit，客户端报告通过校验并成功本地持久化后发送 ACK；只有 ACK 事务消费 Credit，未 ACK、生成失败、校验失败或本地保存失败均释放预留；
- Modern / Classical、英文 / 简体中文、System / Light / Dark；
- 服务器已由用户重启；旧 Interstellar Web/API/Edge 容器已停止并保留。Relay 完成后使用本机/CI 产出的 linux/amd64 镜像部署，禁止在低内存服务器现场编译。

### 正式内容链路

```text
ChartSnapshot / Aspect / Event
→ StandardSignalBuilder
→ CardEvidencePlanner
→ ThemeMapper
→ CopyCatalogMatcher
→ CardTextModel
→ InsightCard / Today
```

- 英文和简体中文源附件必须转换为项目稳定 ID、`selector`、`factRefs/evidence` 与 51 个六盘/Today 卡片合同后才可成为运行时资源，禁止原附件直接打包；
- `approved` 与结构合法性是两个独立条件，必须同时通过；构建前、单元测试和 CI 都执行正式 JSON Schema 与引用完整性校验；
- 技术事实模板最多 3 个强类型变量且只输出事实；消费者标题、正文和建议原则上 0 个、最多 2 个变量；
- 西班牙语和法语本轮提供必要 UI 翻译，审核语料未交付前回退到英文；不得继续扩展 Swift 中的双语 `localized(en, zh)` 硬编码方式。

### 本地化分层

- `Localizable.xcstrings`：按钮、Tab、页面标题、设置、权限、空状态、错误、加载、报告和 Ask 固定文字；
- `AstroTerms-{en,zh-Hans,es,fr}.json`：行星、星座、宫位、相位、阶段、逆行状态、元素、模式、角点、月相和盘型等统一术语；
- `CopyCatalog-{locale}`：消费者卡片、Today 与受控解释正文；
- 日期、时间、数字、单复数、日期区间和动态句序由 Locale-aware formatter / String Catalog variation 处理，不能按英文词序机械替换变量；
- AI 请求、提示词、输出校验和 Artifact 指纹均包含语言；不同语言不能共享正文缓存；
- App Store 元数据与运行时资源分开维护，不塞入 Copy Catalog。

## 3. ChartContext 参数

地点参数只能来自 Apple 地图当前位置、搜索或点选；消费者 UI 不显示或编辑经纬度，时区由地点自动确定并只读展示。

Ask Life Areas 默认空且必须显式选择。一个 Primary Area 决定核心 significator，Related Areas 只提供辅助证据；每个 Related 项必须提供明确的“设为 Primary”操作。A/B/C 可使用 Shared Primary + Shared Related + Option Additional，或无 Shared Primary 时由每个 Option 显式选择 Primary；禁止 option-level Primary override。只有显式 Shared Primary 的 A/B/C 才按盘的 sect 使用 triplicity rulers 分配独立 significator，混合 Primary 不得因局部宫位重复触发。

Ask 的 Judgment 与 Support 必须分离。Judgment 消费真实 direct perfection、换座、station/refranation、基础 prohibition、translation 与 collection 事件证据；Support 只描述 reception、行星状态、Moon 与 Related Areas，不得决定 Judgment，也不得在 A/B/C 间归一化成合计 100%。同领域选择依次比较有效完成、合相、完成先后、reception、condition 与 Moon；证据相同必须保留无明确领先结果，不能继续增加无传统依据的 tie-break。`Find the Best Time` 继续使用独立 Electional Timing 合同，不得被 Horary Judgment 改造污染。

| 盘型 | 参数 |
|---|---|
| 本命 | 人物出生资料 |
| 天象 | 默认当前时间/地点；可选日期、时间、地点 |
| 行运 | 默认当前时间；可选目标时间，高级地点与 7/30/90 天范围 |
| 次限 | 目标日期；无独立地点/relocation |
| 日返 | 年份、生日所在地 |
| 合盘 | 两位已保存人物；无目标时间地点 |

任何参数变化先重算权威 Snapshot，再按新指纹读取或生成 Artifact。Today 始终使用当前实际上下文，不被 Charts 的探索参数污染。

## 4. AI 与缓存

`GeneratedChartArtifact` 必须记录语义指纹、盘型、人物哈希、参数、语言、预设、事实哈希、Provider、模型、提示词版本、Schema、生成时间和整盘报告。

- 首次联网前展示一次完整数据范围和删除方式；授权不等于自动生成，必须由用户在 Reports 中明确触发；
- 生成期间允许离开 Reports 页面并稍后返回查看；重新生成失败时保留旧报告，成功后原子覆盖同语义报告；
- 撤回授权不删除已有报告，但阻止后续请求；
- 人物删除同步删除关联 Artifact；支持按人物、盘型和全部清除；
- 文件原子写入并启用 iOS 文件保护；损坏文件视为未命中；
- 后台提示词变化不主动使本机旧报告失效；手动“重新生成”覆盖当前语义版本。

### Pro、Credits 与 iCloud

- 消费者名称统一为 Pro，内部兼容 Product ID 保持 `premium_monthly`（$4.99/月）与 `premium_annual`（$39.99/年）；消耗型商品固定为 `credits_10`（10 Credits / $1.99）与 `credits_20`（20 Credits / $2.99）；开发 Scheme 固定加载 `Interstellar.storekit`；
- Free 完整开放 Today、本命、天象、Ask、Chart Wheel、Aspects、日期、地点、范围与其他参数；Special 仅兼容历史数据，不向消费者提供选择；
- Free 在行运、合盘、日返、次限只开放第 1 张 Interpretation Card，第 2 张起使用不泄露正文的锁定卡触发 contextual Paywall；Free 允许本人加 2 位其他人物，新增第 3 位时触发 Paywall；
- Free 进入上述 Premium 盘时必须在首屏明确显示“第 1 张免费预览、其余需 Premium”，不能只在滚动到第 2 张卡后才看到付费提示；
- 所有账户每个 UTC 自然月获得 2 个免费 Credits；Pro 在保留这 2 个免费 Credits 的基础上，按订阅锚点每月额外获得 10 个 Pro Credits，两类月度额度均为替换而非累加；Annual 首次购买一次性发放 20 Bonus Credits、1 年过期，续订、恢复与交易重放不得重复；
- Credit 消耗顺序固定为 allowance → 有期限的 bonus/admin → purchased；购买的 Credits 永不过期。Relay 是余额、预留、消费、释放与 Ledger 的唯一权威；
- 匿名 `userID` 由首次启动生成并保存到 Keychain，与 installation ID 分离；Profile 底部以小字展示可复制 User ID，StoreKit 使用 `appAccountToken=userID`，恢复购买只允许经 Apple 签名交易把新安装重新关联到原 UUID；
- iCloud 备份由用户设置控制，只写用户私人 ubiquity container，包含 Profile、其他人物、语言/外观/字号/预设、六盘报告和周期报告；Relay 不参与跨设备报告存储；
- Profile 首屏明显展示 Free/Pro、总 Credits、月度额度、限期赠送、永久购买额度、刷新日期、Pro 有效期与最近 Credit 增减流水；
- 所有 Charts 与 Reports 生成入口在确认操作前显示当前 Credits、固定成本 1 Credit 和成功生成后的预计余额；
- Pro 与购买 Credits 均使用底部抽屉；Pro 抽屉默认选中 Annual，并提供 Monthly、Continue、Restore、Terms 与 Privacy。Terms / Privacy 正文随 App 本地打包，不依赖服务器请求；首次启动使用两页向导说明四个主入口以及 Free/Pro 区别，设置中允许再次打开向导。

## 5. Relay 与后台

- Relay 与独立后台的正式权威域名为 `https://aaadmin.xiaoguiwk.top`；站点根路径与 `/xiaoguiwk` 均打开嵌入式管理端，不依赖旧 Web；
- 请求包含稳定事实、`semanticFingerprint / factsHash / generationSchemaVersion`、语言和预设；不再包含卡片 ID、每卡允许证据或 `TransitContentPlan`；
- 响应只包含 4–8 节整盘报告；每节携带 `evidenceFactIDs`，Relay 验证其来自本次请求事实，并验证 Schema 与语言；
- `requestID` 只能预留和消费一次；同 ID 的并发或重放不得再次调用 AI 或再次扣费。由于 Relay 不保存正文，未成功 ACK 的结果不能由服务器恢复，释放后必须使用新 `requestID` 重新生成；
- 上游非法 JSON 最多修复重试一次；失败不得进入 awaiting-ACK 或消费 Credit；
- Provider/模型停用必须阻止生成；默认 Provider 由设置决定，不硬编码 `default`；
- 管理密码使用 bcrypt，管理会话持久、可撤销、HttpOnly/SameSite；同源访问，不允许 `*` CORS；
- 密钥加密；审计只记动作与范围，不记出生资料、事实正文、提示词正文或 AI 正文；Relay 数据库不建立报告正文缓存；
- 生产生成链路需要 App Attest 安装级短期令牌、请求体断言、设备级限流和每日配额；模拟器绕过只允许开发环境。
- App Store 客户端交易和 Server Notifications V2 均验证 Apple `x5c` / ES256 JWS；续订、到期、撤销、退款和交易重放只更新同一权威权益/Grant，不重复发放；
- 管理端 Reports 支持 User、盘型、语言、状态、日期筛选并展示 Tokens、耗时和 `creditCost/creditStatus`，Report ID / Request ID 分行换行展示，不保留无增量信息的详情按钮；所有管理端时间统一按 Asia/Shanghai 的人类可读格式显示。Users 展示 Apple/Admin Pro、到期、分钱包余额、Grant 明细和报告数，并提供带审计的 Free/Pro/Apple Auto 强制切换、赠送 Credits、扣减 Credits，以及只取消未使用后台赠送的“恢复默认 Credits”，供未接入 App Store Connect 前的真机测试使用。

## 6. 实施阶段

1. DeepSeek 快照与重构分支；
2. 共享模型、ChartContext、事件与 Artifact；
3. 规范、计划、矩阵和交接统一；
4. 本命 Emotional Needs 垂直切片，再扩展六盘；
5. Today、参数、Reports 和本地 AI 体验；
6. Relay、`/xiaoguiwk`、鉴权、缓存、审计和配额；
7. iPhone 12 mini、自动门禁、本机构建镜像；用户重启后部署。

每个阶段真正完成后，通过用户指定的 Bark 地址发送“第几步 + 完成内容”通知。部分完成不得发送完成通知。

## 7. 当前证据（2026-08-02）

- 阶段 1 已完成：DeepSeek 快照提交 `a42f1d6`，重构分支基线 `7d5b115`；
- 阶段 2 已完成：新卡片事实模型、ChartContext、真实 ingress/精确相位/行运窗口/行星 station、GeneratedChartArtifact、人物清除、语义缓存和 AI 证据链已编译；
- AstroCore 专项测试通过：月亮换座、天象精确相位、次限月亮窗口、行星转顺/转逆；
- 六盘 44 卡和 Today 已接入英中正式 Catalog，iPhone 12 mini 英中六盘 UI 测试通过；
- 现代行运六卡已通过 14 组固定 fixture、5 个真实星盘各 4 个日期和 4623 个系统探针：219 条 Registry requirements 中 216 条可达、3 条结构不可达，运行时 unknown 与 reachable missing 均为 0，Timeline 消费者正文请求为 0；172 条新增正文已进入英中私有源，西法 Catalog 显式使用英文回退，四语运行时 Catalog 均为 1529 条；
- Charts 选择行运盘的渲染循环已修复：卡片构建不再在 SwiftUI `body` 求值期间写回 `@Published transitContentPlan`；最新 Debug 签名构建已覆盖安装并启动到连接的 iPhone 12 mini（`HUAWEI PURA 70`），CoreDevice 确认 `com.xiaoguiwk.interstellar` 进程 PID 4197；
- Charts 轮盘上方只保留页面栏、盘型、Wheel/Aspects 与单一参数入口，人物/预设/时间/地点收进参数弹窗，展开参数不得把轮盘整体挤出初始视口；Ask 恢复简洁输入、键盘 Return 为“完成”并接通 History，两个专项 UI 测试通过；
- 阶段 7 已完成：Relay 已通过本机构建的 `linux/amd64` 镜像部署到 `https://aaadmin.xiaoguiwk.top`；公开 Cloudflare 健康检查、管理页、随机管理员登录/退出撤销均通过。旧 Web/API 容器保持停止且未删除；
- 阶段 6 已完成代码门禁：Relay 验证整盘报告 Schema、4–8 节、事实引用和语言；报告正文零存储、客户端本地持久化后 ACK 扣费、未 ACK 释放、强制重新生成、一次 JSON 修复、安装配额、App Attest 请求体断言、Provider/模型真实停用、bcrypt 管理员、可撤销安全会话和不记录正文的审计均已接通；
- 独立 `/xiaoguiwk` 管理页已内嵌在 Relay，自动初始化 DeepSeek `deepseek-v4-flash` 以及六盘中英文分盘提示词，支持 API Key、模型发现/停用、连接测试、提示词编辑/恢复和含错误数的用量查看；Go 测试、vet、Compose 校验和本地 HTTP 冒烟通过；
- 当前 report-only 生产发布目录为 `/opt/interstellar/releases/v6-relay-v6-20260809-report-only`，镜像为 `interstellar-relay:v6-20260809-report-only`；切换前数据库备份为 `/opt/interstellar/backups/relay-20260809-1243.db`；
- 生产默认 Provider 已修正为带有效密钥的 `DeepSeek`。真实 Relay → DeepSeek 请求和同键缓存命中均已通过；密钥未写入 Git、日志、命令输出或截图；
- 下一步为最终阶段：全量工程门禁、最新签名 Release 真机安装以及 iPhone 12 mini 逐屏验收。
