"use client";

import { useCallback, useEffect, useState } from "react";
import styles from "./xiaoguiwk.module.css";

const API_BASE = "/xiaoguiwk-api";

type Provider = {
  id: string;
  label: string;
  base_url: string;
  api_key_set: boolean;
  default_model: string;
  enabled: boolean;
  is_default: boolean;
};

type Prompt = { scope: string; locale: string; system_prompt: string; version: number; updated_at: string };

type UsageRow = { day: string; model: string; requests: number; successes: number; success_rate: number; prompt_tokens: number; completion_tokens: number };

function promptKey(p: Prompt): string {
  return `${p.scope}|${p.locale}`;
}

export default function XiaoguiwkAdminPage() {
  const [authenticated, setAuthenticated] = useState<boolean | null>(null);
  const [tab, setTab] = useState<"config" | "prompts" | "usage">("config");

  useEffect(() => {
    api<{ authenticated: boolean }>("/admin/session", "")
      .then(() => setAuthenticated(true))
      .catch(() => setAuthenticated(false));
  }, []);

  if (authenticated === null) {
    return <div className={styles.shell} />;
  }
  if (!authenticated) {
    return <LoginView onLogin={() => setAuthenticated(true)} />;
  }

  async function logout() {
    try {
      await api("/admin/logout", "", { method: "POST" });
    } finally {
      setAuthenticated(false);
    }
  }
  return (
    <div className={styles.shell}>
      <div className={styles.inner}>
        <div className={styles.header}>
          <div className={styles.brand}>
            Interstellar <em>· 管理员后台</em>
          </div>
          <button className={`${styles.btn} ${styles.danger}`} onClick={logout}>
            退出登录
          </button>
        </div>
        <div className={styles.tabs}>
          {(
            [
              ["config", "API Key 配置"],
              ["prompts", "提示词"],
              ["usage", "用量"],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              className={`${styles.tab} ${tab === key ? styles.active : ""}`}
              onClick={() => setTab(key)}
            >
              {label}
            </button>
          ))}
        </div>
        {tab === "config" && <ConfigView token="" />}
        {tab === "prompts" && <PromptsView token="" />}
        {tab === "usage" && <UsageView token="" />}
      </div>
    </div>
  );
}

async function api<T>(path: string, token: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
  const res = await fetch(`${API_BASE}${path}`, { ...init, headers, credentials: "same-origin" });
  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const body = await res.json();
      message = body?.error ?? message;
    } catch {
      /* ignore */
    }
    throw new Error(message);
  }
  return (await res.json()) as T;
}

