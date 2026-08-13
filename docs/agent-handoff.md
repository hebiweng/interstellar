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

> 更新时间：2026-08-13。本文件只记录当前有效状态、验证证据、风险和下一步；历史过程查 Git，不在这里重复。

## 1. 接手快照

| 项目 | 当前值 |
|---|---|
| 分支 | `codex/ios-v6-rebuild` |
| 当前提交 | 本轮 Pro / Credits / Relay 管理提交，以 Git `HEAD` 为准 |
| 相对 `origin/dev` | 本轮提交前超前 18、落后 0 |
| 产品合同 | `docs/ios-v6-rebuild-plan.md` |
| 卡片合同 | `docs/ios-card-implementation-matrix.md` |
| iOS 测试设备 | 已连接的 iPhone 12 mini；后续不使用模拟器 |
| Relay 权威域名 | `https://aaadmin.xiaoguiwk.top` |
| 当前生产 Relay | 部署完成后以 `docker inspect interstellar-relay` 为准；上一版为 `interstellar-relay:v6-20260812-testability` |

工作区有大量未提交的 iOS、本地化、Relay 和文档改动，属于当前用户任务，不得重置或覆盖。另有与当前任务来源不明的 `vendor/timezone-boundary-builder/timezones-2026b.geojson.zip` 删除，尚未处理。

## 2. 当前产品与实现状态

### iOS 固定合同

- 六盘保持本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8；Composite 延期。
- Today 保持 8 模块；Ask 与 Profile 均为正式能力。
- Modern / Classical、en / zh-Hans / es / fr、System / Light / Dark 已接线。
- 默认语言为英文；默认字号为 Standard。用户已保存的字号选择优先，卡片与普通 UI 使用 Dynamic Type 字体。
- 后续 Xcode 构建和 UI 测试只使用已连接真机，不创建、启动或下载模拟器。

### 本地化与内容

- `ios/Localization/ui-translations.json` 是固定 UI 的四语唯一源，当前 930 条；Swift 只写 stable key。
- `scripts/build-ios-localization.mjs` 由上述 JSON 生成并校验 `Localizable.xcstrings`。
- 消费者正文仍来自私有 Copy Catalog；西法未审核正文按合同回退英文。
- 语料生成的标准输入是 `artifacts/<preset>-<chart>/` 下每套 10 个公开合同 JSON，不是 `PrivateContent` 或单一 worklist。
- 合盘事实级 v4 已完成导入：Modern 306 条、Classical 380 条，英中正文来自已审核交付；西法按当前合同使用英文回退。
- `scripts/import-synastry-fact-copy-v4.mjs` 会校验 Registry 精确键集、双语文件一致性、审核状态、占位符、重复与禁用确定性表述，再写入被 Git 忽略的私有 Catalog；公开目录只保留键、Schema 与不含正文的 validation。
- `artifacts/modern-synastry-fact-copy-v4/` 与 `artifacts/classical-synastry-fact-copy-v4/` 当前 validation 均为 passed，missing / extra 均为 0。
- v4 精确事实语料来自真实样本，但样本不等于所有可能组合。运行时先匹配 v4 精确键；合法但未观察过的组合明确映射到已审核的 shared planet-role / house-overlay 私有语料，所有基础选择器在四语 Catalog 中必须齐全，不能再以 `missingCopy` 清空整盘。

### 本轮 UI 与事实修复

