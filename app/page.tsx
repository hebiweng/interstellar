"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";

import {
  createCurrentSkyCalculation,
  createPersonAndNatalCalculation,
  createSecondaryProgression,
  createTransitComparison,
  getAiProviders,
  getNatalItemInterpretation,
  getNatalTechnicalDocument,
  InterstellarApiError,
  previewNatalAiPayload,
  searchLocations,
  submitNatalToAi,
  type AiProvider,
  type ChartComparison,
  type CurrentSkyInput,
  type ItemInterpretation,
  type NatalAspect,
  type NatalCalculationSettings,
  type NatalHouse,
  type NatalPersonInput,
  type NatalPoint,
  type NatalSnapshot,
  type LocationSearchItem,
  type SecondaryProgressionResult,
} from "./lib/interstellar-api";
import { submitFeedback, FeedbackApiError } from "./lib/feedback-api";
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
} from "./lib/account-workspace";
import {
  buildNatalRenderSpec,
  downloadBlob,
  selectVisibleNatalAspects,
  type NatalRenderControls,
  type RenderSpec,
} from "./lib/render-export";
import { recordAnalyticsEvent } from "./lib/analytics";
import { buildCurrentSkyConsumerInsight, buildCurrentSkyInterpretationSections, buildNatalConsumerInsight, buildSecondaryProgressionConsumerInsight, buildSecondaryProgressionInterpretationSections, buildTransitConsumerInsight, buildTransitInterpretationSections, type ConsumerInsight, type InterpretationSection } from "./lib/consumer-insight";
import {
  classicalStarlightPairOrbs,
  cloneNatalPointGroups,
  cloneNatalSettings,
  identifyNatalPreset,
  identifyTimingPreset,
  natalCalculationPresets,
  normalizeNatalSettings,
  timingCalculationPresets,
  type NatalPointGroups,
  type NatalPresetId,
} from "./lib/natal-presets";

type ResultTab = "basic" | "signs" | "houses" | "aspects" | "structure" | "classical" | "technical";
type CalculationTab = "features" | "planets" | "houses" | "firdaria" | "profections" | "lots" | "stars" | "fortune_zr" | "spirit_zr" | "mirrors" | "degrees" | "rays" | "midpoints";
type CurrentSkyResultTab = "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "events";
type TransitResultTab = "overview" | "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "cross_aspects" | "reference_houses";
type SecondaryResultTab = "overview" | "features" | "planets" | "houses" | "lots" | "stars" | "mirrors" | "degrees" | "rays" | "midpoints" | "aspects" | "cross_aspects" | "reference_houses";
type ChartView = "professional" | "compact" | "aspect_grid";
type ThemeMode = "dark" | "light";
type EntryPointId = "technique" | "topic" | "intent" | "object" | "personal" | "context";
type TechniqueId = "natal" | "transits" | "current_sky" | "secondary_progressions" | "tertiary_progressions" | "solar_return" | "lunar_return" | "solar_arc" | "firdaria" | "annual_profections" | "relocation" | "dragon_head" | "dodecatemoria" | "tridecatemoria";
type InterpretationTarget = {
  type: "point" | "house" | "aspect" | "structure" | "classical";
  id: string;
  title: string;
  fact: string;
  facts?: string[];
  resultPath?: string;
};

const globalNavigation = ["工作台", "分析中心", "对象库"] as const;

const entryModes: Array<{ id: EntryPointId; title: string; description: string; context: string }> = [
  { id: "technique", title: "技法排盘", description: "直接选择本命、行运、推运、返照等计算方法", context: "只加入所选技法的必需依赖，默认不添加专题解释。" },
  { id: "topic", title: "专题模型", description: "从职业、关系、财富、人格等专题模型进入", context: "专题锁定必要计算参数，只开放与主题相关的调整。" },
  { id: "intent", title: "分析目的", description: "从现实问题反推需要的对象、技法和输出", context: "先确认目的，再由预检生成可检查的计算配方。" },
  { id: "object", title: "对象快捷", description: "从人物、关系、项目、事件或组织开始", context: "预填当前对象，只展示该对象真正可执行的动作。" },
  { id: "personal", title: "时间与周期", description: "查看短期、年度和长期周期", context: "预填当前人物和时间范围，页面打开时不批量计算。" },
  { id: "context", title: "关系／项目／地点", description: "预填双人、项目或地点上下文", context: "缺少第二人物、事件时刻或目标地点时会明确阻断。" },
];

const chartTechniques: Array<{ id: TechniqueId; label: string; status: "active" | "planned"; stage: string; inputs: string; outputs: string }> = [
  { id: "natal", label: "本命盘", status: "active", stage: "当前", inputs: "一名人物的出生时间与地点", outputs: "单轮盘、相位图、基础与古典结果" },
  { id: "transits", label: "行运盘", status: "active", stage: "可用", inputs: "人物＋目标时刻或时间范围", outputs: "本命＋行运双轮、跨盘相位与本命落宫" },
  { id: "current_sky", label: "天象盘", status: "active", stage: "当前", inputs: "时刻与地点", outputs: "当前天空单盘、天象事件" },
  { id: "secondary_progressions", label: "次限盘", status: "active", stage: "可用", inputs: "人物＋目标日期", outputs: "本命＋次限双轮、推运月相" },
  { id: "tertiary_progressions", label: "三限盘", status: "planned", stage: "规划中", inputs: "人物＋目标日期", outputs: "本命＋三限双轮、时间线" },
  { id: "solar_return", label: "日返盘", status: "planned", stage: "规划中", inputs: "人物＋目标年份与地点", outputs: "太阳返照盘与年度主题" },
  { id: "lunar_return", label: "月返盘", status: "planned", stage: "规划中", inputs: "人物＋目标月份与地点", outputs: "月亮返照盘与月度主题" },
  { id: "solar_arc", label: "日弧盘", status: "planned", stage: "规划中", inputs: "人物＋目标日期", outputs: "太阳弧双轮、弧向命中" },
  { id: "firdaria", label: "法达", status: "planned", stage: "规划中", inputs: "人物＋目标日期", outputs: "主限、次限与起始日期" },
  { id: "annual_profections", label: "小限", status: "planned", stage: "规划中", inputs: "人物＋目标年份", outputs: "年小限宫位、主星与时间线" },
  { id: "relocation", label: "重置盘", status: "planned", stage: "规划中", inputs: "人物＋目标地点", outputs: "重置地点后的四轴、宫位与轮盘" },
  { id: "dragon_head", label: "龙首", status: "planned", stage: "规划中", inputs: "人物＋交点规则", outputs: "龙首相关传统推演结果" },
  { id: "dodecatemoria", label: "12分盘", status: "planned", stage: "规划中", inputs: "人物＋十二分规则", outputs: "Dodecatemoria 十二分位置与轮盘" },
  { id: "tridecatemoria", label: "13分盘", status: "planned", stage: "规划中", inputs: "人物＋十三分规则", outputs: "十三分位置与轮盘" },
];

const calculationResultTabs: Array<{ id: CalculationTab; label: string }> = [
  { id: "features", label: "特征" },
  { id: "planets", label: "行星" },
  { id: "houses", label: "宫位" },
  { id: "firdaria", label: "法达" },
  { id: "profections", label: "小限" },
  { id: "lots", label: "阿拉伯点" },
  { id: "stars", label: "恒星" },
  { id: "fortune_zr", label: "福点" },
  { id: "spirit_zr", label: "精神点" },
  { id: "mirrors", label: "映点" },
  { id: "degrees", label: "特殊度数" },
  { id: "rays", label: "光线" },
  { id: "midpoints", label: "中点" },
];

const currentSkyResultTabs: Array<{ id: CurrentSkyResultTab; label: string }> = [
  { id: "features", label: "特征" },
  { id: "planets", label: "行星" },
  { id: "houses", label: "宫位" },
  { id: "aspects", label: "相位" },
  { id: "lots", label: "阿拉伯点" },
  { id: "stars", label: "恒星" },
  { id: "mirrors", label: "映点" },
  { id: "degrees", label: "特殊度数" },
  { id: "rays", label: "光线" },
  { id: "midpoints", label: "中点" },
  { id: "events", label: "天象" },
];

const currentSkySharedResultTabs = new Set<CurrentSkyResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

const secondaryResultTabs: Array<{ id: SecondaryResultTab; label: string }> = [
  { id: "overview", label: "总览" },
  { id: "features", label: "特征" },
  { id: "planets", label: "次限点位" },
  { id: "houses", label: "次限宫位" },
  { id: "aspects", label: "次限相位" },
  { id: "cross_aspects", label: "跨盘相位" },
  { id: "reference_houses", label: "本命落宫" },
  { id: "lots", label: "阿拉伯点" },
  { id: "stars", label: "恒星" },
  { id: "mirrors", label: "映点" },
  { id: "degrees", label: "特殊度数" },
  { id: "rays", label: "光线" },
  { id: "midpoints", label: "中点" },
];

const transitResultTabs: Array<{ id: TransitResultTab; label: string }> = [
  { id: "overview", label: "总览" },
  { id: "features", label: "特征" },
  { id: "planets", label: "行运点位" },
  { id: "houses", label: "行运宫位" },
  { id: "aspects", label: "天象相位" },
  { id: "cross_aspects", label: "跨盘相位" },
  { id: "reference_houses", label: "本命落宫" },
  { id: "lots", label: "阿拉伯点" },
  { id: "stars", label: "恒星" },
  { id: "mirrors", label: "映点" },
  { id: "degrees", label: "特殊度数" },
  { id: "rays", label: "光线" },
  { id: "midpoints", label: "中点" },
];

const transitSharedResultTabs = new Set<TransitResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

const secondarySharedResultTabs = new Set<SecondaryResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

const fallbackTimezoneOptions = [
  "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Taipei", "Asia/Tokyo", "Asia/Singapore",
  "Europe/London", "Europe/Paris", "America/New_York", "America/Chicago", "America/Los_Angeles", "Australia/Sydney",
];

const fallbackPlaceOptions = [
  { name: "北京", countryCode: "CN", latitude: 39.9042, longitude: 116.4074, timezoneId: "Asia/Shanghai" },
  { name: "上海", countryCode: "CN", latitude: 31.2304, longitude: 121.4737, timezoneId: "Asia/Shanghai" },
  { name: "广州", countryCode: "CN", latitude: 23.1291, longitude: 113.2644, timezoneId: "Asia/Shanghai" },
  { name: "深圳", countryCode: "CN", latitude: 22.5431, longitude: 114.0579, timezoneId: "Asia/Shanghai" },
  { name: "香港", countryCode: "HK", latitude: 22.3193, longitude: 114.1694, timezoneId: "Asia/Hong_Kong" },
  { name: "台北", countryCode: "TW", latitude: 25.033, longitude: 121.5654, timezoneId: "Asia/Taipei" },
  { name: "东京", countryCode: "JP", latitude: 35.6762, longitude: 139.6503, timezoneId: "Asia/Tokyo" },
  { name: "伦敦", countryCode: "GB", latitude: 51.5074, longitude: -0.1278, timezoneId: "Europe/London" },
  { name: "巴黎", countryCode: "FR", latitude: 48.8566, longitude: 2.3522, timezoneId: "Europe/Paris" },
  { name: "纽约", countryCode: "US", latitude: 40.7128, longitude: -74.006, timezoneId: "America/New_York" },
  { name: "洛杉矶", countryCode: "US", latitude: 34.0522, longitude: -118.2437, timezoneId: "America/Los_Angeles" },
];

const houseSystemOptions: Array<{ id: NatalCalculationSettings["houseSystem"]; label: string }> = [
  { id: "placidus", label: "Placidus 普拉西德" },
  { id: "whole_sign", label: "Whole Sign 整宫制" },
  { id: "koch", label: "Koch 柯赫" },
  { id: "porphyry", label: "Porphyry 波菲利" },
  { id: "regiomontanus", label: "Regiomontanus 雷吉奥蒙塔努斯" },
  { id: "campanus", label: "Campanus 坎帕努斯" },
  { id: "equal", label: "Equal 等宫制" },
  { id: "alcabitius", label: "Alcabitius 阿卡比特" },
  { id: "topocentric", label: "Topocentric 拓扑中心宫制" },
  { id: "morinus", label: "Morinus 莫里努斯" },
  { id: "krusinski", label: "Krusinski / Pisa 克鲁辛斯基-比萨" },
  { id: "vehlow", label: "Vehlow 维洛" },
  { id: "equal_mc", label: "Equal MC · 第十宫宫头固定 MC" },
  { id: "equal_aries", label: "Equal Aries · 白羊 0° 起宫" },
  { id: "meridian", label: "Meridian / Axial Rotation 子午线制" },
  { id: "horizontal", label: "Horizontal / Azimuthal 地平制" },
  { id: "carter_poli_equatorial", label: "Carter Poli-Equatorial 卡特制" },
  { id: "apc", label: "APC 宫位制" },
  { id: "pullen_sd", label: "Pullen SD 正弦差制" },
  { id: "pullen_sr", label: "Pullen SR 正弦比制" },
  { id: "sunshine_treindl", label: "Sunshine / Treindl 阳光宫位制" },
  { id: "sripati", label: "Sripati 宫位制" },
];

const ayanamsaOptions: Array<{ id: NatalCalculationSettings["ayanamsa"]; label: string }> = [
  { id: "fagan_bradley", label: "Fagan–Bradley" },
  { id: "lahiri", label: "Lahiri" },
  { id: "deluce", label: "De Luce" },
  { id: "raman", label: "Raman" },
  { id: "ushashashi", label: "Ushashashi" },
  { id: "krishnamurti", label: "Krishnamurti" },
  { id: "djwhal_khul", label: "Djwhal Khul" },
  { id: "yukteshwar", label: "Yukteshwar" },
  { id: "jn_bhasin", label: "J. N. Bhasin" },
  { id: "true_pushya", label: "True Pushya" },
  { id: "hipparchos", label: "Hipparchos" },
  { id: "true_revati", label: "True Revati" },
  { id: "true_citra", label: "True Citra" },
  { id: "galactic_center_0_sagittarius", label: "Galactic Center 0° Sagittarius" },
];

const pointNames: Record<string, string> = {
  sun: "太阳", moon: "月亮", mercury: "水星", venus: "金星", mars: "火星",
  jupiter: "木星", saturn: "土星", uranus: "天王星", neptune: "海王星", pluto: "冥王星",
  asc: "上升", dsc: "下降", mc: "天顶", ic: "天底", vertex: "宿命点", anti_vertex: "反宿命点",
  east_point: "东点", west_point: "西点", true_north_node: "真北交点", true_south_node: "真南交点",
  mean_north_node: "平均北交点", mean_south_node: "平均南交点", mean_lilith: "平均莉莉丝",
  true_lilith: "真莉莉丝", lunar_perigee: "月球近地点", chiron: "凯龙星", ceres: "谷神星",
  pallas: "智神星", juno: "婚神星", vesta: "灶神星", pholus: "福洛斯", nessus: "涅索斯",
  chariklo: "查里克洛", asteroid_eros: "爱神星", psyche: "灵神星", eris: "阋神星", sedna: "赛德娜",
  haumea: "妊神星", makemake: "鸟神星", quaoar: "创神星", orcus: "亡神星", ixion: "伊克西翁",
  varuna: "伐楼拿", astraea: "义神星", hygiea: "健神星", fortune: "福点", spirit: "精神点",
  lot_eros: "爱神点", lot_necessity: "必然点", lot_courage: "勇气点", lot_victory: "胜利点",
  lot_nemesis: "复仇点", lot_exaltation: "擢升点",
  cupido: "丘比特", hades: "哈得斯", zeus: "宙斯", kronos: "克洛诺斯", apollon: "阿波罗",
  admetos: "阿得门图斯", vulkanus: "弗卡奴斯", poseidon: "波塞冬", syzygy: "朔望点", zi_qi: "紫炁",
};

const pointGlyphs: Record<string, string> = {
  sun: "☉", moon: "☽", mercury: "☿", venus: "♀", mars: "♂", jupiter: "♃", saturn: "♄",
  uranus: "♅", neptune: "♆", pluto: "♇", asc: "A", dsc: "D", mc: "M", ic: "I",
  true_north_node: "☊", true_south_node: "☋", mean_north_node: "☊", mean_south_node: "☋",
  chiron: "⚷", ceres: "⚳", pallas: "⚴", juno: "⚵", vesta: "⚶", fortune: "⊗", spirit: "◇",
  lot_eros: "E", lot_necessity: "N", lot_courage: "C", lot_victory: "V", lot_nemesis: "N", lot_exaltation: "X",
};

const wheelPointLabels: Record<string, string> = {
  sun: "日", moon: "月", mercury: "水", venus: "金", mars: "火", jupiter: "木", saturn: "土",
  uranus: "天", neptune: "海", pluto: "冥", asc: "升", dsc: "降", mc: "顶", ic: "底",
  vertex: "宿", anti_vertex: "反", east_point: "东", west_point: "西", true_north_node: "北",
  true_south_node: "南", mean_north_node: "平北", mean_south_node: "平南", mean_lilith: "莉",
  true_lilith: "真莉", lunar_perigee: "近", chiron: "凯", ceres: "谷", pallas: "智", juno: "婚",
  vesta: "灶", fortune: "福", spirit: "灵", lot_eros: "爱", lot_necessity: "必", lot_courage: "勇",
  lot_victory: "胜", lot_nemesis: "报", lot_exaltation: "擢", cupido: "丘", hades: "哈", zeus: "宙",
  kronos: "克", apollon: "阿", admetos: "得", vulkanus: "弗", poseidon: "波",
};

const signNames: Record<string, string> = {
  aries: "白羊", taurus: "金牛", gemini: "双子", cancer: "巨蟹", leo: "狮子", virgo: "处女",
  libra: "天秤", scorpio: "天蝎", sagittarius: "射手", capricorn: "摩羯", aquarius: "水瓶", pisces: "双鱼",
};
const signGlyphs = ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"];
const signIds = Object.keys(signNames);

const aspectNames: Record<string, string> = {
  conjunction: "合相", opposition: "对冲", trine: "三分", square: "四分", sextile: "六分",
  semiduodecile: "半十二分", semioctile: "辅八分", semisextile: "半六分", semisquare: "半刑", sesquisquare: "拱半", quincunx: "梅花",
  quintile: "五分", biquintile: "双五分", novile: "九分", septile: "七分", biseptile: "双七分",
  triseptile: "三七分", undecile: "十一分", decile: "十分",
};

const aspectPhaseNames: Record<string, string> = {
  applying: "入相",
  exact: "精确",
  separating: "出相",
  stationary: "停滞",
  unknown: "阶段未判定",
};

function aspectPhaseLabel(value: string) {
  return aspectPhaseNames[value];
}

const aspectMarks: Record<string, string> = {
  conjunction: "☌", opposition: "☍", trine: "△", square: "□", sextile: "✶", quincunx: "⚻",
  semisextile: "⚺", semisquare: "∠", sesquisquare: "⚼", quintile: "Q", biquintile: "bQ",
  novile: "N", septile: "S", biseptile: "bS", triseptile: "tS", undecile: "U", decile: "D",
};

const lunarPhaseNames: Record<string, string> = {
  new_moon: "新月",
  waxing_crescent: "蛾眉月",
  first_quarter: "上弦月",
  waxing_gibbous: "盈凸月",
  full_moon: "满月",
  waning_gibbous: "亏凸月",
  last_quarter: "下弦月",
  waning_crescent: "残月",
};

function lunarPhaseLabel(value: unknown) {
  const id = typeof value === "string" ? value : "";
  return lunarPhaseNames[id] ?? (id || "未提供");
}

