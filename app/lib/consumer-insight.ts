import type { ChartComparison, NatalAspect, NatalPoint, NatalSnapshot, SecondaryProgressionResult } from "./interstellar-api";

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

const elementBySign: Record<string, "fire" | "earth" | "air" | "water"> = {
  aries: "fire", leo: "fire", sagittarius: "fire",
  taurus: "earth", virgo: "earth", capricorn: "earth",
  gemini: "air", libra: "air", aquarius: "air",
  cancer: "water", scorpio: "water", pisces: "water",
};

const pointLabels: Record<string, string> = {
  sun: "太阳", moon: "月亮", mercury: "水星", venus: "金星", mars: "火星",
  jupiter: "木星", saturn: "土星", uranus: "天王星", neptune: "海王星", pluto: "冥王星",
  asc: "上升", mc: "天顶", true_north_node: "北交点", mean_north_node: "北交点",
};

const aspectLabels: Record<string, string> = {
  conjunction: "紧密相连", opposition: "彼此拉扯", trine: "自然配合", square: "互相较劲", sextile: "互相帮忙",
};

const pointMeanings: Record<string, string> = {
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

const supportiveAspectIds = new Set(["trine", "sextile"]);
const tensionAspectIds = new Set(["square", "opposition", "quincunx", "semisquare", "sesquisquare"]);

function clampScore(value: number) {
  return Math.max(18, Math.min(92, Math.round(value)));
}

function aspectWeight(aspect: NatalAspect) {
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

function dimensionMeaning(id: ConsumerInsightDimension["id"], score: number, mode: "natal" | "current_sky") {
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

function signalMeaning(aspect: NatalAspect, mode: "natal" | "current_sky") {
  const left = pointMeanings[aspect.point_a] ?? "一种需要";
  const right = pointMeanings[aspect.point_b] ?? "另一种需要";
  const subject = mode === "natal" ? "你" : "这个时段";
  if (aspect.type === "trine" || aspect.type === "sextile") {
    return `${subject}在“${left}”和“${right}”之间比较容易找到配合。顺手并不等于自动发生，主动用起来才会变成真正的优势。`;
  }
  if (aspect.type === "square" || aspect.type === "opposition" || ["quincunx", "semisquare", "sesquisquare"].includes(aspect.type)) {
    return `${subject}会在“${left}”和“${right}”之间感到拉扯：顾到一边时，另一边容易不满意。它会制造压力，也会推动人寻找更成熟的处理办法。`;
  }
  if (aspect.type === "conjunction") {
    return `${subject}很难把“${left}”和“${right}”完全分开，两件事常常一起出现、彼此放大。用得好会很集中，过头时也容易只听见一个声音。`;
  }
  return `${subject}需要同时处理“${left}”和“${right}”。先看清两边各自要什么，会比急着下结论更有帮助。`;
}

export function buildNatalConsumerInsight(
  snapshot: NatalSnapshot,
  mode: "natal" | "current_sky" = "natal",
): ConsumerInsight {
  const corePoints = snapshot.result.points.filter((point) =>
    ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"].includes(point.point_id)
  );
  const elementCounts = { fire: 0, earth: 0, air: 0, water: 0 };
  for (const point of corePoints) {
    const element = elementBySign[point.sign];
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
    ? `这段时间最显眼的行运是${movingLabel(strongest.moving_point_id)}${aspectLabel(strongest.type)}本命${refLabel(strongest.reference_point_id)}。这会把外在的“${pointMeanings[strongest.moving_point_id] ?? "变化"}”和你命里的“${pointMeanings[strongest.reference_point_id] ?? "核心主题"}”勾到一起，是近期最值得留意的入口。`
    : base.summary;

  const signals = top.slice(0, 3).map((aspect) => {
    const moving = movingLabel(aspect.moving_point_id);
    const reference = refLabel(aspect.reference_point_id);
    const phase = aspect.applying_state === "exact" ? "目前非常明显" : aspect.applying_state === "applying" ? "影响正在接近" : "影响正在缓和";
    const templates: Record<string, string> = {
      conjunction: `行运${moving}正在合相你的本命${reference}：两件事暂时分不开，外在的“${pointMeanings[aspect.moving_point_id] ?? "变化"}”会直接点燃你命里的“${pointMeanings[aspect.reference_point_id] ?? "核心主题"}”。`,
      trine: `行运${moving}三分本命${reference}：这是比较容易找到资源的一段，外部变化会顺着你的内在节奏走，适合主动推进。`,
      sextile: `行运${moving}六分本命${reference}：机会型触发，需要你主动搭把手，才会从“可能”变成“真的有用”。`,
      square: `行运${moving}刑克本命${reference}：两种需求会互相较劲，你容易在“${pointMeanings[aspect.moving_point_id] ?? "外部变化"}”和“${pointMeanings[aspect.reference_point_id] ?? "自身需要"}”之间感到拉扯。`,
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
      meaning: `行运${movingLabel(h.moving_point_id)}正在经过你的本命第${h.reference_house}宫（${houseDomain(h.reference_house)}），这会把“${pointMeanings[h.moving_point_id] ?? "外部变化"}”的主题带到你的现实生活中。`,
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
  const closing = `行运盘显示的是当前天空和你本命之间的互动。重点不是“会发生什么事”，而是“哪些主题被点亮了”，以及你准备怎么回应。`;

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

export function buildSecondaryProgressionConsumerInsight(
  result: SecondaryProgressionResult,
  _latestNatalSnapshot: NatalSnapshot,
): ConsumerInsight {
  const progressed = result.progressed_snapshot;
  const comparison = result.comparison;
  const base = buildNatalConsumerInsight(progressed, "current_sky");
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
    : base.summary;

  const signals = top.slice(0, 3).map((aspect) => {
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

  if (progressedMoon) {
    signals.unshift({
      id: "progressed-moon",
      title: `次限月亮在${progressedMoon.sign}`,
      detail: "情绪基调正在转变",
      meaning: `次限月亮走到${progressedMoon.sign}，接下来一段时间你的情绪需求和被照顾的方式会偏向这个星座的特质。`,
      strength: 88,
    });
  }

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
    : base.strengths;
  const reminders = [
    progressedSun ? `次限太阳在${progressedSun.sign}，长期目标和自我表达的方向正在转向这个星座的特质。` : "次限盘反映的是长期趋势，不是单一日期的突发事件。",
    "次限的变化通常以年为单位，给它一些时间，观察主题如何展开。",
  ];
  const closing = "次限盘像一条慢速播放的成长线。它不会说今天会发生什么，但能说明你现在处在哪一段长期主题里。";

  return {
    ...base,
    title,
    summary,
    signals: signals.slice(0, 4),
    strengths,
    reminders,
    closing,
  };
}

// Consumer-friendly interpretation cards for non-natal charts

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

const signLabels: Record<string, string> = {
  aries: "白羊座", taurus: "金牛座", gemini: "双子座", cancer: "巨蟹座",
  leo: "狮子座", virgo: "处女座", libra: "天秤座", scorpio: "天蝎座",
  sagittarius: "射手座", capricorn: "摩羯座", aquarius: "水瓶座", pisces: "双鱼座",
};

const signThemes: Record<string, string> = {
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

const houseLabels: Record<number, string> = {
  1: "自我、形象和出发方式", 2: "价值、资源和安全感", 3: "沟通、学习和日常",
  4: "家庭、根基和情绪", 5: "创造、玩乐和恋爱", 6: "工作、健康和习惯",
  7: "关系、合作和伴侣", 8: "共有资源、转化和危机", 9: "远行、信念和高等教育",
  10: "事业、公共形象和成就", 11: "社群、未来和理想", 12: "内在、释放和潜意识",
};

const pointThemes: Record<string, string> = {
  sun: "核心意志和自我表达", moon: "情绪需求和安全感", mercury: "思考和沟通方式",
  venus: "关系和价值观", mars: "行动和冲动", jupiter: "成长和信念",
  saturn: "责任和限制", uranus: "变化和突破", neptune: "想象和理想化",
  pluto: "深层转化", asc: "外在形象和起点", mc: "事业和公共目标",
  true_north_node: "成长方向", mean_north_node: "成长方向",
};

const aspectThemes: Record<string, string> = {
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

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function pointNarrative(point: NatalPoint, prefix = ""): string {
  const pointName = pointLabels[point.point_id] ?? point.point_id;
  const sign = signLabels[point.sign] ?? point.sign;
  const signTheme = signThemes[point.sign] ?? "强调当前主题";
  const house = point.house ? `第${point.house}宫（${houseLabels[point.house]}）` : "";
  const retro = point.retrograde ? "当前逆行，相关主题适合先回顾、再推进。" : "";
  return `${prefix}${pointName}落在${sign}${house ? "，" + house : ""}，${signTheme}。${retro}`;
}

function aspectNarrative(aspect: NatalAspect, prefix = ""): string {
  const a = pointLabels[aspect.point_a] ?? aspect.point_a;
  const b = pointLabels[aspect.point_b] ?? aspect.point_b;
  const typeTheme = aspectThemes[aspect.type] ?? "形成联系";
  const phase = aspect.applying_state === "applying" ? "正在增强" : aspect.applying_state === "exact" ? "正在精确" : aspect.applying_state === "separating" ? "正在减弱" : "当前阶段较平稳";
  return `${prefix}${a}与${b}${typeTheme}。影响${phase}，容许度 ${aspect.orb_deg.toFixed(2)}°。`;
}

function crossAspectNarrative(aspect: NatalAspect & { moving_point_id: string; reference_point_id: string }, context: "transit" | "progression"): string {
  const moving = pointLabels[aspect.moving_point_id] ?? aspect.moving_point_id;
  const ref = pointLabels[aspect.reference_point_id] ?? aspect.reference_point_id;
  const typeTheme = aspectThemes[aspect.type] ?? "形成联系";
  const phase = aspect.applying_state === "applying" ? "正在接近" : aspect.applying_state === "exact" ? "正在精确触发" : aspect.applying_state === "separating" ? "正在离开" : "当前阶段较平稳";
  const prefix = context === "progression" ? "次限" : "行运";
  return `${prefix}${moving}正在${phase}你命中的${ref}，${typeTheme}。`;
}

function houseNarrative(pointId: string, houseNumber: number, context: "current_sky" | "transit" | "progression"): string {
  const pointName = pointLabels[pointId] ?? pointId;
  const house = houseLabels[houseNumber] ?? `第${houseNumber}宫`;
  const prefix = context === "current_sky" ? "" : context === "transit" ? "行运" : "次限";
  return `${prefix}${pointName}的行程正把你的注意力带到${house}领域。`;
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
