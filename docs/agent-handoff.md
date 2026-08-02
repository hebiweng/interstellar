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

## 0. iOS v6 当前权威状态（2026-08-01）

本节覆盖本文档后续所有与旧 iOS V1、四盘、旧 Today、固定 corpus 详情或 Obsidian 默认流程冲突的历史记录。

- 当前开发分支：`codex/ios-v6-rebuild`；DeepSeek 原始未提交工作已完整保存在 `codex/deepseek-v6-snapshot`（提交 `a42f1d6`），重构基线提交为 `7d5b115`；
- 当前产品合同：`docs/ios-v6-rebuild-plan.md`；卡片合同：`docs/ios-card-implementation-matrix.md`；
- 现阶段不默认读取 Obsidian。项目内 v6 文档、Schema、代码、测试和私有内容系统是权威；原型只参考层级、密度和视觉，不强制照搬字段；
- 本轮六盘为本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8；Composite 延期；
- Today 改为 v6 的 `Current Chapter / Active Today / Coming Next / Moon Today / Timeline / Upcoming Sky / Retrogrades / Current Sky`；
- 卡片首屏合同改为每个事实“计算结果 + 私有一句自然解读”。约 100 字卡片详情和整盘专业报告改为整盘 AI 首次生成、本机长期保存；旧固定 `summary + detail + note` 合同失效；
- 已完成共享基础：`ChartContext`、真实日期/地点参数、稳定事实模型、真实换座/精确相位/行运窗口/行星转向、`GeneratedChartArtifact`、语义缓存、人物删除联动、按人物/盘型清除和 AI 证据 ID；
- Relay 代码升级已完成：24 小时 AES-GCM 加密缓存、Provider/模型真实停用、bcrypt、持久且可撤销的 HttpOnly/SameSite 会话、同源限制、无正文审计、六盘精确卡片合同、结构/语言/长度/证据校验、非法输出一次修复、App Attest 安装令牌与请求体断言、设备限流及每日配额均已接通；
- Ask 保留原有三流程与专业事实；DeepSeek 没有改写 Ask 主体，只增加历史清理接线。Profile 的人物、头像、地图、预设、主题、字体和本地数据设计继续保留，并已加入 AI 授权撤回与按范围清理；
- iOS 当前编译通过；AstroCore 的换座、精确相位、次限月亮窗口和 station 专项测试通过；
- 用户已重启生产服务器；旧 `interstellar-edge`、`interstellar-api`、`interstellar-web` 容器已停止但未删除，数据卷保留。Relay 使用本机或 CI 构建的 linux/amd64 镜像传输部署，服务器只加载镜像并切换 Compose，避免再次耗尽内存。权威域名为 `https://aaadmin.xiaoguiwk.top`。

### 2026-08-01 v6 内容系统与 Relay 配置进展

