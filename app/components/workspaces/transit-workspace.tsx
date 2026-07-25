import { useState, useEffect, useMemo } from 'react';
import type { NatalCalculationSettings, NatalPointGroups, NatalSnapshot, NatalPersonInput, CurrentSkyInput, ChartComparison } from '../../lib/interstellar-api';
import type { ThemeMode, TransitResultTab } from '../lib/chart-types';
import { createCurrentSkyCalculation, createTransitComparison, InterstellarApiError } from '../../lib/interstellar-api';
import { classicalStarlightPairOrbs } from '../../lib/natal-presets';
import { buildNatalRenderSpec } from '../../lib/render-export';
import type { NatalRenderControls } from '../../lib/render-export';
import {
  cloneNatalSettings, cloneNatalPointGroups, timingCalculationPresets, identifyTimingPreset
} from '../../lib/natal-presets';
import {
  buildTransitConsumerInsight, buildTransitInterpretationSections
} from '../../lib/consumer-insight';
import {
  defaultTimingSettings, defaultTimingGroups, defaultWheelControls,
  houseSystemOptions, fallbackTimezoneOptions,
  pointNames, houseDomains
} from '../lib/chart-constants';
import { effectivePointIds } from '../lib/chart-utils';
import { ComparisonWheel } from '../wheels/comparison-wheel';
import { NatalWheel } from '../wheels/natal-wheel';
import { SharedAdvancedCalculationFields } from '../forms/shared-advanced-calculation-fields';
import { TransitCalculationPanel } from '../panels/transit-calculation-panel';
import { NonNatalInterpretationSection } from '../panels/non-natal-interpretation-section';
import { TechniqueGuideDialog } from '../forms/technique-guide-dialog';

