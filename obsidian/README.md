# Interstellar Obsidian 目录

`interstellar/` 是本机私有 Obsidian Vault，只保存研究资料、候选语料和历史笔记，不是应用运行时或当前工程合同的权威源。

| 路径 | 用途 | Git 策略 |
|---|---|---|
| `interstellar/0-架构约束/` | 历史工程笔记 | 本机私有参考，不覆盖项目合同 |
| `interstellar/1-主盘型/` 至 `5-合盘/` | 占星研究与原创候选语料 | 本机私有参考，不直接进入运行时 |
| `interstellar/6-iOS开发/` | 历史 iOS 设计、ADR 与阶段记录 | 本机私有参考，不作为当前进度 |

整个 `interstellar*` 已加入 `.gitignore`；Vault 内容必须保持未追踪。公开仓库只保留本 README，用于说明私有边界。

## 单一事实来源

- iOS 产品合同以 [`../docs/ios-v6-rebuild-plan.md`](../docs/ios-v6-rebuild-plan.md) 与 [`../docs/ios-card-implementation-matrix.md`](../docs/ios-card-implementation-matrix.md) 为准；
- 当前进度和验证证据以 [`../docs/agent-handoff.md`](../docs/agent-handoff.md) 为准；
- 计算事实、Schema、选择规则和测试以项目代码为准；
- Obsidian 只在项目内权威源无法解决明确缺口时定向查询；候选内容必须重写、审核并进入项目私有内容源，运行时不得读取 Vault。

## 同步规则

从下载目录同步研究 Vault 时：

1. 源目录必须先通过修改时间与文件数量确认；
2. 默认排除 `.DS_Store` 和压缩包；
3. 不把私有 Vault 的新增文件加入 Git；
4. iOS 项目可以链接研究笔记，但不得复制完整语料到公共代码；
5. 删除或替换研究文件前先生成可恢复备份并预演差异。
