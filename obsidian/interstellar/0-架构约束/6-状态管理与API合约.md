---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '2e1728aa-8167-4887-8518-a88f4b4c6d9c'
  PropagateID: '2e1728aa-8167-4887-8518-a88f4b4c6d9c'
  ReservedCode1: '5f86339c-bb88-487c-ace0-d6e5512a3ad9'
  ReservedCode2: '5f86339c-bb88-487c-ace0-d6e5512a3ad9'
---

# 状态管理与 API 合约

> 前端状态分层管理，前后端数据结构对齐。

---

## 前端状态分层

### 第一层：URL 状态

适用场景：
- 当前选中的盘型（Tab）
- 当前选中的用户 ID
- 不需要持久化的筛选条件

规则：URL 状态用 Next.js 的 `useSearchParams` 或 `useRouter` 管理，刷新页面后保留。

### 第二层：组件状态（useState）

适用场景：
- 表单输入值（目标日期、参数设置）
- 计算结果
- AI 分析加载/结果
- 面板内部交互（Tab 选中、展开/折叠）

规则：所有计算结果和解读数据最终汇聚在 workspace 组件的 state 中，再通过 props 向下传递。

### 第三层：派生状态（useMemo）

适用场景：
- 解读数据构建（`buildSecondaryProgressionRightPanel` 等函数的输出）
- 渲染规格（`buildNatalRenderSpec` 的输出）
- 排序/筛选后的列表

规则：useMemo 的依赖必须是 state 或 props，禁止在 useMemo 回调中发起异步操作。

### 禁止使用的全局状态

- 不使用 React Context 跨盘型共享计算结果
- 不使用全局 store（如 Zustand/Redux）管理盘型状态
- 跨盘型数据传递通过 URL 参数或 workspace 顶层 props 实现

---

## API 合约规范

### 请求规范

| 规则 | 说明 |
|---|---|
| 路径风格 | RESTful，kebab-case：`/ai/natal/analyses/preview` |
| 请求方法 | 查询用 GET，创建/提交用 POST |
| 请求体 | JSON，字段 camelCase |
| 认证 | 通过 middleware 自动注入，前端不手动传递 token |

### 响应规范

| 规则 | 说明 |
|---|---|
| 状态码 | 200 成功、404 资源不存在、409 冲突、422 参数错误、500 服务端错误 |
| 响应体 | JSON，字段 camelCase |
| 错误格式 | `{ detail: string, status: number }` |

### Snapshot 传递规则

核心问题：前端何时传 snapshot ID，何时传完整对象？

| 场景 | 传递方式 | 原因 |
|---|---|---|
| 后端已持久化的 snapshot | 只传 `snapshot_id` | 后端可从数据库读取 |
| 前端刚计算、后端尚未持久化的 snapshot | 传 `snapshot` 全量对象 | 后端 workflow_store 是内存字典，无法通过 ID 查找 |
| AI 分析请求 | 同时传 `snapshot_id` + `snapshot` 全量 | preview 接口需要验证可用性，submit 接口需要完整数据 |

**判断标准**：如果后端存储是持久化的（PostgreSQL），传 ID 即可；如果后端存储是内存字典（workflow_store），必须传全量。当前 workflow_store 是内存字典，因此一律传全量。

### 前后端类型对齐

- 后端 Pydantic 模型变更时，必须同步更新前端 `interstellar-api.ts` 中的对应类型
- 新增/删除字段时，前端做 optional 处理（`field?: Type`），避免因后端先部署导致前端崩溃
- 类型变更必须在同一 PR 中完成前后端同步

### 错误处理模式

```text
API 请求
    → 成功：更新 state
    → 网络错误：显示"请检查网络连接或稍后再试"
    → 404：显示"资源不存在，请重新计算"
    → 409：显示"服务配置有误，请联系管理员"
    → 422：显示"请求参数有误"（开发环境同时 console.error 详细信息）
    → 500：显示"服务端异常，请稍后再试"
```

- 不使用 toast 弹窗通知（按用户要求）
- 错误信息显示在面板内容区域，替换正常内容
- AI 分析的错误处理：在面板内显示降级提示 + 引导使用本地解读

## 检查清单

- [ ] 新增状态是否放在了正确的层级
- [ ] 是否误用了全局状态管理跨盘型数据
- [ ] API 请求是否传了完整的 snapshot（当前阶段需要）
- [ ] 后端模型变更是否同步了前端类型
- [ ] 错误处理是否在面板内展示（而非 toast）
- [ ] useMemo 依赖是否正确（无异步操作）

> AI生成