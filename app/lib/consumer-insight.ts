import type { ChartComparison, NatalSnapshot } from "./interstellar-api";
import {
  type ConsumerInsightDimension,
  type ConsumerInsight,
  type InterpretationCard,
  type InterpretationSection,
  pointLabels, aspectLabels, pointMeanings,
  supportiveAspectIds, tensionAspectIds,
  clampScore, aspectWeight, dimensionMeaning, signalMeaning,
  asRecord, pointNarrative, aspectNarrative, crossAspectNarrative, houseNarrative,
  signLabels, houseLabels,
} from "./insight/shared";

// Re-export types for backward compatibility (other components import from here)
export type { ConsumerInsightDimension, ConsumerInsight, InterpretationCard, InterpretationSection };

export function buildNatalConsumerInsight(
  snapshot: NatalSnapshot,
  mode: "natal" | "current_sky" = "natal",
): ConsumerInsight {
  const corePoints = snapshot.result.points.filter((point) =>
    ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"].includes(point.point_id)
  );
  const elementCounts = { fire: 0, earth: 0, air: 0, water: 0 };
  for (const point of corePoints) {
    const element = { aries: "fire", leo: "fire", sagittarius: "fire", taurus: "earth", virgo: "earth", capricorn: "earth", gemini: "air", libra: "air", aquarius: "air", cancer: "water", scorpio: "water", pisces: "water" }[point.sign] as "fire" | "earth" | "air" | "water" | undefined;
    if (element) elementCounts[element] += point.point_id === "sun" || point.point_id === "moon" ? 2 : 1;
  }
  const totalElements = Math.max(1, Object.values(elementCounts).reduce((sum, count) => sum + count, 0));
  const elementScore = (element: keyof typeof elementCounts) => 34 + elementCounts[element] / totalElements * 96;

  const weightedAspects = snapshot.result.aspects.map((aspect) => ({
    aspect,
    weight: aspectWeight(aspect),
  }));
  const aspectCounts = weightedAspects.reduce((balance, item) => {
    if (supportiveAspectIds.has(item.aspect.type)) balance.supportive += 1;
    else if (tensionAspectIds.has(item.aspect.type)) balance.tension += 1;
    else balance.neutral += 1;
    return balance;
  }, { supportive: 0, tension: 0, neutral: 0 });

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

  const dimensionScores: Array<Omit<ConsumerInsightDimension, "note">> = [
    {
      id: "action",
      label: "行动推进",
      score: clampScore(elementScore("fire") + Math.min(14, involvement(["mars", "sun"]) * 2) + balanceAdjustment),
    },
    {
      id: "emotion",
      label: "情绪感受",
      score: clampScore(elementScore("water") + Math.min(14, involvement(["moon", "venus"]) * 2)),
    },
    {
      id: "expression",
      label: "沟通表达",
      score: clampScore(elementScore("air") + Math.min(14, involvement(["mercury", "asc"]) * 2) + balanceAdjustment / 2),
    },
    {
      id: "stability",
      label: "稳定建设",
      score: clampScore(elementScore("earth") + Math.min(14, involvement(["saturn", "jupiter"]) * 2) - balanceAdjustment / 2),
    },
  ];
  const dimensions = dimensionScores.map((dimension) => ({
    ...dimension,
    note: dimensionMeaning(dimension.id, dimension.score, mode),
  }));

  const strongestDimension = [...dimensions].sort((left, right) => right.score - left.score)[0];

  const signals = [...weightedAspects]
    .sort((left, right) => right.weight - left.weight)
    .slice(0, 3)
    .map(({ aspect }) => ({
      id: aspect.aspect_id,
      title: `${pointLabels[aspect.point_a] ?? aspect.point_a} ${aspectLabels[aspect.type] ?? aspect.type} ${pointLabels[aspect.point_b] ?? aspect.point_b}`,
      detail: `${aspect.applying_state === "applying" ? "影响正在变得明显" : aspect.applying_state === "separating" ? "影响已经开始缓和" : aspect.applying_state === "exact" ? "目前非常明显" : "当前阶段较平稳"}`,
      meaning: signalMeaning(aspect, mode),
      strength: Math.round(aspect.strength * 100),
    }));

  const sortedDimensions = [...dimensions].sort((left, right) => right.score - left.score);
  const strongestTwo = sortedDimensions.slice(0, 2);
  const gentlest = sortedDimensions.at(-1) ?? sortedDimensions[0];
  const balanceMeaning = aspectCounts.tension > aspectCounts.supportive
    ? mode === "natal"
      ? "盘里需要协调的地方比较多。你可能常在矛盾中成长：事情不一定省力，但压力也会逼着你练出解决问题的能力。"
      : "这个时段需要协调的事情比较多，推进时容易遇到不同方向的要求。先排优先级，比同时满足所有人更有效。"
    : aspectCounts.supportive > aspectCounts.tension
      ? mode === "natal"
        ? "盘里互相帮得上忙的地方比较多。你更容易找到顺手的做法，但太熟悉的优势也可能被当成理所当然。"
        : "这个时段不同力量比较容易配合，适合沟通、整合资源和把已有计划往前推。"
      : mode === "natal"
        ? "顺手和费力的部分比较均衡。你既有自然会做的事，也有需要慢慢练习的地方，关键是知道什么时候该顺势、什么时候该调整。"
        : "这个时段既有顺势的部分，也有需要协调的部分。稳住节奏、边做边看，比一开始就追求完美更实际。";

  return {
    title: mode === "natal"
      ? strongestDimension.score >= 72 ? "你的做事风格很有重点" : "你会在几种不同节奏之间切换"
      : strongestDimension.score >= 72 ? "这个时段的主旋律比较清楚" : "这个时段有几股力量同时在走",
    summary: mode === "natal"
      ? `${strongestDimension.label}是盘里最醒目的部分。简单说，你更容易从这条路开始处理问题；这不是能力高低，而是你最常用、也最容易被别人看见的方式。`
      : `${strongestDimension.label}是这个时段最明显的倾向。它描述公共天空的节奏，不代表每个人都会发生同一件事。`,
    dimensions,
    aspectBalance: { ...aspectCounts, meaning: balanceMeaning },
    signals,
    strengths: strongestTwo.map((dimension) =>
      mode === "natal"
        ? `${dimension.label}比较突出。把它用在合适的事情上，你更容易进入状态，也更容易让别人理解你的长处。`
        : `${dimension.label}较明显。适合顺着这个节奏安排对应的沟通、行动或整理工作。`
    ),
    reminders: [
      mode === "natal"
        ? `${gentlest.label}不是短板，只是它通常不会自动跑到最前面。遇到需要它的场合，给自己多一点准备时间就够了。`
        : `${gentlest.label}相对安静。这个时段若需要这部分能力，最好提前安排，不要只靠临场发挥。`,
      aspectCounts.tension
        ? mode === "natal" ? "感到内在拉扯时，不必急着选边站；先分别说清两边真正需要什么。" : "事情互相打架时，先定优先级，再逐项推进。"
        : mode === "natal" ? "做得顺手的事也值得认真经营，不要因为来得自然就低估它。" : "节奏顺的时候适合把关键步骤做实，别只停在讨论。",
    ],
    closing: mode === "natal"
      ? "把这张盘当作一份使用说明：它告诉你哪些反应比较自然、哪些地方需要多一点练习。真正的选择仍然在你手里。"
      : "天象盘描述的是这个时刻的大环境，不是个人预言。要判断它对某个人的具体影响，需要再与那个人的本命盘比较。",
  };
}

