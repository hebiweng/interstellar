/**
 * 日返盘核心语料数据
 * 豁免：纯数据文件，条目结构统一，拆分破坏完整性
 * 语料库版本：V1.0（对应 6-解读设计.md 2026-07-30）
 * 本文件：类型定义、年度主轴方向、四季阶段、月度节奏、六领域、
 *   关系气候、事业阶梯、资源状态、压力转化、承诺追踪、行动路线、
 *   信号评分、展示语料
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

// ─── 一、年度主轴方向语料 ─────────────────────────────────────

export const axisDirectionCorpus: Record<string, CorpusEntry> = {
  career: {
    id: '1-career', keywords: '事业主轴、公开角色、定位、成就',
    summary: '这一年最重要的主轴落在事业定位与公开角色，力量主要指向建立可持续的位置。',
    detail: '你会更在意自己被如何看见，也更需要把能力转化成稳定身份。关系与资源是辅助线，真正的核心是把能量集中到可见的位置上。',
    challenge: '事业主轴强时不等于所有精力都放工作，而是说这一年的主要结构变化最容易在职业和公共领域展开。',
    advice: '把核心精力放在职业结构上，同时为关系和资源留出辅助线。',
  },
  relationship: {
    id: '1-relationship', keywords: '关系主轴、伴侣、合作、亲密',
    summary: '这一年最重要的主轴落在关系与合作，力量主要指向建立或重新平衡重要关系。',
    detail: '你今年的核心变化最容易在关系领域展开。这包括亲密关系、重要合作和关键人际网络的重新调整。',
    challenge: '关系主轴强时，个人的独立目标容易被关系需求挤占，需要同时给自己和关系留出空间。',
    advice: '优先处理最重要的关系，但保留自己的方向线。合作的前提是有自己可贡献的。',
  },
  resource: {
    id: '1-resource', keywords: '资源主轴、金钱、时间、积累',
    summary: '这一年最重要的主轴落在资源积累与管理，力量主要指向建立和守护可用资源。',
    detail: '今年的核心变化最容易在资源和财务领域展开。你更关注什么值得投入、什么需要收紧。',
    challenge: '资源主轴强时容易过度关注安全感，可能把"稳妥"当成唯一标准。',
    advice: '资源管理不等于保守——在核心稳定的前提下，留出部分用于尝试新方向。',
  },
  inner: {
    id: '1-inner', keywords: '内在主轴、成长、心理、自我探索',
    summary: '这一年最重要的主轴落在内在成长，力量主要指向自我理解和内在结构。',
    detail: '今年的核心变化更多发生在内部。外部可能看起来没什么大事，但你对生活的理解、选择的依据正在发生变化。',
    challenge: '内在主轴强时不等于外部什么都不做，而是说关键变化首先发生在你的内在判断上。',
    advice: '适合投入学习、自我整理和内在梳理。外在节奏可以适度放慢，但不必完全停步。',
  },
  mixed: {
    id: '1-mixed', keywords: '多线主轴、多维、平衡',
    summary: '这一年主轴分散在多个方向，没有单一压倒性主题，力量需要在多条线之间分配。',
    detail: '不同领域同时被激活，很难只专注一个方向。管理好优先级比追求单一突破更重要。',
    challenge: '主轴不集中时不等于"没有主题"，而是需要在多条线索间分配注意力。',
    advice: '每季度选定一个核心方向，其他方向做最低维护。避免同时全线推进。',
  },
};

// ─── 二、四季阶段语料 ─────────────────────────────────────────

export const quarterPhaseCorpus: Record<string, CorpusEntry> = {
  Q1_foundation: {
    id: '2-Q1', keywords: '第一季度、建基、整理、起步',
    summary: '第一季度更适合建基，把当前状态整理清楚，为全年方向做准备。',
    detail: 'Q1适合整理旧事务、确认方向和调整结构。这时候推太急容易在根基不稳时消耗资源。',
    challenge: '建基期不等于什么都不做，而是选择性地整理和准备，避免过早冲刺。',
    advice: '把Q1当作全年节奏的起步阶段——整理、确认、调整优先级。',
  },
  Q2_accelerate: {
    id: '2-Q2', keywords: '第二季度、推进、加速、开始行动',
    summary: '第二季度开始加速，适合把准备好的方向往前推进。',
    detail: 'Q2适合正式启动、推进计划和扩大行动范围。上半年的准备在此时开始产出。',
    challenge: '加速期容易因为节奏加快而忽略细节，同时关注执行质量和推进速度。',
    advice: '在推进时保持节奏感——快速启动，稳步扩展，不要跳过关键步骤。',
  },
  Q3_peak: {
    id: '2-Q3', keywords: '第三季度、峰值、高峰、关键决定',
    summary: '第三季度进入全年峰值，最核心的变化和决定最容易在这段时间发生。',
    detail: 'Q3是全年信号最密集的阶段。外部事件和内在需求在这一时期同时放大。',
    challenge: '峰值期压力大，但也是全年最重要的窗口。高峰时不适合做不可逆决定，但适合确认方向。',
    advice: '利用高峰期确认方向和关键决定，给最极端的行动留出缓冲。',
  },
  Q4_consolidate: {
    id: '2-Q4', keywords: '第四季度、收束、整合、沉淀',
    summary: '第四季度适合收束和整合，把全年成果固化，为下一轮做准备。',
    detail: 'Q4的强度回落，更适合整理成果、修正结构和沉淀经验。',
    challenge: '收束期容易觉得"不够多"而继续冲刺，但真正的价值在于把已有成果稳定住。',
    advice: '把Q4当作整合期——收尾、总结和为下一轮蓄力。',
  },
};

// ─── 三、月度节奏语料 ─────────────────────────────────────────

export const monthRhythmCorpus: Record<string, CorpusEntry> = {
  peak: {
    id: '3-peak', keywords: '峰值月、高活跃、关键节点',
    summary: '信号密度最高的月份，全年最核心的变化最容易在此月展开。',
    detail: '行星触发和主题集中度在此月达到峰值。外部事件和内在感受都会更强烈。',
    challenge: '峰值月不等于一定发生大事，而是说这个月的主题集中度最高。',
    advice: '适合做关键决定，但给最极端的行动留出缓冲。',
  },
  turning: {
    id: '3-turning', keywords: '转折月、方向变化、切换',
    summary: '方向可能发生切换的月份，上半年的主题可能在此时开始转向。',
    detail: '新的行星触发点进入精确范围，主题从推进转向调整或从准备转向启动。',
    challenge: '转折月不一定有明确的转折事件，但内在方向会开始偏移。',
    advice: '注意捕捉内在方向的变化信号，但不必急着切换——让新方向自然浮现。',
  },
  buffer: {
    id: '3-buffer', keywords: '缓冲月、恢复、整理、低强度',
    summary: '相对平缓的月份，适合整理前期成果和恢复节奏。',
    detail: '没有强烈的新触发信号，主题以持续推进和微调为主。',
    challenge: '缓冲月不等于浪费时间，它是消化和沉淀的必要阶段。',
    advice: '利用缓冲月整理、复盘和为下一个高强度阶段做准备。',
  },
  moderate: {
    id: '3-moderate', keywords: '中等月、稳步推进、正常节奏',
    summary: '中等活跃月份，适合在当前方向上稳步推进。',
    detail: '信号强度适中，没有特别密集的触发，也没有完全安静。',
    challenge: '中等月份容易被忽略，但它是把方向落到实处的关键时间。',
    advice: '保持稳定节奏推进，不需要特别冲刺或特别收缩。',
  },
};

// ─── 四、六领域天际线语料 ─────────────────────────────────────

export const domainCorpus: Record<string, CorpusEntry> = {
  family: {
    id: '4-family', keywords: '家庭、居住、根基',
    summary: '家庭和居住事务会成为年度重要资源去向，时间和注意力被居住和亲情牵动。',
    detail: '搬家、装修、家人关系调整或居住需求变化都可能消耗较多精力。',
    challenge: '家庭领域高不代表其他领域不重要，而是说这块容易占用更多注意力。',
    advice: '给家庭事务划出专门处理时间，同时避免让它挤占其他领域的最低维护。',
  },
  relationship: {
    id: '4-relationship', keywords: '关系、合作、伴侣',
    summary: '关系和合作领域会成为年度重要资源去向，亲密关系和关键人际网络需要投入。',
    detail: '伴侣关系、重要合作和人际互动的频率和质量都会增加。',
    challenge: '关系领域高时，个人独立目标容易被合作需求调整。',
    advice: '在合作中保留自己的方向线，同时投入关系的质量维护。',
  },
  career: {
    id: '4-career', keywords: '事业、职业、公开角色',
    summary: '事业和职业领域会成为年度最大资源去向，时间和精力被公开角色和职业目标牵动。',
    detail: '职业方向调整、新角色承担、项目交付和行业声誉都可能是重点。',
    challenge: '事业领域最高时不等于一定要牺牲一切，而是说今年最核心的变化在这个领域展开。',
    advice: '把核心精力放在职业结构上，为其他领域留出最低维护。',
  },
  finance: {
    id: '4-finance', keywords: '金钱、收入、财务',
    summary: '金钱和财务领域今年需要特别关注，收入和支出的节奏会发生变化。',
    detail: '收入结构调整、新的财务责任或投资决策可能成为焦点。',
    challenge: '财务领域高时容易过度关注安全感，可能把"稳妥"当作唯一标准。',
    advice: '在核心稳定的前提下，留出部分用于尝试新方向。',
  },
  health: {
    id: '4-health', keywords: '健康、身体、日常节奏',
    summary: '健康和日常节奏需要主动维护，尤其在高压季度容易被忽视。',
    detail: '身体状态和生活习惯的调整需求增加，压力管理的重要性上升。',
    challenge: '健康领域不一定全年都高，但在高压季度会成为卡点。',
    advice: '提前在Q1和Q2建立健康基线，高压季度只需要维护即可。',
  },
  learning: {
    id: '4-learning', keywords: '学习、成长、视野',
    summary: '学习和成长领域今年有新的空间，新的知识和视野可能成为重要支撑。',
    detail: '学习计划、技能提升或视野扩展都可能在今年占更多比重。',
    challenge: '学习领域高时容易分散注意力，需要选定核心方向深入。',
    advice: '每半年选定一个学习主题深入，而不是同时展开多个方向。',
  },
};

// ─── 五、关系气候语料 ─────────────────────────────────────────

export const relationshipClimateCorpus: Record<string, CorpusEntry> = {
  calm: {
    id: '5-calm', keywords: '冷静、观望、低调',
    summary: '关系气候偏冷静，互动频率低，适合观察和整理关系需求。',
    detail: '这个阶段不太会有大的关系事件，更多是内在梳理和明确自己在关系中要什么。',
    challenge: '冷静期不等于关系停摆，而是在为下一阶段的互动做准备。',
    advice: '利用冷静期理清关系需求，不必强行推进互动。',
  },
  cloudy: {
    id: '5-cloudy', keywords: '多云、磨合、调整',
    summary: '关系气候偏多云，需要更多磨合和规则确认，互动中不确定感增加。',
    detail: '这个阶段容易在关系中出现意见分歧或边界不清晰的情况，但也是调整规则的好时机。',
    challenge: '多云期摩擦增加但不等于关系危机，适合调整而非退出。',
    advice: '主动澄清边界和期望，减少猜测空间。',
  },
  warming: {
    id: '5-warming', keywords: '转暖、互动增加、开放',
    summary: '关系气候逐步转暖，互动增加，合作和亲密的可能性上升。',
    detail: '这个阶段关系中的互动频率和质量都在提升，新关系可能开始，旧关系可能深化。',
    challenge: '转暖期互动增加时也容易过度投入，注意留出个人空间。',
    advice: '增加互动的同时保留自己的节奏，不必每次都全力响应。',
  },
  hot: {
    id: '5-hot', keywords: '高温、强烈、过热风险',
    summary: '关系气候进入高温期，互动最密集，但也容易过热和过度反应。',
    detail: '这个阶段关系中的情绪强度最高，正面和负面的表达都很直接。',
    challenge: '过热期容易在情绪驱动下做出不可逆的决定。',
    advice: '给最激烈的互动留出48小时缓冲，重要决定等情绪回落再做。',
  },
  stable: {
    id: '5-stable', keywords: '稳定、沉淀、可持续',
    summary: '关系气候进入稳定期，互动节奏可以持续，冲突减少。',
    detail: '这个阶段关系中的规则和节奏已经比较自然，不需要刻意调整。',
    challenge: '稳定期容易把"没有冲突"当作"没有问题"，忽视深层需求。',
    advice: '在稳定中检查：有没有被回避但仍在累积的小问题。',
  },
};

// ─── 六、事业阶梯语料 ─────────────────────────────────────────

export const careerLadderCorpus: Record<string, CorpusEntry> = {
  probe: {
    id: '6-probe', keywords: '试探、摸索、初步接触',
    summary: '事业发展处于试探阶段，正在摸索新的可能方向。',
    detail: '这个阶段不需要急着确定方向，更多是了解和体验不同的可能性。',
    challenge: '试探期过长容易变成原地踏步，需要设定决策时间点。',
    advice: '试探期3—6个月足够，之后选定一个方向进入定位阶段。',
  },
  position: {
    id: '6-position', keywords: '定位、确认方向、选择',
    summary: '事业发展进入定位阶段，正在确认核心方向并建立基本位置。',
    detail: '这个阶段需要做出选择——保留什么方向、放弃什么方向。',
    challenge: '定位期最怕"什么都想要"，需要取舍。',
    advice: '选定一个核心方向深入，其他方向做最低维护。',
  },
  assume: {
    id: '6-assume', keywords: '承担、扩大责任、深入',
    summary: '事业发展进入承担阶段，开始在选定方向上扩大责任和影响。',
    detail: '这个阶段你的角色会从参与者转向负责人，责任和可见度同时增加。',
    challenge: '承担期容易因为责任增加而分散注意力，需要保持核心方向。',
    advice: '在扩大责任时保持核心方向，避免因为"能做"而"什么都做"。',
  },
  visible: {
    id: '6-visible', keywords: '被看见、被认可、公开',
    summary: '事业发展进入"被看见"阶段，你的能力和成果开始被更多人认识。',
    detail: '这个阶段公共曝光和认可度都会增加，是之前积累的自然结果。',
    challenge: '"被看见"的前提是交付稳定，不是展示能力。',
    advice: '确保交付质量稳定后再接受更多曝光，否则会被放大缺点。',
  },
};

// ─── 七、资源状态语料 ─────────────────────────────────────────

export const resourcePoolCorpus: Record<string, CorpusEntry> = {
  accumulating: {
    id: '7-accumulating', keywords: '累积、增长、正净变化',
    summary: '本年度资源状态偏累积，输入大于输出，适合逐步扩大。',
    detail: '全年收入和支持的流入大于支出和消耗的流出，可以适度扩大投入。',
    challenge: '累积期容易过快投入多个方向，需要保留机动空间。',
    advice: '保留20%—30%的缓冲，不要把新增资源全部投出去。',
  },
  flowing: {
    id: '7-flowing', keywords: '流动、收支平衡、动态',
    summary: '本年度资源状态偏流动，输入和输出基本平衡，需要精细管理。',
    detail: '全年收入和支出的节奏比较接近，需要在特定季度注意平衡。',
    challenge: '流动期某一个季度输出增加就容易赤字，需要提前规划。',
    advice: '在Q1和Q2建立储备，应对Q3可能的输出高峰。',
  },
  draining: {
    id: '7-draining', keywords: '消耗、输出增加、储备下降',
    summary: '本年度资源状态偏消耗，输出大于输入，需要控制节奏和保留缓冲。',
    detail: '全年支出和消耗的压力大于新增收入和支持，需要主动管理节奏。',
    challenge: '消耗期不等于资源危机，但需要主动控制输出节奏。',
    advice: '优先保证核心方向，非核心支出适当收缩，同时寻找新的输入渠道。',
  },
};

// ─── 八、压力—机会转化语料 ─────────────────────────────────────

export const pressureOpportunityCorpus: Record<string, CorpusEntry> = {
  responsibility: {
    id: '8-responsibility', keywords: '责任增加、压力、事业负担',
    summary: '事业责任增加是全年最大压力，也是最重要的机会来源。',
    detail: '若只把它理解为负担，会越来越累；若借此建立流程、边界和判断权，它会转化成更稳定的位置。',
    challenge: '压力本身不会自动变成机会，需要主动调整应对方式。',
    advice: '把压力转成结构而非硬扛——建立流程、设定边界、分配决策权。',
  },
  conflict: {
    id: '8-conflict', keywords: '冲突、关系张力、意见分歧',
    summary: '关系冲突增加是压力来源，也是重新调整规则的机会。',
    detail: '冲突说明当前的互动规则需要更新，适合主动澄清边界和期望。',
    challenge: '冲突不会自己消失，但也不需要一次性解决所有问题。',
    advice: '每次冲突后检查：哪里需要调整规则，而不是只处理表面情绪。',
  },
  restriction: {
    id: '8-restriction', keywords: '限制、约束、条件',
    summary: '外在限制条件增加是压力，也是聚焦核心的机会。',
    detail: '限制条件迫使你放弃不必要的方向，把资源集中到真正重要的位置上。',
    challenge: '限制不等于没有空间，而是在更小的空间里做得更精。',
    advice: '把限制当作聚焦工具——它帮你筛选出真正重要的方向。',
  },
};

// ─── 九、行动路线语料 ─────────────────────────────────────────

export const actionRouteCorpus: Record<string, CorpusEntry> = {
  organize_first: {
    id: '9-organize', keywords: '先整理、建基、收束',
    summary: '这一年更适合先整理结构，为后续推进打好基础。',
    detail: '上半年需要先整理已有结构和资源，确认方向后再集中推进。如果急于证明结果，容易消耗在短期反馈上。',
    challenge: '先收后扩容易被误解为"什么都不做"，但整理本身就是行动。',
    advice: 'Q1—Q2整理和确认方向，Q3集中推进，Q4整合定型。',
  },
  expand_mid: {
    id: '9-expand', keywords: '中段推进、扩张、集中',
    summary: '中段是全年最重要的推进窗口，上半年准备、下半年定型。',
    detail: 'Q2—Q3是全年推进的黄金时段，这时候方向已经明确，资源也已经就位。',
    challenge: '中段推进期容易分散注意力，需要守住核心方向。',
    advice: '选定1—2个核心方向全力推进，其他方向做最低维护。',
  },
  finalize_late: {
    id: '9-finalize', keywords: '后期定型、沉淀、固化',
    summary: '后期适合把推进的成果固化为稳定结构，而不是继续扩张。',
    detail: 'Q4是整合和定型的阶段，把全年积累转化成可持续的位置和资源。',
    challenge: '定型期容易因为"不够多"而继续冲刺，但过度冲刺会透支下一年的储备。',
    advice: '把Q4当作整合期，收尾、总结和为下一轮蓄力。',
  },
};

// ─── 十、信号评分规则 ─────────────────────────────────────────

export const scoringRules = {
  /** 年度主轴评分公式说明 */
  formula: 'annual_score = angularity × ruler_weight × luminary_weight × natal_resonance × time_layer',
  /** 分数只用于排序、指数和视觉强度 */
  disclaimer: '分数只表示主题密度和结构清晰度，不表示事件发生概率。',
  /** 四向权重计算用的行星映射 */
  axisWeights: {
    career: { points: ['mc', 'saturn', 'jupiter', 'sun'], house: 10, label: '事业' },
    relationship: { points: ['dsc', 'venus', 'moon'], house: 7, label: '关系' },
    resource: { points: ['jupiter', 'venus'], house: [2, 8], label: '资源' },
    inner: { points: ['ic', 'moon', 'neptune'], house: [4, 12], label: '内在' },
  },
  /** 领域评分映射 */
  domainWeights: {
    family: { house: [4], points: ['moon', 'ic'] },
    relationship: { house: [7], points: ['venus', 'dsc'] },
    career: { house: [10], points: ['mc', 'saturn', 'jupiter', 'sun'] },
    finance: { house: [2, 8], points: ['venus', 'jupiter', 'pluto'] },
    health: { house: [6], points: ['mars', 'mercury'] },
    learning: { house: [3, 9], points: ['mercury', 'jupiter'] },
  },
} as const;