- Today 头部已改为标题、完整日期、姓名与地点三层；长姓名和长地址不再与日期争抢同一行。
- Profile、其他人物与 Ask 的地点入口统一为 Apple Maps；不再展示或编辑经纬度，地点和时区不能手填，时区随地图结果自动更新并只读显示。
- Ask 三流程的 Life Areas 默认均为空，改为显式 Primary + Related 多选；未选 Primary 时不能计算，列表提供四语生活场景说明。
- A/B/C 只支持 2–3 个选项；可选择共同 Primary/Related，也可为不同类型选项分别选择 Primary，共同 Primary 下 Option Additional 永远只作为 Related。相同 Primary 的候选由 AstroCore 按日夜盘 triplicity rulers 分配独立主星，普通 UI 不显示专业术语。
- Ask Judgment 已从 Support 分数中拆出：AstroCore 使用有截止时刻的 Swiss Ephemeris 事件查询解析 direct perfection、换座、station/refranation、基础 prohibition、translation 与 collection；Support 仅保留 reception、行星状态、Moon 与 Related Areas。A/B/C 不再归一化为合计 100%，只有显式 Shared Primary 才启用三分主星，证据相同时返回无明确领先。
- Life Areas 的每个 Related 项下提供四语“设为 Primary”操作；A/B/C History 的重复 ×100 和排序后字母身份错位已修复。消费者结果文案只描述当前情况，不输出算法辩护或内部设计说明。Electional `Find the Best Time` 未改动。
- A/B/C 页面已加入问号入口，长帮助正文按 en / zh-Hans / es / fr 四个 Markdown 运行时资源独立维护。
- 报告页删除 `% read`、阅读分钟估算；标签保持单行。
- 合盘相位矩阵已增大并响应 Dynamic Type。
- 卡片、Charts、Today 和普通 UI 的固定点字号已迁为 semantic / scaled Dynamic Type；架构门禁阻止重新引入。
- Moon Today 与 Current Sky 共用真实 Sun–Moon 黄经差；亮暗均为月面，终止线和照明按真实月相绘制。
- Elements 为 Fire / Earth / Air / Water；另显示 Cardinal / Fixed / Mutable 三模式，权重来自真实点位占比。
- 合盘 Communication / Chemistry 无对应相位时使用真实 Mercury / Venus-Mars（Modern 可含 Pluto）落宫，不再产生空卡。
- Key Inter-Aspects 在候选足够时排除情绪、沟通、吸引、承诺已使用的事实。
- `relationship-overview` 卡片合同门禁已识别动态 `make(...)` 构造方式。
- Light / Dark 架构检查阻止普通 Swift UI 使用原始 RGB 或 `Color.black`。
- 西班牙语、法语核心导航测试使用稳定 accessibility identifier，不依赖可见译文定位。

### Reports、Profile 与 Relay

- 六盘生成报告时不再让用户选择人物或参数；确认弹窗按盘型仅展示当前适用信息，例如人物、时间、地点和 Modern / Classical，不适用的字段不显示。
- 已存在报告时弹窗明确提示将覆盖原报告；“编辑”会返回对应 Charts 盘型并打开参数页。合盘只确认双方人物，AI `params.relationship` 读取 Profile 已保存关系。
- 六盘 AI 仅在 Reports 明确点击后生成 4–8 节整盘报告；本机同语义 Artifact 命中禁止联网。
- Relay 六盘中英文分盘提示词已部署；管理端提示词页可按盘型和语言筛选。
- iOS 反馈发送到 `https://aaadmin.xiaoguiwk.top/v1/feedback`；Relay 管理端有平级“用户反馈”菜单。
- 反馈内容使用 AES-GCM 存储并具有限流、字段校验、状态筛选、处理与重新打开能力。

### Pro、Credits、iCloud 与 Relay 管理

