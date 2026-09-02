import type { NatalSnapshot, SecondaryProgressionResult } from "../interstellar-api";
import {
  type ConsumerInsight,
  type InterpretationSection,
  pointLabels, aspectLabels, signLabels,
  supportiveAspectIds, tensionAspectIds,
  clampScore, aspectWeight, dimensionMeaning,
  asRecord, pointNarrative, aspectNarrative, crossAspectNarrative, houseNarrative,
} from "./shared";
import { moonSignPhases, sunSignPhases, lunarPhaseCorpus, houseCorpus, stageTransitions, keyNodes, natalLinkRules, rightPanelDisplayCorpus } from "./secondary-corpus";
import { moonNatalCombinations, planetNatalCombinations, outerPlanetCombinations } from "./secondary-corpus-combinations";

export type SecondaryProgressionCard = {
  id: string;
  icon: string;
  title: string;
  summary: string;
  details: string[];
  translation: string;
  action: string;
  caution: string;
};

export type SecondaryProgressionRightPanel = {
  cards: SecondaryProgressionCard[];
};

function lunarPhaseKey(angle: number): string {
  if (angle < 90) return "new";
  if (angle < 180) return "first_quarter";
  if (angle < 270) return "full";
  return "last_quarter";
}

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

function corpusSentence(text: string | undefined, fallback: string): string {
  return (text ?? fallback).split(/[。；]/)[0].replace(/：$/, "").trim();
}

function pointLabel(id: string): string {
  return pointLabels[id] ?? id;
}

function aspectLabel(type: string): string {
  return aspectLabels[type] ?? type;
}

function combinationFor(movingPointId: string, referencePointId: string) {
  const key = `${movingPointId}-${referencePointId}`;
  return moonNatalCombinations[key] ?? planetNatalCombinations[key] ?? outerPlanetCombinations[key];
}

const rightPanelPrimaryPointIds = new Set(rightPanelDisplayCorpus.coreTurningPointIds);
const slowPointIds = new Set(["jupiter", "saturn", "uranus", "neptune", "pluto"]);

function rightPanelAspectWeight(aspect: { moving_point_id: string; reference_point_id: string; strength: number; orb_deg: number; applying_state: string }): number {
  let score = aspect.strength * 100 - aspect.orb_deg;
  if (rightPanelPrimaryPointIds.has(aspect.moving_point_id)) score += 20;
  if (rightPanelPrimaryPointIds.has(aspect.reference_point_id)) score += 16;
  if (aspect.applying_state === "exact") score += 12;
  else if (aspect.applying_state === "applying") score += 5;
  return score;
}

function isRightPanelAspectCandidate(aspect: { moving_point_id: string; reference_point_id: string }): boolean {
  if (aspect.moving_point_id === aspect.reference_point_id && slowPointIds.has(aspect.moving_point_id)) return false;
  return rightPanelPrimaryPointIds.has(aspect.moving_point_id) && rightPanelPrimaryPointIds.has(aspect.reference_point_id);
}

function genericRightPanelAspectSentence(aspect: { moving_point_id: string; reference_point_id: string; type: string }): string {
  const movingTheme = rightPanelDisplayCorpus.pointThemes[aspect.moving_point_id as keyof typeof rightPanelDisplayCorpus.pointThemes] ?? pointLabel(aspect.moving_point_id);
  const referenceTheme = rightPanelDisplayCorpus.pointThemes[aspect.reference_point_id as keyof typeof rightPanelDisplayCorpus.pointThemes] ?? pointLabel(aspect.reference_point_id);
  const aspectTheme = rightPanelDisplayCorpus.aspectThemes[aspect.type as keyof typeof rightPanelDisplayCorpus.aspectThemes] ?? "正在形成新的互动关系。";
  return `${movingTheme}和${referenceTheme}${aspectTheme}`;
}