// ─── 十一、展示语料 ─────────────────────────────────────────

export const displayCorpus = {
  topIndex: {
    labelFormat: '{score}/100',
    subLabels: { density: '主题密度', clarity: '结构清晰' },
    stateLabels: {
      background: '背景',
      light: '轻度',
      active: '活跃',
      high: '高活跃',
      dense: '密集',
    },
  },
  cards: {
    A: { id: 'annual-compass', title: '年度主轴罗盘', icon: '◉' },
    B: { id: 'monthly-rhythm', title: '12个月节律环', icon: '◎' },
    C: { id: 'quarterly-terrain', title: '四季度地形图', icon: '⛰' },
    D: { id: 'domain-skyline', title: '年度领域天际线', icon: '▌' },
    E: { id: 'relationship-climate', title: '关系气候带', icon: '☵' },
    F: { id: 'career-ladder', title: '事业定位阶梯', icon: '▮' },
    G: { id: 'resource-pool', title: '资源蓄水池', icon: '◻' },
    H: { id: 'pressure-bridge', title: '压力—机会桥', icon: '⌇' },
    I: { id: 'commitment-tracker', title: '年度承诺追踪', icon: '◯' },
    J: { id: 'action-route', title: '年度行动路线书', icon: '→' },
  },
  emptyState: {
    noNatal: '需要先有本命数据才能展示年度解读。',
    noLocation: '缺少地点信息，宫位相关图表降级为行星/相位主题。',
    lowActivity: '当前年度信号强度偏低，处于背景期。主题以持续推进和微调为主。',
    insufficientData: '数据不足，部分图表以灰色占位显示。',
  },
  boundaryNote: '所有指数表示主题密度、结构清晰度或体感强度，不表示事件概率。',
  colorStates: {
    supportive: '#4ade80',
    tension: '#f87171',
    mixed: '#fbbf24',
    neutral: '#94a3b8',
  },
} as const;

