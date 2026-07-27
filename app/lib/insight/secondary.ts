// Secondary progression interpretation logic
// Types + buildSecondaryProgressionConsumerInsight + buildSecondaryProgressionRightPanel + buildSecondaryProgressionInterpretationSections

import type { ChartComparison, NatalSnapshot, SecondaryProgressionResult } from "../interstellar-api";
import {
  type ConsumerInsight,
  type InterpretationCard,
  type InterpretationSection,
  pointLabels, aspectLabels, signLabels, houseLabels,
  supportiveAspectIds, tensionAspectIds,
  clampScore, aspectWeight, dimensionMeaning, signalMeaning,
  asRecord, pointNarrative, aspectNarrative, crossAspectNarrative, houseNarrative,
} from "./shared";
import { moonSignPhases, sunSignPhases, lunarPhaseCorpus, houseCorpus, stageTransitions, keyNodes, natalLinkRules } from "./secondary-corpus";
import { moonNatalCombinations, planetNatalCombinations, outerPlanetCombinations } from "./secondary-corpus-combinations";

// ── Right-panel card types ──

export type SecondaryProgressionCard = {
  id: string;
  icon: string;
  title: string;
  summary: string;
  details: string[];
};

export type SecondaryProgressionRightPanel = {
  cards: SecondaryProgressionCard[];
};

// ── Helper: resolve phase key from angle ──

function lunarPhaseKey(angle: number): string {
  if (angle < 90) return "new";
  if (angle < 180) return "first_quarter";
  if (angle < 270) return "full";
  return "last_quarter";
}

// ── Helper: lunar phase info from corpus ──

function lunarPhaseInfo(snapshot: NatalSnapshot): { phase: string; phaseLabel: string; meaning: string; phaseKey: string } {
  const ctx = asRecord(snapshot.result.astronomical_context);
  const lp = asRecord(ctx.lunar_phase);
  const angle = Number(lp.angle ?? lp.elongation_deg ?? 0);
  const phaseKey = lunarPhaseKey(angle);
  const phaseNames: Record<string, string> = { new: "新月期", first_quarter: "上弦期", full: "满月期", last_quarter: "下弦期" };
  const phase = phaseNames[phaseKey] ?? "新月期";
  const corpus = lunarPhaseCorpus[phaseKey];
  const phaseLabel = corpus?.summary?.split("，")[0] ?? "";
  const meaning = corpus ? `${phase}（约持续7—8年）：${corpus.summary}` : `${phase}（约持续7—8年）`;
  return { phase, phaseLabel, meaning, phaseKey };
}

// ── buildSecondaryProgressionConsumerInsight ──
// Legacy ConsumerInsight-based insight for bottom tab

