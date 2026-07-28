---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '2fb51c4d-260f-43d3-aba8-10edbaa6b882'
  PropagateID: '2fb51c4d-260f-43d3-aba8-10edbaa6b882'
  ReservedCode1: '485383bb-ea2b-4c11-b8fb-63121ba0cbf7'
  ReservedCode2: '485383bb-ea2b-4c11-b8fb-63121ba0cbf7'
---

# Git 工作流

> 分支策略、提交规范、推送确认规则。

---

## 分支策略

| 分支 | 用途 | 命名规则 |
|---|---|---|
| `codex/interstellar-v1` | 主开发分支，所有稳定功能合并至此 | 固定名称 |
| `sec` | 次限盘专用功能分支 | 盘型缩写 |
| `feature/{盘型或功能名}` | 新功能开发分支 | `feature/secondary-right-panel`、`feature/transit-ai` |
| `fix/{问题描述}` | Bug 修复分支 | `fix/transit-404`、`fix/ai-analysis-409` |

**规则**：
1. 功能开发在 feature 分支进行，完成后合并到 `codex/interstellar-v1`
2. 盘型专用功能（如次限盘右侧面板）在盘型分支开发，完成后合并到主开发分支
3. 禁止直接在 `codex/interstellar-v1` 上开发新功能
4. 分支合并前必须通过验证（截图 + checklist）

## 提交信息规范

格式：

```text
{类型}: {简短描述}

{可选：详细说明}
```

类型：

| 类型 | 说明 |
|---|---|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 重构（不改变功能） |
| `style` | 样式调整（不改变逻辑） |
| `docs` | 文档变更 |
| `chore` | 构建/工具/依赖变更 |

示例：

```text
feat(secondary): 右侧面板替换为5卡片解读布局

- 替换通用 ConsumerInsight 为专用卡片
- 保留 AI 圆形按钮和降级提示
- 添加卡片 CSS 样式
```

## 推送确认规则

1. **不自动推送**：所有本地提交默认不推送到 GitHub，必须用户明确确认后才推送。
2. **推送前检查**：
   - 本地所有提交是否通过验证（截图/Playwright）
   - 是否有未完成的功能（WIP 代码）
   - 是否有敏感信息（API Key、密码等）
3. **推送命令**：`git push origin {分支名}`，只在用户确认后执行。

## 合并规则

1. Feature 分支合并到主开发分支时，优先使用 squash merge（保持提交历史整洁）
2. 冲突解决在本地完成，不在 GitHub 网页上解决
3. 合并后删除 feature 分支

## 检查清单

- [ ] 新提交是否符合提交信息规范
- [ ] 是否在正确的分支上开发
- [ ] 推送前是否经过用户确认
- [ ] 合并前是否通过验证
- [ ] 合并后是否删除了 feature 分支

> AI生成