- StoreKit 2 已接入 `premium_monthly`、`premium_annual`、`credits_10` 与 `credits_20`；消费者名称统一为 Pro。10 Credits 为 $1.99，20 Credits 为 $2.99；Annual 首购一次性发 20 个一年期 Credits，Monthly 不赠送，续订/恢复/重放不重复。
- Free 完整开放 Today、本命、天象、Ask、Wheel、Aspects、日期、地点和参数；Special 只兼容历史值，不可选。行运、合盘、日返、次限的第 2 张及后续 Interpretation Card 完全不渲染正文，使用 contextual Paywall；本人之外可免费保存 2 人。
- Relay 是 Premium/Credits 权威：Free 自然月 refill 到 2，Premium 按订阅月锚点 refill 到 10；Annual 首购一次性发 20 个一年期 Bonus；购买的 10 Credits 永不过期；消耗顺序 allowance → bonus/admin → purchased。
- 报告生成前只预留 Credit。Relay 完成 AI、Schema 与 evidence 校验后仅写 `awaiting_ack` 元数据，不保存正文；iOS 必须先原子保存六盘或周期报告，再 ACK。ACK 事务恰好消费一次；生成、校验、本地保存失败或未 ACK 超时均原路释放。iOS 会持久化并重试暂时失败的 ACK。
- Relay 已删除旧 `generation_cache` 表和所有读写方法，启动迁移会清空并删除任何旧 `payload_enc` 列；当前报告元数据表没有正文列或正文读取路径。App Store 客户端交易及 Server Notifications V2 均验证 ES256/x5c JWS，并处理续订、billing grace、到期、撤销、退款和交易重放。
- 管理端新增 Reports 与 Users：Reports 有 User/盘型/语言/状态/日期筛选、Tokens、耗时、错误、Credit 成本与状态；Users 有 Apple/Admin Premium、到期、分钱包余额、Grant 明细、报告数、跳转 Reports，以及带审计的 Grant/Revoke Premium 和 Grant Credits。
- Profile 的 Your Plan 卡片展示 Free/Pro、月度/限期赠送/永久购买额度、总余额、刷新/到期日期和最近增减流水；个人资料与编辑入口合并进顶部卡片。私人 iCloud container 备份本人/其他人物、语言、外观、字号、预设、六盘报告和周期报告；恢复时抑制中间自动覆盖。Relay 不参与 iCloud 报告存储。
- 设置中的 Required Notices 已提供 en / zh-Hans / es / fr Swiss Ephemeris / AGPL 说明和完整随包许可证；Paywall 有四语 Terms/Privacy 入口，Relay 提供四语公开页面。App Icon 已替换为用户提供的 1024×1024 Leo 图标，无 alpha、无预烘焙圆角。
- 测试可见性修复已完成代码实现：Profile 首屏展示 Relay 权威 Free/Premium、Credits、额度刷新日、Premium 到期和可复制 User ID；设置页不再单独使用本地 StoreKit 状态冒充权威 Plan，并提供账户刷新。
- Charts 顺序固定为本命、天象、行运、合盘、日返、次限；行运、次限、日返、合盘在 Free 下首屏显示 Pro 预览提示，第 1 张 Interpretation Card 可见，第 2 张起用玻璃锁定卡显示标题但不显示正文。报告生成中再次进入只显示等待状态，不能重复生成。
- 本机已有报告按盘型保留 View / Regenerate，即使当前参数产生了新语义指纹；重新生成仍使用当前参数并原子覆盖。Ask 首页只显示 History 入口和数量，详细条目只在 History 页面展示，并支持逐条确认删除。
- Relay Users 管理端支持按 User ID 查找、Free/Pro/Apple Auto 强制切换、Credits 赠送、扣减及恢复默认；恢复默认只清除未使用的后台赠送，不动月度额度、年度首购赠送和购买 Credits。Reports 的长 ID 分行换行，移除无增量详情按钮；管理端时间统一显示上海时间且不暴露 ISO `T/Z`。
- Pro 与 Buy Credits 使用底部抽屉；Terms / Privacy 正文随 App 本地打包，不向 Relay 请求。Today 已移除底部 Current Sky 跳转；Ask 显示每次 1 Credit 与限时免费状态。
- 首次启动新增四语两页向导，说明 Today/Charts/Ask/Profile 与 Free/Premium 差异；设置中可再次打开，不需要删除 App。

### 仓库结构与清理

- `AGENTS.md` 已加入权威目录地图和固定语料链路，明确 `artifacts/` 十文件合同包、私有源、运行时包和可删除缓存的边界。
- 已删除会误导当前实现的 iOS V1 计划、9 卡审计、旧跨盘 Agent handoff、Transit 阶段收口计划、旧 Web 阿里云部署说明和两个已完成的一次性迁移脚本；历史仍可从 Git 查询。
- 已删除约 231 MB 可再生成缓存与旧产物，包括 Swift Package `.build`、前端 dist/output、Playwright/Python/Ruff/Wrangler 缓存、旧 IPA、旧 TranslationExports 和 Xcode 用户状态；`node_modules` 因当前构建仍在使用而保留。
- 326 个私有 Obsidian Vault 文件已从 Git 索引移除但完整保留在本地；`.gitignore`、CI 和 `scripts/check-private-content.sh` 已阻止 Vault、私有 Catalog、TranslationExports 与私有规则重新进入公开 Git。
- 旧 Web/API/Worker、Obsidian 本地资料、vendor 锁定数据、本地数据库和凭据未作为垃圾删除。

## 3. 当前架构边界

```text
AstroCore Snapshot / Aspect / Event
→ StandardSignalBuilder
→ CardEvidencePlanner
→ ThemeMapper
→ CopyCatalogMatcher
→ CardTextModel
→ InsightCard / Today
```

