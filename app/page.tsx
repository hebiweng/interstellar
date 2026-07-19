"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import {
  createPersonAndNatalCalculation,
  getAiProviders,
  getNatalItemInterpretation,
  getNatalTableExport,
  getNatalTechnicalDocument,
  InterstellarApiError,
  previewNatalAiPayload,
  searchLocations,
  submitNatalToAi,
  type AiProvider,
  type AiModelId,
  type AiProviderId,
  type ItemInterpretation,
  type NatalAspect,
  type NatalCalculationSettings,
  type NatalHouse,
  type NatalPersonInput,
  type NatalPoint,
  type NatalSnapshot,
  type LocationSearchItem,
  type NatalAiPayloadPreview,
} from "./lib/interstellar-api";
import {
  getAccountWorkspace,
  loginAccount,
  logoutAccount,
  registerAccount,
  saveAccountPerson,
  saveLatestAiAnalysis,
  saveLatestNatal,
  setAccountSampleVisibility,
  setDefaultAccountPerson,
  type AccountWorkspace,
  type WorkspacePerson,
} from "./lib/account-workspace";
import {
  buildNatalRenderSpec,
  buildSingleImagePdf,
  downloadBlob,
  rasterizeSerializedSvg,
  selectVisibleNatalAspects,
  serializeSvgWithComputedStyles,
  type NatalRenderControls,
  type RenderSpec,
} from "./lib/render-export";
import { recordAnalyticsEvent } from "./lib/analytics";

type ResultTab = "basic" | "signs" | "houses" | "aspects" | "structure" | "classical" | "technical";
type ChartView = "professional" | "compact" | "aspect_grid";
type ThemeMode = "dark" | "light";
type EntryPointId = "technique" | "topic" | "intent" | "object" | "personal" | "context";
type TechniqueId = "synastry" | "natal" | "transits" | "current_sky" | "secondary_progressions" | "tertiary_progressions" | "solar_arc" | "returns" | "question" | "geography";
type InterpretationTarget = {
  type: "point" | "house" | "aspect" | "structure" | "classical";
  id: string;
  title: string;
  fact: string;
  facts?: string[];
  resultPath?: string;
};

const globalNavigation = ["工作台", "分析中心", "技法排盘", "对象库"] as const;

const entryModes: Array<{ id: EntryPointId; title: string; description: string; context: string }> = [
  { id: "technique", title: "技法排盘", description: "直接选择本命、行运、推运、返照等计算方法", context: "只加入所选技法的必需依赖，默认不添加专题解释。" },
  { id: "topic", title: "专题模型", description: "从职业、关系、财富、人格等专题模型进入", context: "专题锁定核心规则方案，只开放声明过的参数。" },
  { id: "intent", title: "分析目的", description: "从现实问题反推需要的对象、技法和输出", context: "先确认目的，再由预检生成可检查的计算配方。" },
  { id: "object", title: "对象快捷", description: "从人物、关系、项目、事件或组织开始", context: "预填当前对象，只展示该对象真正可执行的动作。" },
  { id: "personal", title: "时间与周期", description: "查看短期、年度和长期周期", context: "预填当前人物和时间范围，页面打开时不批量计算。" },
  { id: "context", title: "关系／项目／地点", description: "预填双人、项目或地点上下文", context: "缺少第二人物、事件时刻或目标地点时会明确阻断。" },
];

const chartTechniques: Array<{ id: TechniqueId; label: string; status: "active" | "planned"; stage: string; inputs: string; outputs: string }> = [
  { id: "synastry", label: "合盘", status: "planned", stage: "M6", inputs: "两个人物", outputs: "比较盘、宫位覆盖、组合盘" },
  { id: "natal", label: "本命盘", status: "active", stage: "当前", inputs: "一名人物的出生时间与地点", outputs: "单轮盘、相位图、基础与古典结果" },
  { id: "transits", label: "行运盘", status: "planned", stage: "M5后续", inputs: "人物＋目标时刻或时间范围", outputs: "本命＋行运双轮、命中与时间轴" },
  { id: "current_sky", label: "天象盘", status: "planned", stage: "M5后续", inputs: "时刻与地点", outputs: "当前天空单盘、天象事件" },
  { id: "secondary_progressions", label: "次限盘", status: "planned", stage: "M7—M8", inputs: "人物＋目标日期", outputs: "本命＋次限双轮、推运月相" },
  { id: "tertiary_progressions", label: "三限盘", status: "planned", stage: "M7—M8", inputs: "人物＋目标日期", outputs: "本命＋三限双轮、时间线" },
  { id: "solar_arc", label: "太阳弧", status: "planned", stage: "M8", inputs: "人物＋目标日期", outputs: "太阳弧双轮、弧向命中" },
  { id: "returns", label: "返照盘", status: "planned", stage: "M5后续", inputs: "人物＋返照年份与地点", outputs: "太阳／月亮／行星返照" },
  { id: "question", label: "卜卦／择时", status: "planned", stage: "M16—M17", inputs: "问题或候选时间范围＋地点", outputs: "问事盘、约束排序与证据链" },
  { id: "geography", label: "地理占星", status: "planned", stage: "M18", inputs: "人物＋一个或多个地点", outputs: "迁移盘、地理线、Local Space" },
];

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
  { id: "krusinski", label: "Krusinski 克鲁辛斯基" },
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

const analysisSystemOptions: Array<{ id: NatalCalculationSettings["analysisSystem"]; label: string; description: string }> = [
  { id: "integrated", label: "专业综合本命 v1", description: "计算完整现代、结构与古典事实，并分层展示。" },
  { id: "modern", label: "现代本命 v1", description: "默认阅读现代点位、宫位、相位与盘面结构。" },
  { id: "classical", label: "古典本命 v1", description: "默认阅读七曜、昼夜、尊贵、太阳条件、接纳与阿拉伯点。" },
];

