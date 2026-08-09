# Interstellar iOS v6 重构执行合同

| 字段 | 值 |
|---|---|
| 生效日期 | 2026-08-01 |
| 当前分支 | `codex/ios-v6-rebuild` |
| 快照分支 | `codex/deepseek-v6-snapshot` |
| 范围 | iOS 六盘、v6 Today、AI Artifact、Go Relay、`/xiaoguiwk` |
| 延期 | Composite、跨设备报告同步、Web 消费端、旧 `/admin` 迁移 |

本文件取代 `docs/ios-v1-development-plan.md` 中与 Today、卡片详情、盘型数量和 AI 缓存冲突的旧规则。旧文件只保留历史背景。

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
- Relay 只保留 24 小时加密幂等缓存；AI 只能解释并引用请求事实；
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

## 5. Relay 与后台

- Relay 与独立后台的正式权威域名为 `https://aaadmin.xiaoguiwk.top`；站点根路径与 `/xiaoguiwk` 均打开嵌入式管理端，不依赖旧 Web；
- 请求包含稳定事实、`semanticFingerprint / factsHash / generationSchemaVersion`、语言和预设；不再包含卡片 ID、每卡允许证据或 `TransitContentPlan`；
- 响应只包含 4–8 节整盘报告；每节携带 `evidenceFactIDs`，Relay 验证其来自本次请求事实，并验证 Schema 与语言；
- `forceRegenerate` 只绕过同键缓存读取，成功结果仍覆盖同一缓存身份；失败不得写入残缺结果；
- 上游非法 JSON 最多修复重试一次；失败不缓存残缺产物；
- Provider/模型停用必须阻止生成；默认 Provider 由设置决定，不硬编码 `default`；
- 管理密码使用 bcrypt，管理会话持久、可撤销、HttpOnly/SameSite；同源访问，不允许 `*` CORS；
- 密钥和缓存加密；审计只记动作与范围，不记出生资料、事实正文、提示词正文或 AI 正文；
- 生产生成链路需要 App Attest 安装级短期令牌、请求体断言、设备级限流和每日配额；模拟器绕过只允许开发环境。

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
- 阶段 6 已完成代码门禁：Relay 验证整盘报告 Schema、4–8 节、事实引用和语言；24 小时加密缓存、强制重新生成、一次 JSON 修复、安装配额、App Attest 请求体断言、Provider/模型真实停用、bcrypt 管理员、可撤销安全会话和不记录正文的审计均已接通；
- 独立 `/xiaoguiwk` 管理页已内嵌在 Relay，自动初始化 DeepSeek `deepseek-v4-flash` 以及六盘中英文分盘提示词，支持 API Key、模型发现/停用、连接测试、提示词编辑/恢复和含错误数的用量查看；Go 测试、vet、Compose 校验和本地 HTTP 冒烟通过；
- 当前 report-only 生产发布目录为 `/opt/interstellar/releases/v6-relay-v6-20260809-report-only`，镜像为 `interstellar-relay:v6-20260809-report-only`；切换前数据库备份为 `/opt/interstellar/backups/relay-20260809-1243.db`；
- 生产默认 Provider 已修正为带有效密钥的 `DeepSeek`。真实 Relay → DeepSeek 请求和同键缓存命中均已通过；密钥未写入 Git、日志、命令输出或截图；
- 下一步为最终阶段：全量工程门禁、最新签名 Release 真机安装以及 iPhone 12 mini 逐屏验收。