const pointGroups = {
  core: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"],
  angles: ["asc", "mc", "true_north_node", "true_south_node", "mean_lilith", "fortune", "spirit", "ic", "dsc", "vertex", "east_point"],
  lunar: ["mean_north_node", "mean_south_node", "true_lilith", "lunar_perigee", "anti_vertex", "west_point"],
  asteroids: ["chiron", "ceres", "pallas", "juno", "vesta", "pholus", "nessus", "chariklo", "asteroid_eros", "psyche", "eris", "sedna", "haumea", "makemake", "quaoar", "orcus", "ixion", "varuna", "astraea", "hygiea"],
  lots: ["lot_eros", "lot_necessity", "lot_courage", "lot_victory", "lot_nemesis", "lot_exaltation"],
  hamburg: ["cupido", "hades", "zeus", "kronos", "apollon", "admetos", "vulkanus", "poseidon"],
} as const;

const unavailableVirtualPoints = [
  { id: "syzygy", reason: "需先锁定朔望事件搜索与采用的朔望定义" },
  { id: "zi_qi", reason: "尚无已核定的天文身份与计算公式" },
] as const;

const majorAspectIds = ["conjunction", "opposition", "trine", "square", "sextile"];
const professionalAspectIds = [
  ...majorAspectIds,
  "semisextile", "semisquare", "sesquisquare", "quincunx", "quintile", "biquintile",
];

const pointGroupLabels: Record<keyof typeof pointGroups, string> = {
  core: "十大行星",
  angles: "虚点",
  lunar: "扩展敏感点",
  asteroids: "常用小行星",
  lots: "阿拉伯点",
  hamburg: "汉堡虚星",
};

const orbPointClassOptions = [
  ["luminary", "日月"], ["planet", "行星"], ["dwarf_planet", "矮行星"],
  ["angle", "轴点"], ["node", "月交点"], ["lunar_point", "月球点"],
  ["asteroid", "小行星"], ["centaur", "半人马体"], ["lot", "阿拉伯点"],
  ["hypothetical", "虚拟点"], ["sensitive_point", "敏感点"],
] as const;

const orbPointOptions = [...new Set(Object.values(pointGroups).flat())];

const fixedStarOptions = [
  ["aldebaran", "毕宿五 Aldebaran"], ["antares", "心宿二 Antares"], ["regulus", "轩辕十四 Regulus"],
  ["spica", "角宿一 Spica"], ["sirius", "天狼星 Sirius"], ["algol", "大陵五 Algol"],
  ["alcyone", "昴宿六 Alcyone"], ["achernar", "水委一 Achernar"], ["capella", "五车二 Capella"],
  ["arcturus", "大角星 Arcturus"], ["vega", "织女一 Vega"], ["altair", "河鼓二 Altair"],
  ["pollux", "北河三 Pollux"], ["castor", "北河二 Castor"], ["procyon", "南河三 Procyon"],
  ["fomalhaut", "北落师门 Fomalhaut"], ["polaris", "勾陈一 Polaris"], ["deneb", "天津四 Deneb"],
  ["rigel", "参宿七 Rigel"], ["betelgeuse", "参宿四 Betelgeuse"], ["canopus", "老人星 Canopus"],
  ["zuben_elgenubi", "氐宿一 Zuben Elgenubi"], ["zuben_eschamali", "氐宿四 Zuben Eschamali"],
  ["unukalhai", "蜀增一 Unukalhai"],
] as const;

const pointKindNames: Record<string, string> = {
  planet: "行星",
  angle: "轴点",
  node: "月交点",
  lunar_point: "月球点",
  asteroid: "小行星",
  lot: "阿拉伯点",
  hamburg: "汉堡虚星",
  sensitive_point: "敏感点",
};

const availabilityNames: Record<string, string> = {
  published: "已计算",
  available: "已计算",
  reference_fixture: "演示数据",
  experimental: "试验性结果",
  beta: "测试中",
  unavailable: "尚不可用",
  not_calculated: "尚未计算",
  blocked_by_input_quality: "输入条件不足",
};

const statusNames: Record<string, string> = {
  published: "已识别",
  available: "已识别",
  reference_fixture: "演示数据",
  uncertain: "不确定",
  unavailable: "尚不可用",
  not_calculated: "尚未计算",
  not_published: "规则尚未发布",
};

function availabilityLabel(value: unknown) {
  const key = String(value ?? "");
  return availabilityNames[key] ?? statusNames[key] ?? "计算结果";
}

const allPointGroupsEnabled: Record<keyof typeof pointGroups, boolean> = {
  core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: true,
};

const defaultModernGroups: NatalPointGroups = cloneNatalPointGroups(natalCalculationPresets[0].groups);

const defaultWheelGroups: Record<keyof typeof pointGroups, boolean> = {
  core: true, angles: true, lunar: true, asteroids: false, lots: false, hamburg: false,
};

const defaultWheelControls: Omit<NatalRenderControls, "visiblePointIds"> = {
  showDegreeTicks: true,
  showZodiacNames: true,
  showZodiacDegrees: true,
  showHouseLines: true,
  showHouseNumbers: true,
  showAxes: true,
  showPointLeaders: true,
  showPointDegrees: true,
  showFixedStarContacts: true,
  showAspectLines: true,
  showLegend: true,
  majorAspectsOnly: true,
  aspectFilterMode: "top_percent",
  aspectTopPercent: 15,
  aspectMinimumStrength: 0.7,
};

const allAspectIds = [
  "conjunction", "semiduodecile", "semioctile", "semisextile", "undecile", "decile", "novile", "semisquare", "septile",
  "sextile", "quintile", "square", "biseptile", "trine", "sesquisquare", "biquintile", "quincunx", "triseptile", "opposition",
];

const houseDomains = [
  "自我、身体与呈现", "金钱、资源与价值", "学习、表达与近距离环境", "家庭、根基与私人生活",
  "创造、恋爱与子女", "日常工作、技能与健康习惯", "伴侣、合作与公开关系", "共同资源、亲密与转化",
  "高等学习、信念与远行", "事业、目标与社会角色", "社群、人脉与长期愿景", "退隐、潜意识与幕后事务",
];

const pointFunctions: Record<string, string> = {
  sun: "核心意志、生命方向与自我认同", moon: "情绪反应、安全需要与习惯", mercury: "思考、学习与表达方式",
  venus: "价值、关系吸引与审美", mars: "行动、欲望、竞争与边界", jupiter: "扩展、信念与机会感",
  saturn: "责任、限制、结构与成熟", uranus: "独立、突破与非典型变化", neptune: "想象、理想化、渗透与边界",
  pluto: "深层驱力、控制与转化", asc: "外在呈现与进入世界的方式", mc: "公共方向、职业可见度与目标",
  dsc: "一对一关系中的他者模式", ic: "内在根基、家庭与归属", true_north_node: "被强调的发展方向",
  true_south_node: "熟悉的惯性与既有模式", fortune: "传统公式中的身体、环境与际遇指标", spirit: "传统公式中的意志与行动指标",
  lot_eros: "传统七大赫尔墨斯点中的欲望、吸引与关系趋向指标", lot_necessity: "传统七大赫尔墨斯点中的约束、义务与不可回避条件指标",
  lot_courage: "传统公式中的勇气、冲突与主动承担指标", lot_victory: "传统公式中的达成、支持与胜利条件指标",
  lot_nemesis: "传统公式中的阻碍、制约与后果指标", lot_exaltation: "传统公式中的提升、认可与显著化指标",
  vertex: "被动相遇与外部触发的关系敏感点", anti_vertex: "宿命点轴线的对点", east_point: "面向环境的呈现敏感点", west_point: "东方点轴线的对点",
  mean_north_node: "平滑化计算的发展方向", mean_south_node: "平滑化计算的熟悉路径", mean_lilith: "月球平远地点所指向的边界与疏离主题", true_lilith: "月球振荡远地点所指向的边界与疏离主题", lunar_perigee: "月球近地点所指向的本能与依附强度",
  chiron: "创伤经验、修复过程与经验转化", ceres: "照料、滋养、分离与安全感", pallas: "模式识别、策略与技巧", juno: "承诺、平等与长期契约", vesta: "专注、奉献与私人空间", pholus: "小触发引发的连锁变化", nessus: "权力边界与停止伤害循环", chariklo: "容纳、见证与疗愈边界", asteroid_eros: "欲望、迷恋与创造冲动", psyche: "敏感、信任与内在联结", eris: "排斥、不平等与挑战秩序", sedna: "孤立经验与重建力量", haumea: "再生、创造与身体自主", makemake: "生存智慧与资源适应", quaoar: "节律、规则与组织形式", orcus: "誓言、承诺与原则边界", ixion: "越界、特权与责任", varuna: "誓约、秩序与整体责任", astraea: "公平、判断与理想标准", hygiea: "预防、维护与日常健康秩序",
  cupido: "汉堡学派用于观察结合、群体、艺术与组织关系的假想点", hades: "汉堡学派用于观察隐蔽、消耗、陈旧与困难条件的假想点",
  zeus: "汉堡学派用于观察定向意志、创造冲动与发动能力的假想点", kronos: "汉堡学派用于观察权威、独立、地位与高标准的假想点",
  apollon: "汉堡学派用于观察扩展、知识、商业与多重连接的假想点", admetos: "汉堡学派用于观察收缩、凝固、耐力与停滞的假想点",
  vulkanus: "汉堡学派用于观察力量、强度、执行与巨大推动力的假想点", poseidon: "汉堡学派用于观察思想、精神取向、澄清与理念传播的假想点",
};

const signStyles: Record<string, string> = {
  aries: "直接、启动、竞争", taurus: "稳定、积累、感官", gemini: "交流、切换、好奇", cancer: "保护、情感、归属",
  leo: "创造、表现、中心感", virgo: "分析、改进、服务", libra: "协调、比较、关系", scorpio: "深入、控制、转化",
  sagittarius: "探索、信念、扩张", capricorn: "结构、责任、长期", aquarius: "独立、系统、群体", pisces: "感受、想象、融合",
};

const samplePoints: NatalPoint[] = [
  ["sun", "luminary", "pisces", 11.063, 7, false, 341.063], ["moon", "luminary", "capricorn", 15.659, 5, false, 285.659],
  ["mercury", "planet", "pisces", 11.632, 7, true, 341.632], ["venus", "planet", "aquarius", 15.012, 6, false, 315.012],
  ["mars", "planet", "aries", 13.864, 9, false, 13.864], ["jupiter", "planet", "taurus", 2.739, 9, false, 32.739],
  ["saturn", "planet", "taurus", 12.436, 9, false, 42.436], ["uranus", "planet", "aquarius", 18.17, 6, false, 318.17],
  ["neptune", "planet", "aquarius", 5.378, 6, false, 305.378], ["pluto", "dwarf_planet", "sagittarius", 12.845, 4, false, 252.845],
  ["asc", "angle", "leo", 22.945, 1, null, 142.945], ["dsc", "angle", "aquarius", 22.945, 7, null, 322.945],
  ["mc", "angle", "taurus", 15.83, 10, null, 45.83], ["ic", "angle", "scorpio", 15.83, 4, null, 225.83],
  ["true_north_node", "node", "leo", 1.87, 12, true, 121.87], ["true_south_node", "node", "aquarius", 1.87, 6, true, 301.87],
  ["chiron", "centaur", "sagittarius", 17.2, 4, false, 257.2], ["ceres", "asteroid", "capricorn", 7.4, 5, false, 277.4],
  ["fortune", "lot", "sagittarius", 27.5, 5, null, 267.5], ["spirit", "lot", "pisces", 24.6, 8, null, 354.6],
].map(([point_id, kind, sign, degree, house, retrograde, longitude]) => ({
  point_id: String(point_id), kind: String(kind), sign: String(sign), degree_in_sign: Number(degree),
  house: Number(house), retrograde: retrograde as boolean | null,
  motion_interpretation: retrograde === null ? "not_applicable" : "meaningful",
  position: { ecliptic: { longitude_deg: Number(longitude), latitude_deg: 0 }, velocity: { longitude_deg_per_day: retrograde ? -0.1 : 0.5 }, motion_state: retrograde ? "retrograde" : "direct" },
}));

const sampleHouses: NatalHouse[] = Array.from({ length: 12 }, (_, index) => {
  const asc = 142.945;
  const longitude = (asc + index * 30) % 360;
  const sign = signIds[Math.floor(longitude / 30)];
  return {
    number: index + 1, cusp_longitude_deg: longitude, sign, degree_in_sign: longitude % 30, span_deg: 30,
    traditional_ruler_ids: [], modern_ruler_ids: [],
    point_ids: samplePoints.filter((point) => point.house === index + 1).map((point) => point.point_id),
    intercepted_signs: [], repeated_cusp_sign: false,
  };
});

const sampleAspectDefinitions = [
  { type: "conjunction", angle: 0, orb: 8 },
  { type: "opposition", angle: 180, orb: 8 },
  { type: "trine", angle: 120, orb: 7 },
  { type: "square", angle: 90, orb: 7 },
  { type: "sextile", angle: 60, orb: 5 },
] as const;

// The opening workspace is a deterministic virtual fixture. Derive its complete
// major-aspect set from the displayed longitudes so the wheel, matrix and table
// always describe the same facts. Applying/separating is deliberately not faked:
// the real calculation service supplies that state from actual velocities.
const sampleAspects: NatalAspect[] = samplePoints.flatMap((left, leftIndex) =>
  samplePoints.slice(leftIndex + 1).flatMap((right) => {
    const rawDistance = Math.abs(left.position.ecliptic.longitude_deg - right.position.ecliptic.longitude_deg);
    const actualAngle = Math.min(rawDistance, 360 - rawDistance);
    const definition = sampleAspectDefinitions.find((candidate) => Math.abs(actualAngle - candidate.angle) <= candidate.orb);
    if (!definition) return [];
    const orb = Math.abs(actualAngle - definition.angle);
    return [{
      aspect_id: `sample:${left.point_id}:${right.point_id}:${definition.type}`,
      point_a: left.point_id,
      point_b: right.point_id,
      type: definition.type,
      exact_angle_deg: definition.angle,
      actual_angle_deg: Number(actualAngle.toFixed(6)),
      orb_deg: Number(orb.toFixed(6)),
      applying_state: "not_calculated_in_virtual_fixture",
      strength: Math.max(0, 1 - orb / definition.orb),
    }];
  }),
);

const sampleSnapshot: NatalSnapshot = {
  id: "sample-natal-20000301-beijing", status: "succeeded", maturity: "reference_fixture",
  input_fingerprint: "sha256:virtual-reference-fixture", engine: { name: "interstellar-core", version: "0.1.0-reference" }, warnings: [],
  result: {
    charts: [{ family: "natal", technique: "natal.standard_chart", status: "reference_fixture" }],
    points: samplePoints, houses: sampleHouses, aspects: sampleAspects,
    distributions: [
      { dimension: "elements", categories: [{ category_id: "fire", count: 2 }, { category_id: "earth", count: 3 }, { category_id: "air", count: 3 }, { category_id: "water", count: 2 }] },
      { dimension: "modalities", categories: [{ category_id: "cardinal", count: 3 }, { category_id: "fixed", count: 4 }, { category_id: "mutable", count: 3 }] },
    ],
    structure: { availability: "reference_fixture", note: "真实计算后显示半球、象限、角续果宫、群星与几何格局。" },
    classical: { availability: "reference_fixture", day_night_status: "day", note: "真实计算后显示昼夜盘、尊贵、太阳条件、接纳与定位星。" },
    dignities: [], lots: [], receptions: [], dispositors: {}, evidence: [],
    astronomical_context: { source: "virtual_reference_fixture", uncertainty: { mode: "exact_reference_fixture" }, day_night_status: "day" },
    output_manifest: [
      { output_id: "manifest.astronomy.ephemeris_core", status: "reference_fixture", result_pointer: "/result/points", view_ids: ["view.natal.basic"], table_ids: ["table.planet_positions", "table.planet_speeds"], export_formats: ["json"], algorithm_cards: ["ALG-ASTRONOMY-001"] },
      { output_id: "manifest.astronomy.houses_angles", status: "reference_fixture", result_pointer: "/result/houses", view_ids: ["wheel.natal", "view.natal.houses"], table_ids: ["table.house_cusps"], export_formats: ["json"], algorithm_cards: ["ALG-ASTRONOMY-003"] },
      { output_id: "manifest.astronomy.aspects", status: "reference_fixture", result_pointer: "/result/aspects", view_ids: ["wheel.natal", "view.natal.aspects"], table_ids: ["table.natal_aspects"], export_formats: ["json"], algorithm_cards: ["ALG-ASTRONOMY-004"] },
      { output_id: "manifest.natal.patterns_distributions", status: "reference_fixture", result_pointer: "/result/structure", view_ids: ["view.natal.structure"], table_ids: ["table.elements", "table.modalities", "table.polarity", "table.chart_patterns"], export_formats: ["json"], algorithm_cards: ["ALG-NATAL-003"] },
      { output_id: "manifest.natal.dignity_reception", status: "reference_fixture", result_pointer: "/result/classical", view_ids: ["view.natal.classical"], table_ids: ["table.essential_dignities", "table.receptions", "graph.dispositor_chain", "table.sect_condition"], export_formats: ["json"], algorithm_cards: ["ALG-NATAL-004"] },
      { output_id: "manifest.natal.standard_chart", status: "reference_fixture", result_pointer: "/result/charts/0", view_ids: ["wheel.natal", "view.natal.technical_document"], table_ids: [], export_formats: ["json"], algorithm_cards: ["ALG-NATAL-001"] },
    ],
  },
};

const defaultPerson: NatalPersonInput = {
  displayName: "", relation: "self", localDate: "2000-03-01", localTime: "16:30", timezoneId: "Asia/Shanghai",
  timePrecision: "minute", placeName: "北京", countryCode: "CN", latitude: 39.93, longitude: 116.41,
  timeConfidence: "high", timezoneStatus: "resolved",
};

const defaultSettings: NatalCalculationSettings = cloneNatalSettings(natalCalculationPresets[0].settings);
const defaultTimingSettings: NatalCalculationSettings = cloneNatalSettings(timingCalculationPresets[0].settings);
const defaultTimingGroups: NatalPointGroups = cloneNatalPointGroups(timingCalculationPresets[0].groups);

function effectivePointIds(
  settings: NatalCalculationSettings,
  groups: Record<keyof typeof pointGroups, boolean>,
) {
  return (Object.entries(groups) as Array<[keyof typeof pointGroups, boolean]>)
    .filter(([, enabled]) => enabled)
    .flatMap(([group]) => [...pointGroups[group]])
    .filter((pointId) => {
      if (settings.disabledPointIds.includes(pointId)) return false;
      if (settings.nodeType === "true") return !pointId.startsWith("mean_north_node") && !pointId.startsWith("mean_south_node");
      if (settings.nodeType === "mean") return !pointId.startsWith("true_north_node") && !pointId.startsWith("true_south_node");
      return true;
    });
}

function formatDegree(value: number) {
  const totalSeconds = Math.round(value * 3600);
  const degree = Math.floor(totalSeconds / 3600);
  const remainder = totalSeconds % 3600;
  const minute = Math.floor(remainder / 60);
  const second = remainder % 60;
  return `${degree}°${String(minute).padStart(2, "0")}′${String(second).padStart(2, "0")}″`;
}

function pointPlacementLabel(point: NatalPoint, dateLevel: boolean) {
  return `${dateLevel ? "≈ " : ""}${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)}`;
}

function pointHouseLabel(point: NatalPoint) {
  return point.house == null ? "未计算（时刻未知）" : `第${point.house}宫`;
}

function pointMotionLabel(point: NatalPoint, dateLevel: boolean) {
  if (dateLevel && point.status_refs?.some((item) => item.includes("motion_state_changes"))) return "日期内可能变化";
  if (point.motion_interpretation === "not_applicable") return "不适用";
  return point.retrograde ? "逆行" : "顺行";
}

