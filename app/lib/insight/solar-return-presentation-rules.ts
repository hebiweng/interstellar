/**
 * 日返盘展示规则
 * 定义10个模块的视觉、事实来源、文案规则和禁忌
 */

import type { CorpusEntry } from "./solar-return-corpus";

export type ModuleSpec = {
  id: string;
  title: string;
  icon: string;
  visual: string;
  facts: string[];
  copy: {
    summaryTemplate: string;
    detailMaxChars: number;
  };
  avoid: string[];
};

export const solarReturnPresentationRules: ModuleSpec[] = [
  {
    id: "annual-compass",
    title: "年度主轴罗盘",
    icon: "◉",
    visual: "四向年度罗盘",
    facts: ["日返上升、太阳、主星、四轴、年度主题评分"],
    copy: {
      summaryTemplate: "这一年最重要的主轴是【主题】，力量主要指向【方向】。",
      detailMaxChars: 140,
    },
    avoid: ["不把罗盘方向写成命运注定", "不用伪概率如80%会发生"],
  },
  {
    id: "monthly-rhythm",
    title: "12个月节律环",
    icon: "◎",
    visual: "十二月年环",
    facts: ["月份触发、行运叠加、月返评分、事件窗口"],
    copy: {
      summaryTemplate: "【月份】到【月份】是本年度最关键的节奏带。",
      detailMaxChars: 140,
    },
    avoid: ["不把深色月份直接解释成坏月", "不给出精确事件预测"],
  },
  {
    id: "quarterly-terrain",
    title: "四季度地形图",
    icon: "⛰",
    visual: "四季度地形坡度",
    facts: ["季度聚合分数、月份强度、阶段语料"],
    copy: {
      summaryTemplate: "最适合集中发力的是【季度】，最适合整理的是【季度】。",
      detailMaxChars: 140,
    },
    avoid: ["不把地形高度等同于运势好坏", "不忽略各阶段不同策略"],
  },
  {
    id: "domain-skyline",
    title: "年度领域天际线",
    icon: "▌",
    visual: "六座建筑天际线",
    facts: ["宫位权重、主星、角宫、年度主题聚合"],
    copy: {
      summaryTemplate: "今年你的主要资源会投向【领域1】、【领域2】和【领域3】。",
      detailMaxChars: 140,
    },
    avoid: ["不把高建筑理解为事件概率", "不把建筑高度等同于运势好坏"],
  },
  {
    id: "relationship-climate",
    title: "关系气候带",
    icon: "☵",
    visual: "关系气候色带",
    facts: ["金星、月亮、第7宫、关系主星、月份触发"],
    copy: {
      summaryTemplate: "这一年的关系气候会从【状态】逐步转向【状态】。",
      detailMaxChars: 140,
    },
    avoid: ["不写必然分手或必然成功", "不把气候等同于关系结果"],
  },
  {
    id: "career-ladder",
    title: "事业定位阶梯",
    icon: "▮",
    visual: "四级阶梯",
    facts: ["第10宫、MC、太阳、土星、木星、季度触发"],
    copy: {
      summaryTemplate: "事业发展更像【路径】，而不是一次性突破。",
      detailMaxChars: 140,
    },
    avoid: ["不把阶梯写成必然升级", "不跳过前置条件直接到高级"],
  },
  {
    id: "resource-pool",
    title: "资源蓄水池",
    icon: "◻",
    visual: "输入管道/水位/输出管道",
    facts: ["第2/8宫、金星木星土星、季度资源分数"],
    copy: {
      summaryTemplate: "本年度资源状态偏【累积/流动/消耗】，关键在【原因】。",
      detailMaxChars: 140,
    },
    avoid: ["不把消耗写成财务危机", "不给具体投资建议"],
  },
  {
    id: "pressure-bridge",
    title: "压力—机会桥",
    icon: "⌇",
    visual: "双岸转化桥",
    facts: ["压力相位、支持相位、行动语料、转化规则"],
    copy: {
      summaryTemplate: "今年最大的机会，来自把【压力】转化为【能力/结果】。",
      detailMaxChars: 140,
    },
    avoid: ["不把压力写灾难", "不给保证性结果承诺"],
  },
  {
    id: "commitment-tracker",
    title: "年度承诺追踪",
    icon: "◯",
    visual: "3个承诺进度板",
    facts: ["年度主题、用户记录、目标映射"],
    copy: {
      summaryTemplate: "本年度最值得坚持的承诺是【承诺】。",
      detailMaxChars: 140,
    },
    avoid: ["不代替用户设目标", "不把建议写成必须完成"],
  },
  {
    id: "action-route",
    title: "年度行动路线书",
    icon: "→",
    visual: "三段路线书",
    facts: ["综合年度评分、阶段语料、行动规则"],
    copy: {
      summaryTemplate: "这一年更适合按【节奏】推进，而不是一步到位。",
      detailMaxChars: 140,
    },
    avoid: ["不给具体日期事件预测", "不写必然成功或失败"],
  },
];

/** 解读优先级排序 */
export const interpretationPriority = [
  "日返上升与主星",
  "日返太阳/月亮落宫及相位",
  "日返四轴与本命轴线共振",
  "季度与关键月份叠加",
  "普通背景相位",
];

/** 全局禁忌 */
export const globalTaboos = [
  "不输出必然发生、一定成功、必定分手等确定性语言",
  "压力项必须给出调节出口",
  "支持项不得写成结果保证",
  "所有卡片应能追溯到 source_ids、rule_id 和 corpus_id",
  "不显示伪概率",
  "不把支持色等同于好运",
  "不把压力色写成灾难",
  "不用持续旋转、闪烁等高干扰动效",
];
