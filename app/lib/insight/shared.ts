// 豁免：纯数据文件+共享工具，条目结构统一，拆分破坏完整性

import type { NatalAspect, NatalPoint } from "../interstellar-api";

// ── Shared types ──

export type ConsumerInsightDimension = {
  id: "action" | "emotion" | "expression" | "stability";
  label: string;
  score: number;
  note: string;
};

export type ConsumerInsight = {
  title: string;
  summary: string;
  dimensions: ConsumerInsightDimension[];
  aspectBalance: {
    supportive: number;
    tension: number;
    neutral: number;
    meaning: string;
  };
  signals: Array<{
    id: string;
    title: string;
    detail: string;
    meaning: string;
    strength: number;
  }>;
  strengths: string[];
  reminders: string[];
  closing: string;
};

export type InterpretationCard = {
  id: string;
  title: string;
  subtitle?: string;
  bullets: string[];
  emphasis?: string;
};

export type InterpretationSection = {
  id: string;
  label: string;
  cards: InterpretationCard[];
};

// ── Shared constants ──

export const elementBySign: Record<string, "fire" | "earth" | "air" | "water"> = {
  aries: "fire", leo: "fire", sagittarius: "fire",
  taurus: "earth", virgo: "earth", capricorn: "earth",
  gemini: "air", libra: "air", aquarius: "air",
  cancer: "water", scorpio: "water", pisces: "water",
};

export const pointLabels: Record<string, string> = {
  sun: "太阳", moon: "月亮", mercury: "水星", venus: "金星", mars: "火星",
  jupiter: "木星", saturn: "土星", uranus: "天王星", neptune: "海王星", pluto: "冥王星",
  asc: "上升", mc: "天顶", true_north_node: "北交点", mean_north_node: "北交点",
};

export const aspectLabels: Record<string, string> = {
  conjunction: "紧密相连", opposition: "彼此拉扯", trine: "自然配合", square: "互相较劲", sextile: "互相帮忙",
};

export const pointMeanings: Record<string, string> = {
  sun: "想做自己、主动拿主意",
  moon: "情绪反应和安全感",
  mercury: "思考、说话和理解信息",
  venus: "喜欢什么、怎样与人亲近",
  mars: "行动、竞争和表达不满",
  jupiter: "信心、成长和打开眼界",
  saturn: "责任、规则和长期坚持",
  uranus: "变化、独立和打破惯例",
  neptune: "想象、共情和理想化",
  pluto: "控制感、深层改变和重新开始",
  asc: "给人的第一印象和起步方式",
  mc: "公开形象和想达成的目标",
  true_north_node: "容易把人带向新经验的方向",
  mean_north_node: "容易把人带向新经验的方向",
};

export const supportiveAspectIds = new Set(["trine", "sextile"]);
export const tensionAspectIds = new Set(["square", "opposition", "quincunx", "semisquare", "sesquisquare"]);

export const signLabels: Record<string, string> = {
  aries: "白羊座", taurus: "金牛座", gemini: "双子座", cancer: "巨蟹座",
  leo: "狮子座", virgo: "处女座", libra: "天秤座", scorpio: "天蝎座",
  sagittarius: "射手座", capricorn: "摩羯座", aquarius: "水瓶座", pisces: "双鱼座",
};

export const signThemes: Record<string, string> = {
  aries: "强调启动、行动和抢先一步",
  taurus: "强调稳定、价值和逐步落实",
  gemini: "强调沟通、信息和多角度尝试",
  cancer: "强调情绪、照顾和安全感",
  leo: "强调表达、创造和获得关注",
  virgo: "强调整理、服务和完善细节",
  libra: "强调关系、平衡和合作",
  scorpio: "强调深入、转化和掌控",
  sagittarius: "强调探索、信念和扩展视野",
  capricorn: "强调目标、责任和长期积累",
  aquarius: "强调独立、变化和群体视角",
  pisces: "强调共情、想象和边界消融",
};

export const houseLabels: Record<number, string> = {
  1: "自我、形象和出发方式", 2: "价值、资源和安全感", 3: "沟通、学习和日常",
  4: "家庭、根基和情绪", 5: "创造、玩乐和恋爱", 6: "工作、健康和习惯",
  7: "关系、合作和伴侣", 8: "共有资源、转化和危机", 9: "远行、信念和高等教育",
  10: "事业、公共形象和成就", 11: "社群、未来和理想", 12: "内在、释放和潜意识",
};

