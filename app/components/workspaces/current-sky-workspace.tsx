import { useState, useEffect, useMemo, useRef } from 'react';
import type { NatalCalculationSettings, NatalSnapshot, NatalPersonInput, CurrentSkyInput } from '../../lib/interstellar-api';
import type { NatalPointGroups, NatalPresetId } from '../../lib/natal-presets';
import type { ThemeMode, ChartView } from '../lib/chart-types';
import { createCurrentSkyCalculation, InterstellarApiError } from '../../lib/interstellar-api';
import { classicalStarlightPairOrbs } from '../../lib/natal-presets';
import { buildNatalRenderSpec } from '../../lib/render-export';
import type { NatalRenderControls } from '../../lib/render-export';
import {
  cloneNatalSettings, cloneNatalPointGroups, natalCalculationPresets, identifyNatalPreset
} from '../../lib/natal-presets';
import {
  buildCurrentSkyConsumerInsight, buildCurrentSkyInterpretationSections
} from '../../lib/consumer-insight';
import {
  defaultSettings, defaultModernGroups, defaultWheelControls,
  houseSystemOptions, fallbackTimezoneOptions, currentSkyResultTabs,
  pointNames, aspectNames, houseDomains, pointGroups
} from '../lib/chart-constants';
import { lunarPhaseLabel } from '../lib/chart-labels';
import { asRecord, effectivePointIds } from '../lib/chart-utils';
import { NatalWheel } from '../wheels/natal-wheel';
import { AspectGrid } from '../wheels/aspect-grid';
import { SharedAdvancedCalculationFields } from '../forms/shared-advanced-calculation-fields';
import { CurrentSkyCalculationPanel } from '../panels/current-sky-calculation-panel';
import { NonNatalInterpretationSection } from '../panels/non-natal-interpretation-section';
import { TechniqueGuideDialog } from '../forms/technique-guide-dialog';
import { ConsumerInsightCards } from '../panels/consumer-insight-cards';

