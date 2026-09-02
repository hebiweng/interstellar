---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '39e422dc-767f-4685-9ea1-287c3cf5f9d7'
  PropagateID: '39e422dc-767f-4685-9ea1-287c3cf5f9d7'
  ReservedCode1: 'b217d9fb-3094-4cd9-8874-74c655a9774c'
  ReservedCode2: 'b217d9fb-3094-4cd9-8874-74c655a9774c'
---

# Interstellar iOS 上架检查

> 更新时间：2026-08-22。本文件按执行依赖排序，只记录正式 App Store 上架门禁。产品功能待办见 `docs/ios-product-backlog.md`，当前构建与环境状态见 `docs/agent-handoff.md`。

执行原则：先完成所有会改变客户端二进制、Entitlements、隐私声明、购买行为或生产 Relay 的事项，再生成 Build 9。Build 9 Archive 生成后才执行 Privacy Report 和 TestFlight 验证；若这些验证要求修改二进制，则修复后必须提升为新的 Build，不得继续提交原包。

## 1. Build 9 前置门禁

以下事项可能改变发布二进制、购买测试条件或生产行为，必须先完成。

订阅权益权威链路为 Apple 签名交易/状态 → Relay → 客户端展示。用户是否打开 App 不能决定或延长订阅；客户端缓存只能改善展示，不能成为付费事实源。

### 1.1 订阅、内购与 Relay

首版不实现 App 内 Monthly → Annual 主动切换；该能力已转入产品 backlog，不阻塞 Build 9。Monthly 与 Annual 若提供相同 Pro 权益、仅计费周期不同，应位于同一订阅组的同一等级，由 Apple 作为 crossgrade 在续订日生效。