// ─── 十二、日返升星座语料 ─────────────────────────────────────

export const solarReturnAscCorpus: Record<string, CorpusEntry> = {
  aries: { id: '12-aries', keywords: '年度起点、主动开局、快速启动', summary: '这一年倾向于主动开局，起点节奏快，适合迅速启动新方向。', detail: '日返上升白羊座意味着年度主基调偏向主动出击和先行一步，你更容易在新领域做出第一次尝试。' },
  taurus: { id: '12-taurus', keywords: '年度建基、稳扎稳打、积累', summary: '这一年倾向于稳步建基，适合在已有基础上做长期积累。', detail: '日返上升金牛座意味着年度主基调偏向务实和稳定建设，更适合巩固资源而非冒险扩张。' },
  gemini: { id: '12-gemini', keywords: '年度多元、信息驱动、灵活', summary: '这一年倾向于多元尝试，信息和沟通在年度节奏中占重要比重。', detail: '日返上升双子座意味着年度主基调偏向灵活和信息驱动，可能同时发展多个方向。' },
  cancer: { id: '12-cancer', keywords: '年度内聚、家庭关注、情绪基线', summary: '这一年内在需求和家庭事务是年度基线。', detail: '日返上升巨蟹座意味着年度主基调偏向内在安全感和家庭根基，居住和亲密关系的重要性上升。' },
  leo: { id: '12-leo', keywords: '年度表达、创造力、被看见', summary: '这一年表达和创造是重要线索，你更需要被认可和看见。', detail: '日返上升狮子座意味着年度主基调偏向创作和公共表达，个人项目和社会能见度增加。' },
  virgo: { id: '12-virgo', keywords: '年度整理、专业化、服务', summary: '这一年更适合精炼和专业化，把已有的东西打磨到位。', detail: '日返上升处女座意味着年度主基调偏向整理和服务，专业技能和工作质量的重要性上升。' },
  libra: { id: '12-libra', keywords: '年度关系、合作、平衡', summary: '这一年关系和合作是年度主线，你需要更多平衡和协商。', detail: '日返上升天秤座意味着年度主基调偏向关系和合作，合作事务的比重显著增加。' },
  scorpio: { id: '12-scorpio', keywords: '年度深度、转化、权力', summary: '这一年更适合深度投入和根本性调整，表面合作可能不够。', detail: '日返上升天蝎座意味着年度主基调偏向深度转化和权力议题，旧结构可能需要根本性重构。' },
  sagittarius: { id: '12-sagittarius', keywords: '年度扩展、视野、信念', summary: '这一年扩展视野和探索新可能性是重要线索。', detail: '日返上升射手座意味着年度主基调偏向学习、旅行和信念扩展，但对日常的容忍度可能下降。' },
  capricorn: { id: '12-capricorn', keywords: '年度结构、责任、目标', summary: '这一年事业和长期目标是年度核心，责任和结构建设最重要。', detail: '日返上升摩羯座意味着年度主基调偏向职业结构和社会角色，长期目标和公共形象的权重最高。' },
  aquarius: { id: '12-aquarius', keywords: '年度独立、创新、社群', summary: '这一年独立性和创新需求增强，传统路径的约束感可能增加。', detail: '日返上升水瓶座意味着年度主基调偏向独立和创新，新社群和非传统路径的吸引力增强。' },
  pisces: { id: '12-pisces', keywords: '年度融合、直觉、超越', summary: '这一年直觉和内在意义的需求增加，现实结构可能需要灵活调整。', detail: '日返上升双鱼座意味着年度主基调偏向内在融合和直觉，现实判断需要额外核实。' },
};