function LoginView({ onLogin }: { onLogin: () => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    setError("");
    try {
      await api<{ expiresAt: string }>("/admin/login", "", {
        method: "POST",
        body: JSON.stringify({ username, password }),
      });
      onLogin();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={styles.shell}>
      <div className={styles.inner}>
        <div className={styles.brand} style={{ marginBottom: 24 }}>
          Interstellar <em>· 管理员后台</em>
        </div>
        <div className={styles.card} style={{ maxWidth: 380 }}>
          <label className={styles.label}>用户名</label>
          <input className={styles.input} style={{ width: "100%" }} value={username} onChange={(e) => setUsername(e.target.value)} />
          <label className={styles.label}>密码</label>
          <input
            className={styles.input}
            style={{ width: "100%" }}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && submit()}
          />
          {error && <div className={`${styles.status} ${styles.err}`}>{error}</div>}
          <div style={{ marginTop: 16 }}>
            <button className={`${styles.btn} ${styles.primary}`} disabled={busy} onClick={submit}>
              {busy ? "登录中…" : "登录"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function ConfigView({ token }: { token: string }) {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, { label: string; base_url: string; api_key: string; default_model: string; enabled: boolean; is_default: boolean }>>({});
  const [models, setModels] = useState<Record<string, string[]>>({});

  const load = useCallback(async () => {
    try {
      const result = await api<{ providers: Provider[] }>("/admin/providers", token);
      setProviders(result.providers);
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    }
  }, [token]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data loading on mount
    void load();
  }, [load]);

  function draftOf(p: Provider) {
    return (
      drafts[p.id] ?? {
        label: p.label,
        base_url: p.base_url,
        api_key: "",
        default_model: p.default_model,
        enabled: p.enabled,
        is_default: p.is_default,
      }
    );
  }

  async function saveProvider(p: Provider) {
    setBusyId(p.id);
    setMessage(null);
    try {
      const d = draftOf(p);
      await api("/admin/providers", token, {
        method: "PUT",
        body: JSON.stringify({ id: p.id, label: d.label, base_url: d.base_url, api_key: d.api_key, default_model: d.default_model, enabled: d.enabled, is_default: d.is_default }),
      });
      setDrafts((prev) => ({ ...prev, [p.id]: { ...d, api_key: "" } }));
      setMessage({ ok: true, text: `已保存 ${p.id}` });
      await load();
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusyId(null);
    }
  }

  async function fetchModels(p: Provider) {
    setBusyId(p.id);
    setMessage(null);
    try {
      const result = await api<{ models: { id: string }[] }>(`/admin/providers/${p.id}/models`, token);
      setModels((prev) => ({ ...prev, [p.id]: result.models.map((m) => m.id) }));
      setMessage({ ok: true, text: `已拉取 ${p.id} 的模型列表（${result.models.length} 个）` });
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusyId(null);
    }
  }

  async function testProvider(p: Provider) {
    setBusyId(p.id);
    setMessage(null);
    try {
      await api(`/admin/providers/${p.id}/test`, token, { method: "POST" });
      setMessage({ ok: true, text: `${p.id} 连接正常` });
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusyId(null);
    }
  }

  async function addProvider() {
    const id = prompt("Provider ID（如 default / deepseek / openai / moonshot）");
    if (!id) return;
    const p: Provider = { id, label: id, base_url: "https://api.deepseek.com", api_key_set: false, default_model: "", enabled: true, is_default: false };
    setDrafts((prev) => ({ ...prev, [id]: { label: id, base_url: "https://api.deepseek.com", api_key: "", default_model: "", enabled: true, is_default: false } }));
    setProviders((prev) => [...prev, p]);
  }

  async function removeProvider(p: Provider) {
    if (!confirm(`删除 ${p.id}？`)) return;
    try {
      await api(`/admin/providers/${p.id}`, token, { method: "DELETE" });
      setProviders((prev) => prev.filter((x) => x.id !== p.id));
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    }
  }

  return (
    <div>
      <div className={styles.hint} style={{ marginBottom: 14 }}>
        填写企业（provider）与 API Key 后，点击「拉取模型」获取该企业的模型列表，再选择默认生成模型（例如 DeepSeek V4 Flash）。保存后 App 端即可正常生成卡片简介与整盘报告。
      </div>
      {message && <div className={`${styles.status} ${message.ok ? styles.ok : styles.err}`}>{message.text}</div>}
      {providers.map((p) => {
        const d = draftOf(p);
        return (
          <div className={styles.card} key={p.id}>
            <div className={styles.row}>
              <strong>{p.id}</strong>
              <span className={styles.hint}>{p.api_key_set ? "已配置 Key" : "未配置 Key"}</span>
              <span className={styles.hint}>{p.enabled ? "启用" : "停用"}</span>
              {p.is_default && <span className={styles.hint}>当前默认</span>}
            </div>
            <label className={styles.label}>名称</label>
            <input className={styles.input} value={d.label} onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, label: e.target.value } }))} />
            <label className={styles.label}>Base URL（OpenAI 兼容）</label>
            <input className={styles.input} style={{ minWidth: 300 }} value={d.base_url} onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, base_url: e.target.value } }))} />
            <label className={styles.label}>API Key（留空表示不修改）</label>
            <input
              className={styles.input}
              style={{ minWidth: 300 }}
              type="password"
              placeholder={p.api_key_set ? "已保存，输入新 Key 可替换" : "输入 API Key"}
              value={d.api_key}
              onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, api_key: e.target.value } }))}
            />
            <label className={styles.label}>默认生成模型</label>
            <input className={styles.input} value={d.default_model} placeholder="如 deepseek-v4-flash" onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, default_model: e.target.value } }))} />
            {(models[p.id] ?? []).length > 0 && (
              <div className={styles.modelList}>
                {models[p.id].map((model) => (
                  <button
                    key={model}
                    className={`${styles.modelChip} ${d.default_model === model ? styles.selected : ""}`}
                    onClick={() => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, default_model: model } }))}
                  >
                    {model}
                  </button>
                ))}
              </div>
            )}
            <div className={styles.row} style={{ marginTop: 12 }}>
              <label>
                <input
                  type="checkbox"
                  checked={d.enabled}
                  onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, enabled: e.target.checked } }))}
                />{" "}
                启用 Provider
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={d.is_default}
                  disabled={!d.enabled}
                  onChange={(e) => setDrafts((prev) => ({ ...prev, [p.id]: { ...d, is_default: e.target.checked } }))}
                />{" "}
                设为默认 Provider
              </label>
            </div>
            <div className={styles.row} style={{ marginTop: 14 }}>
              <button className={`${styles.btn} ${styles.primary}`} disabled={busyId === p.id} onClick={() => saveProvider(p)}>
                {busyId === p.id ? "保存中…" : "保存"}
              </button>
              <button className={styles.btn} disabled={busyId === p.id} onClick={() => fetchModels(p)}>
                拉取模型
              </button>
              <button className={styles.btn} disabled={busyId === p.id} onClick={() => testProvider(p)}>
                测试连接
              </button>
              <button className={`${styles.btn} ${styles.danger}`} disabled={busyId === p.id} onClick={() => removeProvider(p)}>
                删除
              </button>
            </div>
          </div>
        );
      })}
      <button className={styles.btn} onClick={addProvider}>
        + 添加 Provider
      </button>
    </div>
  );
}