export function buildCurrentSkyConsumerInsight(snapshot: NatalSnapshot): ConsumerInsight {
  const base = buildNatalConsumerInsight(snapshot, "current_sky");
  const labels: Record<ConsumerInsightDimension["id"], string> = {
    action: "启动能量",
    emotion: "感受氛围",
    expression: "信息流动",
    stability: "落地节奏",
  };
  const strongest = [...base.dimensions].sort((left, right) => right.score - left.score)[0];
  const strongestLabel = labels[strongest.id];
  return {
    ...base,
    title: strongest.score >= 72 ? `${strongestLabel}较为集中` : "多股天象节奏同时展开",
    summary: `${strongestLabel}是这个时刻最明显的节奏。下面直接说明它适合怎样安排事情、哪里容易卡住；这仍然是公共天空，不是个人事件预言。`,
    dimensions: base.dimensions.map((dimension) => ({
      ...dimension,
      label: labels[dimension.id],
    })),
  };
}

export function buildTransitConsumerInsight(
  comparison: ChartComparison,
  _latestNatalSnapshot: NatalSnapshot,
  movingLayer: NatalSnapshot,
): ConsumerInsight {
  const base = buildNatalConsumerInsight(movingLayer, "current_sky");
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg);
  const top = cross.slice(0, 5);
  const houses = [...comparison.result.moving_points_in_reference_houses]
    .filter((h) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(h.moving_point_id))
    .slice(0, 6);
  const strongest = top[0];

  const movingLabel = (id: string) => pointLabels[id] ?? id;
  const refLabel = (id: string) => pointLabels[id] ?? id;
  const aspectLabel = (type: string) => aspectLabels[type] ?? type;
  const houseDomain = (n: number) => {
    const domains = ["自我与起点", "价值与资源", "交流与日常", "家庭与根基", "创造与表达", "工作与健康", "关系与伴侣", "共有资源与转化", "远行与信念", "事业与公共形象", "社群与未来", "内在与释放"];
    return domains[n - 1] ?? `第${n}宫`;
  };

  const title = strongest
    ? `${movingLabel(strongest.moving_point_id)}${aspectLabel(strongest.type)}本命${refLabel(strongest.reference_point_id)}`
    : base.title;
  const summary = strongest
    ? `这段时间最显眼的行运是${movingLabel(strongest.moving_point_id)}${aspectLabel(strongest.type)}本命${refLabel(strongest.reference_point_id)}。这会把外在的"${pointMeanings[strongest.moving_point_id] ?? "变化"}"和你命里的"${pointMeanings[strongest.reference_point_id] ?? "核心主题"}"勾到一起，是近期最值得留意的入口。`
    : base.summary;

  const signals = top.slice(0, 3).map((aspect) => {
    const moving = movingLabel(aspect.moving_point_id);
    const reference = refLabel(aspect.reference_point_id);
    const phase = aspect.applying_state === "exact" ? "目前非常明显" : aspect.applying_state === "applying" ? "影响正在接近" : "影响正在缓和";
    const templates: Record<string, string> = {
      conjunction: `行运${moving}正在合相你的本命${reference}：两件事暂时分不开，外在的"${pointMeanings[aspect.moving_point_id] ?? "变化"}"会直接点燃你命里的"${pointMeanings[aspect.reference_point_id] ?? "核心主题"}"。`,
      trine: `行运${moving}三分本命${reference}：这是比较容易找到资源的一段，外部变化会顺着你的内在节奏走，适合主动推进。`,
      sextile: `行运${moving}六分本命${reference}：机会型触发，需要你主动搭把手，才会从"可能"变成"真的有用"。`,
      square: `行运${moving}刑克本命${reference}：两种需求会互相较劲，你容易在"${pointMeanings[aspect.moving_point_id] ?? "外部变化"}"和"${pointMeanings[aspect.reference_point_id] ?? "自身需要"}"之间感到拉扯。`,
      opposition: `行运${moving}对冲本命${reference}：关系或外部事件会把矛盾摆到台面上，需要你在对立面之间做协调。`,
    };
    return {
      id: aspect.aspect_id,
      title: `${moving} ${aspectLabel(aspect.type)} 本命${reference}`,
      detail: phase,
      meaning: templates[aspect.type] ?? `行运${moving}正在${aspectLabel(aspect.type)}你的本命${reference}：这是近期值得关注的触发。`,
      strength: Math.round(aspect.strength * 100),
    };
  });

  if (houses.length > 0) {
    const h = houses[0];
    signals.push({
      id: `house-${h.moving_point_id}`,
      title: `${movingLabel(h.moving_point_id)}落入本命第${h.reference_house}宫`,
      detail: h.on_cusp ? "贴近宫头，影响力更强" : "已进入该生活领域",
      meaning: `行运${movingLabel(h.moving_point_id)}正在经过你的本命第${h.reference_house}宫（${houseDomain(h.reference_house)}），这会把"${pointMeanings[h.moving_point_id] ?? "外部变化"}"的主题带到你的现实生活中。`,
      strength: h.on_cusp ? 92 : 70,
    });
  }

  const supportiveCount = cross.filter((a) => supportiveAspectIds.has(a.type)).length;
  const tensionCount = cross.filter((a) => tensionAspectIds.has(a.type)).length;
  const balanceMeaning = supportiveCount > tensionCount
    ? "跨盘相位里顺手的比较多，适合借势推进、沟通合作。"
    : tensionCount > supportiveCount
      ? "跨盘相位里需要协调的比较多，近期遇到对抗时先排优先级。"
      : "顺势与压力比较均衡，边做边看会更稳。";

  const strengths = top.length > 0
    ? [`${movingLabel(top[0].moving_point_id)}与${refLabel(top[0].reference_point_id)}的触发最近，值得优先观察。`]
    : base.strengths;
  const reminders = [
    houses.length > 0 ? `${movingLabel(houses[0].moving_point_id)}进入本命第${houses[0].reference_house}宫，留意这个领域是否开始冒出新事务。` : "行运不只是触发，也要看落到哪个生活领域。",
    "单个相位不代表事件结论，结合现实处境和你自己的选择才有意义。",
  ];
  const closing = `行运盘显示的是当前天空和你本命之间的互动。重点不是"会发生什么事"，而是"哪些主题被点亮了"，以及你准备怎么回应。`;

  return {
    ...base,
    title,
    summary,
    signals: signals.slice(0, 4),
    aspectBalance: { ...base.aspectBalance, meaning: balanceMeaning },
    strengths,
    reminders,
    closing,
  };
}

