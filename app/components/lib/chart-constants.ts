import type {
  CalculationTab,
  CurrentSkyResultTab,
  EntryPointId,
  SecondaryResultTab,
  TechniqueId,
  TransitResultTab,
} from "./chart-types";
import type { NatalCalculationSettings, NatalPointGroups } from "../../lib/natal-presets";
import { cloneNatalPointGroups, cloneNatalSettings, natalCalculationPresets, timingCalculationPresets } from "../../lib/natal-presets";
import type { NatalRenderControls } from "../../lib/render-export";
import type { NatalAspect, NatalHouse, NatalPersonInput, NatalPoint, NatalSnapshot } from "../../lib/interstellar-api";

export const globalNavigation = ["工作台", "分析中心", "对象库"] as const;

export const entryModes: Array<{ id: EntryPointId; title: string; description: string; context: string }> = [
  { id: "technique", title: "技法排盘", description: "直接选择本命、行运、推运、返照等计算方法", context: "只加入所选技法的必需依赖，默认不添加专题解释。" },
  { id: "topic", title: "专题模型", description: "从职业、关系、财富、人格等专题模型进入", context: "专题锁定必要计算参数，只开放与主题相关的调整。" },
  { id: "intent", title: "分析目的", description: "从现实问题反推需要的对象、技法和输出", context: "先确认目的，再由预检生成可检查的计算配方。" },
  { id: "object", title: "对象快捷", description: "从人物、关系、项目、事件或组织开始", context: "预填当前对象，只展示该对象真正可执行的动作。" },
  { id: "personal", title: "时间与周期", description: "查看短期、年度和长期周期", context: "预填当前人物和时间范围，页面打开时不批量计算。" },
  { id: "context", title: "关系／项目／地点", description: "预填双人、项目或地点上下文", context: "缺少第二人物、事件时刻或目标地点时会明确阻断。" },
];