const ayanamsaOptions: Array<{ id: NatalCalculationSettings["ayanamsa"]; label: string }> = [
  { id: "fagan_bradley", label: "Fagan–Bradley" },
  { id: "lahiri", label: "Lahiri" },
  { id: "deluce", label: "De Luce" },
  { id: "raman", label: "Raman" },
  { id: "krishnamurti", label: "Krishnamurti" },
  { id: "yukteshwar", label: "Yukteshwar" },
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
  pallas: "智神星", juno: "婚神星", vesta: "灶神星", fortune: "福点", spirit: "精神点",
  lot_eros: "爱神点", lot_necessity: "必然点", lot_courage: "勇气点", lot_victory: "胜利点",
  lot_nemesis: "复仇点", lot_exaltation: "擢升点",
  cupido: "丘比特", hades: "哈得斯", zeus: "宙斯", kronos: "克洛诺斯", apollon: "阿波罗",
  admetos: "阿得门图斯", vulkanus: "弗卡奴斯", poseidon: "波塞冬",
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

const pointGroups = {
  core: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"],
  angles: ["asc", "dsc", "mc", "ic", "vertex", "anti_vertex", "east_point", "west_point"],
  lunar: ["true_north_node", "true_south_node", "mean_north_node", "mean_south_node", "mean_lilith", "true_lilith", "lunar_perigee"],
  asteroids: ["chiron", "ceres", "pallas", "juno", "vesta"],
  lots: ["fortune", "spirit", "lot_eros", "lot_necessity", "lot_courage", "lot_victory", "lot_nemesis", "lot_exaltation"],
  hamburg: ["cupido", "hades", "zeus", "kronos", "apollon", "admetos", "vulkanus", "poseidon"],
} as const;

type NatalPresetId = "recommended" | "modern" | "classical" | "sidereal_research" | "custom";

const majorAspectIds = ["conjunction", "opposition", "trine", "square", "sextile"];
const professionalAspectIds = [
  ...majorAspectIds,
  "semisextile", "semisquare", "sesquisquare", "quincunx", "quintile", "biquintile",
];

const natalCalculationPresets: Array<{
  id: Exclude<NatalPresetId, "custom">;
  label: string;
  badge: string;
  description: string;
  basis: string;
  settings: Partial<NatalCalculationSettings>;
  groups: Record<keyof typeof pointGroups, boolean>;
}> = [
  {
    id: "recommended",
    label: "专业综合本命",
    badge: "平台推荐",
    description: "同时生成现代基础、盘面结构、完整专业相位和古典核心结果。",
    basis: "面向第一次完整排盘的默认方案；使用回归黄道、Placidus 与专业常用相位集。",
    settings: { analysisSystem: "integrated", zodiac: "tropical", houseSystem: "placidus", aspectIds: professionalAspectIds },
    groups: { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: false },
  },
  {
    id: "modern",
    label: "现代本命",
    badge: "常用方案",
    description: "突出十大行星、四轴、月交点、宫位、主要与常用次要相位。",
    basis: "适合现代心理占星与一般本命阅读；汉堡虚星和传统 Lots 默认关闭。",
    settings: { analysisSystem: "modern", zodiac: "tropical", houseSystem: "placidus", aspectIds: professionalAspectIds },
    groups: { core: true, angles: true, lunar: true, asteroids: true, lots: false, hamburg: false },
  },
  {
    id: "classical",
    label: "古典七曜与整宫",
    badge: "传统方案",
    description: "优先读取七曜、昼夜、尊贵、接纳、太阳条件和赫尔墨斯点。",
    basis: "采用回归黄道与 Whole Sign；传统规则仍由版本化 Rule Pack 决定。",
    settings: { analysisSystem: "classical", zodiac: "tropical", houseSystem: "whole_sign", aspectIds: majorAspectIds },
    groups: { core: true, angles: true, lunar: true, asteroids: false, lots: true, hamburg: false },
  },
  {
    id: "sidereal_research",
    label: "恒星黄道研究",
    badge: "研究方案",
    description: "使用 Sidereal 与指定 Ayanamsa 生成可复现的恒星黄道本命结果。",
    basis: "默认 Lahiri，仅代表可复现的研究预设，不宣称为唯一权威体系。",
    settings: { analysisSystem: "integrated", zodiac: "sidereal", ayanamsa: "lahiri", houseSystem: "whole_sign", aspectIds: professionalAspectIds },
    groups: { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: false },
  },
];

const pointGroupLabels: Record<keyof typeof pointGroups, string> = {
  core: "十大行星",
  angles: "四轴与敏感点",
  lunar: "交点与月球点",
  asteroids: "常用小行星",
  lots: "阿拉伯点",
  hamburg: "汉堡虚星",
};

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

const natalTableExports = [
  ["table.planet_positions", "完整点位"], ["table.planet_speeds", "点位速度"], ["table.house_cusps", "十二宫"],
  ["table.natal_aspects", "完整相位"], ["table.elements", "四元素"], ["table.modalities", "三模式"],
  ["table.polarity", "阴阳属性"], ["table.chart_patterns", "盘面格局"], ["table.essential_dignities", "先天尊贵"],
  ["table.receptions", "接纳互容"], ["table.sect_condition", "昼夜 Sect"],
  ["table.arabic_parts", "阿拉伯点"],
] as const;

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

const defaultSettings: NatalCalculationSettings = {
  analysisSystem: "integrated", zodiac: "tropical", ayanamsa: "lahiri",
  houseSystem: "placidus", nodeType: "both", pointIds: [], aspectIds: [], orbOverrides: {},
};

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

function isDateLevelSnapshot(snapshot: NatalSnapshot): boolean {
  return asRecord(asRecord(snapshot.result.astronomical_context).uncertainty).mode === "civil_day_range";
}

function dateLevelPointRange(snapshot: NatalSnapshot, pointId: string): Record<string, unknown> {
  const ranges = asRecord(asRecord(snapshot.result.structure).date_level_point_ranges);
  return asRecord(ranges[pointId]);
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
        ? "出生时刻未知，因此不合成上升、宫位、相位、Lots、昼夜 Sect 或其他时刻依赖结论；若该点在日期内跨星座或改变运动状态，必须同时阅读不确定范围。"
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
    `# ${subjectName} · 本命盘分析数据`, "", "> 可复制给占星师或外部模型继续分析；完整 JSON 可另行导出。", "",
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
      <circle cx="320" cy="320" r={professional ? "43" : "54"} className="wheel-core" />
      <text x="320" y={professional ? "316" : "306"} className="wheel-core-title">{dateLevel ? "DATE RANGE" : professional ? "本命" : "NATAL"}</text>
      <text x="320" y={professional ? "330" : "329"} className="wheel-core-sub">{dateLevel ? `${points.length} 点 · 时刻未知` : `${points.length} 点 · ${visibleAspects.length}/${snapshot.result.aspects.length} 相位线`}</text>
      {hasLayer("legend") && !dateLevel && professional && <g className="wheel-legend"><line x1="266" y1="371" x2="284" y2="371" className="aspect-line hard major" /><text x="288" y="374">张力</text><line x1="322" y1="371" x2="340" y2="371" className="aspect-line soft major" /><text x="344" y="374">支持</text></g>}
    </svg>
  );
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
  return <section className="time-dependent-unavailable"><span>TIME DEPENDENT · BLOCKED</span><h3>{title}</h3><p>{detail}</p><ul><li>系统没有把 00:00 或日期中点当作出生时刻。</li><li>补充可靠当地出生时间后，重新计算会生成新的不可变快照。</li><li>当前仍可查看日期级天体位置、不确定范围及可能的跨星座／运动状态变化。</li></ul></section>;
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
      <article className="professional-card"><header><div><small>STELLIUMS</small><h3>群星结构</h3></div><span>{stelliums.length}</span></header>{stelliums.length ? <ul className="fact-list">{stelliums.map((fact, index) => <li key={String(fact.stellium_id ?? index)}><span>{patternNames[String(fact.kind)] ?? String(fact.kind)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}{fact.longitude_span_deg == null ? "" : ` · 跨度 ${Number(fact.longitude_span_deg).toFixed(3)}°`}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.stellium_id ?? index), title: patternNames[String(fact.kind)] ?? "群星结构", fact: toPlain(fact), resultPath: `/result/structure/stelliums/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前规则方案未命中群星结构。</p>}</article>
      <article className="professional-card"><header><div><small>GEOMETRIC PATTERNS</small><h3>几何格局</h3></div><span>{patterns.length}</span></header>{patterns.length ? <ul className="fact-list">{patterns.map((fact, index) => <li key={String(fact.pattern_id ?? index)}><span>{patternNames[String(fact.pattern_type)] ?? String(fact.pattern_type)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.pattern_id ?? index), title: patternNames[String(fact.pattern_type)] ?? "几何格局", fact: toPlain(fact), resultPath: `/result/structure/geometric_patterns/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前规则方案未命中已发布几何格局。</p>}</article>
      <article className="professional-card"><header><div><small>盘型分类</small><h3>Jones 盘型</h3></div><span>{statusNames[String(jones.status ?? "")] ?? (jones.shape_id ? "已识别" : "不确定")}</span></header><p className="boundary-copy">{jones.shape_id ? String(jones.shape_id) : "当前没有通过验证的分类规则，因此保留为不确定，不用视觉猜测生成盘型。"}</p><button onClick={() => onOpen({ type: "structure", id: "jones_shape", title: "Jones 盘型边界", fact: toPlain(jones), resultPath: "/result/structure/jones_shape" })}>查看依据</button></article>
    </div>
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
    <div className="classical-summary"><div><small>昼夜盘</small><b>{classical.day_night_status === "day" ? "昼盘" : classical.day_night_status === "night" ? "夜盘" : "不确定"}</b><span>太阳高度 {classical.sun_altitude_deg == null ? "—" : `${Number(classical.sun_altitude_deg).toFixed(3)}°`}</span></div><div><small>本质尊贵</small><b>{dignities.length}</b><span>传统七曜逐星计算</span></div><div><small>接纳 / 互容</small><b>{receptions.length} / {mutualReceptions.length}</b><span>不要求相位的接纳事实</span></div><div><small>阿拉伯点</small><b>{lots.length}</b><span>昼夜公式写入快照</span></div></div>

    <div className="professional-card sect-card"><header><div><small>{availabilityLabel(classical.availability)}</small><h3>Sect 昼夜体系</h3></div><button onClick={() => onOpen({ type: "classical", id: "sect", title: "Sect 昼夜体系", fact: toPlain(sect), resultPath: "/result/classical/sect" })}>解读</button></header><dl className="fact-definition"><div><dt>当权光体</dt><dd>{pointNames[String(sect.sect_light_id)] ?? String(sect.sect_light_id ?? "—")}</dd></div><div><dt>昼星</dt><dd>{pointList(sect.diurnal_planet_ids)}</dd></div><div><dt>夜星</dt><dd>{pointList(sect.nocturnal_planet_ids)}</dd></div><div><dt>条件星</dt><dd>{pointList(sect.conditional_planet_ids)}</dd></div></dl></div>

    <h3 className="table-group-title">先天尊贵与失势落陷</h3>
    <div className="professional-table-wrap"><table className="professional-table dignity-table"><thead><tr><th>星体</th><th>位置</th><th>尊贵</th><th>失势／落陷</th><th>游走</th><th>Sect</th><th>操作</th></tr></thead><tbody>{dignities.map((raw, index) => { const row = asRecord(raw); const active = asRecords(row.dignities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)); const debilities = asRecords(row.debilities).map((item) => dignityNames[String(item.kind)] ?? String(item.kind)); return <tr key={String(row.point_id ?? index)}><td>{pointNames[String(row.point_id)] ?? String(row.point_id)}</td><td>{signNames[String(row.sign_id)] ?? String(row.sign_id)} {formatDegree(Number(row.degree_in_sign ?? 0))}</td><td>{active.join("、") || "无"}</td><td>{debilities.join("、") || "无"}</td><td>{row.peregrine === true ? "是" : row.peregrine === false ? "否" : "不适用"}</td><td>{String(row.sect ?? "—")}</td><td><button onClick={() => onOpen({ type: "classical", id: `dignity.${String(row.point_id)}`, title: `${pointNames[String(row.point_id)] ?? String(row.point_id)}的本质尊贵`, fact: toPlain(row), resultPath: `/result/dignities/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>

    <h3 className="table-group-title">太阳条件与方向状态</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>星体</th><th>太阳条件</th><th>日距</th><th>东方／西方</th><th>越界</th><th>物理可见性</th><th>操作</th></tr></thead><tbody>{solarConditions.map((condition, index) => { const point = snapshot.result.points.find((item) => item.point_id === String(condition.point_id)); return <tr key={String(condition.point_id ?? index)}><td>{pointNames[String(condition.point_id)] ?? String(condition.point_id)}</td><td>{solarRelationNames[String(condition.relation)] ?? String(condition.relation)}</td><td>{condition.separation_deg == null ? "—" : `${Number(condition.separation_deg).toFixed(3)}°`}</td><td>{point?.oriental_occidental === "oriental" ? "东方" : point?.oriental_occidental === "occidental" ? "西方" : "不适用"}</td><td>{point?.out_of_bounds === true ? "是" : point?.out_of_bounds === false ? "否" : "不适用"}</td><td>{point?.visibility_state === "uncertain" ? "未计算（需晨昏模型）" : point?.visibility_state ?? "—"}</td><td><button onClick={() => onOpen({ type: "classical", id: `solar.${String(condition.point_id)}`, title: `${pointNames[String(condition.point_id)] ?? String(condition.point_id)}的太阳条件`, fact: toPlain(condition), resultPath: `/result/classical/solar_conditions/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>

    <div className="professional-grid classical-relations">
      <article className="professional-card"><header><div><small>RECEPTIONS</small><h3>接纳与互容</h3></div><span>{receptions.length + mutualReceptions.length}</span></header><ul className="fact-list">{receptions.map((row, index) => <li key={`direct-${index}`}><span>{pointNames[String(row.host_point_id)] ?? String(row.host_point_id)} 接纳 {pointNames[String(row.guest_point_id)] ?? String(row.guest_point_id)}</span><b>{dignityNames[String(row.dignity_kind)] ?? String(row.dignity_kind)}</b><small>{row.active_for_sect == null ? "无昼夜过滤" : row.active_for_sect ? "当前 Sect 生效" : "当前 Sect 不生效"}</small></li>)}{mutualReceptions.map((row, index) => <li key={`mutual-${index}`}><span>{pointNames[String(row.point_a)] ?? String(row.point_a)} ↔ {pointNames[String(row.point_b)] ?? String(row.point_b)}</span><b>互容</b><small>{asStrings(row.a_receives_b_by).map((id) => dignityNames[id] ?? id).join("、")} / {asStrings(row.b_receives_a_by).map((id) => dignityNames[id] ?? id).join("、")}</small></li>)}</ul>{!receptions.length && !mutualReceptions.length && <p className="empty-fact">当前规则方案没有命中接纳或互容。</p>}<button onClick={() => onOpen({ type: "classical", id: "receptions", title: "接纳与互容", fact: toPlain(receptionDocument), resultPath: "/result/classical/receptions" })}>解读</button></article>
    </div>

    <h3 className="table-group-title">阿拉伯点／赫尔墨斯 Lots</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>点位</th><th>位置</th><th>宫位</th><th>昼夜</th><th>公式</th><th>版本</th><th>操作</th></tr></thead><tbody>{lots.map((raw, index) => { const lot = asRecord(raw); const point = snapshot.result.points.find((item) => item.point_id === String(lot.lot_id)); return <tr key={String(lot.lot_id ?? index)}><td>{pointNames[String(lot.lot_id)] ?? String(lot.lot_id)}</td><td>{signNames[String(lot.sign_id)] ?? String(lot.sign_id)} {formatDegree(Number(lot.degree_in_sign ?? 0))}</td><td>{point?.house == null ? "—" : `第${point.house}宫`}</td><td>{String(lot.sect ?? "—")}</td><td><code>{String(lot.formula_expression ?? "—")}</code></td><td>{String(lot.formula_version ?? "—")}</td><td><button onClick={() => onOpen({ type: "classical", id: `lot.${String(lot.lot_id)}`, title: `${pointNames[String(lot.lot_id)] ?? String(lot.lot_id)}的计算与含义`, fact: toPlain(lot), resultPath: `/result/lots/${index}` })}>解读</button></td></tr>; })}</tbody></table></div>

    <p className="professional-boundary">当前已可靠实现 9 个昼夜感知 Lots。Hayz、Almuten、综合尊贵分、完整偶然尊贵与物理可见性仍明确标记为待验证，不以空白分数或通用文案伪装。</p>
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
        <header><div><span>CONTEXTUAL INTERPRETATION</span><h2>{result.title ?? target.title}</h2></div><button onClick={onClose} aria-label="关闭">×</button></header>
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
    <label>出生时间<input type="time" value={person.localTime} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} step={person.timePrecision === "hour" ? 3600 : 60} onChange={(event) => onChange({ ...person, localTime: event.target.value })} /><small>{person.timePrecision === "date" || person.timePrecision === "unknown" ? "将只返回日期级天体位置及不确定范围；上升、宫位、相位、Lots、昼夜 Sect 与古典时刻判断会明确阻断。" : "输入的是出生地当地钟表时间；系统会使用历史 IANA 时区规则换算 UTC。"}</small></label>
    <label className="location-search-field">出生城市／地区<input role="combobox" aria-autocomplete="list" aria-controls="birth-location-options" value={person.placeName} onChange={(event) => updatePlaceQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Escape") { setLocationSearchActive(false); setLocationCandidates([]); } }} placeholder="输入城市、区县或多语言地名" autoComplete="off" aria-expanded={locationSearchActive && locationCandidates.length > 0} />{locationLoading && locationSearchActive && <small>正在搜索本地版本化地点索引…</small>}{locationSearchActive && locationCandidates.length > 0 && <span id="birth-location-options" className="location-candidates" role="listbox">{locationCandidates.map((candidate) => <button type="button" role="option" aria-selected="false" key={candidate.id} onClick={() => selectLocation(candidate)}><b>{candidate.label}</b><small>{candidate.location.latitude.toFixed(4)}, {candidate.location.longitude.toFixed(4)} · {candidate.timezone_status === "resolved" ? candidate.location.timezone_id : `时区需确认（${candidate.timezone_candidates.map((item) => item.timezone_id).join(" / ") || "无候选"}）`}</small></button>)}</span>}<small>{locationMessage || "输入至少两个字符后显示地点候选；选择后自动填写经纬度、国家和 IANA 时区。地点精确到城市或区县即可，无需填写街道或医院。"}</small></label>
    <label>IANA 时区<select value={person.timezoneId} onChange={(event) => onChange({ ...person, timezoneId: event.target.value, timezoneStatus: "manual" })}>{timezoneOptions.map((timezone) => <option key={timezone} value={timezone}>{timezone}</option>)}</select><small>{person.timezoneStatus === "ambiguous" || person.timezoneStatus === "degraded" ? "地点数据未能唯一确认时区，必须人工确认。" : "时区使用 IANA 标识；历史夏令时由规则库计算，不让用户填写 UTC 偏移。"}</small></label>
    <label>时间可信度<select value={person.timeConfidence} disabled={person.timePrecision === "date" || person.timePrecision === "unknown"} onChange={(event) => onChange({ ...person, timeConfidence: event.target.value as NatalPersonInput["timeConfidence"] })}><option value="high">高：出生证明或正式记录</option><option value="medium">中：本人或亲友记忆</option><option value="low">低：大致时间</option><option value="unknown">未知：没有出生时刻</option></select></label>
    {(person.timePrecision === "date" || person.timePrecision === "unknown") && <p className="time-precision-warning"><b>日期级模式</b><span>可以计算天体在该日期内的星座位置范围、运动方向范围与跨界风险；不能生成完整本命盘。补充可靠出生时刻后才会开放四轴、十二宫、相位和古典结果。</span></p>}
    <details className="advanced-location"><summary>高级位置覆盖</summary><div><label>纬度<input type="number" step="0.0001" value={person.latitude} onChange={(event) => onChange({ ...person, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={person.longitude} onChange={(event) => onChange({ ...person, longitude: Number(event.target.value) })} /></label></div><p>一般无需修改。国家代码由地点候选派生，仅用于消歧，不参与占星判断。</p></details>
  </div>;
}

export default function Home() {
  const [snapshot, setSnapshot] = useState<NatalSnapshot>(sampleSnapshot);
  const [subjectName, setSubjectName] = useState("阿特拉斯");
  const [tab, setTab] = useState<ResultTab>("basic");
  const [chartView, setChartView] = useState<ChartView>("professional");
  const [personModal, setPersonModal] = useState(false);
  const [calculationModal, setCalculationModal] = useState(false);
  const [analysisCenterOpen, setAnalysisCenterOpen] = useState(false);
  const [capabilityTarget, setCapabilityTarget] = useState<(typeof chartTechniques)[number] | null>(null);
  const [entryPoint, setEntryPoint] = useState<EntryPointId>("technique");
  const [selectedPresetId, setSelectedPresetId] = useState<NatalPresetId>("recommended");
  // The server and the first browser render must use identical values. Browser
  // preferences are applied after hydration so React never has to reconcile
  // different theme labels/icons or responsive panel state.
  const [theme, setTheme] = useState<ThemeMode>("dark");
  const [settingsOpen, setSettingsOpen] = useState(true);
  const [person, setPerson] = useState<NatalPersonInput>(defaultPerson);
  const [settings, setSettings] = useState<NatalCalculationSettings>(defaultSettings);
  const [appliedSettings, setAppliedSettings] = useState<NatalCalculationSettings>(defaultSettings);
  const [groups, setGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ ...allPointGroupsEnabled });
  const [appliedGroups, setAppliedGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ ...allPointGroupsEnabled });
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
  const [sampleVisible, setSampleVisible] = useState(true);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [target, setTarget] = useState<InterpretationTarget | null>(null);
  const [technicalDocument, setTechnicalDocument] = useState(() => buildLocalTechnicalDocument(sampleSnapshot, "阿特拉斯"));
  const [technicalDocumentHash, setTechnicalDocumentHash] = useState("虚拟样例 · 未生成服务端内容哈希");
  const [providers, setProviders] = useState<AiProvider[]>([
    { provider_id: "deepseek", label: "DeepSeek", configured: false, availability: "blocked", blocking_reason: "等待服务端配置 DeepSeek API 密钥", models: [{ model_id: "deepseek-v4-pro", label: "DeepSeek V4 Pro", configured: false }] },
    { provider_id: "openai", label: "GPT / OpenAI", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "gpt", label: "GPT（后台指定版本）", configured: false }] },
    { provider_id: "moonshot", label: "Kimi / Moonshot", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "kimi", label: "Kimi（后台指定版本）", configured: false }] },
  ]);
  const [providerId, setProviderId] = useState<AiProviderId>("deepseek");
  const [modelId, setModelId] = useState<AiModelId>("deepseek-v4-pro");
  const [exportTableId, setExportTableId] = useState<(typeof natalTableExports)[number][0]>("table.planet_positions");
  const [graphicExportBusy, setGraphicExportBusy] = useState<"svg" | "png" | "pdf" | null>(null);
  const [consent, setConsent] = useState(false);
  const [subjectDataAuthority, setSubjectDataAuthority] = useState(false);
  const [aiFocus, setAiFocus] = useState("");
  const [aiPreview, setAiPreview] = useState<NatalAiPayloadPreview | null>(null);
  const [aiPreviewBusy, setAiPreviewBusy] = useState(false);
  const [aiSubmitBusy, setAiSubmitBusy] = useState(false);
  const [aiAnalysisText, setAiAnalysisText] = useState("");
  const resultsRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const storedTheme = window.localStorage.getItem("interstellar.theme");
    const openSettings = !window.matchMedia("(max-width: 900px)").matches;
    queueMicrotask(() => {
      if (storedTheme === "light" || storedTheme === "dark") {
        setTheme(storedTheme);
      }
      setSettingsOpen(openSettings);
    });
  }, []);

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
      const configured = items.find((item) => item.provider_id === "deepseek" && item.configured);
      if (configured) {
        setProviderId("deepseek");
        setModelId(configured.models.find((model) => model.configured)?.model_id ?? "deepseek-v4-pro");
      }
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

  const selectedProvider = providers.find((provider) => provider.provider_id === providerId) ?? providers[0];
  const corePoints = snapshot.result.points.filter((point) => pointGroups.core.includes(point.point_id as never));
  const extendedPoints = snapshot.result.points.filter((point) => !pointGroups.core.includes(point.point_id as never));
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

  async function dismissSampleSubject() {
    try {
      if (accountWorkspace.authenticated) {
        await setAccountSampleVisibility(false);
        const workspace = await refreshWorkspace();
        setSampleVisible(false);
        if (workspace.people[0]) selectWorkspacePerson(workspace.people[0], false);
        else showEmptyWorkspace();
      } else {
        window.localStorage.setItem("interstellar.sampleVisible", "false");
        setSampleVisible(false);
        showEmptyWorkspace();
      }
      setNotice("已移除示例人物“阿特拉斯”。可在对象库中恢复。");
    } catch (reason) {
      setNotice(reason instanceof Error ? reason.message : "示例人物移除失败。");
    }
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
    setSampleVisible(accountSampleVisible);
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
      setSampleVisible(guestSampleVisible);
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
    setSettings(latest.settings);
    setAppliedSettings(latest.settings);
    const savedGroups = { ...allPointGroupsEnabled, ...latest.groups } as Record<keyof typeof pointGroups, boolean>;
    setGroups(savedGroups);
    setAppliedGroups(savedGroups);
    setTechnicalDocument(latest.analysisDocument);
    setTechnicalDocumentHash(latest.analysisDocumentHash);
    setAiAnalysisText(latest.aiAnalysisText ?? "");
    if (latest.aiModelId) setModelId(latest.aiModelId as AiModelId);
    setAiPreview(null);
    setConsent(false);
    setSubjectDataAuthority(false);
    setTab("basic");
    setChartView("professional");
    setHasActiveSnapshot(true);
    setNotice(`已载入“${saved.person.displayName}”最后一次本命盘（${new Date(latest.calculatedAt).toLocaleString("zh-CN")}）。`);
  }

  function openTechnicalResults() {
    setTab("technical");
    window.requestAnimationFrame(() => resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }));
  }

  function openNewCalculation(selectedEntry: EntryPointId = "technique", selectedPerson?: NatalPersonInput) {
    setEntryPoint(selectedEntry);
    if (selectedPerson) setPerson(selectedPerson);
    setCalculationModal(true);
  }

  function applyNatalPreset(presetId: Exclude<NatalPresetId, "custom">) {
    const preset = natalCalculationPresets.find((item) => item.id === presetId);
    if (!preset) return;
    setSelectedPresetId(presetId);
    setSettings((current) => ({ ...current, ...preset.settings }));
    setGroups({ ...preset.groups });
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
    const pointIds = (Object.entries(groups) as Array<[keyof typeof pointGroups, boolean]>)
      .filter(([, enabled]) => enabled).flatMap(([group]) => [...pointGroups[group]]);
    const allGroupsEnabled = Object.values(groups).every(Boolean);
    try {
      const result = await createPersonAndNatalCalculation(person, { ...settings, pointIds: allGroupsEnabled ? [] : pointIds });
      setSnapshot(result.snapshot); setSubjectName(person.displayName); setHasActiveSubject(true); setHasActiveSnapshot(true); setAppliedSettings({ ...settings }); setAppliedGroups({ ...groups }); setCalculationModal(false); setTab(settings.analysisSystem === "classical" ? "classical" : "basic"); setChartView("professional");
      const document = await getNatalTechnicalDocument(result.snapshot.id, "markdown");
      setTechnicalDocument(document.content);
      setTechnicalDocumentHash(document.contentHash);
      setAiAnalysisText("");
      setAiPreview(null);
      setConsent(false);
      setSubjectDataAuthority(false);
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
        ? "；已覆盖保存为该人物最新一次结果"
        : accountWorkspace.authenticated
          ? "；本次临时结果未保存"
          : "；游客结果不会保存";
      setNotice((isDateLevelSnapshot(result.snapshot)
        ? `已生成日期级部分快照：${result.snapshot.result.points.length} 个天体位置范围；时刻依赖能力已阻断。`
        : `已生成真实本命快照：${result.snapshot.result.points.length} 个点位、${result.snapshot.result.aspects.length} 条相位。`) + persistenceNote);
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

  async function downloadTechnical(format: "markdown" | "plaintext") {
    try {
      const artifact = snapshot.id.startsWith("calculation-")
        ? await getNatalTechnicalDocument(snapshot.id, format)
        : {
          content: format === "markdown" ? technicalDocument : technicalDocument.replace(/^#+\s*/gm, ""),
          contentHash: technicalDocumentHash,
        };
      if (snapshot.id.startsWith("calculation-") && artifact.contentHash !== technicalDocumentHash) {
        throw new Error("下载内容与当前页面的分析数据校验值不一致");
      }
      downloadBlob(
        new Blob([artifact.content], { type: format === "markdown" ? "text/markdown;charset=utf-8" : "text/plain;charset=utf-8" }),
        `${subjectName}-本命盘分析数据.${format === "markdown" ? "md" : "txt"}`,
      );
      setNotice(`已导出本命盘分析${format === "markdown" ? " Markdown" : "纯文本"}文档（${new Blob([artifact.content]).size} 字节）。`);
    } catch (error) {
      setNotice(`分析数据导出失败：${error instanceof Error ? error.message : "未知错误"}`);
    }
  }

  function downloadSnapshotJson() {
    const blob = new Blob([JSON.stringify(snapshot, null, 2)], { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob); const link = document.createElement("a");
    link.href = url; link.download = `${subjectName}-本命盘完整快照.json`; link.click(); URL.revokeObjectURL(url);
    setNotice("已导出完整 JSON 快照，包含计算事实、警告、版本与复现信息。");
    recordAnalyticsEvent({ event_name: "report_exported", success: true, metadata: { analysis_type: "natal", export_format: "json" } });
  }

  async function downloadSelectedTable() {
    if (!snapshot.id.startsWith("calculation-")) { setNotice("虚拟样例没有服务端 CSV；请先生成真实本命快照。"); return; }
    try {
      const blob = await getNatalTableExport(snapshot.id, exportTableId, "csv");
      const url = URL.createObjectURL(blob); const link = document.createElement("a");
      const label = natalTableExports.find(([id]) => id === exportTableId)?.[1] ?? exportTableId;
      link.href = url; link.download = `${subjectName}-本命盘-${label}.csv`; link.click(); URL.revokeObjectURL(url);
      setNotice(`已导出“${label}”CSV 表。`);
      recordAnalyticsEvent({ event_name: "report_exported", success: true, metadata: { analysis_type: "natal", export_format: "csv" } });
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "CSV 导出失败。");
    }
  }

  async function downloadNatalGraphic(format: "svg" | "png" | "pdf") {
    if (chartView === "aspect_grid") {
      setNotice("相位矩阵有独立导出规格；当前图形导出仅适用于专业／简洁本命轮盘。");
      return;
    }
    const svg = document.querySelector<SVGSVGElement>(".natal-wheel");
    if (!svg) { setNotice("未找到当前轮盘，无法导出。"); return; }
    setGraphicExportBusy(format);
    try {
      const serialized = serializeSvgWithComputedStyles(svg, natalRenderSpec);
      const filename = `${subjectName}-${chartView === "compact" ? "简洁" : "专业"}本命轮盘`;
      if (format === "svg") {
        downloadBlob(new Blob([serialized], { type: "image/svg+xml;charset=utf-8" }), `${filename}.svg`);
      } else if (format === "png") {
        const png = await rasterizeSerializedSvg(serialized, natalRenderSpec, "image/png");
        downloadBlob(png, `${filename}.png`);
      } else {
        const jpeg = await rasterizeSerializedSvg(serialized, natalRenderSpec, "image/jpeg");
        const pdf = buildSingleImagePdf(new Uint8Array(await jpeg.arrayBuffer()), natalRenderSpec.width, natalRenderSpec.height);
        downloadBlob(new Blob([pdf], { type: "application/pdf" }), `${filename}.pdf`);
      }
      setNotice(`已按当前图形显示设置导出 ${format.toUpperCase()}；屏幕和文件使用同一黄道、宫位、点位与相位图层。`);
      recordAnalyticsEvent({ event_name: "report_exported", success: true, metadata: { analysis_type: "natal", export_format: format } });
    } catch (error) {
      setNotice(`图形导出失败：${error instanceof Error ? error.message : "未知错误"}`);
    } finally {
      setGraphicExportBusy(null);
    }
  }

  async function previewAi() {
    if (!snapshot.id.startsWith("calculation-")) { setNotice("虚拟样例不能创建第三方载荷预览；请先生成真实计算快照。"); return; }
    setAiPreviewBusy(true);
    try {
      const preview = await previewNatalAiPayload({
        snapshotId: snapshot.id,
        providerId,
        modelId,
        focus: aiFocus,
        storeResponse: accountWorkspace.authenticated && Boolean(selectedPersonId),
      });
      setAiPreview(preview);
      setConsent(false);
      setSubjectDataAuthority(false);
      setNotice(`载荷预览已生成：约 ${preview.estimated_tokens} tokens；当前不会发送数据。`);
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "AI 载荷预览失败。");
    } finally {
      setAiPreviewBusy(false);
    }
  }

  async function submitAi() {
    if (!snapshot.id.startsWith("calculation-")) { setNotice("虚拟样例不能提交；请先生成真实计算快照。 "); return; }
    if (!aiPreview) { setNotice("请先预览本次将发送的具体载荷。"); return; }
    setAiSubmitBusy(true);
    try {
      const artifact = await submitNatalToAi({
        snapshotId: snapshot.id,
        providerId,
        modelId,
        focus: aiFocus,
        consent,
        payloadHash: aiPreview.payload_hash,
        authorityForSubjectData: subjectDataAuthority,
        storeResponse: accountWorkspace.authenticated && Boolean(selectedPersonId),
      });
      const text = artifact.response?.text?.trim();
      if (!text) throw new Error("DeepSeek 未返回分析文本");
      setAiAnalysisText(text);
      if (accountWorkspace.authenticated && selectedPersonId) {
        await saveLatestAiAnalysis(selectedPersonId, text, artifact.response.model ?? modelId);
        await refreshWorkspace();
      }
      setNotice(accountWorkspace.authenticated && selectedPersonId
        ? "DeepSeek 分析已完成，并附加到该人物的最新本命结果。"
        : "DeepSeek 分析已完成；游客结果仅在当前页面显示，不会保存。 ");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : `AI 分析失败：${error instanceof Error ? error.message : "未知错误"}`);
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
      ...(dateLevelMode ? [`完整日期最大位置不确定度 ±${(Number(point.position.uncertainty_arcsec ?? 0) / 3600).toFixed(6)}°`, `日期范围事实 ${toPlain(dateLevelPointRange(snapshot, point.point_id))}`] : []),
      `赤经 ${point.position.equatorial?.right_ascension_deg?.toFixed(6) ?? "—"}° · 赤纬 ${point.position.equatorial?.declination_deg?.toFixed(6) ?? "—"}° · 越界 ${point.out_of_bounds == null ? "—" : point.out_of_bounds ? "是" : "否"}`,
      `黄经速度 ${point.position.velocity?.longitude_deg_per_day?.toFixed(9) ?? "—"}°/日 · 运动状态 ${point.position.motion_state ?? (point.retrograde ? "retrograde" : "direct")}`,
      `距上一宫头 ${point.distance_from_previous_cusp_deg?.toFixed(6) ?? "—"}° · 距下一宫头 ${point.distance_to_next_cusp_deg?.toFixed(6) ?? "—"}° · 宫内比例 ${point.house_position_fraction?.toFixed(6) ?? "—"}`,
      `太阳关系 ${point.solar_relation ?? "—"} · 日距 ${point.solar_elongation_deg?.toFixed(6) ?? "—"}° · 可见性 ${point.visibility_state ?? "—"} · 东方/西方 ${point.oriental_occidental ?? "—"}`,
      `公式 ${point.formula_ref ?? "—"} · 天体目录 ${point.catalog_object_ref ?? "—"} · 历元 ${point.position.epoch ?? "—"}`,
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
        <button className="brand-button" onClick={() => { setTab("basic"); window.scrollTo({ top: 0, behavior: "smooth" }); }}><span className="brand-mark">✦</span><span><b>INTERSTELLAR</b><small>PROFESSIONAL ASTROLOGY</small></span></button>
        <nav>{globalNavigation.map((item) => <button key={item} className={item === "工作台" ? "active" : ""} onClick={() => {
          if (item === "工作台") window.scrollTo({ top: 0, behavior: "smooth" });
          if (item === "分析中心") setAnalysisCenterOpen(true);
          if (item === "技法排盘") openNewCalculation("technique");
          if (item === "对象库") window.location.href = "/objects";
        }}>{item}</button>)}</nav>
        <div className="site-actions"><button className="theme-toggle" onClick={toggleTheme} aria-label={`切换到${theme === "dark" ? "浅色" : "深色"}主题`} title={`当前${theme === "dark" ? "深色" : "浅色"}主题`}><span>{theme === "dark" ? "☀" : "☾"}</span><small>{theme === "dark" ? "Light" : "Dark"}</small></button>{accountWorkspace.authenticated ? <div className="account-menu"><button onClick={() => { window.location.href = "/account"; }}>{accountWorkspace.user?.displayName}</button>{accountWorkspace.user?.role && accountWorkspace.user.role !== "user" && <button onClick={() => { window.location.href = "/admin"; }}>后台</button>}<button onClick={signOut}>退出</button></div> : <button className="account-action" onClick={() => { setAuthError(""); setAuthModal("login"); }}>登录／注册</button>}<button className="primary-action" onClick={() => openNewCalculation()}>＋ 新建分析</button></div>
      </header>

      <div className="natal-layout">
        <aside className="person-sidebar" id="subject-library">
          <div className="side-heading"><span>当前人物</span><button onClick={() => { setSelectedPersonId(null); setSetAsDefault(false); setPerson({ ...defaultPerson, displayName: "" }); setPersonModal(true); }}>新增</button></div>
          {hasActiveSubject && <button className="current-person"><span className="person-avatar">{subjectName.slice(0, 1)}</span><span><b>{subjectName}</b><small>{hasActiveSnapshot ? snapshot.id.startsWith("calculation-") ? "真实计算快照" : "示例人物 · 非真实资料" : "尚未计算本命盘"}</small></span><i>✓</i></button>}
          {sampleVisible && hasActiveSnapshot && !selectedPersonId && !snapshot.id.startsWith("calculation-") && <button className="remove-sample" onClick={() => void dismissSampleSubject()}>删除示例人物</button>}
          <div className="side-heading"><span>{accountWorkspace.authenticated ? "我的人物" : "游客人物"}</span><small>{savedPeople.length}</small></div>
          <div className="saved-people">
            {savedPeople.map((saved) => <button key={saved.id} className={selectedPersonId === saved.id ? "active" : ""} onClick={() => selectWorkspacePerson(saved)}><span>{saved.person.displayName.slice(0, 1)}</span><div><b>{saved.person.displayName}</b><small>{saved.latestNatal ? `最新计算 ${new Date(saved.latestNatal.calculatedAt).toLocaleDateString("zh-CN")}` : `${saved.person.relation} · 尚未计算`}</small></div><i>{saved.latestNatal ? "载入" : "计算"}</i></button>)}
            {!savedPeople.length && <p>{accountWorkspace.authenticated ? "尚无保存人物。新增人物后可保存，每个人物只保留最后一次本命盘。" : "游客可在“新建分析”中临时添加人物；关闭页面后不会保存。"}</p>}
          </div>
          <section className="privacy-note"><b>{accountWorkspace.authenticated ? "账户隔离" : "游客模式"}</b><p>{accountWorkspace.authenticated ? "只加载当前登录账户的人物。每个人物重算时覆盖旧结果，只保留最新本命盘。" : "可临时建档、计算和分析，但人物、计算与 AI 文本均不保存。"}</p>{!accountWorkspace.authenticated && <button onClick={() => { setAuthError(""); setAuthModal("register"); }}>注册后保存</button>}</section>
        </aside>

        {!workspaceResolved ? <section className="main-workspace empty-workspace"><div><span>◌</span><h1>正在读取工作台</h1><p>正在确认默认人物、示例人物和最近添加人物。</p></div></section> : !hasActiveSnapshot ? <section className="main-workspace empty-workspace"><div><span>✦</span><h1>{hasActiveSubject ? `${subjectName}尚未计算本命盘` : "开始第一次本命分析"}</h1><p>{hasActiveSubject ? "人物资料已经准备好，点击下方按钮确认推荐参数并生成第一份本命结果。" : "当前没有默认人物、示例人物或已保存人物。新建分析后即可在这里查看轮盘、相位矩阵和专业数据。"}</p><button className="primary-action" onClick={() => openNewCalculation("technique", hasActiveSubject ? person : undefined)}>＋ 新建分析</button></div></section> : <section className="main-workspace">
          <header className="subject-title">
            <div><span>{dateLevelMode ? "DATE-LEVEL EPHEMERIS · PARTIAL SNAPSHOT" : "PROFESSIONAL NATAL · INTEGRATED FACTS"}</span><h1>{subjectName}的{dateLevelMode ? "日期级星座位置" : "本命盘"}</h1><p>{dateLevelMode ? "出生时刻未知：展示完整当地日期内的天体范围，不生成伪造的上升、宫位、相位或古典结论。" : "现代基础、盘面结构、完整相位与古典核心结果来自同一次计算，避免不同参数的结果混用。"}</p></div>
            <div className="header-actions"><button onClick={() => openNewCalculation("technique", person)}>↻ 重新分析</button><button onClick={() => setSettingsOpen((value) => !value)}>⚙ 参数</button><button onClick={openTechnicalResults}>分析数据与导出</button></div>
          </header>
          {notice && <div className="workspace-status" role="status"><p>{notice}</p><button onClick={() => setNotice("")} aria-label="关闭提示">×</button></div>}

          <div className={`hero-grid ${settingsOpen ? "with-settings" : ""}`}>
            <article className="wheel-panel">
              <div className="panel-heading"><div><small>{dateLevelMode ? "DATE-LEVEL POSITION VIEW" : "NATAL CHART VIEWS"}</small><h2>{dateLevelMode ? "日期级星座位置图（非本命轮盘）" : chartView === "professional" ? "专业本命轮盘" : chartView === "compact" ? "简洁本命轮盘" : "相位矩阵"}</h2></div><div className="panel-tools"><div className="view-switcher"><button className={chartView === "professional" ? "active" : ""} onClick={() => setChartView("professional")}>{dateLevelMode ? "专业位置图" : "专业轮盘"}</button><button className={chartView === "compact" ? "active" : ""} onClick={() => setChartView("compact")}>{dateLevelMode ? "简洁位置图" : "简洁轮盘"}</button><button disabled={dateLevelMode} className={chartView === "aspect_grid" ? "active" : ""} onClick={() => setChartView("aspect_grid")}>相位矩阵</button><span>{appliedSettings.zodiac === "tropical" ? "回归黄道" : `恒星黄道 · ${ayanamsaOptions.find((item) => item.id === appliedSettings.ayanamsa)?.label}`}</span>{!dateLevelMode && <span>{houseSystemOptions.find((item) => item.id === appliedSettings.houseSystem)?.label}</span>}<span>{natalRenderSpec.options.visible_point_ids.length}/{snapshot.result.points.length} 点</span><span>{natalRenderSpec.options.visible_aspect_count}/{snapshot.result.aspects.length} 相位线</span></div><div className="graphic-export-actions" aria-label="本命轮盘图形导出"><small>同源导出</small>{(["svg", "png", "pdf"] as const).map((format) => <button key={format} disabled={chartView === "aspect_grid" || graphicExportBusy !== null} onClick={() => downloadNatalGraphic(format)}>{graphicExportBusy === format ? "生成中…" : format.toUpperCase()}</button>)}</div></div></div>
              {chartView === "aspect_grid" && !dateLevelMode ? <AspectGrid snapshot={snapshot} onOpen={openAspect} /> : <NatalWheel snapshot={snapshot} renderSpec={natalRenderSpec} controls={effectiveWheelControls} />}
              <footer><span>计算相位 {snapshot.result.aspects.length} 条</span><span>轮盘绘制 {natalRenderSpec.options.visible_aspect_count} 条</span><span>完整结果见“相位”页</span><span>图形导出沿用当前显示设置</span></footer>
            </article>

            {settingsOpen && <aside className="settings-panel">
              <div className="settings-title"><div><small>CALCULATION SETTINGS</small><h2>本命盘参数</h2></div><button onClick={() => setSettingsOpen(false)}>×</button></div>
              <label>黄道制<select value={settings.zodiac} onChange={(event) => setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] })}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select><small>切换黄道会生成新的计算快照，不会只移动图形标签。</small></label>
              {settings.zodiac === "sidereal" && <label>岁差体系 Ayanamsa<select value={settings.ayanamsa} onChange={(event) => setSettings({ ...settings, ayanamsa: event.target.value as NatalCalculationSettings["ayanamsa"] })}>{ayanamsaOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select><small>岁差体系会写入本次计算结果与导出的分析数据。</small></label>}
              <label>规则方案<select value={settings.analysisSystem} onChange={(event) => setSettings({ ...settings, analysisSystem: event.target.value as NatalCalculationSettings["analysisSystem"] })}>{analysisSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select><small>{analysisSystemOptions.find((option) => option.id === settings.analysisSystem)?.description}</small></label>
              <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
              <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="both">真交点＋平均交点</option><option value="true">真交点</option><option value="mean">平均交点</option></select></label>
              <fieldset><legend>计算点位（需重新计算）</legend>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <label className="check-option" key={group}><input type="checkbox" checked={groups[group]} onChange={(event) => setGroups({ ...groups, [group]: event.target.checked })} /><span>{pointGroupLabels[group]}</span><small>{pointGroups[group].length}</small></label>)}</fieldset>
              <fieldset><legend>相位计算（需重新计算）</legend><label className="check-option"><input type="checkbox" checked={!settings.aspectIds.length} onChange={(event) => setSettings({ ...settings, aspectIds: event.target.checked ? [] : ["conjunction", "opposition", "trine", "square", "sextile"] })} /><span>完整专业相位集</span><small>{allAspectIds.length}</small></label><div className="aspect-toggle-grid">{allAspectIds.map((aspect) => <button key={aspect} className={!settings.aspectIds.length || settings.aspectIds.includes(aspect) ? "on" : ""} onClick={() => { const base = settings.aspectIds.length ? settings.aspectIds : [...allAspectIds]; setSettings({ ...settings, aspectIds: base.includes(aspect) ? base.filter((id) => id !== aspect) : [...base, aspect] }); }}>{aspectNames[aspect] ?? aspect}</button>)}</div><details className="orb-overrides"><summary>逐相位容许度覆盖（{allAspectIds.length} 项）</summary><div>{allAspectIds.map((aspect) => <label key={`orb-${aspect}`}><span>{aspectNames[aspect] ?? aspect}</span><input type="number" min="0" max="15" step="0.1" placeholder="规则默认" value={settings.orbOverrides[aspect] ?? ""} onChange={(event) => { const next = { ...settings.orbOverrides }; if (event.target.value === "") delete next[aspect]; else next[aspect] = Number(event.target.value); setSettings({ ...settings, orbOverrides: next }); }} /></label>)}</div></details></fieldset>
              <fieldset className="wheel-display-settings"><legend>轮盘显示（即时生效）</legend><p className="settings-help">这些选项只改变当前轮盘与图形导出，不会修改计算快照。</p><h3>显示点位</h3>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <label className="check-option" key={`wheel-${group}`}><input type="checkbox" checked={wheelGroups[group]} onChange={(event) => setWheelGroups({ ...wheelGroups, [group]: event.target.checked })} /><span>{pointGroupLabels[group]}</span><small>{pointGroups[group].length}</small></label>)}<h3>图层</h3><div className="display-toggle-grid">{([
                ["showDegreeTicks", "360°刻度"], ["showZodiacNames", "星座名称"], ["showZodiacDegrees", "星座度数"], ["showHouseLines", "宫位分割线"], ["showHouseNumbers", "宫位数字"], ["showAxes", "四轴"], ["showPointLeaders", "点位引线"], ["showPointDegrees", "点位度数"], ["showAspectLines", "中心相位线"], ["showLegend", "相位图例"],
              ] as Array<[keyof Omit<NatalRenderControls, "visiblePointIds" | "aspectFilterMode" | "aspectTopPercent" | "aspectMinimumStrength">, string]>).map(([key, label]) => <label className="check-option" key={key}><input type="checkbox" checked={Boolean(wheelControls[key])} onChange={(event) => setWheelControls({ ...wheelControls, [key]: event.target.checked })} /><span>{label}</span></label>)}</div><label className="check-option"><input type="checkbox" checked={wheelControls.majorAspectsOnly} onChange={(event) => setWheelControls({ ...wheelControls, majorAspectsOnly: event.target.checked })} /><span>仅主要相位</span><small>0° / 60° / 90° / 120° / 180°</small></label><label>相位线筛选<select value={wheelControls.aspectFilterMode} onChange={(event) => setWheelControls({ ...wheelControls, aspectFilterMode: event.target.value as NatalRenderControls["aspectFilterMode"] })}><option value="top_percent">按强度保留前百分比</option><option value="minimum_strength">按最低强度阈值</option></select></label>{wheelControls.aspectFilterMode === "top_percent" ? <label>保留强度最高的 {wheelControls.aspectTopPercent}%<input type="range" min="1" max="100" step="1" value={wheelControls.aspectTopPercent} onChange={(event) => setWheelControls({ ...wheelControls, aspectTopPercent: Number(event.target.value) })} /><small>当前显示 {natalRenderSpec.options.visible_aspect_count} / {snapshot.result.aspects.length} 条计算相位。</small></label> : <label>最低强度 {Math.round(wheelControls.aspectMinimumStrength * 100)}%<input type="range" min="0" max="100" step="1" value={Math.round(wheelControls.aspectMinimumStrength * 100)} onChange={(event) => setWheelControls({ ...wheelControls, aspectMinimumStrength: Number(event.target.value) / 100 })} /><small>当前显示 {natalRenderSpec.options.visible_aspect_count} / {snapshot.result.aspects.length} 条计算相位。</small></label>}</fieldset>
              <button className="settings-calculate" disabled={busy} onClick={calculateNatal}>{busy ? "正在重新计算…" : settingsDirty ? "重新计算并应用参数" : "按当前参数重新计算"}</button>
              {settingsDirty && <p className="settings-boundary"><b>存在尚未应用的参数改动。</b> 点击上方“重新计算并应用参数”后，轮盘与分析结果会一起更新。</p>}
              <p className="settings-boundary">当前已支持专业点位组、汉堡虚星与扩展 Lots。固定星与任意小行星等扩展能力会在计算规则完成验证后开放；未开放的选项不会伪装为已计算。</p>
            </aside>}
          </div>

          <section className="result-section" id="natal-results" ref={resultsRef}>
            <div className="result-tabs">
              {(["basic", "signs", "houses", "aspects", "structure", "classical", "technical"] as ResultTab[]).map((item) => <button key={item} className={tab === item ? "active" : ""} onClick={() => setTab(item)}>{({ basic: "基本", signs: "星座", houses: "宫位", aspects: "相位", structure: "结构", classical: "古典", technical: "分析数据与导出" })[item]}<small>{item === "basic" ? snapshot.result.points.length : item === "signs" ? signGroups.length : item === "houses" ? snapshot.result.houses.length : item === "aspects" ? snapshot.result.aspects.length : ""}</small></button>)}
            </div>

            {tab === "basic" && <div className="result-content">
              <div className="section-copy"><div><small>{dateLevelMode ? "DATE-RANGE EPHEMERIS" : "DIRECT CALCULATION"}</small><h2>{dateLevelMode ? "日期级星座位置与不确定范围" : "星座、度数、宫位与运动状态"}</h2><p>{dateLevelMode ? "≈ 表示当地日期中点的参考位置，不是出生时刻。每颗天体同时保留完整日期内的最大不确定度、跨星座和运动状态风险。" : "这些结果由天文与占星规则直接计算。点击“解读”读取该点位的自身功能、星座表达、宫位领域与运动状态。"}</p></div><button onClick={() => setTab("technical")}>查看全部字段</button></div>
              <h3 className="table-group-title">十大行星</h3><div className="data-table"><div className="table-head"><span>星体</span><span>星座度数</span><span>宫位</span><span>运动</span><span>经纬度／范围</span><span>操作</span></div>{corePoints.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id]}</b>{pointNames[point.point_id]}</span><span>{pointPlacementLabel(point, dateLevelMode)}{dateLevelMode && <small>日期中点参考</small>}</span><span>{pointHouseLabel(point)}</span><span className={point.retrograde ? "retrograde" : ""}>{pointMotionLabel(point, dateLevelMode)}</span><span>{point.position.ecliptic.longitude_deg.toFixed(4)}°<small>{dateLevelMode ? pointUncertaintyLabel(point) : `纬 ${point.position.ecliptic.latitude_deg?.toFixed(3) ?? "—"}°`}</small></span><button onClick={() => openPoint(point)}>解读</button></div>)}</div>
              <h3 className="table-group-title">轴点、交点、小行星与阿拉伯点</h3>{extendedPoints.length ? <div className="data-table"><div className="table-head"><span>点位</span><span>星座度数</span><span>宫位</span><span>运动</span><span>类型</span><span>操作</span></div>{extendedPoints.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id] ?? "•"}</b>{pointNames[point.point_id] ?? point.point_id}</span><span>{pointPlacementLabel(point, dateLevelMode)}</span><span>{pointHouseLabel(point)}</span><span className={point.retrograde ? "retrograde" : ""}>{pointMotionLabel(point, dateLevelMode)}</span><span>{pointKindNames[String(point.kind)] ?? "扩展点位"}</span><button onClick={() => openPoint(point)}>解读</button></div>)}</div> : <TimeDependentUnavailable title="时刻依赖点位未生成" detail="四轴、Vertex、依赖 ASC 的 Lots 与其他时刻敏感点不会在出生时刻未知时进入结果。" />}
            </div>}

            {tab === "signs" && <div className="result-content"><div className="section-copy"><div><small>SIGN PLACEMENTS</small><h2>星座落点与表达方式</h2><p>{dateLevelMode ? "按日期中点参考星座聚合，并保留完整日期的不确定范围。跨星座风险会进入点位事实，不把中点位置包装成精确本命落点。" : "星座由黄经直接换算。这里按星座聚合所有已选择点位，并保留每个点位的精确度数、宫位、运动状态和独立解读入口。"}</p></div></div><div className="sign-result-grid">{signGroups.map((group) => <article key={group.sign}><header><span>{signGlyphs[signIds.indexOf(group.sign)]}</span><div><b>{signNames[group.sign]}</b><small>{signStyles[group.sign]}</small></div><i>{group.points.length} 点</i></header><div>{group.points.map((point) => <button key={point.point_id} onClick={() => openPoint(point)}><span>{pointGlyphs[point.point_id] ?? "•"}</span><b>{pointNames[point.point_id] ?? point.point_id}</b><small>{dateLevelMode ? "≈ " : ""}{formatDegree(point.degree_in_sign)} · {point.house ? `第${point.house}宫` : pointUncertaintyLabel(point)}{point.retrograde ? " · 逆行" : ""}</small><i>解读</i></button>)}</div></article>)}</div></div>}

            {tab === "houses" && <div className="result-content"><div className="section-copy"><div><small>HOUSE CUSPS & RULERS</small><h2>十二宫宫头、宫主与宫内点位</h2><p>十二宫把星盘划分为自我、资源、沟通、家庭、创造、日常、关系、共同资源、远行、事业、社群与内在等生活领域。宫位依赖出生时间和地点；资料不足时会明确提示，不会默认使用 00:00。</p></div></div>{snapshot.result.houses.length ? <div className="house-grid">{snapshot.result.houses.map((house, index) => <article key={house.number}><header><span>{house.number}</span><div><b>第{house.number}宫</b><small>{houseDomains[house.number - 1]}</small></div></header><dl><div><dt>宫头</dt><dd>{signNames[house.sign]} {formatDegree(house.degree_in_sign)}</dd></div><div><dt>跨度</dt><dd>{house.span_deg.toFixed(3)}°</dd></div><div><dt>传统宫主</dt><dd>{house.traditional_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>现代宫主</dt><dd>{house.modern_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>宫内点位</dt><dd>{house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}</dd></div></dl><button onClick={() => setTarget({ type: "house", id: String(house.number), title: `第${house.number}宫`, fact: `宫头 ${signNames[house.sign]} ${formatDegree(house.degree_in_sign)}，跨度 ${house.span_deg.toFixed(3)}°`, resultPath: `/result/houses/${index}` })}>解读宫位</button></article>)}</div> : <TimeDependentUnavailable title="十二宫未计算" detail="ASC、MC 和十二宫宫头会在一天内显著移动；没有出生时刻就不存在唯一、可复现的宫位结果。" />}</div>}

            {tab === "aspects" && <div className="result-content"><div className="section-copy"><div><small>PROFESSIONAL ASPECT SET</small><h2>完整本命相位表</h2><p>展示理论角度、实际角距、容许度、入出相和强度。平行/反平行与镜像相位在算法卡通过后以独立分组出现，不会混入黄经相位。</p></div><span className="count-chip">{snapshot.result.aspects.length} 条</span></div>{snapshot.result.aspects.length ? <div className="aspect-table"><div className="aspect-head"><span>点位 A</span><span>相位</span><span>点位 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span><span>操作</span></div>{snapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}<small>{aspect.exact_angle_deg.toFixed(3)}°</small></b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span><i style={{ width: `${Math.round(aspect.strength * 100)}%` }} />{Math.round(aspect.strength * 100)}%</span><button onClick={() => openAspect(aspect)}>解读</button></div>)}</div> : <TimeDependentUnavailable title="本命相位未计算" detail="日期内月亮及快速点位会移动，单取中点会制造并不存在于出生时刻的相位；日期级模式只报告点位范围。" />}</div>}

            {tab === "structure" && <div className="result-content"><div className="section-copy"><div><small>NATAL STRUCTURE</small><h2>元素、模式、半球、象限与几何格局</h2><p>每项都显示参与点位、数量与规则边界。描述性结构不是人格分数；尚无版本化依据的 Jones 盘型保持不确定。</p></div></div>{dateLevelMode ? <TimeDependentUnavailable title="整盘结构未计算" detail="当前策略不以日期中点替代本命盘。半球、象限、角续果、群星、几何格局和 Jones 盘型均等待可靠出生时刻。" /> : <><div className="distribution-grid">{snapshot.result.distributions?.map((distribution) => <article key={distribution.dimension}><h3>{({ elements: "四元素", modalities: "三模式", polarities: "阴阳属性" } as Record<string, string>)[distribution.dimension] ?? distribution.dimension}</h3>{distribution.categories.map((category) => { const max = Math.max(...distribution.categories.map((item) => item.count), 1); return <div key={category.category_id}><span>{({ fire: "火", earth: "土", air: "风", water: "水", cardinal: "基本", fixed: "固定", mutable: "变动", positive: "阳性", negative: "阴性" } as Record<string, string>)[category.category_id] ?? category.category_id}</span><i><b style={{ width: `${category.count / max * 100}%` }} /></i><strong>{category.count}</strong></div>; })}</article>)}</div><StructureResults snapshot={snapshot} onOpen={setTarget} /></>}</div>}

            {tab === "classical" && <div className="result-content"><div className="section-copy"><div><small>CLASSICAL & HELLENISTIC CORE</small><h2>昼夜、尊贵、太阳条件、接纳与阿拉伯点</h2><p>古典结果与现代结果共用同一份天文快照，但采用独立、版本化的传统规则表；不再用原始 JSON 代替专业阅读。</p></div></div>{dateLevelMode ? <TimeDependentUnavailable title="古典与希腊化结果未计算" detail="Sect、太阳高度、宫位、Lots、偶然尊贵和许多接纳语境依赖出生时刻。当前快照不会混合部分可算项后冒充完整古典分析。" /> : <ClassicalResults snapshot={snapshot} onOpen={setTarget} />}</div>}

            {tab === "technical" && <div className="result-content technical-layout">
              <div className="technical-main"><div className="section-copy"><div><small>PORTABLE ANALYSIS DATA</small><h2>可复制的本命盘分析数据</h2><p>只包含可以交给占星师或外部模型继续分析的事实：点位、宫位、相位、分布、格局、古典状态与输入提醒。</p></div><div className="document-actions"><button onClick={copyTechnical}>复制全文</button><button onClick={() => downloadTechnical("markdown")}>导出 .md</button><button onClick={() => downloadTechnical("plaintext")}>导出 .txt</button><button onClick={downloadSnapshotJson}>专业 JSON</button></div></div><dl className="document-integrity"><div><dt>当前格式</dt><dd>Markdown · {new Blob([technicalDocument]).size} 字节</dd></div><div><dt>文档用途</dt><dd>复制给占星师、GPT、Kimi 或其他外部分析工具。</dd></div><div><dt>数据边界</dt><dd>只输出可用于继续分析的事实；完整 JSON 可单独导出。</dd></div></dl><div className="csv-export"><label>专业数据表<select value={exportTableId} onChange={(event) => setExportTableId(event.target.value as (typeof natalTableExports)[number][0])}>{natalTableExports.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select></label><button disabled={!snapshot.id.startsWith("calculation-")} onClick={downloadSelectedTable}>导出所选 CSV</button><small>{snapshot.id.startsWith("calculation-") ? "CSV 由同一不可变快照投影，不会重新计算。" : "演示数据仅支持本地 JSON；生成真实快照后开放 CSV。"}</small></div><textarea aria-label="本命盘分析数据" value={technicalDocument} readOnly spellCheck={false} /></div>
              <aside className="ai-panel"><span>OPTIONAL AI CONNECTOR</span><h3>提交至 AI 分析</h3><p>AI 只接收已算好的分析数据，不负责计算星历、星座、宫位或相位。必须先预览本次载荷，再单独同意。</p><label>服务商<select value={providerId} onChange={(event) => { const next = event.target.value as AiProviderId; const provider = providers.find((item) => item.provider_id === next); setProviderId(next); setModelId(provider?.models[0]?.model_id ?? "deepseek-v4-pro"); setAiPreview(null); setConsent(false); setSubjectDataAuthority(false); }}>{providers.map((provider) => <option key={provider.provider_id} value={provider.provider_id}>{provider.label}{provider.configured ? "" : " · 未配置"}</option>)}</select></label><label>模型<select value={modelId} onChange={(event) => { setModelId(event.target.value as AiModelId); setAiPreview(null); setConsent(false); setSubjectDataAuthority(false); }}>{selectedProvider?.models.map((model) => <option key={model.model_id} value={model.model_id}>{model.label}{model.configured ? "" : " · 未配置"}</option>)}</select></label><label>分析重点（可选）<textarea value={aiFocus} onChange={(event) => { setAiFocus(event.target.value); setAiPreview(null); setConsent(false); setSubjectDataAuthority(false); }} placeholder="例如：优先分析职业结构与古典尊贵之间的关系" /></label><button className="payload-preview-button" disabled={aiPreviewBusy || !snapshot.id.startsWith("calculation-")} onClick={previewAi}>{aiPreviewBusy ? "正在生成预览…" : "预览将发送的载荷"}</button>{aiPreview && <section className="payload-preview"><header><b>本次载荷预览</b><small>尚未发送</small></header><dl><div><dt>分析数据</dt><dd>{aiPreview.document_format} · {aiPreview.character_count} 字符 · 约 {aiPreview.estimated_tokens} tokens</dd></div><div><dt>内容校验</dt><dd><code>{aiPreview.document_content_hash}</code></dd></div><div><dt>载荷校验</dt><dd><code>{aiPreview.payload_hash}</code></dd></div><div><dt>数据目的地</dt><dd>{aiPreview.data_destination}</dd></div><div><dt>响应保存</dt><dd>{aiPreview.store_response ? "随该人物最新结果保存" : "游客／临时结果不保存"}</dd></div><div><dt>保留说明</dt><dd>{aiPreview.retention_policy}</dd></div></dl><details><summary>查看发送内容节选</summary><pre>{aiPreview.preview_excerpt}</pre></details></section>}<label className="consent-row"><input type="checkbox" disabled={!aiPreview} checked={subjectDataAuthority} onChange={(event) => setSubjectDataAuthority(event.target.checked)} /><span>我确认有权提交该人物的资料</span></label><label className="consent-row"><input type="checkbox" disabled={!aiPreview} checked={consent} onChange={(event) => setConsent(event.target.checked)} /><span>我同意发送本次预览中同一校验值的载荷</span></label><button className="ai-submit" disabled={aiSubmitBusy || !selectedProvider?.configured || !aiPreview || !consent || !subjectDataAuthority || !snapshot.id.startsWith("calculation-")} onClick={submitAi}>{aiSubmitBusy ? "DeepSeek 分析中…" : `提交至 ${selectedProvider?.label}`}</button><div className="connector-status"><b>{selectedProvider?.configured ? "已配置" : "尚未配置"}</b><p>{selectedProvider?.blocking_reason ?? "服务端密钥已配置，等待用户预览和授权。"}</p></div>{aiAnalysisText && <label className="ai-result"><span>AI 分析结果</span><textarea aria-label="DeepSeek 分析结果" value={aiAnalysisText} readOnly spellCheck={false} /></label>}<button className="copy-fallback" onClick={copyTechnical}>没有 API？复制后自行提交</button></aside>
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
          <section className="calculation-step"><div className="step-title"><span>4</span><div><b>检查关键参数</b><small>这里只展示最影响结果的参数；完整点位、相位与容许度仍可在工作台参数面板调整。</small></div></div><div className="calculation-key-settings"><label>分析体系<select value={settings.analysisSystem} onChange={(event) => { setSelectedPresetId("custom"); setSettings({ ...settings, analysisSystem: event.target.value as NatalCalculationSettings["analysisSystem"] }); }}>{analysisSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label><label>黄道体系<select value={settings.zodiac} onChange={(event) => { setSelectedPresetId("custom"); setSettings({ ...settings, zodiac: event.target.value as NatalCalculationSettings["zodiac"] }); }}><option value="tropical">Tropical 回归黄道</option><option value="sidereal">Sidereal 恒星黄道</option></select></label><label>宫位制<select value={settings.houseSystem} onChange={(event) => { setSelectedPresetId("custom"); setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] }); }}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>{settings.zodiac === "sidereal" && <label>Ayanamsa<select value={settings.ayanamsa} onChange={(event) => { setSelectedPresetId("custom"); setSettings({ ...settings, ayanamsa: event.target.value as NatalCalculationSettings["ayanamsa"] }); }}>{ayanamsaOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>}<label>点位范围<select value={groups.hamburg ? "all" : groups.lots ? "professional" : "modern"} onChange={(event) => { setSelectedPresetId("custom"); const value = event.target.value; setGroups(value === "all" ? { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: true } : value === "professional" ? { core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: false } : { core: true, angles: true, lunar: true, asteroids: true, lots: false, hamburg: false }); }}><option value="modern">现代常用点位</option><option value="professional">专业点位（含 Lots）</option><option value="all">全部已发布点位（含汉堡虚星）</option></select></label><label>相位范围<select value={settings.aspectIds.length === majorAspectIds.length ? "major" : settings.aspectIds.length === professionalAspectIds.length ? "professional" : "all"} onChange={(event) => { setSelectedPresetId("custom"); const value = event.target.value; setSettings({ ...settings, aspectIds: value === "major" ? majorAspectIds : value === "professional" ? professionalAspectIds : [] }); }}><option value="major">五大主要相位</option><option value="professional">专业常用相位</option><option value="all">全部已发布相位</option></select></label></div><section className="effective-parameter-preview"><header><b>本次生效参数</b><span>{selectedPresetId === "custom" ? "自定义" : natalCalculationPresets.find((item) => item.id === selectedPresetId)?.badge}</span></header><dl><div><dt>分析体系</dt><dd>{analysisSystemOptions.find((item) => item.id === settings.analysisSystem)?.label}</dd></div><div><dt>黄道</dt><dd>{settings.zodiac === "tropical" ? "回归黄道" : `恒星黄道 · ${ayanamsaOptions.find((item) => item.id === settings.ayanamsa)?.label}`}</dd></div><div><dt>宫位</dt><dd>{houseSystemOptions.find((item) => item.id === settings.houseSystem)?.label}</dd></div><div><dt>点位组</dt><dd>{Object.values(groups).filter(Boolean).length} / {Object.keys(groups).length}</dd></div><div><dt>相位</dt><dd>{settings.aspectIds.length || allAspectIds.length} 种</dd></div><div><dt>输出</dt><dd>轮盘、相位矩阵、数据表、基本／星座／宫位／结构／古典／导出</dd></div></dl><p>计算结果会记录这些参数及数据版本；修改后会生成一份新的可复现快照。</p></section><label className="save-person"><input type="checkbox" disabled={!accountWorkspace.authenticated || Boolean(selectedPersonId)} checked={Boolean(selectedPersonId) || saveProfile} onChange={(event) => setSaveProfile(event.target.checked)} /><span><b>{selectedPersonId ? "覆盖该人物的最新本命盘" : accountWorkspace.authenticated ? "计算完成后保存人物与最新结果" : "游客结果不保存"}</b><small>{selectedPersonId ? "旧的本命计算结果不会保留。" : accountWorkspace.authenticated ? "不勾选则只在当前页面使用。" : "登录／注册后才可永久保存。"}</small></span></label>{accountWorkspace.authenticated && <label className="save-person"><input type="checkbox" disabled={!selectedPersonId && !saveProfile} checked={setAsDefault} onChange={(event) => setSetAsDefault(event.target.checked)} /><span><b>设为工作台默认人物</b><small>下次打开工作台时优先展示这个人物；之后可在对象库修改或取消。</small></span></label>}</section>
          <footer><button onClick={() => setCalculationModal(false)}>取消</button><button className="calculate-button" disabled={busy} onClick={calculateNatal}>{busy ? "正在计算全部本命事实…" : "计算完整本命盘"}</button></footer>
        </section>
      </div>}

      {analysisCenterOpen && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAnalysisCenterOpen(false); }}><section className="person-modal analysis-center" role="dialog" aria-modal="true" aria-label="分析中心"><header><div><span>ANALYSIS CENTER</span><h2>六种分析入口</h2><p>入口只决定用户从哪里开始；后台仍生成可检查的计算配方，不会一次计算全部能力。</p></div><button onClick={() => setAnalysisCenterOpen(false)} aria-label="关闭">×</button></header><div className="entry-mode-grid">{entryModes.map((entry, index) => <article key={entry.id}><span>0{index + 1}</span><h3>{entry.title}</h3><p>{entry.description}</p><small>{entry.context}</small><button onClick={() => { setAnalysisCenterOpen(false); openNewCalculation(entry.id); }}>从此入口开始</button></article>)}</div></section></div>}

      {capabilityTarget && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setCapabilityTarget(null); }}><section className="person-modal capability-modal" role="dialog" aria-modal="true" aria-label={`${capabilityTarget.label}能力说明`}><header><div><span>FUTURE CHART METHOD</span><h2>{capabilityTarget.label}</h2><p>已保留独立产品入口，当前本命盘完成前不开发此技法。</p></div><button onClick={() => setCapabilityTarget(null)} aria-label="关闭">×</button></header><div className="capability-detail"><dl><div><dt>状态</dt><dd>规划中 · 当前不可计算</dd></div><div><dt>所需输入</dt><dd>{capabilityTarget.inputs}</dd></div><div><dt>未来输出</dt><dd>{capabilityTarget.outputs}</dd></div><div><dt>原计划阶段</dt><dd>{capabilityTarget.stage}（现已暂停，等待本命盘完成后的用户决定）</dd></div></dl><p>这个入口不会打开本命盘弹窗，也不会返回示例结果。未来开发时会复用本命盘阶段完成的时间、星历、宫位、相位、轮盘、表格、解读和导出能力。</p></div><footer><button className="calculate-button" onClick={() => setCapabilityTarget(null)}>我知道了</button></footer></section></div>}
      {target && <InterpretationDrawer target={target} snapshot={snapshot} onClose={() => setTarget(null)} />}
    </main>
  );
}
