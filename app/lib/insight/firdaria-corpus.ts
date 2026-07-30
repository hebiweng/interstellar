/**
 * 法达盘核心语料数据
 * 豁免：纯数据文件，条目结构统一，拆分破坏完整性
 * 语料库版本：V1.0
 * 本文件：类型定义、行星主题、昼夜起序、主/次运组合、宫位领域、
 *         转折规则、右侧展示语料
 */

// ─── 类型定义 ───────────────────────────────────────────────

export type CorpusEntry = {
  id: string;
  keywords: string;
  summary: string;
  detail: string;
  challenge?: string;
  advice?: string;
};

export type FirdariaCard = {
  id: string;
  icon: string;
  title: string;
  summary: string;
  details: string[];
  translation: string;
  action: string;
  caution: string;
};

export type FirdariaRightPanel = {
  cards: FirdariaCard[];
};

// ─── 一、行星主题语料 ──────────────────────────────────────

export const planetThemes: Record<string, CorpusEntry> = {
  sun: {
    id: "1-sun", keywords: "太阳主运、身份、意志、光芒",
    summary: "身份方向和自我意志正在成为这一阶段的核心驱动力。",
    detail: "太阳主运通常对应你在社会中寻求明确角色定位的阶段。你可能更在意「我想要成为什么样的人」，并为此采取主动行动。",
    challenge: "容易过度追求外界认可，或者忽略内在需求而只顾表面形象。健康方面需要关注心脏和活力。",
    advice: "找到真正让你感到有意义的目标，而非仅仅符合他人期待的方向。",
  },
  moon: {
    id: "1-moon", keywords: "月亮主运、情绪、安全感、内在需求",
    summary: "情绪需求和安全感是这个阶段最活跃的内在线索。",
    detail: "月亮主运往往伴随内在感受的强烈起伏。你对安全感的定义可能正在重新形成，家庭和亲密关系会成为焦点。",
    challenge: "情绪波动较大，容易因环境变化而感到不安。需要区分「真正需要的稳定」和「害怕改变的惯性」。",
    advice: "允许自己有情绪起伏，但重要决定最好等情绪平复后再做。照顾好自己的日常生活节奏。",
  },
  saturn: {
    id: "1-saturn", keywords: "土星主运、责任、结构、长期积累",
    summary: "责任感和现实结构正在塑造这个阶段的生活框架。",
    detail: "土星主运通常带来需要认真面对的现实课题。你可能会承担更大的责任，或被迫建立更稳固的生活结构。",
    challenge: "压力感较强，容易觉得进展缓慢或受限。这段时期的考验是为了让你建立更可持续的基础。",
    advice: "不回避困难，但要给自己合理的节奏。土星不奖励急躁，但会回报持续的努力。",
  },
  jupiter: {
    id: "1-jupiter", keywords: "木星主运、扩展、信念、机遇",
    summary: "扩展和机遇正在成为这个阶段的显著特征。",
    detail: "木星主运往往带来视野拓宽和机会增多的时期。你可能更愿意尝试新的方向，或感受到生活正在打开。",
    challenge: "机会多不代表每个都适合你。过度扩张可能导致资源分散，承诺太多反而难以兑现。",
    advice: "选择真正重要的方向深耕，而非试图抓住每一个可能性。",
  },
  mars: {
    id: "1-mars", keywords: "火星主运、行动、竞争、突破",
    summary: "行动力和突破意愿正在这个阶段明显增强。",
    detail: "火星主运通常对应需要主动推进或面对竞争的阶段。你可能感到精力充沛，也更愿意为自己的立场发声。",
    challenge: "冲动决策和急躁是最大的风险。与他人的冲突概率增加，需要学会选择战场。",
    advice: "把行动力用在已确认的目标上，而非被情绪驱动做出反应。运动或体力活动有助于释放过剩能量。",
  },
  venus: {
    id: "1-venus", keywords: "金星主运、关系、价值、享受",
    summary: "关系和价值正在成为这个阶段的重要关注点。",
    detail: "金星主运往往带来对亲密关系、审美体验和物质安全感的重视。你可能更愿意投入关系中，也更关注生活品质。",
    challenge: "过度追求舒适可能阻碍必要的调整。关系中的依赖倾向增强，需要保持独立判断。",
    advice: "在关系和价值选择中，区分「真正想要的」和「习惯觉得好的」。",
  },
  mercury: {
    id: "1-mercury", keywords: "水星主运、思维、沟通、学习",
    summary: "思维和沟通正在这个阶段变得更加活跃和关键。",
    detail: "水星主运通常对应学习、写作、交流频繁的时期。你可能更关注信息的获取和表达，也更容易在沟通中找到方向。",
    challenge: "思维容易过度活跃但缺乏聚焦，说得很多但真正落实的少。信息过多可能导致判断犹豫。",
    advice: "选定一个主题深入，比同时追踪多条线索更有效。",
  },
};

// ─── 二、昼夜起序规则 ──────────────────────────────────────

