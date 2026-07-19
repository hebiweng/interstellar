"use client";

import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import Link from "next/link";

import { PortalShell } from "../components/portal-shell";
import {
  deleteAccountPerson,
  getAccountWorkspace,
  saveAccountPerson,
  setAccountSampleVisibility,
  setDefaultAccountPerson,
  type AccountWorkspace,
  type WorkspacePerson,
} from "../lib/account-workspace";
import { searchLocations, type LocationSearchItem, type NatalPersonInput } from "../lib/interstellar-api";
import styles from "./objects.module.css";

type ObjectType = "people" | "relationships" | "events" | "projects" | "organizations" | "locations" | "cases";

const objectTypes: Array<{
  id: ObjectType;
  icon: string;
  label: string;
  description: string;
  available: boolean;
}> = [
  { id: "people", icon: "人", label: "人物", description: "出生资料与最新本命结果", available: true },
  { id: "relationships", icon: "双", label: "关系", description: "双人关系与关系事件", available: false },
  { id: "events", icon: "时", label: "事件", description: "发生时刻与事件盘", available: false },
  { id: "projects", icon: "项", label: "项目", description: "启动时刻与关键节点", available: false },
  { id: "organizations", icon: "组", label: "组织", description: "公司、机构与国家对象", available: false },
  { id: "locations", icon: "地", label: "地点", description: "迁移与地理分析地点", available: false },
  { id: "cases", icon: "问", label: "问题／案例", description: "卜卦问题与研究案例", available: false },
];

const emptyPerson: NatalPersonInput = {
  displayName: "",
  relation: "other",
  localDate: "2000-01-01",
  localTime: "12:00",
  timePrecision: "minute",
  timezoneId: "Asia/Shanghai",
  placeName: "",
  countryCode: "CN",
  latitude: 0,
  longitude: 0,
  timeConfidence: "high",
  timezoneStatus: "unresolved",
};