function PromptsView({ token }: { token: string }) {
  const [prompts, setPrompts] = useState<Prompt[]>([]);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const result = await api<{ prompts: Prompt[] }>("/admin/prompts", token);
      setPrompts(result.prompts);
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    }
  }, [token]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data loading on mount
    void load();
  }, [load]);

  async function save(p: Prompt) {
    setBusy(true);
    setMessage(null);
    try {
      await api("/admin/prompts", token, {
        method: "PUT",
        body: JSON.stringify({ scope: p.scope, locale: p.locale, system_prompt: drafts[promptKey(p)] ?? p.system_prompt }),
      });
      setMessage({ ok: true, text: `已保存 ${p.scope} / ${p.locale}` });
      await load();
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  async function restore(p: Prompt) {
    if (!confirm(`恢复 ${p.scope} / ${p.locale} 的默认提示词？`)) return;
    setBusy(true);
    try {
      await api(`/admin/prompts/${p.scope}/${p.locale}/restore`, token, { method: "POST" });
      setMessage({ ok: true, text: `已恢复默认 ${p.scope} / ${p.locale}` });
      await load();
    } catch (e) {
      setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) });
    } finally {
      setBusy(false);
    }
  }

  const locales: Array<"zh-Hans" | "en"> = ["zh-Hans", "en"];
  const scopes = prompts.reduce<string[]>((acc, p) => (acc.includes(p.scope) ? acc : [...acc, p.scope]), []);

  return (
    <div>
      <div className={styles.hint} style={{ marginBottom: 14 }}>
        提示词由服务器（Go relay）在转发时注入，客户端只传计算事实。修改后立即生效（内存缓存带版本号刷新）。安全边界为固定层，不会被替换。
      </div>
      {message && <div className={`${styles.status} ${message.ok ? styles.ok : styles.err}`}>{message.text}</div>}
      {scopes.map((scope) => (
        <div className={styles.card} key={scope}>
          <strong>{scope}</strong>
          {locales.map((locale) => {
            const p = prompts.find((x) => x.scope === scope && x.locale === locale);
            if (!p) return null;
            return (
              <div key={locale}>
                <label className={styles.label}>
                  {locale} · v{p.version}
                </label>
                <textarea
                  className={styles.textarea}
                  value={drafts[promptKey(p)] ?? p.system_prompt}
                  onChange={(e) => setDrafts((prev) => ({ ...prev, [promptKey(p)]: e.target.value }))}
                />
                <div className={styles.row}>
                  <button className={`${styles.btn} ${styles.primary}`} disabled={busy} onClick={() => save(p)}>
                    保存
                  </button>
                  <button className={styles.btn} disabled={busy} onClick={() => restore(p)}>
                    恢复默认
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ))}
      {scopes.length === 0 && <div className={styles.hint}>暂无提示词模板（服务首次启动时会自动写入默认模板）。</div>}
    </div>
  );
}

function UsageView({ token }: { token: string }) {
  const [rows, setRows] = useState<UsageRow[]>([]);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data loading on mount
    api<{ usage: UsageRow[] }>("/admin/usage", token)
      .then((result) => setRows(result.usage))
      .catch((e) => setMessage({ ok: false, text: e instanceof Error ? e.message : String(e) }));
  }, [token]);

  return (
    <div>
      {message && <div className={`${styles.status} ${message.ok ? styles.ok : styles.err}`}>{message.text}</div>}
      <div className={styles.card}>
        <table>
          <thead>
            <tr>
              <th>日期</th>
              <th>模型</th>
              <th>请求数</th>
              <th>成功率</th>
              <th>输入 tokens</th>
              <th>输出 tokens</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.day}>
                <td>{row.day}</td>
                <td>{row.model}</td>
                <td>{row.requests}</td>
                <td>{Math.round(row.success_rate * 100)}%</td>
                <td>{row.prompt_tokens}</td>
                <td>{row.completion_tokens}</td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td colSpan={6} style={{ color: "#9aa0b5" }}>
                  暂无数据
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