export function CurrentSkyWorkspace({ theme }: { theme: ThemeMode }) {
  const [input, setInput] = useState<CurrentSkyInput>({
    localDate: "2026-07-23",
    localTime: "12:00",
    timezoneId: "Asia/Shanghai",
    placeName: "上海",
    countryCode: "CN",
    latitude: 31.2304,
    longitude: 121.4737,
  });
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultSettings));
  const [groups, setGroups] = useState<Record<keyof typeof pointGroups, boolean>>(() => cloneNatalPointGroups(defaultModernGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultSettings));
  const [appliedGroups, setAppliedGroups] = useState<Record<keyof typeof pointGroups, boolean>>(() => cloneNatalPointGroups(defaultModernGroups));
  const [appliedInput, setAppliedInput] = useState<CurrentSkyInput | null>(null);
  const [snapshot, setSnapshot] = useState<NatalSnapshot | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("选择目标时刻与地点后点击计算；天象盘不会读取或叠加任何人物。");
  const [chartView, setChartView] = useState<ChartView>("professional");
  const [guideOpen, setGuideOpen] = useState(false);
  const [resultTab, setResultTab] = useState<CurrentSkyResultTab>("features");
  const [showCalculationResults, setShowCalculationResults] = useState(false);
  const [wheelControls] = useState<Omit<NatalRenderControls, "visiblePointIds">>({ ...defaultWheelControls });
  const presetId = useMemo(() => identifyNatalPreset(settings, groups), [settings, groups]);

  useEffect(() => {
    const parts = new Intl.DateTimeFormat("sv-SE", {
      timeZone: "Asia/Shanghai",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date());
    const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    const nextInput = {
      ...input,
      localDate: `${value.year}-${value.month}-${value.day}`,
      localTime: `${value.hour}:${value.minute}`,
    };
    queueMicrotask(() => {
      setInput(nextInput);
      void calculate(nextInput);
    });
  }, []);

  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({
    ...wheelControls,
    visiblePointIds,
  }), [wheelControls, visiblePointIds]);
  const renderSpec = useMemo(
    () => snapshot ? buildNatalRenderSpec(snapshot, chartView === "compact" ? "compact" : "professional", theme, controls, "current_sky") : null,
    [snapshot, chartView, theme, controls],
  );
  const insight = useMemo(() => snapshot ? buildCurrentSkyConsumerInsight(snapshot) : null, [snapshot]);

  function applyPreset(id: Exclude<NatalPresetId, "custom">) {
    const preset = natalCalculationPresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  async function calculate(computeInput = input) {
    const pointIds = effectivePointIds(settings, groups);
    const requestSettings = cloneNatalSettings({
      ...settings,
      pointIds,
      pointPairOrbs: settings.orbMode === "classical_starlight"
        ? classicalStarlightPairOrbs(pointIds, settings.pointPairOrbs)
        : settings.pointPairOrbs,
    });
    setBusy(true);
    setNotice("正在计算目标时刻的真实天体、宫位、相位与月相…");
    try {
      const result = await createCurrentSkyCalculation(computeInput, requestSettings);
      setSnapshot(result.snapshot);
      setAppliedInput({ ...input });
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
      setChartView("professional");
      setResultTab("features");
      setNotice("天象盘已更新。修改参数不会自动生效，需要再次点击计算。");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : `天象盘计算失败：${error instanceof Error ? error.message : "未知错误"}`);
    } finally {
      setBusy(false);
    }
  }

  const context = snapshot ? asRecord(snapshot.result.astronomical_context) : {};
  const lunarPhase = asRecord(context.lunar_phase);
  const strongestAspects = snapshot ? [...snapshot.result.aspects].sort((left, right) => right.strength - left.strength).slice(0, 5) : [];
  const stationaryPoints = snapshot?.result.points.filter((point) => point.position.motion_state === "stationary") ?? [];
  const retrogradePoints = snapshot?.result.points.filter((point) => point.retrograde) ?? [];

  return <section className="main-workspace current-sky-workspace">
    {notice && <div className="app-toast" role="status"><p>{notice}</p><button onClick={() => setNotice("")} aria-label="关闭提示">×</button></div>}
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading"><div className="wheel-heading-main"><div><small>CURRENT SKY · SINGLE CHART</small><h2>天象盘</h2></div><div className="wheel-heading-actions">{snapshot && <><button className="result-flip-button" onClick={() => setShowCalculationResults(true)}>查看结果</button><div className="view-switcher" aria-label="天象盘视图切换"><button className={chartView === "professional" ? "active" : ""} onClick={() => setChartView("professional")}>轮盘</button><button className={chartView === "compact" ? "active" : ""} onClick={() => setChartView("compact")}>简洁</button><button className={chartView === "aspect_grid" ? "active" : ""} onClick={() => setChartView("aspect_grid")}>相位矩阵</button></div></>}<button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是天象盘？</button></div></div><div className="chart-selector-bar"><label>目标日期<input type="date" value={input.localDate} onChange={(event) => setInput({ ...input, localDate: event.target.value })} /></label><label>目标时间<input type="time" value={input.localTime} onChange={(event) => setInput({ ...input, localTime: event.target.value })} /></label><label>地点<input value={input.placeName} onChange={(event) => setInput({ ...input, placeName: event.target.value })} /></label><label>IANA 时区<select value={input.timezoneId} onChange={(event) => setInput({ ...input, timezoneId: event.target.value })}>{fallbackTimezoneOptions.map((timezone) => <option key={timezone}>{timezone}</option>)}</select></label><small>选择目标时刻与地点，天象盘会即时计算对应的真实天空。</small></div></div>
        {showCalculationResults ? (
          <CurrentSkyCalculationPanel snapshot={snapshot} resultTab={resultTab} setResultTab={setResultTab} onBack={() => setShowCalculationResults(false)} />
        ) : (
          <>
            <div className="wheel-canvas-area">{snapshot && renderSpec ? chartView === "aspect_grid" ? <AspectGrid snapshot={snapshot} onOpen={() => undefined} /> : <NatalWheel snapshot={snapshot} renderSpec={renderSpec} controls={controls} /> : <div className="sky-empty-state"><span>☼</span><h3>天空尚未计算</h3><p>这里始终是一张纯天象单盘，不会叠加人物本命盘。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算当前天象"}</button></div>}</div>
            <footer><span>{(appliedInput ?? input).localDate} {(appliedInput ?? input).localTime}</span><span>{(appliedInput ?? input).placeName}</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span><span>{houseSystemOptions.find((item) => item.id === appliedSettings.houseSystem)?.label}</span></footer>
          </>
        )}
      </article>

      <aside className="settings-panel">
        <div className="settings-title"><div><small>CURRENT SKY SETTINGS</small><h2>天象盘参数</h2></div><div className="settings-title-actions"><span className="settings-title-status">单盘</span><button className="settings-header-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算"}</button></div></div>
        <div className="preset-shortcuts" aria-label="天象盘预设">{natalCalculationPresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>
        <p className="sky-person-boundary"><b>不关联人物</b><span>只计算指定时刻与地点的天空；个人影响请使用行运盘。</span></p>

        <details className="advanced-location"><summary>经纬度</summary><div><label>纬度<input type="number" step="0.0001" value={input.latitude} onChange={(event) => setInput({ ...input, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={input.longitude} onChange={(event) => setInput({ ...input, longitude: Number(event.target.value) })} /></label></div></details>
        <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
        <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
        <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
        <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
        <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="天象盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "正在计算…" : "按当前参数重新计算"}</button>
      </aside>

      <aside className="ai-insight-panel">
        <header><div><small>SKY INSIGHT · LOCAL</small><h2>天象速览</h2></div></header>
        {snapshot && insight ? <article className="instant-insight"><section className="instant-theme"><span>现在的大环境</span><h3>{insight.title}</h3><p>{insight.summary}</p></section><section className="insight-dimensions">{insight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section><section className="aspect-balance"><header><b>顺势的地方与容易卡住的地方</b></header><div><span className="supportive" style={{ flex: insight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: insight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: insight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {insight.aspectBalance.supportive}</span><span>需要协调 {insight.aspectBalance.tension}</span><span>彼此相连 {insight.aspectBalance.neutral}</span></footer><p>{insight.aspectBalance.meaning}</p></section><section className="top-signals"><header><b>最值得留意的三个天象组合</b><small>直接说明它们会带来怎样的节奏</small></header>{insight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>)}</section><section className="insight-advice"><div><b>这时比较适合</b>{insight.strengths.map((item) => <p key={item}>• {item}</p>)}</div><div><b>安排事情时注意</b>{insight.reminders.map((item) => <p key={item}>• {item}</p>)}</div></section><section className="insight-closing"><b>最后提醒</b><p>{insight.closing}</p></section></article> : <div className="ai-waiting"><b>等待计算</b><p>计算完成后会马上用大白话说明这个时段的整体节奏、顺势点和需要注意的地方，不调用大模型。</p></div>}
        <footer><span>{lunarPhase.phase ? `月相：${lunarPhaseLabel(lunarPhase.phase)}` : "纯天象单盘"}</span><small>个人触发、落入本命宫位和跨盘相位将在行运盘中提供。</small></footer>
      </aside>
    </div>

    {snapshot && <NonNatalInterpretationSection insight={insight} sections={buildCurrentSkyInterpretationSections(snapshot)} />}
    <TechniqueGuideDialog open={guideOpen} title="什么是天象盘？" path="/current-sky-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}