export function buildSecondaryProgressionConsumerInsight(
  result: SecondaryProgressionResult,
  _latestNatalSnapshot: NatalSnapshot,
): ConsumerInsight {
  const progressed = result.progressed_snapshot;
  const comparison = result.comparison;

  // Reuse natal dimension scoring on the progressed snapshot
  const corePoints = progressed.result.points.filter((point) =>
    ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"].includes(point.point_id)
  );
  const elementCounts = { fire: 0, earth: 0, air: 0, water: 0 };
  for (const point of corePoints) {
    const element = { aries: "fire", leo: "fire", sagittarius: "fire", taurus: "earth", virgo: "earth", capricorn: "earth", gemini: "air", libra: "air", aquarius: "air", cancer: "water", scorpio: "water", pisces: "water" }[point.sign];
    if (element) elementCounts[element as keyof typeof elementCounts] += point.point_id === "sun" || point.point_id === "moon" ? 2 : 1;
  }
  const totalElements = Math.max(1, Object.values(elementCounts).reduce((sum, count) => sum + count, 0));
  const elementScore = (element: keyof typeof elementCounts) => 34 + elementCounts[element] / totalElements * 96;

  const weightedAspects = progressed.result.aspects.map((aspect) => ({
    aspect,
    weight: aspectWeight(aspect),
  }));
  const involvement = (pointIds: string[]) => weightedAspects
    .filter(({ aspect }) => pointIds.includes(aspect.point_a) || pointIds.includes(aspect.point_b))
    .reduce((sum, item) => sum + item.weight, 0);
  const supportiveTotal = weightedAspects
    .filter(({ aspect }) => supportiveAspectIds.has(aspect.type))
    .reduce((sum, item) => sum + item.weight, 0);
  const tensionTotal = weightedAspects
    .filter(({ aspect }) => tensionAspectIds.has(aspect.type))
    .reduce((sum, item) => sum + item.weight, 0);
  const balanceAdjustment = Math.max(-10, Math.min(10, (supportiveTotal - tensionTotal) * 1.8));

  const dimensionScores = [
    { id: "action" as const, label: "行动推进", score: clampScore(elementScore("fire") + Math.min(14, involvement(["mars", "sun"]) * 2) + balanceAdjustment) },
    { id: "emotion" as const, label: "情绪感受", score: clampScore(elementScore("water") + Math.min(14, involvement(["moon", "venus"]) * 2)) },
    { id: "expression" as const, label: "沟通表达", score: clampScore(elementScore("air") + Math.min(14, involvement(["mercury", "asc"]) * 2) + balanceAdjustment / 2) },
    { id: "stability" as const, label: "稳定建设", score: clampScore(elementScore("earth") + Math.min(14, involvement(["saturn", "jupiter"]) * 2) - balanceAdjustment / 2) },
  ];
  const dimensions = dimensionScores.map((d) => ({ ...d, note: dimensionMeaning(d.id, d.score, "current_sky") }));

  const strongestDimension = [...dimensions].sort((a, b) => b.score - a.score)[0];
  const aspectCounts = weightedAspects.reduce((balance, item) => {
    if (supportiveAspectIds.has(item.aspect.type)) balance.supportive += 1;
    else if (tensionAspectIds.has(item.aspect.type)) balance.tension += 1;
    else balance.neutral += 1;
    return balance;
  }, { supportive: 0, tension: 0, neutral: 0 });

  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const top = cross.slice(0, 5);
  const houses = [...comparison.result.moving_points_in_reference_houses]
    .filter((h) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(h.moving_point_id))
    .slice(0, 6);
  const progressedMoon = progressed.result.points.find((p) => p.point_id === "moon");
  const progressedSun = progressed.result.points.find((p) => p.point_id === "sun");

  const movingLabel = (id: string) => pointLabels[id] ?? id;
  const refLabel = (id: string) => pointLabels[id] ?? id;
  const aspectLabel = (type: string) => aspectLabels[type] ?? type;
  const houseDomain = (n: number) => {
    const domains = ["自我与起点", "价值与资源", "交流与日常", "家庭与根基", "创造与表达", "工作与健康", "关系与伴侣", "共有资源与转化", "远行与信念", "事业与公共形象", "社群与未来", "内在与释放"];
    return domains[n - 1] ?? `第${n}宫`;
  };

  const title = progressedMoon
    ? `次限月亮在${progressedMoon.sign}，推进你的情绪节奏`
    : top.length > 0
      ? `次限${movingLabel(top[0].moving_point_id)}${aspectLabel(top[0].type)}本命${refLabel(top[0].reference_point_id)}`
      : "次限盘正在缓慢推进你的生命主题";

  const summary = progressedMoon
    ? `次限月亮 moved into ${progressedMoon.sign}，代表你内在的情绪需求和反应方式正在经历一段较长期的调整。它不会制造突发事件，而是悄悄改变你看待关系和安全感的方式。`
    : `${strongestDimension.label}是这个时段最明显的倾向。它描述公共天空的节奏，不代表每个人都会发生同一件事。`;

  const signals: ConsumerInsight["signals"] = [];

  if (progressedMoon) {
    signals.push({
      id: "progressed-moon",
      title: `次限月亮在${progressedMoon.sign}`,
      detail: "情绪基调正在转变",
      meaning: `次限月亮走到${progressedMoon.sign}，接下来一段时间你的情绪需求和被照顾的方式会偏向这个星座的特质。`,
      strength: 88,
    });
  }

  const topSignals = top.slice(0, 3).map((aspect) => {
    const moving = movingLabel(aspect.moving_point_id);
    const reference = refLabel(aspect.reference_point_id);
    const phase = aspect.applying_state === "exact" ? "目前非常聚焦" : aspect.applying_state === "applying" ? "影响正在深化" : "影响正在过去";
    const templates: Record<string, string> = {
      conjunction: `次限${moving}合相本命${reference}：内在节奏正在与你的核心主题重合，这是长期转化较明显的阶段。`,
      trine: `次限${moving}三分本命${reference}：内在发展顺着你本命的资源走，适合顺势而为。`,
      sextile: `次限${moving}六分本命${reference}：有机会出现，但需要你先跨出一小步。`,
      square: `次限${moving}刑克本命${reference}：内在成长与外部结构之间会有张力，需要调整节奏。`,
      opposition: `次限${moving}对冲本命${reference}：关系或外部事件会让你看见对立的两边，需要整合。`,
    };
    return {
      id: aspect.aspect_id,
      title: `次限${moving} ${aspectLabel(aspect.type)} 本命${reference}`,
      detail: phase,
      meaning: templates[aspect.type] ?? `次限${moving}正在${aspectLabel(aspect.type)}你的本命${reference}：这是长期推进中值得关注的线索。`,
      strength: Math.round(aspect.strength * 100),
    };
  });
  signals.push(...topSignals);

  if (houses.length > 0) {
    const h = houses[0];
    signals.push({
      id: `house-${h.moving_point_id}`,
      title: `次限${movingLabel(h.moving_point_id)}进入本命第${h.reference_house}宫`,
      detail: h.on_cusp ? "贴近宫头，主题更明显" : "长期影响这个领域",
      meaning: `次限${movingLabel(h.moving_point_id)}正在经过你的本命第${h.reference_house}宫（${houseDomain(h.reference_house)}），这是长期被点亮的生命领域。`,
      strength: h.on_cusp ? 92 : 70,
    });
  }

  const strengths = progressedMoon
    ? [`次限月亮在${progressedMoon.sign}，情绪节奏与这个星座的特质更合拍。`]
    : [`${strongestDimension.label}比较突出。把它用在合适的事情上，你更容易进入状态，也更容易让别人理解你的长处。`];

  const reminders = [
    progressedSun ? `次限太阳在${progressedSun.sign}，长期目标和自我表达的方向正在转向这个星座的特质。` : "次限盘反映的是长期趋势，不是单一日期的突发事件。",
    "次限的变化通常以年为单位，给它一些时间，观察主题如何展开。",
  ];

  const balanceMeaning = aspectCounts.tension > aspectCounts.supportive
    ? "需要协调的事情比较多，推进时容易遇到不同方向的要求。先排优先级，比同时满足所有人更有效。"
    : aspectCounts.supportive > aspectCounts.tension
      ? "不同力量比较容易配合，适合沟通、整合资源和把已有计划往前推。"
      : "顺势与压力比较均衡，边做边看会更稳。";

  return {
    title,
    summary,
    dimensions,
    aspectBalance: { ...aspectCounts, meaning: balanceMeaning },
    signals: signals.slice(0, 4),
    strengths,
    reminders,
    closing: "次限盘像一条慢速播放的成长线。它不会说今天会发生什么，但能说明你现在处在哪一段长期主题里。",
  };
}