- 英文与简体中文附件已由 `scripts/build-ios-copy-catalog.mjs` 转换为被 Git 忽略的运行时包；每包包含 51 个六盘/Today 合同、905 条稳定 copy、29 条主题规则，不把源附件直接打包；
- 正式 `copy-catalog.schema.json` 与校验器已覆盖精确合同集合、稳定 selector、factRefs/evidence、重复 ID/路径、引用完整性、占位符声明、强类型和变量上限；`approved` 不能绕过结构校验；
- Xcode 构建前和 GitHub CI 都已加入强制校验。CI 通过受保护的 `INTERSTELLAR_COPY_CATALOG_EN_B64` 与 `INTERSTELLAR_COPY_CATALOG_ZH_HANS_B64` secrets 注入私有包；缺少私有包即失败；
- App 已加入英语、简体中文、西班牙语、法语四种语言。英中读取各自审核包；西/法在正式翻译包交付前只让固定语料回退英文；
- Relay 默认初始化 DeepSeek Provider，Base URL `https://api.deepseek.com`、模型 `deepseek-v4-flash`。六盘中英文系统提示词由 Relay 自动初始化，各盘采用独立的消费者口吻与内容范围，可在 `/xiaoguiwk` 查看、编辑和恢复默认；旧自动通用口吻只在内容与旧默认完全一致时迁移，管理员改写不会被覆盖。部署后用户只需填写 API Key。
- Relay 内嵌独立管理页，`aaadmin.xiaoguiwk.top` 根路径和 `/xiaoguiwk` 均可访问；它不依赖暂停维护的 Next.js Web。管理页支持 DeepSeek 密钥、Provider/默认模型、模型列表与启停、连接测试、六盘中英文提示词、恢复默认和请求/成功/错误/Token 用量。
- `POST /v1/generate` 现在只接受本命 10、天象 7、行运 6、次限 6、日返 7、合盘 8 的精确卡片集合，拒绝缺卡、额外卡、重复卡、越权/重复证据、语言混杂和不合格长度；Composite 不在合同内。
- Relay 的 Go 测试、vet、Relay-only Compose 配置和本地 HTTP 冒烟均通过。Dockerfile 使用构建平台原生编译器交叉编译目标架构，并为 distroless nonroot 用户预置 `/data` 所有权；全新命名卷的 SQLite 创建与健康检查已验证。
- Relay 已以 `interstellar-relay:v6-20260801-2119`（`linux/amd64`）部署到 `/opt/interstellar/releases/v6-relay-20260801-2119/infra/deploy`；服务器只执行镜像加载与 Compose 切换。`aaadmin.xiaoguiwk.top` 经公开 Cloudflare DNS 的 `/v1/health` 正常，管理页返回 200，随机管理员登录、DeepSeek 默认配置、18 份双语提示词及退出后 401 均验证通过。
- 部署时服务器不存在旧 Relay 数据卷；旧 `.env` 已备份到 `/opt/interstellar/backups/env-before-relay-v6-20260801-2119`。旧 `interstellar-web` 与 `interstellar-api` 仍为 Exited 且未删除；Caddy 与 Relay healthy。管理员凭据仅在本机 Git 忽略、权限 600 的交付文件中，DeepSeek API Key 等待用户在后台填写。
- v6 内容运行链路已落地为 `StandardSignalBuilder → CardEvidencePlanner → ThemeMapper → CopyCatalogMatcher → CardTextModel`。六盘 44 卡和 Today 七个内容模块均读取同一审核 Catalog；Today 不再为章节卡拼接旧 `theme + area` 解释句；
- 动态 selector 对月交点等暂无消费者相位文案的事实采用“技术事实保留、文案层按强度选择首个有审核覆盖的主要星体相位”，不伪造或删除 Snapshot 事实；
- iPhone 12 mini 模拟器的英文六盘 UI 测试和简体中文六盘 UI 测试均通过；Today 英中截图确认正式 Catalog 生效；章节卡和 Active Today 卡的右侧空列布局已修正，空时间胶囊已移除；
- 快照缓存现保持旧内容立即可见、后台刷新，不再每次启动用全屏 `Calculating locally…` 覆盖已有页面；Charts 选中人物已贯穿计算、默认地点、AI 事实、语义指纹和本地 Artifact。
- Charts 轮盘上方已压缩为页面栏、盘型、Wheel/Aspects 和单一 Parameters 入口；人物、Modern/Classical、时间、地点和范围统一收进参数弹窗，不能再用展开参数把轮盘整体挤出首屏。全局纵向滚动条已隐藏；
- Ask 已按用户限定范围撤销 DeepSeek 新增的“逐要素分配生活领域”和输入锁定 Done/Edit 设计，保留原有三流程与专业计算；系统键盘 Return 使用 Done/完成并收起键盘，History 入口、空状态和本地持久记录均已接通；
- iPhone 12 mini 的 Ask History/键盘 Done 与 Charts 紧凑顶部/参数弹窗专项 UI 测试均通过；测试要求轮盘进入初始视口，而不是机械要求轮盘排在必要控制之前；Canvas 轮盘以正式无障碍标签 `Astrology wheel / 星盘轮盘` 验收；
- 多语言按三层推进：固定 UI 进入 `Localizable.xcstrings`，占星基础词进入四语 `AstroTerms`，消费者正文继续使用 Copy Catalog；日期、数量和动态句序使用 Locale-aware formatter。西/法正式语料交付前仅 Copy Catalog 正文回退英文，不能让整套 UI 回退英文。
- `scripts/build-ios-localization.mjs` 已把 564 个固定/语义 UI 键收进 String Catalog，英中完整、无歧义旧键；西/法当前各 79 个核心 UI 键。四语 AstroTerms 采用完全一致的类别与键集合，构建器会校验版本、locale、类别、键和非空值；
- `LocalizedFormatters` 已接管本地化日期/月年/时间、Ask 历史数量、未来日/月范围、小时、报告倒计时/阅读时长、领域数量、日/季度和逆行行星单复数。iPhone 12 mini 西语/法语核心 Tab、参数按钮和轮盘术语专项 UI 测试通过；
- Xcode 构建前与 GitHub CI 都执行 `ios:localization:validate`；App Store 元数据明确独立于运行时资源，本轮不混入 Copy Catalog。

