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

本文件只保留跨任务强制规则，不记录版本号、设备状态、部署流水或产品待办。

## 1. 必读文件与职责

接手任何未完成任务，必须先读 `AGENTS.md` 和 `docs/agent-handoff.md`。随后按任务类型补读，不要把所有历史文档都载入上下文：

1. `AGENTS.md`：跨任务规则。
2. `docs/ios-v6-rebuild-plan.md`：当前 iOS 产品与实施合同。
3. `docs/ios-card-implementation-matrix.md`：六盘和 Today 的卡片合同。
4. `docs/ios-product-backlog.md`：尚未实施的产品需求。
5. `docs/ios-release-readiness.md`：正式上架门禁。
6. `docs/agent-handoff.md`：当前工作区、Build、Relay、验证证据和下一步。

| 任务类型 | 必须补读 |
|---|---|
| iOS 产品、UI、计算、卡片或报告实现 | `docs/ios-v6-rebuild-plan.md`、`docs/ios-card-implementation-matrix.md` |
| 新增、修改或核销产品需求 | `docs/ios-product-backlog.md`，并回查相关产品合同 |
| Archive、TestFlight、App Store、购买、隐私、许可或上线检查 | `docs/ios-release-readiness.md` |
| 内容 Schema、Copy Catalog 或私有语料构建 | `ios/ContentSchema/` 内相关说明及对应私有构建说明 |
| Relay 或生产部署 | `docs/ios-release-readiness.md`、`infra/deploy/` 内目标部署合同 |
| 旧 Web 解读架构 | `docs/chart-insight-design-standard.md` |

权威优先级：真实计算与不可变 Snapshot → v6 合同 → 卡片矩阵 → 当前代码和测试 → 原型视觉参考。backlog 只能描述未来改动，不能覆盖已生效合同；handoff 只能描述状态，不能创建长期产品规则。

Obsidian 只在项目合同、Schema、代码、测试和私有内容都无法解决明确缺口时定向查询，不得默认遍历。

## 2. 目录与安全边界

| 路径 | 职责与边界 |
|---|---|
| `ios/App/` | iOS 源码和固定 UI 资源；生成的私有 Copy Catalog 被忽略，不是编辑源 |
| `ios/Localization/ui-translations.json` | en / zh-Hans / es / fr 固定 UI 唯一源；不得放消费者解释正文 |
| `ios/ContentSchema/` | 可公开的内容 Schema、卡片和变量合同 |
| `artifacts/<preset>-<chart>/` | 可公开语料合同包；每套固定 10 个 JSON，只含键、结构、事实覆盖和缺口 |
| `ios/PrivateContent/`、`ios/PrivateRules/` | 私有正文、提示词和规则源；不得进入公开 Git、日志、附件或截图 |
| `ios/App/Resources/CopyCatalog-*`、`Private*` | 从私有源生成的运行时包；可重建，不得公开 |
| `ios/Packages/AstroCore/` | iOS 权威占星计算 |
| `ios/Packages/ContentKit/` | 内容模型、匹配和结构校验 |
| `relay/` | Go Relay、管理端、购买、反馈、鉴权和审计；不得记录密钥、提示词或报告正文 |
| `infra/deploy/` | 生产、Relay-only、Caddy 和镜像部署合同 |
| GitHub Pages | 无需鉴权或动态后端的正式外部页面统一承载于此，包括法律、支持、Privacy Choices / Account Deletion、产品宣传及以后同类静态页面；iOS 新版本直接链接 Pages，Relay 仅为旧版本保留永久重定向兼容 |
| 旧 Web/API/Worker 目录 | 延期但仍受版本控制；未完成退役审计前不得删除 |
| `.env*`、凭据、本地数据库、设备日志 | 永不进入 Git、artifact、聊天输出或截图 |
| 缓存与构建产物 | 确认无进程使用后可删除并按需重建；不得把源码或私有数据当缓存 |

语料链路固定为：

```text
代码 / Planner / 真实计算测试
→ artifacts/<preset>-<chart>/ 十文件公开合同包
→ 外部生成并人工审核的 patch（不进公开 Git）
→ ios/PrivateContent/copy-catalog-v2/ 私有源
→ scripts/build-ios-copy-catalog.mjs
→ ios/App/Resources/CopyCatalog-<locale>.json
```