export const pointThemes: Record<string, string> = {
  sun: "核心意志和自我表达", moon: "情绪需求和安全感", mercury: "思考和沟通方式",
  venus: "关系和价值观", mars: "行动和冲动", jupiter: "成长和信念",
  saturn: "责任和限制", uranus: "变化和突破", neptune: "想象和理想化",
  pluto: "深层转化", asc: "外在形象和起点", mc: "事业和公共目标",
  true_north_node: "成长方向", mean_north_node: "成长方向",
};

export const aspectThemes: Record<string, string> = {
  conjunction: "两颗星的功能正在融合，主题会叠加",
  sextile: "有机会互相配合，但需要主动迈出一步",
  square: "两边有张力，需要调整节奏",
  trine: "能量顺畅，容易自然发挥",
  opposition: "对立的两边需要整合，常体现在关系或外部事件中",
  quincunx: "难以直接协调，需要弹性和变通",
  semisextile: "相邻但主题不同，需要磨合",
  semisquare: "轻微摩擦，容易带来急躁或紧张",
  sesquisquare: "持续压力，需要找到释放口",
};

// ── Shared helpers ──

export function clampScore(value: number) {
  return Math.max(18, Math.min(92, Math.round(value)));
}

export function aspectWeight(aspect: NatalAspect) {
  const participantWeight = [aspect.point_a, aspect.point_b].reduce((weight, pointId) => {
    if (pointId === "sun" || pointId === "moon" || pointId === "asc" || pointId === "mc") return weight + 1.4;
    if (["mercury", "venus", "mars"].includes(pointId)) return weight + 1.2;
    if (["jupiter", "saturn"].includes(pointId)) return weight + 1;
    if (["uranus", "neptune", "pluto"].includes(pointId)) return weight + 0.8;
    return weight + 0.6;
  }, 0) / 2;
  const phaseWeight = aspect.applying_state === "exact"
    ? 1
    : aspect.applying_state === "applying"
      ? 0.9
      : aspect.applying_state === "separating"
        ? 0.7
        : 0.8;
  return aspect.strength * participantWeight * phaseWeight;
}

export function dimensionMeaning(id: ConsumerInsightDimension["id"], score: number, mode: "natal" | "current_sky") {
  const level = score >= 70 ? "high" : score >= 48 ? "medium" : "low";
  const natal: Record<ConsumerInsightDimension["id"], Record<typeof level, string>> = {
    action: {
      high: "遇到事情时更容易先行动、先试一遍。优点是推进快，忙起来时要记得给自己留出判断的时间。",
      medium: "通常能在观察和行动之间找到节奏，确定方向后会比较愿意往前推。",
      low: "比起马上出手，你更习惯先想清楚、等条件合适。慢一点不等于没行动力，准备充分时反而更稳。",
    },
    emotion: {
      high: "对气氛和他人的反应比较敏感，感受丰富，也更需要被理解。情绪满的时候，先缓一缓再回应会更舒服。",
      medium: "能感受到情绪变化，也通常能把它放回现实中处理，不容易一直被一种感受困住。",
      low: "处理事情时更倾向讲方法和结果，不一定会马上说出感受。把真实需要讲明白，别人会更容易靠近你。",
    },
    expression: {
      high: "脑子转得快，也愿意通过说、写或交流把事情理清。信息太多时容易分心，抓住一个重点会更有力量。",
      medium: "大多数时候能把想法说明白，也愿意先听再回应，沟通方式比较灵活。",
      low: "不喜欢为了说而说，更倾向想成熟后再开口。重要场合提前组织一下语言，会让表达更轻松。",
    },
    stability: {
      high: "重视可靠、可持续和看得见的进展，适合把复杂事情一步步做完。偶尔也要允许计划被现实调整。",
      medium: "既能顾到现实，也愿意在必要时改变做法，稳定和弹性比较均衡。",
      low: "比起固定流程，你更容易被新鲜感和可能性带动。把目标拆成小步骤，想法会更容易真正落地。",
    },
  };
  const sky: typeof natal = {
    action: {
      high: "这个时段整体节奏偏快，适合启动、推进和把话说开；也容易因为着急而少想一步。",
      medium: "这个时段既有行动空间，也留得出观察余地，适合边做边调整。",
      low: "这个时段更适合准备、复盘和等信息明朗，不必强行追求立刻见效。",
    },
    emotion: {
      high: "这个时段人们更容易被气氛带动，感受会放大。重要回应最好先确认事实，再处理情绪。",
      medium: "情绪有存在感但不至于淹没事情本身，适合把感受和现实需要一起说清楚。",
      low: "这个时段更偏理性和事务处理，感受可能被放到后面，沟通时别忘了照顾人的接受方式。",
    },
    expression: {
      high: "信息交换明显加快，适合讨论、写作和整理方案；消息过多时要主动筛选重点。",
      medium: "沟通节奏比较平稳，适合把复杂问题拆开谈，也适合边听边修正。",
      low: "信息推进相对慢，结论可能需要多一点时间沉淀，重要决定不必被催着做。",
    },
    stability: {
      high: "这个时段更容易关注现实结果、规则和长期安排，适合收尾、规划和处理具体问题。",
      medium: "稳定和变化都有空间，既能守住基本安排，也能对新情况作出调整。",
      low: "变化感比确定感更强，计划需要留有余地；先抓住最重要的一件事会更稳。",
    },
  };
  return (mode === "natal" ? natal : sky)[id][level];
}