export function TransitWorkspace({
  theme,
  person,
  latestNatalSnapshot,
}: {
  theme: ThemeMode;
  person: NatalPersonInput;
  latestNatalSnapshot: NatalSnapshot;
}) {
  const [input, setInput] = useState<CurrentSkyInput>({
    localDate: "2026-07-23",
    localTime: "12:00",
    timezoneId: person.timezoneId || "Asia/Shanghai",
    placeName: person.placeName || "上海",
    countryCode: person.countryCode || "CN",
    latitude: person.latitude,
    longitude: person.longitude,
  });
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [groups, setGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [appliedGroups, setAppliedGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedInput, setAppliedInput] = useState<CurrentSkyInput | null>(null);
  const [movingLayer, setMovingLayer] = useState<NatalSnapshot | null>(null);
  const [comparison, setComparison] = useState<ChartComparison | null>(null);
  const [wheelMode, setWheelMode] = useState<"single" | "double">("double");
  const [guideOpen, setGuideOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState(`选择目标时刻后点击计算；行运盘会把当时的天空与${person.displayName}的本命盘比较。`);
  const [resultTab, setResultTab] = useState<TransitResultTab>("overview");
  const [showCalculationResults, setShowCalculationResults] = useState(false);
  const presetId = useMemo(() => identifyTimingPreset(settings, groups), [settings, groups]);
  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({ ...defaultWheelControls, visiblePointIds }), [visiblePointIds]);
  const renderSpec = useMemo(
    () => buildNatalRenderSpec(latestNatalSnapshot, "professional", theme, controls),
    [latestNatalSnapshot, theme, controls],
  );
  const movingRenderSpec = useMemo(
    () => movingLayer ? buildNatalRenderSpec(movingLayer, "professional", theme, controls, "current_sky") : null,
    [movingLayer, theme, controls],
  );
  const transitInsight = useMemo(
    () => comparison && movingLayer ? buildTransitConsumerInsight(comparison, latestNatalSnapshot, movingLayer) : null,
    [comparison, latestNatalSnapshot, movingLayer],
  );

  useEffect(() => {
    const parts = new Intl.DateTimeFormat("sv-SE", {
      timeZone: person.timezoneId || "Asia/Shanghai",
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
  }, [person.timezoneId]);

  function applyPreset(id: Exclude<NatalPresetId, "custom">) {
    const preset = timingCalculationPresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  async function calculate(computeInput = input) {
    if (person.timePrecision === "date" || person.timePrecision === "unknown") {
      setNotice("行运盘需要可靠的出生时刻来确定本命宫位和四轴；当前人物只有日期，不能用午夜代替。");
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
    setNotice("正在同时计算本命固定层和目标时刻天象层，然后检查跨盘相位与落宫…");
    try {
      const sky = await createCurrentSkyCalculation(computeInput, requestSettings);
      const compared = await createTransitComparison(latestNatalSnapshot, sky.snapshot.id, requestSettings);
      setMovingLayer(sky.snapshot);
      setComparison(compared);
      setAppliedInput({ ...input });
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
      setWheelMode("double");
      setResultTab("overview");
      setNotice("行运盘已更新。修改日期、地点或参数后，需要再次点击计算才会生效。");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : `行运盘计算失败：${error instanceof Error ? error.message : "未知错误"}`);
    } finally {
      setBusy(false);
    }
  }

  const strongest = comparison ? [...comparison.result.cross_aspects].sort((left, right) => right.strength - left.strength).slice(0, 4) : [];
  const houseHighlights = comparison ? comparison.result.moving_points_in_reference_houses.filter((item) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(item.moving_point_id)) : [];

  return <section className="main-workspace transit-workspace">
    {notice && <div className="app-toast" role="status"><p>{notice}</p><button onClick={() => setNotice("")} aria-label="关闭提示">×</button></div>}
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading"><div className="wheel-heading-main"><div><small>TRANSITS · NATAL + CURRENT SKY</small><h2>{person.displayName}的行运盘</h2></div><div className="wheel-heading-actions">{comparison && <><button className="result-flip-button" onClick={() => setShowCalculationResults(true)}>查看结果</button><div className="view-switcher" aria-label="行运盘单双盘切换"><button className={wheelMode === "single" ? "active" : ""} onClick={() => setWheelMode("single")}>单盘</button><button className={wheelMode === "double" ? "active" : ""} onClick={() => setWheelMode("double")}>双盘</button></div></>}<button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是行运盘？</button></div></div><div className="chart-selector-bar"><label>目标日期<input type="date" value={input.localDate} onChange={(event) => setInput({ ...input, localDate: event.target.value })} /></label><label>目标时间<input type="time" value={input.localTime} onChange={(event) => setInput({ ...input, localTime: event.target.value })} /></label><label>行运地点<input value={input.placeName} onChange={(event) => setInput({ ...input, placeName: event.target.value })} /></label><label>IANA 时区<select value={input.timezoneId} onChange={(event) => setInput({ ...input, timezoneId: event.target.value })}>{fallbackTimezoneOptions.map((timezone) => <option key={timezone}>{timezone}</option>)}</select></label><small>选择目标时刻与地点，行运盘会把当时的天空与当前本命盘比较。</small></div></div>
        {showCalculationResults ? (
          <TransitCalculationPanel comparison={comparison} movingLayer={movingLayer} resultTab={resultTab} setResultTab={setResultTab} onBack={() => setShowCalculationResults(false)} />
        ) : (
          <>
            <div className="wheel-canvas-area">{movingLayer && comparison ? wheelMode === "double" ? <ComparisonWheel natalSnapshot={latestNatalSnapshot} movingSnapshot={movingLayer} comparison={comparison} renderSpec={renderSpec} controls={controls} chartLabel="行运盘" movingLabel="行运外层" /> : movingRenderSpec ? <NatalWheel snapshot={movingLayer} renderSpec={movingRenderSpec} controls={controls} /> : null : <div className="sky-empty-state"><span>◎</span><h3>行运盘尚未计算</h3><p>会直接读取当前人物上一次本命计算结果，再叠加现代预设的目标时刻天空。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算行运盘"}</button></div>}</div>
            <footer><span>{person.displayName} · {person.localDate}</span><span>目标 {(appliedInput ?? input).localDate} {(appliedInput ?? input).localTime}</span><span>{(appliedInput ?? input).placeName}</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span></footer>
          </>
        )}
      </article>

      <aside className="settings-panel">
        <div className="settings-title"><div><small>TRANSIT SETTINGS</small><h2>行运盘参数</h2></div><div className="settings-title-actions"><span className="settings-title-status">双盘</span><button className="settings-header-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算"}</button></div></div>
        <div className="preset-shortcuts" aria-label="行运盘预设">{timingCalculationPresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>
        <p className="sky-person-boundary"><b>当前人物：{person.displayName}</b><span>本命盘固定不动；日期和地点只改变外层的行运天空。</span></p>

        <details className="advanced-location"><summary>行运地点经纬度</summary><div><label>纬度<input type="number" step="0.0001" value={input.latitude} onChange={(event) => setInput({ ...input, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={input.longitude} onChange={(event) => setInput({ ...input, longitude: Number(event.target.value) })} /></label></div></details>
        <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
        <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
        <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
        <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
        <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="行运盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "正在计算…" : "按当前参数重新计算"}</button>
      </aside>

      <aside className="ai-insight-panel">
        <header><div><small>TRANSIT INSIGHT · LOCAL</small><h2>这段时间怎么看</h2></div></header>
        {transitInsight ? <article className="instant-insight"><section className="instant-theme"><span>行运重点</span><h3>{transitInsight.title}</h3><p>{transitInsight.summary}</p></section><section className="insight-dimensions">{transitInsight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section><section className="aspect-balance"><header><b>顺势的地方与容易卡住的地方</b></header><div><span className="supportive" style={{ flex: transitInsight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: transitInsight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: transitInsight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {transitInsight.aspectBalance.supportive}</span><span>需要协调 {transitInsight.aspectBalance.tension}</span><span>彼此相连 {transitInsight.aspectBalance.neutral}</span></footer><p>{transitInsight.aspectBalance.meaning}</p></section><section className="top-signals"><header><b>最明显的行运触发</b><small>数字越高，当前关系越紧密</small></header>{transitInsight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>)}</section><section className="insight-advice"><div><b>行运行星落到本命哪里</b>{houseHighlights.slice(0, 5).map((item) => <p key={item.moving_point_id}>• {pointNames[item.moving_point_id] ?? item.moving_point_id}落入本命第{item.reference_house}宫：近期更容易把注意力带到“{houseDomains[item.reference_house - 1]}”。</p>)}</div><div><b>怎么使用</b><p>• 先看最紧密、正在接近的关系，再看它落入哪个生活领域。</p><p>• 不要把单个相位当作事件结论，要结合现实处境和自己的选择。</p></div></section><section className="insight-closing"><b>最后提醒</b><p>{transitInsight.closing}</p></section></article> : <div className="ai-waiting"><b>等待计算</b><p>计算完成后会立刻说明哪些本命主题被触动、落入哪些生活领域，不调用大模型。</p></div>}
        <footer><span>本地即时解读</span><small>只有点击计算才会更新；修改参数不会自动提交。</small></footer>
      </aside>
    </div>

    {comparison && movingLayer && <NonNatalInterpretationSection insight={transitInsight} sections={buildTransitInterpretationSections(comparison, movingLayer)} />}
    <TechniqueGuideDialog open={guideOpen} title="什么是行运盘？" path="/transit-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}