`TranslationExports` 只兼容旧流程。新任务不得自创替代合同，也不得把待生成合同放进 `PrivateContent`。

## 3. 事实、展示与 AI

- iOS 事实链路为 AstroCore → 不可变 Snapshot → 展示层；展示层只能排序、过滤、映射和呈现空状态。
- 不得虚构评分、事件、相位、宫位、日期或演示数据，也不得在展示层补算。
- AI 只能解释请求中已经计算的事实，不能计算星盘、覆盖 Snapshot 或新增事实。
- Today 只消费注册 provider 输出和已计算事件；新增盘型通过 provider 注册，不在页面写盘型分支。
- 参数变化必须先重算 Snapshot，再按新指纹读取或生成 Artifact；Today 不受 Charts 探索参数污染。
- 卡片事实、内容选择和报告证据必须保留稳定 ID 与来源引用。

## 4. 内容、本地化与报告

- 每个可见事实呈现“计算结果 + 已审核的一句自然解读”；Swift 不拼消费者解释句。
- `approved` 不等于可发布；条目还必须通过 Schema、类型、selector、事实引用和卡片合同校验。
- 固定 UI 使用 String Catalog；术语使用四语 AstroTerms；消费者正文只进私有 Copy Catalog。
- 内容键缺失必须明确失败，不得在 Swift 中加入解释性降级句。
- 六盘 AI 只生成整盘报告，不生成单卡 AI 详情；只有用户明确操作才可联网。
- 本机同语义 Artifact 命中时禁止联网；撤回 AI 授权后已有报告仍可读，但不得生成新报告。
- Relay 的 Credit 消费以客户端成功保存并 ACK 为准；不得出现已扣费但没有本地可读报告。
- 私有原创正文、翻译、规则、提示词和运行时包不得因开源代码交付而泄漏；许可范围按 `ios/LICENSE.md` 和发布审查结论执行。

## 5. 人物、地点与消费者体验

- 地点只能来自 Apple 地图当前位置、搜索或点选；时区自动确定并只读，消费者不编辑经纬度。
- Profile 保留本人、其他人物、关系、头像和出生资料；删除人物必须清理关联 Artifact。
- 同一界面只显示当前语言；先给生活结论，再给技术参数。
- 关键页面必须支持 iPhone 12 mini、长文本、Dynamic Type、浅深色和 VoiceOver。
- 轮盘、矩阵、时间线和其他视觉必须映射真实事实；构建通过不等于视觉或内容验收完成。

## 6. 实现、验证与交接

重要改动按以下顺序：

1. 核对相关合同、代码、测试和私有内容 Schema。
2. 明确计算输入、事实映射、空状态和失败方式。
3. 按事实 → planner/builder → 私有内容 → 固定组件分层实现。
4. 运行适用单元测试、构建和人工真机验收。
5. 只在有证据时标记完成；更新对应 backlog/release 文件和 handoff。

适用门禁：

```sh
scripts/check-ios-card-contract.sh
npm run ios:copy:validate
npm run ios:localization:validate
npm run architecture:check
npm run lint -- --quiet
scripts/check-private-content.sh
git diff --check
```

同时运行相关 AstroCore、ContentKit、iOS 和 Relay 测试。私有 Catalog 缺失时恢复私有源，不得用公开临时文案绕过。

## 7. 部署与运维

- 开发环境使用 `compose.yaml` + `compose.app.yaml`。
- 生产和 Relay-only 分别以 `infra/deploy/compose.production.yaml`、`infra/deploy/compose.relay-only.yaml` 为准。
- iOS Relay 权威域名为 `https://aaadmin.xiaoguiwk.top`。
- `linux/amd64` 镜像在本机或 CI 构建后传输；低内存服务器不现场编译。
- 部署前备份数据库并验证目标镜像、Compose 和环境；只重建任务要求的服务。
- 不得把管理员凭据、API Key、出生资料、事实正文、提示词或 AI 正文写入 Git、日志、Bark 或截图。
- 新增对外静态页面时默认使用 GitHub Pages，不得继续增加 Relay 静态页面负载；只有需要鉴权、购买、报告、动态数据或服务端处理的页面/API 才进入 Relay。Pages 仓库不得包含私有语料、提示词、密钥、Relay 配置或用户数据。

> AI生成
