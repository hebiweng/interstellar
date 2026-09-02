---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '3f30005d-ea0b-44b1-b6fc-620608ab752f'
  PropagateID: '3f30005d-ea0b-44b1-b6fc-620608ab752f'
  ReservedCode1: '68f2023f-dbb5-4c40-9498-0c86db1ff26e'
  ReservedCode2: '68f2023f-dbb5-4c40-9498-0c86db1ff26e'
---

# Interstellar iOS 产品待办

> 更新时间：2026-08-30。本文件只记录尚未实施的产品需求和优先级。已生效的产品规则以 `docs/ios-v6-rebuild-plan.md` 和 `docs/ios-card-implementation-matrix.md` 为准。

## P1 — 账户与 Apple 身份权威归属

- [ ] 在 Relay 实现权威账户合并/解绑与 Apple identity 重新归属流程，彻底消除“当前 installation/userID 可同步，但 signed App Transaction 已绑定另一 active account”造成的首次 `409 account_sync_failed`。统一 account sync、订阅 Restore、账户删除 successor、购买归属和客户端 Keychain 更新的最终权威 userID；完成后移除客户端对该精确冲突的无 Apple identity 重试兼容。
- [ ] 该流程必须 fail closed：只接受 production App Attest 验证的 installation、Apple 签名交易/状态和可证明的账户 lineage；不得允许任意 userID 合并、跨 installation 接管或静默覆盖无关 active account。解绑、合并和重新绑定必须幂等并保留审计，日志/数据库不得保存 JWS 正文。
- [ ] 合并时保留订阅、购买交易、Credit grant/ledger、报告 reservation/ACK 和账户删除最小财务历史；不得重复发 Monthly Bonus、Pro allowance、welcome Credits 或消耗品 Credits。迁移前必须备份数据库并验证 integrity，失败可回滚。
- [ ] 覆盖测试至少包含：TestFlight 与 Xcode Debug 覆盖、卸载重装、Keychain identity 保留/重建、多代账户删除 successor、Apple identity 已绑定另一 active account、无关 installation 拒绝、订阅 Restore、退款/撤销、unfinished 消耗品，以及合并前后 Credits/ledger 守恒。生产验收要求首次带 signed App Transaction 的 `/v1/account/sync` 直接返回 200，不再依赖客户端 409 fallback。
- [ ] 订阅购买前或购买结果返回外来 `appAccountToken` 时，不再显示“Apple 已确认、等待同步”；改为明确的恢复购买提示。只有用户主动点击恢复时才调用 `AppStore.sync()`，并说明 StoreKit 使用系统当前“媒体与购买项目”账号，App 无法读取、显示、预填或选择 Apple ID；Sandbox 验收需覆盖系统 Sandbox Apple Account 切换后重试。
- [ ] 强制订阅身份一对一：一个 active Stelyra 账户最多绑定一个 Apple 购买身份，一个 Apple 购买身份的订阅权益同时只能归属一个 active Stelyra 账户。不同 Apple ID 的订阅不得叠加到同一账户；冲突时 fail closed，并提示切换到与当前 Stelyra 账户绑定的 Apple ID 后恢复，不得静默迁移另一 active account 的订阅、Credits 或报告。
- [ ] 恢复购买交互允许展示脱敏的 Stelyra 账户标识以辅助排查，但不得声称它是 Apple ID，也不得保存或推断 Apple ID 邮箱。覆盖测试包含：当前 Apple ID 无订阅、正确 Apple ID 恢复成功、错误 Apple ID 已订阅但绑定另一 Stelyra 账户、同一 Stelyra 账户尝试绑定第二个 Apple 购买身份，以及用户取消系统认证。

## P1 — AI 报告请求语言

- [x] Build 17 已完成：客户端每次实际请求生成整盘报告时显式传递当时的 App 语言；Relay 保留请求语言并将它作为统一英语提示词的输出约束，不再按语言维护提示词。切换 App 语言不翻译、不失效或重新生成本机已有报告，只有之后的新请求使用切换后的语言。首次安装会匹配系统首选语言，无法匹配八种支持语言时回退英语；2026-08-29 已通过客户端/Relay 自动化测试及真机英语三级推运报告生成、ACK、本地重启复用验收。

## P1 — Today Timeline 精简与布局

- [ ] Today Timeline 的事件行只保留本地时间和真实计算事件标题；删除 `This theme is strongest now.` 等 `signal.subtitle` 消费者解读，并且不再为 Timeline 事件行准备或展示任何同类语料。Timeline 的“无精确事件”和“正在更新”状态文案不属于事件解读，继续保留。
- [ ] Timeline 左侧时间必须完整显示并强制单行，不截断、不换行；为时间列保留足够宽度。右侧真实事件标题允许自然换行，在 iPhone 12 mini、四语和 Dynamic Type 下验收。

## P1 — 公开法律与支持页面

- [ ] 下一阶段建立独立公开 GitHub Pages 站点并绑定长期稳定的自定义域名（建议 `legal.xiaoguiwk.top`），承载四语 Privacy Policy、Terms of Use、Support、Privacy Choices / Account Deletion；页面不得包含私有语料、提示词、密钥或 Relay 配置。
- [ ] 将 iOS 的 Privacy / Terms WebView 地址切换到 Pages，自带四语离线正文继续作为加载失败降级；Relay 原 `/privacy`、`/terms` 保留永久重定向，兼容 Build 8 等旧版本。
- [ ] 在 App Store Connect 更新 Privacy Policy URL、Support URL 和可选的 User Privacy Choices URL，并验证匿名访问、HTTPS、移动端布局、四语内容及支持联系方式。

## P1 — 上线后一个月内的订阅验证

- [ ] 在 Billing Grace Period 保持关闭的 Sandbox 场景验证 `DID_FAIL_TO_RENEW` 后按原交易 `expiresDate` 降为 Free，`DID_RENEW/BILLING_RECOVERY` 后恢复 Pro；同时验证通知延迟或丢失时由服务端补偿同步纠正状态。
- [ ] 验证客户端在订阅到期、离线重开和回到前台时不会因缓存继续解锁 Pro，并审计真实续订、到期、退款、撤销及计费重试通知的幂等记录。该项在首发上线后一个月内完成，不阻塞首发 Build 9。

## P2 — 订阅管理

- [ ] 后续版本实现 App 内 Monthly → Annual 主动切换或清晰的系统订阅管理入口。首版允许 Monthly 与 Annual 作为同组、同等级、不同周期的方案分别购买，不以此项阻塞 Build 9。
- [ ] 后续版本评估并实现 Billing Grace Period：先修复和验证 App Store Server Notifications V2，完成 Sandbox 中进入宽限期、恢复扣款、宽限期结束和客户端离线/回前台权益同步，再决定时长、适用续期类型并开启生产环境。

## P2 — 发布维护

- [ ] 后续版本在 `Info.plist` 添加 `ITSAppUsesNonExemptEncryption = false`，声明 App 仅使用 Apple 操作系统提供的豁免加密，避免每次上传重复回答出口合规问卷。Build 11 继续在 App Store Connect 手工回答“不使用非豁免加密”，本项不阻塞首发。

## 已完成，不再列为待办

- [x] Today Current Chapter 上方多余空白已移除。
- [x] Current Chapter 和相关长标题已支持自然换行。
- [x] Today 说明文字字号已与其他页面对应层级统一。
- [x] Today、Profile 和合盘中的适用长文本已取消不必要的单行截断。

完成项目后从待办区移除，并在 Git 历史和 `docs/agent-handoff.md` 的当轮验证中保留证据；不要长期累积完成流水。

> AI生成
