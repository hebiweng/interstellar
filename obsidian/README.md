# Interstellar Obsidian 目录

`interstellar/` 是唯一 Obsidian Vault，完整占星研究与 iOS 开发项目在同一知识图谱内维护。

| 路径 | 用途 | Git 策略 |
|---|---|---|
| `interstellar/0-架构约束/` | 通用工程约束 | 私有 Vault 内容 |
| `interstellar/1-主盘型/` 至 `5-合盘/` | 占星研究与原创语料 | 私有 Vault 内容 |
| `interstellar/6-iOS开发/` | iOS 产品、开发、ADR、测试与阶段记录 | 私有 Vault 内容 |

整个 `interstellar/` 已加入 `.gitignore`，防止新增研究资料进入应用仓库。历史上已经被 Git 跟踪的旧 Vault 文件不会因 `.gitignore` 自动解除跟踪；公开仓库前必须执行一次单独、可审查的索引迁移。

## 单一事实来源

- 完整研究资料以 `interstellar/` 为准；
- iOS 工程执行合同以 [`../docs/ios-v1-development-plan.md`](../docs/ios-v1-development-plan.md) 为准；
- `interstellar/6-iOS开发/` 用于记录设计判断、阶段证据、ADR 和 backlog，不复制完整研究语料；
- 计算代码、公共规则和样例内容仍以代码仓库对应目录为准。

## 同步规则

从下载目录同步研究 Vault 时：

1. 源目录必须先通过修改时间与文件数量确认；
2. 默认排除 `.DS_Store` 和压缩包；
3. 不把私有 Vault 的新增文件加入 Git；
4. iOS 项目可以链接研究笔记，但不得复制完整语料到公共代码；
5. 删除或替换研究文件前先生成可恢复备份并预演差异。