function buildEventSection(snapshot: NatalSnapshot): InterpretationSection {
  const context = asRecord(snapshot.result.astronomical_context);
  const lunarPhase = asRecord(context.lunar_phase);
  const phase = String(lunarPhase.phase ?? "—");
  const illumination = Math.round(Number(lunarPhase.illumination_fraction ?? 0) * 100);
  const age = Number(lunarPhase.lunar_age_days ?? 0).toFixed(1);
  const retrogradePoints = snapshot.result.points.filter((p) => p.retrograde).map((p) => pointLabels[p.point_id] ?? p.point_id);
  const stationaryPoints = snapshot.result.points.filter((p) => p.position.motion_state === "stationary").map((p) => pointLabels[p.point_id] ?? p.point_id);
  const cards: InterpretationCard[] = [];
  cards.push({
    id: "lunar-phase",
    title: "月相",
    subtitle: `亮面约 ${illumination}% · 月龄 ${age} 天`,
    bullets: [`当前月相为 ${phase}。`, `月亮快速移动，月相描述的是短期周期与情绪节奏。`],
  });
  if (retrogradePoints.length) {
    cards.push({ id: "retrograde", title: "逆行行星", bullets: [`${retrogradePoints.join("、")} 正在逆行。`, `逆行期间适合回顾、修正、重新评估，而非强行启动。`] });
  }
  if (stationaryPoints.length) {
    cards.push({ id: "stationary", title: "停驻点位", bullets: [`${stationaryPoints.join("、")} 接近停驻。`, `行星停驻前后状态转换较明显，容易带来开始、转折或收尾。`] });
  }
  const strongest = [...snapshot.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 3);
  if (strongest.length) {
    cards.push({ id: "strongest-aspects", title: "最紧密相位", bullets: strongest.map((a) => aspectNarrative(a)) });
  }
  return { id: "events", label: "天象", cards };
}