export function signalMeaning(aspect: NatalAspect, mode: "natal" | "current_sky") {
  const left = pointMeanings[aspect.point_a] ?? "一种需要";
  const right = pointMeanings[aspect.point_b] ?? "另一种需要";
  const subject = mode === "natal" ? "你" : "这个时段";
  if (aspect.type === "trine" || aspect.type === "sextile") {
    return `${subject}在"${left}"和"${right}"之间比较容易找到配合。顺手并不等于自动发生，主动用起来才会变成真正的优势。`;
  }
  if (aspect.type === "square" || aspect.type === "opposition" || ["quincunx", "semisquare", "sesquisquare"].includes(aspect.type)) {
    return `${subject}会在"${left}"和"${right}"之间感到拉扯：顾到一边时，另一边容易不满意。它会制造压力，也会推动人寻找更成熟的处理办法。`;
  }
  if (aspect.type === "conjunction") {
    return `${subject}很难把"${left}"和"${right}"完全分开，两件事常常一起出现、彼此放大。用得好会很集中，过头时也容易只听见一个声音。`;
  }
  return `${subject}需要同时处理"${left}"和"${right}"。先看清两边各自要什么，会比急着下结论更有帮助。`;
}

export function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

export function pointNarrative(point: NatalPoint, prefix = ""): string {
  const pointName = pointLabels[point.point_id] ?? point.point_id;
  const sign = signLabels[point.sign] ?? point.sign;
  const signTheme = signThemes[point.sign] ?? "强调当前主题";
  const house = point.house ? `第${point.house}宫（${houseLabels[point.house]}）` : "";
  const retro = point.retrograde ? "当前逆行，相关主题适合先回顾、再推进。" : "";
  return `${prefix}${pointName}落在${sign}${house ? "，" + house : ""}，${signTheme}。${retro}`;
}

export function aspectNarrative(aspect: NatalAspect, prefix = ""): string {
  const a = pointLabels[aspect.point_a] ?? aspect.point_a;
  const b = pointLabels[aspect.point_b] ?? aspect.point_b;
  const typeTheme = aspectThemes[aspect.type] ?? "形成联系";
  const phase = aspect.applying_state === "applying" ? "正在增强" : aspect.applying_state === "exact" ? "正在精确" : aspect.applying_state === "separating" ? "正在减弱" : "当前阶段较平稳";
  return `${prefix}${a}与${b}${typeTheme}。影响${phase}，容许度 ${aspect.orb_deg.toFixed(2)}°。`;
}

export function crossAspectNarrative(aspect: NatalAspect & { moving_point_id: string; reference_point_id: string }, context: "transit" | "progression"): string {
  const moving = pointLabels[aspect.moving_point_id] ?? aspect.moving_point_id;
  const ref = pointLabels[aspect.reference_point_id] ?? aspect.reference_point_id;
  const typeTheme = aspectThemes[aspect.type] ?? "形成联系";
  const phase = aspect.applying_state === "applying" ? "正在接近" : aspect.applying_state === "exact" ? "正在精确触发" : aspect.applying_state === "separating" ? "正在离开" : "当前阶段较平稳";
  const contextPrefix = context === "progression" ? "次限" : "行运";
  return `${contextPrefix}${moving}正在${phase}你命中的${ref}，${typeTheme}。`;
}

export function houseNarrative(pointId: string, houseNumber: number, context: "current_sky" | "transit" | "progression"): string {
  const pointName = pointLabels[pointId] ?? pointId;
  const house = houseLabels[houseNumber] ?? `第${houseNumber}宫`;
  const prefix = context === "current_sky" ? "" : context === "transit" ? "行运" : "次限";
  return `${prefix}${pointName}的行程正把你的注意力带到${house}领域。`;
}
