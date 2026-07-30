/**
 * 日返盘 Insight Builder
 * 按六层架构：后端事实 → insight builder → corpus → presentation rules → React → CSS
 * 从 SolarReturnResult 提取事实、选择语料、构建10张右侧卡片数据
 */

import type { NatalSnapshot, SolarReturnResult } from "../interstellar-api";
import {
  type ConsumerInsight,
  type InterpretationSection,
  pointLabels, aspectLabels, signLabels,
  supportiveAspectIds, tensionAspectIds,
  clampScore, aspectWeight, dimensionMeaning,
  asRecord, pointNarrative, aspectNarrative, crossAspectNarrative, houseNarrative,
  pointThemes, houseLabels, elementBySign, signalMeaning,
} from "./shared";
import {
  axisDirectionCorpus, quarterPhaseCorpus, monthRhythmCorpus,
  domainCorpus, relationshipClimateCorpus, careerLadderCorpus,
  resourcePoolCorpus, pressureOpportunityCorpus, actionRouteCorpus,
  scoringRules, displayCorpus, solarReturnAscCorpus,
  type CorpusEntry,
} from "./solar-return-corpus";

// ─── 类型 ─────────────────────────────────────────────────

export type SolarReturnCard = {
  id: string;
  icon: string;
  title: string;
  summary: string;
  details: string[];
  translation: string;
  action: string;
  caution: string;
};

export type SolarReturnRightPanel = {
  topIndex: {
    score: number;
    state: string;
    career: number;
    relationship: number;
    resource: number;
    inner: number;
    direction: string;
    directionLabel: string;
    topSignals: string[];
  };
  cards: SolarReturnCard[];
};

// ─── 工具 ─────────────────────────────────────────────────

function corpusSentence(text: string | undefined, fallback: string): string {
  return (text ?? fallback).split(/[。；]/)[0].replace(/：$/, "").trim();
}