export const chartTechniques: Array<{ id: TechniqueId; label: string; status: "active" | "planned"; stage: string; inputs: string; outputs: string }> = [
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

export const calculationResultTabs: Array<{ id: CalculationTab; label: string }> = [
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

export const currentSkyResultTabs: Array<{ id: CurrentSkyResultTab; label: string }> = [
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

export const currentSkySharedResultTabs = new Set<CurrentSkyResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

export const secondaryResultTabs: Array<{ id: SecondaryResultTab; label: string }> = [
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

export const transitResultTabs: Array<{ id: TransitResultTab; label: string }> = [
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

export const transitSharedResultTabs = new Set<TransitResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

export const secondarySharedResultTabs = new Set<SecondaryResultTab>(
  ["features", "planets", "houses", "lots", "stars", "mirrors", "degrees", "rays", "midpoints"],
);

export const fallbackTimezoneOptions = [
  "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Taipei", "Asia/Tokyo", "Asia/Singapore",
  "Europe/London", "Europe/Paris", "America/New_York", "America/Chicago", "America/Los_Angeles", "Australia/Sydney",
];

export const fallbackPlaceOptions = [
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

export const houseSystemOptions: Array<{ id: NatalCalculationSettings["houseSystem"]; label: string }> = [
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

export const ayanamsaOptions: Array<{ id: NatalCalculationSettings["ayanamsa"]; label: string }> = [
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

export const pointNames: Record<string, string> = {
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

export const pointGlyphs: Record<string, string> = {
  sun: "☉", moon: "☽", mercury: "☿", venus: "♀", mars: "♂", jupiter: "♃", saturn: "♄",
  uranus: "♅", neptune: "♆", pluto: "♇", asc: "A", dsc: "D", mc: "M", ic: "I",
  true_north_node: "☊", true_south_node: "☋", mean_north_node: "☊", mean_south_node: "☋",
  chiron: "⚷", ceres: "⚳", pallas: "⚴", juno: "⚵", vesta: "⚶", fortune: "⊗", spirit: "◇",
  lot_eros: "E", lot_necessity: "N", lot_courage: "C", lot_victory: "V", lot_nemesis: "N", lot_exaltation: "X",
};

export const wheelPointLabels: Record<string, string> = {
  sun: "日", moon: "月", mercury: "水", venus: "金", mars: "火", jupiter: "木", saturn: "土",
  uranus: "天", neptune: "海", pluto: "冥", asc: "升", dsc: "降", mc: "顶", ic: "底",
  vertex: "宿", anti_vertex: "反", east_point: "东", west_point: "西", true_north_node: "北",
  true_south_node: "南", mean_north_node: "平北", mean_south_node: "平南", mean_lilith: "莉",
  true_lilith: "真莉", lunar_perigee: "近", chiron: "凯", ceres: "谷", pallas: "智", juno: "婚",
  vesta: "灶", fortune: "福", spirit: "灵", lot_eros: "爱", lot_necessity: "必", lot_courage: "勇",
  lot_victory: "胜", lot_nemesis: "报", lot_exaltation: "擢", cupido: "丘", hades: "哈", zeus: "宙",
  kronos: "克", apollon: "阿", admetos: "得", vulkanus: "弗", poseidon: "波",
};

export const signNames: Record<string, string> = {
  aries: "白羊", taurus: "金牛", gemini: "双子", cancer: "巨蟹", leo: "狮子", virgo: "处女",
  libra: "天秤", scorpio: "天蝎", sagittarius: "射手", capricorn: "摩羯", aquarius: "水瓶", pisces: "双鱼",
};
export const signGlyphs = ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"];
export const signIds = Object.keys(signNames);

export const aspectNames: Record<string, string> = {
  conjunction: "合相", opposition: "对冲", trine: "三分", square: "四分", sextile: "六分",
  semiduodecile: "半十二分", semioctile: "辅八分", semisextile: "半六分", semisquare: "半刑", sesquisquare: "拱半", quincunx: "梅花",
  quintile: "五分", biquintile: "双五分", novile: "九分", septile: "七分", biseptile: "双七分",
  triseptile: "三七分", undecile: "十一分", decile: "十分",
};

export const aspectPhaseNames: Record<string, string> = {
  applying: "入相",
  exact: "精确",
  separating: "出相",
  stationary: "停滞",
  unknown: "阶段未判定",
};

export const aspectMarks: Record<string, string> = {
  conjunction: "☌", opposition: "☍", trine: "△", square: "□", sextile: "✶", quincunx: "⚻",
  semisextile: "⚺", semisquare: "∠", sesquisquare: "⚼", quintile: "Q", biquintile: "bQ",
  novile: "N", septile: "S", biseptile: "bS", triseptile: "tS", undecile: "U", decile: "D",
};

export const lunarPhaseNames: Record<string, string> = {
  new_moon: "新月",
  waxing_crescent: "蛾眉月",
  first_quarter: "上弦月",
  waxing_gibbous: "盈凸月",
  full_moon: "满月",
  waning_gibbous: "亏凸月",
  last_quarter: "下弦月",
  waning_crescent: "残月",
};

export const pointGroups = {
  core: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"],
  angles: ["asc", "mc", "true_north_node", "true_south_node", "mean_lilith", "fortune", "spirit", "ic", "dsc", "vertex", "east_point"],
  lunar: ["mean_north_node", "mean_south_node", "true_lilith", "lunar_perigee", "anti_vertex", "west_point"],
  asteroids: ["chiron", "ceres", "pallas", "juno", "vesta", "pholus", "nessus", "chariklo", "asteroid_eros", "psyche", "eris", "sedna", "haumea", "makemake", "quaoar", "orcus", "ixion", "varuna", "astraea", "hygiea"],
  lots: ["lot_eros", "lot_necessity", "lot_courage", "lot_victory", "lot_nemesis", "lot_exaltation"],
  hamburg: ["cupido", "hades", "zeus", "kronos", "apollon", "admetos", "vulkanus", "poseidon"],
} as const;

export const unavailableVirtualPoints = [
  { id: "syzygy", reason: "需先锁定朔望事件搜索与采用的朔望定义" },
  { id: "zi_qi", reason: "尚无已核定的天文身份与计算公式" },
] as const;

export const majorAspectIds = ["conjunction", "opposition", "trine", "square", "sextile"];
export const professionalAspectIds = [
  ...majorAspectIds,
  "semisextile", "semisquare", "sesquisquare", "quincunx", "quintile", "biquintile",
];

export const pointGroupLabels: Record<keyof typeof pointGroups, string> = {
  core: "十大行星",
  angles: "虚点",
  lunar: "扩展敏感点",
  asteroids: "常用小行星",
  lots: "阿拉伯点",
  hamburg: "汉堡虚星",
};

export const orbPointClassOptions = [
  ["luminary", "日月"], ["planet", "行星"], ["dwarf_planet", "矮行星"],
  ["angle", "轴点"], ["node", "月交点"], ["lunar_point", "月球点"],
  ["asteroid", "小行星"], ["centaur", "半人马体"], ["lot", "阿拉伯点"],
  ["hypothetical", "虚拟点"], ["sensitive_point", "敏感点"],
] as const;

export const orbPointOptions = [...new Set(Object.values(pointGroups).flat())];

export const fixedStarOptions = [
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

export const pointKindNames: Record<string, string> = {
  planet: "行星",
  angle: "轴点",
  node: "月交点",
  lunar_point: "月球点",
  asteroid: "小行星",
  lot: "阿拉伯点",
  hamburg: "汉堡虚星",
  sensitive_point: "敏感点",
};

export const availabilityNames: Record<string, string> = {
  published: "已计算",
  available: "已计算",
  reference_fixture: "演示数据",
  experimental: "试验性结果",
  beta: "测试中",
  unavailable: "尚不可用",
  not_calculated: "尚未计算",
  blocked_by_input_quality: "输入条件不足",
};

export const statusNames: Record<string, string> = {
  published: "已识别",
  available: "已识别",
  reference_fixture: "演示数据",
  uncertain: "不确定",
  unavailable: "尚不可用",
  not_calculated: "尚未计算",
  not_published: "规则尚未发布",
};

export const allPointGroupsEnabled: Record<keyof typeof pointGroups, boolean> = {
  core: true, angles: true, lunar: true, asteroids: true, lots: true, hamburg: true,
};

export const defaultModernGroups: NatalPointGroups = cloneNatalPointGroups(natalCalculationPresets[0].groups);

export const defaultWheelGroups: Record<keyof typeof pointGroups, boolean> = {
  core: true, angles: true, lunar: true, asteroids: false, lots: false, hamburg: false,
};

export const defaultWheelControls: Omit<NatalRenderControls, "visiblePointIds"> = {
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

export const allAspectIds = [
  "conjunction", "semiduodecile", "semioctile", "semisextile", "undecile", "decile", "novile", "semisquare", "septile",
  "sextile", "quintile", "square", "biseptile", "trine", "sesquisquare", "biquintile", "quincunx", "triseptile", "opposition",
];

export const houseDomains = [
  "自我、身体与呈现", "金钱、资源与价值", "学习、表达与近距离环境", "家庭、根基与私人生活",
  "创造、恋爱与子女", "日常工作、技能与健康习惯", "伴侣、合作与公开关系", "共同资源、亲密与转化",
  "高等学习、信念与远行", "事业、目标与社会角色", "社群、人脉与长期愿景", "退隐、潜意识与幕后事务",
];

export const pointFunctions: Record<string, string> = {
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

export const signStyles: Record<string, string> = {
  aries: "直接、启动、竞争", taurus: "稳定、积累、感官", gemini: "交流、切换、好奇", cancer: "保护、情感、归属",
  leo: "创造、表现、中心感", virgo: "分析、改进、服务", libra: "协调、比较、关系", scorpio: "深入、控制、转化",
  sagittarius: "探索、信念、扩张", capricorn: "结构、责任、长期", aquarius: "独立、系统、群体", pisces: "感受、想象、融合",
};

export const dignityNames: Record<string, string> = {
  domicile: "入庙", exaltation: "擢升", triplicity: "三分性", term: "界", face: "十度区间／面",
  detriment: "失势", fall: "落陷", peregrine: "游走",
};

export const solarRelationNames: Record<string, string> = {
  cazimi: "日核", combust: "燃烧", under_beams: "光束下", free_of_beams: "脱离光束", self: "太阳本身", not_applicable: "不适用",
};

export const structureCategoryNames: Record<string, string> = {
  fire: "火", earth: "土", air: "风", water: "水",
  cardinal: "基本", fixed: "固定", mutable: "变动", positive: "阳性", negative: "阴性",
  east: "东方半球", west: "西方半球", above: "上半球", below: "下半球",
  quadrant_1: "第一象限", quadrant_2: "第二象限", quadrant_3: "第三象限", quadrant_4: "第四象限",
  angular: "角宫", succedent: "续宫", cadent: "果宫",
};

export const distributionNames: Record<string, string> = {
  elements: "四元素", modalities: "三模式", polarities: "阴阳属性",
};

export const patternNames: Record<string, string> = {
  grand_trine: "大三角", t_square: "T 三角", grand_cross: "大十字", yod: "Yod",
  kite: "风筝", mystic_rectangle: "神秘矩形", sign: "同星座群星", house: "同宫群星", longitude: "经度群星",
};

export const defaultSettings: NatalCalculationSettings = cloneNatalSettings(natalCalculationPresets[0].settings);
export const defaultTimingSettings: NatalCalculationSettings = cloneNatalSettings(timingCalculationPresets[0].settings);
export const defaultTimingGroups: NatalPointGroups = cloneNatalPointGroups(timingCalculationPresets[0].groups);

export const samplePoints: NatalPoint[] = [
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

export const sampleHouses: NatalHouse[] = Array.from({ length: 12 }, (_, index) => {
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

export const sampleAspects: NatalAspect[] = samplePoints.flatMap((left, leftIndex) =>
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

export const sampleSnapshot: NatalSnapshot = {
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

export const defaultPerson: NatalPersonInput = {
  displayName: "", relation: "self", localDate: "2000-03-01", localTime: "16:30", timezoneId: "Asia/Shanghai",
  timePrecision: "minute", placeName: "北京", countryCode: "CN", latitude: 39.93, longitude: 116.41,
  timeConfidence: "high", timezoneStatus: "resolved",
};