- [x] 核对 Monthly 与 Annual 位于同一订阅组、同一等级，产品 ID、周期、价格、地区、展示名称、本地化、Review Screenshot、Review Notes 和可售状态均完整且符合首版方案；2026-08-22 已在 App Store Connect 人工核对。
- [x] 确认 App Store Connect 的 Billing Grace Period 保持关闭。首版订阅扣款失败后按原交易 `expiresDate` 立即降为 Free；宽限期及其 Sandbox/生产端到端验证转入后续版本；2026-08-22 已人工确认不启用。
- [x] 核对 `credits_10`、`credits_20` 的价格、地区、元数据、购买恢复边界和服务端幂等性；2026-08-22 已在 App Store Connect 人工核对商品配置，代码和 Relay 边界仍由后续测试门禁覆盖。
- [x] App Store Connect 的 Production 与 Sandbox Server URL 均已配置为 `https://aaadmin.xiaoguiwk.top/v1/store/notifications`。当前新界面不再显示版本选择；2026-08-22 通过 App Store Server API 实际发送并接收 V2 `TEST` 验证配置。
- [x] Relay 能接受并审计 V2 `TEST` 等不带 `signedTransactionInfo` 的有效 Apple 通知；无效 JWS 仍 fail closed。相关单元测试、Relay 全量测试和生产伪造 JWS 探针已通过，代码随 `interstellar-relay:v6-20260822-app-store-sync` 部署。
- [x] 发送 Sandbox Test Notification 并调用 Get Test Notification Status；2026-08-22 Apple 返回 `SUCCESS`，生产 Relay 审计表记录 `TEST / Sandbox`，数据库 integrity 为 `ok`，容器 healthy、RestartCount=0。
- [x] Relay 保存订阅的 Apple transaction/original transaction 标识，并实现独立于 App 启动的服务端补偿同步：每 6 小时调用 `Get All Subscription Statuses`，并用 `Get Notification History` 恢复漏收事件。2026-08-22 生产部署后已通过 Sandbox API 同步 2 条订阅并写入 history checkpoint；Production API 在首个正式版本发布前返回 Apple 401，首发后必须重新验证 Production。
- [x] 构建并部署账户生命周期新版 Relay：`linux/amd64` 镜像 `interstellar-relay:v6-20260822-account-lifecycle-e6fc5c3` 已于 2026-08-22 部署。切换前使用 SQLite backup API 备份权威数据库，备份与切换后 integrity 均为 `ok`，核心财务记录数一致；账户 lifecycle 字段、Apple 身份和 Credit 防重复表均已落库，容器 healthy、RestartCount=0，公开健康/隐私/条款探针通过。Build 9 真机删除/恢复验收归入第 3 节。
- [x] Build 13 账户恢复 Relay `interstellar-relay:v6-20260823-build13-account-recovery` 已于 2026-08-23 部署：停用祖先 ID 仅能由原已验证 installation 沿 successor 链恢复到该安装当前绑定的 active 账户，跨 installation 恢复仍拒绝；多代删除重试返回最新 successor。部署前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build13-account-recovery-20260823T062630Z.db`，切换前后 integrity 均为 `ok`、核心账户/交易表计数一致，容器 healthy、RestartCount=0。
- [x] Build 13 账户同步 Relay 热修复 `interstellar-relay:v6-20260823-build13-account-sync-hotfix` 已于 2026-08-23 部署：同步解析 inactive ancestor 后，Apple 身份绑定和账户重新读取统一使用权威 active successor，避免服务器后台已识别新 ID 但客户端因 409 保留旧 Keychain ID。新增精确回归测试且 Relay 全量测试、`go vet` 通过；部署前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build13-account-sync-hotfix-20260823T064556Z.db`，SHA-256 为 `131ae8dbd6af3f419fcfc098752ff7619dbdb4044b8a4df8fc07d2218c251964`；切换前后 integrity 均为 `ok`、核心账户/交易表计数一致，容器 healthy、RestartCount=0。现有 iOS Build 13 无需重建。
- [x] Build 14 Credits 终态对账 Relay `interstellar-relay:v6-20260823-build14-storekit-terminal-reconciliation` 已于 2026-08-23 部署：Apple 签名的消耗品按真实 token 归属结算，缺失 token 只对当前已验证 installation 入账，旧/其他账户交易不会误发给当前账户；永久拒绝返回客户端可 finish 的终态，暂时失败保持重试。新增审计表只保存 JWS SHA-256 和终态元数据。部署前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build14-storekit-terminal-reconciliation-20260823T082439Z.db`，SHA-256 为 `fc2529302b34974c1d1ad596f9e1f10e89196fa8bc2b25864b4a06eacdd8ef43`；切换前后 integrity 均为 `ok`，五项核心计数一致，容器 healthy、RestartCount=0，Edge/Caddy 未重建。
- [x] Build 17 报告语言与 12 盘提示词 Relay `interstellar-relay:v6-20260829-build17-reports-language` 已于 2026-08-29 部署：15 个盘型/周期提示词统一维护 canonical English，6 个新增盘面板已进入管理端；请求的八种 App 语言在生成时附加为输出约束，未知语言回退英语。部署前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build17-reports-language-20260828T162206Z.db`，SHA-256 为 `359a6ddd2970e3745c07fd3e0ee165a824955b1f8613e3ed9982039f653a7490`；备份及切换后 integrity 均为 `ok`，容器 healthy、RestartCount=0，Edge/Caddy 未重建。Build 17 已在 iPhone 12 mini 通过 production App Attest 实际生成并 ACK 一份英语三级推运报告，重启后本地复用通过。
- [x] You / Bonds 生产 Relay `interstellar-relay:v6-20260829-build18-bonds-prompts` 已于 2026-08-29 部署：16 种关系盘均有独立 canonical English scope，生成请求严格校验对应 `reportPromptKey`；管理端提示词页可按 You / Bonds / period、技术族、精确 scope 和搜索筛选。生产库核对为 31 个 canonical English 模板、其中 relationship 16 个；切换前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build18-bonds-prompts-20260829T143300Z.db`，SHA-256 为 `a3d3e8edd968ed1f2ffbc96b510cf7d4f29faf838b36fae209f9c44aa4f5db2b`，备份与切换后 integrity 均为 `ok`，容器 healthy、RestartCount=0，Edge/Caddy 未重建。`Stelyra 1.0.1 (1)` 已在 iPhone 12 mini 覆盖安装，production account sync 和 Composite 无解读卡真机验收均通过，未生成新 AI 报告或消费 Credits。
- [x] Themes 生产 Relay `interstellar-relay:v6-20260830-build21-themes-focus` 已于 2026-08-30 部署：8 个 Theme 各有独立 canonical English 提示词并严格匹配 scope，多个盘在 iOS 本地计算后合并 facts，只进行一次模型调用；生成上限为 16,000 tokens、首次超时 90 秒，客户端原子保存并 ACK 后一次消费 2 Credits。8/8 生产提示词均明确把 `params.focus` 作为首要分析重点；旧默认提示词只按精确内容迁移，不覆盖管理员编辑。切换前 SQLite backup API 备份为 `/opt/interstellar/backups/relay-before-build21-themes-focus-20260830T141658Z.db`，SHA-256 为 `db29748ad5d09c26cc118be9a152f9bc2df3eb18c6f03a323a3724fe73abde52`；备份及切换后 integrity 均为 `ok`，容器 healthy、RestartCount=0，Edge/Caddy 未重建。iPhone 12 mini 真机生产 Themes 生成、2 Credits ACK、重启本地读取及 Charts 紧凑布局专项通过。
- [x] Charts / Today / Week / Ask 私有内容已拆为独立运行时域，并以 10 个生成文件、area/locale/schema 校验和缺失内容显式失败为门禁；旧混合 PrivateContent / PrivateCorpus 生成缓存不再进入工程。固定 UI 已注册 `pt-BR`，但 ZIP 中大部分葡语值仍是英文骨架，正式把葡语列为完整本地化前必须完成翻译包、术语、帮助文档和四个私有内容域的人工审核。

### 1.2 隐私、安全与生产开关

- [x] 补齐并静态验证 `PrivacyInfo.xcprivacy`：已申报 UserDefaults Required Reason 及当前收集数据类型，项目资源引用、warnings-as-errors 测试编译和静态门禁通过；最终 Archive 的实际清单与 Xcode Privacy Report 仍按第 2 节核验。
- [x] 完成四语 Privacy Policy、首次 AI 联网授权弹窗和 Settings AI 披露：明确 ChatGPT 只辅助优化用户主动请求的报告，星盘计算与 App 内固定内容不由 ChatGPT 生成；仅转发名字/昵称、适用时的关系类型和计算结果，不转发 Profile 出生日期、出生时间、出生地点或明文地点参数；建议担心姓名泄露时使用昵称；设备保存并确认交付后 Relay 删除报告且不再保存。2026-08-22 本地化校验、iOS 出站最小化测试、Relay 防御性过滤测试和法律页面测试通过。生产 Provider 配置由账户所有者在 Relay 管理端完成，不作为代码任务。
- [x] 生产 ChatGPT Provider 已在 Relay 管理端完成配置；2026-08-22 由账户所有者确认。
- [x] 删除旧 Settings Reset、`ACCOUNT_RESET_TESTING` 及旧生产 reset 路由/开关。新的用户主动“删除账户与数据”采用不同合同：真实清除数据、停用旧 ID、自动创建新 ID，并保留最小财务历史；其门禁见 1.1，不能复用旧 Reset 语义。
- [x] 确认生产 App Attest 禁止开发绕过，正式 Bundle、Team/App ID 和最低版本一致。生产 Relay 为 `RELAY_ALLOW_DEV_BYPASS=0`、`RELAY_APP_ATTEST_ALLOW_DEVELOPMENT=0`、production、`KCC8FFFAA5.com.xiaoguiwk.interstellar`、`1+`；Release 配置使用 production entitlement。
- [x] 首版不上线推送通知，已移除未使用的 `aps-environment` entitlement；最终签名 Archive 的实际 Entitlements 仍按第 2 节核验。
- [x] 核查 Photos private access。客户端仅通过头像 `PhotosPicker` 读取用户主动选择的图片，未调用全图库 API，也未声明全图库权限。

### 1.3 App Store Connect 基础条件

- [x] Paid Applications Agreement、税务和银行信息已生效；2026-08-22 由账户所有者确认已完成。
- [x] App Availability 已按首发方案设置，并同步核对 Monthly、Annual、`credits_10`、`credits_20` 的销售地区；2026-08-22 由账户所有者确认已完成。
- [x] 订阅和消耗品已在 Sandbox/TestFlight 环境多次完成正常购买验证；2026-08-22 由账户所有者确认。

## 2. 生成并核验 Build 9

只有第 1 节所有适用的阻塞项完成后，才开始本节。

- [x] 统一版本源：`ios/project.yml` 与 `ios/Interstellar.xcodeproj/project.pbxproj` 均为 Marketing Version `1.0`、Build `9`；Archive 实际版本已核对为 `1.0 (9)`。
- [x] 最终功能源码固化于提交 `e6fc5c3`。复用开发阶段全量证据，并仅重跑最后隐私出站变化直接影响的 iOS/Relay 定向测试、本地化和 diff 门禁；未机械重跑未受影响的完整套件。
- [x] 已从干净提交生成 Build 9 Archive，包含 StoreKit `appAccountToken` 归属过滤、unfinished 队列修复、账户删除/重建/恢复和 Build 8 后的 UI/产品改动。Archive 路径：`/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-22/Interstellar 2026-08-22 17.16.xcarchive`。
- [x] 已核验 Archive 为 `1.0 (9)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement，并确认 `PrivacyInfo.xcprivacy` 实际进入 Archive；同一 Archive 的 App Store Connect 自动 Distribution 导出与上传校验成功。
- [x] 已用同一 Build 9 Archive 生成并检查 Xcode Privacy Report。报告汇总 7 类数据：Name、Precise Location、Other User Content、User ID、Device ID、Purchase History、Product Interaction，均为 App Functionality、Linked、Not Tracking；Archive 与源码中的 `PrivacyInfo.xcprivacy` SHA-256 一致，未发现需要修改 Build 9 的清单差异。PDF SHA-256 为 `b8e45adbe909b383fee32311c544482dbbf23b80694299f6379d79bdf3792b84`。
- [ ] 在 App Store Connect 按该 Privacy Report 核对并同步 App Privacy Answers；若填写核对暴露新的二进制或清单缺口，修复并提升新 Build。