function pointUncertaintyLabel(point: NatalPoint) {
  if (point.position.uncertainty_arcsec == null) return "";
  return `日期范围 ±${(point.position.uncertainty_arcsec / 3600).toFixed(4)}°`;
}

function toPlain(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  return JSON.stringify(value, null, 2);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function asRecords(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value.map(asRecord) : [];
}

function asStrings(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String) : [];
}

function renderGuideInline(value: string): ReactNode[] {
  return value.split(/(\*\*[^*]+\*\*)/g).filter(Boolean).map((part, index) =>
    part.startsWith("**") && part.endsWith("**")
      ? <strong key={`${index}:${part}`}>{part.slice(2, -2)}</strong>
      : part,
  );
}

function SafeMarkdownDocument({ markdown }: { markdown: string }) {
  const lines = markdown.split("\n");
  const content: ReactNode[] = [];
  let index = 0;
  const isSpecialLine = (line: string) =>
    !line.trim()
    || /^#{1,3}\s/.test(line)
    || line.trim() === "---"
    || line.startsWith("> ")
    || line.startsWith("- ")
    || /^\d+\.\s/.test(line)
    || line.startsWith("|")
    || line.startsWith("```");

  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) { index += 1; continue; }
    if (line.startsWith("```")) {
      const code: string[] = [];
      index += 1;
      while (index < lines.length && !lines[index].startsWith("```")) {
        code.push(lines[index]);
        index += 1;
      }
      index += 1;
      content.push(<pre key={`code-${index}`}><code>{code.join("\n")}</code></pre>);
      continue;
    }
    if (line.startsWith("### ")) { content.push(<h3 key={`h3-${index}`}>{renderGuideInline(line.slice(4))}</h3>); index += 1; continue; }
    if (line.startsWith("## ")) { content.push(<h2 key={`h2-${index}`}>{renderGuideInline(line.slice(3))}</h2>); index += 1; continue; }
    if (line.startsWith("# ")) { content.push(<h1 key={`h1-${index}`}>{renderGuideInline(line.slice(2))}</h1>); index += 1; continue; }
    if (line.trim() === "---") { content.push(<hr key={`hr-${index}`} />); index += 1; continue; }
    if (line.startsWith("> ")) { content.push(<blockquote key={`quote-${index}`}>{renderGuideInline(line.slice(2))}</blockquote>); index += 1; continue; }
    if (line.startsWith("|")) {
      const rows: string[][] = [];
      while (index < lines.length && lines[index].startsWith("|")) {
        rows.push(lines[index].slice(1, -1).split("|").map((cell) => cell.trim()));
        index += 1;
      }
      const [head, separator, ...body] = rows;
      const tableBody = separator?.every((cell) => /^:?-{3,}:?$/.test(cell)) ? body : rows.slice(1);
      content.push(<div className="natal-guide-table" key={`table-${index}`}><table><thead><tr>{head.map((cell, cellIndex) => <th key={cellIndex}>{renderGuideInline(cell)}</th>)}</tr></thead><tbody>{tableBody.map((row, rowIndex) => <tr key={rowIndex}>{row.map((cell, cellIndex) => <td key={cellIndex}>{renderGuideInline(cell)}</td>)}</tr>)}</tbody></table></div>);
      continue;
    }
    if (line.startsWith("- ")) {
      const items: string[] = [];
      while (index < lines.length && lines[index].startsWith("- ")) { items.push(lines[index].slice(2)); index += 1; }
      content.push(<ul key={`ul-${index}`}>{items.map((item, itemIndex) => <li key={itemIndex}>{renderGuideInline(item)}</li>)}</ul>);
      continue;
    }
    if (/^\d+\.\s/.test(line)) {
      const items: string[] = [];
      while (index < lines.length && /^\d+\.\s/.test(lines[index])) { items.push(lines[index].replace(/^\d+\.\s/, "")); index += 1; }
      content.push(<ol key={`ol-${index}`}>{items.map((item, itemIndex) => <li key={itemIndex}>{renderGuideInline(item)}</li>)}</ol>);
      continue;
    }
    const paragraph = [line.trim()];
    index += 1;
    while (index < lines.length && !isSpecialLine(lines[index])) { paragraph.push(lines[index].trim()); index += 1; }
    content.push(<p key={`p-${index}`}>{renderGuideInline(paragraph.join(" "))}</p>);
  }
  return <>{content}</>;
}

function isDateLevelSnapshot(snapshot: NatalSnapshot): boolean {
  return asRecord(asRecord(snapshot.result.astronomical_context).uncertainty).mode === "civil_day_range";
}

function pointList(value: unknown): string {
  return asStrings(value).map((id) => pointNames[id] ?? id).join("、") || "—";
}

const dignityNames: Record<string, string> = {
  domicile: "入庙", exaltation: "擢升", triplicity: "三分性", term: "界", face: "十度区间／面",
  detriment: "失势", fall: "落陷", peregrine: "游走",
};

const solarRelationNames: Record<string, string> = {
  cazimi: "日核", combust: "燃烧", under_beams: "光束下", free_of_beams: "脱离光束", self: "太阳本身", not_applicable: "不适用",
};

const structureCategoryNames: Record<string, string> = {
  fire: "火", earth: "土", air: "风", water: "水",
  cardinal: "基本", fixed: "固定", mutable: "变动", positive: "阳性", negative: "阴性",
  east: "东方半球", west: "西方半球", above: "上半球", below: "下半球",
  quadrant_1: "第一象限", quadrant_2: "第二象限", quadrant_3: "第三象限", quadrant_4: "第四象限",
  angular: "角宫", succedent: "续宫", cadent: "果宫",
};

const distributionNames: Record<string, string> = {
  elements: "四元素", modalities: "三模式", polarities: "阴阳属性",
};

const patternNames: Record<string, string> = {
  grand_trine: "大三角", t_square: "T 三角", grand_cross: "大十字", yod: "Yod",
  kite: "风筝", mystic_rectangle: "神秘矩形", sign: "同星座群星", house: "同宫群星", longitude: "经度群星",
};

function buildLocalInterpretation(target: InterpretationTarget, snapshot: NatalSnapshot): ItemInterpretation {
  const fixtureLayer = (
    itemKind: string,
    label: string,
    status: "published" | "unavailable" | "not_applicable" | "blocked_by_input_quality",
    fact: Record<string, unknown>,
    meaning?: string,
    unavailableReason?: string,
  ): NonNullable<ItemInterpretation["layers"]>[number] => ({
    item_kind: itemKind,
    label,
    status,
    fact,
    meaning,
    unavailable_reason: unavailableReason,
    warnings: [],
    content_hash: `reference-fixture:${snapshot.input_fingerprint}:${target.id}:${itemKind}`,
    rule_ref: `reference_fixture.${itemKind}.v1`,
    template_version: "1.0.0",
    maturity: "Reference fixture",
    source_refs: ["internal.authored.natal-reference-fixture.v1"],
  });
  if (target.type === "point") {
    const point = snapshot.result.points.find((item) => item.point_id === target.id);
    if (!point) return { status: "unavailable", unavailable_reason: "未找到对应点位事实。" };
    const fn = pointFunctions[point.point_id] ?? "此点位的专门解释模板尚未发布";
    const style = signStyles[point.sign] ?? "该星座的表达方式";
    const dateLevel = isDateLevelSnapshot(snapshot);
    const domain = point.house ? houseDomains[point.house - 1] : "宫位未计算（需要可靠出生时刻）";
    const pointLabel = pointNames[point.point_id] ?? point.point_id;
    const signLabel = signNames[point.sign] ?? point.sign;
    const pointFact = {
      point_id: point.point_id,
      sign_id: point.sign,
      degree_in_sign: point.degree_in_sign,
      house: point.house,
      motion_state: point.position.motion_state,
      retrograde: point.retrograde,
    };
    const intrinsicPublished = Boolean(pointFunctions[point.point_id]);
    const signPublished = Boolean(signStyles[point.sign]) && intrinsicPublished;
    const layers: NonNullable<ItemInterpretation["layers"]> = [
      fixtureLayer(
        "point_intrinsic",
        "星体自身功能",
        intrinsicPublished ? "published" : "unavailable",
        pointFact,
        intrinsicPublished ? `${pointLabel}：${fn}。` : undefined,
        intrinsicPublished ? undefined : "POINT_INTRINSIC_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "point_in_sign",
        "星座表达方式",
        signPublished ? "published" : "unavailable",
        pointFact,
        signPublished ? `${pointLabel}落在${signLabel}：这项功能倾向${style}。` : undefined,
        signPublished ? undefined : "POINT_OR_SIGN_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "point_in_house",
        "所在宫位领域",
        dateLevel || point.house == null ? "blocked_by_input_quality" : intrinsicPublished ? "published" : "unavailable",
        pointFact,
        !dateLevel && point.house != null && intrinsicPublished
          ? `${pointLabel}落在第${point.house}宫：这项功能主要通过${domain}被体验和表达。`
          : undefined,
        dateLevel || point.house == null ? "MISSING_HOUSE_ASSIGNMENT" : intrinsicPublished ? undefined : "POINT_INTRINSIC_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "motion",
        "运动状态",
        point.motion_interpretation === "not_applicable" ? "not_applicable" : "published",
        pointFact,
        point.motion_interpretation === "not_applicable"
          ? undefined
          : `${pointLabel}${point.retrograde ? "逆行" : "顺行"}；这是运动状态，不单独表示吉凶。`,
        point.motion_interpretation === "not_applicable" ? "MOTION_INTERPRETATION_NOT_APPLICABLE" : undefined,
      ),
    ];
    return {
      status: "available", title: `${pointNames[point.point_id] ?? point.point_id} · ${signNames[point.sign] ?? point.sign}${point.house ? ` · 第${point.house}宫` : ""}`,
      facts: target.facts ?? [target.fact, `运动状态：${point.retrograde === true ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"}`],
      meaning: dateLevel
        ? `${fn}。日期范围内的参考位置落在${signNames[point.sign] ?? point.sign}，可用“${style}”作为星座层阅读；这不是伪造的出生时刻。`
        : `${fn}，通过“${style}”的方式表达，主要落在“${domain}”这一生活领域。`,
      synthesis: dateLevel
        ? "出生时刻未知，因此不生成上升、宫位、相位、阿拉伯点、昼夜体系或其他时刻依赖结论；若该点在日期内跨星座或改变运动状态，必须同时阅读不确定范围。"
        : "这是结构化单项解释，不替代整盘综合；相位、宫主星、尊贵与重复主题可能强化、修正或抵消这条倾向。",
      rule_refs: ["reporting.contextual_item_interpretation.v1", "natal.point_sign_house.composition.v1"],
      source_refs: ["internal.authored.natal-basic-template.v1"], template_version: "1.0.0", maturity: "Beta",
      content_hash: layers.map((layer) => layer.content_hash).join(" · "),
      layers,
    };
  }
  if (target.type === "house") {
    const house = snapshot.result.houses.find((item) => String(item.number) === target.id);
    const houseMeaning = house
      ? `第${house.number}宫对应“${houseDomains[house.number - 1]}”。宫头落在${signNames[house.sign] ?? house.sign}，表示这个领域倾向以“${signStyles[house.sign] ?? "对应星座"}”的方式启动。`
      : undefined;
    return house ? {
      status: "available", title: `第${house.number}宫 · ${signNames[house.sign] ?? house.sign}`,
      facts: [target.fact, `宫内点位：${house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}`],
      meaning: houseMeaning,
      synthesis: "完整判断还需要宫主星落座、落宫、相位、宫内天体和宫位制共同参与。",
      rule_refs: ["natal.house.cusp_ruler.v1"], source_refs: ["internal.authored.house-domain.v1"], template_version: "1.0.0", maturity: "Beta",
      layers: [fixtureLayer("house_cusp_ruler", "宫头与宫主链", "published", house as unknown as Record<string, unknown>, houseMeaning)],
    } : { status: "unavailable", unavailable_reason: "未找到宫位事实。" };
  }
  if (target.type === "aspect") {
    const aspect = snapshot.result.aspects.find((item) => item.aspect_id === target.id);
    if (!aspect) return { status: "unavailable", unavailable_reason: "未找到相位事实。" };
    const interaction: Record<string, string> = {
      conjunction: "两种功能紧密融合并彼此放大", opposition: "两端形成拉扯，需要在关系或情境中寻找平衡", square: "两种功能形成摩擦并推动行动",
      trine: "两种功能较自然地互相支持", sextile: "两种功能存在可被主动使用的协作机会", quincunx: "两种功能需要持续调整",
    };
    const aspectMeaning = `${pointNames[aspect.point_a] ?? aspect.point_a}与${pointNames[aspect.point_b] ?? aspect.point_b}${interaction[aspect.type] ?? "形成一种需要结合具体定义阅读的关系"}。`;
    const phase = aspectPhaseLabel(aspect.applying_state);
    return {
      status: "available", title: target.title, facts: [target.fact, ...(phase ? [`阶段：${phase}`] : []), `强度：${Math.round(aspect.strength * 100)}%`],
      meaning: aspectMeaning,
      synthesis: "容许度越小通常越接近精确；入相/出相只在两点运动语义都明确时判断。次要相位不应压过太阳、月亮、四轴和紧密主要相位。",
      rule_refs: aspect.rule_refs ?? ["official.aspects.professional_natal.v1"], source_refs: ["internal.authored.aspect-template.v1"], template_version: "1.0.0", maturity: "Beta",
      layers: [fixtureLayer("natal_aspect", "相位互动", "published", aspect as unknown as Record<string, unknown>, aspectMeaning)],
    };
  }
  return {
    status: "unavailable", title: target.title, facts: [target.fact],
    unavailable_reason: "REFERENCE_FIXTURE_SEMANTIC_RULE_UNAVAILABLE",
    synthesis: "请与点位、宫位、相位以及其他同向或反向证据一起阅读。",
    rule_refs: [target.type === "classical" ? "ALG-NATAL-004" : "ALG-NATAL-003"],
    source_refs: ["interstellar.versioned-rule-pack"], template_version: "1.0.0", maturity: "Experimental",
    layers: [fixtureLayer(
      target.type === "classical" ? "classical_condition" : "structure_indicator",
      target.type === "classical" ? "古典条件" : "盘面结构",
      "unavailable",
      { reference_fact: target.fact },
      undefined,
      "REFERENCE_FIXTURE_SEMANTIC_RULE_UNAVAILABLE",
    )],
  };
}

function buildLocalTechnicalDocument(snapshot: NatalSnapshot, subjectName: string) {
  const distributions = snapshot.result.distributions ?? [];
  const dignities = snapshot.result.dignities ?? [];
  const lots = snapshot.result.lots ?? [];
  const lines = [
    `# ${subjectName} · 本命盘分析数据`, "", "> 可复制给占星师或外部模型继续分析。", "",
    "## 完整点位", "", "| 点位 | 星座度数 | 宫位 | 运动 | 黄经 |", "|---|---:|---:|---|---:|",
    ...snapshot.result.points.map((point) => `| ${pointNames[point.point_id] ?? point.point_id} | ${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)} | ${point.house ?? "—"} | ${point.retrograde ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"} | ${point.position.ecliptic.longitude_deg.toFixed(6)}° |`),
    "", "## 十二宫", "", ...snapshot.result.houses.map((house) => `- 第${house.number}宫：${signNames[house.sign] ?? house.sign} ${formatDegree(house.degree_in_sign)}；点位 ${house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}`),
    "", "## 完整相位", "", ...snapshot.result.aspects.map((aspect) => {
      const phase = aspectPhaseLabel(aspect.applying_state);
      return `- ${pointNames[aspect.point_a] ?? aspect.point_a} ${aspectNames[aspect.type] ?? aspect.type} ${pointNames[aspect.point_b] ?? aspect.point_b}；容许度 ${aspect.orb_deg.toFixed(3)}°${phase ? `；${phase}` : ""}；强度 ${Math.round(aspect.strength * 100)}%`;
    }),
    "", "## 分布与盘面结构", "",
    ...distributions.flatMap((distribution) => [
      `- ${distributionNames[distribution.dimension] ?? distribution.dimension}：${distribution.categories.map((category) => `${structureCategoryNames[category.category_id] ?? category.category_id} ${category.percentage?.toFixed(2) ?? "—"}%`).join("；")}`,
    ]),
    ...((snapshot.result.patterns ?? []).map((pattern) => { const row = asRecord(pattern); return `- 格局：${patternNames[String(row.pattern_type ?? row.kind)] ?? String(row.pattern_type ?? row.kind ?? "未命名格局")}；参与点位 ${pointList(row.participant_ids)}`; })),
    "", "## 古典与希腊化事实", "",
    ...dignities.map((raw) => { const row = asRecord(raw); return `- ${pointNames[String(row.point_id)] ?? String(row.point_id)}：尊贵 ${asRecords(row.dignities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)).join("、") || "无"}；失势/落陷 ${asRecords(row.debilities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)).join("、") || "无"}；游走 ${row.peregrine === true ? "是" : row.peregrine === false ? "否" : "不适用"}`; }),
    ...lots.map((raw) => { const lot = asRecord(raw); return `- ${pointNames[String(lot.lot_id)] ?? String(lot.lot_id)}：${signNames[String(lot.sign_id)] ?? String(lot.sign_id)} ${formatDegree(Number(lot.degree_in_sign ?? 0))}；公式 ${String(lot.formula_expression ?? "—")}`; }),
    "", "## 输入质量与分析提醒", "", ...(snapshot.warnings.length ? snapshot.warnings.map((warning) => `- ${warning.message}`) : ["- 没有影响本次分析范围的计算警告。"]),
  ];
  return lines.join("\n");
}