// ── buildSecondaryProgressionRightPanel ──
// Corpus-driven 5-card right panel

export function buildSecondaryProgressionRightPanel(
  result: SecondaryProgressionResult,
  natalSnapshot: NatalSnapshot,
): SecondaryProgressionRightPanel {
  const progressed = result.progressed_snapshot;
  const comparison = result.comparison;
  const cards: SecondaryProgressionCard[] = [];

  // ── Card A: 当前人生阶段 ──
  const pMoon = progressed.result.points.find(p => p.point_id === "moon");
  const pSun = progressed.result.points.find(p => p.point_id === "sun");
  const moonSign = pMoon?.sign ?? "";
  const sunSign = pSun?.sign ?? "";
  const phaseInfo = lunarPhaseInfo(progressed);

  const cardADetails: string[] = [];
  if (pMoon) {
    const moonCorpus = moonSignPhases[moonSign];
    cardADetails.push(moonCorpus ? moonCorpus.summary : `次限月亮在${signLabels[moonSign] ?? moonSign}`);
  }
  if (pSun) {
    const sunCorpus = sunSignPhases[sunSign];
    cardADetails.push(sunCorpus ? sunCorpus.summary : `次限太阳在${signLabels[sunSign] ?? sunSign}`);
  }
  const lpCorpus = lunarPhaseCorpus[phaseInfo.phaseKey];
  cardADetails.push(lpCorpus ? lpCorpus.summary : phaseInfo.meaning);
  cards.push({
    id: "current-stage",
    icon: "◐",
    title: "当前人生阶段",
    summary: pMoon ? (moonSignPhases[moonSign]?.summary ?? `次限月亮在${signLabels[moonSign] ?? moonSign}`) : "次限盘正在推进",
    details: cardADetails,
  });

  // ── Card B: 长期变化主题 ──
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const topCross = cross.slice(0, 3);
  const cardBDetails: string[] = [];
  if (pMoon && pMoon.house) {
    const hc = houseCorpus[String(pMoon.house)];
    cardBDetails.push(hc ? hc.summary : `情绪关注点：本命第${pMoon.house}宫`);
  }
  if (pSun && pSun.house) {
    const hc = houseCorpus[String(pSun.house)];
    cardBDetails.push(hc ? `身份方向：${hc.summary}` : `身份方向：本命第${pSun.house}宫`);
  }
  for (const aspect of topCross) {
    const moving = pointLabels[aspect.moving_point_id] ?? aspect.moving_point_id;
    const ref = pointLabels[aspect.reference_point_id] ?? aspect.reference_point_id;
    const typeLabel = aspectLabels[aspect.type] ?? aspect.type;
    const combKey = `${aspect.moving_point_id}-${aspect.reference_point_id}`;
    const combCorpus = moonNatalCombinations[combKey] ?? planetNatalCombinations[combKey] ?? outerPlanetCombinations[combKey];
    const aspectText = combCorpus?.aspects?.[aspect.type] ?? `${moving} ${typeLabel} ${ref}`;
    const stateLabel = aspect.applying_state === "exact" ? "正在精确" : aspect.applying_state === "applying" ? "正在增强" : "正在减弱";
    cardBDetails.push(`${aspectText}（${stateLabel}）`);
  }
  let cardBSummary = "次限行星正在缓慢推进";
  if (topCross.length > 0 && topCross[0]) {
    const topA = topCross[0];
    const combKey = `${topA.moving_point_id}-${topA.reference_point_id}`;
    const comb = moonNatalCombinations[combKey] ?? planetNatalCombinations[combKey] ?? outerPlanetCombinations[combKey];
    cardBSummary = comb ? comb.meaning : `次限${pointLabels[topA.moving_point_id] ?? topA.moving_point_id}正在激活本命${pointLabels[topA.reference_point_id] ?? topA.reference_point_id}`;
  }
  cards.push({
    id: "change-themes",
    icon: "◈",
    title: "长期变化主题",
    summary: cardBSummary,
    details: cardBDetails,
  });

  // ── Card C: 核心转折点 ──
  const cardCDetails: string[] = [];
  if (pMoon && pMoon.degree_in_sign < 3) {
    const sprout = stageTransitions.sprout;
    cardCDetails.push(sprout ? sprout.summary : `次限月亮刚进入${signLabels[moonSign] ?? moonSign}，换座过渡期约6—12个月。`);
  } else if (pMoon && pMoon.degree_in_sign > 27) {
    const crossInfo = stageTransitions.signCross;
    cardCDetails.push(crossInfo ? crossInfo.summary : `次限月亮即将离开当前星座。`);
  }
  if (pSun && pSun.degree_in_sign < 2) {
    const sunChange = keyNodes.sunSignChange;
    cardCDetails.push(sunChange ? sunChange.summary : `次限太阳刚进入${signLabels[sunSign] ?? sunSign}，身份方向正在长期调整。`);
  }
  const exactAspects = cross.filter(a => a.applying_state === "exact");
  for (const aspect of exactAspects.slice(0, 2)) {
    const moving = pointLabels[aspect.moving_point_id] ?? aspect.moving_point_id;
    const ref = pointLabels[aspect.reference_point_id] ?? aspect.reference_point_id;
    cardCDetails.push(`次限${moving}精确${aspectLabels[aspect.type] ?? aspect.type}本命${ref}，当前转折信号最强。`);
  }
  const lpAngle = Number(asRecord(progressed.result.astronomical_context).lunar_phase?.angle ?? asRecord(progressed.result.astronomical_context).lunar_phase?.elongation_deg ?? 0);
  if (lpAngle < 5 || Math.abs(lpAngle - 90) < 5 || Math.abs(lpAngle - 180) < 5 || Math.abs(lpAngle - 270) < 5) {
    const phaseCross = stageTransitions.phaseCross;
    cardCDetails.push(phaseCross ? phaseCross.summary : `次限月相正处于${phaseInfo.phase}的起始阶段，内在节奏正在转换。`);
  }
  if (cardCDetails.length === 0) {
    const quiet = stageTransitions.quietPeriod;
    cardCDetails.push(quiet ? quiet.summary : "当前没有特别集中的次限转折信号，内在节奏相对平稳。");
  }
  cards.push({
    id: "turning-points",
    icon: "⟐",
    title: "核心转折点",
    summary: cardCDetails.length > 0 ? cardCDetails[0].split("，")[0] : "当前阶段较平稳",
    details: cardCDetails,
  });

  // ── Card D: 阶段建议 ──
  const cardDDetails: string[] = [];
  if (pMoon) {
    const moonCorpus = moonSignPhases[moonSign];
    const moonHouse = pMoon.house;
    if (moonHouse) {
      const hc = houseCorpus[String(moonHouse)];
      cardDDetails.push(hc ? `情绪关注领域：${hc.summary}` : `情绪关注领域：本命第${moonHouse}宫`);
    }
    if (moonCorpus?.advice) cardDDetails.push(moonCorpus.advice);
  }
  if (pSun) {
    const sunCorpus = sunSignPhases[sunSign];
    if (sunCorpus?.advice) cardDDetails.push(sunCorpus.advice);
  }
  if (lpCorpus?.advice) cardDDetails.push(lpCorpus.advice);
  if (topCross.length > 0) {
    const topAspect = topCross[0];
    const isSupportive = supportiveAspectIds.has(topAspect.type);
    if (isSupportive) {
      cardDDetails.push(natalLinkRules.supportive.summary);
    } else if (tensionAspectIds.has(topAspect.type)) {
      cardDDetails.push(natalLinkRules.challenging.summary);
    }
  }
  cards.push({
    id: "stage-advice",
    icon: "▷",
    title: "阶段建议",
    summary: "次限盘描述内在变化节奏，不是事件预测",
    details: cardDDetails,
  });

  // ── Card E: 与本命盘的关系 ──
  const cardEDetails: string[] = [];
  const supportiveCross = cross.filter(a => supportiveAspectIds.has(a.type)).slice(0, 2);
  const tensionCross = cross.filter(a => tensionAspectIds.has(a.type)).slice(0, 2);

  if (supportiveCross.length > 0) {
    const suppRule = natalLinkRules.supportive;
    const labels = supportiveCross.map(a => `次限${pointLabels[a.moving_point_id] ?? a.moving_point_id}强化了本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`);
    cardEDetails.push(suppRule ? `${suppRule.summary} ${labels.join("；")}。` : `被强化的本命倾向：${labels.join("；")}。`);
  }
  if (tensionCross.length > 0) {
    const challRule = natalLinkRules.challenging;
    const labels = tensionCross.map(a => `次限${pointLabels[a.moving_point_id] ?? a.moving_point_id}挑战了本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`);
    cardEDetails.push(challRule ? `${challRule.summary} ${labels.join("；")}。` : `被挑战的本命倾向：${labels.join("；")}。`);
  }
  const natalAspectPairs = new Set(natalSnapshot.result.aspects.map(a => `${a.point_a}-${a.point_b}`));
  const newCombinations = cross.filter(a => {
    const key = `${a.moving_point_id}-${a.reference_point_id}`;
    const reverseKey = `${a.reference_point_id}-${a.moving_point_id}`;
    return !natalAspectPairs.has(key) && !natalAspectPairs.has(reverseKey);
  }).slice(0, 2);
  if (newCombinations.length > 0) {
    const introRule = natalLinkRules.introducing;
    const labels = newCombinations.map(a => `次限${pointLabels[a.moving_point_id] ?? a.moving_point_id}与本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}的${aspectLabels[a.type] ?? a.type}`);
    cardEDetails.push(introRule ? `${introRule.summary} ${labels.join("；")}。` : `新出现的内在可能：${labels.join("；")}。`);
  }
  if (cardEDetails.length === 0) {
    cardEDetails.push("次限层与本命层的互动较平稳，没有强烈的强化或挑战信号。");
  }
  cards.push({
    id: "natal-link",
    icon: "⇌",
    title: "与本命盘的关系",
    summary: supportiveCross.length > tensionCross.length ? natalLinkRules.supportive.summary : tensionCross.length > 0 ? natalLinkRules.challenging.summary : "次限与本命互动平稳",
    details: cardEDetails,
  });

  return { cards };
}

