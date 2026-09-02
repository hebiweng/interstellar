"use client";

import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";

import { PortalShell } from "../components/portal-shell";
import {
  AdminApiError,
  addAdmin,
  createAdminUser,
  deleteAdminUser,
  getAdminMetrics,
  getAdminOverview,
  getAdminUsers,
  getAdmins,
  getAiPrompt,
  getAiProviders,
  removeAdmin,
  restoreDefaultAiPrompt,
  rotateAiProviderKey,
  saveAiModel,
  saveAiPrompt,
  saveAiProvider,
  testAiProvider,
  updateAdminUser,
  type AdminAccount,
  type AdminAiModel,
  type AdminAiPrompt,
  type AdminAiProvider,
  type AdminMetrics,
  type AdminOverview,
  type AdminUser,
  type UserStatus,
} from "../lib/admin-api";
import {
  FeedbackApiError,
  type FeedbackListResponse,
  type FeedbackRecord,
  listFeedback,
  updateFeedbackStatus,
} from "../lib/feedback-api";
import styles from "./admin.module.css";

type AdminTab = "overview" | "users" | "admins" | "ai" | "feedback";
type AccessState = "loading" | "ready" | "forbidden" | "unavailable" | "error";

const statusLabels: Record<UserStatus, string> = {
  active: "正常",
  disabled: "已禁用",
  suspended: "已停用",
  pending_deletion: "待删除",
  deleted: "已删除",
};

function statusTone(status: UserStatus) {
  if (status === "active") return "active";
  if (status === "suspended" || status === "pending_deletion") return "warning";
  return "danger";
}

function formatDate(value?: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) return value;
  return new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function number(value?: number | null) {
  return new Intl.NumberFormat("zh-CN").format(value ?? 0);
}

function messageOf(reason: unknown) {
  return reason instanceof Error ? reason.message : "操作失败，请稍后重试。";
}

function defaultModel(): AdminAiModel {
  return {
    id: "",
    modelId: "",
    displayName: "",
    purpose: "本命盘专业分析",
    enabled: true,
    isDefault: false,
    temperature: 0.3,
    maxTokens: 6000,
    timeoutSeconds: null,
    promptOverride: "",
    promptVersion: null,
    promptUpdatedBy: null,
    promptUpdatedAt: null,
  };
}

