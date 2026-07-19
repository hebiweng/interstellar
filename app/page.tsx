"use client";

import { useEffect, useMemo, useState } from "react";

import {
  createPersonAndNatalCalculation,
  getAiProviders,
  getNatalItemInterpretation,
  getNatalTechnicalDocument,
  InterstellarApiError,
  submitNatalToAi,
  type AiProvider,
  type ItemInterpretation,
  type NatalAspect,
  type NatalCalculationSettings,
  type NatalHouse,
  type NatalPersonInput,
  type NatalPoint,
  type NatalSnapshot,
} from "./lib/interstellar-api";

type ResultTab = "basic" | "signs" | "houses" | "aspects" | "structure" | "classical" | "technical";
type ChartView = "wheel" | "aspect_grid";
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

const globalNavigation = ["工作台", "分析中心", "对象库", "图表中心", "报告"] as const;

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

const timezoneOptions = [
  "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Taipei", "Asia/Tokyo", "Asia/Singapore",
  "Europe/London", "Europe/Paris", "America/New_York", "America/Chicago", "America/Los_Angeles", "Australia/Sydney",
];

const placeOptions = [
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

const signNames: Record<string, string> = {
  aries: "白羊", taurus: "金牛", gemini: "双子", cancer: "巨蟹", leo: "狮子", virgo: "处女",
  libra: "天秤", scorpio: "天蝎", sagittarius: "射手", capricorn: "摩羯", aquarius: "水瓶", pisces: "双鱼",
};
const signGlyphs = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"];
const signIds = Object.keys(signNames);

const aspectNames: Record<string, string> = {
  conjunction: "合相", opposition: "对冲", trine: "三分", square: "四分", sextile: "六分",
  semiduodecile: "半十二分", semioctile: "辅八分", semisextile: "半六分", semisquare: "半刑", sesquisquare: "拱半", quincunx: "梅花",
  quintile: "五分", biquintile: "双五分", novile: "九分", septile: "七分", biseptile: "双七分",
  triseptile: "三七分", undecile: "十一分", decile: "十分",
};

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

const sampleAspects: NatalAspect[] = [
  ["sun", "mercury", "conjunction", 0.57, "applying"], ["sun", "moon", "sextile", 4.6, "separating"],
  ["venus", "uranus", "conjunction", 3.16, "applying"], ["mars", "jupiter", "conjunction", 1.13, "separating"],
  ["saturn", "neptune", "square", 7.06, "applying"], ["moon", "pluto", "semisextile", 2.81, "separating"],
].map(([a, b, type, orb, state], index) => ({
  aspect_id: `sample:${index}`, point_a: String(a), point_b: String(b), type: String(type),
  exact_angle_deg: type === "conjunction" ? 0 : type === "sextile" ? 60 : type === "square" ? 90 : 30,
  actual_angle_deg: 0, orb_deg: Number(orb), applying_state: String(state), strength: Math.max(0, 1 - Number(orb) / 8),
}));

const sampleSnapshot: NatalSnapshot = {
  id: "sample-natal-20000301-beijing", status: "succeeded", maturity: "reference_fixture",
  input_fingerprint: "sha256:virtual-reference-fixture", engine: { name: "interstellar-core", version: "0.1.0-reference" }, warnings: [],
  result: {
    points: samplePoints, houses: sampleHouses, aspects: sampleAspects,
    distributions: [
      { dimension: "elements", categories: [{ category_id: "fire", count: 2 }, { category_id: "earth", count: 3 }, { category_id: "air", count: 3 }, { category_id: "water", count: 2 }] },
      { dimension: "modalities", categories: [{ category_id: "cardinal", count: 3 }, { category_id: "fixed", count: 4 }, { category_id: "mutable", count: 3 }] },
    ],
    structure: { availability: "reference_fixture", note: "真实计算后显示半球、象限、角续果宫、群星与几何格局。" },
    classical: { availability: "reference_fixture", day_night_status: "day", note: "真实计算后显示昼夜盘、尊贵、太阳条件、接纳与定位星。" },
    dignities: [], lots: [], receptions: [],
  },
};

const defaultPerson: NatalPersonInput = {
  displayName: "", relation: "self", localDate: "2000-03-01", localTime: "16:30", timezoneId: "Asia/Shanghai",
  placeName: "北京", countryCode: "CN", latitude: 39.93, longitude: 116.41, timeConfidence: "high",
};

const defaultSettings: NatalCalculationSettings = {
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

function toPlain(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  return JSON.stringify(value, null, 2);
}

function buildLocalInterpretation(target: InterpretationTarget, snapshot: NatalSnapshot): ItemInterpretation {
  if (target.type === "point") {
    const point = snapshot.result.points.find((item) => item.point_id === target.id);
    if (!point) return { status: "unavailable", unavailable_reason: "未找到对应点位事实。" };
    const fn = pointFunctions[point.point_id] ?? "此点位的专门解释模板尚未发布";
    const style = signStyles[point.sign] ?? "该星座的表达方式";
    const domain = point.house ? houseDomains[point.house - 1] : "宫位依赖准确出生时间";
    return {
      status: "available", title: `${pointNames[point.point_id] ?? point.point_id} · ${signNames[point.sign] ?? point.sign} · 第${point.house ?? "—"}宫`,
      facts: target.facts ?? [target.fact, `运动状态：${point.retrograde === true ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"}`],
      meaning: `${fn}，通过“${style}”的方式表达，主要落在“${domain}”这一生活领域。`,
      synthesis: "这是结构化单项解释，不替代整盘综合；相位、宫主星、尊贵与重复主题可能强化、修正或抵消这条倾向。",
      rule_refs: ["reporting.contextual_item_interpretation.v1", "natal.point_sign_house.composition.v1"],
      source_refs: ["internal.authored.natal-basic-template.v1"], template_version: "1.0.0", maturity: "Beta",
    };
  }
  if (target.type === "house") {
    const house = snapshot.result.houses.find((item) => String(item.number) === target.id);
    return house ? {
      status: "available", title: `第${house.number}宫 · ${signNames[house.sign] ?? house.sign}`,
      facts: [target.fact, `宫内点位：${house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}`],
      meaning: `第${house.number}宫对应“${houseDomains[house.number - 1]}”。宫头落在${signNames[house.sign] ?? house.sign}，表示这个领域倾向以“${signStyles[house.sign] ?? "对应星座"}”的方式启动。`,
      synthesis: "完整判断还需要宫主星落座、落宫、相位、宫内天体和宫位制共同参与。",
      rule_refs: ["natal.house.cusp_ruler.v1"], source_refs: ["internal.authored.house-domain.v1"], template_version: "1.0.0", maturity: "Beta",
    } : { status: "unavailable", unavailable_reason: "未找到宫位事实。" };
  }
  if (target.type === "aspect") {
    const aspect = snapshot.result.aspects.find((item) => item.aspect_id === target.id);
    if (!aspect) return { status: "unavailable", unavailable_reason: "未找到相位事实。" };
    const interaction: Record<string, string> = {
      conjunction: "两种功能紧密融合并彼此放大", opposition: "两端形成拉扯，需要在关系或情境中寻找平衡", square: "两种功能形成摩擦并推动行动",
      trine: "两种功能较自然地互相支持", sextile: "两种功能存在可被主动使用的协作机会", quincunx: "两种功能需要持续调整",
    };
    return {
      status: "available", title: target.title, facts: [target.fact, `入出相：${aspect.applying_state}`, `强度：${Math.round(aspect.strength * 100)}%`],
      meaning: `${pointNames[aspect.point_a] ?? aspect.point_a}与${pointNames[aspect.point_b] ?? aspect.point_b}${interaction[aspect.type] ?? "形成一种需要结合具体定义阅读的关系"}。`,
      synthesis: "容许度越小通常越接近精确；入相/出相只在两点运动语义都明确时判断。次要相位不应压过太阳、月亮、四轴和紧密主要相位。",
      rule_refs: aspect.rule_refs ?? ["official.aspects.professional_natal.v1"], source_refs: ["internal.authored.aspect-template.v1"], template_version: "1.0.0", maturity: "Beta",
    };
  }
  return {
    status: "available", title: target.title, facts: [target.fact],
    meaning: "该条目是由确定性规则引擎生成的结构或古典事实。当前先展示事实与计算依据；未发布的综合判断不会用通用文案补齐。",
    synthesis: "请与点位、宫位、相位以及其他同向或反向证据一起阅读。",
    rule_refs: [target.type === "classical" ? "ALG-NATAL-004" : "ALG-NATAL-003"],
    source_refs: ["interstellar.versioned-rule-pack"], template_version: "1.0.0", maturity: "Experimental",
  };
}

function buildLocalTechnicalDocument(snapshot: NatalSnapshot, subjectName: string) {
  const lines = [
    `# ${subjectName} · 本命盘专业技术推演`, "", "> 由确定性计算结果生成；AI 不参与星历、星座、宫位或相位计算。", "",
    "## 完整点位", "", "| 点位 | 星座度数 | 宫位 | 运动 | 黄经 |", "|---|---:|---:|---|---:|",
    ...snapshot.result.points.map((point) => `| ${pointNames[point.point_id] ?? point.point_id} | ${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)} | ${point.house ?? "—"} | ${point.retrograde ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"} | ${point.position.ecliptic.longitude_deg.toFixed(6)}° |`),
    "", "## 十二宫", "", ...snapshot.result.houses.map((house) => `- 第${house.number}宫：${signNames[house.sign] ?? house.sign} ${formatDegree(house.degree_in_sign)}；点位 ${house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}`),
    "", "## 完整相位", "", ...snapshot.result.aspects.map((aspect) => `- ${pointNames[aspect.point_a] ?? aspect.point_a} ${aspectNames[aspect.type] ?? aspect.type} ${pointNames[aspect.point_b] ?? aspect.point_b}；容许度 ${aspect.orb_deg.toFixed(3)}°；${aspect.applying_state}`),
    "", "## 结构与古典事实", "", "```json", JSON.stringify({ structure: snapshot.result.structure, classical: snapshot.result.classical, dignities: snapshot.result.dignities, lots: snapshot.result.lots }, null, 2), "```",
    "", "## 可复现性", "", `- Snapshot: ${snapshot.id}`, `- Engine: ${snapshot.engine.name}@${snapshot.engine.version}`, `- Input fingerprint: ${snapshot.input_fingerprint}`, `- Maturity: ${snapshot.maturity}`,
  ];
  return lines.join("\n");
}

function NatalWheel({ snapshot }: { snapshot: NatalSnapshot }) {
  const points = snapshot.result.points.filter((point) => [
    ...pointGroups.core, "asc", "mc", "true_north_node", "chiron", "fortune", "spirit",
  ].includes(point.point_id));
  const asc = snapshot.result.points.find((point) => point.point_id === "asc")?.position.ecliptic.longitude_deg
    ?? snapshot.result.houses[0]?.cusp_longitude_deg ?? 0;
  const angleFor = (longitude: number) => (180 - (longitude - asc)) * Math.PI / 180;
  const xy = (longitude: number, radius: number) => ({
    x: Number((320 + Math.cos(angleFor(longitude)) * radius).toFixed(6)),
    y: Number((320 - Math.sin(angleFor(longitude)) * radius).toFixed(6)),
  });
  const pointById = new Map(snapshot.result.points.map((point) => [point.point_id, point]));
  return (
    <svg className="natal-wheel" viewBox="0 0 640 640" role="img" aria-label="本命盘轮盘">
      <circle cx="320" cy="320" r="294" className="wheel-outer" />
      <circle cx="320" cy="320" r="246" className="wheel-ring" />
      <circle cx="320" cy="320" r="184" className="wheel-ring wheel-inner" />
      {Array.from({ length: 12 }, (_, index) => {
        const boundary = xy(index * 30, 294);
        const inner = xy(index * 30, 246);
        const label = xy(index * 30 + 15, 270);
        return <g key={`sign-${index}`}><line x1={inner.x} y1={inner.y} x2={boundary.x} y2={boundary.y} className="sign-line" /><text x={label.x} y={label.y} className="sign-glyph">{signGlyphs[index]}</text></g>;
      })}
      {snapshot.result.houses.map((house) => {
        const end = xy(house.cusp_longitude_deg, 246);
        const number = xy(house.cusp_longitude_deg + house.span_deg / 2, 218);
        return <g key={`house-${house.number}`}><line x1="320" y1="320" x2={end.x} y2={end.y} className={house.number === 1 || house.number === 10 ? "house-line axis" : "house-line"} /><text x={number.x} y={number.y} className="house-number">{house.number}</text></g>;
      })}
      {snapshot.result.aspects.slice(0, 80).map((aspect) => {
        const a = pointById.get(aspect.point_a); const b = pointById.get(aspect.point_b);
        if (!a || !b) return null;
        const start = xy(a.position.ecliptic.longitude_deg, 176); const end = xy(b.position.ecliptic.longitude_deg, 176);
        const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
        return <line key={aspect.aspect_id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={hard ? "aspect-line hard" : "aspect-line"} />;
      })}
      {points.map((point, index) => {
        const location = xy(point.position.ecliptic.longitude_deg, 196 - (index % 3) * 13);
        return <g key={point.point_id} transform={`translate(${location.x} ${location.y})`}><circle r="13" className="planet-dot" /><text className="planet-glyph" y="1">{pointGlyphs[point.point_id] ?? "•"}</text></g>;
      })}
      <circle cx="320" cy="320" r="54" className="wheel-core" />
      <text x="320" y="310" className="wheel-core-title">NATAL</text>
      <text x="320" y="333" className="wheel-core-sub">{snapshot.result.points.length} 点 · {snapshot.result.aspects.length} 相位</text>
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
      <p>矩阵展示核心点位的主要相位；完整专业相位集仍在下方“相位”结果页中。点击单元格可查看计算事实与解读边界。</p>
    </div>
  );
}

function InterpretationDrawer({ target, snapshot, onClose }: { target: InterpretationTarget; snapshot: NatalSnapshot; onClose: () => void }) {
  const [result, setResult] = useState<ItemInterpretation>(() => buildLocalInterpretation(target, snapshot));
  const [loading, setLoading] = useState(snapshot.id.startsWith("calculation-") && Boolean(target.resultPath));
  useEffect(() => {
    let active = true;
    if (!snapshot.id.startsWith("calculation-") || !target.resultPath) return () => { active = false; };
    getNatalItemInterpretation(snapshot.id, target.type, target.resultPath)
      .then((value) => {
        if (active && value.status === "available") {
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
  }, [snapshot.id, target.fact, target.facts, target.id, target.resultPath, target.title, target.type]);
  return (
    <div className="drawer-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <aside className="interpretation-drawer" role="dialog" aria-modal="true" aria-label="逐项解读">
        <header><div><span>CONTEXTUAL INTERPRETATION</span><h2>{result.title ?? target.title}</h2></div><button onClick={onClose} aria-label="关闭">×</button></header>
        {loading && <div className="drawer-loading">正在读取版本化解读规则…</div>}
        {result.status === "unavailable" ? <section><h3>尚无已发布规则</h3><p>{result.unavailable_reason}</p></section> : <>
          <section><h3>计算事实</h3>{[...new Set(result.facts ?? [])].map((fact, index) => <p className="fact-line" key={`${index}:${fact}`}>{fact}</p>)}</section>
          <section><h3>单项含义</h3><p>{result.meaning}</p></section>
          <section><h3>组合阅读边界</h3><p>{result.synthesis}</p></section>
          <section className="provenance-box"><h3>规则与来源</h3><dl><div><dt>成熟度</dt><dd>{result.maturity}</dd></div><div><dt>模板</dt><dd>{result.template_version}</dd></div><div><dt>规则</dt><dd>{[...new Set(result.rule_refs ?? [])].join(" · ")}</dd></div><div><dt>来源</dt><dd>{[...new Set(result.source_refs ?? [])].join(" · ")}</dd></div></dl></section>
        </>}
      </aside>
    </div>
  );
}

function PersonFields({ person, onChange }: { person: NatalPersonInput; onChange: (person: NatalPersonInput) => void }) {
  const applyPlace = (name: string) => {
    const match = placeOptions.find((place) => place.name === name);
    onChange(match ? { ...person, placeName: match.name, countryCode: match.countryCode, latitude: match.latitude, longitude: match.longitude, timezoneId: match.timezoneId } : { ...person, placeName: name });
  };
  return <div className="form-grid">
    <label>名称<input value={person.displayName} onChange={(event) => onChange({ ...person, displayName: event.target.value })} placeholder="本人或关系人物名称" /></label>
    <label>与我的关系<select value={person.relation} onChange={(event) => onChange({ ...person, relation: event.target.value as NatalPersonInput["relation"] })}><option value="self">本人</option><option value="family">亲人</option><option value="partner">伴侣</option><option value="friend">朋友</option><option value="client">客户</option><option value="other">其他</option></select></label>
    <label>出生日期<input type="date" value={person.localDate} onChange={(event) => onChange({ ...person, localDate: event.target.value })} /></label>
    <label>出生时间<input type="time" value={person.localTime} onChange={(event) => onChange({ ...person, localTime: event.target.value })} /><small>当前精确时间模式；完全未知时间模式将在计算契约接入后开放，绝不默认 00:00。</small></label>
    <label>出生城市／地区<input list="interstellar-place-options" value={person.placeName} onChange={(event) => applyPlace(event.target.value)} placeholder="输入城市并从候选中选择" /><datalist id="interstellar-place-options">{placeOptions.map((place) => <option key={place.name} value={place.name}>{place.countryCode}</option>)}</datalist><small>选择候选会自动填写经纬度、国家和时区。</small></label>
    <label>IANA 时区<select value={person.timezoneId} onChange={(event) => onChange({ ...person, timezoneId: event.target.value })}>{timezoneOptions.map((timezone) => <option key={timezone} value={timezone}>{timezone}</option>)}</select><small>时区必须从候选选择，不接受自由文本。</small></label>
    <label>时间可信度<select value={person.timeConfidence} onChange={(event) => onChange({ ...person, timeConfidence: event.target.value as NatalPersonInput["timeConfidence"] })}><option value="high">高：出生证明或正式记录</option><option value="medium">中：本人或亲友记忆</option><option value="low">低：大致时间</option></select></label>
    <details className="advanced-location"><summary>高级位置覆盖</summary><div><label>纬度<input type="number" step="0.0001" value={person.latitude} onChange={(event) => onChange({ ...person, latitude: Number(event.target.value) })} /></label><label>经度<input type="number" step="0.0001" value={person.longitude} onChange={(event) => onChange({ ...person, longitude: Number(event.target.value) })} /></label></div><p>一般无需修改。国家代码由地点候选派生，仅用于消歧，不参与占星判断。</p></details>
  </div>;
}

export default function Home() {
  const [snapshot, setSnapshot] = useState<NatalSnapshot>(sampleSnapshot);
  const [subjectName, setSubjectName] = useState("阿斯特拉（虚拟验收样例）");
  const [tab, setTab] = useState<ResultTab>("basic");
  const [chartView, setChartView] = useState<ChartView>("wheel");
  const [personModal, setPersonModal] = useState(false);
  const [calculationModal, setCalculationModal] = useState(false);
  const [analysisCenterOpen, setAnalysisCenterOpen] = useState(false);
  const [capabilityTarget, setCapabilityTarget] = useState<(typeof chartTechniques)[number] | null>(null);
  const [entryPoint, setEntryPoint] = useState<EntryPointId>("technique");
  const [theme, setTheme] = useState<ThemeMode>("dark");
  const [settingsOpen, setSettingsOpen] = useState(true);
  const [person, setPerson] = useState<NatalPersonInput>(defaultPerson);
  const [settings, setSettings] = useState<NatalCalculationSettings>(defaultSettings);
  const [groups, setGroups] = useState<Record<keyof typeof pointGroups, boolean>>({ core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: true });
  const [saveProfile, setSaveProfile] = useState(false);
  const [savedPeople, setSavedPeople] = useState<NatalPersonInput[]>([]);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("当前展示静态虚拟验收样例；连接计算服务后可新增人物并生成真实快照。");
  const [target, setTarget] = useState<InterpretationTarget | null>(null);
  const [technicalDocument, setTechnicalDocument] = useState(() => buildLocalTechnicalDocument(sampleSnapshot, "阿斯特拉（虚拟验收样例）"));
  const [providers, setProviders] = useState<AiProvider[]>([
    { provider_id: "openai", label: "GPT / OpenAI", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "gpt", label: "GPT（后台指定版本）", configured: false }] },
    { provider_id: "moonshot", label: "Kimi / Moonshot", configured: false, availability: "blocked", blocking_reason: "等待后台配置 API 与允许模型", models: [{ model_id: "kimi", label: "Kimi（后台指定版本）", configured: false }] },
  ]);
  const [providerId, setProviderId] = useState<"openai" | "moonshot">("openai");
  const [consent, setConsent] = useState(false);
  const [aiFocus, setAiFocus] = useState("");

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const stored = window.localStorage.getItem("interstellar.natal.people.v1");
      if (stored) {
        try { setSavedPeople(JSON.parse(stored)); } catch { /* ignore invalid local cache */ }
      }
    }, 0);
    getAiProviders().then(setProviders).catch(() => undefined);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    const stored = window.localStorage.getItem("interstellar.theme") as ThemeMode | null;
    const next: ThemeMode = stored === "light" || stored === "dark" ? stored : "dark";
    setTheme(next);
    document.documentElement.dataset.theme = next;
  }, []);

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
  const structureEntries = useMemo(() => Object.entries(snapshot.result.structure ?? {}), [snapshot]);
  const classicalEntries = useMemo(() => Object.entries(snapshot.result.classical ?? {}), [snapshot]);

  function savePersonOnly() {
    if (!person.displayName.trim()) { setNotice("请先填写人物名称。 "); return; }
    const next = [...savedPeople.filter((item) => !(item.displayName === person.displayName && item.localDate === person.localDate)), person];
    setSavedPeople(next);
    window.localStorage.setItem("interstellar.natal.people.v1", JSON.stringify(next));
    setPersonModal(false);
    setNotice(`已保存人物“${person.displayName}”，未启动任何计算。可从“新建计算”选择这个人物。`);
  }

  function openNewCalculation(selectedEntry: EntryPointId = "technique", selectedPerson?: NatalPersonInput) {
    setEntryPoint(selectedEntry);
    if (selectedPerson) setPerson(selectedPerson);
    setCalculationModal(true);
  }

  async function calculateNatal() {
    if (!person.displayName.trim()) { setNotice("请先填写人物名称。 "); return; }
    setBusy(true); setNotice("正在标准化时间、计算星历、宫位、相位、结构与古典事实…");
    const pointIds = (Object.entries(groups) as Array<[keyof typeof pointGroups, boolean]>)
      .filter(([, enabled]) => enabled).flatMap(([group]) => [...pointGroups[group]]);
    const allGroupsEnabled = Object.values(groups).every(Boolean);
    try {
      const result = await createPersonAndNatalCalculation(person, { ...settings, pointIds: allGroupsEnabled ? [] : pointIds });
      setSnapshot(result.snapshot); setSubjectName(person.displayName); setCalculationModal(false); setTab("basic"); setChartView("wheel");
      const document = await getNatalTechnicalDocument(result.snapshot.id, "markdown");
      setTechnicalDocument(document);
      if (saveProfile) {
        const next = [...savedPeople.filter((item) => item.displayName !== person.displayName), person];
        setSavedPeople(next); window.localStorage.setItem("interstellar.natal.people.v1", JSON.stringify(next));
      }
      setNotice(`已生成真实本命快照：${result.snapshot.result.points.length} 个点位、${result.snapshot.result.aspects.length} 条相位。`);
    } catch (error) {
      const message = error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "本命盘计算失败。";
      setNotice(message);
    } finally { setBusy(false); }
  }

  async function copyTechnical() {
    try { await navigator.clipboard.writeText(technicalDocument); setNotice("已复制完整 Markdown 技术推演，可直接粘贴给外部模型。 "); }
    catch { setNotice("浏览器未允许剪贴板访问，请在技术推演中手动全选复制。 "); }
  }

  function downloadTechnical(format: "markdown" | "plaintext") {
    const content = format === "markdown" ? technicalDocument : technicalDocument.replace(/^#+\s*/gm, "").replace(/\|/g, " ");
    const blob = new Blob([content], { type: format === "markdown" ? "text/markdown;charset=utf-8" : "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob); const link = document.createElement("a");
    link.href = url; link.download = `${subjectName}-本命盘专业技术推演.${format === "markdown" ? "md" : "txt"}`; link.click(); URL.revokeObjectURL(url);
    setNotice(`已导出${format === "markdown" ? " Markdown" : "纯文本"}文档。`);
  }

  async function submitAi() {
    if (!snapshot.id.startsWith("calculation-")) { setNotice("虚拟样例不能提交；请先生成真实计算快照。 "); return; }
    try {
      await submitNatalToAi({ snapshotId: snapshot.id, providerId, modelId: providerId === "openai" ? "gpt" : "kimi", focus: aiFocus, consent });
      setNotice("AI 分析任务已提交。 ");
    } catch (error) {
      setNotice(error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "AI 分析提交失败。 ");
    }
  }

  const openPoint = (point: NatalPoint) => setTarget({
    type: "point", id: point.point_id, title: pointNames[point.point_id] ?? point.point_id,
    fact: `${pointNames[point.point_id] ?? point.point_id}位于${signNames[point.sign] ?? point.sign}${formatDegree(point.degree_in_sign)}，第${point.house ?? "—"}宫${point.retrograde ? "，逆行" : ""}`,
    facts: [
      `${pointNames[point.point_id] ?? point.point_id}位于${signNames[point.sign] ?? point.sign}${formatDegree(point.degree_in_sign)}，第${point.house ?? "—"}宫${point.retrograde ? "，逆行" : ""}`,
      `黄经 ${point.position.ecliptic.longitude_deg.toFixed(6)}° · 黄纬 ${point.position.ecliptic.latitude_deg?.toFixed(6) ?? "—"}°`,
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
    facts: [`理论角度 ${aspect.exact_angle_deg.toFixed(3)}°`, `入出相 ${aspect.applying_state}`, `强度 ${Math.round(aspect.strength * 100)}%`],
    resultPath: `/result/aspects/${snapshot.result.aspects.findIndex((item) => item.aspect_id === aspect.aspect_id)}`,
  });

  return (
    <main className="natal-app">
      <header className="site-header">
        <button className="brand-button" onClick={() => { setTab("basic"); window.scrollTo({ top: 0, behavior: "smooth" }); }}><span className="brand-mark">✦</span><span><b>INTERSTELLAR</b><small>PROFESSIONAL ASTROLOGY</small></span></button>
        <nav>{globalNavigation.map((item) => <button key={item} className={item === "工作台" ? "active" : ""} onClick={() => {
          if (item === "工作台") window.scrollTo({ top: 0, behavior: "smooth" });
          if (item === "分析中心") setAnalysisCenterOpen(true);
          if (item === "对象库") document.getElementById("subject-library")?.scrollIntoView({ behavior: "smooth" });
          if (item === "图表中心") document.getElementById("technique-strip")?.scrollIntoView({ behavior: "smooth" });
          if (item === "报告") { setTab("technical"); document.getElementById("natal-results")?.scrollIntoView({ behavior: "smooth" }); }
        }}>{item}</button>)}</nav>
        <div className="site-actions"><button className="theme-toggle" onClick={toggleTheme} aria-label={`切换到${theme === "dark" ? "浅色" : "深色"}主题`} title={`当前${theme === "dark" ? "深色" : "浅色"}主题`}><span>{theme === "dark" ? "☀" : "☾"}</span><small>{theme === "dark" ? "Light" : "Dark"}</small></button><button className="primary-action" onClick={() => openNewCalculation()}>＋ 新建计算</button></div>
      </header>

      <div className="notice-bar" role="status"><span>{snapshot.id.startsWith("calculation-") ? "REAL SNAPSHOT" : "VIRTUAL FIXTURE"}</span><p>{notice}</p></div>

      <section className="technique-strip" id="technique-strip" aria-label="占星计算方法">
        <div><small>CHART METHODS</small><b>计算方法</b></div>
        <nav>{chartTechniques.map((technique) => <button key={technique.id} className={technique.status === "active" ? "active" : "planned"} onClick={() => {
          if (technique.status === "active") { setChartView("wheel"); window.scrollTo({ top: 0, behavior: "smooth" }); }
          else setCapabilityTarget(technique);
        }}><span>{technique.label}</span><small>{technique.status === "active" ? "已开放" : "规划中"}</small></button>)}</nav>
      </section>

      <div className="natal-layout">
        <aside className="person-sidebar" id="subject-library">
          <div className="side-heading"><span>当前人物</span><button onClick={() => setPersonModal(true)}>新增</button></div>
          <button className="current-person"><span className="person-avatar">{subjectName.slice(0, 1)}</span><span><b>{subjectName}</b><small>{snapshot.id.startsWith("calculation-") ? "真实计算快照" : "虚拟示例 · 非真实人物"}</small></span><i>✓</i></button>
          <div className="side-heading"><span>本机人物库</span><small>{savedPeople.length}</small></div>
          <div className="saved-people">
            {savedPeople.map((saved) => <button key={`${saved.displayName}-${saved.localDate}`} onClick={() => { setPerson(saved); setNotice(`已选择人物“${saved.displayName}”。点击右上角“新建计算”选择计算方法。`); }}><span>{saved.displayName.slice(0, 1)}</span><div><b>{saved.displayName}</b><small>{saved.relation} · {saved.localDate}</small></div><i>选择</i></button>)}
            {!savedPeople.length && <p>尚无保存人物。“新增”只建档，不会自动计算；计算请使用右上角“新建计算”。</p>}
          </div>
          <section className="privacy-note"><b>当前保存边界</b><p>人物快捷资料仅保存在本机浏览器。登录、云端隔离和长期快照库尚未接入，绝不会显示成“全网共享”。</p></section>
        </aside>

        <section className="main-workspace">
          <header className="subject-title">
            <div><span>PROFESSIONAL NATAL · INTEGRATED FACTS</span><h1>{subjectName}的本命盘</h1><p>现代基础、盘面结构、完整相位与古典核心事实使用同一份不可变计算快照。</p></div>
            <div className="header-actions"><button onClick={() => setSettingsOpen((value) => !value)}>⚙ 参数</button><button onClick={() => setTab("technical")}>查看完整推演</button></div>
          </header>

          <div className={`hero-grid ${settingsOpen ? "with-settings" : ""}`}>
            <article className="wheel-panel">
              <div className="panel-heading"><div><small>NATAL CHART VIEWS</small><h2>{chartView === "wheel" ? "本命轮盘" : "主要相位图"}</h2></div><div className="view-switcher"><button className={chartView === "wheel" ? "active" : ""} onClick={() => setChartView("wheel")}>星盘</button><button className={chartView === "aspect_grid" ? "active" : ""} onClick={() => setChartView("aspect_grid")}>相位图</button><span>回归黄道</span><span>{settings.houseSystem}</span><span>{snapshot.result.points.length} 点</span></div></div>
              {chartView === "wheel" ? <NatalWheel snapshot={snapshot} /> : <AspectGrid snapshot={snapshot} onOpen={openAspect} />}
              <footer><span>Engine {snapshot.engine.version}</span><span>{snapshot.maturity}</span><span>{snapshot.input_fingerprint.slice(0, 22)}…</span></footer>
            </article>

            {settingsOpen && <aside className="settings-panel">
              <div className="settings-title"><div><small>CALCULATION SETTINGS</small><h2>本命盘参数</h2></div><button onClick={() => setSettingsOpen(false)}>×</button></div>
              <label>黄道制<select disabled><option>回归黄道 Tropical（当前可用）</option><option>恒星黄道（待实现）</option></select><small>当前服务只支持 Tropical，不会静默替换。</small></label>
              <label>规则方案<select defaultValue="integrated"><option value="integrated">专业综合本命 v1</option><option value="modern">现代本命 v1</option><option value="classical">古典本命 v1</option><option value="custom" disabled>自定义方案（规划中）</option></select><small>现代与古典事实分层展示，不合成不透明总分。</small></label>
              <label>宫位制<select value={settings.houseSystem} onChange={(event) => setSettings({ ...settings, houseSystem: event.target.value as NatalCalculationSettings["houseSystem"] })}>{houseSystemOptions.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
              <label>交点类型<select value={settings.nodeType} onChange={(event) => setSettings({ ...settings, nodeType: event.target.value as NatalCalculationSettings["nodeType"] })}><option value="both">真交点＋平均交点</option><option value="true">真交点</option><option value="mean">平均交点</option></select></label>
              <fieldset><legend>点位组</legend>{(Object.keys(pointGroups) as Array<keyof typeof pointGroups>).map((group) => <label className="check-option" key={group}><input type="checkbox" checked={groups[group]} onChange={(event) => setGroups({ ...groups, [group]: event.target.checked })} /><span>{({ core: "十大行星", angles: "四轴与敏感点", lunar: "交点与月球点", asteroids: "常用小行星", lots: "阿拉伯点", hamburg: "汉堡虚星" })[group]}</span><small>{pointGroups[group].length}</small></label>)}</fieldset>
              <fieldset><legend>相位展示与计算</legend><label className="check-option"><input type="checkbox" checked={!settings.aspectIds.length} onChange={(event) => setSettings({ ...settings, aspectIds: event.target.checked ? [] : ["conjunction", "opposition", "trine", "square", "sextile"] })} /><span>完整专业相位集</span><small>{allAspectIds.length}</small></label><div className="aspect-toggle-grid">{allAspectIds.map((aspect) => <button key={aspect} className={!settings.aspectIds.length || settings.aspectIds.includes(aspect) ? "on" : ""} onClick={() => { const base = settings.aspectIds.length ? settings.aspectIds : [...allAspectIds]; setSettings({ ...settings, aspectIds: base.includes(aspect) ? base.filter((id) => id !== aspect) : [...base, aspect] }); }}>{aspectNames[aspect] ?? aspect}</button>)}</div></fieldset>
              <button className="settings-calculate" onClick={() => openNewCalculation()}>用这些参数新建计算</button>
              <p className="settings-boundary">当前已支持专业点位组、汉堡虚星与扩展 Lots。固定星、任意小行星、平行/反平行与镜像相位在数据或算法卡不足时明确禁用，不会伪造为已计算。</p>
            </aside>}
          </div>

          <section className="result-section" id="natal-results">
            <div className="result-tabs">
              {(["basic", "signs", "houses", "aspects", "structure", "classical", "technical"] as ResultTab[]).map((item) => <button key={item} className={tab === item ? "active" : ""} onClick={() => setTab(item)}>{({ basic: "基本", signs: "星座", houses: "宫位", aspects: "相位", structure: "结构", classical: "古典", technical: "完整技术推演" })[item]}<small>{item === "basic" ? snapshot.result.points.length : item === "signs" ? signGroups.length : item === "houses" ? 12 : item === "aspects" ? snapshot.result.aspects.length : ""}</small></button>)}
            </div>

            {tab === "basic" && <div className="result-content">
              <div className="section-copy"><div><small>DIRECT CALCULATION</small><h2>星座、度数、宫位与运动状态</h2><p>这些结果由天文与占星规则直接计算。点击“解读”读取该点位的自身功能、星座表达、宫位领域与运动状态。</p></div><button onClick={() => setTab("technical")}>查看全部字段</button></div>
              <h3 className="table-group-title">十大行星</h3><div className="data-table"><div className="table-head"><span>星体</span><span>星座度数</span><span>宫位</span><span>运动</span><span>经纬度</span><span>操作</span></div>{corePoints.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id]}</b>{pointNames[point.point_id]}</span><span>{signNames[point.sign]} {formatDegree(point.degree_in_sign)}</span><span>第{point.house ?? "—"}宫</span><span className={point.retrograde ? "retrograde" : ""}>{point.retrograde ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"}</span><span>{point.position.ecliptic.longitude_deg.toFixed(4)}°<small>纬 {point.position.ecliptic.latitude_deg?.toFixed(3) ?? "—"}°</small></span><button onClick={() => openPoint(point)}>解读</button></div>)}</div>
              <h3 className="table-group-title">轴点、交点、小行星与阿拉伯点</h3><div className="data-table"><div className="table-head"><span>点位</span><span>星座度数</span><span>宫位</span><span>运动</span><span>类型</span><span>操作</span></div>{extendedPoints.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id] ?? "•"}</b>{pointNames[point.point_id] ?? point.point_id}</span><span>{signNames[point.sign]} {formatDegree(point.degree_in_sign)}</span><span>第{point.house ?? "—"}宫</span><span className={point.retrograde ? "retrograde" : ""}>{point.motion_interpretation === "not_applicable" ? "不适用" : point.retrograde ? "逆行" : "顺行"}</span><span>{point.kind}</span><button onClick={() => openPoint(point)}>解读</button></div>)}</div>
            </div>}

            {tab === "signs" && <div className="result-content"><div className="section-copy"><div><small>SIGN PLACEMENTS</small><h2>星座落点与表达方式</h2><p>星座由黄经直接换算。这里按星座聚合所有已选择点位，并保留每个点位的精确度数、宫位、运动状态和独立解读入口。</p></div></div><div className="sign-result-grid">{signGroups.map((group) => <article key={group.sign}><header><span>{signGlyphs[signIds.indexOf(group.sign)]}</span><div><b>{signNames[group.sign]}</b><small>{signStyles[group.sign]}</small></div><i>{group.points.length} 点</i></header><div>{group.points.map((point) => <button key={point.point_id} onClick={() => openPoint(point)}><span>{pointGlyphs[point.point_id] ?? "•"}</span><b>{pointNames[point.point_id] ?? point.point_id}</b><small>{formatDegree(point.degree_in_sign)} · 第{point.house ?? "—"}宫{point.retrograde ? " · 逆行" : ""}</small><i>解读</i></button>)}</div></article>)}</div></div>}

            {tab === "houses" && <div className="result-content"><div className="section-copy"><div><small>HOUSE CUSPS & RULERS</small><h2>十二宫宫头、宫主与宫内点位</h2><p>宫位依赖出生时间和地点；高纬度或时间不确定会返回警告，而不是默认 00:00。</p></div></div><div className="house-grid">{snapshot.result.houses.map((house, index) => <article key={house.number}><header><span>{house.number}</span><div><b>第{house.number}宫</b><small>{houseDomains[house.number - 1]}</small></div></header><dl><div><dt>宫头</dt><dd>{signNames[house.sign]} {formatDegree(house.degree_in_sign)}</dd></div><div><dt>跨度</dt><dd>{house.span_deg.toFixed(3)}°</dd></div><div><dt>传统宫主</dt><dd>{house.traditional_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>现代宫主</dt><dd>{house.modern_ruler_ids.map((id) => pointNames[id] ?? id).join("、") || "—"}</dd></div><div><dt>宫内点位</dt><dd>{house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}</dd></div></dl><button onClick={() => setTarget({ type: "house", id: String(house.number), title: `第${house.number}宫`, fact: `宫头 ${signNames[house.sign]} ${formatDegree(house.degree_in_sign)}，跨度 ${house.span_deg.toFixed(3)}°`, resultPath: `/result/houses/${index}` })}>解读宫位</button></article>)}</div></div>}

            {tab === "aspects" && <div className="result-content"><div className="section-copy"><div><small>PROFESSIONAL ASPECT SET</small><h2>完整本命相位表</h2><p>展示理论角度、实际角距、容许度、入出相和强度。平行/反平行与镜像相位在算法卡通过后以独立分组出现，不会混入黄经相位。</p></div><span className="count-chip">{snapshot.result.aspects.length} 条</span></div><div className="aspect-table"><div className="aspect-head"><span>点位 A</span><span>相位</span><span>点位 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span><span>操作</span></div>{snapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}<small>{aspect.exact_angle_deg.toFixed(3)}°</small></b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspect.applying_state}</span><span><i style={{ width: `${Math.round(aspect.strength * 100)}%` }} />{Math.round(aspect.strength * 100)}%</span><button onClick={() => openAspect(aspect)}>解读</button></div>)}</div></div>}

            {tab === "structure" && <div className="result-content"><div className="section-copy"><div><small>NATAL STRUCTURE</small><h2>元素、模式、半球、象限与几何格局</h2><p>描述性结构不等于人格分数；Jones 盘型等证据不足的能力会明确标记不可用或 Experimental。</p></div></div><div className="distribution-grid">{snapshot.result.distributions?.map((distribution) => <article key={distribution.dimension}><h3>{distribution.dimension}</h3>{distribution.categories.map((category) => { const max = Math.max(...distribution.categories.map((item) => item.count), 1); return <div key={category.category_id}><span>{category.category_id}</span><i><b style={{ width: `${category.count / max * 100}%` }} /></i><strong>{category.count}</strong></div>; })}</article>)}</div><div className="fact-card-grid">{structureEntries.map(([key, value]) => <article key={key}><header><b>{key}</b><button onClick={() => setTarget({ type: "structure", id: key, title: key, fact: toPlain(value) })}>解读</button></header><pre>{toPlain(value)}</pre></article>)}</div></div>}

            {tab === "classical" && <div className="result-content"><div className="section-copy"><div><small>CLASSICAL & HELLENISTIC CORE</small><h2>昼夜盘、尊贵、太阳状态、接纳、定位星与阿拉伯点</h2><p>古典模块按版本化规则表计算。Hayz、Almuten、综合尊贵分、物理可见性及福点/精神点以外的 Lots 尚未可靠实现。</p></div></div><div className="classical-summary"><div><small>昼夜盘</small><b>{String(snapshot.result.classical?.day_night_status ?? "—")}</b></div><div><small>本质尊贵</small><b>{snapshot.result.dignities?.length ?? 0}</b></div><div><small>接纳</small><b>{snapshot.result.receptions?.length ?? 0}</b></div><div><small>阿拉伯点</small><b>{snapshot.result.lots?.length ?? 0}</b></div></div><div className="fact-card-grid">{classicalEntries.map(([key, value]) => <article key={key}><header><b>{key}</b><button onClick={() => setTarget({ type: "classical", id: key, title: key, fact: toPlain(value) })}>解读</button></header><pre>{toPlain(value)}</pre></article>)}</div></div>}

            {tab === "technical" && <div className="result-content technical-layout">
              <div className="technical-main"><div className="section-copy"><div><small>PORTABLE TECHNICAL DOCUMENT</small><h2>完整专业技术推演</h2><p>覆盖输入、设置、天文上下文、全部点位、十二宫、完整相位、结构、古典事实、警告与版本信息。可直接复制给外部模型。</p></div><div className="document-actions"><button onClick={copyTechnical}>复制全文</button><button onClick={() => downloadTechnical("markdown")}>导出 .md</button><button onClick={() => downloadTechnical("plaintext")}>导出 .txt</button></div></div><textarea aria-label="完整本命盘技术推演" value={technicalDocument} onChange={(event) => setTechnicalDocument(event.target.value)} spellCheck={false} /></div>
              <aside className="ai-panel"><span>OPTIONAL AI CONNECTOR</span><h3>提交至 AI 分析</h3><p>AI 只接收已算好的技术文档，不负责计算星历、星座、宫位或相位。</p><label>服务商<select value={providerId} onChange={(event) => setProviderId(event.target.value as "openai" | "moonshot")}><option value="openai">GPT / OpenAI</option><option value="moonshot">Kimi / Moonshot</option></select></label><label>模型<select value={selectedProvider?.models[0]?.model_id ?? ""} disabled><option>{selectedProvider?.models[0]?.label ?? "未配置"}</option></select></label><label>分析重点（可选）<textarea value={aiFocus} onChange={(event) => setAiFocus(event.target.value)} placeholder="例如：优先分析职业结构与古典尊贵之间的关系" /></label><label className="consent-row"><input type="checkbox" checked={consent} onChange={(event) => setConsent(event.target.checked)} /><span>我同意将这份本命数据发送给所选第三方模型</span></label><button className="ai-submit" disabled={!selectedProvider?.configured || !consent || !snapshot.id.startsWith("calculation-")} onClick={submitAi}>提交至 {selectedProvider?.label}</button><div className="connector-status"><b>{selectedProvider?.configured ? "已配置" : "尚未配置"}</b><p>{selectedProvider?.blocking_reason ?? "等待后台提供方执行器。"}</p></div><button className="copy-fallback" onClick={copyTechnical}>没有 API？复制后自行提交</button></aside>
            </div>}
          </section>

          {snapshot.warnings.length > 0 && <section className="warning-panel"><h2>计算警告</h2>{snapshot.warnings.map((warning) => <p key={`${warning.code}-${warning.message}`}><b>{warning.code}</b>{warning.message}</p>)}</section>}
        </section>
      </div>

      {personModal && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setPersonModal(false); }}>
        <section className="person-modal" role="dialog" aria-modal="true" aria-label="新增人物">
          <header><div><span>SUBJECT LIBRARY</span><h2>新增人物</h2><p>这里只保存可复用的人物资料，不启动本命盘或任何其他计算。</p></div><button onClick={() => setPersonModal(false)} aria-label="关闭">×</button></header>
          <PersonFields person={person} onChange={setPerson} />
          <footer><button onClick={() => setPersonModal(false)}>取消</button><button className="calculate-button" onClick={savePersonOnly}>保存人物</button></footer>
        </section>
      </div>}

      {calculationModal && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setCalculationModal(false); }}>
        <section className="person-modal calculation-modal" role="dialog" aria-modal="true" aria-label="新建计算">
          <header><div><span>NEW CALCULATION</span><h2>新建计算</h2><p>{entryModes.find((entry) => entry.id === entryPoint)?.context}</p></div><button onClick={() => setCalculationModal(false)} aria-label="关闭">×</button></header>
          <section className="calculation-step"><div className="step-title"><span>1</span><div><b>选择计算方法</b><small>本命盘当前可运行；其他方法保留入口，但不返回假结果。</small></div></div><div className="calculation-techniques">{chartTechniques.map((technique) => <button key={technique.id} className={technique.status === "active" ? "active" : "planned"} onClick={() => technique.status === "active" ? undefined : setCapabilityTarget(technique)}><b>{technique.label}</b><small>{technique.outputs}</small><i>{technique.status === "active" ? "已选择" : "规划中"}</i></button>)}</div></section>
          <section className="calculation-step"><div className="step-title"><span>2</span><div><b>选择人物</b><small>可以选择本机人物，也可以直接填写仅用于本次计算的临时人物。</small></div></div>{savedPeople.length > 0 && <div className="subject-picker">{savedPeople.map((saved) => <button key={`${saved.displayName}:${saved.localDate}`} className={person.displayName === saved.displayName && person.localDate === saved.localDate ? "active" : ""} onClick={() => setPerson(saved)}><span>{saved.displayName.slice(0, 1)}</span><b>{saved.displayName}</b><small>{saved.localDate}</small></button>)}</div>}<details className="inline-person" open={!savedPeople.length || !person.displayName}><summary>{person.displayName ? `本次人物：${person.displayName}（展开编辑）` : "填写临时人物"}</summary><PersonFields person={person} onChange={setPerson} /></details></section>
          <section className="calculation-step"><div className="step-title"><span>3</span><div><b>确认规则与输出</b><small>改变计算参数会生成新的不可变 Snapshot；切换轮盘/相位图不会重算。</small></div></div><section className="modal-settings-summary"><div><small>占星方案</small><b>专业综合本命 v1</b></div><div><small>黄道</small><b>回归黄道</b></div><div><small>宫位制</small><b>{houseSystemOptions.find((item) => item.id === settings.houseSystem)?.label}</b></div><div><small>点位 / 相位</small><b>{Object.values(groups).filter(Boolean).length} 组 / {settings.aspectIds.length || allAspectIds.length} 种</b></div></section><label className="save-person"><input type="checkbox" checked={saveProfile} onChange={(event) => setSaveProfile(event.target.checked)} /><span><b>计算完成后保存临时人物</b><small>不勾选时仅用于本次计算；当前保存范围是本机浏览器。</small></span></label></section>
          <footer><button onClick={() => setCalculationModal(false)}>取消</button><button className="calculate-button" disabled={busy} onClick={calculateNatal}>{busy ? "正在计算全部本命事实…" : "计算完整本命盘"}</button></footer>
        </section>
      </div>}

      {analysisCenterOpen && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setAnalysisCenterOpen(false); }}><section className="person-modal analysis-center" role="dialog" aria-modal="true" aria-label="分析中心"><header><div><span>ANALYSIS CENTER</span><h2>六种分析入口</h2><p>入口只决定用户从哪里开始；后台仍生成可检查的计算配方，不会一次计算全部能力。</p></div><button onClick={() => setAnalysisCenterOpen(false)} aria-label="关闭">×</button></header><div className="entry-mode-grid">{entryModes.map((entry, index) => <article key={entry.id}><span>0{index + 1}</span><h3>{entry.title}</h3><p>{entry.description}</p><small>{entry.context}</small><button onClick={() => { setAnalysisCenterOpen(false); openNewCalculation(entry.id); }}>从此入口开始</button></article>)}</div></section></div>}

      {capabilityTarget && <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setCapabilityTarget(null); }}><section className="person-modal capability-modal" role="dialog" aria-modal="true" aria-label={`${capabilityTarget.label}能力说明`}><header><div><span>FUTURE CHART METHOD</span><h2>{capabilityTarget.label}</h2><p>已保留独立产品入口，当前本命盘完成前不开发此技法。</p></div><button onClick={() => setCapabilityTarget(null)} aria-label="关闭">×</button></header><div className="capability-detail"><dl><div><dt>状态</dt><dd>规划中 · 当前不可计算</dd></div><div><dt>所需输入</dt><dd>{capabilityTarget.inputs}</dd></div><div><dt>未来输出</dt><dd>{capabilityTarget.outputs}</dd></div><div><dt>原计划阶段</dt><dd>{capabilityTarget.stage}（现已暂停，等待本命盘完成后的用户决定）</dd></div></dl><p>这个入口不会打开本命盘弹窗，也不会返回示例结果。未来开发时会复用本命盘阶段完成的时间、星历、宫位、相位、轮盘、表格、解读和导出能力。</p></div><footer><button className="calculate-button" onClick={() => setCapabilityTarget(null)}>我知道了</button></footer></section></div>}
      {target && <InterpretationDrawer target={target} snapshot={snapshot} onClose={() => setTarget(null)} />}
    </main>
  );
}