- iOS 权威事实来自本地 AstroCore；展示层不补算或伪造。
- AI 只解释请求中的已计算事实，不新增事实、日期、相位或结局。
- 行运 Modern / Classical 已迁入独立 Planner/Factory/Copy/Validation。
- 合盘已有专属 FactBundle / Planner / Copy / Factory / Validator；`Legacy` 只是尚未更名的物理路径。
- 天象、本命、日返、次限已按模块归位，但仍通过 Legacy factory，后续迁移必须行为不变。
- 旧 Web/API/Worker 源码仍保留但消费者改造延期；未完成正式退役审计前不得删除。

## 4. 最新验证证据

- AstroCore 25 项测试通过，包含有界 Horary Judgment 事件证据、同领域 A/B/C 的 sect-aware triplicity 分配、独立模式重复宫位不误触发，以及原始 Option 身份稳定性。
- iPhoneOS arm64 Debug 无签名构建通过；四语帮助 Markdown 已进入 App Resources，固定 UI 930 条四语本地化生成与构建期校验通过。
- iPhoneOS arm64 Debug 真机构建通过，并已覆盖安装、启动到 iPhone 12 mini。
- iPhone 12 mini 上 Ask 端到端 UI 测试通过：输入问题、关闭键盘、选择 Primary / Related、将 Related 设为 Primary、提交并进入 Judgment 结果页。
- 真机月相数学与 14 对人物 × Modern/Classical 共 28 份合盘计划测试通过：8 卡顺序正确、空卡 0、卡内重复 0、事实引用与角色方向合法；所有实际选中事实在 en / zh-Hans / es / fr 均能命中非空解读。
- 已用真机当前保存人物复现并修复合盘 `missingCopy`：未观察过的 `modern / relationship-overview / Jupiter conjunction Jupiter` 现命中已审核基础选择器；修复后同一真机页面正常显示 Relationship Overview。永久单元测试覆盖该键以及四语全部 planet-role / 12 宫 house-overlay 基础选择器。
- 私有运行时 Catalog 构建与校验通过：en / zh-Hans 各 2506 条，es / fr 各 2399 条，51 份合同。
- 西班牙语 / 法语核心导航真机 UI 测试通过。
- `scripts/check-ios-card-contract.sh` 通过。
- `npm run ios:copy:validate` 通过。
- `npm run ios:localization:validate` 通过。
- `npm run architecture:check` 通过。
- `npm run lint -- --quiet` 通过。
- `scripts/check-private-content.sh` 通过。
- `git diff --check` 通过。
- Relay `go test ./...`、反馈接口校验和生产健康检查通过。
- 本轮 Relay `go test ./...` 通过，新增覆盖 ACK 恰好一次、未 ACK 释放、Relay 无缓存/无正文、Credit 原 Grant 恢复、购买交易重放、Annual welcome 幂等、撤销回收和 billing grace。
- 本轮 iPhoneOS arm64 无签名构建通过（Swift 6 + warnings-as-errors）；Scheme 已识别 `Interstellar.storekit`。首次签名真机构建确认免费 Personal Team 被 iCloud capability 阻断；按用户要求临时置空 entitlement 后，iPhone 12 mini 签名构建、覆盖安装和启动均成功。
- 本轮 AstroCore 25 项、ContentKit 6 项测试通过；Copy Catalog、四语固定 UI（930 条）、架构、lint、卡片合同、私有内容边界和 `git diff --check` 均通过。
- 测试可见性修复后，iPhoneOS arm64 无签名与 iPhone 12 mini 签名 Debug 构建均以 Swift 6 warnings-as-errors 通过；固定 UI 更新为 962 条四语字符串。新包已覆盖安装并成功启动到同一台 iPhone 12 mini，未删除 App 数据。
- Relay 变更专项测试通过，覆盖后台 Free/Premium/Auto 强制切换、对应 2/10 allowance 刷新、订阅宽限期与交易/报告/Credit 路径；`go vet ./...`、管理端 JavaScript 语法、全部项目门禁和 `git diff --check` 通过。
- 本轮 Relay `go test ./...` 与 `go vet ./...` 通过，新增覆盖月度 Pro 不赠送、Annual welcome 幂等、20 Credits 购买、后台扣减不足拒绝、恢复默认只清后台赠送及 Ledger/Audit；iPhoneOS arm64 Debug 无签名构建以 Swift 6 warnings-as-errors 通过，固定 UI 996 条四语字符串通过生成和校验。
- 已从提交 `0baacd2` 构建并于 2026-08-13 部署 `linux/amd64` 镜像 `interstellar-relay:v6-20260812-testability`。切换前停止 Relay 写入并备份生产数据库到 `/opt/interstellar/backups/relay-20260813-192548-pre-testability.db`，随后只重建 `interstellar-relay`；Caddy 保持运行，旧 Web/API 容器保持停止且未删除。
- 部署后 Relay 容器为 healthy，公开 `/v1/health`、`/privacy`、`/terms` 均返回 200；管理端已出现 Reports、Users 与 Credits 测试能力。管理员登录、Users/Reports/Provider 查询、注销及会话撤销均通过，生产现有 Provider 为 1，Users/Reports 暂为空；未携带安装身份的 `/v1/account/sync` 正确返回 401。
- 本轮没有使用模拟器；当前 DerivedData 保留，用于已连接真机的后续快速覆盖构建。