export default function AdminPage() {
  const [access, setAccess] = useState<AccessState>("loading");
  const [tab, setTab] = useState<AdminTab>("overview");
  const [overview, setOverview] = useState<AdminOverview | null>(null);
  const [serverMetrics, setServerMetrics] = useState<AdminMetrics | null>(null);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [admins, setAdmins] = useState<AdminAccount[]>([]);
  const [providers, setProviders] = useState<AdminAiProvider[]>([]);
  const [prompt, setPrompt] = useState<AdminAiPrompt | null>(null);
  const [promptDraft, setPromptDraft] = useState("");
  const [expandedProvider, setExpandedProvider] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [newUser, setNewUser] = useState({ email: "", displayName: "", password: "" });
  const [newAdmin, setNewAdmin] = useState({ email: "", role: "admin" as "admin" | "super_admin" });
  const [newProvider, setNewProvider] = useState({ id: "", displayName: "", baseUrl: "", apiKey: "", timeoutSeconds: 60 });
  const [providerKeys, setProviderKeys] = useState<Record<string, string>>({});
  const [newModels, setNewModels] = useState<Record<string, AdminAiModel>>({});
  const [feedbackResponse, setFeedbackResponse] = useState<FeedbackListResponse | null>(null);
  const [feedbackStatus, setFeedbackStatus] = useState<"pending" | "resolved" | null>(null);
  const [feedbackBusy, setFeedbackBusy] = useState(false);

  const handleFailure = useCallback((reason: unknown) => {
    setNotice(null);
    setError(messageOf(reason));
  }, []);

  const loadOverview = useCallback(async () => {
    setAccess("loading");
    setError(null);
    try {
      setOverview(await getAdminOverview());
      try {
        setServerMetrics(await getAdminMetrics());
      } catch (metricsReason) {
        // Metrics are optional; do not block the overview if endpoint is not ready.
      }
      setAccess("ready");
    } catch (reason) {
      if (reason instanceof AdminApiError && (reason.status === 401 || reason.status === 403)) setAccess("forbidden");
      else if (reason instanceof AdminApiError && reason.status === 404) setAccess("unavailable");
      else setAccess("error");
      setError(messageOf(reason));
    }
  }, []);

  useEffect(() => {
    queueMicrotask(() => void loadOverview());
  }, [loadOverview]);

  async function selectTab(next: AdminTab) {
    setTab(next);
    setNotice(null);
    setError(null);
    try {
      if (next === "users") setUsers((await getAdminUsers(query)).users ?? []);
      if (next === "admins") setAdmins((await getAdmins()).admins ?? []);
      if (next === "ai") {
        const [providerResult, promptResult] = await Promise.all([getAiProviders(), getAiPrompt()]);
        setProviders(providerResult.providers ?? []);
        setPrompt(promptResult);
        setPromptDraft(promptResult.platformPrompt ?? "");
      }
      if (next === "feedback") {
        setFeedbackBusy(true);
        try {
          setFeedbackResponse(await listFeedback(feedbackStatus ?? undefined));
        } catch (reason) {
          handleFailure(reason);
        } finally {
          setFeedbackBusy(false);
        }
      }
    } catch (reason) {
      handleFailure(reason);
    }
  }

  async function refreshUsers(search = query) {
    setBusy(true);
    setError(null);
    try {
      setUsers((await getAdminUsers(search)).users ?? []);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function submitUser(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await createAdminUser(newUser);
      setNewUser({ email: "", displayName: "", password: "" });
      setNotice("用户已创建。系统应通过邀请或密码重置流程让用户自行设置密码。");
      await refreshUsers();
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function changeUserStatus(user: AdminUser, status: UserStatus) {
    if (status === user.status) return;
    const reason = window.prompt(`将 ${user.email} 设为“${statusLabels[status]}”。请输入操作原因：`, "后台管理操作");
    if (reason === null) return;
    let suspendedUntil: string | null = null;
    if (status === "suspended") {
      const entered = window.prompt("请输入停用截止时间（ISO 8601，例如 2026-08-01T00:00:00Z）：", "");
      if (entered === null) return;
      suspendedUntil = entered;
    }
    setBusy(true);
    try {
      const updated = await updateAdminUser(user.email, { status, reason, suspendedUntil });
      setUsers((items) => items.map((item) => item.email === user.email ? updated : item));
      setNotice(`${user.email} 的状态已更新为“${statusLabels[status]}”。`);
    } catch (failure) {
      handleFailure(failure);
    } finally {
      setBusy(false);
    }
  }



  async function refreshFeedback(status?: "pending" | "resolved") {
    setFeedbackBusy(true);
    setError(null);
    try {
      setFeedbackResponse(await listFeedback(status));
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setFeedbackBusy(false);
    }
  }

  async function markFeedbackResolved(record: FeedbackRecord) {
    if (!window.confirm(`将 #${record.id} 标记为已处理？`)) return;
    setFeedbackBusy(true);
    try {
      await updateFeedbackStatus(record.id, "resolved");
      await refreshFeedback(feedbackStatus ?? undefined);
      setNotice(`反馈 #${record.id} 已标记为已处理。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setFeedbackBusy(false);
    }
  }
  async function requestDeleteUser(user: AdminUser) {
    if (!window.confirm(`确认将 ${user.email} 标记为待删除？此操作会撤销会话，并进入数据保留期。`)) return;
    setBusy(true);
    try {
      await deleteAdminUser(user.email);
      setUsers((items) => items.map((item) => item.email === user.email ? { ...item, status: "pending_deletion" } : item));
      setNotice(`${user.email} 已进入待删除状态。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function submitAdmin(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    try {
      await addAdmin(newAdmin);
      setNewAdmin({ email: "", role: "admin" });
      setAdmins((await getAdmins()).admins ?? []);
      setNotice("管理员已添加。新增管理员的权限会在服务端校验，不依赖前端菜单隐藏。");
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function revokeAdmin(admin: AdminAccount) {
    if (!window.confirm(`确认移除 ${admin.email} 的管理员权限？最后一名超级管理员不能被移除。`)) return;
    setBusy(true);
    try {
      await removeAdmin(admin.email);
      setAdmins((items) => items.filter((item) => item.email !== admin.email));
      setNotice(`${admin.email} 的管理员权限已移除。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function submitProvider(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    try {
      const created = await saveAiProvider({ ...newProvider, enabled: true, isDefault: providers.length === 0 });
      setProviders((items) => [...items, { ...created, models: created.models ?? [] }]);
      setNewProvider({ id: "", displayName: "", baseUrl: "", apiKey: "", timeoutSeconds: 60 });
      setExpandedProvider(created.id);
      setNotice("供应商已保存。API Key 不会再次明文返回。请继续添加可用模型并执行连接测试。");
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  function patchProviderLocal(id: string, patch: Partial<AdminAiProvider>) {
    setProviders((items) => items.map((item) => item.id === id ? { ...item, ...patch } : item));
  }

  async function persistProvider(provider: AdminAiProvider) {
    setBusy(true);
    try {
      const updated = await saveAiProvider(provider);
      setProviders((items) => items.map((item) => item.id === provider.id ? { ...updated, models: updated.models ?? item.models } : item));
      setNotice(`${provider.displayName} 的供应商配置已保存。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function rotateKey(provider: AdminAiProvider) {
    const value = providerKeys[provider.id]?.trim();
    if (!value) {
      setError("请输入新的 API Key。密钥只会提交到服务端，不会写入浏览器存储。");
      return;
    }
    setBusy(true);
    try {
      const updated = await rotateAiProviderKey(provider, value);
      setProviders((items) => items.map((item) => item.id === provider.id ? { ...item, ...updated } : item));
      setProviderKeys((items) => ({ ...items, [provider.id]: "" }));
      setNotice(`${provider.displayName} 的 API Key 已轮换。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function testProvider(provider: AdminAiProvider) {
    setBusy(true);
    try {
      const result = await testAiProvider(provider.id);
      setNotice(`${provider.displayName}：${result.message}${result.latencyMs ? `（${result.latencyMs} ms）` : ""}`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  function patchModelLocal(providerId: string, modelId: string, patch: Partial<AdminAiModel>) {
    setProviders((items) => items.map((provider) => provider.id === providerId ? {
      ...provider,
      models: provider.models.map((model) => model.id === modelId ? { ...model, ...patch } : model),
    } : provider));
  }

  async function persistModel(providerId: string, model: AdminAiModel) {
    setBusy(true);
    try {
      const updated = await saveAiModel(providerId, model);
      setProviders((items) => items.map((provider) => provider.id === providerId ? {
        ...provider,
        models: provider.models.map((item) => item.id === model.id ? updated : item),
      } : provider));
      setNotice(`${model.displayName} 的模型配置已保存。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function addModel(providerId: string) {
    const draft = newModels[providerId] ?? defaultModel();
    if (!draft.modelId.trim() || !draft.displayName.trim()) {
      setError("模型 ID 和显示名不能为空。");
      return;
    }
    setBusy(true);
    try {
      const created = await saveAiModel(providerId, draft);
      setProviders((items) => items.map((provider) => provider.id === providerId ? { ...provider, models: [...provider.models, created] } : provider));
      setNewModels((items) => ({ ...items, [providerId]: defaultModel() }));
      setNotice(`${created.displayName} 已加入供应商。`);
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function persistPrompt() {
    setBusy(true);
    try {
      const updated = await saveAiPrompt(promptDraft);
      setPrompt(updated);
      setPromptDraft(updated.platformPrompt);
      setNotice("平台通用分析前置提示词已保存并生成新版本。");
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  async function restorePrompt() {
    if (!window.confirm("恢复平台默认前置提示词？当前版本仍应由服务端保留审计记录。")) return;
    setBusy(true);
    try {
      const restored = await restoreDefaultAiPrompt();
      setPrompt(restored);
      setPromptDraft(restored.platformPrompt);
      setNotice("已恢复平台默认前置提示词。");
    } catch (reason) {
      handleFailure(reason);
    } finally {
      setBusy(false);
    }
  }

  const metrics = useMemo(() => overview ? [
    ["注册用户", number(overview.totalUsers)],
    ["近 30 日活跃用户", number(overview.activeUsers30d)],
    ["今日访问", number(overview.visitsToday)],
    ["今日分析", number(overview.analysesToday)],
    ["今日报告／导出", number(overview.exportsToday)],
    ["今日 AI 调用", number(overview.aiCallsToday)],
    ["请求错误率", `${((overview.errorRate ?? 0) * 100).toFixed(2)}%`],
    ["事件平均耗时", overview.averageLatencyMs === null ? "—" : `${number(Math.round(overview.averageLatencyMs))} ms`],
  ] : [], [overview]);

  if (access !== "ready") {
    const copy = access === "forbidden"
      ? { icon: "锁", title: "无后台访问权限", text: error ?? "请使用管理员账户登录。后台权限会由服务端校验。" }
      : access === "unavailable"
        ? { icon: "建", title: "后台服务尚未启用", text: error ?? "页面已准备好，等待后台管理接口部署。" }
        : access === "error"
          ? { icon: "!", title: "后台暂时不可用", text: error ?? "无法连接后台服务，请检查 API 服务状态。" }
          : { icon: "◌", title: "正在验证管理员身份", text: "读取后台概览与当前账户权限。" };
    return (
      <PortalShell active="admin" eyebrow="Administration · Restricted" title="后台管理" description="用户、运营行为、管理员和 AI 供应商配置只对授权管理员开放。">
        <section className={styles.accessCard}>
          <div><span className={styles.accessIcon}>{copy.icon}</span><h2>{copy.title}</h2><p>{copy.text}</p>{access === "loading" ? null : <button type="button" onClick={() => void loadOverview()}>重新验证</button>}</div>
        </section>
      </PortalShell>
    );
  }

  return (
    <PortalShell active="admin" eyebrow="Administration · Restricted" title="后台管理" description="查看账户与关键行为，管理管理员身份，并安全配置 AI 供应商、模型与分析前置提示词。">
      <nav className={styles.tabs} aria-label="后台管理栏目">
        {([
          ["overview", "运营概览"],
          ["users", "用户管理"],
          ["admins", "管理员"],
          ["ai", "AI 供应商与模型"],
          ["feedback", "用户反馈"],
        ] as Array<[AdminTab, string]>).map(([id, label]) => (
          <button key={id} type="button" data-active={tab === id} onClick={() => void selectTab(id)}>{label}</button>
        ))}
      </nav>

      {notice && <p className={styles.success}>{notice}</p>}
      {error && <p className={styles.error}>{error}</p>}

      {tab === "overview" && overview && <><OverviewView overview={overview} metrics={metrics} /><MetricsPanel metrics={serverMetrics} /></>}
      {tab === "users" && (
        <section className={styles.panel}>
          <header className={styles.panelHeader}><div><h2>用户管理</h2><p>状态操作会撤销或限制登录；流量与行为是运营监控，不是用户权限。</p></div></header>
          <form className={styles.formGrid} onSubmit={(event) => void submitUser(event)}>
            <label>用户邮箱<input required type="email" value={newUser.email} onChange={(event) => setNewUser((item) => ({ ...item, email: event.target.value }))} /></label>
            <label>显示名称<input required value={newUser.displayName} onChange={(event) => setNewUser((item) => ({ ...item, displayName: event.target.value }))} /></label>
            <label>临时密码<input required type="password" minLength={8} autoComplete="new-password" value={newUser.password} onChange={(event) => setNewUser((item) => ({ ...item, password: event.target.value }))} placeholder="至少 8 位，仅本次提交" /></label>
            <button className={styles.primaryButton} disabled={busy} type="submit">新增用户</button>
          </form>
          <form className={styles.toolbar} onSubmit={(event) => { event.preventDefault(); void refreshUsers(); }}>
            <label>搜索邮箱或名称<input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="输入关键词" /></label>
            <button className={styles.button} disabled={busy} type="submit">搜索</button>
          </form>
          <div className={styles.tableWrap}><table className={styles.table}><thead><tr><th>用户</th><th>状态</th><th>最后登录</th><th>对象</th><th>分析</th><th>导出</th><th>AI 调用</th><th>操作</th></tr></thead><tbody>
            {users.length === 0 ? <tr><td className={styles.emptyRow} colSpan={8}>暂无匹配用户</td></tr> : users.map((user) => <tr key={user.email}>
              <td><b>{user.displayName}</b><small>{user.email} · 注册于 {formatDate(user.createdAt)}</small></td>
              <td><span className={styles.badge} data-tone={statusTone(user.status)}>{statusLabels[user.status]}</span></td>
              <td>{formatDate(user.lastLoginAt)}</td><td>{number(user.peopleCount)}</td><td>{number(user.analysesCount)}</td><td>{number(user.exportsCount)}</td><td>{number(user.aiCallsCount)}</td>
              <td><div className={styles.inlineActions}><select aria-label={`设置 ${user.email} 的状态`} value={user.status} disabled={busy} onChange={(event) => void changeUserStatus(user, event.target.value as UserStatus)}>{Object.entries(statusLabels).filter(([id]) => id !== "deleted").map(([id, label]) => <option value={id} key={id}>{label}</option>)}</select><button className={styles.dangerButton} type="button" disabled={busy || user.status === "pending_deletion"} onClick={() => void requestDeleteUser(user)}>删除</button></div></td>
            </tr>)}</tbody></table></div>
        </section>
      )}

      {tab === "admins" && (
        <section className={styles.panel}>
          <header className={styles.panelHeader}><div><h2>管理员</h2><p>当前仅设置 user / admin / super_admin 角色，不提前虚构业务权限矩阵。</p></div></header>
          <form className={styles.formGrid} onSubmit={(event) => void submitAdmin(event)}>
            <label>已注册用户邮箱<input required type="email" value={newAdmin.email} onChange={(event) => setNewAdmin((item) => ({ ...item, email: event.target.value }))} /></label>
            <label>管理员角色<select value={newAdmin.role} onChange={(event) => setNewAdmin((item) => ({ ...item, role: event.target.value as "admin" | "super_admin" }))}><option value="admin">普通管理员</option><option value="super_admin">超级管理员</option></select></label>
            <button className={styles.primaryButton} disabled={busy} type="submit">添加管理员</button>
          </form>
          <div className={styles.tableWrap}><table className={styles.table}><thead><tr><th>管理员</th><th>角色</th><th>状态</th><th>最后登录</th><th>操作</th></tr></thead><tbody>
            {admins.length === 0 ? <tr><td className={styles.emptyRow} colSpan={5}>暂无管理员记录</td></tr> : admins.map((admin) => <tr key={admin.email}><td><b>{admin.displayName}</b><small>{admin.email}</small></td><td>{admin.role === "super_admin" ? "超级管理员" : "普通管理员"}</td><td><span className={styles.badge} data-tone={statusTone(admin.status)}>{statusLabels[admin.status]}</span></td><td>{formatDate(admin.lastLoginAt)}</td><td><button className={styles.dangerButton} disabled={busy} type="button" onClick={() => void revokeAdmin(admin)}>移除权限</button></td></tr>)}</tbody></table></div>
        </section>
      )}

            {tab === "feedback" && (
        <section className={styles.panel}>
          <header className={styles.panelHeader}>
            <div><h2>用户反馈</h2><p>用户提交的 Bug、功能建议与问题。反馈是公开接口，无需登录即可提交。</p></div>
          </header>
          <div className={styles.toolbar}>
            <label>
              状态筛选
              <select value={feedbackStatus ?? ""} onChange={(event) => { const value = event.target.value as "pending" | "resolved" | ""; setFeedbackStatus(value || null); void refreshFeedback(value || undefined); }}>
                <option value="">全部</option>
                <option value="pending">待处理</option>
                <option value="resolved">已处理</option>
              </select>
            </label>
            <button className={styles.primaryButton} type="button" disabled={feedbackBusy} onClick={() => void refreshFeedback(feedbackStatus ?? undefined)}>刷新</button>
          </div>
          <table className={styles.table}>
            <thead>
              <tr><th>ID</th><th>类型</th><th>内容</th><th>联系方式</th><th>用户邮箱</th><th>状态</th><th>时间</th><th>操作</th></tr>
            </thead>
            <tbody>
              {(feedbackResponse?.items ?? []).length === 0 && <tr><td colSpan={8} style={{ textAlign: "center", padding: "24px" }}>暂无反馈</td></tr>}
              {(feedbackResponse?.items ?? []).map((item) => (
                <tr key={item.id}>
                  <td>{item.id}</td>
                  <td>{item.type === "bug" ? "Bug" : item.type === "feature" ? "功能建议" : "其他"}</td>
                  <td className={styles.wrapCell} style={{ maxWidth: 320 }}>{item.content}</td>
                  <td>{item.contact ?? "—"}</td>
                  <td>{item.userEmail ?? "—"}</td>
                  <td><span className={styles.badge} data-tone={item.status === "pending" ? "warning" : "active"}>{item.status === "pending" ? "待处理" : "已处理"}</span></td>
                  <td>{formatDate(item.createdAt)}</td>
                  <td>
                    {item.status === "pending" && <button className={styles.button} type="button" disabled={feedbackBusy} onClick={() => void markFeedbackResolved(item)}>标记已处理</button>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
{tab === "ai" && (
        <div className={styles.sectionStack}>
          <PromptPanel prompt={prompt} draft={promptDraft} busy={busy} onDraft={setPromptDraft} onSave={() => void persistPrompt()} onRestore={() => void restorePrompt()} />
          <section className={styles.panel}>
            <header className={styles.panelHeader}><div><h2>供应商与模型</h2><p>密钥保存后只显示配置状态与末四位；普通用户不能读取后台配置原文。</p></div></header>
            <form className={styles.formGrid} onSubmit={(event) => void submitProvider(event)}>
              <label>供应商 ID<input required pattern="[a-z0-9][a-z0-9_-]+" value={newProvider.id} onChange={(event) => setNewProvider((item) => ({ ...item, id: event.target.value.toLowerCase() }))} placeholder="deepseek" /></label>
              <label>供应商显示名<input required value={newProvider.displayName} onChange={(event) => setNewProvider((item) => ({ ...item, displayName: event.target.value }))} placeholder="例如 DeepSeek" /></label>
              <label>Base URL<input required type="url" value={newProvider.baseUrl} onChange={(event) => setNewProvider((item) => ({ ...item, baseUrl: event.target.value }))} placeholder="https://api.example.com" /></label>
              <button className={styles.primaryButton} disabled={busy} type="submit">新增供应商</button>
              <label>初始 API Key<input type="password" autoComplete="new-password" value={newProvider.apiKey} onChange={(event) => setNewProvider((item) => ({ ...item, apiKey: event.target.value }))} placeholder="仅提交至服务端" /></label>
              <label>默认超时（秒）<input type="number" min="5" max="600" value={newProvider.timeoutSeconds} onChange={(event) => setNewProvider((item) => ({ ...item, timeoutSeconds: Number(event.target.value) }))} /></label><span />
            </form>
          </section>
          {providers.map((provider) => {
            const newModel = newModels[provider.id] ?? defaultModel();
            return <article className={styles.providerCard} key={provider.id}>
              <div className={styles.providerSummary}><div><h3>{provider.displayName}</h3><p>{provider.baseUrl}</p></div><div className={styles.providerMeta}><span className={styles.badge} data-tone={provider.enabled ? "active" : "warning"}>{provider.enabled ? "已启用" : "已停用"}</span>{provider.isDefault && <span className={styles.badge} data-tone="active">默认供应商</span>}<span className={styles.badge}>{provider.apiKeyConfigured ? `Key 已配置 ····${provider.apiKeyLastFour ?? ""}` : "Key 未配置"}</span><span className={styles.badge}>{provider.models.length} 个模型</span></div><button className={styles.button} type="button" onClick={() => setExpandedProvider((value) => value === provider.id ? null : provider.id)}>{expandedProvider === provider.id ? "收起" : "管理"}</button></div>
              {expandedProvider === provider.id && <div className={styles.providerBody}>
                <div className={styles.providerSettings}><label className={styles.field}>显示名<input value={provider.displayName} onChange={(event) => patchProviderLocal(provider.id, { displayName: event.target.value })} /></label><label className={styles.field}>Base URL<input type="url" value={provider.baseUrl} onChange={(event) => patchProviderLocal(provider.id, { baseUrl: event.target.value })} /></label><label className={styles.field}>超时（秒）<input type="number" min="5" max="600" value={provider.timeoutSeconds} onChange={(event) => patchProviderLocal(provider.id, { timeoutSeconds: Number(event.target.value) })} /></label><label className={styles.checkbox}><input type="checkbox" checked={provider.enabled} onChange={(event) => patchProviderLocal(provider.id, { enabled: event.target.checked })} />启用</label></div>
                <div className={styles.inlineActions}><button className={styles.primaryButton} disabled={busy} type="button" onClick={() => void persistProvider(provider)}>保存供应商</button><button className={styles.button} disabled={busy} type="button" onClick={() => void testProvider(provider)}>测试连接</button></div>
                <div className={styles.keyRow}><label className={styles.field}>轮换 API Key<input type="password" autoComplete="new-password" value={providerKeys[provider.id] ?? ""} onChange={(event) => setProviderKeys((items) => ({ ...items, [provider.id]: event.target.value }))} placeholder="保存后仅显示末四位" /></label><span className={styles.badge}>{provider.apiKeyConfigured ? `当前 ····${provider.apiKeyLastFour ?? ""}` : "尚未配置"}</span><button className={styles.button} disabled={busy} type="button" onClick={() => void rotateKey(provider)}>轮换密钥</button></div>
                <div className={styles.modelList}>{provider.models.map((model) => <ModelEditor key={model.id} model={model} busy={busy} onChange={(patch) => patchModelLocal(provider.id, model.id, patch)} onSave={() => void persistModel(provider.id, model)} />)}</div>
                <ModelEditor model={newModel} busy={busy} isNew onChange={(patch) => setNewModels((items) => ({ ...items, [provider.id]: { ...newModel, ...patch } }))} onSave={() => void addModel(provider.id)} />
              </div>}
            </article>;
          })}
        </div>
      )}
    </PortalShell>
  );
}


function MetricsPanel({ metrics }: { metrics: AdminMetrics | null }) {
  if (!metrics) return null;
  return <section className={styles.metricPanel}><header className={styles.panelHeader}><div><h2>运行指标</h2><p>服务器负载与使用概况（请求计数待接入）。</p></div></header><div className={styles.metricGrid}><article><span>CPU</span><b>{metrics.cpu_percent ? `${metrics.cpu_percent.toFixed(1)}%` : "—"}</b></article><article><span>内存</span><b>{metrics.memory_percent ? `${metrics.memory_percent.toFixed(1)}%` : "—"}</b></article><article><span>24h 活跃</span><b>{number(metrics.active_users_24h)}</b></article><article><span>24h AI 调用</span><b>{number(metrics.ai_calls_24h)}</b></article></div></section>;
}

function OverviewView({ overview, metrics }: { overview: AdminOverview; metrics: string[][] }) {
  return <><section className={styles.metricGrid}>{metrics.map(([label, value]) => <article className={styles.metric} key={label}><small>{label}</small><b>{value}</b></article>)}</section><section className={styles.activityPanel}><header className={styles.panelHeader}><div><h2>关键行为</h2><p>访问、分析、报告／导出和 AI 调用的运营记录，不采集按键内容或会话回放。</p></div></header><ul className={styles.activityList}>{(overview.recentActivity ?? []).length === 0 ? <li><b>暂无近期行为记录</b></li> : overview.recentActivity.map((item) => <li key={item.id}><span>{item.type}</span><b>{item.label}{item.actor ? ` · ${item.actor}` : ""}</b><time>{formatDate(item.createdAt)}</time></li>)}</ul></section></>;
}

function PromptPanel({ prompt, draft, busy, onDraft, onSave, onRestore }: { prompt: AdminAiPrompt | null; draft: string; busy: boolean; onDraft: (value: string) => void; onSave: () => void; onRestore: () => void }) {
  return <section className={styles.promptPanel}><header className={styles.panelHeader}><div><h2>分析前置提示词</h2><p>平台通用提示可由模型专属提示补充，但不可覆盖服务端安全边界。</p></div></header><div className={styles.promptBody}><div><label className={styles.field}>平台通用前置提示词<textarea value={draft} onChange={(event) => onDraft(event.target.value)} placeholder="为全部占星分析模型提供统一的任务说明与输出要求" /></label><p className={styles.promptMeta}>版本 {prompt?.version ?? "—"} · 最后修改者 {prompt?.updatedBy ?? "—"} · {formatDate(prompt?.updatedAt)}</p><div className={styles.promptActions}><button className={styles.button} disabled={busy} type="button" onClick={onRestore}>恢复默认</button><button className={styles.primaryButton} disabled={busy} type="button" onClick={onSave}>保存新版本</button></div></div><aside className={styles.promptPreview}><h3>发送给模型的拼接顺序</h3><ol><li><b>不可覆盖安全边界</b><br />由服务端维护，管理员提示词也不能删除。</li><li><b>平台通用前置提示</b><br />统一专业性、表达方式和输出结构。</li><li><b>模型专属覆盖</b><br />用于适配不同供应商或模型能力。</li><li><b>用户分析重点</b><br />普通用户只填写想关注的问题，不接触系统配置。</li></ol></aside></div></section>;
}

function ModelEditor({ model, busy, isNew = false, onChange, onSave }: { model: AdminAiModel; busy: boolean; isNew?: boolean; onChange: (patch: Partial<AdminAiModel>) => void; onSave: () => void }) {
  return <section className={styles.modelCard}><header className={styles.modelHeading}><div><b>{isNew ? "新增模型" : model.displayName}</b><small>{model.modelId || "填写供应商模型 ID"}</small></div>{!isNew && <div className={styles.providerMeta}><span className={styles.badge} data-tone={model.enabled ? "active" : "warning"}>{model.enabled ? "已启用" : "已停用"}</span>{model.isDefault && <span className={styles.badge} data-tone="active">默认模型</span>}</div>}</header><div className={styles.modelForm}><label>模型 ID<input value={model.modelId} onChange={(event) => onChange({ modelId: event.target.value })} placeholder="deepseek-chat" /></label><label>显示名<input value={model.displayName} onChange={(event) => onChange({ displayName: event.target.value })} placeholder="DeepSeek Chat" /></label><label>用途<input value={model.purpose} onChange={(event) => onChange({ purpose: event.target.value })} /></label><label>超时（秒）<input type="number" min="5" max="600" value={model.timeoutSeconds ?? ""} onChange={(event) => onChange({ timeoutSeconds: event.target.value ? Number(event.target.value) : null })} /></label><label>Temperature<input type="number" min="0" max="2" step="0.1" value={model.temperature ?? ""} onChange={(event) => onChange({ temperature: event.target.value ? Number(event.target.value) : null })} /></label><label>最大输出 Tokens<input type="number" min="256" value={model.maxTokens ?? ""} onChange={(event) => onChange({ maxTokens: event.target.value ? Number(event.target.value) : null })} /></label><label className={styles.checkbox}><input type="checkbox" checked={model.enabled} onChange={(event) => onChange({ enabled: event.target.checked })} />启用模型</label><label className={styles.checkbox}><input type="checkbox" checked={model.isDefault} onChange={(event) => onChange({ isDefault: event.target.checked })} />设为默认</label><label className={`${styles.full}`}>模型专属前置提示覆盖<textarea value={model.promptOverride} onChange={(event) => onChange({ promptOverride: event.target.value })} placeholder="留空则只使用平台通用提示；不能覆盖安全边界。" /></label>{!isNew && <p className={`${styles.promptMeta} ${styles.full}`}>提示词版本 {model.promptVersion ?? "—"} · 最后修改者 {model.promptUpdatedBy ?? "—"} · {formatDate(model.promptUpdatedAt)}</p>}<div className={styles.modelFormActions}><button className={styles.primaryButton} disabled={busy} type="button" onClick={onSave}>{isNew ? "添加模型" : "保存模型"}</button></div></div></section>;
}

