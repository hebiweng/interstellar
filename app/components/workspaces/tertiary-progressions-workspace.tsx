import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import type { NatalCalculationSettings, NatalSnapshot, NatalPersonInput, TertiaryProgressionResult } from '../../lib/interstellar-api';
import type { ThemeMode } from '../lib/chart-types';
import type { WorkspacePerson } from '../../lib/account-workspace';
import { createTertiaryProgression } from '../../lib/interstellar-api';
import { type NatalPointGroups, type NatalPresetId, classicalStarlightPairOrbs, cloneNatalSettings, cloneNatalPointGroups, timingCalculationPresets, identifyTimingPreset } from '../../lib/natal-presets';
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

export function TertiaryProgressionsWorkspace({
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
  const today = new Date().toISOString().slice(0, 10);
  const [targetDate, setTargetDate] = useState(today);
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [groups, setGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [appliedGroups, setAppliedGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedTargetDate, setAppliedTargetDate] = useState<string | null>(null);
  const [result, setResult] = useState<TertiaryProgressionResult | null>(null);
  const [wheelMode, setWheelMode] = useState<"single" | "double">("double");
  const [chartView, setChartView] = useState<"professional" | "compact" | "aspect_grid">("professional");
  const [guideOpen, setGuideOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const tertiaryAutoCalculated = useRef(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [personMenuOpen, setPersonMenuOpen] = useState(false);
  const personMenuRef = useRef<HTMLDivElement>(null);

  const presetId = useMemo(() => identifyTimingPreset(settings, groups), [settings, groups]);
  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({ ...defaultWheelControls, visiblePointIds }), [visiblePointIds]);
  const natalRenderSpec = useMemo(
    () => buildNatalRenderSpec(latestNatalSnapshot, chartView === "compact" ? "compact" : "professional", theme, controls),
    [latestNatalSnapshot, chartView, theme, controls],
  );
  const progressedSnapshot = result?.progressed_snapshot ?? null;
  const comparison = result?.comparison ?? null;
  const progressedRenderSpec = useMemo(
    () => progressedSnapshot ? buildNatalRenderSpec(progressedSnapshot, chartView === "compact" ? "compact" : "professional", theme, controls, "current_sky") : null,
    [progressedSnapshot, chartView, theme, controls],
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
    const preset = timingCalculationPresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  const calculate = useCallback(async (computeTargetDate = targetDate) => {
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
      const calculated = await createTertiaryProgression(
        latestNatalSnapshot,
        person,
        computeTargetDate,
        requestSettings,
      );
      setResult(calculated);
      setAppliedTargetDate(computeTargetDate);
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
      setWheelMode("double");
    } catch {
      /* silent — error displayed via busy state */
    } finally {
      setBusy(false);
    }
  }, [groups, latestNatalSnapshot, person, settings, targetDate]);

  useEffect(() => {
    if (tertiaryAutoCalculated.current) return;
    tertiaryAutoCalculated.current = true;
    const today = new Date().toISOString().slice(0, 10);
    setTargetDate(today);
    queueMicrotask(() => void calculate(today));
  }, [calculate]);

  return <section className="main-workspace secondary-progressions-workspace">
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>TERTIARY PROGRESSIONS</small><h2>三限轮盘</h2></div>
          <div className="panel-tools">
              {chartView === "aspect_grid" ? <button className="view-toggle" onClick={() => setChartView("professional")} title="轮盘"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg></button> : <>
                <button className="view-toggle" onClick={() => setChartView(chartView === "professional" ? "compact" : "professional")} title={chartView === "professional" ? "简洁" : "轮盘"}>{chartView === "professional" ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="2" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="22" y2="12"/></svg>}</button>
                <button className="view-toggle" onClick={() => setChartView("aspect_grid")} title="相位矩阵"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg></button>
              </>}
              {result && <button className="view-toggle" onClick={() => setWheelMode(wheelMode === "single" ? "double" : "single")} title={wheelMode === "single" ? "双盘" : "单盘"}>{wheelMode === "single" ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/></svg> : <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="9"/></svg>}</button>}
              <button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是三限盘？</button>
            </div>
        </div>
        <div className="wheel-canvas-area">
          {progressedSnapshot && comparison ? (
            chartView === "aspect_grid" ? (
              <AspectGrid snapshot={progressedSnapshot} onOpen={() => undefined} />
            ) : wheelMode === "double" ? (
              <ComparisonWheel natalSnapshot={latestNatalSnapshot} movingSnapshot={progressedSnapshot} comparison={comparison} renderSpec={natalRenderSpec} controls={controls} chartLabel="三限盘" movingLabel="三限外层" hideLegend />
            ) : progressedRenderSpec ? (
              <NatalWheel snapshot={progressedSnapshot} renderSpec={progressedRenderSpec} controls={controls} />
            ) : null
          ) : <div className="sky-empty-state"><span>◔</span><h3>三限盘尚未计算</h3><p>三限盘基于"一月对应一日"原理，反映月度级别的心理变化和短期运势波动。选择目标日期后点击计算。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算三限盘"}</button></div>}
        </div>
        <footer><span>{person.displayName} · {person.localDate}</span><span>目标 {appliedTargetDate ?? targetDate}</span><span>{result ? `三限时刻 ${result.progressed_time.replace("T", " ")}` : "一月对应一日"}</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span></footer>
      </article>

      <aside className="settings-panel settings-panel-secondary">
        <div className="settings-title"><div><small>PROGRESSION SETTINGS</small><h2>三限盘参数</h2></div><div className="settings-title-actions"><button className="advanced-settings-trigger" onClick={() => setDrawerOpen(true)}>专业参数</button></div></div>

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
          <label className="secondary-field-label">目标日期<input type="date" min={person.localDate} value={targetDate} onChange={(e) => setTargetDate(e.target.value)} /></label>
          <small className="secondary-field-hint">一月人生对应出生后一日</small>
        </div>

        <div className="preset-shortcuts" aria-label="三限盘预设">{timingCalculationPresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>

        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算三限盘"}</button>

        <p className="settings-boundary">修改目标日期或参数后，需要再次点击计算才会生效。专业参数（黄道制、宫位制、交点类型等）点击上方「专业参数」按钮配置。</p>
      </aside>

      {drawerOpen && <div className="drawer-backdrop" onClick={() => setDrawerOpen(false)}><aside className="settings-drawer" onClick={(e) => e.stopPropagation()}>
        <header className="drawer-header"><h2>三限盘专业参数</h2><button className="drawer-close" onClick={() => setDrawerOpen(false)} aria-label="关闭">×</button></header>
        <div className="drawer-body">
          <p className="sky-person-boundary"><b>固定本命：{person.displayName}</b><span>本命点位与宫位直接读取上一次结果；默认只给三限层加载现代预设。</span></p>
          <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
          <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
          <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
          <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
          <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="三限盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        </div>
        <footer className="drawer-footer"><button className="settings-calculate" disabled={busy} onClick={() => { void calculate(); setDrawerOpen(false); }}>{busy ? "正在计算…" : "应用并计算"}</button></footer>
      </aside></div>}

      <aside className="ai-insight-panel">
        <header><div><small>TERTIARY INSIGHT · LOCAL</small><h2>这一阶段怎么看</h2></div></header>
        <div className="ai-waiting"><b>解读开发中</b><p>三限盘的本地即时解读和 AI 分析功能正在开发中。计算接口就绪后将首先提供本地解读。</p></div>
        <footer><span>本地即时解读</span><small>开发中</small></footer>
      </aside>
    </div>

    <TechniqueGuideDialog open={guideOpen} title="什么是三限盘？" path="/tertiary-progressions-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}