export function buildCurrentSkyInterpretationSections(snapshot: NatalSnapshot): InterpretationSection[] {
  const corePoints = snapshot.result.points.filter((p) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(p.point_id));
  const planetCards = corePoints.map((p) => ({
    id: `point-${p.point_id}`,
    title: `${pointLabels[p.point_id] ?? p.point_id}在${signLabels[p.sign] ?? p.sign}${p.house ? `第${p.house}宫` : ""}`,
    subtitle: p.retrograde ? "当前逆行" : undefined,
    bullets: [pointNarrative(p)],
  }));
  const topAspects = [...snapshot.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 6);
  const aspectCards = topAspects.map((a) => ({
    id: a.aspect_id,
    title: `${pointLabels[a.point_a] ?? a.point_a} ${aspectLabels[a.type] ?? a.type} ${pointLabels[a.point_b] ?? a.point_b}`,
    subtitle: `容许度 ${a.orb_deg.toFixed(2)}° · 强度 ${Math.round(a.strength * 100)}`,
    bullets: [aspectNarrative(a)],
  }));
  const houseCards = snapshot.result.houses
    .filter((h) => h.point_ids.length > 0)
    .map((h) => ({
      id: `house-${h.number}`,
      title: `第${h.number}宫 · ${signLabels[h.sign] ?? h.sign}`,
      subtitle: `${h.point_ids.length} 个点位`,
      bullets: h.point_ids.map((pid) => `${pointLabels[pid] ?? pid} 落在这里`),
      emphasis: houseLabels[h.number],
    }));
  return [
    { id: "planets", label: "行星", cards: planetCards },
    { id: "houses", label: "宫位", cards: houseCards },
    { id: "aspects", label: "相位", cards: aspectCards },
    buildEventSection(snapshot),
  ];
}