const corePointIds = new Set(["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "asc", "mc"]);

function axisScore(snapshot: NatalSnapshot, axisKey: keyof typeof scoringRules.axisWeights): number {
  const spec = scoringRules.axisWeights[axisKey];
  let score = 0;
  const points = snapshot.result.points;
  for (const point of points) {
    if ((spec.points as readonly string[]).includes(point.point_id) && point.house) {
      const houseArr: number[] = Array.isArray(spec.house) ? [...spec.house] : [spec.house as unknown as number];
      if (houseArr.includes(point.house)) score += 18;
      else score += 3;
    }
    if ((spec.points as readonly string[]).includes(point.point_id) && point.retrograde) score += 2;
  }
  for (const point of points) {
    if (corePointIds.has(point.point_id) && point.house) {
      const houseArr: number[] = Array.isArray(spec.house) ? [...spec.house] : [spec.house as unknown as number];
      if (houseArr.includes(point.house)) score += 8;
    }
  }
  // Aspect involvement for axis points
  for (const aspect of snapshot.result.aspects) {
    if ((spec.points as readonly string[]).includes(aspect.point_a) || (spec.points as readonly string[]).includes(aspect.point_b)) {
      score += supportiveAspectIds.has(aspect.type) ? 5 : tensionAspectIds.has(aspect.type) ? 4 : 2;
    }
  }
  return clampScore(score);
}

function domainScore(snapshot: NatalSnapshot, domainKey: keyof typeof scoringRules.domainWeights): number {
  const spec = scoringRules.domainWeights[domainKey];
  let score = 0;
  const points = snapshot.result.points;
  for (const point of points) {
    if ((spec.points as readonly string[]).includes(point.point_id) && point.house) {
      const houseArr: number[] = Array.isArray(spec.house) ? [...spec.house] : [spec.house as unknown as number];
      if (houseArr.includes(point.house)) score += 20;
      else score += 3;
    }
  }
  for (const point of points) {
    if (corePointIds.has(point.point_id) && point.house) {
      const houseArr: number[] = Array.isArray(spec.house) ? [...spec.house] : [spec.house as unknown as number];
      if (houseArr.includes(point.house)) score += 6;
    }
  }
  return clampScore(score);
}

function stateLabel(score: number): string {
  if (score <= 20) return displayCorpus.topIndex.stateLabels.background;
  if (score <= 40) return displayCorpus.topIndex.stateLabels.light;
  if (score <= 60) return displayCorpus.topIndex.stateLabels.active;
  if (score <= 80) return displayCorpus.topIndex.stateLabels.high;
  return displayCorpus.topIndex.stateLabels.dense;
}

function strongestDirection(scores: Record<string, number>): { key: string; label: string } {
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  if (sorted.length === 0) return { key: "mixed", label: "多线平衡" };
  const top = sorted[0];
  const topValue = top[1];
  const second = sorted[1];
  if (second && topValue - second[1] < 8) return { key: "mixed", label: "多线平衡" };
  return { key: top[0], label: scoringRules.axisWeights[top[0] as keyof typeof scoringRules.axisWeights]?.label ?? top[0] };
}

// ─── 右侧面板构建 ─────────────────────────────────────────

export function buildSolarReturnRightPanel(
  result: SolarReturnResult,
  natalSnapshot: NatalSnapshot,
): SolarReturnRightPanel {
  const returnSnapshot = result.return_snapshot;
  const comparison = result.comparison;
  const cards: SolarReturnCard[] = [];

  // ── 计算四向权重 ──
  const careerScore = axisScore(returnSnapshot, "career");
  const relationshipScore = axisScore(returnSnapshot, "relationship");
  const resourceScore = axisScore(returnSnapshot, "resource");
  const innerScore = axisScore(returnSnapshot, "inner");
  const axisScores = { career: careerScore, relationship: relationshipScore, resource: resourceScore, inner: innerScore };
  const direction = strongestDirection(axisScores);
  const topAxisCorpus = axisDirectionCorpus[direction.key] ?? axisDirectionCorpus.mixed;

  // ── 计算主指数 ──
  const topIndexScore = clampScore(Math.round((careerScore + relationshipScore + resourceScore + innerScore) / 3.2));
  const densityScore = clampScore(Math.round(topIndexScore * 0.55));
  const clarityScore = clampScore(Math.round(topIndexScore * 0.45));

  // ── 计算领域分数 ──
  const domainScores = {
    family: domainScore(returnSnapshot, "family"),
    relationship: domainScore(returnSnapshot, "relationship"),
    career: domainScore(returnSnapshot, "career"),
    finance: domainScore(returnSnapshot, "finance"),
    health: domainScore(returnSnapshot, "health"),
    learning: domainScore(returnSnapshot, "learning"),
  };
  const sortedDomains = Object.entries(domainScores).sort((a, b) => b[1] - a[1]);
  const topDomainIds = sortedDomains.slice(0, 3).map(d => d[0]);

  // ── Cross aspects ──
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const rightPanelCross = cross
    .filter(a => corePointIds.has(a.moving_point_id) && corePointIds.has(a.reference_point_id))
    .sort((a, b) => (b.strength * 100 - b.orb_deg) - (a.strength * 100 - a.orb_deg));

  const supportiveCross = rightPanelCross.filter(a => supportiveAspectIds.has(a.type)).slice(0, 2);
  const tensionCross = rightPanelCross.filter(a => tensionAspectIds.has(a.type)).slice(0, 2);

  // ── 顶部信号 ──
  const topSignals: string[] = [];
  const ascPoint = returnSnapshot.result.points.find(p => p.point_id === "asc");
  const mcPoint = returnSnapshot.result.points.find(p => p.point_id === "mc");
  if (ascPoint) topSignals.push(`日返上升在${signLabels[ascPoint.sign] ?? ascPoint.sign}`);
  if (mcPoint) topSignals.push(`日返MC在${signLabels[mcPoint.sign] ?? mcPoint.sign}`);
  const sunPoint = returnSnapshot.result.points.find(p => p.point_id === "sun");
  if (sunPoint?.house === 10) topSignals.push("太阳落第10宫");
  else if (sunPoint?.house) topSignals.push(`太阳第${sunPoint.house}宫`);
  const topAspect = rightPanelCross[0];
  if (topAspect) topSignals.push(`${pointLabels[topAspect.moving_point_id] ?? topAspect.moving_point_id}${aspectLabels[topAspect.type] ?? topAspect.type}${pointLabels[topAspect.reference_point_id] ?? topAspect.reference_point_id}`);

  // ── Card A: 年度主轴罗盘 ──
  const ascCorpus = ascPoint ? solarReturnAscCorpus[ascPoint.sign] : undefined;
  cards.push({
    id: "annual-compass",
    icon: displayCorpus.cards.A.icon,
    title: displayCorpus.cards.A.title,
    summary: topAxisCorpus.summary,
    details: [
      ascCorpus ? corpusSentence(ascCorpus.summary, "年度主轴方向待确认") : "日返上升方向待确认",
      topAxisCorpus.detail.split(/[。；]/)[0],
      ...(rightPanelCross.slice(0, 2).map(a =>
        `日返${pointLabels[a.moving_point_id] ?? a.moving_point_id}${aspectLabels[a.type] ?? a.type}本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}（${a.applying_state === "exact" ? "精确" : a.applying_state === "applying" ? "增强中" : "减弱中"}）`
      )),
    ],
    translation: topAxisCorpus.detail,
    action: topAxisCorpus.advice ?? "围绕年度主轴做持续调整。",
    caution: topAxisCorpus.challenge ?? "指数表示主题集中度，不表示事件概率。",
  });

  // ── Card B: 12个月节律环 ──
  // 按月估算信号强度（从跨盘相位的月份触发近似）
  const monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"];
  const monthIntensities = monthLabels.map((_, i) => {
    let intensity = 20 + Math.random() * 10; // baseline
    // 用返回盘的行星分布和跨盘相位粗估月份节奏
    const sunDeg = sunPoint?.degree_in_sign ?? 0;
    const monthStart = i * 30;
    const sunDist = Math.abs(sunDeg - (monthStart % 360));
    if (sunDist < 30) intensity += 15;
    for (const aspect of rightPanelCross.slice(0, 3)) {
      if (aspect.applying_state === "exact") intensity += 12;
      else if (aspect.applying_state === "applying") intensity += 6;
    }
    return Math.min(100, Math.round(intensity));
  });
  const peakMonthIdx = monthIntensities.indexOf(Math.max(...monthIntensities));
  const turningMonthIdx = monthIntensities.findIndex((v, i) => i > peakMonthIdx && v < monthIntensities[peakMonthIdx] * 0.7);
  const peakRhythm = peakMonthIdx >= 6 ? "下半年" : "上半年";
  cards.push({
    id: "monthly-rhythm",
    icon: displayCorpus.cards.B.icon,
    title: displayCorpus.cards.B.title,
    summary: `${monthLabels[Math.max(0, peakMonthIdx - 1)]}到${monthLabels[Math.min(11, peakMonthIdx + 1)]}是本年度最关键的节奏带。`,
    details: [
      `峰值月：${monthLabels[peakMonthIdx]}（${monthRhythmCorpus.peak.summary}）`,
      ...(turningMonthIdx >= 0 ? [`转折月：${monthLabels[turningMonthIdx]}（${monthRhythmCorpus.turning.summary}）`] : []),
      `节奏主线：全年关键变化集中在${peakRhythm}，其余时间以推进和缓冲为主。`,
    ],
    translation: `${peakRhythm}信号更密集，另一半年更适合整理和恢复节奏。`,
    action: "在峰值月做关键决定，在缓冲月整理和恢复。",
    caution: "峰值月不等于一定会发生大事，而是说主题集中度最高。",
  });

  // ── Card C: 四季度地形图 ──
  const qScores = [
    { key: "Q1", score: (monthIntensities[0] + monthIntensities[1] + monthIntensities[2]) / 3, phase: quarterPhaseCorpus.Q1_foundation },
    { key: "Q2", score: (monthIntensities[3] + monthIntensities[4] + monthIntensities[5]) / 3, phase: quarterPhaseCorpus.Q2_accelerate },
    { key: "Q3", score: (monthIntensities[6] + monthIntensities[7] + monthIntensities[8]) / 3, phase: quarterPhaseCorpus.Q3_peak },
    { key: "Q4", score: (monthIntensities[9] + monthIntensities[10] + monthIntensities[11]) / 3, phase: quarterPhaseCorpus.Q4_consolidate },
  ];
  const peakQ = qScores.reduce((a, b) => a.score > b.score ? a : b);
  const lowestQ = qScores.reduce((a, b) => a.score < b.score ? a : b);
  cards.push({
    id: "quarterly-terrain",
    icon: displayCorpus.cards.C.icon,
    title: displayCorpus.cards.C.title,
    summary: `最适合集中发力的是${peakQ.key}，最适合整理的是${lowestQ.key}。`,
    details: qScores.map(q => `${q.key}：${q.phase.summary}（高度 ${Math.round(q.score)}）`),
    translation: peakQ.phase.detail,
    action: peakQ.phase.advice ?? "按季度节奏调整策略。",
    caution: "若全年一直用同样强度推进，反而容易在峰值前透支。",
  });

  // ── Card D: 年度领域天际线 ──
  const topDomainLabels = topDomainIds.map(id => domainCorpus[id] ?? null).filter(Boolean) as CorpusEntry[];
  cards.push({
    id: "domain-skyline",
    icon: displayCorpus.cards.D.icon,
    title: displayCorpus.cards.D.title,
    summary: `今年你的主要资源会投向${topDomainIds.map(id => scoringRules.domainWeights[id as keyof typeof scoringRules.domainWeights]?.house?.toString() ?? id).join("、")}领域。`,
    details: sortedDomains.map(([key, score]) => {
      const corpus = domainCorpus[key];
      const label = key === "career" ? "事业" : key === "relationship" ? "关系" : key === "family" ? "家庭" : key === "finance" ? "金钱" : key === "health" ? "健康" : "学习";
      return `${label}：${corpus ? corpusSentence(corpus.summary, "年度关注待确认") : "年度关注待确认"}（${score}）`;
    }),
    translation: topDomainLabels[0]?.detail ?? "领域资源分布以宫位权重和主星主题为基础。",
    action: topDomainLabels[0]?.advice ?? "在核心领域集中精力，其他领域做最低维护。",
    caution: "高建筑不等于事件概率，而是时间和注意力占比。",
  });

  // ── Card E: 关系气候带 ──
  const venusPoint = returnSnapshot.result.points.find(p => p.point_id === "venus");
  const moonPoint = returnSnapshot.result.points.find(p => p.point_id === "moon");
  const seventhHousePoints = returnSnapshot.result.points.filter(p => p.house === 7);
  const hasStrongRelationship = seventhHousePoints.length > 0 || (venusPoint && (tensionAspectIds.has("square") || supportiveAspectIds.has("trine")));
  const climatePhase = hasStrongRelationship
    ? (tensionCross.length > supportiveCross.length ? "cloudy" : "warming")
    : "calm";
  const climateCorpus = relationshipClimateCorpus[climatePhase] ?? relationshipClimateCorpus.calm;
  const climateSequence = tensionCross.length > supportiveCross.length
    ? ["冷静", "多云", "转暖"]
    : supportiveCross.length > tensionCross.length
      ? ["转暖", "高温", "稳定"]
      : ["冷静", "转暖", "稳定"];
  cards.push({
    id: "relationship-climate",
    icon: displayCorpus.cards.E.icon,
    title: displayCorpus.cards.E.title,
    summary: `这一年的关系气候会从${climateSequence[0]}逐步转向${climateSequence[2]}。`,
    details: [
      `全年关系基调：${climateCorpus.summary}`,
      ...(venusPoint ? [`日返金星在${signLabels[venusPoint.sign] ?? venusPoint.sign}${venusPoint.house ? `第${venusPoint.house}宫` : ""}，关系价值观和偏好正在调整。`] : []),
      ...(seventhHousePoints.length > 0 ? [`${seventhHousePoints.map(p => pointLabels[p.point_id] ?? p.point_id).join("、")}落在第7宫，合作和伴侣事务更活跃。`] : []),
    ],
    translation: climateCorpus.detail,
    action: climateCorpus.advice ?? "在关系气候中保持节奏，不必每次都全力响应。",
    caution: "关系气候不等于关系结果，它描述的是互动氛围和节奏。",
  });

  // ── Card F: 事业定位阶梯 ──
  const mcCorpus = mcPoint ? solarReturnAscCorpus[mcPoint.sign] : undefined;
  const tenthHousePoints = returnSnapshot.result.points.filter(p => p.house === 10);
  const careerAspectCount = rightPanelCross.filter(a =>
    ["mc", "saturn", "jupiter", "sun"].includes(a.moving_point_id) || ["mc", "saturn", "jupiter", "sun"].includes(a.reference_point_id)
  ).length;
  const careerLevel = careerAspectCount >= 3 ? "visible" : careerAspectCount >= 2 ? "assume" : tenthHousePoints.length > 0 ? "position" : "probe";
  const careerLevelCorpus = careerLadderCorpus[careerLevel] ?? careerLadderCorpus.probe;
  const careerLevelLabels: Record<string, string> = { probe: "①试探", position: "②定位", assume: "③承担", visible: "④被看见" };
  cards.push({
    id: "career-ladder",
    icon: displayCorpus.cards.F.icon,
    title: displayCorpus.cards.F.title,
    summary: `事业发展更像${careerLevel === "visible" ? "逐步升级" : careerLevel === "assume" ? "从定位到承担" : careerLevel === "position" ? "从试探到定位" : "探索和确认方向"}，而不是一次性突破。`,
    details: [
      `当前阶段：${careerLevelLabels[careerLevel]}（${careerLevelCorpus.summary}）`,
      ...(mcPoint ? [`日返MC在${signLabels[mcPoint.sign] ?? mcPoint.sign}，公开角色方向偏向这个星座的特质。`] : []),
      ...(tenthHousePoints.length > 0 ? [`${tenthHousePoints.map(p => pointLabels[p.point_id] ?? p.point_id).join("、")}落在第10宫，事业能见度增加。`] : []),
    ],
    translation: careerLevelCorpus.detail,
    action: careerLevelCorpus.advice ?? "按阶梯推进，跳过前置条件容易翻车。",
    caution: "不把阶梯写成必然升级——每一层需要先交付稳定才能进入下一层。",
  });

  // ── Card G: 资源蓄水池 ──
  const secondHousePoints = returnSnapshot.result.points.filter(p => p.house === 2);
  const eighthHousePoints = returnSnapshot.result.points.filter(p => p.house === 8);
  const resourceInput = secondHousePoints.length + rightPanelCross.filter(a => ["jupiter", "venus"].includes(a.moving_point_id) && supportiveAspectIds.has(a.type)).length;
  const resourceOutput = eighthHousePoints.length + tensionCross.length;
  const resourceState = resourceInput > resourceOutput + 1 ? "accumulating" : resourceOutput > resourceInput + 1 ? "draining" : "flowing";
  const resourceCorpus = resourcePoolCorpus[resourceState] ?? resourcePoolCorpus.flowing;
  const resourceStateLabel: Record<string, string> = { accumulating: "累积↑", flowing: "流动→", draining: "消耗↓" };
  const waterLevel = clampScore(40 + (resourceInput - resourceOutput) * 12);
  cards.push({
    id: "resource-pool",
    icon: displayCorpus.cards.G.icon,
    title: displayCorpus.cards.G.title,
    summary: `本年度资源状态偏${resourceState === "accumulating" ? "累积" : resourceState === "draining" ? "消耗" : "流动"}，关键在${resourceState === "draining" ? "控制输出节奏和寻找新输入" : resourceState === "accumulating" ? "合理分配新增资源" : "收支平衡管理"}。`,
    details: [
      `净变化：${resourceStateLabel[resourceState]} 水位 ${waterLevel}%`,
      `输入管道：${secondHousePoints.length > 0 ? secondHousePoints.map(p => pointLabels[p.point_id] ?? p.point_id).join("、") + "在第2宫" : "第2宫行星待确认"}`,
      `输出管道：${eighthHousePoints.length > 0 ? eighthHousePoints.map(p => pointLabels[p.point_id] ?? p.point_id).join("、") + "在第8宫" : "第8宫行星待确认"}`,
    ],
    translation: resourceCorpus.detail,
    action: resourceCorpus.advice ?? "在核心稳定的前提下管理资源流向。",
    caution: resourceCorpus.challenge ?? "消耗期不等于资源危机，但需要主动控制输出节奏。",
  });

  // ── Card H: 压力—机会桥 ──
  const pressureItems = tensionCross.slice(0, 2).map(a =>
    `日返${pointLabels[a.moving_point_id] ?? a.moving_point_id}${aspectLabels[a.type] ?? a.type}本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`
  );
  const opportunityItems = supportiveCross.slice(0, 2).map(a =>
    `日返${pointLabels[a.moving_point_id] ?? a.moving_point_id}${aspectLabels[a.type] ?? a.type}本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`
  );
  const mainPressure = pressureItems[0] ?? "无显著压力";
  const pressureCorpusEntry = tensionCross.length > 0
    ? pressureOpportunityCorpus.responsibility
    : pressureOpportunityCorpus.restriction;
  cards.push({
    id: "pressure-bridge",
    icon: displayCorpus.cards.H.icon,
    title: displayCorpus.cards.H.title,
    summary: `今年最大的机会，来自把${mainPressure.split("日返")[1]?.split("日返")[0] ?? "压力"}转化为${tensionCross.length > 0 ? "能力和结构" : "聚焦和方向"}。`,
    details: [
      ...(pressureItems.length > 0 ? [`压力岸：${pressureItems.join("；")}`] : ["压力岸：当前没有突出的压力相位"]),
      `转化桥：调整打法、建立流程、设定边界`,
      ...(opportunityItems.length > 0 ? [`机会岸：${opportunityItems.join("；")}`] : ["机会岸：以内在既有主题的强化与调整为主"]),
    ],
    translation: pressureCorpusEntry.detail,
    action: pressureCorpusEntry.advice ?? "把压力转成结构而非硬扛。",
    caution: "压力项必须给出调节出口；支持项不是结果保证。",
  });

  // ── Card I: 年度承诺追踪 ──
  // 从年度主题推导3个承诺
  const commitDomains = topDomainIds.slice(0, 3);
  const commitmentItems = commitDomains.map((id, i) => {
    const dCorpus = domainCorpus[id];
    const label = id === "career" ? "建立职业结构" : id === "relationship" ? "调整关系规则" : id === "family" ? "巩固家庭根基" : id === "finance" ? "管理财务节奏" : id === "health" ? "建立健康基线" : "推进学习目标";
    return { label, progress: Math.max(20, 75 - i * 20), corpus: dCorpus };
  });
  cards.push({
    id: "commitment-tracker",
    icon: displayCorpus.cards.I.icon,
    title: displayCorpus.cards.I.title,
    summary: `本年度最值得坚持的承诺是${commitmentItems[0]?.label ?? "年度主题待确认"}。`,
    details: commitmentItems.map((item, i) => `${i + 1}. ${item.label} [${item.progress}%]${item.corpus ? " — " + corpusSentence(item.corpus.summary, "") : ""}`),
    translation: "日返盘从解释工具变成年度执行参考，但进度由你记录，盘面只负责提出重点。",
    action: "每季度检查一次进度，根据实际情况调整优先级。",
    caution: "承诺由你设定和跟踪，盘面只提供方向参考。",
  });

  // ── Card J: 年度行动路线书 ──
  const routeStyle = peakQ.key === "Q3"
    ? actionRouteCorpus.organize_first
    : peakQ.key === "Q2"
      ? actionRouteCorpus.expand_mid
      : actionRouteCorpus.organize_first;
  cards.push({
    id: "action-route",
    icon: displayCorpus.cards.J.icon,
    title: displayCorpus.cards.J.title,
    summary: `这一年更适合按${peakQ.key === "Q3" ? "先收后扩" : peakQ.key === "Q2" ? "早推晚定" : "稳步推进"}的节奏推进，而不是一步到位。`,
    details: [
      `起点（Q1—Q2）：整理结构，确认方向`,
      `中段（Q2—Q3）：集中推进，扩大行动`,
      `终点（Q3—Q4）：整合成果，固化身份`,
      `⚠岔路：急于证明结果、追逐短期反馈`,
    ],
    translation: routeStyle.detail,
    action: routeStyle.advice ?? "按路线走，高峰期的机会更容易落地。",
    caution: "上半年若急于证明结果，容易消耗在短期反馈上。",
  });

  return {
    topIndex: {
      score: topIndexScore,
      state: stateLabel(topIndexScore),
      career: careerScore,
      relationship: relationshipScore,
      resource: resourceScore,
      inner: innerScore,
      direction: direction.key,
      directionLabel: direction.label,
      topSignals: topSignals.slice(0, 3),
    },
    cards,
  };
}

export function buildSolarReturnConsumerInsight(
  result: SolarReturnResult,
): ConsumerInsight {
  const returnSnapshot = result.return_snapshot;
  const comparison = result.comparison;
  const rightPanel = buildSolarReturnRightPanel(result, returnSnapshot);

  // Use the return snapshot for dimension scoring
  const corePoints = returnSnapshot.result.points.filter(p =>
    ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"].includes(p.point_id)
  );
  const elementCounts = { fire: 0, earth: 0, air: 0, water: 0 };
  for (const point of corePoints) {
    const element = { aries: "fire", leo: "fire", sagittarius: "fire", taurus: "earth", virgo: "earth", capricorn: "earth", gemini: "air", libra: "air", aquarius: "air", cancer: "water", scorpio: "water", pisces: "water" }[point.sign];
    if (element) elementCounts[element as keyof typeof elementCounts] += point.point_id === "sun" || point.point_id === "moon" ? 2 : 1;
  }
  const totalElements = Math.max(1, Object.values(elementCounts).reduce((sum, count) => sum + count, 0));
  const elementScore = (element: keyof typeof elementCounts) => 34 + elementCounts[element] / totalElements * 96;

  const weightedAspects = returnSnapshot.result.aspects.map(aspect => ({
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
    { id: "action" as const, label: "\u884c\u52a8\u63a8\u8fdb", score: clampScore(elementScore("fire") + Math.min(14, involvement(["mars", "sun"]) * 2) + balanceAdjustment) },
    { id: "emotion" as const, label: "\u60c5\u7eea\u611f\u53d7", score: clampScore(elementScore("water") + Math.min(14, involvement(["moon", "venus"]) * 2)) },
    { id: "expression" as const, label: "\u6c9f\u901a\u8868\u8fbe", score: clampScore(elementScore("air") + Math.min(14, involvement(["mercury", "asc"]) * 2) + balanceAdjustment / 2) },
    { id: "stability" as const, label: "\u7a33\u5b9a\u5efa\u8bbe", score: clampScore(elementScore("earth") + Math.min(14, involvement(["saturn", "jupiter"]) * 2) - balanceAdjustment / 2) },
  ];
  const dimensions = dimensionScores.map(d => ({ ...d, note: dimensionMeaning(d.id, d.score, "current_sky") }));

  const strongestDimension = [...dimensions].sort((a, b) => b.score - a.score)[0];
  const aspectCounts = weightedAspects.reduce((balance, item) => {
    if (supportiveAspectIds.has(item.aspect.type)) balance.supportive += 1;
    else if (tensionAspectIds.has(item.aspect.type)) balance.tension += 1;
    else balance.neutral += 1;
    return balance;
  }, { supportive: 0, tension: 0, neutral: 0 });

  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const topCross = cross.slice(0, 5);
  const ascPoint = returnSnapshot.result.points.find(p => p.point_id === "asc");

  const signals = topCross.map(a => ({
    id: a.aspect_id,
    title: `\u65e5\u8fd4${pointLabels[a.moving_point_id] ?? a.moving_point_id}${aspectLabels[a.type] ?? a.type}\u672c\u547d${pointLabels[a.reference_point_id] ?? a.reference_point_id}`,
    detail: crossAspectNarrative(a, "transit"),
    meaning: signalMeaning(a, "current_sky"),
    strength: a.strength,
  }));

  const title = ascPoint
    ? `\u65e5\u8fd4\u4e0a\u5347\u5728${signLabels[ascPoint.sign] ?? ascPoint.sign}\uff0c${rightPanel.topIndex.directionLabel}\u662f\u5e74\u5ea6\u4e3b\u8f74`
    : topCross.length > 0
      ? `\u65e5\u8fd4${pointLabels[topCross[0].moving_point_id] ?? topCross[0].moving_point_id}${aspectLabels[topCross[0].type] ?? topCross[0].type}\u672c\u547d${pointLabels[topCross[0].reference_point_id] ?? topCross[0].reference_point_id}`
      : "\u65e5\u8fd4\u76d8\u5e74\u5ea6\u89e3\u8bfb";

  const strengths = rightPanel.cards.slice(0, 3).map(c => corpusSentence(c.action, c.action));
  const reminders = rightPanel.cards.slice(0, 3).map(c => corpusSentence(c.caution, c.caution));

  return {
    title,
    summary: rightPanel.cards[0]?.summary ?? "\u65e5\u8fd4\u76d8\u5e74\u5ea6\u4e3b\u9898\u89e3\u8bfb",
    dimensions,
    aspectBalance: {
      supportive: aspectCounts.supportive,
      tension: aspectCounts.tension,
      neutral: aspectCounts.neutral,
      meaning: aspectCounts.supportive > aspectCounts.tension
        ? "\u652f\u6301\u6027\u76f8\u4f4d\u591a\u4e8e\u7d27\u5f20\u6027\uff0c\u6574\u4f53\u73af\u5883\u504f\u987a\u7545"
        : aspectCounts.tension > aspectCounts.supportive
          ? "\u7d27\u5f20\u6027\u76f8\u4f4d\u591a\u4e8e\u652f\u6301\u6027\uff0c\u9700\u8981\u4e3b\u52a8\u8c03\u8282"
          : "\u652f\u6301\u4e0e\u7d27\u5f20\u76f8\u4f4d\u5747\u8861\uff0c\u52a8\u6001\u5e73\u8861",
    },
    signals,
    strengths,
    reminders,
    closing: `\u65e5\u8fd4\u76d8\u7684\u5e74\u5ea6\u89e3\u8bfb\u57fa\u4e8e${rightPanel.topIndex.directionLabel}\u4e3b\u8f74\uff0c\u6307\u6570${rightPanel.topIndex.score}/100\u8868\u793a\u4e3b\u9898\u5bc6\u5ea6\uff0c\u4e0d\u8868\u793a\u4e8b\u4ef6\u6982\u7387\u3002`,
  };
}

// ─── 底部解读区段 ─────────────────────────────────────────

export function buildSolarReturnInterpretationSections(result: SolarReturnResult): InterpretationSection[] {
  const returnSnapshot = result.return_snapshot;
  const comparison = result.comparison;
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg).slice(0, 6);
  const crossCards = cross.map(a => ({
    id: a.aspect_id,
    title: `日返${pointLabels[a.moving_point_id] ?? a.moving_point_id} ${aspectLabels[a.type] ?? a.type} 本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`,
    subtitle: `强度 ${Math.round(a.strength * 100)} · ${a.applying_state === "applying" ? "正在接近" : a.applying_state === "exact" ? "正在精确" : "正在离开"}`,
    bullets: [crossAspectNarrative(a, "transit")],
  }));
  const houses = [...comparison.result.moving_points_in_reference_houses].slice(0, 8);
  const houseCards = houses.map(h => ({
    id: `house-${h.moving_point_id}`,
    title: `日返${pointLabels[h.moving_point_id] ?? h.moving_point_id} 落入本命第${h.reference_house}宫`,
    subtitle: h.on_cusp ? "贴近宫头" : "长期影响该领域",
    bullets: [houseNarrative(h.moving_point_id, h.reference_house, "transit")],
  }));
  const corePoints = returnSnapshot.result.points.filter(p => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(p.point_id));
  const planetCards = corePoints.map(p => ({
    id: `point-${p.point_id}`,
    title: `日返${pointLabels[p.point_id] ?? p.point_id}在${signLabels[p.sign] ?? p.sign}${p.house ? `第${p.house}宫` : ""}`,
    bullets: [pointNarrative(p, "日返")],
  }));
  const topAspects = [...returnSnapshot.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 6);
  const aspectCards = topAspects.map(a => ({
    id: a.aspect_id,
    title: `日返${pointLabels[a.point_a] ?? a.point_a} ${aspectLabels[a.type] ?? a.type} 日返${pointLabels[a.point_b] ?? a.point_b}`,
    subtitle: `容许度 ${a.orb_deg.toFixed(2)}°`,
    bullets: [aspectNarrative(a, "日返")],
  }));
  return [
    { id: "cross", label: "本命触发", cards: crossCards },
    { id: "reference_houses", label: "落宫", cards: houseCards },
    { id: "planets", label: "行星", cards: planetCards },
    { id: "aspects", label: "相位", cards: aspectCards },
  ];
}