---

## 1. 项目概况
## 0.1 2026-08-01 当前任务状态（最终交接）

本任务由用户授权：临时关闭 App Attest 以继续真机测试；部署新版 Relay；安装真机并继续剩余测试。用户已要求停止 DeepSeek 调试，先完成交接。

已完成：
1. 在 `infra/deploy/compose.production.yaml` 与 `infra/deploy/compose.relay-only.yaml` 中临时将 `RELAY_ALLOW_DEV_BYPASS` 设为 `"1"`，并添加临时注释。
2. 在 `ios/App/AIGeneration.swift` 中让 Debug 构建（`#if DEBUG || targetEnvironment(simulator)`）跳过 App Attest，发送 `X-App-Attest-Development-Bypass: 1`。
3. 在 `AGENTS.md` 增加 “App Attest 临时状态” 小节，告知后续 agent 必须重新启用。
4. 构建并部署新版 Relay 镜像 `interstellar-relay:v6-20260801-2219` 到 `aaadmin.xiaoguiwk.top`；服务器 `/v1/health` 返回 HTTP 200（部署由前序 agent 完成，当前环境受网络沙盒限制无法直接复测）。
5. 管理后台登录正常；DeepSeek provider `api_key_set=true`，连接测试成功（`POST /admin/providers/deepseek/test` 返回 `{"ok": true}`）。
6. 已将项目 `DEVELOPMENT_TEAM` 从 `YD3FY9ZB52` 切换为免费个人账号 `M2A7RHP7MT`（`ios/project.yml` 与 `ios/Interstellar.xcodeproj/project.pbxproj`），并移除 `ios/App/Interstellar.entitlements` 中的 `com.apple.developer.devicecheck.appattest-environment` 以适配无付费证书环境。
7. 修复 Xcode 中 `Validate Content and Localization` Build Phase 在 GUI 构建时找不到 `node` 的问题：在 `ios/Interstellar.xcodeproj/project.pbxproj` 的脚本里增加 `export PATH="$HOME/.local/bin:$PATH"`，并同步到 `ios/project.yml` 的 `postBuildScripts` 中，确保后续 `xcodegen` 不丢失。

已验证：
- iPhone 12 mini 模拟器 Debug 构建成功（`BUILD SUCCEEDED`），使用本地签名（Sign to Run Locally）。
- 真机安装通过 Xcode GUI build/run 成功：用户确认已安装到手机 `HUAWEI PURA 70`（UDID `00008101-0001701A1180001E`）。注意命令行 `xcodebuild install` 与 `build` 在该 Xcode/设备组合下不能稳定安装；当前以 Xcode GUI 的 `Personal Team` + `build/run` 为准。

