export const secondaryRightPanelModules = [
  {
    id: "current-stage",
    title: "当前人生阶段",
    question: "阶段名称和一句话总结",
    visual: ["月相圆盘", "次限月亮星座进度条", "次限太阳星座进度条", "月亮/太阳阶段标签"],
    facts: ["progressed Moon sign/house/degree", "progressed Sun sign/house/degree", "lunar phase illumination"],
    copy: "阶段名 + 一句阶段结论；不解释模板，不写单日预测。",
    avoid: ["今日吉凶", "事件倒计时", "把进度条写成好坏分"],
  },
  {
    id: "change-themes",
    title: "三个长期变化主题",
    question: "身份定位/情绪需求/关系标准/事业方向/家庭角色/内在成熟中，哪三项最突出",
    visual: ["支持/挑战/中性色条", "三张主题小卡"],
    facts: ["progressed-to-natal aspect balance", "moving points in natal houses", "top cross aspects"],
    copy: "标题行固定为主题名 + 可复核事实标签（如本命第8宫）；下一行使用项目内语料库的一句结论。",
    avoid: ["只显示某星刑某星", "额外增加设计外的落宫河流条", "把数量解释成事件概率", "把弱相位硬凑成主题"],
  },
  {
    id: "turning-points",
    title: "核心转折点",
    question: "是否有月亮换座/换宫、太阳换座、精确相位、月相变化",
    visual: ["固定三行转折标记", "旧→新迁移箭头", "精确/过渡/平稳状态点"],
    facts: ["Moon degree near sign boundary", "Sun degree near sign boundary", "exact cross aspects", "phase near quarter points"],
    copy: "固定三行：核心相位槽、月亮阶段/换座槽、月相槽；核心相位要求次限点与本命点都属于右侧核心点集合；无强条件时显示平稳语料，不隐藏槽位。",
    avoid: ["强行制造转折", "让慢行星合自身抢核心槽位", "给虚假精确月份", "把换座直接断成外部事件"],
  },
  {
    id: "stage-advice",
    title: "当前阶段建议",
    question: "当前更适合识别、调整、整合还是长期建设",
    visual: ["行动方向标签", "固定三条图标建议列表"],
    facts: ["top aspect tone", "Moon/Sun corpus advice", "lunar phase advice"],
    copy: "适合推进/适合调整/适合整合 + 💭情绪关注、☀️长期方向、⚖️当前相位三条固定建议。",
    avoid: ["命令式恐吓", "每日行动分", "确定性结果承诺"],
  },
  {
    id: "natal-link",
    title: "与本命盘的关系",
    question: "哪些本命倾向正在被重新激活、被挑战或出现新的处理方式",
    visual: ["被强化/被挑战两列", "新出现的内在可能提示"],
    facts: ["supportive cross aspects", "tension cross aspects", "new progressed-natal combinations"],
    copy: "本命底图 × 次限移动层；先整合，再列来源。",
    avoid: ["把次限盘当新本命盘", "脱离本命结构解读", "重复右侧其他卡的原句"],
  },
] as const;

// 底部解读区本轮暂不作为实现范围，避免未完成的 tab 规则误导后续开发。
// 当前文件只约束右侧即时解读 A-E 卡片。

export const secondaryInterpretationPriority = [
  "次限月亮换座/换宫/精确相位",
  "次限太阳换座/精确相位",
  "次限月相变化",
  "多个次限信号共振指向同一主题",
  "次限行星与本命四轴的相位",
  "次限行星与本命个人行星的相位",
  "次限慢行星的长期位置变化",
] as const;