export const sectRules = {
  day: {
    id: "2-day", keywords: "昼盘、日生人、太阳起运",
    summary: "昼生人（日间出生），法达从太阳起运。",
    detail: "昼盘起序：太阳 → 金星 → 水星 → 月亮 → 土星 → 木星 → 火星。起运行星决定了前几年的人生基调。",
  },
  night: {
    id: "2-night", keywords: "夜盘、夜生人、月亮起运",
    summary: "夜生人（夜间出生），法达从月亮起运。",
    detail: "夜盘起序：月亮 → 土星 → 木星 → 火星 → 太阳 → 金星 → 水星。起运行星决定了前几年的人生基调。",
  },
};

// ─── 三、主/次运组合语料 ─────────────────────────────────

export const majorMinorCombinations: Record<string, CorpusEntry> = {
  "sun-moon": {
    id: "3-sun-moon", keywords: "日主月次、身份与情绪",
    summary: "身份方向与内在需求同时活跃，需要在两者之间找到节奏。",
    detail: "太阳推动你向外表达，月亮让你向内感受。这个组合常见于人生方向调整期。",
    advice: "在做重大身份选择时，先确认它是否真正回应了你的内在需求。",
  },
  "sun-saturn": {
    id: "3-sun-saturn", keywords: "日主土次、身份与责任",
    summary: "身份追求需要与现实条件匹配，耐心积累比急切行动更有效。",
    detail: "太阳想要表达自我，土星要求你先证明资格。这是一个需要务实推进的阶段。",
    advice: "把目标分解为可执行的步骤，用实际成果来确认方向。",
  },
  "sun-jupiter": {
    id: "3-sun-jupiter", keywords: "日主木次、身份与扩展",
    summary: "身份方向正在打开，机遇增多但需要聚焦。",
    detail: "木星为太阳的主题带来扩展空间，你可能发现新的可能性。",
    advice: "选择最契合核心方向的机会深入，而非试图同时推进所有可能。",
  },
  "moon-venus": {
    id: "3-moon-venus", keywords: "月主金次、情绪与关系",
    summary: "情感需求和关系互动同时活跃，亲密关系是重要线索。",
    detail: "月亮让你更敏感，金星让你更在意关系的品质。这个组合常见于感情和合作关系的关键调整期。",
    advice: "在关系中既照顾自己的感受，也留意对方的需求变化。",
  },
  "moon-saturn": {
    id: "3-moon-saturn", keywords: "月主土次、情绪与责任",
    summary: "内在情绪和现实责任之间存在张力，需要建立可持续的应对节奏。",
    detail: "月亮需要安全感，土星要求你先承担现实。这个组合可能带来情绪压力较大的阶段。",
    advice: "允许自己有低落时刻，但不让情绪完全驱动决策。维持基本的生活秩序很重要。",
  },
  "moon-jupiter": {
    id: "3-moon-jupiter", keywords: "月主木次、情绪与扩展",
    summary: "情绪体验正在打开，可能迎来内心视野的拓宽。",
    detail: "木星为月亮的情绪需求带来扩展空间，你可能更容易接纳新的感受方式。",
    advice: "利用这个阶段探索新的情感体验，但保持对边界的觉察。",
  },
  "saturn-mars": {
    id: "3-saturn-mars", keywords: "土主火次、责任与行动",
    summary: "现实框架需要行动力来推进，这是建立新结构的关键组合。",
    detail: "土星搭建结构，火星提供行动力。这个组合适合推进长期项目。",
    challenge: "容易感到被限制，同时又有强烈的突破冲动。协调两者需要节奏。",
    advice: "在土星的框架内，用火星的能量逐步推进，而非一次性突破所有障碍。",
  },
  "jupiter-venus": {
    id: "3-jupiter-venus", keywords: "木主金次、扩展与价值",
    summary: "生活正在打开，关系和物质都可能迎来正面发展。",
    detail: "木星的扩展力与金星的享受倾向结合，可能带来社交活跃和生活品质提升。",
    advice: "享受这个阶段的同时，留意不要过度扩张资源或承诺。",
  },
};

// ─── 四、右侧即时解读展示语料 ────────────────────────────────────

export const rightPanelDisplayCorpus = {
  currentPeriod: {
    majorFallback: "当前主运正在塑造这个阶段的人生主题。",
    minorFallback: "次运行星正在为当前主运添加具体色调。",
    combinationFallback: "主运和次运的组合正在共同影响这个阶段的节奏。",
  },
  transitionGuidance: {
    approaching: "你正在进入新的主运期，主题转换通常需要1\u20142个月的过渡。",
    midpoint: "你处于当前主运的中段，主题已经充分展开。",
    approachingEnd: "当前主运正在接近尾声，下一阶段的主题开始酝酿。",
  },
  adviceSlots: {
    period: { icon: "\u25C8", title: "当前周期" },
    combination: { icon: "\u21CC", title: "主次组合" },
    transition: { icon: "\u27D0", title: "阶段过渡" },
  },
  aspectTone: {
    structured: "这个阶段更强调结构和纪律，适合建立可持续的基础。",
    expansive: "这个阶段扩展感更强，适合探索新方向和打开视野。",
    active: "这个阶段行动力突出，适合推进具体事务和做出关键选择。",
    reflective: "这个阶段更偏向内省和感受，适合整理和消化经验。",
    steady: "这个阶段的节奏比较平稳，适合持续积累而不是大幅调整。",
  },
};