## 5. 当前未完成事项

### 最近完成

1. 生产 Relay 已切换到 `v6-20260812-testability`，数据库备份、容器健康、公网路由、法律页面、Users/Reports/Provider API、管理员登录与会话撤销均已验证；来源不明的 timezone vendor ZIP 删除未纳入本次部署。

### 发布前仍需完成

1. 在 iPhone 12 mini 上人工逐屏验收英中/西法、浅深色、标准/大字体、VoiceOver、长文本与空状态。
2. 人工走通 Reports：逐盘核对确认弹窗只显示适用字段，“编辑”准确返回对应参数页；并验证首次生成、离开后返回、同语义本地命中、重新生成覆盖、失败保留旧报告、Modern/Classical 隔离。
3. 决定 Transit Horizon 使用 90 天还是 calendar year，并统一合同和性能基准。
4. 完成 Classical trueNode policy 与 validator；不得在展示层猜测。
5. 迁移 Ask / Week 旧私有内容结构，以及天象、本命、日返、次限 Legacy factory。
6. 验证飞行模式、本地 Artifact 零网络、授权撤回后只读、人物删除清理和损坏文件恢复。

### App Attest 阻断

当前没有 Apple Developer Program，开发期保持：

- `RELAY_ALLOW_DEV_BYPASS="1"`；
- Debug 构建发送开发绕过头；
- 免费 Personal Team 为 `YD3FY9ZB52`，正式 App Attest entitlement 未启用。

发布前必须恢复 Apple Developer Program，重新确认届时正式 Team ID，恢复 App Attest entitlement，将 `RELAY_ALLOW_DEV_BYPASS` 改为 `"0"`，再做生产端到端验证。

### iCloud / App Store 外部配置阻断

- 当前免费 Personal Team 无法创建包含 iCloud container 的 provisioning profile；已确认报错来自 iCloud capability，不是 Swift 编译。为先测试其他功能，`Interstellar.entitlements` 已按用户要求临时置空，iCloud 代码仍完整保留并会显示 unavailable。购买/恢复 Apple Developer Program 后，需恢复 iCloud Documents、`iCloud.com.xiaoguiwk.interstellar` 和 ubiquity kv-store entitlements，在 Developer Portal 启用相同能力并重新生成 profile，再做真机备份/恢复验收。
- App Store Connect 仍需按同一 Product ID 创建 Monthly、Annual、10 Credits 和 20 Credits 商品，配置价格/四语元数据、订阅组、退款/宽限期策略，并把 Server Notifications V2 URL 指向 `https://aaadmin.xiaoguiwk.top/v1/store/notifications`。
- Relay 数据库迁移与新管理端已部署；后续 StoreKit 真机测试产生用户同步或报告流水后，再从 Users/Reports 核对权威余额、Plan 覆盖、Grant 和 ACK 消费记录。

## 6. 推荐下一步

```text
提交当前工作区改动
→ 真机 StoreKit、Paywall、Credits 与 Reports ACK 全链路验收，并在 Relay Users/Reports 核对流水
→ 恢复 Apple Developer Program 并配置 iCloud / App Store Connect 与 Notifications V2
→ 真机逐屏与 Reports 确认弹窗闭环验收
→ Node policy / Horizon / Classical validator
→ 其余盘型 Legacy 迁移
→ 恢复生产 App Attest
→ 发布准备
```

适用门禁见 `AGENTS.md`。私有 Catalog 缺失导致 Copy validate 失败时应恢复私有源，不能用公开临时文案绕过。

> AI生成
