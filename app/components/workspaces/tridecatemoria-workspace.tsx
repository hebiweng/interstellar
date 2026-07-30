import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import type { NatalCalculationSettings, NatalSnapshot, NatalPersonInput, HarmonicChartResult } from '../../lib/interstellar-api';
import type { ThemeMode } from '../lib/chart-types';
import type { WorkspacePerson } from '../../lib/account-workspace';
import { createTridecatemoria } from '../../lib/interstellar-api';
import { type NatalPointGroups, type NatalPresetId, classicalStarlightPairOrbs, cloneNatalSettings, cloneNatalPointGroups, natalCalculationPresets, identifyNatalPreset, timingCalculationPresets, identifyTimingPreset } from '../../lib/natal-presets';
import { buildNatalRenderSpec } from '../../lib/render-export';
import type { NatalRenderControls } from '../../lib/render-export';
import {
  defaultTimingSettings, defaultTimingGroups, defaultWheelControls,
  houseSystemOptions,
} from '../lib/chart-constants';
import { effectivePointIds } from '../lib/chart-utils';
import { ComparisonWheel } from '../wheels/comparison-wheel';
import { NatalWheel } from '../wheels/natal-wheel';
import { AspectGrid } from '../wheels/aspect-grid';
import { SharedAdvancedCalculationFields } from '../forms/shared-advanced-calculation-fields';
import { TechniqueGuideDialog } from '../forms/technique-guide-dialog';
import '../../styles/secondary.css';