export function buildTransitInterpretationSections(comparison: ChartComparison, movingLayer: NatalSnapshot): InterpretationSection[] {
  const cross = [...comparison.result.cross_aspects].sort((a, b) => b.strength - a.strength || a.orb_deg - b.orb_deg).slice(0, 6);
  const crossCards = cross.map((a) => ({
    id: a.aspect_id,
    title: `行运${pointLabels[a.moving_point_id] ?? a.moving_point_id} ${aspectLabels[a.type] ?? a.type} 本命${pointLabels[a.reference_point_id] ?? a.reference_point_id}`,
    subtitle: `强度 ${Math.round(a.strength * 100)} · ${a.applying_state === "applying" ? "正在接近" : a.applying_state === "exact" ? "正在精确" : "正在离开"}`,
    bullets: [crossAspectNarrative(a, "transit")],
  }));
  const houses = [...comparison.result.moving_points_in_reference_houses].slice(0, 8);
  const houseCards = houses.map((h) => ({
    id: `house-${h.moving_point_id}`,
    title: `行运${pointLabels[h.moving_point_id] ?? h.moving_point_id} 落入本命第${h.reference_house}宫`,
    subtitle: h.on_cusp ? "贴近宫头" : "已进入该领域",
    bullets: [houseNarrative(h.moving_point_id, h.reference_house, "transit")],
  }));
  const corePoints = movingLayer.result.points.filter((p) => ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"].includes(p.point_id));
  const planetCards = corePoints.map((p) => ({
    id: `point-${p.point_id}`,
    title: `行运${pointLabels[p.point_id] ?? p.point_id}在${signLabels[p.sign] ?? p.sign}${p.house ? `第${p.house}宫` : ""}`,
    subtitle: p.retrograde ? "当前逆行" : undefined,
    bullets: [pointNarrative(p, "行运")],
  }));
  const topAspects = [...movingLayer.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 6);
  const aspectCards = topAspects.map((a) => ({
    id: a.aspect_id,
    title: `行运${pointLabels[a.point_a] ?? a.point_a} ${aspectLabels[a.type] ?? a.type} 行运${pointLabels[a.point_b] ?? a.point_b}`,
    subtitle: `容许度 ${a.orb_deg.toFixed(2)}°`,
    bullets: [aspectNarrative(a, "行运")],
  }));
  return [
    { id: "cross", label: "本命触发", cards: crossCards },
    { id: "reference_houses", label: "落宫", cards: houseCards },
    { id: "planets", label: "行星", cards: planetCards },
    { id: "aspects", label: "相位", cards: aspectCards },
  ];
}
