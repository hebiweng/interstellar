import type { NatalAspect, NatalSnapshot } from "./interstellar-api";

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