未完成/待排查：
- **DeepSeek 端到端报告生成失败**：App 中打开盘的 AI 详情/整盘报告后无法加载内容。可能原因包括：设备到 `aaadmin.xiaoguiwk.top` 的网络可达性、Relay 证书/HTTPS 握手、App 中生成请求 URL/认证头、DeepSeek API key 余额/网络、App 是否发送了 `X-App-Attest-Development-Bypass: 1` 等。需要后续 agent 在设备可用网络/调试环境下专项排查。

注意：
- 当前未购买 Apple Developer Program 并不影响真机测试本身，只影响 App Attest、自动签名持久化和发布上架。
- 上线前必须重新购买 Apple Developer Program，恢复 `DEVELOPMENT_TEAM = YD3FY9ZB52`，在 `ios/App/Interstellar.entitlements` 中恢复 `com.apple.developer.devicecheck.appattest-environment`，并将 `RELAY_ALLOW_DEV_BYPASS` 改回 `"0"`。
- 本次修改 `ios/project.yml` 的 `postBuildScripts` 与 `ios/Interstellar.xcodeproj/project.pbxproj` 的脚本以修复 Xcode GUI 中 `node` 路径问题；若切换构建环境（如 CI 中 node 路径不同），需要同步调整。

当前工作区改动文件（共 66 个，含前序未提交改动与本任务新增）：

```text
 M .github/workflows/quality.yml
 M .gitignore
 M AGENTS.md
 M app/xiaoguiwk/page.tsx
 M docs/agent-handoff.md
 M docs/ios-card-implementation-matrix.md
 M docs/ios-v1-development-plan.md
 M infra/deploy/Caddyfile.fate
 M infra/deploy/compose.production.yaml
 M infra/deploy/interstellar.env.example
 M ios/App/AIGeneration.swift
 M ios/App/AppModel.swift
 M ios/App/ChartEvents.swift
 M ios/App/ChartRenderer.swift
 M ios/App/ChartsView.swift
 M ios/App/InsightCards.swift
 M ios/App/InsightContent.swift
 M ios/App/InsightFactory.swift
 M ios/App/InterpretationContextFactory.swift
 M ios/App/LocationPicker.swift
 M ios/App/Models.swift
 M ios/App/ProfileView.swift
 M ios/App/Reports.swift
 M ios/App/ReportsView.swift
 M ios/App/SynastryView.swift
 M ios/App/TodayDashboard.swift
 M ios/App/TodayView.swift
 D ios/App/YearAnchorCopy.swift
 M ios/ContentSchema/card-contracts.json
 M ios/Interstellar.xcodeproj/project.pbxproj
 M ios/Packages/AstroCore/Sources/AstroCore/AstroCore.swift
 M ios/Packages/AstroCore/Sources/AstroCore/AstroEvents.swift
 M ios/Packages/AstroCore/Sources/AstroCore/SolarReturn.swift
 M ios/Packages/AstroCore/Tests/AstroCoreTests/AstroCoreTests.swift
 M ios/UITests/VisualRegressionTests.swift
 M ios/project.yml
 M package-lock.json
 M package.json
 M relay/Dockerfile
 M relay/README.md
 M relay/auth.go
 M relay/go.mod
 M relay/go.sum
 M relay/handlers.go
 M relay/llm.go
 M relay/main.go
 M relay/prompts.go
 M relay/store.go
 M relay/store_test.go
 M scripts/check-ios-card-contract.sh
?? docs/ios-v6-rebuild-plan.md
?? infra/deploy/compose.relay-only.yaml
?? ios/App/AstroTerms.swift
?? ios/App/Interstellar.entitlements
?? ios/App/Localizable.xcstrings
?? ios/App/LocalizedFormatters.swift
?? ios/App/Resources/
?? ios/ContentSchema/copy-catalog.schema.json
?? ios/Localization/
?? relay/admin.html
?? relay/admin_ui.go
?? relay/app_attest.go
?? relay/app_attest_test.go
?? scripts/build-ios-copy-catalog.mjs
?? scripts/build-ios-localization.mjs
?? scripts/validate-ios-copy-ci.mjs
```

