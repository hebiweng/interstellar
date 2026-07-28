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

> 任何 agent 或工程师接手本项目时，先读此文件，再读 `docs/agent-handoff.md` 和 `docs/chart-insight-design-standard.md`。

---

## 1. 接手前必读顺序

```text
1. AGENTS.md（本文件）
2. docs/agent-handoff.md       ← 当前状态与交接
3. docs/chart-insight-design-standard.md  ← 跨盘型解读设计标准
4. 对应盘型 Obsidian 目录      ← 调研源和语料素材
5. 已有同类盘型实现            ← 优先参考次限盘
```

不要跳过。不要从空白处自由发挥。

---

## 2. Obsidian 使用规则

```text
Obsidian = 人工维护的调研源 / 知识源 / 语料素材源
项目文件 = 运行时权威源 / 工程实现源 / 验收源
```

1. 缺语料、缺设计、缺解释时，先查 Obsidian。
2. Obsidian 中有用的内容，必须迁移或改写进项目内 corpus / rules 文件。
3. 运行时代码不能直接依赖 Obsidian。
4. Obsidian 原文不等于消费者文案，必须过滤内部讨论口吻。
5. 如果 Obsidian 内容不完整，agent 可以补充设计，但补充内容也必须写入项目内文件。
6. 如果 Obsidian 内容和项目规则冲突，以项目内已固化规则为准；必要时更新项目规则，并在交接文档里说明原因。

正确流程：

```text
读 Obsidian
→ 提炼可用语料和设计规则
→ 写入项目内 corpus / presentation-rules / docs
→ UI 只消费项目内内容
```

错误流程：

```text
读 Obsidian → 直接写 UI        ← 禁止
运行时代码 import Obsidian     ← 禁止
把 Obsidian 讨论口吻给用户看   ← 禁止
```

---

## 3. 服务器、客户端与 AI 的职责边界

### 服务器负责权威事实

服务器返回的是"可复核事实"：星历计算、黄道与宫位、点位、相位、跨盘相位、ingress/egress/exact 日期、出生地点/时区/经纬度解析、账户/保存/权限、可审计 Snapshot、正式报告生成、AI 调用代理。

### 客户端负责展示层派生

浏览器端可以做：右侧即时解读卡片、可视化组件、根据服务器事实选择语料、空状态、排序和过滤、不改变事实的文案组织。

### 客户端不能伪造权威事实

浏览器端不能做：自己重算星历、补服务器没给的相位、推断精确日期、判断出生时区、把弱信号包装成强信号、制造不存在的 ingress/egress。

### AI 只解释，不计算

AI 只能读取已计算好的事实，生成解释文本。AI 不能：算星盘、改星盘、覆盖服务器事实、生成服务器没返回的相位/宫位/日期、把推测写成计算结果。

---

## 4. 盘型解读分层

每个盘型的解读必须按以下分层实现：

```text
后端事实
→ insight builder（选择事实、填变量、过滤噪声）
→ corpus 语料（提供可复用文案）
→ presentation rules 展示规则（定义模块和禁忌）
→ React 固定模板（只渲染固定结构）
→ CSS 独立样式（只控制视觉）
```

每个分层对应的文件位置：

| 分层 | 文件模式 |
|---|---|
| insight builder | `app/lib/insight/{chart}.ts` |
| corpus 语料 | `app/lib/insight/{chart}-corpus.ts` |
| corpus 组合句 | `app/lib/insight/{chart}-corpus-combinations.ts` |
| presentation rules | `app/lib/insight/{chart}-presentation-rules.ts` |
| 共享工具 | `app/lib/insight/shared.ts` |
| React 组件 | `app/components/workspaces/{chart}-instant-insight.tsx` |
| CSS | 独立 CSS 文件 |

---

## 5. 禁止事项

### 5.1 Obsidian frontmatter 规范

所有 Obsidian `.md` 文件必须包含以下 frontmatter 字段：

```yaml
created: YYYY-MM-DD    # 文件首次创建日期（新建时写入，后续不修改）
updated: YYYY-MM-DD    # 文件最后修改日期（每次修改时更新）
author: 创建者          # teleagent / codefree / codex / human
modified_by: 最后修改者 # 同上
```

详细规范见 `docs/chart-insight-design-standard.md` 第 10 节。

- 运行时代码依赖 Obsidian 目录
- 把内部说明写进消费者 UI
- 硬编码当前样例的特定数值
- 在消费者代码中使用内部话术（"人话""怎么用""别误读""模板回答"等）
- 服务器没返回的事实由客户端伪造
- AI 计算星盘或覆盖服务器事实
- 次限盘样板退化（5 个模块 id 缺失）
- page.tsx 变胖（不能有 `"use client"`、不能持 React state、不能直接 fetch）
- 未经架构检查和 lint 就提交
- 改完不更新 `docs/agent-handoff.md`

---

## 6. 验证要求

每次重要任务完成后：

1. 运行 `npm run architecture:check`（如果已配置）和 `npm run lint -- --quiet`
2. 确认未引入 Obsidian 运行时依赖
3. 确认消费者代码无内部话术
4. 确认次限盘 5 个模块 id 仍存在
5. 更新 `docs/agent-handoff.md`

---

## 7. 完成后必须做的事

1. 更新 `docs/agent-handoff.md`：记录最近完成、当前状态、未完成能力、下一步注意事项
2. 确认架构检查通过
3. 确认未改无关业务

---

## 8. Docker 与部署

- 开发环境：`compose.yaml` + `compose.app.yaml`（注意不是 `docker-compose.yml`）
- 生产环境：`infra/deploy/` 目录下的 `compose.production.yaml` + `Dockerfile.web` + `Caddyfile.fate`
- 开发环境使用 volume mount 热更新，生产环境代码 bake 进镜像
- API 代理：生产环境通过 Caddy 反向代理解决，不依赖客户端直连

---

## 9. 标准任务提示

以后给任何 agent 任务时，可以使用以下提示：

```text
你现在接手 Interstellar 项目。先阅读 AGENTS.md、docs/agent-handoff.md、docs/chart-insight-design-standard.md，再阅读当前任务对应的 Obsidian 盘型目录和已有同类盘型代码。

任务：按跨盘型解读设计规范推进当前盘型。Obsidian 是人工维护的调研/语料源；缺语料时先查 Obsidian，有用内容迁移或改写进项目内 corpus/rules；运行时代码不得依赖 Obsidian。

服务器只负责权威计算事实；浏览器负责展示层派生；AI 只能解释已算事实，不能计算或覆盖事实。

不要把内部说明写进消费者 UI。不要改无关业务。完成后运行 npm run architecture:check 和 npm run lint -- --quiet，并更新 docs/agent-handoff.md。
```

> AI生成