export default function ObjectsPage() {
  const [activeType, setActiveType] = useState<ObjectType>("people");
  const [workspace, setWorkspace] = useState<AccountWorkspace | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState("");
  const [sampleVisible, setSampleVisible] = useState(true);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState<NatalPersonInput>(emptyPerson);
  const [saving, setSaving] = useState(false);
  const [locationOptions, setLocationOptions] = useState<LocationSearchItem[]>([]);
  const [locationBusy, setLocationBusy] = useState(false);

  const loadWorkspace = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const next = await getAccountWorkspace();
      setWorkspace(next);
      const guestSample = window.localStorage.getItem("interstellar.sampleVisible") !== "false";
      setSampleVisible(next.authenticated ? next.preferences?.sampleVisible !== false : guestSample);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "对象库加载失败，请稍后重试。");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    queueMicrotask(() => void loadWorkspace());
  }, [loadWorkspace]);

  const activeDefinition = useMemo(
    () => objectTypes.find((item) => item.id === activeType) ?? objectTypes[0],
    [activeType],
  );
  const people = workspace?.people ?? [];
  const defaultPersonId = workspace?.preferences?.defaultPersonId ?? null;

  async function removeSample() {
    setActionMessage("");
    try {
      if (workspace?.authenticated) {
        await setAccountSampleVisibility(false);
      } else {
        window.localStorage.setItem("interstellar.sampleVisible", "false");
      }
      setSampleVisible(false);
      setActionMessage("已从对象库移除示例人物。没有默认人物时，工作台会改为打开最近添加的人物。");
      if (workspace?.authenticated) await loadWorkspace();
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "示例人物移除失败。");
    }
  }

  async function restoreSample() {
    setActionMessage("");
    try {
      if (workspace?.authenticated) {
        await setAccountSampleVisibility(true);
      } else {
        window.localStorage.setItem("interstellar.sampleVisible", "true");
      }
      setSampleVisible(true);
      setActionMessage("示例人物“阿特拉斯”已恢复。");
      if (workspace?.authenticated) await loadWorkspace();
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "示例人物恢复失败。");
    }
  }

  async function chooseDefault(record: WorkspacePerson) {
    setActionMessage("");
    try {
      await setDefaultAccountPerson(record.id);
      await loadWorkspace();
      setActionMessage(`已将“${record.person.displayName}”设为工作台默认人物。`);
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "默认人物设置失败。");
    }
  }

  async function clearDefault() {
    setActionMessage("");
    try {
      await setDefaultAccountPerson(null);
      await loadWorkspace();
      setActionMessage("已取消默认人物。工作台将按示例人物、最近添加人物的顺序选择。");
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "默认人物取消失败。");
    }
  }

  async function removePerson(record: WorkspacePerson) {
    if (!window.confirm(`确认删除“${record.person.displayName}”及其最新本命结果吗？`)) return;
    setActionMessage("");
    try {
      await deleteAccountPerson(record.id);
      await loadWorkspace();
      setActionMessage(`已删除“${record.person.displayName}”。`);
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "人物删除失败。");
    }
  }

  function openCreatePerson() {
    if (!workspace?.authenticated) {
      setActionMessage("游客资料不会保存。请先登录或注册，再在对象库建立可长期维护的人物档案。");
      return;
    }
    setEditingId(null);
    setDraft(emptyPerson);
    setLocationOptions([]);
    setEditorOpen(true);
  }

  function openEditPerson(record: WorkspacePerson) {
    setEditingId(record.id);
    setDraft(record.person);
    setLocationOptions([]);
    setEditorOpen(true);
  }

  async function findLocations() {
    const query = draft.placeName.trim();
    if (query.length < 2) {
      setActionMessage("请输入至少两个字符再搜索出生地点。");
      return;
    }
    setLocationBusy(true);
    try {
      setLocationOptions(await searchLocations(query, { limit: 8 }));
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "地点搜索失败，请稍后重试。");
    } finally {
      setLocationBusy(false);
    }
  }

  function chooseLocation(item: LocationSearchItem) {
    setDraft({
      ...draft,
      placeName: item.location.name,
      countryCode: item.location.country_code || draft.countryCode,
      latitude: item.location.latitude,
      longitude: item.location.longitude,
      timezoneId: item.location.timezone_id || draft.timezoneId,
      locationSourceId: item.id,
      timezoneStatus: item.timezone_status,
    });
    setLocationOptions([]);
  }

  async function submitPerson(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!workspace?.authenticated) return;
    if (!draft.displayName.trim() || !draft.placeName.trim()) {
      setActionMessage("请填写人物名称，并从地点搜索结果中确认出生地点。");
      return;
    }
    setSaving(true);
    setActionMessage("");
    try {
      await saveAccountPerson({ ...draft, displayName: draft.displayName.trim() }, editingId ?? undefined);
      setEditorOpen(false);
      await loadWorkspace();
      setActionMessage(editingId ? "人物资料已更新；已有计算结果不会在对象库中自动重算。" : "人物已加入对象库。需要计算时，请回到工作台使用“新建分析”。");
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : "人物资料保存失败。");
    } finally {
      setSaving(false);
    }
  }

  return (
    <PortalShell
      active="objects"
      eyebrow="Object Library · Account Workspace"
      title="对象库"
      description="新增和维护人物、关系、事件、项目与地点等事实资料。对象库不发起计算，也不展示分析入口。"
    >
      <section className={styles.statusBar} aria-live="polite">
        <p>
          {workspace?.authenticated
            ? <><b>{workspace.user?.displayName || workspace.user?.email}</b> 的私有对象库 · 当前保存 {people.length} 名人物</>
            : <><b>游客模式</b> · 可以浏览示例；登录后才能在对象库长期保存和维护人物</>}
        </p>
        {workspace?.authenticated ? <button type="button" onClick={openCreatePerson}>＋ 新建人物</button> : <Link href="/?login=1">登录／注册</Link>}
      </section>
      {actionMessage && <p className={styles.actionMessage} role="status">{actionMessage}</p>}

      <nav className={styles.typeGrid} aria-label="对象类型">
        {objectTypes.map((item) => (
          <button
            key={item.id}
            className={styles.typeButton}
            type="button"
            data-active={activeType === item.id}
            onClick={() => setActiveType(item.id)}
          >
            <span>{item.icon}</span>
            <b>{item.label}</b>
            <small>{item.available ? item.description : `${item.description} · 规划中`}</small>
          </button>
        ))}
      </nav>

      <div className={styles.contentGrid}>
        <section className={styles.panel}>
          <header className={styles.panelHeader}>
            <div>
              <h2>{activeDefinition.label}</h2>
              <p>{activeDefinition.description}</p>
            </div>
            {activeDefinition.available && <button type="button" onClick={openCreatePerson}>＋ 新建人物</button>}
          </header>

          {loading ? (
            <div className={styles.empty}><div><span>◌</span><h3>正在读取对象库</h3><p>读取当前账户可访问的人物与最新本命结果。</p></div></div>
          ) : error ? (
            <div className={styles.error}><div><span>!</span><h3>暂时无法读取对象库</h3><p>{error}</p><button type="button" onClick={() => void loadWorkspace()}>重新加载</button></div></div>
          ) : !activeDefinition.available ? (
            <div className={styles.empty}><div><span>{activeDefinition.icon}</span><h3>{activeDefinition.label}对象正在规划</h3><p>数据类型与页面位置已经预留。开放后，这里只负责新增和维护事实资料，计算仍统一在工作台发起。</p></div></div>
          ) : !sampleVisible && people.length === 0 ? (
            <div className={styles.empty}><div><span>人</span><h3>{workspace?.authenticated ? "还没有保存人物" : "游客对象不会保存"}</h3><p>{workspace?.authenticated ? "先建立人物档案；需要计算时，再到工作台的新建分析中选择这个人物。" : "登录或注册后，才会建立只属于你的对象库。"}</p>{workspace?.authenticated ? <button type="button" onClick={openCreatePerson}>新建人物</button> : <Link href="/?login=1">登录／注册</Link>}</div></div>
          ) : (
            <div className={styles.peopleGrid}>
              {sampleVisible && <article className={`${styles.personCard} ${styles.sampleCard}`}>
                <span className={styles.avatar}>阿</span>
                <div className={styles.personBody}>
                  <div className={styles.personTop}><b>阿特拉斯</b><span>示例人物</span></div>
                  <div className={styles.personMeta}>
                    <span>2000-03-01 16:30</span>
                    <span>北京</span>
                    <span>用于体验本命盘界面，不属于真实人物资料</span>
                  </div>
                  <div className={styles.personActions}>
                    <button type="button" onClick={() => void removeSample()}>删除示例</button>
                  </div>
                </div>
              </article>}
              {people.map((record) => (
                <article className={styles.personCard} key={record.id}>
                  <span className={styles.avatar}>{record.person.displayName.slice(0, 1) || "人"}</span>
                  <div className={styles.personBody}>
                    <div className={styles.personTop}>
                      <b>{record.person.displayName}</b>
                      <span>{defaultPersonId === record.id ? "默认人物" : record.person.relation || "人物"}</span>
                    </div>
                    <div className={styles.personMeta}>
                      <span>{record.person.localDate} {record.person.localTime}</span>
                      <span>{record.person.placeName}</span>
                      <span>{record.latestNatal ? "已有本命结果" : "尚无本命结果"}</span>
                    </div>
                    <div className={styles.personActions}>
                      <button type="button" onClick={() => openEditPerson(record)}>修改资料</button>
                      {workspace?.authenticated && (defaultPersonId === record.id
                        ? <button type="button" onClick={() => void clearDefault()}>取消默认</button>
                        : <button type="button" onClick={() => void chooseDefault(record)}>设为默认</button>)}
                      {workspace?.authenticated && <button type="button" className={styles.dangerAction} onClick={() => void removePerson(record)}>删除</button>}
                    </div>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <aside className={styles.sidePanel}>
          <h2>对象与计算的关系</h2>
          <ol>
            <li>在这里新增和维护出生资料、事件时刻、地点与关系等事实。</li>
            <li>对象库不提供“打开本命”或“重新分析”等计算按钮。</li>
            <li>需要计算时，回到工作台的新建分析中选择已保存对象。</li>
          </ol>
          <p className={styles.sideNote}>人物、关系、事件、项目等对象相互独立，避免把“新增人物”和“新增计算”混成同一个动作。</p>
          {!sampleVisible && <button type="button" className={styles.restoreSample} onClick={() => void restoreSample()}>恢复示例人物“阿特拉斯”</button>}
        </aside>
      </div>

      {editorOpen && <div className={styles.modalBackdrop} onMouseDown={(event) => { if (event.target === event.currentTarget) setEditorOpen(false); }}>
        <form className={styles.personEditor} onSubmit={submitPerson}>
          <header><div><small>PERSON OBJECT</small><h2>{editingId ? "修改人物资料" : "新建人物"}</h2><p>这里只保存人物事实资料，不会自动计算星盘。</p></div><button type="button" onClick={() => setEditorOpen(false)} aria-label="关闭">×</button></header>
          <div className={styles.editorGrid}>
            <label>人物名称<input required value={draft.displayName} onChange={(event) => setDraft({ ...draft, displayName: event.target.value })} placeholder="例如：本人、某位朋友" /></label>
            <label>关系<select value={draft.relation} onChange={(event) => setDraft({ ...draft, relation: event.target.value as NatalPersonInput["relation"] })}><option value="self">本人</option><option value="family">家人</option><option value="partner">伴侣</option><option value="friend">朋友</option><option value="client">客户</option><option value="other">其他</option></select></label>
            <label>出生日期<input required type="date" value={draft.localDate} onChange={(event) => setDraft({ ...draft, localDate: event.target.value })} /></label>
            <label>出生时间<input required type="time" value={draft.localTime} onChange={(event) => setDraft({ ...draft, localTime: event.target.value })} /></label>
            <label>时间精度<select value={draft.timePrecision} onChange={(event) => setDraft({ ...draft, timePrecision: event.target.value as NatalPersonInput["timePrecision"] })}><option value="minute">精确到分钟</option><option value="hour">约到小时</option><option value="date">只知道日期</option><option value="unknown">时间未知</option></select></label>
            <label>时间可信度<select value={draft.timeConfidence} onChange={(event) => setDraft({ ...draft, timeConfidence: event.target.value as NatalPersonInput["timeConfidence"] })}><option value="high">高</option><option value="medium">中</option><option value="low">低</option><option value="unknown">未知</option></select></label>
            <label className={styles.locationField}>出生城市／地区<span><input required value={draft.placeName} onChange={(event) => setDraft({ ...draft, placeName: event.target.value, locationSourceId: undefined, timezoneStatus: "unresolved" })} placeholder="输入后搜索并选择" /><button type="button" disabled={locationBusy} onClick={() => void findLocations()}>{locationBusy ? "搜索中" : "搜索"}</button></span>{locationOptions.length > 0 && <div className={styles.locationOptions}>{locationOptions.map((item) => <button type="button" key={item.id} onClick={() => chooseLocation(item)}><b>{item.label}</b><small>{item.location.latitude.toFixed(4)}, {item.location.longitude.toFixed(4)} · {item.location.timezone_id || "时区待确认"}</small></button>)}</div>}<small>选择地点后自动保存经纬度、国家和 IANA 时区。</small></label>
            <label>IANA 时区<input required value={draft.timezoneId} onChange={(event) => setDraft({ ...draft, timezoneId: event.target.value, timezoneStatus: "manual" })} /></label>
          </div>
          <footer><button type="button" onClick={() => setEditorOpen(false)}>取消</button><button type="submit" disabled={saving}>{saving ? "正在保存…" : "保存人物"}</button></footer>
        </form>
      </div>}
    </PortalShell>
  );
}