注意：管理后台中存在一个多余的 provider `的`（无 key），是本次登录前已存在的噪声条目，未删除，不影响主链路。

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

### 2026-08-02 更新：Copy Catalog 迁移至 v2（四语 + Modern/Classical）

- 完成 `ios/App/Resources/CopyCatalog-{en,zh-Hans,es,fr}.json` 重新构建，schemaVersion 2，51 张卡片契约，1238 条文案，modern/classical 主题规则。
- 修复 `ios/App/Models.swift` 中重复的 `corpusLanguage`：es/fr 现在直接加载各自语料，不再回退到英文。
- 更新 `scripts/build-ios-copy-catalog.mjs` 为 v2 结构（shared/modern/classical、`evidenceByPreset`、`copySourceByPreset`）。
- 更新 `package.json` 与 `ios/project.yml` 的四语构建、验证与 inputFiles。
- 更新 `ios/ContentSchema/README.md` 与 `docs/agent-handoff.md` 描述 v2 工作流。
- 重写 `scripts/export-ios-translation-worklist.mjs` 从 v2 源文件导出中英翻译工作表（`ios/TranslationExports/ios-v2-translation-worklist.*`）。
- 删除旧 A 结构：所有 `ios/PrivateContent/**/Corpus-*.json`、`ios/PrivateContent/generate-zh-Hans-corpus.mjs`、空目录、旧 v1 翻译工作表与备份脚本。
- Week 与 Ask 保持旧 `PrivateContent/week` 和 `PrivateCorpus-*.json` 结构，按策略暂不迁移。
- 验证通过：`npm run ios:copy:validate`、`npm run architecture:check`、`npm run lint -- --quiet`。
- 注意：沙箱无法写入 `.git/index`，旧文件已从工作区删除，但未自动 staging。提交前需要手动运行 `git add -u` 或 `git rm --cached` 处理这些删除。

### 2026-08-02 更新：现代行运六卡 Copy 决策链路

