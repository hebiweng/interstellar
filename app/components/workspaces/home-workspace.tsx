"use client";

import { createPortal } from "react-dom";
import { useEffect, useMemo, useRef, useState } from "react";
import dynamic from "next/dynamic";

import {
  createPersonAndNatalCalculation,
  getAiProviders,
  getNatalTechnicalDocument,
  InterstellarApiError,
  previewNatalAiPayload,
  submitNatalToAi,
  type AiProvider,
  type NatalAspect,
  type NatalCalculationSettings,
  type NatalPersonInput,
  type NatalPoint,
  type NatalSnapshot,
} from "../../lib/interstellar-api";
import { submitFeedback, FeedbackApiError } from "../../lib/feedback-api";
import {
  getAccountWorkspace,
  loginAccount,
  logoutAccount,
  registerAccount,
  saveAccountPerson,
  saveLatestAiAnalysis,
  saveLatestNatal,
  setDefaultAccountPerson,
  type AccountWorkspace,
  type WorkspacePerson,
} from "../../lib/account-workspace";
import {
  buildNatalRenderSpec,
  downloadBlob,
  type NatalRenderControls,
} from "../../lib/render-export";
import { recordAnalyticsEvent } from "../../lib/analytics";
import { buildNatalConsumerInsight } from "../../lib/consumer-insight";
import {
  classicalStarlightPairOrbs,
  cloneNatalPointGroups,
  cloneNatalSettings,
  identifyNatalPreset,
  natalCalculationPresets,
  normalizeNatalSettings,
  type NatalPresetId,
} from "../../lib/natal-presets";

import type {
  ResultTab,
  CalculationTab,
  ChartView,
  ThemeMode,
  EntryPointId,
  InterpretationTarget,
} from "../lib/chart-types";
import {
  globalNavigation,
  entryModes,
  chartTechniques,
  calculationResultTabs,
  houseSystemOptions,
  ayanamsaOptions,
  pointNames,
  pointGlyphs,
  signNames,
  signGlyphs,
  signIds,
  aspectNames,
  pointGroups,
  unavailableVirtualPoints,
  majorAspectIds,
  professionalAspectIds,
  pointGroupLabels,
  orbPointClassOptions,
  orbPointOptions,
  fixedStarOptions,
  allPointGroupsEnabled,
  defaultModernGroups,
  defaultWheelGroups,
  defaultWheelControls,
  allAspectIds,
  houseDomains,
  signStyles,
  solarRelationNames,
  defaultSettings,
  sampleSnapshot,
  defaultPerson,
} from "../lib/chart-constants";
import { aspectPhaseLabel } from "../lib/chart-labels";
import {
  effectivePointIds,
  formatDegree,
  pointPlacementLabel,
  pointHouseLabel,
  pointMotionLabel,
  pointUncertaintyLabel,
  isDateLevelSnapshot,
} from "../lib/chart-utils";
import {
  buildLocalTechnicalDocument,
  SafeMarkdownDocument,
} from "../lib/local-interpretation";

import { NatalWheel } from "../wheels/natal-wheel";
import { AspectGrid } from "../wheels/aspect-grid";
import { TimeDependentUnavailable } from "../results/time-dependent-unavailable";
import { PointResultTable } from "../results/point-result-table";
import { CalculationResults } from "../results/calculation-results";
import { StructureResults } from "../results/structure-results";
import { NatalFeatureResults } from "../results/natal-feature-results";
import { ClassicalResults } from "../results/classical-results";
import { InterpretationDrawer } from "../panels/interpretation-drawer";
import { PersonFields } from "../forms/person-fields";