export function TridecatemoriaWorkspace({
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
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [groups, setGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [appliedGroups, setAppliedGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [result, setResult] = useState<HarmonicChartResult | null>(null);
  const [wheelMode, setWheelMode] = useState<"single" | "double">("double");
  const [chartView, setChartView] = useState<"professional" | "compact" | "aspect_grid">("professional");
  const [guideOpen, setGuideOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const tridecatemoriaAutoCalculated = useRef(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [personMenuOpen, setPersonMenuOpen] = useState(false);
  const personMenuRef = useRef<HTMLDivElement>(null);

  /* 根据轮盘模式动态选择预设族：单盘→A族(natal)，双盘→B族(timing) */
  const activePresets = useMemo(() =>
    wheelMode === "single" ? natalCalculationPresets : timingCalculationPresets,
    [wheelMode]
  );
  const identifyActivePreset = useMemo(() =>
    wheelMode === "single" ? identifyNatalPreset : identifyTimingPreset,
    [wheelMode]
  );
  const presetId = useMemo(() => identifyActivePreset(settings, groups), [settings, groups, identifyActivePreset]);
  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({ ...defaultWheelControls, visiblePointIds }), [visiblePointIds]);
  const natalRenderSpec = useMemo(
    () => buildNatalRenderSpec(latestNatalSnapshot, chartView === "compact" ? "compact" : "professional", theme, controls),
    [latestNatalSnapshot, chartView, theme, controls],
  );
  const harmonicSnapshot = result?.harmonic_snapshot ?? null;
  const comparison = result?.comparison ?? null;
  const harmonicRenderSpec = useMemo(
    () => harmonicSnapshot ? buildNatalRenderSpec(harmonicSnapshot, chartView === "compact" ? "compact" : "professional", theme, controls, "current_sky") : null,
    [harmonicSnapshot, chartView, theme, controls],
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
    const preset = activePresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  /* 切换单/双盘模式时，若当前设置精确匹配某预设则自动切换到对应族 */
  function handleWheelModeToggle() {
    const nextMode = wheelMode === "single" ? "double" : "single";
    const nextPresets = nextMode === "single" ? natalCalculationPresets : timingCalculationPresets;
    const currentPresetId = nextMode === "single"
      ? identifyTimingPreset(settings, groups)
      : identifyNatalPreset(settings, groups);
    if (currentPresetId !== "custom") {
      const target = nextPresets.find((p) => p.id === currentPresetId);
      if (target) {
        setSettings(cloneNatalSettings(target.settings));
        setGroups(cloneNatalPointGroups(target.groups));
      }
    }
    setWheelMode(nextMode);
  }

  const calculate = useCallback(async () => {
    if (person.timePrecision === "date" || person.timePrecision === "unknown") {
      return;
    }
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
      const calculated = await createTridecatemoria(
        latestNatalSnapshot,
        person,
        requestSettings,
      );
      setResult(calculated);
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
      setWheelMode("double");
    } catch {
      /* silent — error displayed via busy state */
    } finally {
      setBusy(false);
    }
  }, [groups, latestNatalSnapshot, person, settings]);

  useEffect(() => {
    if (tridecatemoriaAutoCalculated.current) return;
    tridecatemoriaAutoCalculated.current = true;
    queueMicrotask(() => void calculate());
  }, [calculate]);

  return <section className="main-workspace secondary-progressions-workspace">
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>TRIDECATEMORIA</small><h2>13分轮盘</h2></div>
          <div className="panel-tools">
              {chartView === "aspect_grid" ? <button className="view-toggle" onClick={() => setChartView("professional")} title="轮盘"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg></button> : <>
                <button className="view-toggle" onClick={() => setChartView(chartView === "professional" ? "compact" : "professional")} title={chartView === "professional" ? "简洁" : "轮盘"}>{chartView === "professional" ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg>}</button>
                <button className="view-toggle" onClick={() => setChartView("aspect_grid")} title="相位矩阵"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg></button>
              </>}
              {result && <button className="view-toggle" onClick={handleWheelModeToggle} title={wheelMode === "single" ? "双盘" : "单盘"}>{wheelMode === "single" ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="9"/></svg>}</button>}
              <button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是13分盘？</button>
            </div>
        </div>
        <div className="wheel-canvas-area">
          {harmonicSnapshot && comparison ? (
            chartView === "aspect_grid" ? (
              <AspectGrid snapshot={harmonicSnapshot} onOpen={() => undefined} />
            ) : wheelMode === "double" ? (
              <ComparisonWheel natalSnapshot={latestNatalSnapshot} movingSnapshot={harmonicSnapshot} comparison={comparison} renderSpec={natalRenderSpec} controls={controls} chartLabel="13分盘" movingLabel="13分外层" hideLegend />
            ) : harmonicRenderSpec ? (
              <NatalWheel snapshot={harmonicSnapshot} renderSpec={harmonicRenderSpec} controls={controls} />
            ) : null
          ) : <div className="sky-empty-state"><span>⑬</span><h3>13分盘尚未计算</h3><p>13分盘将每颗行星的黄经乘以13后取模360°，揭示隐藏在行星度数中的更深微信息。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算13分盘"}</button></div>}
        </div>
        <footer><span>{person.displayName} · {person.localDate}</span><span>黄经×13</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span></footer>
      </article>

      <aside className="settings-panel settings-panel-secondary">
        <div className="settings-title"><div><small>TRIDECATEMORIA SETTINGS</small><h2>13分盘参数</h2></div><div className="settings-title-actions"><button className="advanced-settings-trigger" onClick={() => setDrawerOpen(true)}>专业参数</button></div></div>

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
          <small className="secondary-field-hint">13分盘无需额外参数，直接基于本命星体度数计算</small>
        </div>

        <div className="preset-shortcuts" aria-label="13分盘预设">{activePresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>

        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算13分盘"}</button>

        <p className="settings-boundary">修改参数后，需要再次点击计算才会生效。专业参数（黄道制、宫位制、交点类型等）点击上方「专业参数」按钮配置。</p>
      </aside>

      {drawerOpen && <div className="drawer-backdrop" onClick={() => setDrawerOpen(false)}><aside className="settings-drawer" onClick={(e) => e.stopPropagation()}>
        <header className="drawer-header"><h2>13分盘专业参数</h2><button className="drawer-close" onClick={() => setDrawerOpen(false)} aria-label="关闭">×</button></header>
        <div className="drawer-body">
          <p className="sky-person-boundary"><b>固定本命：{person.displayName}</b><span>13分盘基于本命星体度数乘以13后取模计算，无需额外时间或地点参数。</span></p>
          <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
          <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
          <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
          <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
          <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="13分盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        </div>
        <footer className="drawer-footer"><button className="settings-calculate" disabled={busy} onClick={() => { void calculate(); setDrawerOpen(false); }}>{busy ? "正在计算…" : "应用并计算"}</button></footer>
      </aside></div>}

      <aside className="ai-insight-panel">
        <header><div><small>TRIDECATEMORIA INSIGHT · LOCAL</small><h2>更深层的微信息</h2></div></header>
        <div className="ai-waiting"><b>解读开发中</b><p>13分盘的本地即时解读和 AI 分析功能正在开发中。计算接口就绪后将首先提供本地解读。</p></div>
        <footer><span>本地即时解读</span><small>开发中</small></footer>
      </aside>
    </div>

    <TechniqueGuideDialog open={guideOpen} title="什么是13分盘？" path="/tridecatemoria-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}
