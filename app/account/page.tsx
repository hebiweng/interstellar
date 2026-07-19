"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";

import { PortalShell } from "../components/portal-shell";
import {
  getAccountWorkspace,
  logoutAccount,
  setAccountSampleVisibility,
  setDefaultAccountPerson,
  type AccountWorkspace,
} from "../lib/account-workspace";
import styles from "./account.module.css";

function formatDate(value?: string | null) {
  if (!value) return "尚未计算";
  const date = new Date(value);
  return Number.isNaN(date.valueOf())
    ? value
    : new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

export default function AccountPage() {
  const [workspace, setWorkspace] = useState<AccountWorkspace | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setWorkspace(await getAccountWorkspace());
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "账户信息读取失败。");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    queueMicrotask(() => void load());
  }, [load]);

  async function changeDefault(personId: string) {
    setBusy(true);
    setMessage("");
    try {
      await setDefaultAccountPerson(personId || null);
      await load();
      setMessage(personId ? "默认人物已更新。" : "已取消默认人物。工作台将按示例人物、最近新增人物的顺序打开。");
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "默认人物更新失败。");
    } finally {
      setBusy(false);
    }
  }

  async function changeSampleVisibility(visible: boolean) {
    setBusy(true);
    setMessage("");
    try {
      await setAccountSampleVisibility(visible);
      await load();
      setMessage(visible ? "示例人物“阿特拉斯”已恢复。" : "示例人物“阿特拉斯”已隐藏。");
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "示例人物设置失败。");
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    setBusy(true);
    try {
      await logoutAccount();
      window.location.href = "/";
    } finally {
      setBusy(false);
    }
  }

  return (
    <PortalShell
      active="account"
      eyebrow="Account · Privacy · Preferences"
      title="账户中心"
      description="管理账户摘要、工作台默认人物和示例偏好。人物资料、计算与删除操作仍集中在独立对象库。"
    >
      {message && <p className={styles.message} role="status">{message}</p>}
      {loading ? (
        <section className={styles.state}><span>◌</span><h2>正在读取账户</h2></section>
      ) : !workspace?.authenticated ? (
        <section className={styles.state}>
          <span>人</span>
          <h2>当前是游客模式</h2>
          <p>游客可以完成本命计算，但人物、最新结果和 AI 文本不会保存。登录后会进入只属于你的工作区。</p>
          <Link href="/?login=1">登录／注册</Link>
        </section>
      ) : (
        <div className={styles.grid}>
          <section className={styles.card}>
            <header><span>{workspace.user?.displayName?.slice(0, 1) || "人"}</span><div><h2>{workspace.user?.displayName || "未设置昵称"}</h2><p>{workspace.user?.email}</p></div></header>
            <dl>
              <div><dt>账户角色</dt><dd>{workspace.user?.role === "super_admin" ? "超级管理员" : workspace.user?.role === "admin" ? "管理员" : "普通用户"}</dd></div>
              <div><dt>保存人物</dt><dd>{workspace.people.length} 名</dd></div>
              <div><dt>数据隔离</dt><dd>仅当前账户可见</dd></div>
            </dl>
            <div className={styles.actions}><Link href="/objects">进入对象库</Link><button disabled={busy} type="button" onClick={() => void signOut()}>退出登录</button></div>
          </section>

          <section className={styles.card}>
            <h2>工作台偏好</h2>
            <label>
              <span>默认人物</span>
              <select disabled={busy} value={workspace.preferences?.defaultPersonId ?? ""} onChange={(event) => void changeDefault(event.target.value)}>
                <option value="">不指定默认人物</option>
                {workspace.people.map((record) => <option key={record.id} value={record.id}>{record.person.displayName}</option>)}
              </select>
              <small>指定后，打开工作台会优先显示该人物；没有本命结果时会提示开始分析。</small>
            </label>
            <label className={styles.switchRow}>
              <input disabled={busy} type="checkbox" checked={workspace.preferences?.sampleVisible !== false} onChange={(event) => void changeSampleVisibility(event.target.checked)} />
              <span><b>显示示例人物“阿特拉斯”</b><small>没有默认人物时，示例人物会先于最近新增人物展示。</small></span>
            </label>
          </section>

          <section className={`${styles.card} ${styles.recent}`}>
            <div className={styles.sectionTitle}><div><h2>最近新增人物</h2><p>按人物创建时间排列，不会因重新计算或修改资料改变顺序。</p></div><Link href="/objects">管理全部</Link></div>
            {workspace.people.length ? <div className={styles.people}>{workspace.people.slice(0, 6).map((record) => (
              <Link key={record.id} href={`/?personId=${encodeURIComponent(record.id)}`}>
                <span>{record.person.displayName.slice(0, 1)}</span>
                <div><b>{record.person.displayName}</b><small>{record.latestNatal ? `最新本命 ${formatDate(record.latestNatal.calculatedAt)}` : "尚未计算本命盘"}</small></div>
                <i>打开</i>
              </Link>
            ))}</div> : <p className={styles.empty}>还没有保存人物。你可以从“新建分析”填写人物并选择保存。</p>}
          </section>
        </div>
      )}
    </PortalShell>
  );
}