const CurrentSkyWorkspace = dynamic(() => import("./current-sky-workspace").then((m) => m.CurrentSkyWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载当前天象工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const TransitWorkspace = dynamic(() => import("./transit-workspace").then((m) => m.TransitWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载推运工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const SecondaryProgressionsWorkspace = dynamic(() => import("./secondary-progressions-workspace").then((m) => m.SecondaryProgressionsWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载次限工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const TertiaryProgressionsWorkspace = dynamic(() => import("./tertiary-progressions-workspace").then((m) => m.TertiaryProgressionsWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载三限工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const SolarReturnWorkspace = dynamic(() => import("./solar-return-workspace").then((m) => m.SolarReturnWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载日返工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const LunarReturnWorkspace = dynamic(() => import("./lunar-return-workspace").then((m) => m.LunarReturnWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载月返工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const SolarArcWorkspace = dynamic(() => import("./solar-arc-workspace").then((m) => m.SolarArcWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载日弧工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const RelocationWorkspace = dynamic(() => import("./relocation-workspace").then((m) => m.RelocationWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载重置工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const DodecatemoriaWorkspace = dynamic(() => import("./dodecatemoria-workspace").then((m) => m.DodecatemoriaWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载12分工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const TridecatemoriaWorkspace = dynamic(() => import("./tridecatemoria-workspace").then((m) => m.TridecatemoriaWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载13分工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const FirdariaWorkspace = dynamic(() => import("./firdaria-workspace").then((m) => m.FirdariaWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载法达工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});
const AnnualProfectionsWorkspace = dynamic(() => import("./annual-profections-workspace").then((m) => m.AnnualProfectionsWorkspace), {
  loading: () => <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在加载小限工作台</h1><p>正在准备组件资源。</p></div></section>,
  ssr: false,
});

export function HomeWorkspace() {
  const [activeTechnique, setActiveTechnique] = useState<"natal" | "current_sky" | "transits" | "secondary_progressions" | "tertiary_progressions" | "solar_return" | "lunar_return" | "solar_arc" | "firdaria" | "annual_profections" | "relocation" | "dodecatemoria" | "tridecatemoria">("natal");
  const [snapshot, setSnapshot] = useState<NatalSnapshot>(sampleSnapshot);
  const [subjectName, setSubjectName] = useState("阿特拉斯");
  const [tab, setTab] = useState<ResultTab>("basic");
  const [chartView, setChartView] = useState<ChartView>("professional");
  const [showCalculationResults, setShowCalculationResults] = useState(false);
  const [calculationTab, setCalculationTab] = useState<CalculationTab>("features");
  const [personMenuOpen, setPersonMenuOpen] = useState(false);
  const [natalGuideOpen, setNatalGuideOpen] = useState(false);
  const [natalGuideText, setNatalGuideText] = useState("");
  const [personModal, setPersonModal] = useState(false);
  const [calculationModal, setCalculationModal] = useState(false);
  const [analysisCenterOpen, setAnalysisCenterOpen] = useState(false);
  const [capabilityTarget, setCapabilityTarget] = useState<(typeof chartTechniques)[number] | null>(null);
  const [entryPoint, setEntryPoint] = useState<EntryPointId>("technique");
  // The server and the first browser render must use identical values. Browser
  // preferences are applied after hydration so React never has to reconcile
  // different theme labels/icons or responsive panel state.
  const [theme, setTheme] = useState<ThemeMode>("dark");
  const [person, setPerson] = useState<NatalPersonInput>(defaultPerson);
  const [settings, setSettings] = useState<NatalCalculationSettings>(defaultSettings);
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(defaultSettings);
  const [groups, setGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ ...defaultModernGroups });
  const [appliedGroups, setAppliedGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ ...defaultModernGroups });
  const selectedPresetId = useMemo(
    () => identifyNatalPreset(settings, groups),
    [settings, groups],
  );
  const [wheelGroups, setWheelGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ ...defaultWheelGroups });
  const [wheelControls, setWheelControls] = useState<Omit<NatalRenderControls, "visiblePointIds">>({ ...defaultWheelControls });
  const [saveProfile, setSaveProfile] = useState(false);
  const [setAsDefault, setSetAsDefault] = useState(false);
  const [accountWorkspace, setAccountWorkspace] = useState<AccountWorkspace>({ authenticated: false, user: null, people: [] });
  const [authModal, setAuthModal] = useState<"login" | "register" | null>(null);
  const [authEmail, setAuthEmail] = useState("");
  const [authPassword, setAuthPassword] = useState("");
  const [authDisplayName, setAuthDisplayName] = useState("");
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState("");
  const [savedPeople, setSavedPeople] = useState<WorkspacePerson[]>([]);
  const [selectedPersonId, setSelectedPersonId] = useState<string | null>(null);
  const [workspaceResolved, setWorkspaceResolved] = useState(false);
  const [hasActiveSubject, setHasActiveSubject] = useState(false);
  const [hasActiveSnapshot, setHasActiveSnapshot] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [feedbackOpen, setFeedbackOpen] = useState(false);
  const [feedbackType, setFeedbackType] = useState<"bug" | "feature" | "other">("other");
  const [feedbackContent, setFeedbackContent] = useState("");
  const [feedbackContact, setFeedbackContact] = useState("");
  const [feedbackBusy, setFeedbackBusy] = useState(false);
  const [feedbackNotice, setFeedbackNotice] = useState<string | null>(null);
  const [moreTechniquesOpen, setMoreTechniquesOpen] = useState(false);
  const [moreTechniquesStyle, setMoreTechniquesStyle] = useState<React.CSSProperties>({});
  const moreTechniquesRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!moreTechniquesOpen) return;
    const onPointerDown = (e: PointerEvent) => { if (moreTechniquesRef.current && !moreTechniquesRef.current.contains(e.target as Node)) setMoreTechniquesOpen(false); };
    const onKeyDown = (e: KeyboardEvent) => { if (e.key === "Escape") setMoreTechniquesOpen(false); };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => { document.removeEventListener("pointerdown", onPointerDown); document.removeEventListener("keydown", onKeyDown); };
  }, [moreTechniquesOpen]);
  const [target, setTarget] = useState<InterpretationTarget | null>(null);
  const [technicalDocument, setTechnicalDocument] = useState(() => buildLocalTechnicalDocument(sampleSnapshot, "阿特拉斯"));
  const [technicalDocumentHash, setTechnicalDocumentHash] = useState("虚拟样例 · 未生成服务端内容哈希");
  const [providers, setProviders] = useState<AiProvider[]>([
    { provider_id: "deepseek", label: "DeepSeek", configured: false, availability: "blocked", blocking_reason: "等待服务端配置 DeepSeek API 密钥", models: [{ model_id: "deepseek-v4-pro", label: "DeepSeek V4 Pro", configured: false }] },
    { provider_id: "openai", label: "GPT / OpenAI", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "gpt", label: "GPT（后台指定版本）", configured: false }] },
    { provider_id: "moonshot", label: "Kimi / Moonshot", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "kimi", label: "Kimi（后台指定版本）", configured: false }] },
  ]);
  const [aiSubmitBusy, setAiSubmitBusy] = useState(false);
  const [aiAnalysisText, setAiAnalysisText] = useState("");
  const [analysisMode, setAnalysisMode] = useState<"instant" | "ai">("instant");
  const activeSnapshotIdRef = useRef(snapshot.id);
  const subjectSwitcherRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const storedTheme = window.localStorage.getItem("interstellar.theme");
    queueMicrotask(() => {
      if (storedTheme === "light" || storedTheme === "dark") {
        setTheme(storedTheme);
      }
    });
  }, []);

  useEffect(() => {
    activeSnapshotIdRef.current = snapshot.id;
  }, [snapshot.id]);

  useEffect(() => {
    if (!personMenuOpen) return;
    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (event.target instanceof Node && !subjectSwitcherRef.current?.contains(event.target)) {
        setPersonMenuOpen(false);
      }
    };
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setPersonMenuOpen(false);
    };
    document.addEventListener("pointerdown", closeOnOutsidePointer);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsidePointer);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [personMenuOpen]);

  useEffect(() => {
    if (!moreTechniquesOpen) return;
    const close = (e: PointerEvent) => { if (moreTechniquesRef.current && !moreTechniquesRef.current.contains(e.target as Node)) setMoreTechniquesOpen(false); };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") setMoreTechniquesOpen(false); };
    document.addEventListener("pointerdown", close);
    document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("pointerdown", close); document.removeEventListener("keydown", esc); };
  }, [moreTechniquesOpen]);

  useEffect(() => {
    if (!natalGuideOpen || natalGuideText) return;
    fetch("/what-is-natal-chart.md")
      .then((response) => {
        if (!response.ok) throw new Error("guide unavailable");
        return response.text();
      })
      .then(setNatalGuideText)
      .catch(() => setNatalGuideText("本命盘说明暂时无法载入，请稍后重试。"));
  }, [natalGuideOpen, natalGuideText]);

  useEffect(() => {
    getAccountWorkspace().then((workspace) => {
      setAccountWorkspace(workspace);
      setSavedPeople(workspace.people);
      initializeWorkspace(workspace);
    }).catch(() => {
      const fallback: AccountWorkspace = { authenticated: false, user: null, people: [] };
      setAccountWorkspace(fallback);
      setSavedPeople([]);
      initializeWorkspace(fallback);
    }).finally(() => {
      setWorkspaceResolved(true);
    });
    getAiProviders().then((items) => {
      setProviders(items);
    }).catch(() => undefined);
    recordAnalyticsEvent({ event_name: "page_view", metadata: { page: "workspace", route: "/" } });
  // Workspace selection is intentionally resolved once from the initial URL and session.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  function toggleTheme() {
    const next: ThemeMode = theme === "dark" ? "light" : "dark";
    setTheme(next);
    document.documentElement.dataset.theme = next;
    window.localStorage.setItem("interstellar.theme", next);
  }

  const corePoints = snapshot.result.points.filter((point) => pointGroups.core.includes(point.point_id as never));
  const virtualPointIds = new Set<string>([...pointGroups.angles, ...pointGroups.lunar].filter((id) => !["fortune", "spirit"].includes(id)));
  const lotPointIds = new Set<string>(["fortune", "spirit", ...pointGroups.lots]);
  const asteroidPointIds = new Set<string>(pointGroups.asteroids);
  const hamburgPointIds = new Set<string>(pointGroups.hamburg);
  const virtualPoints = snapshot.result.points.filter((point) => virtualPointIds.has(point.point_id));
  const asteroidPoints = snapshot.result.points.filter((point) => asteroidPointIds.has(point.point_id));
  const hamburgPoints = snapshot.result.points.filter((point) => hamburgPointIds.has(point.point_id));
  const lotPoints = snapshot.result.points.filter((point) => lotPointIds.has(point.point_id));
  const categorizedPointIds = new Set<string>([...pointGroups.core, ...virtualPointIds, ...asteroidPointIds, ...hamburgPointIds, ...lotPointIds]);
  const otherExtendedPoints = snapshot.result.points.filter((point) => !categorizedPointIds.has(point.point_id));
  const signGroups = useMemo(() => signIds.map((sign) => ({ sign, points: snapshot.result.points.filter((point) => point.sign === sign) })).filter((group) => group.points.length), [snapshot]);
  const settingsDirty = JSON.stringify(settings) !== JSON.stringify(appliedSettings) || JSON.stringify(groups) !== JSON.stringify(appliedGroups);
  const dateLevelMode = isDateLevelSnapshot(snapshot);
  const visibleWheelPointIds = useMemo(() => (Object.entries(wheelGroups) as Array<[keyof typeof pointGroups, boolean]>)
    .filter(([, enabled]) => enabled)
    .flatMap(([group]) => [...pointGroups[group]]), [wheelGroups]);
  const effectiveWheelControls = useMemo<NatalRenderControls>(() => ({
    ...wheelControls,
    visiblePointIds: visibleWheelPointIds,
  }), [wheelControls, visibleWheelPointIds]);
  const natalRenderSpec = useMemo(() => buildNatalRenderSpec(
    snapshot,
    chartView === "compact" ? "compact" : "professional",
    theme,
    effectiveWheelControls,
  ), [snapshot, chartView, theme, effectiveWheelControls]);
  const consumerInsight = useMemo(() => buildNatalConsumerInsight(snapshot), [snapshot]);

  function showSampleSubject() {
    setSnapshot(sampleSnapshot);
    setSubjectName("阿特拉斯");
    setPerson({ ...defaultPerson, displayName: "阿特拉斯" });
    setSelectedPersonId(null);
    setSettings({ ...defaultSettings });
    setAppliedSettings({ ...defaultSettings });
    setGroups({ ...allPointGroupsEnabled });
    setAppliedGroups({ ...allPointGroupsEnabled });
    setTechnicalDocument(buildLocalTechnicalDocument(sampleSnapshot, "阿特拉斯"));
    setTechnicalDocumentHash("虚拟样例 · 未生成服务端内容哈希");
    setAiAnalysisText("");
    setAnalysisMode("instant");
    setHasActiveSubject(true);
    setHasActiveSnapshot(true);
  }

  function showEmptyWorkspace() {
    setSelectedPersonId(null);
    setSubjectName("");
    setPerson({ ...defaultPerson, displayName: "" });
    setHasActiveSubject(false);
    setHasActiveSnapshot(false);
  }

  function initializeWorkspace(workspace: AccountWorkspace) {
    const params = new URLSearchParams(window.location.search);
    const requestedPersonId = params.get("personId") ?? params.get("editPersonId");
    const requestedPerson = workspace.people.find((item) => item.id === requestedPersonId);
    const isNewAnalysis = params.get("new-analysis") === "1";
    const wantsEdit = Boolean(params.get("editPersonId"));
    const accountSampleVisible = workspace.authenticated
      ? workspace.preferences?.sampleVisible !== false
      : window.localStorage.getItem("interstellar.sampleVisible") !== "false";
    if (params.get("analysis-center") === "1") setAnalysisCenterOpen(true);
    if (params.get("login") === "1") setAuthModal("login");

    if (params.get("sample") === "1" && accountSampleVisible) {
      showSampleSubject();
      return;
    }

    if (requestedPerson) {
      selectWorkspacePerson(requestedPerson, false);
      if (wantsEdit) {
        setSetAsDefault(workspace.preferences?.defaultPersonId === requestedPerson.id);
        setPersonModal(true);
      }
      if (isNewAnalysis || (!requestedPerson.latestNatal && !wantsEdit)) {
        openNewCalculation("object", requestedPerson.person);
      }
      return;
    }

    const defaultPersonId = workspace.preferences?.defaultPersonId;
    const defaultRecord = defaultPersonId
      ? workspace.people.find((item) => item.id === defaultPersonId)
      : undefined;
    if (defaultRecord) {
      selectWorkspacePerson(defaultRecord, false);
    } else if (accountSampleVisible) {
      showSampleSubject();
    } else if (workspace.people[0]) {
      selectWorkspacePerson(workspace.people[0], false);
    } else {
      showEmptyWorkspace();
    }
    if (isNewAnalysis) openNewCalculation((params.get("entry") as EntryPointId | null) ?? "technique");
  }

  async function refreshWorkspace() {
    const workspace = await getAccountWorkspace();
    setAccountWorkspace(workspace);
    setSavedPeople(workspace.people);
    return workspace;
  }

  async function submitAccount() {
    if (!authModal) return;
    setAuthBusy(true);
    setAuthError("");
    try {
      if (authModal === "register") {
        await registerAccount({
          email: authEmail,
          password: authPassword,
          displayName: authDisplayName,
        });
      } else {
        await loginAccount({ email: authEmail, password: authPassword });
      }
      const workspace = await refreshWorkspace();
      initializeWorkspace(workspace);
      setAuthModal(null);
      setAuthPassword("");
      setNotice(authModal === "register" ? "注册成功，人物与最新本命盘将保存到你的账户。" : "登录成功，已载入你的保存人物。 ");
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "账户操作失败，请稍后再试。 ");
    } finally {
      setAuthBusy(false);
    }
  }

  async function signOut() {
    try {
      await logoutAccount();
    } finally {
      setAccountWorkspace({ authenticated: false, user: null, people: [] });
      setSavedPeople([]);
      setSelectedPersonId(null);
      const guestSampleVisible = window.localStorage.getItem("interstellar.sampleVisible") !== "false";
      if (guestSampleVisible) showSampleSubject(); else showEmptyWorkspace();
      setNotice("已退出登录。当前页面结果仍可查看，但不会继续保存。 ");
    }
  }

  async function savePersonOnly() {
    if (!person.displayName.trim()) { setNotice("请先填写人物名称。 "); return; }
    if (!accountWorkspace.authenticated) {
      setSubjectName(person.displayName);
      setSelectedPersonId(null);
      setHasActiveSubject(true);
      setHasActiveSnapshot(false);
      setPersonModal(false);
      setNotice(`游客人物“${person.displayName}”已用于当前会话，但不会保存。登录／注册后可永久保存。`);
      return;
    }
    try {
      const saved = await saveAccountPerson(person, selectedPersonId ?? undefined);
      setSelectedPersonId(saved.id);
      if (setAsDefault) await setDefaultAccountPerson(saved.id);
      else if (accountWorkspace.preferences?.defaultPersonId === saved.id) await setDefaultAccountPerson(null);
      const workspace = await refreshWorkspace();
      const savedRecord = workspace.people.find((item) => item.id === saved.id);
      if (savedRecord) selectWorkspacePerson(savedRecord, false);
      setNotice(`已保存人物“${person.displayName}”。该资料只对当前登录账户可见。`);
      setSetAsDefault(false);
    } catch (error) {
      setNotice(`人物保存失败：${error instanceof Error ? error.message : "未知错误"}`);
      return;
    }
    setPersonModal(false);
  }

  function selectWorkspacePerson(saved: WorkspacePerson, openWhenMissing = true) {
    setPerson({ ...defaultPerson, ...saved.person });
    setSelectedPersonId(saved.id);
    setSubjectName(saved.person.displayName);
    setHasActiveSubject(true);
    if (!saved.latestNatal) {
      setHasActiveSnapshot(false);
      setNotice(`“${saved.person.displayName}”尚无本命盘历史；已填入新建分析。`);
      if (openWhenMissing) openNewCalculation("technique", saved.person);
      return;
    }
    const latest = saved.latestNatal;
    setSnapshot(latest.snapshot);
    const savedSettings = normalizeNatalSettings(latest.settings);
    setSettings(savedSettings);
    setAppliedSettings(cloneNatalSettings(savedSettings));
    const savedGroups = { ...defaultModernGroups, ...latest.groups } as Record<keyof typeof pointGroups, boolean>;
    setGroups(savedGroups);
    setAppliedGroups(savedGroups);
    setTechnicalDocument(latest.analysisDocument);
    setTechnicalDocumentHash(latest.analysisDocumentHash);
    setAiAnalysisText(latest.aiAnalysisText ?? "");
    setAnalysisMode("instant");
    setTab("basic");
    setChartView("professional");
    setHasActiveSnapshot(true);
    setNotice("");
  }

  function openNewCalculation(selectedEntry: EntryPointId = "technique", selectedPerson?: NatalPersonInput) {
    setEntryPoint(selectedEntry);
    if (selectedPerson) setPerson(selectedPerson);
    setCalculationModal(true);
  }

  function applyNatalPreset(presetId: Exclude<NatalPresetId, "custom">) {
    const preset = natalCalculationPresets.find((item) => item.id === presetId);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  async function calculateNatal() {
    if (!person.displayName.trim()) { setNotice("请先填写人物名称。 "); return; }
    const dateLevelRequested = person.timePrecision === "date" || person.timePrecision === "unknown";
    recordAnalyticsEvent({
      event_name: "analysis_started",
      metadata: { analysis_type: "natal", chart_family: "natal", technique: "natal" },
    });
    setBusy(true); setNotice(dateLevelRequested
      ? "正在计算完整当地日期范围、天体位置区间与跨星座风险；不会伪造出生时刻…"
      : "正在标准化时间、计算星历、宫位、相位、结构与古典事实…");
    const pointIds = effectivePointIds(settings, groups);
    const allGroupsEnabled = Object.values(groups).every(Boolean);
    try {
      const effectivePointIds = allGroupsEnabled && settings.nodeType === "both" && settings.disabledPointIds.length === 0 ? [] : pointIds;
      const requestSettings = cloneNatalSettings({
        ...settings,
        pointIds: effectivePointIds,
        pointPairOrbs: settings.orbMode === "classical_starlight"
          ? classicalStarlightPairOrbs(pointIds, settings.pointPairOrbs)
          : settings.pointPairOrbs,
      });
      const result = await createPersonAndNatalCalculation(person, requestSettings);
      setSnapshot(result.snapshot); setSubjectName(person.displayName); setHasActiveSubject(true); setHasActiveSnapshot(true); setAppliedSettings(cloneNatalSettings(settings)); setAppliedGroups({ ...groups }); setCalculationModal(false); setTab(settings.analysisSystem === "classical" ? "classical" : "basic"); setChartView("professional");
      const document = await getNatalTechnicalDocument(result.snapshot.id, "plaintext");
      setTechnicalDocument(document.content);
      setTechnicalDocumentHash(document.contentHash);
      setAiAnalysisText("");
      setAnalysisMode("instant");
      if (accountWorkspace.authenticated && (selectedPersonId || saveProfile)) {
        const saved = await saveAccountPerson(person, selectedPersonId ?? undefined);
        setSelectedPersonId(saved.id);
        if (setAsDefault) await setDefaultAccountPerson(saved.id);
        await saveLatestNatal({
          personId: saved.id,
          snapshot: result.snapshot,
          settings: { ...settings },
          groups: { ...groups },
          analysisDocument: document.content,
          analysisDocumentHash: document.contentHash,
          aiAnalysisText: null,
          aiModelId: null,
        });
        await refreshWorkspace();
        setSetAsDefault(false);
      }
      const persistenceNote = accountWorkspace.authenticated && (selectedPersonId || saveProfile)
        ? "已覆盖保存为该人物最新一次结果。"
        : accountWorkspace.authenticated
          ? "本次临时结果未保存。"
          : "游客结果不会保存。";
      setNotice((isDateLevelSnapshot(result.snapshot)
        ? `已生成日期级参考结果：${result.snapshot.result.points.length} 个天体位置范围；需要出生时刻的内容暂不计算。`
        : `已完成本命盘计算：${result.snapshot.result.points.length} 个点位、${result.snapshot.result.aspects.length} 条相位。`) + persistenceNote);
    } catch (error) {
      const message = error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "本命盘计算失败。";
      setNotice(message);
    } finally { setBusy(false); }
  }

  async function copyTechnical() {
    try {
      await navigator.clipboard.writeText(technicalDocument);
      setNotice(`已复制本命盘分析数据（${new Blob([technicalDocument]).size} 字节）。`);
      recordAnalyticsEvent({ event_name: "report_generated", success: true, metadata: { analysis_type: "natal", export_format: "clipboard" } });
    } catch {
      setNotice("浏览器未允许剪贴板访问；文档仍保留在页面中，可手动全选或使用下载按钮。");
    }
  }

  async function downloadTechnical() {
    try {
      const artifact = snapshot.id.startsWith("calculation-")
        ? await getNatalTechnicalDocument(snapshot.id, "plaintext")
        : {
          content: technicalDocument.replace(/^#+\s*/gm, ""),
          contentHash: technicalDocumentHash,
        };
      if (snapshot.id.startsWith("calculation-") && artifact.contentHash !== technicalDocumentHash) {
        throw new Error("下载内容与当前页面的分析数据校验值不一致");
      }
      downloadBlob(
        new Blob([artifact.content], { type: "text/plain;charset=utf-8" }),
        `${subjectName}-本命盘分析数据.txt`,
      );
      setNotice(`已导出本命盘分析纯文本文档（${new Blob([artifact.content]).size} 字节）。`);
    } catch (error) {
      setNotice(`分析数据导出失败：${error instanceof Error ? error.message : "未知错误"}`);
    }
  }

  async function refreshAiAnalysis() {
    setAnalysisMode("ai");
    if (settingsDirty) {
      setNotice("存在尚未应用的参数，请先点击左侧“按当前参数重新计算”。");
      return;
    }
    if (!snapshot.id.startsWith("calculation-")) {
      setNotice("请先生成真实本命盘，再刷新 DeepSeek 分析。");
      return;
    }
    const deepseek = providers.find((provider) => provider.provider_id === "deepseek");
    const deepseekModel = deepseek?.models.find((model) => model.configured) ?? deepseek?.models[0];
    if (!deepseek?.configured || !deepseekModel) {
      setNotice(deepseek?.blocking_reason ?? "DeepSeek 尚未在服务端配置。");
      return;
    }
    const submittedSnapshotId = snapshot.id;
    const submittedPersonId = selectedPersonId;
    setAiSubmitBusy(true);
    setNotice("DeepSeek 正在分析当前已计算的本命盘…");
    try {
      const preview = await previewNatalAiPayload({
        snapshotId: submittedSnapshotId,
        snapshot: snapshot,
        providerId: "deepseek",
        modelId: deepseekModel.model_id,
        focus: "",
        storeResponse: accountWorkspace.authenticated && Boolean(submittedPersonId),
      });
      const artifact = await submitNatalToAi({
        snapshotId: submittedSnapshotId,
        snapshot: snapshot,
        providerId: "deepseek",
        modelId: deepseekModel.model_id,
        focus: "",
        consent: true,
        payloadHash: preview.payload_hash,
        authorityForSubjectData: true,
        storeResponse: accountWorkspace.authenticated && Boolean(submittedPersonId),
      });
      const text = artifact.response?.text?.trim();
      if (!text) throw new Error("DeepSeek 未返回分析文本");
      if (activeSnapshotIdRef.current !== submittedSnapshotId) {
        setNotice("分析期间本命盘已重新计算，较早结果不会覆盖当前分析。");
        return;
      }
      setAiAnalysisText(text);
      if (accountWorkspace.authenticated && submittedPersonId) {
        await saveLatestAiAnalysis(submittedPersonId, submittedSnapshotId, text, artifact.response.model ?? deepseekModel.model_id);
        await refreshWorkspace();
      }
      setNotice(accountWorkspace.authenticated && submittedPersonId
        ? "DeepSeek 分析已刷新，并覆盖保存为该人物的最新分析。"
        : "DeepSeek 分析已刷新；游客结果仅在当前页面显示。");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : `DeepSeek 分析失败：${error instanceof Error ? error.message : "未知错误"}`);
    } finally {
      setAiSubmitBusy(false);
    }
  }

  const openPoint = (point: NatalPoint) => setTarget({
    type: "point", id: point.point_id, title: pointNames[point.point_id] ?? point.point_id,
    fact: `${pointNames[point.point_id] ?? point.point_id}位于${signNames[point.sign] ?? point.sign}${formatDegree(point.degree_in_sign)}${point.house ? `，第${point.house}宫` : "（日期中点参考位置，不是出生时刻）"}${point.retrograde ? "，逆行" : ""}`,
    facts: [
      `${pointNames[point.point_id] ?? point.point_id}位于${signNames[point.sign] ?? point.sign}${formatDegree(point.degree_in_sign)}${point.house ? `，第${point.house}宫` : "（日期中点参考位置，不是出生时刻）"}${point.retrograde ? "，逆行" : ""}`,
      `黄经 ${point.position.ecliptic.longitude_deg.toFixed(6)}° · 黄纬 ${point.position.ecliptic.latitude_deg?.toFixed(6) ?? "—"}°`,
      ...(dateLevelMode ? [`完整日期内最大位置变化范围 ±${(Number(point.position.uncertainty_arcsec ?? 0) / 3600).toFixed(4)}°`] : []),
      ...(point.out_of_bounds === true ? ["该点位当前处于赤纬越界状态。"] : []),
      ...(point.solar_relation && point.solar_relation !== "free_of_beams" && point.solar_relation !== "self" ? [`太阳条件：${solarRelationNames[point.solar_relation] ?? point.solar_relation}`] : []),
    ],
    resultPath: `/result/points/${snapshot.result.points.findIndex((item) => item.point_id === point.point_id)}`,
  });

  const openAspect = (aspect: NatalAspect) => setTarget({
    type: "aspect", id: aspect.aspect_id,
    title: `${pointNames[aspect.point_a] ?? aspect.point_a}${aspectNames[aspect.type] ?? aspect.type}${pointNames[aspect.point_b] ?? aspect.point_b}`,
    fact: `实际角距 ${aspect.actual_angle_deg.toFixed(3)}°，容许度 ${aspect.orb_deg.toFixed(3)}°`,
    facts: [`理论角度 ${aspect.exact_angle_deg.toFixed(3)}°`, ...(aspectPhaseLabel(aspect.applying_state) ? [`阶段 ${aspectPhaseLabel(aspect.applying_state)}`] : []), `强度 ${Math.round(aspect.strength * 100)}%`],
    resultPath: `/result/aspects/${snapshot.result.aspects.findIndex((item) => item.aspect_id === aspect.aspect_id)}`,
  });

  return (
    <main className="natal-app">
      <header className="site-header">
        <button className="brand-button" onClick={() => { window.location.href = "/"; }}><span className="brand-mark">✦</span><span><b>INTERSTELLAR</b><small>PROFESSIONAL ASTROLOGY</small></span></button>
        <nav>{globalNavigation.map((item) => <button key={item} className={item === "工作台" ? "active" : ""} onClick={() => {
          if (item === "工作台") window.scrollTo({ top: 0, behavior: "smooth" });
          if (item === "分析中心") setAnalysisCenterOpen(true);
          if (item === "对象库") window.location.href = "/objects";
        }}>{item}</button>)}</nav>
        <div className="site-actions">
          {activeTechnique !== "current_sky" && <div className="subject-switcher" ref={subjectSwitcherRef}>
            <button className="subject-switcher-trigger" aria-haspopup="menu" aria-expanded={personMenuOpen} onClick={() => setPersonMenuOpen((value) => !value)}><span>{hasActiveSubject ? subjectName.slice(0, 1) : "＋"}</span><span><b>{hasActiveSubject ? subjectName : "选择人物"}</b><small>{hasActiveSubject ? person.localDate || "生日未填写" : "添加或选择人物"}</small></span><i>{personMenuOpen ? "▴" : "▾"}</i></button>
            {personMenuOpen && <div className="subject-switcher-menu" role="menu">
              {savedPeople.slice(0, 5).map((saved) => <button role="menuitem" key={saved.id} className={selectedPersonId === saved.id ? "active" : ""} onClick={() => { selectWorkspacePerson(saved); setPersonMenuOpen(false); }}><span>{saved.person.displayName.slice(0, 1)}</span><span><b>{saved.person.displayName}</b><small>{saved.person.localDate || "生日未填写"}</small></span><i>{selectedPersonId === saved.id ? "当前" : saved.latestNatal ? "切换" : "计算"}</i></button>)}
              {!savedPeople.length && <p>{accountWorkspace.authenticated ? "人物库中还没有人物。" : "登录后可以保存并切换人物。"}</p>}
              <button className="subject-library-link" onClick={() => { window.location.href = "/objects"; }}>编辑／添加／删除 →</button>
            </div>}
          </div>}
          <button className="theme-toggle" onClick={toggleTheme} aria-label={`切换到${theme === "dark" ? "浅色" : "深色"}主题`} title={`当前${theme === "dark" ? "深色" : "浅色"}主题`}><span>{theme === "dark" ? "☀" : "☾"}</span><small>{theme === "dark" ? "Light" : "Dark"}</small></button><button className="feedback-button" onClick={() => setFeedbackOpen(true)} aria-label="提交问题反馈">反馈</button>{accountWorkspace.authenticated ? <div className="account-menu"><button onClick={() => { window.location.href = "/account"; }}>{accountWorkspace.user?.displayName}</button>{accountWorkspace.user?.role && accountWorkspace.user.role !== "user" && <button onClick={() => { window.location.href = "/admin"; }}>后台</button>}<button onClick={signOut}>退出</button></div> : <button className="account-action" onClick={() => { setAuthError(""); setAuthModal("login"); }}>登录／注册</button>}<button className="primary-action" onClick={() => openNewCalculation()}>＋ 新建分析</button>
        </div>
      </header>

      <nav className="technique-strip" aria-label="盘型切换">{chartTechniques.slice(0, 13).map((technique) => <button key={technique.id} className={technique.id === activeTechnique ? "active" : technique.status === "active" ? "" : "planned"} onClick={() => { if (technique.status === "active") { setActiveTechnique(technique.id as typeof activeTechnique); setShowCalculationResults(false); window.scrollTo({ top: 0, behavior: "smooth" }); } else setCapabilityTarget(technique); }}><b>{technique.label}</b><small>{technique.id === activeTechnique ? "当前" : technique.status === "active" ? "可用" : "规划中"}</small></button>)}<div className="technique-more" ref={moreTechniquesRef}><button className={`technique-more-trigger${moreTechniquesOpen ? " active" : ""}`} onClick={() => {
                if (moreTechniquesOpen) { setMoreTechniquesOpen(false); }
                else {
                  const btn = moreTechniquesRef.current?.querySelector(".technique-more-trigger");
                  if (btn) {
                    const rect = btn.getBoundingClientRect();
                    setMoreTechniquesStyle({ top: rect.bottom + 6, right: window.innerWidth - rect.right });
                  }
                  setMoreTechniquesOpen(true);
                }
              }} aria-label="更多盘型"><b>☰</b><small>更多</small></button>{moreTechniquesOpen && createPortal(<div className="technique-more-menu" style={moreTechniquesStyle} role="menu">{chartTechniques.slice(13).map((technique) => <button key={technique.id} role="menuitem" className={technique.id === activeTechnique ? "active" : "planned"} onClick={() => { setMoreTechniquesOpen(false); if (technique.status === "active") { setActiveTechnique(technique.id as typeof activeTechnique); setShowCalculationResults(false); window.scrollTo({ top: 0, behavior: "smooth" }); } else { setCapabilityTarget(technique); } }}><b>{technique.label}</b><small>{technique.status === "active" ? "可用" : "规划中"}</small></button>)}</div>, document.body)}</div></nav>

      <div className="natal-layout">
        {activeTechnique === "current_sky" ? <CurrentSkyWorkspace theme={theme} /> : !workspaceResolved ? <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在读取工作台</h1><p>正在确认默认人物、示例人物和最近添加人物。</p></div></section> : !hasActiveSnapshot ? <section className="main-workspace empty-workspace"><div><span>✦</span><h1>{hasActiveSubject ? `${subjectName}尚未计算本命盘` : "开始第一次本命分析"}</h1><p>{hasActiveSubject ? `${activeTechnique === "natal" ? "本命盘" : "这个盘型"}需要先有一份本命计算结果。点击下方按钮确认参数并生成本命盘。` : "当前没有默认人物、示例人物或已保存人物。新建分析后即可继续。"}</p><button className="primary-action" onClick={() => openNewCalculation("technique", hasActiveSubject ? person : undefined)}>＋ 新建分析</button></div></section> : activeTechnique === "transits" ? <TransitWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} /> : activeTechnique === "secondary_progressions" ? <SecondaryProgressionsWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "tertiary_progressions" ? <TertiaryProgressionsWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "solar_return" ? <SolarReturnWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "lunar_return" ? <LunarReturnWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "solar_arc" ? <SolarArcWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "relocation" ? <RelocationWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "firdaria" ? <FirdariaWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "annual_profections" ? <AnnualProfectionsWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "dodecatemoria" ? <DodecatemoriaWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : activeTechnique === "tridecatemoria" ? <TridecatemoriaWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} savedPeople={savedPeople} selectedPersonId={selectedPersonId} onSelectPerson={selectWorkspacePerson} /> : <section className="main-workspace">
          {notice && <div className="app-toast" role="status"><p>{notice}</p><button onClick={() => setNotice("")} aria-label="关闭提示">×</button></div>}

          <div className="workbench-grid">
            <article className="wheel-panel chart-workspace-card">
              <div className="panel-heading">
                <div className="wheel-heading-main">
                  <div><small>{showCalculationResults ? "CALCULATION RESULTS" : dateLevelMode ? "DATE-LEVEL POSITION VIEW" : "NATAL CHART"}</small><h2>{showCalculationResults ? "本命盘计算结果" : dateLevelMode ? "日期级星座位置图" : "本命轮盘"}</h2></div>
                  <div className="wheel-heading-actions">
                    {!showCalculationResults && <>
                      <button className="result-flip-button" onClick={() => setShowCalculationResults(true)}>查看结果</button>
                      <div className="view-switcher" aria-label="轮盘视图切换"><button className={chartView === "professional" ? "active" : ""} onClick={() => setChartView("professional")}>{dateLevelMode ? "位置图" : "轮盘"}</button><button className={chartView === "compact" ? "active" : ""} onClick={() => setChartView("compact")}>简洁</button><button disabled={dateLevelMode} className={chartView === "aspect_grid" ? "active" : ""} onClick={() => setChartView("aspect_grid")}>相位矩阵</button></div>
                    </>}
                    <button className="natal-guide-link" onClick={() => setNatalGuideOpen(true)}>什么是本命盘？</button>
                  </div>
                </div>
              </div>
              {showCalculationResults ? <>
                <div className="calculation-view-toolbar"><button onClick={() => setShowCalculationResults(false)}>← 返回轮盘</button><span>{snapshot.result.points.length} 点 · {snapshot.result.aspects.length} 相位</span></div>
                <nav className="calculation-result-tabs" aria-label="本命盘计算结果分类">{calculationResultTabs.map((item) => <button key={item.id} className={calculationTab === item.id ? "active" : ""} onClick={() => setCalculationTab(item.id)}>{item.label}</button>)}</nav>
                <CalculationResults snapshot={snapshot} tab={calculationTab} />
              </> : <>
                <div className="wheel-canvas-area">
                  {chartView === "aspect_grid" && !dateLevelMode ? <AspectGrid snapshot={snapshot} onOpen={openAspect} /> : <NatalWheel snapshot={snapshot} renderSpec={natalRenderSpec} controls={effectiveWheelControls} />}
                </div>
                <footer><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : `恒星黄道 · ${ayanamsaOptions.find((item) => item.id === appliedSettings.ayanamsa)?.label}`}</span>{!dateLevelMode && <span>{houseSystemOptions.find((item) => item.id === appliedSettings.houseSystem)?.label}</span>}<span>{natalRenderSpec.options.visible_point_ids.length}/{snapshot.result.points.length} 点</span><span>计算相位 {snapshot.result.aspects.length} 条</span><span>轮盘绘制 {natalRenderSpec.options.visible_aspect_count} 条</span></footer>
              </>}
            </article>

            <aside className="settings-panel">
              <div className="settings-title"><div><small>CALCULATION SETTINGS</small><h2>本命盘参数</h2></div><div className="settings-title-actions"><span className="settings-title-status">{settingsDirty ? "待应用" : "已生效"}</span><button className="settings-header-calculate" disabled={busy} onClick={calculateNatal} aria-label={settingsDirty ? "重新计算并应用参数" : "按当前参数重新计算"}>{busy ? "计算中…" : settingsDirty ? "应用并计算" : "计算"}</button></div></div>
              <div className="preset-shortcuts" aria-label="本命盘预设">{natalCalculationPresets.map((preset) => <button key={preset.id} className={selectedPresetId === preset.id ? "active" : ""} onClick={() => applyNatalPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>
              <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select><small>切换黄道并重新计算后，点位、相位与轮盘会一起更新。</small></label>
              {settings.zodiac === "sidereal" && <label>岁差体系 Ayanamsa<select value={settings.ayanamsa} onChange={(event) => setSettings({ ...settings, ayanamsa: event.target.value as NatalCalculationSettings["ayanamsa"] })}>{ayanamsaOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select><small>岁差体系会写入本次计算结果与导出的分析数据。</small></label>}
              <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
              <label>观测中心<select value={settings.center} onChange={(event) => setSettings({ ...settings, center: event.target.value as NatalCalculationSettings["center"] })}><option value="geocentric">Geocentric 地心</option><option value="topocentric">Topocentric 出生地点拓扑中心</option></select><small>拓扑中心使用出生地点经纬度与海拔重新计算天体坐标；不是只改变图形标签。日心盘具有不同的太阳／地球和宫位语义，将作为独立盘型开放。</small></label>
              <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="both">真交点＋平均交点</option><option value="true">真交点</option><option value="mean">平均交点</option></select></label>
              <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select><small>{settings.orbMode === "classical_starlight" ? "取两个点位各自星光容许度中较小的值，计算时写入可审计的点位对规则。" : "按每种相位的独立容许度计算；三套预设会载入文档中的对应数值。"}</small></label>
              <fieldset><legend>古典规则表（需重新计算）</legend><label>三分主星表<select value={settings.triplicityTable} onChange={(event) => setSettings({ ...settings, triplicityTable: event.target.value as NatalCalculationSettings["triplicityTable"] })}><option value="dorothean">多罗修斯表</option><option value="ptolemaic">托勒密表</option></select><small>用于本质尊贵与接纳计算。</small></label><label>界表<select value={settings.termsTable} onChange={(event) => setSettings({ ...settings, termsTable: event.target.value as NatalCalculationSettings["termsTable"] })}><option value="egyptian">埃及界</option><option value="ptolemaic">托勒密界</option></select><small>切换后逐星界主与相关接纳会重新计算。</small></label></fieldset>
              <fieldset><legend>计算点位（需重新计算）</legend>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <div className="point-selection-group" key={group}><label className="check-option"><input type="checkbox" checked={groups[group]} onChange={(event) => { const enabled = event.target.checked; setGroups({ ...groups, [group]: enabled }); if (enabled) setSettings({ ...settings, disabledPointIds: settings.disabledPointIds.filter((id) => !pointGroups[group].includes(id as never)) }); }} /><span>{pointGroupLabels[group]}</span><small>{groups[group] ? pointGroups[group].filter((id) => !settings.disabledPointIds.includes(id)).length : 0}/{group === "angles" ? pointGroups[group].length + unavailableVirtualPoints.length : pointGroups[group].length}</small></label><details><summary>逐项选择</summary><div>{pointGroups[group].map((id) => <label className="check-option" key={`${group}-${id}`}><input type="checkbox" disabled={!groups[group]} checked={groups[group] && !settings.disabledPointIds.includes(id)} onChange={(event) => setSettings({ ...settings, disabledPointIds: event.target.checked ? settings.disabledPointIds.filter((item) => item !== id) : [...settings.disabledPointIds, id] })} /><span>{pointNames[id] ?? id}</span></label>)}{group === "angles" && unavailableVirtualPoints.map((item) => <label className="check-option unavailable-point" key={item.id} title={item.reason}><input type="checkbox" disabled /><span>{pointNames[item.id]}</span><small>暂不可用</small></label>)}</div></details></div>)}</fieldset>
              <fieldset><legend>固定星（需重新计算）</legend><label className="check-option"><input type="checkbox" checked={settings.fixedStarIds.length === fixedStarOptions.length} onChange={(event) => setSettings({ ...settings, fixedStarIds: event.target.checked ? fixedStarOptions.map(([id]) => id) : [] })} /><span>24 颗常用固定星</span><small>{settings.fixedStarIds.length}/{fixedStarOptions.length}</small></label><details className="orb-overrides"><summary>逐颗选择固定星</summary><div>{fixedStarOptions.map(([id, label]) => <label className="check-option" key={id}><input type="checkbox" checked={settings.fixedStarIds.includes(id)} onChange={(event) => setSettings({ ...settings, fixedStarIds: event.target.checked ? [...settings.fixedStarIds, id] : settings.fixedStarIds.filter((item) => item !== id) })} /><span>{label}</span></label>)}</div></details><label>固定星合相容许度 {settings.fixedStarOrb.toFixed(1)}°<input type="range" min="0.1" max="3" step="0.1" value={settings.fixedStarOrb} onChange={(event) => setSettings({ ...settings, fixedStarOrb: Number(event.target.value) })} /><small>仅计算固定星与所选本命点位的合相，默认 1°；固定星不会被冒充为行星加入普通相位矩阵。</small></label></fieldset>
              <fieldset><legend>特殊事实（需重新计算）</legend><label>映点／反映点接触容许度 {settings.mirrorOrb.toFixed(1)}°<input type="range" min="0" max="5" step="0.1" value={settings.mirrorOrb} onChange={(event) => setSettings({ ...settings, mirrorOrb: Number(event.target.value) })} /><small>每个点位的映点与反映点位置始终生成；该值只控制点位之间是否构成映点接触。</small></label><label>中点命中容许度 {settings.midpointOrb.toFixed(1)}°<input type="range" min="0" max="5" step="0.1" value={settings.midpointOrb} onChange={(event) => setSettings({ ...settings, midpointOrb: Number(event.target.value) })} /><small>以日、月、水、金、火、木的直接／间接中点检查当前相位集。</small></label><small>特殊度数只输出可追溯的面、燃烧之路与 29 度事实，不附加无来源的吉凶判断。</small></fieldset>
              <fieldset><legend>相位计算（需重新计算）</legend><label className="check-option"><input type="checkbox" checked={!settings.aspectIds.length} onChange={(event) => setSettings({ ...settings, aspectIds: event.target.checked ? [] : ["conjunction", "opposition", "trine", "square", "sextile"] })} /><span>完整专业相位集</span><small>{allAspectIds.length}</small></label><div className="aspect-toggle-grid">{allAspectIds.map((aspect) => <button key={aspect} className={!settings.aspectIds.length || settings.aspectIds.includes(aspect) ? "on" : ""} onClick={() => { const base = settings.aspectIds.length ? settings.aspectIds : [...allAspectIds]; setSettings({ ...settings, aspectIds: base.includes(aspect) ? base.filter((id) => id !== aspect) : [...base, aspect] }); }}>{aspectNames[aspect] ?? aspect}</button>)}</div><details className="orb-overrides"><summary>容许度层级（全局／盘型／相位／类别／点位对）</summary><div className="orb-hierarchy"><div className="orb-level-grid"><label><span>全局</span><input type="number" min="0" max="30" step="0.1" placeholder="规则默认" value={settings.globalOrb ?? ""} onChange={(event) => setSettings({ ...settings, globalOrb: event.target.value === "" ? null : Number(event.target.value) })} /></label><label><span>本命盘</span><input type="number" min="0" max="30" step="0.1" placeholder="继承全局" value={settings.chartOrb ?? ""} onChange={(event) => setSettings({ ...settings, chartOrb: event.target.value === "" ? null : Number(event.target.value) })} /></label></div><h4>指定相位</h4><div className="orb-level-grid">{allAspectIds.map((aspect) => <label key={`orb-${aspect}`}><span>{aspectNames[aspect] ?? aspect}</span><input type="number" min="0" max="30" step="0.1" placeholder="继承上级" value={settings.orbOverrides[aspect] ?? ""} onChange={(event) => { const next = { ...settings.orbOverrides }; if (event.target.value === "") delete next[aspect]; else next[aspect] = Number(event.target.value); setSettings({ ...settings, orbOverrides: next }); }} /></label>)}</div><h4>点位类别</h4><div className="orb-level-grid">{orbPointClassOptions.map(([id, label]) => <label key={`class-orb-${id}`}><span>{label}</span><input type="number" min="0" max="30" step="0.1" placeholder="继承上级" value={settings.pointClassOrbs[id] ?? ""} onChange={(event) => { const next = { ...settings.pointClassOrbs }; if (event.target.value === "") delete next[id]; else next[id] = Number(event.target.value); setSettings({ ...settings, pointClassOrbs: next }); }} /></label>)}</div><h4>指定点位对</h4><div className="point-pair-orbs">{settings.pointPairOrbs.map((pair, index) => <div className="point-pair-row" key={`${pair.pointA}:${pair.pointB}:${index}`}><select aria-label={`点位对 ${index + 1} 第一个点`} value={pair.pointA} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, pointA: event.target.value }; setSettings({ ...settings, pointPairOrbs: next }); }}>{orbPointOptions.map((id) => <option value={id} key={`a-${index}-${id}`}>{pointNames[id] ?? id}</option>)}</select><select aria-label={`点位对 ${index + 1} 第二个点`} value={pair.pointB} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, pointB: event.target.value }; setSettings({ ...settings, pointPairOrbs: next }); }}>{orbPointOptions.map((id) => <option value={id} key={`b-${index}-${id}`}>{pointNames[id] ?? id}</option>)}</select><input aria-label={`点位对 ${index + 1} 容许度`} type="number" min="0" max="30" step="0.1" value={pair.orb} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, orb: Number(event.target.value) }; setSettings({ ...settings, pointPairOrbs: next }); }} /><button aria-label={`删除点位对 ${index + 1}`} onClick={() => setSettings({ ...settings, pointPairOrbs: settings.pointPairOrbs.filter((_, pairIndex) => pairIndex !== index) })}>×</button></div>)}<button className="add-point-pair" onClick={() => setSettings({ ...settings, pointPairOrbs: [...settings.pointPairOrbs, { pointA: "sun", pointB: "moon", orb: 8 }] })}>＋ 添加点位对</button></div><small className="orb-precedence">优先级：指定点位对 ＞ 点位类别 ＞ 指定相位 ＞ 本命盘 ＞ 全局 ＞ 规则预设。</small></div></details></fieldset>
              <fieldset className="wheel-display-settings"><legend>轮盘显示（即时生效）</legend><p className="settings-help">这些选项只改变当前轮盘的视觉显示，不会改变计算结果。</p><h3>显示点位</h3>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <label className="check-option" key={`wheel-${group}`}><input type="checkbox" checked={wheelGroups[group]} onChange={(event) => setWheelGroups({ ...wheelGroups, [group]: event.target.checked })} /><span>{pointGroupLabels[group]}</span><small>{pointGroups[group].length}</small></label>)}<h3>图层</h3><div className="display-toggle-grid">{([
                ["showDegreeTicks", "360°刻度"], ["showZodiacNames", "星座名称"], ["showZodiacDegrees", "星座度数"], ["showHouseLines", "宫位分割线"], ["showHouseNumbers", "宫位数字"], ["showAxes", "四轴"], ["showPointLeaders", "点位引线"], ["showPointDegrees", "点位度数"], ["showFixedStarContacts", "固定星合相标记"], ["showAspectLines", "中心相位线"], ["showLegend", "相位图例"],
              ] as Array<[keyof Omit<NatalRenderControls, "visiblePointIds" | "aspectFilterMode" | "aspectTopPercent" | "aspectMinimumStrength">, string]>).map(([key, label]) => <label className="check-option" key={key}><input type="checkbox" checked={Boolean(wheelControls[key])} onChange={(event) => setWheelControls({ ...wheelControls, [key]: event.target.checked })} /><span>{label}</span></label>)}</div><label className="check-option"><input type="checkbox" checked={wheelControls.majorAspectsOnly} onChange={(event) => setWheelControls({ ...wheelControls, majorAspectsOnly: event.target.checked })} /><span>仅主要相位</span><small>0° / 60° / 90° / 120° / 180°</small></label><label>相位线筛选<select value={wheelControls.aspectFilterMode} onChange={(event) => setWheelControls({ ...wheelControls, aspectFilterMode: event.target.value as NatalRenderControls["aspectFilterMode"] })}><option value="top_percent">按强度保留前百分比</option><option value="minimum_strength">按最低强度阈值</option></select></label>{wheelControls.aspectFilterMode === "top_percent" ? <label>保留强度最高的 {wheelControls.aspectTopPercent}%<input type="range" min="1" max="100" step="1" value={wheelControls.aspectTopPercent} onChange={(event) => setWheelControls({ ...wheelControls, aspectTopPercent: Number(event.target.value) })} /><small>当前显示 {natalRenderSpec.options.visible_aspect_count} / {snapshot.result.aspects.length} 条计算相位。</small></label> : <label>最低强度 {Math.round(wheelControls.aspectMinimumStrength * 100)}%<input type="range" min="0" max="100" step="1" value={Math.round(wheelControls.aspectMinimumStrength * 100)} onChange={(event) => setWheelControls({ ...wheelControls, aspectMinimumStrength: Number(event.target.value) / 100 })} /><small>当前显示 {natalRenderSpec.options.visible_aspect_count} / {snapshot.result.aspects.length} 条计算相位。</small></label>}</fieldset>
              <button className="settings-calculate" disabled={busy} onClick={calculateNatal}>{busy ? "正在重新计算…" : settingsDirty ? "重新计算并应用参数" : "按当前参数重新计算"}</button>
              {settingsDirty && <p className="settings-boundary"><b>存在尚未应用的参数改动。</b> 点击上方“重新计算并应用参数”后，轮盘与分析结果会一起更新。</p>}
              <p className="settings-boundary">当前已支持 20 颗常用小行星／半人马体、24 颗固定星、汉堡虚星与扩展阿拉伯点。固定星使用独立目录和合相表，不与普通行星相位混算。</p>
            </aside>

            <aside className="ai-insight-panel" aria-live="polite">
              <header>
                <div><small>{analysisMode === "instant" ? "INSTANT CHART INSIGHT" : "DEEPSEEK ANALYSIS"}</small><h2>{analysisMode === "instant" ? "盘面速览" : "智能分析"}</h2></div>
                <div className="analysis-header-actions">
                  <button className={analysisMode === "ai" ? "active" : ""} onClick={() => setAnalysisMode(analysisMode === "ai" ? "instant" : "ai")}>{analysisMode === "ai" ? "返回速览" : "✦ 问 AI"}</button>
                  <button aria-label="刷新 DeepSeek 分析" disabled={aiSubmitBusy || settingsDirty || !snapshot.id.startsWith("calculation-")} onClick={() => void refreshAiAnalysis()}>{aiSubmitBusy ? "分析中…" : "↻ 刷新"}</button>
                </div>
              </header>
              {analysisMode === "instant" ? <article className="instant-insight">
                <section className="instant-theme"><span>当前主题</span><h3>{consumerInsight.title}</h3><p>{consumerInsight.summary}</p></section>
                <section className="insight-dimensions">{consumerInsight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section>
                <section className="aspect-balance"><header><b>顺手的地方与拉扯的地方</b></header><div><span className="supportive" style={{ flex: consumerInsight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: consumerInsight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: consumerInsight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {consumerInsight.aspectBalance.supportive}</span><span>需要协调 {consumerInsight.aspectBalance.tension}</span><span>彼此相连 {consumerInsight.aspectBalance.neutral}</span></footer><p>{consumerInsight.aspectBalance.meaning}</p></section>
                <section className="top-signals"><header><b>最值得留意的三个组合</b><small>它们在盘里表现得最明显</small></header>{consumerInsight.signals.length ? consumerInsight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>) : <p>当前参数下没有特别突出的组合，可以先看上面的整体节奏。</p>}</section>
                <section className="insight-advice"><div><b>你比较顺手的部分</b>{consumerInsight.strengths.map((item) => <p key={item}>• {item}</p>)}</div><div><b>给自己的两个提醒</b>{consumerInsight.reminders.map((item) => <p key={item}>• {item}</p>)}</div></section>
                <section className="insight-closing"><b>怎么使用这份速览</b><p>{consumerInsight.closing}</p></section>
              </article> : settingsDirty ? <div className="ai-waiting"><b>参数尚未应用</b><p>请先在左侧点击“重新计算并应用参数”。DeepSeek 不会分析尚未生效的修改。</p></div> : aiSubmitBusy ? <div className="ai-waiting"><span className="analysis-spinner">✦</span><b>正在分析中</b><p>正在读取当前计算结果，请稍候。离开本页不会触发新的分析请求。</p></div> : aiAnalysisText ? <article className="ai-analysis-copy"><SafeMarkdownDocument markdown={aiAnalysisText} /></article> : <div className="ai-waiting"><b>尚未生成分析</b><p>“问 AI”只切换视图；只有点击“刷新”才会提交当前已计算的本命盘。</p></div>}
              <footer><span>{analysisMode === "instant" ? "本地模型 · 计算完成即可显示" : selectedPersonId ? "成功后覆盖该人物上一次分析" : "游客结果不会永久保存"}</span><small>修改参数不会自动计算，也不会自动提交分析。</small></footer>
            </aside>
          </div>

          <section className="result-section" id="natal-results">
            <div className="result-tabs">
              {(["basic", "signs", "houses", "aspects", "structure", "classical", "technical"] as ResultTab[]).map((item) => <button key={item} className={tab === item ? "active" : ""} onClick={() => setTab(item)}>{({ basic: "基本", signs: "星座", houses: "宫位", aspects: "相位", structure: "结构", classical: "古典", technical: "分析数据与导出" })[item]}<small>{item === "basic" ? snapshot.result.points.length : item === "signs" ? signGroups.length : item === "houses" ? snapshot.result.houses.length : item === "aspects" ? snapshot.result.aspects.length : ""}</small></button>)}
            </div>

            {tab === "basic" && <div className="result-content">
              <div className="section-copy"><div><small>{dateLevelMode ? "DATE-RANGE EPHEMERIS" : "DIRECT CALCULATION"}</small><h2>{dateLevelMode ? "日期级星座位置与不确定范围" : "星座、度数、宫位与运动状态"}</h2><p>{dateLevelMode ? "≈ 表示当地日期中点的参考位置，不是出生时刻。每颗天体同时保留完整日期内的最大不确定度、跨星座和运动状态风险。" : "这些结果由天文与占星规则直接计算。点击“解读”读取该点位的自身功能、星座表达、宫位领域与运动状态。"}</p></div><button onClick={() => setTab("technical")}>查看全部字段</button></div>
              <h3 className="table-group-title">十大行星</h3><div className="data-table"><div className="table-head"><span>星体</span><span>星座度数</span><span>宫位</span><span>运动</span><span>经纬度／范围</span><span>操作</span></div>{corePoints.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id]}</b>{pointNames[point.point_id]}</span><span>{pointPlacementLabel(point, dateLevelMode)}{dateLevelMode && <small>日期中点参考</small>}</span><span>{pointHouseLabel(point)}</span><span className={point.retrograde ? "retrograde" : ""}>{pointMotionLabel(point, dateLevelMode)}</span><span>{point.position.ecliptic.longitude_deg.toFixed(4)}°<small>{dateLevelMode ? pointUncertaintyLabel(point) : `纬 ${point.position.ecliptic.latitude_deg?.toFixed(3) ?? "—"}°`}</small></span><button onClick={() => openPoint(point)}>解读</button></div>)}</div>
              <PointResultTable title="虚点" points={virtualPoints} dateLevelMode={dateLevelMode} onOpen={openPoint} />
              {!virtualPoints.length && <TimeDependentUnavailable title="虚点未生成" detail="四轴、宿命点和其他时刻敏感虚点不会在出生时刻未知时进入结果。" />}
              <p className="result-boundary-note"><b>朔望点与紫炁暂不输出。</b> 朔望点需要锁定朔望事件搜索与定义，紫炁尚无可审计的统一公式；系统不会自行发明计算规则。</p>
              <PointResultTable title="小行星与半人马体" points={asteroidPoints} dateLevelMode={dateLevelMode} onOpen={openPoint} />
              <PointResultTable title="汉堡虚星" points={hamburgPoints} dateLevelMode={dateLevelMode} onOpen={openPoint} />
              <PointResultTable title="阿拉伯点" points={lotPoints} dateLevelMode={dateLevelMode} onOpen={openPoint} />
              <PointResultTable title="其他扩展点位" points={otherExtendedPoints} dateLevelMode={dateLevelMode} onOpen={openPoint} />
              {!!snapshot.result.fixed_stars?.length && <><h3 className="table-group-title">固定星与本命合相</h3><div className="data-table fixed-star-consumer-table"><div className="table-head"><span>固定星</span><span>星座度数</span><span>视星等</span><span>赤纬</span><span>本命合相</span></div>{snapshot.result.fixed_stars.map((star) => { const contacts = (snapshot.result.fixed_star_contacts ?? []).filter((contact) => contact.star_id === star.star_id); return <div className="table-row" key={star.star_id}><span className="point-name"><b>★</b>{star.label_zh}<small>{star.name}</small></span><span>{signNames[star.sign] ?? star.sign} {formatDegree(star.degree_in_sign)}</span><span>{star.magnitude_v.toFixed(2)}</span><span>{star.position.equatorial.declination_deg.toFixed(4)}°</span><span>{contacts.length ? contacts.map((contact) => `${pointNames[contact.point_id] ?? contact.point_id}（容许度 ${contact.orb_deg.toFixed(3)}°）`).join("、") : "无（当前容许度）"}</span></div>; })}</div></>}
            </div>}

            {tab === "signs" && <div className="result-content"><div className="section-copy"><div><small>SIGN PLACEMENTS</small><h2>星座落点与表达方式</h2><p>{dateLevelMode ? "按日期中点参考星座聚合，并保留完整日期的不确定范围。跨星座风险会进入点位事实，不把中点位置包装成精确本命落点。" : "星座由黄经直接换算。这里按星座聚合所有已选择点位，并保留每个点位的精确度数、宫位、运动状态和独立解读入口。"}</p></div></div><div className="sign-result-grid">{signGroups.map((group) => <article key={group.sign}><header><span>{signGlyphs[signIds.indexOf(group.sign)]}</span><div><b>{signNames[group.sign]}</b><small>{signStyles[group.sign]}</small></div><i>{group.points.length} 点</i></header><div>{group.points.map((point) => <button key={point.point_id} onClick={() => openPoint(point)}><span>{pointGlyphs[point.point_id] ?? "•"}</span><b>{pointNames[point.point_id] ?? point.point_id}</b><small>{dateLevelMode ? "≈ " : ""}{formatDegree(point.degree_in_sign)} · {point.house ? `第${point.house}宫` : pointUncertaintyLabel(point)}{point.retrograde ? " · 逆行" : ""}</small><i>解读</i></button>)}</div></article>)}</div></div>}

            {tab === "houses" && <div className="result-content"><div className="section-copy"><div><small>HOUSE CUSPS & RULERS</small><h2>十二宫宫头、宫主与宫内点位</h2><p>十二宫把星盘划分为自我、资源、沟通、家庭、创造、日常、关系、共同资源、远行、事业、社群与内在等生活领域。宫位依赖出生时间和地点；资料不足时会明确提示，不会默认使用 00:00。</p></div></div>{snapshot.result.houses.length ? <>
              <h3 className="table-group-title">宫主星</h3>
              <div className="data-table house-ruler-consumer-table"><div className="table-head"><span>宫位</span><span>宫头</span><span>传统宫主</span><span>现代宫主</span><span>宫主飞入</span><span>操作</span></div>{snapshot.result.houses.map((house, index) => { const rulerIds = [...new Set([...house.traditional_ruler_ids, ...house.modern_ruler_ids])]; return <div className="table-row" key={`ruler-${house.number}`}><b>第{house.number}宫</b><span>{signNames[house.sign]} {formatDegree(house.degree_in_sign)}</span><span>{house.traditional_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</span><span>{house.modern_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</span><span>{rulerIds.map((id) => { const ruler = snapshot.result.points.find((point) => point.point_id === id); return `${pointNames[id] ?? id}${ruler?.house ? `飞入第${ruler.house}宫` : "位置未生成"}`; }).join("、") || "—"}</span><button onClick={() => setTarget({ type: "house", id: String(house.number), title: `第${house.number}宫`, fact: `宫头 ${signNames[house.sign]} ${formatDegree(house.degree_in_sign)}，跨度 ${house.span_deg.toFixed(3)}°`, resultPath: `/result/houses/${index}` })}>解读</button></div>; })}</div>
              <h3 className="table-group-title">宫内星</h3>
              <div className="data-table house-occupant-consumer-table"><div className="table-head"><span>宫位</span><span>生活领域</span><span>宫头</span><span>宫内点位</span><span>数量</span><span>操作</span></div>{snapshot.result.houses.map((house, index) => <div className="table-row" key={`occupants-${house.number}`}><b>第{house.number}宫</b><span>{houseDomains[house.number - 1]}</span><span>{signNames[house.sign]} {formatDegree(house.degree_in_sign)}</span><span>{house.point_ids.map((id) => { const point = snapshot.result.points.find((item) => item.point_id === id); return `${pointNames[id] ?? id}${point ? `（${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)}）` : ""}`; }).join("、") || "无"}</span><span>{house.point_ids.length}</span><button onClick={() => setTarget({ type: "house", id: String(house.number), title: `第${house.number}宫`, fact: `宫头 ${signNames[house.sign]} ${formatDegree(house.degree_in_sign)}，跨度 ${house.span_deg.toFixed(3)}°`, resultPath: `/result/houses/${index}` })}>解读</button></div>)}</div>
              <h3 className="table-group-title">十二宫详情</h3>
              <div className="house-grid">{snapshot.result.houses.map((house, index) => <article key={house.number}><header><span>{house.number}</span><div><b>第{house.number}宫</b><small>{houseDomains[house.number - 1]}</small></div></header><dl><div><dt>宫头</dt><dd>{signNames[house.sign]} {formatDegree(house.degree_in_sign)}</dd></div><div><dt>跨度</dt><dd>{house.span_deg.toFixed(3)}°</dd></div><div><dt>传统宫主</dt><dd>{house.traditional_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>现代宫主</dt><dd>{house.modern_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>宫内点位</dt><dd>{house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}</dd></div></dl><button onClick={() => setTarget({ type: "house", id: String(house.number), title: `第${house.number}宫`, fact: `宫头 ${signNames[house.sign]} ${formatDegree(house.degree_in_sign)}，跨度 ${house.span_deg.toFixed(3)}°`, resultPath: `/result/houses/${index}` })}>解读宫位</button></article>)}</div>
            </> : <TimeDependentUnavailable title="十二宫未计算" detail="ASC、MC 和十二宫宫头会在一天内显著移动；没有出生时刻就不存在唯一、可复现的宫位结果。" />}</div>}

            {tab === "aspects" && <div className="result-content"><div className="section-copy"><div><small>PROFESSIONAL ASPECT SET</small><h2>相位矩阵与完整本命相位表</h2><p>矩阵用于快速定位点位关系，明细表展示理论角度、实际角距、容许度、入出相和强度。映点关系在“结构”页单独呈现，不与黄经相位混算。</p></div><span className="count-chip">{snapshot.result.aspects.length} 条</span></div>{snapshot.result.aspects.length ? <><h3 className="table-group-title">相位矩阵</h3><AspectGrid snapshot={snapshot} onOpen={openAspect} /><h3 className="table-group-title">相位信息</h3><div className="aspect-table"><div className="aspect-head"><span>点位 A</span><span>相位</span><span>点位 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span><span>操作</span></div>{snapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}<small>{aspect.exact_angle_deg.toFixed(3)}°</small></b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span><i style={{ width: `${Math.round(aspect.strength * 100)}%` }} />{Math.round(aspect.strength * 100)}%</span><button onClick={() => openAspect(aspect)}>解读</button></div>)}</div></> : <TimeDependentUnavailable title="本命相位未计算" detail="日期内月亮及快速点位会移动，单取中点会制造并不存在于出生时刻的相位；日期级模式只报告点位范围。" />}</div>}

            {tab === "structure" && <div className="result-content"><div className="section-copy"><div><small>NATAL STRUCTURE & FEATURES</small><h2>结构、特征、特殊度数与映点</h2><p>每项都显示参与点位、数量与规则边界。描述性结构不是人格分数；尚无可靠分类依据的 Jones 盘型保持不确定。</p></div></div>{dateLevelMode ? <TimeDependentUnavailable title="整盘结构未计算" detail="当前策略不以日期中点替代本命盘。半球、象限、角续果、群星、几何格局和 Jones 盘型均等待可靠出生时刻。" /> : <><div className="distribution-grid">{snapshot.result.distributions?.map((distribution) => <article key={distribution.dimension}><h3>{({ elements: "四元素", modalities: "三模式", polarities: "阴阳属性" } as Record<string, string>)[distribution.dimension] ?? distribution.dimension}</h3>{distribution.categories.map((category) => { const max = Math.max(...distribution.categories.map((item) => item.count), 1); return <div key={category.category_id}><span>{({ fire: "火", earth: "土", air: "风", water: "水", cardinal: "基本", fixed: "固定", mutable: "变动", positive: "阳性", negative: "阴性" } as Record<string, string>)[category.category_id] ?? category.category_id}</span><i><b style={{ width: `${category.count / max * 100}%` }} /></i><strong>{category.count}</strong></div>; })}</article>)}</div><StructureResults snapshot={snapshot} onOpen={setTarget} /><NatalFeatureResults snapshot={snapshot} /></>}</div>}

            {tab === "classical" && <div className="result-content"><div className="section-copy"><div><small>古典与希腊化核心</small><h2>昼夜、先天黄道、后天状态、接纳与阿拉伯点</h2><p>古典结果与现代结果共用同一次计算，并依据当前参数中的传统规则表独立呈现。这里只展示可直接复核的事实，不生成无来源的综合吉凶分。</p></div></div>{dateLevelMode ? <TimeDependentUnavailable title="古典与希腊化结果未计算" detail="昼夜体系、太阳高度、宫位、阿拉伯点、偶然尊贵和许多接纳语境依赖出生时刻。" /> : <ClassicalResults snapshot={snapshot} onOpen={setTarget} />}</div>}

            {tab === "technical" && <div className="result-content">
              <div className="technical-main"><div className="section-copy"><div><small>ANALYSIS DATA</small><h2>分析数据</h2></div><div className="document-actions"><button onClick={copyTechnical}>复制数据</button><button onClick={downloadTechnical}>导出 TXT</button></div></div><textarea aria-label="本命盘分析数据" value={technicalDocument} readOnly spellCheck={false} /></div>
            </div>}
          </section>

          {snapshot.warnings.length > 0 && <section className="warning-panel"><h2>计算提醒</h2>{snapshot.warnings.map((warning, index) => <p key={`${warning.code}-${warning.message}-${index}`}>{warning.message}</p>)}</section>}
        </section>}
      </div>

      {personModal && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setPersonModal(false); }}>
        <section className="person-modal" role="dialog" aria-modal="true" aria-label="新增人物">
          <header><div><span>SUBJECT LIBRARY</span><h2>{selectedPersonId ? "修改人物资料" : "新增人物"}</h2><p>{accountWorkspace.authenticated ? "保存为当前账户可复用的人物资料；此动作不会自动计算。" : "游客可建立本次会话人物，但关闭页面后不会保存；计算请使用“新建分析”。"}</p></div><button onClick={() => setPersonModal(false)} aria-label="关闭">×</button></header>
          <PersonFields person={person} onChange={setPerson} />
          {accountWorkspace.authenticated && <label className="save-person person-default-option"><input type="checkbox" checked={setAsDefault} onChange={(event) => setSetAsDefault(event.target.checked)} /><span><b>设为工作台默认人物</b><small>登录后优先展示这个人物的最新本命结果。</small></span></label>}
          <footer><button onClick={() => setPersonModal(false)}>取消</button><button className="calculate-button" onClick={savePersonOnly}>{accountWorkspace.authenticated ? "保存人物" : "用于本次会话"}</button></footer>
        </section>
      </div>}

      {authModal && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAuthModal(null); }}>
        <section className="person-modal auth-modal" role="dialog" aria-modal="true" aria-label={authModal === "register" ? "注册 Interstellar" : "登录 Interstellar"}>
          <header><div><span>PRIVATE WORKSPACE</span><h2>{authModal === "register" ? "创建你的占星工作区" : "欢迎回来"}</h2><p>登录后人物资料、最新本命盘和 AI 分析只对你的账户可见。</p></div><button onClick={() => setAuthModal(null)} aria-label="关闭">×</button></header>
          <form className="auth-content" onSubmit={(event) => { event.preventDefault(); void submitAccount(); }}>
            <div className="auth-benefits"><b>账户会保存什么</b><p>人物资料、每个人物最后一次本命盘、计算参数与已完成的 AI 分析。</p><small>游客仍可完整计算，但关闭页面后不保存。</small></div>
            {authModal === "register" && <label>昵称<input autoComplete="name" value={authDisplayName} onChange={(event) => setAuthDisplayName(event.target.value)} placeholder="如何称呼你" /></label>}
            <label>邮箱<input type="email" autoComplete="email" value={authEmail} onChange={(event) => setAuthEmail(event.target.value)} placeholder="name@example.com" /></label>
            <label>密码<input type="password" autoComplete={authModal === "register" ? "new-password" : "current-password"} value={authPassword} onChange={(event) => setAuthPassword(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") void submitAccount(); }} placeholder="至少 8 个字符" /></label>
            {authError && <p className="auth-error">{authError}</p>}
            <button type="submit" className="auth-submit" disabled={authBusy || !authEmail || authPassword.length < 8}>{authBusy ? "请稍候…" : authModal === "register" ? "注册并进入工作区" : "登录工作区"}</button>
            <button type="button" className="auth-switch" onClick={() => { setAuthError(""); setAuthModal(authModal === "register" ? "login" : "register"); }}>{authModal === "register" ? "已有账户？直接登录" : "还没有账户？立即注册"}</button>
          </form>
        </section>
      </div>}

      {calculationModal && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setCalculationModal(false); }}>
        <section className="person-modal calculation-modal" role="dialog" aria-modal="true" aria-label="新建分析">
          <header><div><span>NEW ANALYSIS</span><h2>新建分析</h2><p>{entryModes.find((entry) => entry.id === entryPoint)?.context}</p></div><button onClick={() => setCalculationModal(false)} aria-label="关闭">×</button></header>
          <section className="calculation-step"><div className="step-title"><span>1</span><div><b>选择计算方法</b><small>本命盘当前可运行；其他方法保留入口，但不返回假结果。</small></div></div><div className="calculation-techniques">{chartTechniques.map((technique) => <button key={technique.id} className={technique.status === "active" ? "active" : "planned"} onClick={() => technique.status === "active" ? undefined : setCapabilityTarget(technique)}><b>{technique.label}</b><small>{technique.outputs}</small><i>{technique.status === "active" ? "已选择" : "规划中"}</i></button>)}</div></section>
          <section className="calculation-step"><div className="step-title"><span>2</span><div><b>选择人物</b><small>{accountWorkspace.authenticated ? "可以选择我的人物，也可以填写仅用于本次计算的临时人物。" : "游客可以填写临时人物并完成计算，但不会保存。"}</small></div></div>{savedPeople.length > 0 && <div className="subject-picker">{savedPeople.map((saved) => <button key={saved.id} className={selectedPersonId === saved.id ? "active" : ""} onClick={() => { setSelectedPersonId(saved.id); setPerson(saved.person); }}><span>{saved.person.displayName.slice(0, 1)}</span><b>{saved.person.displayName}</b><small>{saved.person.localDate}</small></button>)}</div>}<details className="inline-person" open={!savedPeople.length || !person.displayName}><summary>{person.displayName ? `本次人物：${person.displayName}（展开编辑）` : "填写临时人物"}</summary><PersonFields person={person} onChange={(next) => { setPerson(next); if (selectedPersonId && next.displayName !== savedPeople.find((item) => item.id === selectedPersonId)?.person.displayName) setSelectedPersonId(null); }} /></details></section>
          <section className="calculation-step"><div className="step-title"><span>3</span><div><b>选择推荐方案</b><small>推荐方案只是一组有来源说明的常用默认值；你仍可检查并修改关键参数。</small></div></div><div className="calculation-presets">{natalCalculationPresets.map((preset) => <button key={preset.id} className={selectedPresetId === preset.id ? "active" : ""} onClick={() => applyNatalPreset(preset.id)}><span>{preset.badge}</span><b>{preset.label}</b><p>{preset.description}</p><small>{preset.basis}</small></button>)}</div></section>
          <section className="calculation-step"><div className="step-title"><span>4</span><div><b>检查关键参数</b><small>这里只展示最影响结果的参数；完整点位、相位与容许度仍可在工作台参数面板调整。</small></div></div><div className="calculation-key-settings"><label>黄道体系<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label><label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>{settings.zodiac === "sidereal" && <label>岁差体系<select value={settings.ayanamsa} onChange={(event) => setSettings({ ...settings, ayanamsa: event.target.value as NatalCalculationSettings["ayanamsa"] })}>{ayanamsaOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>}<label>点位范围<select value={groups.hamburg ? "all" : groups.lots ? "professional" : "modern"} onChange={(event) => { const value = event.target.value; setGroups(value === "all" ? { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: true } : value === "professional" ? { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: false } : { core: true, angles: true, lunar: true, asteroids: true, lots: false, hamburg: false }); }}><option value="modern">现代常用点位</option><option value="professional">专业点位（含阿拉伯点）</option><option value="all">全部已发布点位（含汉堡虚星）</option></select></label><label>相位范围<select value={settings.aspectIds.length === majorAspectIds.length ? "major" : settings.aspectIds.length === professionalAspectIds.length ? "professional" : "all"} onChange={(event) => { const value = event.target.value; setSettings({ ...settings, aspectIds: value === "major" ? majorAspectIds : value === "professional" ? professionalAspectIds : [] }); }}><option value="major">五大主要相位</option><option value="professional">专业常用相位</option><option value="all">全部已发布相位</option></select></label></div><section className="effective-parameter-preview"><header><b>本次生效参数</b><span>{selectedPresetId === "custom" ? "自定义" : natalCalculationPresets.find((item) => item.id === selectedPresetId)?.badge}</span></header><dl><div><dt>黄道</dt><dd>{settings.zodiac === "tropical" ? "回归黄道" : `恒星黄道 · ${ayanamsaOptions.find((item) => item.id === settings.ayanamsa)?.label}`}</dd></div><div><dt>宫位</dt><dd>{houseSystemOptions.find((item) => item.id === settings.houseSystem)?.label}</dd></div><div><dt>点位组</dt><dd>{Object.values(groups).filter(Boolean).length} / {Object.keys(groups).length}</dd></div><div><dt>相位</dt><dd>{settings.aspectIds.length || allAspectIds.length} 种</dd></div><div><dt>输出</dt><dd>轮盘、相位矩阵、数据表、基本／星座／宫位／结构／古典／导出</dd></div></dl><p>修改参数后需要重新计算，结果才会更新。</p></section><label className="save-person"><input type="checkbox" disabled={!accountWorkspace.authenticated || Boolean(selectedPersonId)} checked={Boolean(selectedPersonId) || saveProfile} onChange={(event) => setSaveProfile(event.target.checked)} /><span><b>{selectedPersonId ? "覆盖该人物的最新本命盘" : accountWorkspace.authenticated ? "计算完成后保存人物与最新结果" : "游客结果不保存"}</b><small>{selectedPersonId ? "旧的本命计算结果不会保留。" : accountWorkspace.authenticated ? "不勾选则只在当前页面使用。" : "登录／注册后才可永久保存。"}</small></span></label>{accountWorkspace.authenticated && <label className="save-person"><input type="checkbox" disabled={!selectedPersonId && !saveProfile} checked={setAsDefault} onChange={(event) => setSetAsDefault(event.target.checked)} /><span><b>设为工作台默认人物</b><small>下次打开工作台时优先展示这个人物；之后可在对象库修改或取消。</small></span></label>}</section>
          <footer><button onClick={() => setCalculationModal(false)}>取消</button><button className="calculate-button" disabled={busy} onClick={calculateNatal}>{busy ? "正在计算全部本命事实…" : "计算完整本命盘"}</button></footer>
        </section>
      </div>}

      {analysisCenterOpen && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAnalysisCenterOpen(false); }}><section className="person-modal analysis-center" role="dialog" aria-modal="true" aria-label="分析中心"><header><div><span>ANALYSIS CENTER</span><h2>分析中心</h2><p>可以按排盘技法、专题、目的、对象或时间周期进入；14 种盘型保留快速切换入口。</p></div><button onClick={() => setAnalysisCenterOpen(false)} aria-label="关闭">×</button></header><div className="entry-mode-grid">{entryModes.map((entry, index) => <article key={entry.id}><span>{String(index + 1).padStart(2, "0")}</span><h3>{entry.title}</h3><p>{entry.description}</p><small>{entry.context}</small><button onClick={() => { setAnalysisCenterOpen(false); openNewCalculation(entry.id); }}>从这里开始</button></article>)}</div><div className="analysis-technique-section"><header><div><small>CHART TYPES</small><h3>14 种盘型</h3></div><p>本命盘当前可用，其他盘型将在各自参数与计算完成后开放。</p></header><div className="technique-center-grid">{chartTechniques.map((technique, index) => <button key={technique.id} className={technique.status === "active" ? "active" : "planned"} onClick={() => { setAnalysisCenterOpen(false); if (technique.status === "active") { setShowCalculationResults(false); window.scrollTo({ top: 0, behavior: "smooth" }); } else setCapabilityTarget(technique); }}><span>{String(index + 1).padStart(2, "0")}</span><b>{technique.label}</b><small>{technique.status === "active" ? "进入本命盘" : "规划中"}</small></button>)}</div></div></section></div>}

      {natalGuideOpen && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setNatalGuideOpen(false); }}><section className="person-modal natal-guide-modal" role="dialog" aria-modal="true" aria-label="什么是本命盘"><header><div><span>本命盘说明</span><h2>什么是本命盘？</h2><p>盘面内容、资料要求、核心要素与基本解读方法。</p></div><button onClick={() => setNatalGuideOpen(false)} aria-label="关闭">×</button></header><article className="natal-guide-content">{natalGuideText ? <SafeMarkdownDocument markdown={natalGuideText} /> : "正在载入…"}</article></section></div>}

      {capabilityTarget && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setCapabilityTarget(null); }}><section className="person-modal capability-modal" role="dialog" aria-modal="true" aria-label={`${capabilityTarget.label}能力说明`}><header><div><span>规划中</span><h2>{capabilityTarget.label}</h2><p>这项排盘暂未开放。</p></div><button onClick={() => setCapabilityTarget(null)} aria-label="关闭">×</button></header><div className="capability-detail"><dl><div><dt>需要资料</dt><dd>{capabilityTarget.inputs}</dd></div><div><dt>计划内容</dt><dd>{capabilityTarget.outputs}</dd></div></dl></div><footer><button className="calculate-button" onClick={() => setCapabilityTarget(null)}>我知道了</button></footer></section></div>}
      {target && <InterpretationDrawer target={target} snapshot={snapshot} onClose={() => setTarget(null)} />}
      {feedbackOpen && <div className="modal-backdrop feedback-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setFeedbackOpen(false); }}><section className="person-modal feedback-modal" role="dialog" aria-modal="true" aria-label="问题反馈"><header><div><span>FEEDBACK</span><h2>问题反馈</h2><p>遇到 Bug 或有功能建议？请告诉我们。</p></div><button onClick={() => setFeedbackOpen(false)} aria-label="关闭">×</button></header><form onSubmit={(event) => { event.preventDefault(); if (!feedbackContent.trim()) { setFeedbackNotice("请填写反馈内容"); return; } setFeedbackBusy(true); setFeedbackNotice(null); void submitFeedback({ type: feedbackType, content: feedbackContent, contact: feedbackContact }).then(() => { setFeedbackNotice("反馈已提交，谢谢！"); setFeedbackContent(""); setFeedbackContact(""); }).catch((error) => { setFeedbackNotice(error instanceof FeedbackApiError ? error.message : "提交失败，请稍后重试"); }).finally(() => setFeedbackBusy(false)); }}><div className="feedback-form"><label className="feedback-type"><span>反馈类型</span><select value={feedbackType} onChange={(event) => setFeedbackType(event.target.value as "bug" | "feature" | "other")}><option value="bug">Bug 反馈</option><option value="feature">功能建议</option><option value="other">其他</option></select></label><label className="feedback-content"><span>反馈内容</span><textarea value={feedbackContent} onChange={(event) => setFeedbackContent(event.target.value)} placeholder="请描述你遇到的问题或建议…" rows={5} maxLength={5000} required /></label><label className="feedback-contact"><span>联系方式（可选）</span><input type="text" value={feedbackContact} onChange={(event) => setFeedbackContact(event.target.value)} placeholder="邮箱或微信号，方便我们回复" maxLength={160} /></label>{feedbackNotice && <p className={feedbackNotice.startsWith("反馈已提交") ? "feedback-success" : "feedback-error"}>{feedbackNotice}</p>}</div><footer><button type="button" onClick={() => setFeedbackOpen(false)}>取消</button><button type="submit" className="calculate-button" disabled={feedbackBusy}>{feedbackBusy ? "提交中…" : "提交反馈"}</button></footer></form></section></div>}

    </main>
  );
}
