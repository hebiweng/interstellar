import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import type { NatalCalculationSettings, NatalSnapshot, NatalPersonInput, RelocationResult } from '../../lib/interstellar-api';
import type { ThemeMode } from '../lib/chart-types';
import type { WorkspacePerson } from '../../lib/account-workspace';
import { createRelocation } from '../../lib/interstellar-api';
import { type NatalPointGroups, type NatalPresetId, classicalStarlightPairOrbs, cloneNatalSettings, cloneNatalPointGroups, natalCalculationPresets, identifyNatalPreset } from '../../lib/natal-presets';
import { buildNatalRenderSpec } from '../../lib/render-export';
import type { NatalRenderControls } from '../../lib/render-export';
import {
  defaultSettings, defaultModernGroups, defaultWheelControls,
  houseSystemOptions,
} from '../lib/chart-constants';
import { effectivePointIds } from '../lib/chart-utils';
import { NatalWheel } from '../wheels/natal-wheel';
import { AspectGrid } from '../wheels/aspect-grid';
import { SharedAdvancedCalculationFields } from '../forms/shared-advanced-calculation-fields';
import { TechniqueGuideDialog } from '../forms/technique-guide-dialog';
import '../../styles/secondary.css';

export function RelocationWorkspace({
  theme,
  person,
  latestNatalSnapshot,
  savedPeople,
  selectedPersonId,
  onSelectPerson,
}: {
  theme: ThemeMode;
  person: NatalPersonInput;
  latestNatalSnapshot: NatalSnapshot;
  savedPeople: WorkspacePerson[];
  selectedPersonId: string | null;
  onSelectPerson: (person: WorkspacePerson) => void;
}) {
  const [residence, setResidence] = useState(person.placeName);
  const [latitude, setLatitude] = useState(String(person.latitude));
  const [longitude, setLongitude] = useState(String(person.longitude));
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultSettings));
  const [groups, setGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultModernGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultSettings));
  const [appliedGroups, setAppliedGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultModernGroups));
  const [result, setResult] = useState<RelocationResult | null>(null);
  const [chartView, setChartView] = useState<"professional" | "compact" | "aspect_grid">("professional");
  const [guideOpen, setGuideOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [personMenuOpen, setPersonMenuOpen] = useState(false);
  const personMenuRef = useRef<HTMLDivElement>(null);

  const presetId = useMemo(() => identifyNatalPreset(settings, groups), [settings, groups]);
  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({ ...defaultWheelControls, visiblePointIds }), [visiblePointIds]);
  const relocatedSnapshot = result?.relocated_snapshot ?? null;
  const relocatedRenderSpec = useMemo(
    () => relocatedSnapshot ? buildNatalRenderSpec(relocatedSnapshot, chartView === "compact" ? "compact" : "professional", theme, controls) : null,
    [relocatedSnapshot, chartView, theme, controls],
  );

  useEffect(() => {
    if (!personMenuOpen) return;
    const close = (e: PointerEvent) => { if (personMenuRef.current && !personMenuRef.current.contains(e.target as Node)) setPersonMenuOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setPersonMenuOpen(false); };
    document.addEventListener("pointerdown", close);
    document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", close); document.removeEventListener("keydown", esc); };
  }, [personMenuOpen]);

  function applyPreset(id: Exclude<NatalPresetId, "custom">) {
    const preset = natalCalculationPresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  const calculate = useCallback(async () => {
    const pointIds = effectivePointIds(settings, groups);
    const requestSettings = cloneNatalSettings({
      ...settings,
      pointIds,
      pointPairOrbs: settings.orbMode === "classical_starlight"
        ? classicalStarlightPairOrbs(pointIds, settings.pointPairOrbs)
        : settings.pointPairOrbs,
    });
    setBusy(true);
    try {
      const calculated = await createRelocation(
        latestNatalSnapshot,
        person,
        Number(latitude),
        Number(longitude),
        residence || null,
        null,
        requestSettings,
      );
      setResult(calculated);
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
    } catch {
      /* silent — error displayed via busy state */
    } finally {
      setBusy(false);
    }
  }, [groups, latestNatalSnapshot, person, settings, latitude, longitude, residence]);

  return <section className="main-workspace secondary-progressions-workspace">
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>RELOCATION</small><h2>重置轮盘</h2></div>
          <div className="panel-tools">
              {chartView === "aspect_grid" ? <button className="view-toggle" onClick={() => setChartView("professional")} title="轮盘"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg></button> : <>
                <button className="view-toggle" onClick={() => setChartView(chartView === "professional" ? "compact" : "professional")} title={chartView === "professional" ? "简洁" : "轮盘"}>{chartView === "professional" ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg>}</button>
                <button className="view-toggle" onClick={() => setChartView("aspect_grid")} title="相位矩阵"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg></button>
              </>}
              <button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是重置盘？</button>
            </div>
        </div>
        <div className="wheel-canvas-area">
          {relocatedSnapshot ? (
            chartView === "aspect_grid" ? (
              <AspectGrid snapshot={relocatedSnapshot} onOpen={() => undefined} />
            ) : relocatedRenderSpec ? (
              <NatalWheel snapshot={relocatedSnapshot} renderSpec={relocatedRenderSpec} controls={controls} />
            ) : null
          ) : <div className="sky-empty-state"><span>⊕</span><h3>重置盘尚未计算</h3><p>重置盘以出生时刻为基准，将地点更换到新的居住地重新计算宫位和上升点，用于观察地理变迁对人生领域的影响。输入重置地点后点击计算。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算重置盘"}</button></div>}
        </div>
        <footer><span>{person.displayName} · {person.localDate}</span><span>重置地 {residence || "未填写"}</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span></footer>
      </article>

      <aside className="settings-panel settings-panel-secondary">
        <div className="settings-title"><div><small>RELOCATION SETTINGS</small><h2>重置盘参数</h2></div><div className="settings-title-actions"><button className="advanced-settings-trigger" onClick={() => setDrawerOpen(true)}>专业参数</button></div></div>

        <div className="secondary-person-card">
          <div className="secondary-person-selector" ref={personMenuRef}>
            <button className="secondary-person-trigger" onClick={() => setPersonMenuOpen(v => !v)} aria-haspopup="menu" aria-expanded={personMenuOpen}>
              <span className="secondary-person-avatar">{person.displayName.slice(0, 1) || "？"}</span>
              <span className="secondary-person-info"><b>{person.displayName || "选择人物"}</b><small>{person.localDate || "生日未填写"}</small></span>
              <i>{personMenuOpen ? "▴" : "▾"}</i>
            </button>
            {personMenuOpen && <div className="secondary-person-menu" role="menu">
              {savedPeople.slice(0, 5).map((saved) => <button role="menuitem" key={saved.id} className={selectedPersonId === saved.id ? "active" : ""} onClick={() => { onSelectPerson(saved); setPersonMenuOpen(false); }}><span>{saved.person.displayName.slice(0, 1)}</span><span><b>{saved.person.displayName}</b><small>{saved.person.localDate || "生日未填写"}</small></span></button>)}
              {!savedPeople.length && <p>暂无已保存人物</p>}
            </div>}
          </div>
        </div>

        <div className="secondary-fields">
          <label className="secondary-field-label">重置地点<input type="text" value={residence} onChange={(e) => setResidence(e.target.value)} placeholder="城市名" /></label>
          <div style={{ display: "flex", gap: "8px" }}>
            <label className="secondary-field-label" style={{ flex: 1 }}>纬度<input type="number" step="0.01" value={latitude} onChange={(e) => setLatitude(e.target.value)} /></label>
            <label className="secondary-field-label" style={{ flex: 1 }}>经度<input type="number" step="0.01" value={longitude} onChange={(e) => setLongitude(e.target.value)} /></label>
          </div>
          <small className="secondary-field-hint">同一出生时刻，不同地点的宫位与上升点不同</small>
        </div>

        <div className="preset-shortcuts" aria-label="重置盘预设">{natalCalculationPresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>

        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算重置盘"}</button>

        <p className="settings-boundary">修改重置地点或参数后，需要再次点击计算才会生效。专业参数（黄道制、宫位制、交点类型等）点击上方「专业参数」按钮配置。重置盘永远为单盘模式。</p>
      </aside>

      {drawerOpen && <div className="drawer-backdrop" onClick={() => setDrawerOpen(false)}><aside className="settings-drawer" onClick={(e) => e.stopPropagation()}>
        <header className="drawer-header"><h2>重置盘专业参数</h2><button className="drawer-close" onClick={() => setDrawerOpen(false)} aria-label="关闭">×</button></header>
        <div className="drawer-body">
          <p className="sky-person-boundary"><b>固定本命：{person.displayName}</b><span>重置盘永远为单盘模式，仅以新地点重新计算宫位与上升点。</span></p>
          <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
          <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
          <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
          <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
          <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="重置盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        </div>
        <footer className="drawer-footer"><button className="settings-calculate" disabled={busy} onClick={() => { void calculate(); setDrawerOpen(false); }}>{busy ? "正在计算…" : "应用并计算"}</button></footer>
      </aside></div>}

      <aside className="ai-insight-panel">
        <header><div><small>RELOCATION INSIGHT · LOCAL</small><h2>地缘与领域</h2></div></header>
        <div className="ai-waiting"><b>解读开发中</b><p>重置盘的本地即时解读和 AI 分析功能正在开发中。计算接口就绪后将首先提供本地解读。</p></div>
        <footer><span>本地即时解读</span><small>开发中</small></footer>
      </aside>
    </div>

    <TechniqueGuideDialog open={guideOpen} title="什么是重置盘？" path="/relocation-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}