- 现代行运已改为唯一链路：`TransitFactBundle → TransitContentPlanner → TransitContentPlan → UI / Copy / GeneratedChartArtifact`。六张卡 ID、顺序、UI 外壳和现有语料 JSON 未改；Classical 与其他盘型未迁移。
- `TransitFactBundle` 完整承接 scoped 交叉相位、相位窗口关联、重复精确触发、行星位置、十二宫聚合、7/30/90 天日历、换座/换宫/转逆/转顺事件、完整时间戳、时区和权威 `sourceFactIDs`。
- `TransitContentPlanner` 一次生成六个 `CardEvidencePlan`；每条 evidence 独立保存 `claimMode` 和 `role`。Current Story 支持主信号与辅助信号，并输出 `signalRole`、行运行星、生活领域、`integratedThemeID` 和统一来源；Timeline 只接收窗口并仅使用技术格式化内容；Planet Paths 保留完整位置列表；Life Areas 保留全部十二宫；Active Transits 同时接收相位、关联窗口与四类行星事件。
- UI、Copy 和 AI 证据文档均消费同一 scope 的计划；聚焦行运盘不再混入主计划的窗口或日历；缓存恢复、行运地点覆盖、聚焦计算和 AI 使用相同的行运时区与地点。旧的 `StandardCopySignals.primaryAspect` 和忽略 `cardID` 的伪 Evidence Planner 已删除。
- 行运窗口的 repeated pass 只在同一真实 orb 窗口内认领；`passIndex` 计入窗口内历史精确次数，`passCount` 计入历史、当前与后续精确次数，避免把下一轮普通周期误标为 returning。
- `ios/ContentSchema/modern-transit-copy-registry.json` 冻结 6 个 Copy 槽、4 个综合主题、5 个 Story 角色和 38 个有限主题 ID。`signalRole` 使用 `transitPlanet: body` 与 `lifeAreas: houseList` 两个强类型变量；`transit-timeline` 不占用 Copy 槽。
- `scripts/export-modern-transit-copy-keys.mjs` 穷举所有合法请求并与英文运行时 Catalog 对比。当前共 219 条结构需求，其中 216 条运行时可达、3 条因周期行星约束不可达；172 条原始缺失已全部补齐，最终 reachable missing 为 0。Timeline 无文案需求，Planet Paths 与 Life Areas 所需共享键继续使用现有共享语料。
- 导出文件位于被 Git 忽略的 `ios/TranslationExports/modern-transit-copy-requirements.json` 与 `ios/TranslationExports/modern-transit-missing-copy.json`。每项只含 key、cardID、copySlot、theme/integratedTheme/role、强类型变量、使用条件、`requiredBy` 和 Catalog 状态，不含消费者正文。
- 14 组固定 fixture 覆盖混合、纯支持、纯挑战、中性、全空、仅窗口、仅事件、重复触发、完整路径/十二宫和范围过滤。iPhone 12 mini 模拟器执行 14 项 Planner 门禁测试，0 失败；新增门禁确认 Current Story 的综合标题、正文、结论和角色短句均来自对应计划与 Copy key。
- 172 条现代行运新增正文已通过外部双语包进入 Git 忽略的英文与简中 v2 私有源；西语和法语按当前语言合同显式承载同一批英文回退。四个运行时 Catalog 均为 1529 条，并通过 `ios:copy:validate`、`ios:localization:validate`、卡片合同、私有内容边界、`architecture:check` 和 `lint -- --quiet`。
- 现代行运 Copy 可达性门禁现由 `TransitCopyRequest` 单一入口驱动。14 组固定 fixture、5 个真实计算星盘 × 4 个日期和 4623 个系统化 Planner 探针共观测 216 个合法请求身份；覆盖四种综合主题、五种信号角色、长/中/日常周期、十二宫换宫、换座、转逆/转顺、多次精确、无窗口、单一信号和同主题多信号。
- `npm run ios:transit-copy:export` 会先运行 Xcode 可达性测试，再导出 `observed-copy-keys.json`、`unreachable-copy-keys.json`、`unknown-copy-keys.json`、完整 requirements 和最终 missing。当前 unknown 为 0，Timeline 文案请求为 0；219 条 requirements 中 216 条可达、3 条 `currentCycle` 主题因周期行星约束不可达，最终 reachable missing 为 0。
- 修复 Charts 选择行运盘后卡死：`ChartsView.body` 调用 `insightCards(for:)` 时不再写回 `@Published transitContentPlan`，避免渲染期发布状态触发连续 SwiftUI 重绘；Planner 输出仍作为本次卡片构建的局部计划传给 UI 和 Copy，事实合同不变。
- 最新 Debug 签名构建已覆盖安装并启动到连接的 iPhone 12 mini（设备名 `HUAWEI PURA 70`）；产物内四语 Catalog 均为 1529 条，CoreDevice 确认 `com.xiaoguiwk.interstellar` 进程 PID 4197。现有真机 UI 测试已覆盖 `Charts → Transits → Transit timeline`，但本轮自动复跑被 UI Test Runner 的旧 provisioning profile 与当前开发证书不匹配阻断，未进入测试用例。
- 剩余性能风险：行星事件为保证换宫精度采用 6 小时采样；7 天后台刷新已正常运行，90 天范围尚未完成真机耗时基准，后续只能优化计算扫描，不能减少计划事实合同。


> AI生成