// ── buildSecondaryProgressionInterpretationSections ──
// Bottom tab interpretation sections

export function buildSecondaryProgressionInterpretationSections(result: SecondaryProgressionResult): InterpretationSection[] {
  const comparison = result.comparison;
  const movingLayer = result.progressed_snapshot;
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg).slice(0, 6);
  const crossCards = cross.map((a) => ({
    id: a.aspect_id,
    title: `次限${pointLabels[a.moving_point_id] ?? a.moving_point_id} ${aspectLabels[a.type] ?? a.type} 本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`,
    subtitle: `强度 ${Math.round(a.strength * 100)} · ${a.applying_state === "applying" ? "正在接近" : a.applying_state === "exact" ? "正在精确" : "正在离开"}`,
    bullets: [crossAspectNarrative(a, "progression")],
  }));
  const houses = [...comparison.result.moving_points_in_reference_houses].slice(0, 8);
  const houseCards = houses.map((h) => ({
    id: `house-${h.moving_point_id}`,
    title: `次限${pointLabels[h.moving_point_id] ?? h.moving_point_id} 落入本命第${h.reference_house}宫`,
    subtitle: h.on_cusp ? "贴近宫头" : "长期影响该领域",
    bullets: [houseNarrative(h.moving_point_id, h.reference_house, "progression")],
  }));
  const corePoints = movingLayer.result.points.filter((p) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(p.point_id));
  const planetCards = corePoints.map((p) => ({
    id: `point-${p.point_id}`,
    title: `次限${pointLabels[p.point_id] ?? p.point_id}在${signLabels[p.sign] ?? p.sign}${p.house ? `第${p.house}宫` : ""}`,
    bullets: [pointNarrative(p, "次限")],
  }));
  const topAspects = [...movingLayer.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 6);
  const aspectCards = topAspects.map((a) => ({
    id: a.aspect_id,
    title: `次限${pointLabels[a.point_a] ?? a.point_a} ${aspectLabels[a.type] ?? a.type} 次限${pointLabels[a.point_b] ?? a.point_b}`,
    subtitle: `容许度 ${a.orb_deg.toFixed(2)}°`,
    bullets: [aspectNarrative(a, "次限")],
  }));
  return [
    { id: "cross", label: "本命触发", cards: crossCards },
    { id: "reference_houses", label: "落宫", cards: houseCards },
    { id: "planets", label: "行星", cards: planetCards },
    { id: "aspects", label: "相位", cards: aspectCards },
  ];
}