export function buildSecondaryProgressionConsumerInsight(
  result: SecondaryProgressionResult,
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
  const signLabel = (id: string | null | undefined) => id ? (signLabels[id] ?? id) : "";
  const houseDomain = (n: number) => {
    const domains = ["自我与起点", "价值与资源", "交流与日常", "家庭与根基", "创造与表达", "工作与健康", "关系与伴侣", "共有资源与转化", "远行与信念", "事业与公共形象", "社群与未来", "内在与释放"];
    return domains[n - 1] ?? `第${n}宫`;
  };

  const title = progressedMoon
    ? `次限月亮在${signLabel(progressedMoon.sign)}，推进你的情绪节奏`
    : top.length > 0
      ? `次限${movingLabel(top[0].moving_point_id)}${aspectLabel(top[0].type)}本命${refLabel(top[0].reference_point_id)}`
      : "次限盘正在缓慢推进你的生命主题";

  const summary = progressedMoon
    ? `次限月亮进入${signLabel(progressedMoon.sign)}，代表你内在的情绪需求和反应方式正在经历一段较长期的调整。它不会制造突发事件，而是悄悄改变你看待关系和安全感的方式。`
    : `${strongestDimension.label}是这个时段最明显的倾向。它描述公共天空的节奏，不代表每个人都会发生同一件事。`;

  const signals: ConsumerInsight["signals"] = [];

  if (progressedMoon) {
    signals.push({
      id: "progressed-moon",
      title: `次限月亮在${signLabel(progressedMoon.sign)}`,
      detail: "情绪基调正在转变",
      meaning: `次限月亮走到${signLabel(progressedMoon.sign)}，接下来一段时间你的情绪需求和被照顾的方式会偏向这个星座的特质。`,
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
    ? [`次限月亮在${signLabel(progressedMoon.sign)}，情绪节奏与这个星座的特质更合拍。`]
    : [`${strongestDimension.label}比较突出。把它用在合适的事情上，你更容易进入状态，也更容易让别人理解你的长处。`];

  const reminders = [
    progressedSun ? `次限太阳在${signLabel(progressedSun.sign)}，长期目标和自我表达的方向正在转向这个星座的特质。` : "次限盘反映的是长期趋势，不是单一日期的突发事件。",
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
    summary: pMoon ? (moonSignPhases[moonSign]?.summary ?? `次限月亮在${signLabels[moonSign] ?? moonSign}`) : stageTransitions.baseline.summary,
    details: cardADetails,
    translation: "最近几年，情绪镜头和长期人生主线正在慢慢转向新的表达方式。",
    action: "可以留意自己反复在意什么、被什么触动；那些反复出现的感受，往往比单次事件更能说明这个阶段。",
    caution: "这里描述的是逐渐形成的内在气候，不是今天或本周的事件清单。",
  });

  // ── Card B: 长期变化主题 ──
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const rightPanelCross = cross
    .filter(isRightPanelAspectCandidate)
    .sort((a, b) => rightPanelAspectWeight(b) - rightPanelAspectWeight(a));
  const topCross = rightPanelCross.slice(0, 3);
  const cardBDetails: string[] = [];
  if (pMoon && pMoon.house) {
    const hc = houseCorpus[String(pMoon.house)];
    cardBDetails.push(`情绪关注点：本命第${pMoon.house}宫｜${hc ? corpusSentence(hc.summary, "") : `本命第${pMoon.house}宫正在被点亮`}`);
  }
  if (pSun && pSun.house) {
    const hc = houseCorpus[String(pSun.house)];
    cardBDetails.push(`身份方向：本命第${pSun.house}宫｜${hc ? corpusSentence(hc.summary, "") : `本命第${pSun.house}宫正在进入长期调整`}`);
  }
  for (const aspect of topCross) {
    const moving = pointLabel(aspect.moving_point_id);
    const ref = pointLabel(aspect.reference_point_id);
    const combCorpus = combinationFor(aspect.moving_point_id, aspect.reference_point_id);
    const aspectText = corpusSentence(
      combCorpus?.aspects?.[aspect.type] ?? combCorpus?.meaning,
      genericRightPanelAspectSentence(aspect),
    );
    const stateLabel = aspect.applying_state === "exact" ? "正在精确" : aspect.applying_state === "applying" ? "正在增强" : "正在减弱";
    cardBDetails.push(`次限${moving}${aspectLabel(aspect.type)}本命${ref}｜${aspectText}（${stateLabel}）`);
  }
  if (cardBDetails.length < 3 && lpCorpus?.summary) {
    cardBDetails.push(`月相主题：${phaseInfo.phase}｜${corpusSentence(lpCorpus.summary, rightPanelDisplayCorpus.currentStage.phaseFallback)}`);
  }
  let cardBSummary = stageTransitions.baseline.summary;
  if (topCross.length > 0 && topCross[0]) {
    const topA = topCross[0];
    const comb = combinationFor(topA.moving_point_id, topA.reference_point_id);
    cardBSummary = comb
      ? corpusSentence(comb.meaning, stageTransitions.baseline.summary)
      : `次限${pointLabel(topA.moving_point_id)}正在激活本命${pointLabel(topA.reference_point_id)}`;
  }
  cards.push({
    id: "change-themes",
    icon: "◈",
    title: "长期变化主题",
    summary: cardBSummary,
    details: cardBDetails,
    translation: natalLinkRules.resonance.summary,
    action: "优先处理最反复出现的主题；如果多个线索指向同一领域，可以把它视为这一阶段的主线。",
    caution: "强度高表示主题更集中，不等于外部一定发生大事。",
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
    const moving = pointLabel(aspect.moving_point_id);
    const ref = pointLabel(aspect.reference_point_id);
    const comb = combinationFor(aspect.moving_point_id, aspect.reference_point_id);
    cardCDetails.push(`次限${moving}精确${aspectLabel(aspect.type)}本命${ref}：${corpusSentence(comb?.aspects?.[aspect.type] ?? comb?.meaning, "当前转折信号最强")}`);
  }
  const lpAngle = Number(asRecord(progressed.result.astronomical_context).lunar_phase?.angle ?? asRecord(progressed.result.astronomical_context).lunar_phase?.elongation_deg ?? 0);
  if (lpAngle < 5 || Math.abs(lpAngle - 90) < 5 || Math.abs(lpAngle - 180) < 5 || Math.abs(lpAngle - 270) < 5) {
    const phaseCross = stageTransitions.phaseCross;
    cardCDetails.push(phaseCross ? phaseCross.summary : `次限月相正处于${phaseInfo.phase}的起始阶段，内在节奏正在转换。`);
  }
  if (cardCDetails.length === 0) {
    const quiet = stageTransitions.quietPeriod;
    cardCDetails.push(quiet ? quiet.summary : stageTransitions.baseline.summary);
  }
  cards.push({
    id: "turning-points",
    icon: "⟐",
    title: "核心转折点",
    summary: cardCDetails.length > 0 ? cardCDetails[0].split("，")[0] : "当前阶段较平稳",
    details: cardCDetails,
    translation: keyNodes.moonDoubleChange.summary,
    action: stageTransitions.signCross.advice ?? "过渡期按阶段推进，不急着一次完成。",
    caution: stageTransitions.methodBoundary.summary,
  });

  // ── Card D: 阶段建议 ──
  const cardDDetails: string[] = [];
  let moonAdvice = rightPanelDisplayCorpus.currentStage.moonFallback;
  let sunAdvice = rightPanelDisplayCorpus.currentStage.sunFallback;
  let aspectAdvice = rightPanelDisplayCorpus.aspectTone.steady;
  if (pMoon) {
    const moonCorpus = moonSignPhases[moonSign];
    const moonHouse = pMoon.house;
    if (moonHouse) {
      const hc = houseCorpus[String(moonHouse)];
      moonAdvice = moonCorpus?.advice ?? (hc ? hc.summary : `本命第${moonHouse}宫的主题正在被内在需求点亮。`);
    }
    if (moonCorpus?.advice) moonAdvice = moonCorpus.advice;
  }
  if (pSun) {
    const sunCorpus = sunSignPhases[sunSign];
    if (sunCorpus?.advice) sunAdvice = sunCorpus.advice;
  }
  if (topCross.length > 0) {
    const topAspect = topCross[0];
    const isSupportive = supportiveAspectIds.has(topAspect.type);
    if (isSupportive) {
      aspectAdvice = rightPanelDisplayCorpus.aspectTone.supportive;
    } else if (tensionAspectIds.has(topAspect.type)) {
      aspectAdvice = rightPanelDisplayCorpus.aspectTone.tension;
    } else {
      aspectAdvice = rightPanelDisplayCorpus.aspectTone.neutral;
    }
  }
  cardDDetails.push(`${rightPanelDisplayCorpus.adviceSlots.emotion.title}｜${corpusSentence(moonAdvice, rightPanelDisplayCorpus.currentStage.moonFallback)}`);
  cardDDetails.push(`${rightPanelDisplayCorpus.adviceSlots.identity.title}｜${corpusSentence(sunAdvice, lpCorpus?.advice ?? rightPanelDisplayCorpus.currentStage.sunFallback)}`);
  cardDDetails.push(`${rightPanelDisplayCorpus.adviceSlots.aspect.title}｜${corpusSentence(aspectAdvice, rightPanelDisplayCorpus.aspectTone.steady)}`);
  cards.push({
    id: "stage-advice",
    icon: "▷",
    title: "阶段建议",
    summary: stageTransitions.methodBoundary.summary,
    details: cardDDetails,
    translation: lpCorpus?.detail ?? stageTransitions.baseline.detail,
    action: lpCorpus?.advice ?? stageTransitions.baseline.advice ?? "围绕当前主线做持续微调。",
    caution: stageTransitions.methodBoundary.summary,
  });

  // ── Card E: 与本命盘的关系 ──
  const cardEDetails: string[] = [];
  const supportiveCross = rightPanelCross.filter(a => supportiveAspectIds.has(a.type)).slice(0, 2);
  const tensionCross = rightPanelCross.filter(a => tensionAspectIds.has(a.type)).slice(0, 2);

  if (supportiveCross.length > 0) {
    const suppRule = natalLinkRules.supportive;
    const labels = supportiveCross.map(a => `次限${pointLabel(a.moving_point_id)}强化了本命${pointLabel(a.reference_point_id)}`);
    cardEDetails.push(suppRule ? `${suppRule.summary} ${labels.join("；")}。` : `被强化的本命倾向：${labels.join("；")}。`);
  }
  if (tensionCross.length > 0) {
    const challRule = natalLinkRules.challenging;
    const labels = tensionCross.map(a => `次限${pointLabel(a.moving_point_id)}挑战了本命${pointLabel(a.reference_point_id)}`);
    cardEDetails.push(challRule ? `${challRule.summary} ${labels.join("；")}。` : `被挑战的本命倾向：${labels.join("；")}。`);
  }
  const natalAspectPairs = new Set(natalSnapshot.result.aspects.map(a => `${a.point_a}-${a.point_b}`));
  const newCombinations = rightPanelCross.filter(a => {
    const key = `${a.moving_point_id}-${a.reference_point_id}`;
    const reverseKey = `${a.reference_point_id}-${a.moving_point_id}`;
    return !natalAspectPairs.has(key) && !natalAspectPairs.has(reverseKey);
  }).slice(0, 2);
  if (newCombinations.length > 0) {
    const introRule = natalLinkRules.introducing;
    const labels = newCombinations.map(a => `次限${pointLabel(a.moving_point_id)}与本命${pointLabel(a.reference_point_id)}的${aspectLabel(a.type)}`);
    cardEDetails.push(`新出现的内在可能：${introRule ? corpusSentence(introRule.summary, "") : "次限层正在引入本命层未有的新组合"} ${labels.join("；")}。`);
  }
  if (cardEDetails.length === 0) {
    cardEDetails.push(natalLinkRules.steady.summary);
  }
  cards.push({
    id: "natal-link",
    icon: "⇌",
    title: "与本命盘的关系",
    summary: supportiveCross.length > tensionCross.length ? natalLinkRules.supportive.summary : tensionCross.length > 0 ? natalLinkRules.challenging.summary : natalLinkRules.steady.summary,
    details: cardEDetails,
    translation: natalLinkRules.introducing.detail ?? "这些变化是在本命底图上展开的阶段性层叠。",
    action: "顺势部分可以主动使用；需要协调的部分，适合更新旧有表达方式。",
    caution: "次限盘不会替代本命盘，它呈现的是本命结构在当前阶段的展开方式。",
  });

  return { cards };
}

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