Build 10 于 2026-08-22 以 TestFlight Internal Only 上传并完成内部测试，但因带 Internal 标记，不能用于外部测试或正式提交。Build 12 加入无感全球城市搜索与地图附近城市回退，最终候选 Archive 为 `/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 13.44.xcarchive`；实际 `1.0 (12)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest、无 Push Entitlement，隐私清单已进入 Archive 且与源码 SHA-256 一致。Archive 内包含 32,722,944 字节的全部城市/去重时区 SQLite，不包含约 48 MiB 的时区边界 ZIP。Build 12 尚未上传，必须选择 `App Store Connect` → `Upload` 并保持 Internal Only 关闭；`Release Testing` 生成 Ad Hoc Profile，不用于 TestFlight 公测或 App Store。

Build 13 修复删除账户后的停用祖先 ID 恢复、删除重试和已有订阅提示。候选 Archive 为 `/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 14.29.xcarchive`；实际 `1.0 (13)`、production App Attest、无 Push Entitlement，隐私清单与源码 SHA-256 一致，城市库大小及 SHA-256 与 Build 12 一致且未包含时区边界 ZIP。Relay 全量测试、iOS 71 项单元测试、AstroCore 26 项、ContentKit 6 项及适用静态门禁通过。Build 13 已上传并安装到 iPhone 17 Pro Max，账户恢复/删除及 10、20 Credits 购买已完成真机验证；随后在 iPhone 12 mini 暴露旧 `credits_10` unfinished 阻断，修复进入 Build 14。

Build 14 修复消耗型 Credits 的 unfinished 终态对账、删除账户前的“媒体与购买项目”验证，并在 Settings 的 About 下方、Show Welcome Guide Again 上方增加常驻 Terms of Use 与 Privacy Policy 入口。最终 Archive 为 `/Users/xiaoguiwk/Library/Developer/Xcode/Archives/2026-08-23/Interstellar 2026-08-23 16.46.xcarchive`；实际 `1.0 (14)`、production App Attest、无 Push Entitlement，隐私清单和城市库哈希与源码一致，时区边界文件未进入 App，arm64 UUID 为 `06766184-B17E-3EDC-BAEA-CAD849B84FC7`。Relay 全量测试和 `go vet`、iOS 77 项单元测试、法律入口 UI 红绿回归、AstroCore 26 项、ContentKit 6 项及全部适用静态门禁通过。Xcode 已对同一 Archive 返回 `Upload succeeded` 与 `EXPORT SUCCEEDED`；当前等待 App Store Connect 处理及 iPhone 12 mini 安装后清除旧 `credits_10` 阻断的真机证据。

`Stelyra 1.0.1 (2)` Themes 公测 Archive 已于 2026-08-30 生成并上传：`/private/tmp/Interstellar-1.0.1-2.xcarchive`，实际版本 `1.0.1 (2)`、Bundle `com.xiaoguiwk.interstellar`、Team `KCC8FFFAA5`、production App Attest，Privacy manifest SHA-256 为 `d4db607b85ebcfbdf526011f32aa5c5754422aab992624ae28b2f5974e488aa7`，arm64 UUID 为 `03F05895-F9E5-38C8-A146-2B436B7F4F5A`。Xcode 对同一 Archive 返回 `Upload succeeded` 且 ContentDelivery 为 `UPLOAD SUCCEEDED with no errors`；当前等待 App Store Connect 处理后加入 External Testing / Public Link。

## 3. TestFlight 验证

- [x] 已于 2026-08-22 上传第 2 节核验的同一 Build 9 Archive；Xcode 返回 `Upload succeeded` 与 `EXPORT SUCCEEDED`，当前等待 App Store Connect 处理，不得重新构建另一个同号二进制。
- [x] iPhone 17 Pro Max 的 TestFlight Build 9 已完成账户面向用户的关键路径：删除账户与数据后自动创建新的 Free User ID，旧个人数据清除；有有效订阅的 Apple 购买账户 Restore 后恢复 Pro，无购买记录的全新 Sandbox Apple Account Restore 后仍保持 Free。2026-08-22 由账户所有者确认全部通过。
- [x] Relay 管理端已核对旧 ID Inactive、lineage、财务历史保留、订阅归属新 ID 和周期 Credits 未重复；Build 9 卸载重装、App Attest、生产 Relay 连通性均通过。2026-08-22 由账户所有者确认。
- [ ] 在最终包验证外来或缺失 `appAccountToken` transaction 队列不会错误入账、finish 或阻塞当前账户交易；不重复整套 StoreKit/UI 回归。
- [x] 最终包关键路径 smoke 已完成：主要页面正常，报告生成、保存和 ACK 通过；2026-08-22 由账户所有者确认。
- [x] Build 10 Internal Only 内部测试已完成；2026-08-22 由账户所有者确认。该构建不作为外部公测或正式提交候选。
- [ ] 先同步 Build 13 的公开 iOS 源码与数据许可，再通过 `App Store Connect` → `Upload` 上传 Build 13，加入 External Testing 群组并提交 Beta App Review；审核通过后创建 Public Link。
- [ ] 复核 TestFlight 实测版本、提交候选 Archive UUID 和 App Store Connect 中的 Build 完全一致。

## 4. App Store 提交

- [x] 已从 Build 10 候选工作区按白名单导出独立、无历史的 iOS 公开仓库并发布到 `https://github.com/Stelyra-Astro/interstellar-ios`，首个提交 `c7f5ebe2f55fa23adea38e3cc998e59262c26964`。仓库不含 Web/Relay、私有语料与规则、运行时私有 Catalog、凭据、构建/过程/临时文件和无关资产，保留公开源码、构建脚本、AGPL 与 Swiss Ephemeris 许可；敏感信息、私有边界、生成工程引用和暂存清单审计通过，iPhoneOS 无签名构建及 AstroCore 26/26、ContentKit 6/6 通过。若后续 TestFlight 修复改变二进制，必须以新 Build 同步更新该仓库。
- [ ] 补齐版本元数据、关键词、截图、年龄分级、内容权利、Support URL、Privacy Policy URL 和审核说明。
- [ ] 首版提交时把对应订阅与内购一并送审，并在审核说明中写明登录、AI 报告、购买和恢复路径。
- [ ] 最终核对生产 Relay 健康、Provider、App Attest、Server Notifications V2 和隐私页面，不在提交后临时切换未经验证的配置。

## 5. 上架完成定义

只有在以上适用项有可复核证据、最终 Archive 与已测 TestFlight Build 完全一致、生产 Relay 配置已核对，并完成 App Store Connect 提交资料后，才能标记“可上架”。完成项应保留简短证据；历史过程由 Git 和发布记录承载，不在本文件累积日志。