function NatalWheel({ snapshot, renderSpec, controls }: { snapshot: NatalSnapshot; renderSpec: RenderSpec; controls: NatalRenderControls }) {
  const dateLevel = isDateLevelSnapshot(snapshot);
  const variant = renderSpec.options.variant;
  const professional = variant === "professional";
  const hasLayer = (layer: string) => renderSpec.layers.includes(layer);
  const compactPointIds = [...pointGroups.core, "asc", "dsc", "mc", "ic", "true_north_node", "chiron", "fortune", "spirit"];
  const visiblePointIds = new Set(controls.visiblePointIds);
  const points = snapshot.result.points
    .filter((point) => visiblePointIds.has(point.point_id))
    .filter((point) => professional || compactPointIds.includes(point.point_id))
    .sort((a, b) => a.position.ecliptic.longitude_deg - b.position.ecliptic.longitude_deg);
  const asc = snapshot.result.points.find((point) => point.point_id === "asc")?.position.ecliptic.longitude_deg
    ?? snapshot.result.houses[0]?.cusp_longitude_deg ?? 0;
  const angleFor = (longitude: number) => (180 - (longitude - asc)) * Math.PI / 180;
  const xy = (longitude: number, radius: number) => ({
    x: Number((320 + Math.cos(angleFor(longitude)) * radius).toFixed(6)),
    y: Number((320 - Math.sin(angleFor(longitude)) * radius).toFixed(6)),
  });
  const pointById = new Map(snapshot.result.points.map((point) => [point.point_id, point]));
  const angularDistance = (left: number, right: number) => Math.abs(((left - right + 540) % 360) - 180);
  const placed: Array<{ longitude: number; lane: number }> = [];
  const pointLayouts = points.map((point) => {
    const longitude = point.position.ecliptic.longitude_deg;
    const laneCount = professional ? 5 : 3;
    const lane = Array.from({ length: laneCount }, (_, index) => index).find((candidate) =>
      !placed.some((item) => item.lane === candidate && angularDistance(item.longitude, longitude) < (professional ? 6.5 : 10)),
    ) ?? placed.length % laneCount;
    placed.push({ longitude, lane });
    return {
      point,
      anchor: xy(longitude, professional ? 253 : 232),
      label: xy(longitude, professional ? 239 - lane * 11.5 : 207 - lane * 19),
      lane,
    };
  });
  const axes = [["asc", "ASC"], ["dsc", "DSC"], ["mc", "MC"], ["ic", "IC"]] as const;
  const majorAspectTypes = new Set(["conjunction", "opposition", "trine", "square", "sextile"]);
  const visibleAspects = selectVisibleNatalAspects(snapshot, controls);
  const aspectPointIds = new Set(visibleAspects.flatMap((aspect) => [aspect.point_a, aspect.point_b]));
  const aspectRadius = professional ? 143 : 156;
  const fixedStarContacts = new Set((snapshot.result.fixed_star_contacts ?? []).map((item) => item.star_id));
  const contactedFixedStars = (snapshot.result.fixed_stars ?? []).filter((star) => fixedStarContacts.has(star.star_id));
  return (
    <svg className={`natal-wheel ${professional ? "professional-wheel" : "compact-wheel"}`} viewBox="0 0 640 640" role="img" aria-label={renderSpec.accessibility.title} data-render-view={renderSpec.view_id} data-snapshot-id={snapshot.id}>
      <metadata>{JSON.stringify(renderSpec)}</metadata>
      <title>{renderSpec.accessibility.title}</title>
      <desc>{renderSpec.accessibility.description}</desc>
      <circle cx="320" cy="320" r="306" className="wheel-outer" />
      <circle cx="320" cy="320" r="292" className="wheel-ring degree-ring" />
      <circle cx="320" cy="320" r="257" className="wheel-ring zodiac-ring" />
      <circle cx="320" cy="320" r={professional ? "190" : "176"} className="wheel-ring point-band-ring" />
      <circle cx="320" cy="320" r={professional ? "154" : "166"} className="wheel-ring house-number-ring" />
      <circle cx="320" cy="320" r={aspectRadius} className="wheel-ring aspect-stage-ring" />
      {hasLayer("degree_ticks") && Array.from({ length: 360 }, (_, degree) => {
        if (!professional && degree % 5 !== 0) return null;
        const outer = xy(degree, 304);
        const tickLength = degree % 10 === 0 ? 11 : degree % 5 === 0 ? 7 : 3.5;
        const inner = xy(degree, 304 - tickLength);
        return <line key={`degree-tick-${degree}`} x1={inner.x} y1={inner.y} x2={outer.x} y2={outer.y} className={`degree-tick ${degree % 10 === 0 ? "major" : degree % 5 === 0 ? "medium" : "minor"}`} />;
      })}
      {hasLayer("zodiac") && Array.from({ length: 12 }, (_, index) => {
        const boundary = xy(index * 30, 304);
        const inner = xy(index * 30, 257);
        const label = xy(index * 30 + 15, professional ? 279 : 275);
        const name = xy(index * 30 + 15, 264);
        return <g key={`sign-${index}`}><line x1={inner.x} y1={inner.y} x2={boundary.x} y2={boundary.y} className="sign-line" /><text x={label.x} y={label.y} className="sign-glyph">{signGlyphs[index]}</text>{renderSpec.labels.zodiac_names && <text x={name.x} y={name.y} className="sign-name-label">{signNames[signIds[index]]}</text>}{renderSpec.labels.zodiac_degrees && [0, 10, 20].map((degree) => { const tickLabel = xy(index * 30 + degree + 1.3, 297); return <text key={degree} x={tickLabel.x} y={tickLabel.y} className="sign-degree-label">{degree}°</text>; })}</g>;
      })}
      {hasLayer("houses") && snapshot.result.houses.map((house) => {
        const end = xy(house.cusp_longitude_deg, 257);
        const start = xy(house.cusp_longitude_deg, professional ? 154 : 0);
        const number = xy(house.cusp_longitude_deg + house.span_deg / 2, professional ? 171 : 184);
        const isAxis = [1, 4, 7, 10].includes(house.number);
        return <g key={`house-${house.number}`}>{controls.showHouseLines && <line x1={professional ? start.x : 320} y1={professional ? start.y : 320} x2={end.x} y2={end.y} className={isAxis ? "house-line axis" : "house-line"} />}{renderSpec.labels.house_numbers && <text x={number.x} y={number.y} className="house-number">{house.number}</text>}</g>;
      })}
      {hasLayer("aspect_stage") && [...aspectPointIds].map((pointId) => {
        const point = pointById.get(pointId);
        if (!point) return null;
        const longitude = point.position.ecliptic.longitude_deg;
        const outer = xy(longitude, professional ? 154 : 166);
        const anchor = xy(longitude, aspectRadius);
        return <g key={`aspect-anchor-${pointId}`} className="aspect-anchor-group"><line x1={outer.x} y1={outer.y} x2={anchor.x} y2={anchor.y} className="aspect-anchor-spoke" /><circle cx={anchor.x} cy={anchor.y} r={professional ? "2.8" : "2.2"} className="aspect-anchor-dot" /></g>;
      })}
      {hasLayer("aspect_lines") && visibleAspects.map((aspect) => {
        const a = pointById.get(aspect.point_a); const b = pointById.get(aspect.point_b);
        if (!a || !b) return null;
        const start = xy(a.position.ecliptic.longitude_deg, aspectRadius); const end = xy(b.position.ecliptic.longitude_deg, aspectRadius);
        const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
        const soft = ["trine", "sextile", "quintile", "biquintile"].includes(aspect.type);
        const className = `aspect-line ${hard ? "hard" : soft ? "soft" : "neutral"} ${majorAspectTypes.has(aspect.type) ? "major" : "minor"}`;
        return <line key={aspect.aspect_id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={className} data-aspect={aspect.type} style={{ strokeWidth: majorAspectTypes.has(aspect.type) ? 1.05 + aspect.strength * 1.25 : .55 + aspect.strength * .55, opacity: majorAspectTypes.has(aspect.type) ? .5 + aspect.strength * .38 : .16 + aspect.strength * .2 }} />;
      })}
      {hasLayer("axes") && axes.map(([pointId, label]) => {
        const point = pointById.get(pointId);
        if (!point) return null;
        const end = xy(point.position.ecliptic.longitude_deg, 304);
        const tag = xy(point.position.ecliptic.longitude_deg, 316);
        return <g key={`axis-${pointId}`}><line x1="320" y1="320" x2={end.x} y2={end.y} className={`wheel-axis wheel-axis-${pointId}`} /><text x={tag.x} y={tag.y} className="wheel-axis-label">{label}</text></g>;
      })}
      {hasLayer("points") && pointLayouts.map(({ point, anchor, label, lane }) => {
        const glyph = pointGlyphs[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? "•";
        const shortLabel = wheelPointLabels[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? glyph;
        return <g key={point.point_id} className={`wheel-point wheel-point-${point.kind ?? "other"} wheel-point-id-${point.point_id}`} data-lane={lane}>{renderSpec.labels.point_leaders && <line x1={anchor.x} y1={anchor.y} x2={label.x} y2={label.y} className="point-leader" />}<circle cx={anchor.x} cy={anchor.y} r="2.5" className="point-anchor" />{professional ? <g transform={`translate(${label.x} ${label.y})`}><text className="professional-point-label" y="0">{shortLabel}</text>{point.retrograde && <text x="9" y="-8" className="point-retrograde">R</text>}{renderSpec.labels.point_degrees && <text x="0" y="10" className="point-degree-label">{Math.floor(point.degree_in_sign)}°{Math.round((point.degree_in_sign % 1) * 60).toString().padStart(2, "0")}′</text>}</g> : <g transform={`translate(${label.x} ${label.y})`}><circle r="13" className="planet-dot" /><text className="planet-glyph" y="1">{glyph}</text>{point.retrograde && <text x="13" y="-12" className="point-retrograde">R</text>}</g>}</g>;
      })}
      {hasLayer("fixed_star_contacts") && contactedFixedStars.map((star) => {
        const longitude = star.position.ecliptic.longitude_deg;
        const inner = xy(longitude, 191);
        const outer = xy(longitude, 201);
        const label = xy(longitude, 207);
        return <g key={`fixed-star-${star.star_id}`} className="wheel-fixed-star"><title>{star.label_zh} · {star.name} · {signNames[star.sign] ?? star.sign} {formatDegree(star.degree_in_sign)}</title><line x1={inner.x} y1={inner.y} x2={outer.x} y2={outer.y} /><text x={label.x} y={label.y}>★</text></g>;
      })}
      <circle cx="320" cy="320" r={professional ? "43" : "54"} className="wheel-core" />
      <text x="320" y={professional ? "316" : "306"} className="wheel-core-title">{dateLevel ? "DATE RANGE" : professional ? "本命" : "NATAL"}</text>
      <text x="320" y={professional ? "330" : "329"} className="wheel-core-sub">{dateLevel ? `${points.length} 点 · 时刻未知` : `${points.length} 点 · ${visibleAspects.length}/${snapshot.result.aspects.length} 相位线`}</text>
      {hasLayer("legend") && !dateLevel && professional && <g className="wheel-legend"><line x1="266" y1="371" x2="284" y2="371" className="aspect-line hard major" /><text x="288" y="374">张力</text><line x1="322" y1="371" x2="340" y2="371" className="aspect-line soft major" /><text x="344" y="374">支持</text></g>}
    </svg>
  );
}

function ComparisonWheel({
  natalSnapshot,
  movingSnapshot,
  comparison,
  renderSpec,
  controls,
  chartLabel,
  movingLabel,
}: {
  natalSnapshot: NatalSnapshot;
  movingSnapshot: NatalSnapshot;
  comparison: ChartComparison;
  renderSpec: RenderSpec;
  controls: NatalRenderControls;
  chartLabel: string;
  movingLabel: string;
}) {
  const asc = natalSnapshot.result.points.find((point) => point.point_id === "asc")?.position.ecliptic.longitude_deg
    ?? natalSnapshot.result.houses[0]?.cusp_longitude_deg ?? 0;
  const angleFor = (longitude: number) => (180 - (longitude - asc)) * Math.PI / 180;
  const xy = (longitude: number, radius: number) => ({
    x: Number((320 + Math.cos(angleFor(longitude)) * radius).toFixed(6)),
    y: Number((320 - Math.sin(angleFor(longitude)) * radius).toFixed(6)),
  });
  const natalPoints = new Map(natalSnapshot.result.points.map((point) => [point.point_id, point]));
  const movingPoints = new Map(movingSnapshot.result.points.map((point) => [point.point_id, point]));
  const movingVisible = movingSnapshot.result.points
    .filter((point) => controls.visiblePointIds.includes(point.point_id))
    .filter((point) => [...pointGroups.core, "true_north_node", "mean_north_node"].includes(point.point_id))
    .sort((left, right) => left.position.ecliptic.longitude_deg - right.position.ecliptic.longitude_deg);
  const strongestCrossAspects = [...comparison.result.cross_aspects]
    .sort((left, right) => right.strength - left.strength || left.orb_deg - right.orb_deg)
    .slice(0, Math.max(6, Math.ceil(comparison.result.cross_aspects.length * 0.15)));
  return <div className="transit-wheel-stack">
    <NatalWheel snapshot={natalSnapshot} renderSpec={renderSpec} controls={controls} />
    <svg className="transit-wheel-overlay" viewBox="0 0 640 640" role="img" aria-label={`${chartLabel}外圈与跨盘相位`}>
      <title>{chartLabel}外圈与跨盘相位</title>
      <desc>本命盘作为固定内层，{movingLabel}作为变化层，并连接最明显的跨盘相位。</desc>
      <circle cx="320" cy="320" r="220" className="transit-layer-ring" />
      {strongestCrossAspects.map((aspect) => {
        const moving = movingPoints.get(aspect.moving_point_id);
        const reference = natalPoints.get(aspect.reference_point_id);
        if (!moving || !reference) return null;
        const start = xy(moving.position.ecliptic.longitude_deg, 138);
        const end = xy(reference.position.ecliptic.longitude_deg, 138);
        const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
        return <line key={aspect.aspect_id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={`transit-cross-aspect ${hard ? "hard" : "soft"}`} style={{ opacity: .25 + aspect.strength * .55 }} />;
      })}
      {movingVisible.map((point) => {
        const longitude = point.position.ecliptic.longitude_deg;
        const anchor = xy(longitude, 220);
        const label = xy(longitude, 207);
        return <g key={`transit-${point.point_id}`} className="transit-moving-point"><line x1={anchor.x} y1={anchor.y} x2={label.x} y2={label.y} /><circle cx={label.x} cy={label.y} r="10" /><text x={label.x} y={label.y + 1}>{wheelPointLabels[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? "•"}</text>{point.retrograde && <text x={label.x + 9} y={label.y - 9} className="point-retrograde">R</text>}</g>;
      })}
    </svg>
    <div className="transit-wheel-legend"><span><i className="natal-dot" />本命内层</span><span><i className="moving-dot" />{movingLabel}</span><span>{comparison.result.cross_aspects.length} 条跨盘相位</span></div>
  </div>;
}

function AspectGrid({ snapshot, onOpen }: { snapshot: NatalSnapshot; onOpen: (aspect: NatalAspect) => void }) {
  const preferred = [...pointGroups.core, "asc", "mc", "true_north_node", "fortune"];
  const points = preferred
    .map((id) => snapshot.result.points.find((point) => point.point_id === id))
    .filter((point): point is NatalPoint => Boolean(point));
  const aspects = new Map<string, NatalAspect>();
  snapshot.result.aspects.forEach((aspect) => {
    aspects.set(`${aspect.point_a}:${aspect.point_b}`, aspect);
    aspects.set(`${aspect.point_b}:${aspect.point_a}`, aspect);
  });
  return (
    <div className="aspect-matrix-wrap">
      <table className="aspect-matrix" aria-label="本命盘主要相位矩阵">
        <thead><tr><th scope="col">点位</th>{points.map((point) => <th key={point.point_id} scope="col" title={pointNames[point.point_id] ?? point.point_id}>{pointGlyphs[point.point_id] ?? "•"}</th>)}</tr></thead>
        <tbody>{points.map((rowPoint, rowIndex) => <tr key={rowPoint.point_id}><th scope="row"><b>{pointGlyphs[rowPoint.point_id] ?? "•"}</b><span>{pointNames[rowPoint.point_id] ?? rowPoint.point_id}</span></th>{points.map((columnPoint, columnIndex) => {
          if (columnIndex >= rowIndex) return <td key={columnPoint.point_id} className="matrix-empty">{columnIndex === rowIndex ? "—" : ""}</td>;
          const aspect = aspects.get(`${rowPoint.point_id}:${columnPoint.point_id}`);
          if (!aspect) return <td key={columnPoint.point_id} className="matrix-empty" />;
          const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
          return <td key={columnPoint.point_id}><button className={hard ? "hard" : "soft"} onClick={() => onOpen(aspect)} title={`${pointNames[aspect.point_a] ?? aspect.point_a} ${aspectNames[aspect.type] ?? aspect.type} ${pointNames[aspect.point_b] ?? aspect.point_b}，容许度 ${aspect.orb_deg.toFixed(3)}°`}><b>{aspectMarks[aspect.type] ?? "·"}</b><small>{aspect.orb_deg.toFixed(1)}°</small></button></td>;
        })}</tr>)}</tbody>
      </table>
      <p>矩阵用于快速查看点位之间的相位关系；点击单元格可查看理论角度、实际角距、容许度、入相／出相和对应含义。</p>
    </div>
  );
}

function TimeDependentUnavailable({ title, detail }: { title: string; detail: string }) {
  return <section className="time-dependent-unavailable"><span>需要出生时间</span><h3>{title}</h3><p>{detail}</p><ul><li>系统不会把 00:00 或日期中点当作出生时刻。</li><li>补充可靠的当地出生时间后，请重新计算。</li><li>当前仍可查看日期级天体位置、不确定范围及可能的跨星座／运动状态变化。</li></ul></section>;
}

function PointResultTable({ title, points, dateLevelMode, onOpen }: { title: string; points: NatalPoint[]; dateLevelMode: boolean; onOpen: (point: NatalPoint) => void }) {
  if (!points.length) return null;
  return <>
    <h3 className="table-group-title">{title}</h3>
    <div className="data-table"><div className="table-head"><span>点位</span><span>星座度数</span><span>宫位</span><span>运动</span><span>类型</span><span>操作</span></div>{points.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id] ?? "•"}</b>{pointNames[point.point_id] ?? point.point_id}</span><span>{pointPlacementLabel(point, dateLevelMode)}</span><span>{pointHouseLabel(point)}</span><span className={point.retrograde ? "retrograde" : ""}>{pointMotionLabel(point, dateLevelMode)}</span><span>{pointKindNames[String(point.kind)] ?? "扩展点位"}</span><button onClick={() => onOpen(point)}>解读</button></div>)}</div>
  </>;
}

function CalculationUnavailable({ title, detail }: { title: string; detail: string }) {
  return <section className="calculation-unavailable"><span>当前结果暂无数据</span><h3>{title}</h3><p>{detail}</p></section>;
}

function CalculationResults({ snapshot, tab }: { snapshot: NatalSnapshot; tab: CalculationTab }) {
  const result = asRecord(snapshot.result);
  const mirrorResult = asRecord(result.mirror_points);
  const mirrorPoints = asRecords(mirrorResult.mirror_points);
  const mirrorContacts = asRecords(mirrorResult.contacts);
  const specialResult = asRecord(result.special_degrees);
  const specialPoints = asRecords(specialResult.points);
  const dignityByPoint = new Map(asRecords(snapshot.result.dignities).map((item) => [String(item.point_id ?? ""), item]));
  const pointById = new Map(snapshot.result.points.map((point) => [point.point_id, point]));
  const lots = asRecords(snapshot.result.lots);
  const receptionDocument = asRecord(asRecords(snapshot.result.receptions)[0] ?? asRecord(snapshot.result.classical).receptions);
  const receptions = asRecords(receptionDocument.receptions);
  const mutualReceptions = asRecords(receptionDocument.mutual_receptions);
  const midpointResult = asRecord(result.midpoints);
  const midpointFacts = asRecords(midpointResult.midpoints);
  const midpointHits = asRecords(midpointResult.hits);
  const firdaria = asRecord(result.firdaria);
  const firdariaMajor = asRecords(firdaria.major_periods);
  const firdariaMinor = asRecords(firdaria.sub_periods);
  const profections = asRecords(asRecord(result.profections).periods);
  const zodiacalReleasing = asRecord(result.zodiacal_releasing);

  if (tab === "features") return <div className="calculation-result-content"><div className="calculation-summary-grid"><article><span>接纳／互容</span><b>{receptions.length} / {mutualReceptions.length}</b><small>{receptions.length || mutualReceptions.length ? "已按当前三分主星表与界表计算" : "当前参数未命中"}</small></article><article><span>映点接触</span><b>{mirrorContacts.length}</b><small>{mirrorPoints.length ? `${mirrorPoints.length} 个点位已生成映点与反映点` : "本次结果尚未生成"}</small></article><article><span>特殊度数</span><b>{specialPoints.filter((item) => item.in_via_combusta || item.in_terminal_degree_29).length}</b><small>{specialPoints.length ? `${specialPoints.length} 个点位已完成特殊度数检查` : "本次结果尚未生成"}</small></article><article><span>固定星合相</span><b>{snapshot.result.fixed_star_contacts?.length ?? 0}</b><small>{snapshot.result.fixed_stars?.length ? `${snapshot.result.fixed_stars.length} 颗固定星参与计算` : "未选择固定星"}</small></article></div><div className="calculation-list">{receptions.map((item, index) => <article key={`reception-${index}`}><b>{pointNames[String(item.host_point_id)] ?? String(item.host_point_id)}</b><span>接纳</span><b>{pointNames[String(item.guest_point_id)] ?? String(item.guest_point_id)}</b><small>{dignityNames[String(item.dignity_kind)] ?? String(item.dignity_kind)}</small></article>)}{mutualReceptions.map((item, index) => <article key={`mutual-${index}`}><b>{pointNames[String(item.point_a)] ?? String(item.point_a)}</b><span>互容</span><b>{pointNames[String(item.point_b)] ?? String(item.point_b)}</b><small>{asStrings(item.a_receives_b_by).map((kind) => dignityNames[kind] ?? kind).join("、")} / {asStrings(item.b_receives_a_by).map((kind) => dignityNames[kind] ?? kind).join("、")}</small></article>)}{mirrorContacts.map((item, index) => <article key={`mirror-contact-${index}`}><b>{pointNames[String(item.point_a)] ?? String(item.point_a)}</b><span>{item.contact_type === "antiscia" ? "映点接触" : "反映点接触"}</span><b>{pointNames[String(item.point_b)] ?? String(item.point_b)}</b><small>偏差 {Number(item.separation_from_exact_deg ?? 0).toFixed(3)}°</small></article>)}{specialPoints.filter((item) => item.in_via_combusta || item.in_terminal_degree_29).map((item, index) => <article key={`degree-feature-${index}`}><b>{pointNames[String(item.point_id)] ?? String(item.point_id)}</b><span>{item.in_via_combusta ? "燃烧之路" : "29 度区间"}</span><small>{signNames[String(item.sign_id)] ?? String(item.sign_id)} {formatDegree(Number(item.degree_in_sign ?? 0))}</small></article>)}</div></div>;

  if (tab === "planets") return <div className="calculation-result-content"><div className="wide-result-table planet-result-table"><div className="wide-result-head"><span>星体</span><span>黄经</span><span>落宫</span><span>主宰</span><span>庙</span><span>旺</span><span>三分</span><span>界</span><span>面</span><span>陷</span><span>弱</span><span>单度</span><span>分数</span><span>速度</span><span>黄纬</span><span>赤经</span><span>赤纬</span></div>{snapshot.result.points.map((point) => { const dignity = dignityByPoint.get(point.point_id); const dignities = asRecords(dignity?.dignities); const debilities = asRecords(dignity?.debilities); const hasDignity = (kind: string) => dignities.some((item) => item.kind === kind) ? "✓" : "—"; const hasDebility = (kind: string) => debilities.some((item) => item.kind === kind) ? "✓" : "—"; const ruledHouses = snapshot.result.houses.filter((house) => [...house.traditional_ruler_ids, ...house.modern_ruler_ids].includes(point.point_id)).map((house) => house.number); return <div className="wide-result-row" key={point.point_id}><b>{pointNames[point.point_id] ?? point.point_id}</b><span>{signNames[point.sign] ?? point.sign} {formatDegree(point.degree_in_sign)}</span><span>{point.house ? `第${point.house}宫` : "—"}</span><span>{ruledHouses.length ? ruledHouses.map((house) => `${house}宫`).join("、") : "—"}</span><span>{hasDignity("domicile")}</span><span>{hasDignity("exaltation")}</span><span>{hasDignity("triplicity")}</span><span>{hasDignity("term")}</span><span>{hasDignity("face")}</span><span>{hasDebility("detriment")}</span><span>{hasDebility("fall") || dignity?.peregrine === true ? "✓" : "—"}</span><span>—</span><span>—</span><span>{point.position.velocity?.longitude_deg_per_day?.toFixed(5) ?? "—"}°/日</span><span>{point.position.ecliptic.latitude_deg?.toFixed(4) ?? "—"}°</span><span>{point.position.equatorial?.right_ascension_deg?.toFixed(4) ?? "—"}°</span><span>{point.position.equatorial?.declination_deg?.toFixed(4) ?? "—"}°</span></div>; })}</div></div>;

  if (tab === "houses") return snapshot.result.houses.length ? <div className="calculation-result-content"><div className="wide-result-table house-result-table"><div className="wide-result-head"><span>宫位</span><span>宫头</span><span>传统宫主</span><span>现代宫主</span><span>宫内点位</span></div>{snapshot.result.houses.map((house) => <div className="wide-result-row" key={house.number}><b>第{house.number}宫</b><span>{signNames[house.sign] ?? house.sign} {formatDegree(house.degree_in_sign)}</span><span>{pointList(house.traditional_ruler_ids)}</span><span>{pointList(house.modern_ruler_ids)}</span><span>{pointList(house.point_ids)}</span></div>)}</div></div> : <CalculationUnavailable title="宫位未计算" detail="出生时刻不足时不生成虚假的宫头、宫主或宫内点位。" />;

  if (tab === "lots") return lots.length ? <div className="calculation-result-content"><div className="wide-result-table lot-result-table"><div className="wide-result-head"><span>阿拉伯点</span><span>星座度数</span><span>宫位</span></div>{lots.map((lot, index) => { const id = String(lot.lot_id ?? lot.point_id ?? `lot-${index}`); const point = pointById.get(id); return <div className="wide-result-row" key={id}><b>{pointNames[id] ?? id}</b><span>{point ? `${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)}` : `${Number(lot.longitude_deg ?? 0).toFixed(4)}°`}</span><span>{point?.house ? `第${point.house}宫` : "—"}</span></div>; })}</div></div> : <CalculationUnavailable title="阿拉伯点未计算" detail="请在左侧开启阿拉伯点，并用可靠出生时刻重新计算。" />;

  if (tab === "stars") return snapshot.result.fixed_stars?.length ? <div className="calculation-result-content"><div className="wide-result-table star-result-table"><div className="wide-result-head"><span>固定星</span><span>星座度数</span><span>星等</span><span>赤纬</span><span>本命合相</span></div>{snapshot.result.fixed_stars.map((star) => { const contacts = (snapshot.result.fixed_star_contacts ?? []).filter((contact) => contact.star_id === star.star_id); return <div className="wide-result-row" key={star.star_id}><b>{star.label_zh}<small>{star.name}</small></b><span>{signNames[star.sign] ?? star.sign} {formatDegree(star.degree_in_sign)}</span><span>{star.magnitude_v.toFixed(2)}</span><span>{star.position.equatorial.declination_deg.toFixed(4)}°</span><span>{contacts.map((contact) => `${pointNames[contact.point_id] ?? contact.point_id} ${contact.orb_deg.toFixed(3)}°`).join("、") || "无"}</span></div>; })}</div></div> : <CalculationUnavailable title="固定星未开启" detail="在左侧选择固定星并重新计算后，这里显示星座度数、星等、赤纬与本命合相。" />;

  if (tab === "mirrors") return mirrorPoints.length ? <div className="calculation-result-content"><div className="wide-result-table mirror-result-table"><div className="wide-result-head"><span>点位</span><span>自身</span><span>映点</span><span>反映点</span></div>{mirrorPoints.map((item, index) => <div className="wide-result-row" key={String(item.point_id ?? index)}><b>{pointNames[String(item.point_id)] ?? String(item.point_id)}</b><span>{Number(item.longitude_deg ?? 0).toFixed(4)}°</span><span>{`${signNames[String(item.antiscia_sign_id)] ?? String(item.antiscia_sign_id)} ${formatDegree(Number(item.antiscia_degree_in_sign ?? 0))}`}</span><span>{`${signNames[String(item.contra_antiscia_sign_id)] ?? String(item.contra_antiscia_sign_id)} ${formatDegree(Number(item.contra_antiscia_degree_in_sign ?? 0))}`}</span></div>)}</div></div> : <CalculationUnavailable title="映点尚未生成" detail="请确认左侧已开启映点，并按当前参数重新计算。" />;

  if (tab === "degrees") return specialPoints.length ? <div className="calculation-result-content"><div className="calculation-list">{specialPoints.map((item, index) => <article key={String(item.point_id ?? index)}><b>{pointNames[String(item.point_id)] ?? String(item.point_id)}</b><span>{signNames[String(item.sign_id)] ?? String(item.sign_id ?? "")} {formatDegree(Number(item.degree_in_sign ?? 0))}</span><small>{[item.decan_index ? `第${item.decan_index}面` : "", item.in_via_combusta ? "燃烧之路" : "", item.in_terminal_degree_29 ? "29度" : ""].filter(Boolean).join(" · ") || "未命中特殊度数规则"}</small></article>)}</div></div> : <CalculationUnavailable title="特殊度数未计算" detail="本次结果没有特殊度数信息。" />;

  if (tab === "firdaria") return firdariaMajor.length ? <div className="calculation-result-content"><div className="result-filter-chips"><span>{firdaria.sect === "day" ? "昼盘起序" : "夜盘起序"}</span><span>主运＋次运</span></div><div className="wide-result-table firdaria-result-table"><div className="wide-result-head"><span>主运星</span><span>起始</span><span>结束</span><span>年数</span><span>当前</span></div>{firdariaMajor.map((period, index) => <div className="wide-result-row" key={String(period.period_id ?? index)}><b>{pointNames[String(period.major_lord_id)] ?? String(period.major_lord_id)}</b><span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span><span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span><span>{String(period.duration_years)} 年</span><span>{period.current ? "当前主运" : ""}</span></div>)}</div><h3 className="table-group-title">次运</h3><div className="wide-result-table firdaria-sub-result-table"><div className="wide-result-head"><span>主运星</span><span>次运星</span><span>起始</span><span>结束</span><span>当前</span></div>{firdariaMinor.map((period, index) => <div className="wide-result-row" key={String(period.period_id ?? index)}><span>{pointNames[String(period.major_lord_id)] ?? String(period.major_lord_id)}</span><b>{pointNames[String(period.minor_lord_id)] ?? String(period.minor_lord_id)}</b><span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span><span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span><span>{period.current ? "当前次运" : ""}</span></div>)}</div></div> : <CalculationUnavailable title="法达未计算" detail="法达需要可判定的昼夜盘与可靠出生时刻。" />;

  if (tab === "profections") return profections.length ? <div className="calculation-result-content"><div className="result-filter-chips"><span>起点：上升／第一宫</span><span>年度小限</span><span>生日边界</span></div><div className="wide-result-table profection-result-table"><div className="wide-result-head"><span>年龄</span><span>起始</span><span>结束</span><span>宫位</span><span>星座</span><span>主星</span><span>当前</span></div>{profections.map((period, index) => <div className="wide-result-row" key={String(period.age ?? index)}><b>{String(period.age)} 岁</b><span>{String(period.start_date)}</span><span>{String(period.end_date)}</span><span>第{String(period.activated_house)}宫</span><span>{signNames[String(period.activated_sign)] ?? String(period.activated_sign)}</span><span>{pointList(period.time_lord_ids)}</span><span>{period.current ? "当前" : ""}</span></div>)}</div></div> : <CalculationUnavailable title="小限未计算" detail="年度小限需要上升星座与可靠出生日期。" />;

  if (tab === "fortune_zr" || tab === "spirit_zr") { const lotId = tab === "fortune_zr" ? "fortune" : "spirit"; const releasing = asRecord(zodiacalReleasing[lotId]); const levels = asRecord(releasing.levels); const levelOne = asRecords(levels.L1); const levelTwo = asRecords(levels.L2); return levelOne.length ? <div className="calculation-result-content"><div className="result-filter-chips"><span>{lotId === "fortune" ? "福点释放" : "精神点释放"}</span><span>起始：{signNames[String(releasing.starting_sign)] ?? String(releasing.starting_sign)}</span><span>L1 / L2</span></div><div className="wide-result-table zr-result-table"><div className="wide-result-head"><span>层级</span><span>星座</span><span>主星</span><span>起始</span><span>结束</span><span>当前</span></div>{levelOne.map((period, index) => <div className="wide-result-row" key={String(period.period_id ?? index)}><b>L1</b><span>{signNames[String(period.sign_id)] ?? String(period.sign_id)}</span><span>{pointList(period.time_lord_ids)}</span><span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span><span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span><span>{period.current ? "当前" : ""}</span></div>)}</div><h3 className="table-group-title">L2 期间</h3><div className="wide-result-table zr-result-table"><div className="wide-result-head"><span>层级</span><span>星座</span><span>主星</span><span>起始</span><span>结束</span><span>当前</span></div>{levelTwo.map((period, index) => <div className="wide-result-row" key={String(period.period_id ?? index)}><b>L2</b><span>{signNames[String(period.sign_id)] ?? String(period.sign_id)}</span><span>{pointList(period.time_lord_ids)}</span><span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span><span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span><span>{period.current ? "当前" : ""}</span></div>)}</div></div> : <CalculationUnavailable title={`${lotId === "fortune" ? "福点" : "精神点"}黄道释放未计算`} detail={`请在左侧开启${lotId === "fortune" ? "福点" : "精神点"}并重新计算。`} />; }

  if (tab === "rays") return snapshot.result.aspects.length ? <div className="calculation-result-content"><div className="result-filter-chips"><span>光线：当前计算点位</span><span>容许度：已应用五级规则</span></div><div className="wide-result-table ray-result-table"><div className="wide-result-head"><span>发出点</span><span>光线类型</span><span>接收点</span><span>实际角距</span><span>偏差</span><span>阶段</span></div>{snapshot.result.aspects.map((aspect) => <div className="wide-result-row" key={aspect.aspect_id}><b>{pointNames[aspect.point_a] ?? aspect.point_a}</b><span>{aspectNames[aspect.type] ?? aspect.type}</span><b>{pointNames[aspect.point_b] ?? aspect.point_b}</b><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span></div>)}</div><p className="calculation-result-note">这里展示已成立的相位光线；传递光线、收集光线和围攻必须满足额外时序规则，当前结果不把普通相位误标成这些关系。</p></div> : <CalculationUnavailable title="光线未计算" detail="本次结果没有可用相位。" />;

  if (tab === "midpoints") return midpointFacts.length ? <div className="calculation-result-content"><div className="result-filter-chips"><span>中点：日月水金火木</span><span>相位：当前相位集</span><span>容许度：{String(asRecord(midpointResult.provenance).hit_orb_deg ?? 1)}°</span></div><div className="wide-result-table midpoint-result-table"><div className="wide-result-head"><span>点位对</span><span>直接中点</span><span>间接中点</span><span>歧义</span></div>{midpointFacts.map((midpoint, index) => <div className="wide-result-row" key={String(midpoint.midpoint_id ?? index)}><b>{pointNames[String(midpoint.point_a)] ?? String(midpoint.point_a)} / {pointNames[String(midpoint.point_b)] ?? String(midpoint.point_b)}</b><span>{Number(midpoint.direct_midpoint_deg ?? 0).toFixed(4)}°</span><span>{Number(midpoint.indirect_midpoint_deg ?? 0).toFixed(4)}°</span><span>{midpoint.ambiguous ? "对跖点，方向歧义" : ""}</span></div>)}</div><h3 className="table-group-title">中点命中</h3><div className="wide-result-table midpoint-hit-result-table"><div className="wide-result-head"><span>中点</span><span>轴</span><span>目标点</span><span>相位</span><span>偏差</span></div>{midpointHits.map((hit, index) => <div className="wide-result-row" key={String(hit.hit_id ?? index)}><b>{String(hit.midpoint_id ?? "").replace("midpoint:", "").split(":").map((id) => pointNames[id] ?? id).join(" / ")}</b><span>{hit.midpoint_type === "direct" ? "直接" : "间接"}</span><span>{pointNames[String(hit.target_point_id)] ?? String(hit.target_point_id)}</span><span>{aspectNames[String(hit.aspect_id)] ?? String(hit.aspect_id)}</span><span>{Number(hit.orb_deg ?? 0).toFixed(3)}°</span></div>)}</div></div> : <CalculationUnavailable title="中点未计算" detail="本次结果没有足够的基础点位。" />;

  return <CalculationUnavailable title="当前分类没有结果" detail="请检查左侧点位选择并重新计算。" />;
}

function StructureResults({ snapshot, onOpen }: { snapshot: NatalSnapshot; onOpen: (target: InterpretationTarget) => void }) {
  const structure = asRecord(snapshot.result.structure);
  const categorical = [
    ["hemispheres", "半球分布"], ["quadrants", "象限分布"], ["house_modes", "角续果分布"],
  ] as const;
  const angularity = asRecord(structure.angularity);
  const angularFacts = asRecords(angularity.facts);
  const stelliums = asRecords(asRecord(structure.stelliums).facts);
  const patterns = asRecords(asRecord(structure.geometric_patterns).facts);
  const jones = asRecord(structure.jones_shape);
  return <>
    <div className="professional-grid">
      {categorical.map(([key, label]) => {
        const section = asRecord(structure[key]);
        const categories = asRecords(section.categories);
        return <article className="professional-card" key={key}><header><div><small>{availabilityLabel(section.availability)}</small><h3>{label}</h3></div><button onClick={() => onOpen({ type: "structure", id: key, title: label, fact: toPlain(section), resultPath: `/result/structure/${key}` })}>解读</button></header>{categories.length ? <ul className="fact-list">{categories.map((category) => <li key={String(category.category_id)}><span>{structureCategoryNames[String(category.category_id)] ?? String(category.category_id)}</span><b>{Number(category.count ?? 0)}</b><small>{pointList(category.point_ids)}</small></li>)}</ul> : <p className="empty-fact">没有可用分类事实。</p>}</article>;
      })}
    </div>

    <h3 className="table-group-title">角度性与宫位强度位置</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>点位</th><th>宫位</th><th>宫位类型</th><th>最近轴点</th><th>距离</th><th>带宽</th><th>操作</th></tr></thead><tbody>{angularFacts.map((fact, index) => <tr key={String(fact.point_id)}><td>{pointNames[String(fact.point_id)] ?? String(fact.point_id)}</td><td>{fact.house == null ? "—" : `第${String(fact.house)}宫`}</td><td>{structureCategoryNames[String(fact.house_mode)] ?? String(fact.house_mode ?? "—")}</td><td>{pointNames[String(fact.nearest_angle_id)] ?? String(fact.nearest_angle_id ?? "—")}</td><td>{fact.distance_to_angle_deg == null ? "—" : `${Number(fact.distance_to_angle_deg).toFixed(3)}°`}</td><td>{String(fact.band ?? "—")}</td><td><button onClick={() => onOpen({ type: "structure", id: `angularity.${String(fact.point_id)}`, title: `${pointNames[String(fact.point_id)] ?? String(fact.point_id)}的角度性`, fact: toPlain(fact), resultPath: `/result/structure/angularity/facts/${index}` })}>解读</button></td></tr>)}</tbody></table></div>

    <div className="professional-grid structure-patterns">
      <article className="professional-card"><header><div><small>STELLIUMS</small><h3>群星结构</h3></div><span>{stelliums.length}</span></header>{stelliums.length ? <ul className="fact-list">{stelliums.map((fact, index) => <li key={String(fact.stellium_id ?? index)}><span>{patternNames[String(fact.kind)] ?? String(fact.kind)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}{fact.longitude_span_deg == null ? "" : ` · 跨度 ${Number(fact.longitude_span_deg).toFixed(3)}°`}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.stellium_id ?? index), title: patternNames[String(fact.kind)] ?? "群星结构", fact: toPlain(fact), resultPath: `/result/structure/stelliums/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前参数未命中群星结构。</p>}</article>
      <article className="professional-card"><header><div><small>GEOMETRIC PATTERNS</small><h3>几何格局</h3></div><span>{patterns.length}</span></header>{patterns.length ? <ul className="fact-list">{patterns.map((fact, index) => <li key={String(fact.pattern_id ?? index)}><span>{patternNames[String(fact.pattern_type)] ?? String(fact.pattern_type)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.pattern_id ?? index), title: patternNames[String(fact.pattern_type)] ?? "几何格局", fact: toPlain(fact), resultPath: `/result/structure/geometric_patterns/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前参数未命中已发布几何格局。</p>}</article>
      <article className="professional-card"><header><div><small>盘型分类</small><h3>Jones 盘型</h3></div><span>{statusNames[String(jones.status ?? "")] ?? (jones.shape_id ? "已识别" : "不确定")}</span></header><p className="boundary-copy">{jones.shape_id ? String(jones.shape_id) : "当前没有通过验证的分类规则，因此保留为不确定，不用视觉猜测生成盘型。"}</p><button onClick={() => onOpen({ type: "structure", id: "jones_shape", title: "Jones 盘型边界", fact: toPlain(jones), resultPath: "/result/structure/jones_shape" })}>查看依据</button></article>
    </div>
  </>;
}

function NatalFeatureResults({ snapshot }: { snapshot: NatalSnapshot }) {
  const result = asRecord(snapshot.result);
  const specialPoints = asRecords(asRecord(result.special_degrees).points);
  const mirrorResult = asRecord(result.mirror_points);
  const mirrorPoints = asRecords(mirrorResult.mirror_points);
  const mirrorContacts = asRecords(mirrorResult.contacts);
  const receptionDocument = asRecord(asRecord(snapshot.result.classical).receptions);
  const receptions = asRecords(receptionDocument.receptions);
  const mutualReceptions = asRecords(receptionDocument.mutual_receptions);
  return <>
    <h3 className="table-group-title">特征</h3>
    <div className="professional-grid consumer-feature-grid">
      <article className="professional-card"><header><div><small>RECEPTIONS</small><h3>接纳与互容</h3></div><span>{receptions.length + mutualReceptions.length}</span></header>{receptions.length || mutualReceptions.length ? <ul className="fact-list">{receptions.map((item, index) => <li key={`consumer-reception-${index}`}><span>{pointNames[String(item.host_point_id)] ?? String(item.host_point_id)} 接纳 {pointNames[String(item.guest_point_id)] ?? String(item.guest_point_id)}</span><b>{dignityNames[String(item.dignity_kind)] ?? String(item.dignity_kind)}</b></li>)}{mutualReceptions.map((item, index) => <li key={`consumer-mutual-${index}`}><span>{pointNames[String(item.point_a)] ?? String(item.point_a)} ↔ {pointNames[String(item.point_b)] ?? String(item.point_b)}</span><b>互容</b></li>)}</ul> : <p className="empty-fact">当前参数没有命中接纳或互容。</p>}</article>
      <article className="professional-card"><header><div><small>SPECIAL DEGREES</small><h3>特殊度数</h3></div><span>{specialPoints.length}</span></header>{specialPoints.length ? <ul className="fact-list">{specialPoints.map((item, index) => <li key={`consumer-degree-${String(item.point_id ?? index)}`}><span>{pointNames[String(item.point_id)] ?? String(item.point_id)}</span><b>{signNames[String(item.sign_id)] ?? String(item.sign_id)} {formatDegree(Number(item.degree_in_sign ?? 0))}</b><small>{[item.decan_index ? `第${String(item.decan_index)}面` : "", item.in_via_combusta ? "燃烧之路" : "", item.in_terminal_degree_29 ? "29 度区间" : ""].filter(Boolean).join(" · ") || "未命中特殊度数事实"}</small></li>)}</ul> : <p className="empty-fact">本次结果没有特殊度数信息。</p>}</article>
      <article className="professional-card"><header><div><small>MIRROR CONTACTS</small><h3>映点接触</h3></div><span>{mirrorContacts.length}</span></header>{mirrorContacts.length ? <ul className="fact-list">{mirrorContacts.map((item, index) => <li key={`consumer-mirror-contact-${index}`}><span>{pointNames[String(item.point_a)] ?? String(item.point_a)} 与 {pointNames[String(item.point_b)] ?? String(item.point_b)}</span><b>{item.contact_type === "antiscia" ? "映点" : "反映点"}</b><small>距精确位置 {Number(item.separation_from_exact_deg ?? 0).toFixed(3)}°</small></li>)}</ul> : <p className="empty-fact">当前容许度内没有映点或反映点接触。</p>}</article>
    </div>
    <h3 className="table-group-title">映点与反映点</h3>
    {mirrorPoints.length ? <div className="professional-table-wrap"><table className="professional-table mirror-consumer-table"><thead><tr><th>点位</th><th>自身黄经</th><th>映点</th><th>反映点</th></tr></thead><tbody>{mirrorPoints.map((item, index) => <tr key={`consumer-mirror-${String(item.point_id ?? index)}`}><td>{pointNames[String(item.point_id)] ?? String(item.point_id)}</td><td>{Number(item.longitude_deg ?? 0).toFixed(4)}°</td><td>{signNames[String(item.antiscia_sign_id)] ?? String(item.antiscia_sign_id)} {formatDegree(Number(item.antiscia_degree_in_sign ?? 0))}</td><td>{signNames[String(item.contra_antiscia_sign_id)] ?? String(item.contra_antiscia_sign_id)} {formatDegree(Number(item.contra_antiscia_degree_in_sign ?? 0))}</td></tr>)}</tbody></table></div> : <CalculationUnavailable title="映点尚未生成" detail="在左侧开启映点并按当前参数重新计算后，这里会逐点展示映点与反映点。" />}
  </>;
}

function ClassicalResults({ snapshot, onOpen }: { snapshot: NatalSnapshot; onOpen: (target: InterpretationTarget) => void }) {
  const classical = asRecord(snapshot.result.classical);
  const sect = asRecord(classical.sect);
  const dignities = snapshot.result.dignities ?? [];
  const solarConditions = asRecords(classical.solar_conditions);
  const receptionDocument = asRecord(classical.receptions);
  const receptions = asRecords(receptionDocument.receptions);
  const mutualReceptions = asRecords(receptionDocument.mutual_receptions);
  const lots = snapshot.result.lots ?? [];
  return <>
    <div className="classical-summary"><div><small>昼夜盘</small><b>{classical.day_night_status === "day" ? "昼盘" : classical.day_night_status === "night" ? "夜盘" : "不确定"}</b><span>太阳高度 {classical.sun_altitude_deg == null ? "—" : `${Number(classical.sun_altitude_deg).toFixed(3)}°`}</span></div><div><small>本质尊贵</small><b>{dignities.length}</b><span>传统七曜逐星计算</span></div><div><small>接纳 / 互容</small><b>{receptions.length} / {mutualReceptions.length}</b><span>不要求相位的接纳事实</span></div><div><small>阿拉伯点</small><b>{lots.length}</b><span>已按昼夜盘选择对应公式</span></div></div>

    <div className="professional-card sect-card"><header><div><small>{availabilityLabel(classical.availability)}</small><h3>昼夜体系</h3></div><button onClick={() => onOpen({ type: "classical", id: "sect", title: "昼夜体系", fact: toPlain(sect), resultPath: "/result/classical/sect" })}>解读</button></header><dl className="fact-definition"><div><dt>当权光体</dt><dd>{pointNames[String(sect.sect_light_id)] ?? String(sect.sect_light_id ?? "—")}</dd></div><div><dt>昼星</dt><dd>{pointList(sect.diurnal_planet_ids)}</dd></div><div><dt>夜星</dt><dd>{pointList(sect.nocturnal_planet_ids)}</dd></div><div><dt>条件星</dt><dd>{pointList(sect.conditional_planet_ids)}</dd></div></dl></div>

    <h3 className="table-group-title">先天黄道状态</h3>
    <div className="professional-table-wrap"><table className="professional-table dignity-table"><thead><tr><th>星体</th><th>位置</th><th>尊贵</th><th>失势／落陷</th><th>游走</th><th>昼夜状态</th><th>操作</th></tr></thead><tbody>{dignities.map((raw, index) => { const row = asRecord(raw); const active = asRecords(row.dignities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)); const debilities = asRecords(row.debilities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)); return <tr key={String(row.point_id ?? index)}><td>{pointNames[String(row.point_id)] ?? String(row.point_id)}</td><td>{signNames[String(row.sign_id)] ?? String(row.sign_id)} {formatDegree(Number(row.degree_in_sign ?? 0))}</td><td>{active.join("、") || "无"}</td><td>{debilities.join("、") || "无"}</td><td>{row.peregrine === true ? "是" : row.peregrine === false ? "否" : "不适用"}</td><td>{row.sect === "day" ? "昼盘" : row.sect === "night" ? "夜盘" : "—"}</td><td><button onClick={() => onOpen({ type: "classical", id: `dignity.${String(row.point_id)}`, title: `${pointNames[String(row.point_id)] ?? String(row.point_id)}的本质尊贵`, fact: toPlain(row), resultPath: `/result/dignities/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>

    <h3 className="table-group-title">后天状态</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>星体</th><th>太阳条件</th><th>日距</th><th>东方／西方</th><th>越界</th><th>物理可见性</th><th>操作</th></tr></thead><tbody>{solarConditions.map((condition, index) => { const point = snapshot.result.points.find((item) => item.point_id === String(condition.point_id)); return <tr key={String(condition.point_id ?? index)}><td>{pointNames[String(condition.point_id)] ?? String(condition.point_id)}</td><td>{solarRelationNames[String(condition.relation)] ?? String(condition.relation)}</td><td>{condition.separation_deg == null ? "—" : `${Number(condition.separation_deg).toFixed(3)}°`}</td><td>{point?.oriental_occidental === "oriental" ? "东方" : point?.oriental_occidental === "occidental" ? "西方" : "不适用"}</td><td>{point?.out_of_bounds === true ? "是" : point?.out_of_bounds === false ? "否" : "不适用"}</td><td>{point?.visibility_state === "uncertain" ? "未计算（需晨昏模型）" : point?.visibility_state ?? "—"}</td><td><button onClick={() => onOpen({ type: "classical", id: `solar.${String(condition.point_id)}`, title: `${pointNames[String(condition.point_id)] ?? String(condition.point_id)}的太阳条件`, fact: toPlain(condition), resultPath: `/result/classical/solar_conditions/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>

    <div className="professional-grid classical-relations">
      <article className="professional-card"><header><div><small>接纳关系</small><h3>接纳与互容</h3></div><span>{receptions.length + mutualReceptions.length}</span></header><ul className="fact-list">{receptions.map((row, index) => <li key={`direct-${index}`}><span>{pointNames[String(row.host_point_id)] ?? String(row.host_point_id)} 接纳 {pointNames[String(row.guest_point_id)] ?? String(row.guest_point_id)}</span><b>{dignityNames[String(row.dignity_kind)] ?? String(row.dignity_kind)}</b><small>{row.active_for_sect == null ? "不受昼夜条件影响" : row.active_for_sect ? "当前昼夜条件生效" : "当前昼夜条件不生效"}</small></li>)}{mutualReceptions.map((row, index) => <li key={`mutual-${index}`}><span>{pointNames[String(row.point_a)] ?? String(row.point_a)} ↔ {pointNames[String(row.point_b)] ?? String(row.point_b)}</span><b>互容</b><small>{asStrings(row.a_receives_b_by).map((id) => dignityNames[id] ?? id).join("、")} / {asStrings(row.b_receives_a_by).map((id) => dignityNames[id] ?? id).join("、")}</small></li>)}</ul>{!receptions.length && !mutualReceptions.length && <p className="empty-fact">当前参数没有命中接纳或互容。</p>}<button onClick={() => onOpen({ type: "classical", id: "receptions", title: "接纳与互容", fact: toPlain(receptionDocument), resultPath: "/result/classical/receptions" })}>解读</button></article>
    </div>

    <h3 className="table-group-title">阿拉伯点／赫尔墨斯点</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>点位</th><th>位置</th><th>宫位</th><th>昼夜</th><th>操作</th></tr></thead><tbody>{lots.map((raw, index) => { const lot = asRecord(raw); const point = snapshot.result.points.find((item) => item.point_id === String(lot.lot_id)); return <tr key={String(lot.lot_id ?? index)}><td>{pointNames[String(lot.lot_id)] ?? String(lot.lot_id)}</td><td>{signNames[String(lot.sign_id)] ?? String(lot.sign_id)} {formatDegree(Number(lot.degree_in_sign ?? 0))}</td><td>{point?.house == null ? "—" : `第${point.house}宫`}</td><td>{lot.sect === "day" ? "昼盘" : lot.sect === "night" ? "夜盘" : "—"}</td><td><button onClick={() => onOpen({ type: "classical", id: `lot.${String(lot.lot_id)}`, title: `${pointNames[String(lot.lot_id)] ?? String(lot.lot_id)}的含义`, fact: toPlain(lot), resultPath: `/result/lots/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>
  </>;
}

function InterpretationDrawer({ target, snapshot, onClose }: { target: InterpretationTarget; snapshot: NatalSnapshot; onClose: () => void }) {
  const [result, setResult] = useState<ItemInterpretation>(() => buildLocalInterpretation(target, snapshot));
  const [loading, setLoading] = useState(snapshot.id.startsWith("calculation-") && Boolean(target.resultPath));
  useEffect(() => {
    let active = true;
    if (!snapshot.id.startsWith("calculation-") || !target.resultPath) return () => { active = false; };
    getNatalItemInterpretation(snapshot.id, target.type, target.resultPath, { includeTimeDependent: !isDateLevelSnapshot(snapshot) })
      .then((value) => {
        if (active) {
          setResult({
            ...value,
            title: value.title ?? target.title,
            facts: [...(target.facts ?? [target.fact]), ...(value.facts ?? [])],
          });
        }
      })
      .catch(() => undefined)
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [snapshot, target.fact, target.facts, target.id, target.resultPath, target.title, target.type]);
  const readableLayers = (result.layers ?? []).filter((layer) => Boolean(layer.meaning) && layer.status === "published");
  const visibleFacts = [...new Set(result.facts ?? [target.fact])].filter((fact) => {
    const value = fact.trim();
    return value.length > 0 && !value.startsWith("{") && !value.startsWith("[");
  });
  const unavailableTitle = result.status === "blocked_by_input_quality"
    ? "出生资料不足"
    : result.status === "not_applicable"
      ? "此项不适用"
      : "解读内容准备中";
  const unavailableCopy = result.status === "blocked_by_input_quality"
    ? result.unavailable_reason
    : result.status === "not_applicable"
      ? result.unavailable_reason
      : result.unavailable_reason || "这项计算已经完成，专门解读仍在补充中。";
  return (
    <div className="drawer-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <aside className="interpretation-drawer" role="dialog" aria-modal="true" aria-label="逐项解读">
        <header><div><span>逐项解读</span><h2>{result.title ?? target.title}</h2></div><button onClick={onClose} aria-label="关闭">×</button></header>
        {loading && <div className="drawer-loading">正在读取这项结果的解读…</div>}
        {visibleFacts.length > 0 && <section><h3>计算事实</h3>{visibleFacts.map((fact, index) => <p className="fact-line" key={`${index}:${fact}`}>{fact}</p>)}</section>}
        {readableLayers.length ? <section><h3>解读</h3><div className="interpretation-layers">{readableLayers.map((layer) => <article key={`${layer.item_kind}:${layer.content_hash}`} className="interpretation-layer status-published"><header><h4>{layer.label}</h4></header><p>{layer.meaning}</p></article>)}</div></section> : result.status === "available" && result.meaning ? <section><h3>解读</h3><p>{result.meaning}</p></section> : <section><h3>{unavailableTitle}</h3><p>{unavailableCopy}</p></section>}
      </aside>
    </div>
  );
}

function PersonFields({ person, onChange }: { person: NatalPersonInput; onChange: (person: NatalPersonInput) => void }) {
  const [locationCandidates, setLocationCandidates] = useState<LocationSearchItem[]>([]);
  const [locationLoading, setLocationLoading] = useState(false);
  const [locationMessage, setLocationMessage] = useState("");
  const [locationSearchActive, setLocationSearchActive] = useState(false);
  const timezoneOptions = useMemo(() => {
    const supportedValuesOf = (Intl as unknown as { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf;
    const supported = supportedValuesOf ? supportedValuesOf("timeZone") : fallbackTimezoneOptions;
    return [...new Set([person.timezoneId, ...supported, ...fallbackTimezoneOptions].filter(Boolean))].sort();
  }, [person.timezoneId]);

  useEffect(() => {
    const query = person.placeName.trim();
    if (!locationSearchActive || query.length < 2 || person.locationSourceId) return;
    let active = true;
    const timer = window.setTimeout(() => {
      setLocationLoading(true);
      searchLocations(query)
        .then((items) => {
          if (!active) return;
          setLocationCandidates(items);
          setLocationMessage(items.length ? "请选择与出生地相符的正式地点候选。" : "官方地点索引中没有匹配项，可继续细化地名或手动覆盖坐标。 ");
        })
        .catch((error) => {
          if (!active) return;
          const fallback = fallbackPlaceOptions
            .filter((place) => place.name.includes(query) || query.includes(place.name))
            .map<LocationSearchItem>((place, index) => ({
              id: `demo-fallback:${index}`,
              label: `${place.name} · ${place.countryCode} · 演示后备`,
              match_score: 0,
              match_reasons: ["demo_fallback"],
              location: { name: place.name, country_code: place.countryCode, admin_path: [], latitude: place.latitude, longitude: place.longitude, elevation_m: null, timezone_id: place.timezoneId, warnings: [] },
              timezone_status: "resolved",
              timezone_candidates: [{ timezone_id: place.timezoneId, confidence: "demo_fallback", boundary_match: false }],
            }));
          setLocationCandidates(fallback);
          setLocationMessage(error instanceof InterstellarApiError && error.code === "API_NOT_CONFIGURED"
            ? "当前未连接地点服务，仅显示明确标注的演示后备候选；正式计算应使用官方 GeoNames 数据集。"
            : "地点服务暂不可用。你仍可手动输入地点、时区和经纬度。 ");
        })
        .finally(() => { if (active) setLocationLoading(false); });
    }, 320);
    return () => { active = false; window.clearTimeout(timer); };
  }, [locationSearchActive, person.locationSourceId, person.placeName]);

  const selectLocation = (candidate: LocationSearchItem) => {
    const timezone = candidate.location.timezone_id ?? candidate.timezone_candidates[0]?.timezone_id ?? person.timezoneId;
    onChange({
      ...person,
      placeName: candidate.location.name,
      countryCode: candidate.location.country_code,
      latitude: candidate.location.latitude,
      longitude: candidate.location.longitude,
      timezoneId: timezone,
      locationSourceId: candidate.id,
      timezoneStatus: candidate.timezone_status,
    });
    setLocationCandidates([]);
    setLocationSearchActive(false);
    setLocationMessage(candidate.timezone_status === "resolved"
      ? `已使用 ${candidate.label}，IANA 时区由边界数据自动确认。`
      : "地点已选择，但时区处于边界歧义或弱提示状态，请在下方人工确认 IANA 时区。 ");
  };

  const updatePlaceQuery = (value: string) => {
    setLocationCandidates([]);
    setLocationSearchActive(value.trim().length >= 2);
    onChange({ ...person, placeName: value, locationSourceId: undefined, timezoneStatus: "unresolved" });
  };
  return <div className="form-grid">
    <label>名称<input value={person.displayName} onChange={(event) => onChange({ ...person, displayName: event.target.value })} placeholder="本人或关系人物名称" /></label>
    <label>与我的关系<select value={person.relation} onChange={(event) => onChange({ ...person, relation: event.target.value as NatalPersonInput["relation"] })}><option value="self">本人</option><option value="family">亲人</option><option value="partner">伴侣</option><option value="friend">朋友</option><option value="client">客户</option><option value="other">其他</option></select></label>
    <label>时间精度<select value={person.timePrecision} onChange={(event) => { const precision = event.target.value as NatalPersonInput["timePrecision"]; onChange({ ...person, timePrecision: precision, timeConfidence: precision === "date" || precision === "unknown" ? "unknown" : person.timeConfidence === "unknown" ? "low" : person.timeConfidence }); }}><option value="minute">精确到分钟</option><option value="hour">精确到小时</option><option value="date">只有日期</option><option value="unknown">出生时刻未知</option></select><small>“只有日期／时刻未知”按完整当地民用日计算范围，绝不默认 00:00。</small></label>
    <label>出生日期<input type="date" value={person.localDate} onChange={(event) => onChange({ ...person, localDate: event.target.value })} /></label>
    <label>出生时间<input type="time" value={person.localTime} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} step={person.timePrecision === "hour" ? 3600 : 60} onChange={(event) => onChange({ ...person, localTime: event.target.value })} /><small>{person.timePrecision === "date" || person.timePrecision === "unknown" ? "将只返回日期级天体位置及不确定范围；上升、宫位、相位、阿拉伯点、昼夜体系与古典时刻判断不会生成。" : "输入的是出生地当地钟表时间；系统会使用历史 IANA 时区规则换算 UTC。"}</small></label>
    <label className="location-search-field">出生城市／地区<input role="combobox" aria-autocomplete="list" aria-controls="birth-location-options" value={person.placeName} onChange={(event) => updatePlaceQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Escape") { setLocationSearchActive(false); setLocationCandidates([]); } }} placeholder="输入城市、区县或多语言地名" autoComplete="off" aria-expanded={locationSearchActive && locationCandidates.length > 0} />{locationLoading && locationSearchActive && <small>正在搜索地点…</small>}{locationSearchActive && locationCandidates.length > 0 && <span id="birth-location-options" className="location-candidates" role="listbox">{locationCandidates.map((candidate) => <button type="button" role="option" aria-selected="false" key={candidate.id} onClick={() => selectLocation(candidate)}><b>{candidate.label}</b><small>{candidate.location.latitude.toFixed(4)}, {candidate.location.longitude.toFixed(4)} · {candidate.timezone_status === "resolved" ? candidate.location.timezone_id : `时区需确认（${candidate.timezone_candidates.map((item) => item.timezone_id).join(" / ") || "无候选"}）`}</small></button>)}</span>}<small>{locationMessage || "输入至少两个字符后显示地点候选；选择后自动填写经纬度、国家和 IANA 时区。地点精确到城市或区县即可，无需填写街道或医院。"}</small></label>
    <label>IANA 时区<select value={person.timezoneId} onChange={(event) => onChange({ ...person, timezoneId: event.target.value, timezoneStatus: "manual" })}>{timezoneOptions.map((timezone) => <option key={timezone} value={timezone}>{timezone}</option>)}</select><small>{person.timezoneStatus === "ambiguous" || person.timezoneStatus === "degraded" ? "地点数据未能唯一确认时区，必须人工确认。" : "时区使用 IANA 标识；历史夏令时由规则库计算，不让用户填写 UTC 偏移。"}</small></label>
    <label>时间可信度<select value={person.timeConfidence} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} onChange={(event) => onChange({ ...person, timeConfidence: event.target.value as NatalPersonInput["timeConfidence"] })}><option value="high">高：出生证明或正式记录</option><option value="medium">中：本人或亲友记忆</option><option value="low">低：大致时间</option><option value="unknown">未知：没有出生时刻</option></select></label>
    {(person.timePrecision === "date" || person.timePrecision === "unknown") && <p className="time-precision-warning"><b>日期级模式</b><span>可以计算天体在该日期内的星座位置范围、运动方向范围与跨界风险；不能生成完整本命盘。补充可靠出生时刻后才会开放四轴、十二宫、相位和古典结果。</span></p>}
    <details className="advanced-location"><summary>高级位置覆盖</summary><div><label>纬度<input type="number" step="0.0001" value={person.latitude} onChange={(event) => onChange({ ...person, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={person.longitude} onChange={(event) => onChange({ ...person, longitude: Number(event.target.value) })} /></label></div><p>一般无需修改。国家代码由地点候选派生，仅用于消歧，不参与占星判断。</p></details>
  </div>;
}

function SharedAdvancedCalculationFields({
  settings,
  groups,
  chartLabel,
  onSettingsChange,
  onGroupsChange,
}: {
  settings: NatalCalculationSettings;
  groups: NatalPointGroups;
  chartLabel: string;
  onSettingsChange: (settings: NatalCalculationSettings) => void;
  onGroupsChange: (groups: NatalPointGroups) => void;
}) {
  return <>
    {settings.zodiac === "sidereal" && <label>岁差体系 Ayanamsa<select value={settings.ayanamsa} onChange={(event) => onSettingsChange({ ...settings, ayanamsa: event.target.value as NatalCalculationSettings["ayanamsa"] })}>{ayanamsaOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select><small>重新计算后，点位、相位与轮盘会一起切换到所选恒星黄道。</small></label>}
    <label>观测中心<select value={settings.center} onChange={(event) => onSettingsChange({ ...settings, center: event.target.value as NatalCalculationSettings["center"] })}><option value="geocentric">Geocentric 地心</option><option value="topocentric">Topocentric 地点拓扑中心</option></select><small>拓扑中心会使用当前地点经纬度重新计算，不只是改变显示名称。</small></label>
    <fieldset><legend>古典规则表（需重新计算）</legend><label>三分主星表<select value={settings.triplicityTable} onChange={(event) => onSettingsChange({ ...settings, triplicityTable: event.target.value as NatalCalculationSettings["triplicityTable"] })}><option value="dorothean">多罗修斯表</option><option value="ptolemaic">托勒密表</option></select></label><label>界表<select value={settings.termsTable} onChange={(event) => onSettingsChange({ ...settings, termsTable: event.target.value as NatalCalculationSettings["termsTable"] })}><option value="egyptian">埃及界</option><option value="ptolemaic">托勒密界</option></select></label></fieldset>
    <fieldset><legend>计算点位（需重新计算）</legend>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <div className="point-selection-group" key={`${chartLabel}-${group}`}><label className="check-option"><input type="checkbox" checked={groups[group]} onChange={(event) => { const enabled = event.target.checked; onGroupsChange({ ...groups, [group]: enabled }); if (enabled) onSettingsChange({ ...settings, disabledPointIds: settings.disabledPointIds.filter((id) => !pointGroups[group].includes(id as never)) }); }} /><span>{pointGroupLabels[group]}</span><small>{groups[group] ? pointGroups[group].filter((id) => !settings.disabledPointIds.includes(id)).length : 0}/{group === "angles" ? pointGroups[group].length + unavailableVirtualPoints.length : pointGroups[group].length}</small></label><details><summary>逐项选择</summary><div>{pointGroups[group].map((id) => <label className="check-option" key={`${chartLabel}-${group}-${id}`}><input type="checkbox" disabled={!groups[group]} checked={groups[group] && !settings.disabledPointIds.includes(id)} onChange={(event) => onSettingsChange({ ...settings, disabledPointIds: event.target.checked ? settings.disabledPointIds.filter((item) => item !== id) : [...settings.disabledPointIds, id] })} /><span>{pointNames[id] ?? id}</span></label>)}{group === "angles" && unavailableVirtualPoints.map((item) => <label className="check-option unavailable-point" key={`${chartLabel}-${item.id}`} title={item.reason}><input type="checkbox" disabled /><span>{pointNames[item.id]}</span><small>暂不可用</small></label>)}</div></details></div>)}</fieldset>
    <fieldset><legend>固定星（需重新计算）</legend><label className="check-option"><input type="checkbox" checked={settings.fixedStarIds.length === fixedStarOptions.length} onChange={(event) => onSettingsChange({ ...settings, fixedStarIds: event.target.checked ? fixedStarOptions.map(([id]) => id) : [] })} /><span>24 颗常用固定星</span><small>{settings.fixedStarIds.length}/{fixedStarOptions.length}</small></label><details className="orb-overrides"><summary>逐颗选择固定星</summary><div>{fixedStarOptions.map(([id, label]) => <label className="check-option" key={`${chartLabel}-${id}`}><input type="checkbox" checked={settings.fixedStarIds.includes(id)} onChange={(event) => onSettingsChange({ ...settings, fixedStarIds: event.target.checked ? [...settings.fixedStarIds, id] : settings.fixedStarIds.filter((item) => item !== id) })} /><span>{label}</span></label>)}</div></details><label>固定星合相范围 {settings.fixedStarOrb.toFixed(1)}°<input type="range" min="0.1" max="3" step="0.1" value={settings.fixedStarOrb} onChange={(event) => onSettingsChange({ ...settings, fixedStarOrb: Number(event.target.value) })} /></label></fieldset>
    <fieldset><legend>特殊事实（需重新计算）</legend><label>映点／反映点接触范围 {settings.mirrorOrb.toFixed(1)}°<input type="range" min="0" max="5" step="0.1" value={settings.mirrorOrb} onChange={(event) => onSettingsChange({ ...settings, mirrorOrb: Number(event.target.value) })} /><small>每个点位的映点位置都会计算；这个数值控制多接近才算接触。</small></label><label>中点命中范围 {settings.midpointOrb.toFixed(1)}°<input type="range" min="0" max="5" step="0.1" value={settings.midpointOrb} onChange={(event) => onSettingsChange({ ...settings, midpointOrb: Number(event.target.value) })} /></label></fieldset>
    <fieldset><legend>相位计算（需重新计算）</legend><label className="check-option"><input type="checkbox" checked={!settings.aspectIds.length} onChange={(event) => onSettingsChange({ ...settings, aspectIds: event.target.checked ? [] : [...majorAspectIds] })} /><span>完整专业相位集</span><small>{allAspectIds.length}</small></label><div className="aspect-toggle-grid">{allAspectIds.map((aspect) => <button type="button" key={`${chartLabel}-${aspect}`} className={!settings.aspectIds.length || settings.aspectIds.includes(aspect) ? "on" : ""} onClick={() => { const base = settings.aspectIds.length ? settings.aspectIds : [...allAspectIds]; onSettingsChange({ ...settings, aspectIds: base.includes(aspect) ? base.filter((id) => id !== aspect) : [...base, aspect] }); }}>{aspectNames[aspect] ?? aspect}</button>)}</div><details className="orb-overrides"><summary>容许度层级（全局／盘型／相位／类别／点位对）</summary><div className="orb-hierarchy"><div className="orb-level-grid"><label><span>全局</span><input type="number" min="0" max="30" step="0.1" placeholder="规则默认" value={settings.globalOrb ?? ""} onChange={(event) => onSettingsChange({ ...settings, globalOrb: event.target.value === "" ? null : Number(event.target.value) })} /></label><label><span>{chartLabel}</span><input type="number" min="0" max="30" step="0.1" placeholder="继承全局" value={settings.chartOrb ?? ""} onChange={(event) => onSettingsChange({ ...settings, chartOrb: event.target.value === "" ? null : Number(event.target.value) })} /></label></div><h4>指定相位</h4><div className="orb-level-grid">{allAspectIds.map((aspect) => <label key={`${chartLabel}-orb-${aspect}`}><span>{aspectNames[aspect] ?? aspect}</span><input type="number" min="0" max="30" step="0.1" placeholder="继承上级" value={settings.orbOverrides[aspect] ?? ""} onChange={(event) => { const next = { ...settings.orbOverrides }; if (event.target.value === "") delete next[aspect]; else next[aspect] = Number(event.target.value); onSettingsChange({ ...settings, orbOverrides: next }); }} /></label>)}</div><h4>点位类别</h4><div className="orb-level-grid">{orbPointClassOptions.map(([id, label]) => <label key={`${chartLabel}-class-orb-${id}`}><span>{label}</span><input type="number" min="0" max="30" step="0.1" placeholder="继承上级" value={settings.pointClassOrbs[id] ?? ""} onChange={(event) => { const next = { ...settings.pointClassOrbs }; if (event.target.value === "") delete next[id]; else next[id] = Number(event.target.value); onSettingsChange({ ...settings, pointClassOrbs: next }); }} /></label>)}</div><h4>指定点位对</h4><div className="point-pair-orbs">{settings.pointPairOrbs.map((pair, index) => <div className="point-pair-row" key={`${chartLabel}-${pair.pointA}:${pair.pointB}:${index}`}><select aria-label={`${chartLabel}点位对 ${index + 1} 第一个点`} value={pair.pointA} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, pointA: event.target.value }; onSettingsChange({ ...settings, pointPairOrbs: next }); }}>{orbPointOptions.map((id) => <option value={id} key={`${chartLabel}-a-${index}-${id}`}>{pointNames[id] ?? id}</option>)}</select><select aria-label={`${chartLabel}点位对 ${index + 1} 第二个点`} value={pair.pointB} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, pointB: event.target.value }; onSettingsChange({ ...settings, pointPairOrbs: next }); }}>{orbPointOptions.map((id) => <option value={id} key={`${chartLabel}-b-${index}-${id}`}>{pointNames[id] ?? id}</option>)}</select><input aria-label={`${chartLabel}点位对 ${index + 1} 容许度`} type="number" min="0" max="30" step="0.1" value={pair.orb} onChange={(event) => { const next = [...settings.pointPairOrbs]; next[index] = { ...pair, orb: Number(event.target.value) }; onSettingsChange({ ...settings, pointPairOrbs: next }); }} /><button type="button" aria-label={`删除${chartLabel}点位对 ${index + 1}`} onClick={() => onSettingsChange({ ...settings, pointPairOrbs: settings.pointPairOrbs.filter((_, pairIndex) => pairIndex !== index) })}>×</button></div>)}<button type="button" className="add-point-pair" onClick={() => onSettingsChange({ ...settings, pointPairOrbs: [...settings.pointPairOrbs, { pointA: "sun", pointB: "moon", orb: 8 }] })}>＋ 添加点位对</button></div><small className="orb-precedence">优先级：指定点位对 ＞ 点位类别 ＞ 指定相位 ＞ {chartLabel} ＞ 全局 ＞ 规则预设。</small></div></details></fieldset>
  </>;
}

function TechniqueGuideDialog({
  open,
  title,
  path,
  onClose,
}: {
  open: boolean;
  title: string;
  path: string;
  onClose: () => void;
}) {
  const [markdown, setMarkdown] = useState("");
  useEffect(() => {
    let active = true;
    if (!open || markdown) return () => { active = false; };
    fetch(path, { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error(String(response.status));
        return response.text();
      })
      .then((text) => {
        const content = text
          .replace(/^\uFEFF?---\r?\n[\s\S]*?\r?\n---\r?\n/, "")
          .trim();
        if (active) setMarkdown(content);
      })
      .catch(() => { if (active) setMarkdown(`# ${title}\n\n说明暂时无法读取，请稍后重试。`); });
    return () => { active = false; };
  }, [markdown, open, path, title]);
  if (!open) return null;
  return <div className="modal-backdrop guide-modal-backdrop" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose(); }}><section className="person-modal natal-guide-modal" role="dialog" aria-modal="true" aria-label={title}><header><div><small>CHART GUIDE</small><h2>{title}</h2></div><button onClick={onClose} aria-label={`关闭${title}`}>×</button></header><div className="natal-guide-content">{markdown ? <SafeMarkdownDocument markdown={markdown} /> : <p>正在读取说明…</p>}</div></section></div>;
}

function ConsumerInsightCards({
  insight,
  themeLabel,
  signalsTitle,
  signalsHint,
  advice,
  closing,
}: {
  insight: ConsumerInsight;
  themeLabel: string;
  signalsTitle: string;
  signalsHint: string;
  advice: ReactNode;
  closing: string;
}) {
  return (
    <article className="instant-insight">
      <section className="instant-theme"><span>{themeLabel}</span><h3>{insight.title}</h3><p>{insight.summary}</p></section>
      <section className="insight-dimensions">{insight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section>
      <section className="aspect-balance"><header><b>顺势的地方与容易卡住的地方</b></header><div><span className="supportive" style={{ flex: insight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: insight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: insight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {insight.aspectBalance.supportive}</span><span>需要协调 {insight.aspectBalance.tension}</span><span>彼此相连 {insight.aspectBalance.neutral}</span></footer><p>{insight.aspectBalance.meaning}</p></section>
      <section className="top-signals"><header><b>{signalsTitle}</b><small>{signalsHint}</small></header>{insight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>)}</section>
      <section className="insight-advice">{advice}</section>
      <section className="insight-closing"><b>最后提醒</b><p>{closing}</p></section>
    </article>
  );
}

function NonNatalInterpretationSection({
  insight,
  sections,
  empty,
}: {
  insight: ConsumerInsight | null;
  sections: InterpretationSection[];
  empty?: ReactNode;
}) {
  const [activeTab, setActiveTab] = useState("overview");
  const tabs = [{ id: "overview", label: "整体解读" }, ...sections.map((s) => ({ id: s.id, label: s.label }))];
  return (
    <section className="result-section non-natal-interpretation" id="non-natal-interpretation">
      <div className="result-tabs">
        {tabs.map((tab) => <button key={tab.id} className={activeTab === tab.id ? "active" : ""} onClick={() => setActiveTab(tab.id)}>{tab.label}</button>)}
      </div>
      <div className="result-content">
        {activeTab === "overview" && (insight
          ? <ConsumerInsightCards
              insight={insight}
              themeLabel="整体解读"
              signalsTitle="最值得留意的信号"
              signalsHint="数字越高，当前关系越紧密"
              advice={<><div><b>比较适合做的事</b>{insight.strengths.map((item) => <p key={item}>• {item}</p>)}</div><div><b>需要注意的方面</b>{insight.reminders.map((item) => <p key={item}>• {item}</p>)}</div></>}
              closing={insight.closing}
            />
          : (empty ?? <div className="interpretation-empty"><p>等待计算完成后查看整体解读。</p></div>)
        )}
        {activeTab !== "overview" && <div className="interpretation-grid">
          {sections.find((s) => s.id === activeTab)?.cards.map((card) => (
            <article className="professional-card interpretation-card" key={card.id}>
              <header><div><small>{card.subtitle}</small><h3>{card.title}</h3></div></header>
              <ul>{card.bullets.map((bullet, index) => <li key={index}>{bullet}</li>)}</ul>
              {card.emphasis && <p>{card.emphasis}</p>}
            </article>
          ))}
        </div>}
      </div>
    </section>
  );
}

function CurrentSkyCalculationPanel({ snapshot, resultTab, setResultTab, onBack }: { snapshot: NatalSnapshot | null; resultTab: CurrentSkyResultTab; setResultTab: (tab: CurrentSkyResultTab) => void; onBack: () => void; }) {
  if (!snapshot) return null;
  const context = asRecord(snapshot.result.astronomical_context);
  const lunarPhase = asRecord(context.lunar_phase);
  const strongestAspects = [...snapshot.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 5);
  const stationaryPoints = snapshot.result.points.filter((p) => p.position.motion_state === "stationary");
  const retrogradePoints = snapshot.result.points.filter((p) => p.retrograde);
  return (
    <>
      <div className="calculation-view-toolbar"><button onClick={onBack}>← 返回轮盘</button><span>{snapshot.result.points.length} 点 · {snapshot.result.aspects.length} 相位</span></div>
      <nav className="calculation-result-tabs" aria-label="天象盘计算结果分类">{currentSkyResultTabs.map((item) => <button key={item.id} className={resultTab === item.id ? "active" : ""} onClick={() => setResultTab(item.id)}>{item.label}</button>)}</nav>
      {currentSkySharedResultTabs.has(resultTab) && <CalculationResults snapshot={snapshot} tab={resultTab as CalculationTab} />}
      {resultTab === "aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>点位 A</span><span>相位</span><span>点位 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span></div>{snapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "events" && <div className="calculation-result-content"><div className="section-copy"><div><small>EXACT MOMENT SKY FACTS</small><h2>目标时刻天象</h2><p>这里展示本次精确时刻已经成立的事实。</p></div></div><div className="fact-card-grid"><article className="professional-card"><h3>月相</h3><p>{lunarPhaseLabel(lunarPhase.phase)}；月龄约 {Number(lunarPhase.lunar_age_days ?? 0).toFixed(1)} 天，亮面约 {Math.round(Number(lunarPhase.illumination_fraction ?? 0) * 100)}%。</p></article><article className="professional-card"><h3>逆行行星</h3><p>{retrogradePoints.map((point) => pointNames[point.point_id] ?? point.point_id).join("、") || "当前所选点位中无逆行行星"}</p></article><article className="professional-card"><h3>停驻点位</h3><p>{stationaryPoints.map((point) => pointNames[point.point_id] ?? point.point_id).join("、") || "当前精确时刻没有点位处于停驻阈值内"}</p></article><article className="professional-card"><h3>最紧密相位</h3><p>{strongestAspects.slice(0, 3).map((aspect) => `${pointNames[aspect.point_a] ?? aspect.point_a}${aspectNames[aspect.type] ?? aspect.type}${pointNames[aspect.point_b] ?? aspect.point_b}（${aspect.orb_deg.toFixed(2)}°）`).join("；") || "当前相位集没有命中"}</p></article></div></div>}
    </>
  );
}

function TransitCalculationPanel({ comparison, movingLayer, resultTab, setResultTab, onBack }: { comparison: ChartComparison | null; movingLayer: NatalSnapshot | null; resultTab: TransitResultTab; setResultTab: (tab: TransitResultTab) => void; onBack: () => void; }) {
  if (!comparison || !movingLayer) return null;
  return (
    <>
      <div className="calculation-view-toolbar"><button onClick={onBack}>← 返回轮盘</button><span>{movingLayer.result.points.length} 点 · {comparison.result.cross_aspects.length} 跨盘相位</span></div>
      <nav className="calculation-result-tabs" aria-label="行运盘计算结果分类">{transitResultTabs.map((item) => <button key={item.id} className={resultTab === item.id ? "active" : ""} onClick={() => setResultTab(item.id)}>{item.label}</button>)}</nav>
      {resultTab === "overview" && <div className="calculation-result-content"><div className="calculation-summary-grid"><article><span>本命点位</span><b>{comparison.result.reference_snapshot_id ? "已加载" : "—"}</b><small>上一次已计算结果</small></article><article><span>行运点位</span><b>{movingLayer.result.points.length}</b><small>目标时刻天空</small></article><article><span>天象盘内相位</span><b>{movingLayer.result.aspects.length}</b><small>行运点位彼此关系</small></article><article><span>跨盘相位</span><b>{comparison.result.cross_aspects.length}</b><small>行运点对本命点</small></article></div></div>}
      {transitSharedResultTabs.has(resultTab) && <CalculationResults snapshot={movingLayer} tab={resultTab as CalculationTab} />}
      {resultTab === "aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>行运点 A</span><span>相位</span><span>行运点 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span></div>{movingLayer.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "cross_aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>行运点</span><span>相位</span><span>本命点</span><span>实际角距</span><span>偏差</span><span>阶段</span><span>强度</span></div>{comparison.result.cross_aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "reference_houses" && <div className="calculation-result-content"><div className="wide-result-table house-result-table"><div className="wide-result-head"><span>行运点</span><span>落入本命宫位</span><span>生活领域</span><span>是否贴近宫头</span><span>宫头编号</span></div>{comparison.result.moving_points_in_reference_houses.map((item) => <div className="wide-result-row" key={item.moving_point_id}><b>{pointNames[item.moving_point_id] ?? item.moving_point_id}</b><span>第{item.reference_house}宫</span><span>{houseDomains[item.reference_house - 1]}</span><span>{item.on_cusp ? "是" : "否"}</span><span>{item.cusp_number ?? "—"}</span></div>)}</div></div>}
    </>
  );
}

function SecondaryCalculationPanel({ result, resultTab, setResultTab, onBack }: { result: SecondaryProgressionResult | null; resultTab: SecondaryResultTab; setResultTab: (tab: SecondaryResultTab) => void; onBack: () => void; }) {
  if (!result) return null;
  const comparison = result.comparison;
  const progressedSnapshot = result.progressed_snapshot;
  return (
    <>
      <div className="calculation-view-toolbar"><button onClick={onBack}>← 返回轮盘</button><span>{progressedSnapshot.result.points.length} 点 · {comparison.result.cross_aspects.length} 跨盘相位</span></div>
      <nav className="calculation-result-tabs" aria-label="次限盘计算结果分类">{secondaryResultTabs.map((item) => <button key={item.id} className={resultTab === item.id ? "active" : ""} onClick={() => setResultTab(item.id)}>{item.label}</button>)}</nav>
      {resultTab === "overview" && <div className="calculation-result-content"><div className="calculation-summary-grid"><article><span>固定本命点位</span><b>{result.reference_snapshot_id ? "已加载" : "—"}</b><small>直接读取上一次结果</small></article><article><span>次限点位</span><b>{progressedSnapshot.result.points.length}</b><small>{result.progressed_time.replace("T", " ")}</small></article><article><span>次限盘内相位</span><b>{progressedSnapshot.result.aspects.length}</b><small>次限点位彼此关系</small></article><article><span>跨盘相位</span><b>{comparison.result.cross_aspects.length}</b><small>次限点位对本命点位</small></article></div></div>}
      {secondarySharedResultTabs.has(resultTab) && <CalculationResults snapshot={progressedSnapshot} tab={resultTab as CalculationTab} />}
      {resultTab === "aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>次限点 A</span><span>相位</span><span>次限点 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span></div>{progressedSnapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "cross_aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>次限点</span><span>相位</span><span>本命点</span><span>实际角距</span><span>偏差</span><span>阶段</span><span>强度</span></div>{comparison.result.cross_aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "reference_houses" && <div className="calculation-result-content"><div className="wide-result-table house-result-table"><div className="wide-result-head"><span>次限点</span><span>落入本命宫位</span><span>生活领域</span><span>贴近宫头</span><span>宫头编号</span></div>{comparison.result.moving_points_in_reference_houses.map((item) => <div className="wide-result-row" key={item.moving_point_id}><b>{pointNames[item.moving_point_id] ?? item.moving_point_id}</b><span>第{item.reference_house}宫</span><span>{houseDomains[item.reference_house - 1]}</span><span>{item.on_cusp ? "是" : "否"}</span><span>{item.cusp_number ?? "—"}</span></div>)}</div></div>}
    </>
  );
}


function CurrentSkyWorkspace({ theme }: { theme: ThemeMode }) {
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
    setInput(nextInput);
    queueMicrotask(() => void calculate(nextInput));
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

function TransitWorkspace({
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
    setInput(nextInput);
    queueMicrotask(() => void calculate(nextInput));
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

function SecondaryProgressionsWorkspace({
  theme,
  person,
  latestNatalSnapshot,
}: {
  theme: ThemeMode;
  person: NatalPersonInput;
  latestNatalSnapshot: NatalSnapshot;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const [targetDate, setTargetDate] = useState(today);
  const [settings, setSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [groups, setGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(() => cloneNatalSettings(defaultTimingSettings));
  const [appliedGroups, setAppliedGroups] = useState<NatalPointGroups>(() => cloneNatalPointGroups(defaultTimingGroups));
  const [appliedTargetDate, setAppliedTargetDate] = useState<string | null>(null);
  const [result, setResult] = useState<SecondaryProgressionResult | null>(null);
  const [wheelMode, setWheelMode] = useState<"single" | "double">("double");
  const [guideOpen, setGuideOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState(`选择目标日期后点击计算；系统会直接读取${person.displayName}上一次本命结果，只计算新的次限层。`);
  const secondaryAutoCalculated = useRef(false);
  useEffect(() => {
    if (secondaryAutoCalculated.current) return;
    secondaryAutoCalculated.current = true;
    const today = new Date().toISOString().slice(0, 10);
    setTargetDate(today);
    queueMicrotask(() => void calculate(today));
  }, []);
  const [resultTab, setResultTab] = useState<SecondaryResultTab>("overview");
  const [showCalculationResults, setShowCalculationResults] = useState(false);
  const presetId = useMemo(() => identifyTimingPreset(settings, groups), [settings, groups]);
  const visiblePointIds = useMemo(() => effectivePointIds(appliedSettings, appliedGroups), [appliedSettings, appliedGroups]);
  const controls = useMemo<NatalRenderControls>(() => ({ ...defaultWheelControls, visiblePointIds }), [visiblePointIds]);
  const natalRenderSpec = useMemo(
    () => buildNatalRenderSpec(latestNatalSnapshot, "professional", theme, controls),
    [latestNatalSnapshot, theme, controls],
  );
  const progressedSnapshot = result?.progressed_snapshot ?? null;
  const comparison = result?.comparison ?? null;
  const progressedRenderSpec = useMemo(
    () => progressedSnapshot ? buildNatalRenderSpec(progressedSnapshot, "professional", theme, controls, "current_sky") : null,
    [progressedSnapshot, theme, controls],
  );
  const secondaryInsight = useMemo(
    () => result ? buildSecondaryProgressionConsumerInsight(result, latestNatalSnapshot) : null,
    [result, latestNatalSnapshot],
  );

  function applyPreset(id: Exclude<NatalPresetId, "custom">) {
    const preset = timingCalculationPresets.find((item) => item.id === id);
    if (!preset) return;
    setSettings(cloneNatalSettings(preset.settings));
    setGroups(cloneNatalPointGroups(preset.groups));
  }

  async function calculate(computeTargetDate = targetDate) {
    if (person.timePrecision === "date" || person.timePrecision === "unknown") {
      setNotice("次限盘需要可靠的出生时刻；当前人物只有日期，不能用午夜代替。");
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
    setNotice("正在换算次限日期、计算次限点位，并与上一次本命结果比较…");
    try {
      const calculated = await createSecondaryProgression(
        latestNatalSnapshot,
        person,
        computeTargetDate,
        requestSettings,
      );
      setResult(calculated);
      setAppliedTargetDate(targetDate);
      setAppliedSettings(cloneNatalSettings(requestSettings));
      setAppliedGroups(cloneNatalPointGroups(groups));
      setWheelMode("double");
      setResultTab("overview");
      setNotice("次限盘已更新。修改目标日期或参数后，需要再次点击计算才会生效。");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : `次限盘计算失败：${error instanceof Error ? error.message : "未知错误"}`);
    } finally {
      setBusy(false);
    }
  }

  const strongest = comparison
    ? [...comparison.result.cross_aspects].sort((left, right) => right.strength - left.strength || left.orb_deg - right.orb_deg).slice(0, 5)
    : [];
  const progressedMoon = progressedSnapshot?.result.points.find((point) => point.point_id === "moon");
  const progressedSun = progressedSnapshot?.result.points.find((point) => point.point_id === "sun");
  const lunarPhase = asRecord(asRecord(progressedSnapshot?.result.astronomical_context).lunar_phase);
  const houseHighlights = comparison?.result.moving_points_in_reference_houses
    .filter((item) => ["sun", "moon", "mercury", "venus", "mars"].includes(item.moving_point_id))
    .slice(0, 5) ?? [];

  return <section className="main-workspace secondary-progressions-workspace">
    {notice && <div className="app-toast" role="status"><p>{notice}</p><button onClick={() => setNotice("")} aria-label="关闭提示">×</button></div>}
    <div className="workbench-grid">
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading"><div className="wheel-heading-main"><div><small>SECONDARY PROGRESSIONS · NATAL + PROGRESSED</small><h2>{person.displayName}的次限盘</h2></div><div className="wheel-heading-actions">{result && <><button className="result-flip-button" onClick={() => setShowCalculationResults(true)}>查看结果</button><div className="view-switcher" aria-label="次限盘单双盘切换"><button className={wheelMode === "single" ? "active" : ""} onClick={() => setWheelMode("single")}>单盘</button><button className={wheelMode === "double" ? "active" : ""} onClick={() => setWheelMode("double")}>双盘</button></div></>}<button className="natal-guide-link" onClick={() => setGuideOpen(true)}>什么是次限盘？</button></div></div><div className="chart-selector-bar chart-selector-bar-single"><label>目标日期<input type="date" min={person.localDate} value={targetDate} onChange={(event) => setTargetDate(event.target.value)} /></label><small>系统按出生日至目标日的实际天数换算次限时刻，一年人生对应出生后一日。</small></div></div>
        {showCalculationResults ? (
          <SecondaryCalculationPanel result={result} resultTab={resultTab} setResultTab={setResultTab} onBack={() => setShowCalculationResults(false)} />
        ) : (
          <>
            <div className="wheel-canvas-area">{progressedSnapshot && comparison ? wheelMode === "double" ? <ComparisonWheel natalSnapshot={latestNatalSnapshot} movingSnapshot={progressedSnapshot} comparison={comparison} renderSpec={natalRenderSpec} controls={controls} chartLabel="次限盘" movingLabel="次限外层" /> : progressedRenderSpec ? <NatalWheel snapshot={progressedSnapshot} renderSpec={progressedRenderSpec} controls={controls} /> : null : <div className="sky-empty-state"><span>◔</span><h3>次限盘尚未计算</h3><p>本命盘保持上一次计算结果不动，只按现代预设计算目标日期对应的次限层。</p><button onClick={() => void calculate()} disabled={busy}>{busy ? "计算中…" : "计算次限盘"}</button></div>}</div>
            <footer><span>{person.displayName} · {person.localDate}</span><span>目标 {appliedTargetDate ?? targetDate}</span><span>{result ? `次限时刻 ${result.progressed_time.replace("T", " ")}` : "一年对应一日"}</span><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : "恒星黄道"}</span></footer>
          </>
        )}
      </article>

      <aside className="settings-panel">
        <div className="settings-title"><div><small>SECONDARY PROGRESSION SETTINGS</small><h2>次限盘参数</h2></div><div className="settings-title-actions"><span className="settings-title-status">双盘</span><button className="settings-header-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "计算中…" : "计算"}</button></div></div>
        <div className="preset-shortcuts" aria-label="次限盘预设">{timingCalculationPresets.map((preset) => <button key={preset.id} className={presetId === preset.id ? "active" : ""} onClick={() => applyPreset(preset.id)}><b>{preset.label}</b><small>{preset.badge}</small></button>)}</div>
        <p className="sky-person-boundary"><b>固定本命：{person.displayName}</b><span>本命点位与宫位直接读取上一次结果；默认只给次限层加载现代预设。</span></p>

        <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label>
        <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
        <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="true">真交点</option><option value="mean">平均交点</option><option value="both">两者</option></select></label>
        <label>相位容许度体系<select value={settings.orbMode} onChange={(event) => setSettings({ ...settings, orbMode: event.target.value as NatalCalculationSettings["orbMode"] })}><option value="modern_aspect">现代－按相位</option><option value="classical_starlight">古典－星光容许度</option></select></label>
        <SharedAdvancedCalculationFields settings={settings} groups={groups} chartLabel="次限盘" onSettingsChange={setSettings} onGroupsChange={setGroups} />
        <button className="settings-calculate" disabled={busy} onClick={() => void calculate()}>{busy ? "正在计算…" : "按当前参数重新计算"}</button>
      </aside>

      <aside className="ai-insight-panel">
        <header><div><small>PROGRESSION INSIGHT · LOCAL</small><h2>这一阶段怎么看</h2></div></header>
        {secondaryInsight ? <article className="instant-insight">
          <section className="instant-theme"><span>阶段重点</span><h3>{secondaryInsight.title}</h3><p>{secondaryInsight.summary}</p></section>
          <section className="insight-dimensions">{secondaryInsight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section>
          <section className="aspect-balance"><header><b>顺势的地方与容易卡住的地方</b></header><div><span className="supportive" style={{ flex: secondaryInsight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: secondaryInsight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: secondaryInsight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {secondaryInsight.aspectBalance.supportive}</span><span>需要协调 {secondaryInsight.aspectBalance.tension}</span><span>彼此相连 {secondaryInsight.aspectBalance.neutral}</span></footer><p>{secondaryInsight.aspectBalance.meaning}</p></section>
          <section className="top-signals"><header><b>最明显的变化信号</b><small>越靠前，当前关系越紧密</small></header>{secondaryInsight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>)}</section>
          <section className="insight-advice"><div><b>变化落在生活哪里</b>{houseHighlights.map((item) => <p key={item.moving_point_id}>• 次限{pointNames[item.moving_point_id] ?? item.moving_point_id}落入本命第{item.reference_house}宫：这一阶段更容易围绕“{houseDomains[item.reference_house - 1]}”发生内在调整。</p>)}</div><div><b>怎么使用</b><p>{secondaryInsight.strengths.map((item) => <p key={item}>• {item}</p>)}</p><p>{secondaryInsight.reminders.map((item) => <p key={item}>• {item}</p>)}</p></div></section>
          <section className="insight-closing"><b>最后提醒</b><p>{secondaryInsight.closing}</p></section>
        </article> : <div className="ai-waiting"><b>等待计算</b><p>计算完成后会立即用大白话说明次限月亮、次限太阳、次限月相和最明显的成长主题，不调用大模型。</p></div>}
        <footer><span>本地即时解读</span><small>只有点击计算才会更新；修改日期或参数不会自动提交。</small></footer>
      </aside>
    </div>

    {result && progressedSnapshot && comparison && <NonNatalInterpretationSection insight={secondaryInsight} sections={buildSecondaryProgressionInterpretationSections(result)} />}
    <TechniqueGuideDialog open={guideOpen} title="什么是次限盘？" path="/secondary-progressions-guide.md" onClose={() => setGuideOpen(false)} />
  </section>;
}

export default function Home() {
  const [activeTechnique, setActiveTechnique] = useState<"natal" | "current_sky" | "transits" | "secondary_progressions">("natal");
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
        providerId: "deepseek",
        modelId: deepseekModel.model_id,
        focus: "",
        storeResponse: accountWorkspace.authenticated && Boolean(submittedPersonId),
      });
      const artifact = await submitNatalToAi({
        snapshotId: submittedSnapshotId,
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

      <nav className="technique-strip" aria-label="盘型切换">{chartTechniques.map((technique) => <button key={technique.id} className={technique.id === activeTechnique ? "active" : technique.status === "active" ? "" : "planned"} onClick={() => { if (technique.id === "natal" || technique.id === "current_sky" || technique.id === "transits" || technique.id === "secondary_progressions") { setActiveTechnique(technique.id); setShowCalculationResults(false); window.scrollTo({ top: 0, behavior: "smooth" }); } else setCapabilityTarget(technique); }}><b>{technique.label}</b><small>{technique.id === activeTechnique ? "当前" : technique.status === "active" ? "可用" : "规划中"}</small></button>)}</nav>

      <div className="natal-layout">
        {activeTechnique === "current_sky" ? <CurrentSkyWorkspace theme={theme} /> : !workspaceResolved ? <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在读取工作台</h1><p>正在确认默认人物、示例人物和最近添加人物。</p></div></section> : !hasActiveSnapshot ? <section className="main-workspace empty-workspace"><div><span>✦</span><h1>{hasActiveSubject ? `${subjectName}尚未计算本命盘` : "开始第一次本命分析"}</h1><p>{hasActiveSubject ? `${activeTechnique === "natal" ? "本命盘" : "这个盘型"}需要先有一份本命计算结果。点击下方按钮确认参数并生成本命盘。` : "当前没有默认人物、示例人物或已保存人物。新建分析后即可继续。"}</p><button className="primary-action" onClick={() => openNewCalculation("technique", hasActiveSubject ? person : undefined)}>＋ 新建分析</button></div></section> : activeTechnique === "transits" ? <TransitWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} /> : activeTechnique === "secondary_progressions" ? <SecondaryProgressionsWorkspace theme={theme} person={person} latestNatalSnapshot={snapshot} /> : <section className="main-workspace">
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
