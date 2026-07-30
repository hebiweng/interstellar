/**
 * 年度小限盘 insight builder
 * 从本命盘快照的 profections 数据中提取事实，选择语料，构建右侧即时解读卡片。
 * 服务器提供权威事实（宫位、星座、时间主星、年龄、日期范围），客户端负责选择语料和展示。
 */

import type { NatalSnapshot } from "../interstellar-api";
import { asRecord, asRecords } from "../../components/lib/chart-utils";
import { pointNames, signNames } from "../../components/lib/chart-constants";
import {
  type ProfectionsRightPanel,
  houseDomains,
  timeLordThemes,
  rightPanelDisplayCorpus,
} from "./annual-profections-corpus";

export type { ProfectionsRightPanel } from "./annual-profections-corpus";

function corpusSentence(text: string | undefined, fallback: string): string {
  return (text ?? fallback).split(/[。；]/)[0].replace(/：$/, "").trim();
}

/**
 * 判断年度在生日年中的位置
 */
function yearPosition(fraction: number): "yearStart" | "yearMid" | "yearEnd" {
  if (fraction < 0.33) return "yearStart";
  if (fraction < 0.66) return "yearMid";
  return "yearEnd";
}

/**
 * 根据时间主星判断年度调性
 */
function yearTone(lordIds: unknown): string {
  const lords = Array.isArray(lordIds) ? lordIds.map(String) : [];
  if (lords.includes("saturn")) return rightPanelDisplayCorpus.toneLabels.structured;
  if (lords.includes("jupiter") || lords.includes("venus")) return rightPanelDisplayCorpus.toneLabels.expansive;
  if (lords.includes("mars") || lords.includes("sun")) return rightPanelDisplayCorpus.toneLabels.active;
  if (lords.includes("moon")) return rightPanelDisplayCorpus.toneLabels.reflective;
  return rightPanelDisplayCorpus.toneLabels.steady;
}

export function buildProfectionsRightPanel(
  snapshot: NatalSnapshot,
): ProfectionsRightPanel {
  const result = asRecord(snapshot.result);
  const profections = asRecords(asRecord(result.profections).periods);
  const cards: ProfectionsRightPanel["cards"] = [];

  /* Current period data */
  const currentPeriod = profections.find((p) => p.current);
  const activatedHouse = Number(currentPeriod?.activated_house ?? 0);
  const activatedSign = String(currentPeriod?.activated_sign ?? "");
  const timeLordIds = currentPeriod?.time_lord_ids;
  const age = Number(currentPeriod?.age ?? 0);

  // ── Card A: 当前年份 ──
  const cardADetails: string[] = [];
  const houseTheme = houseDomains[activatedHouse];
  if (houseTheme) {
    cardADetails.push(houseTheme.summary);
    if (houseTheme.detail) cardADetails.push(houseTheme.detail);
    if (houseTheme.challenge) cardADetails.push(`注意：${corpusSentence(houseTheme.challenge, "")}`);
  } else if (activatedHouse > 0) {
    cardADetails.push(rightPanelDisplayCorpus.currentYear.houseFallback);
  }
  if (activatedSign) {
    cardADetails.push(`激活星座：${signNames[activatedSign] ?? activatedSign}，该星座的特质会影响这个宫位的表达方式。`);
  }
  cards.push({
    id: "current-year",
    icon: "◈",
    title: "当前年份",
    summary: houseTheme?.summary ?? rightPanelDisplayCorpus.currentYear.houseFallback,
    details: cardADetails,
    translation: `${age}岁 · 第${activatedHouse || "?"}宫被激活`,
    action: houseTheme?.advice ?? "观察当前激活宫位的主题如何在实际生活中展开。",
    caution: "小限描述的是年度基调，不是精确到每一天的事件。",
  });

  // ── Card B: 时间主星 ──
  const cardBDetails: string[] = [];
  const lordNames = Array.isArray(timeLordIds)
    ? timeLordIds.map((id: unknown) => pointNames[String(id)] ?? String(id)).join("、")
    : "";
  const firstLord = Array.isArray(timeLordIds) && timeLordIds.length > 0
    ? String(timeLordIds[0])
    : "";
  const lordTheme = firstLord ? timeLordThemes[firstLord] : null;

  if (lordTheme) {
    cardBDetails.push(lordTheme.summary);
    if (lordTheme.detail) cardBDetails.push(lordTheme.detail);
    if (lordTheme.advice) cardBDetails.push(`建议：${lordTheme.advice}`);
  } else if (lordNames) {
    cardBDetails.push(`${lordNames}是这一年的时间主星，其主题会影响整个年度的节奏。`);
  } else {
    cardBDetails.push(rightPanelDisplayCorpus.currentYear.lordFallback);
  }
  cards.push({
    id: "year-lord",
    icon: "☀",
    title: "时间主星",
    summary: lordTheme?.summary ?? rightPanelDisplayCorpus.currentYear.lordFallback,
    details: cardBDetails,
    translation: `时间主星：${lordNames || "待确认"}`,
    action: lordTheme?.advice ?? "留意时间主星的主题如何在这一年中反复出现。",
    caution: "时间主星带来的是年度调性，不决定具体事件。",
  });

  // ── Card C: 宫位+主星组合 ──
  const cardCDetails: string[] = [];
  if (houseTheme && lordTheme) {
    cardCDetails.push(`宫位与主星的组合：第${activatedHouse}宫（${houseTheme.summary.split("，")[0]}）由${lordNames}主星引导。`);
    cardCDetails.push("宫位决定了焦点领域，主星决定了这个领域里的行动方式。");
  } else {
    cardCDetails.push("宫位决定了关注焦点，主星决定了行动方式。两者共同塑造年度节奏。");
  }
  cards.push({
    id: "house-lord-combo",
    icon: "⇌",
    title: "宫位与主星",
    summary: `第${activatedHouse || "?"}宫由${lordNames || "?"}引导`,
    details: cardCDetails,
    translation: "宫位定焦点，主星定方式。",
    action: "在激活的宫位领域内，用主星的方式去行动。",
    caution: "宫位和主星组合可能产生协同，也可能产生张力，留意两者的互动。",
  });

  // ── Card D: 年度过渡 ──
  const cardDDetails: string[] = [];
  if (currentPeriod) {
    const startDate = String(currentPeriod.start_date);
    const endDate = String(currentPeriod.end_date);
    cardDDetails.push(`年度范围：${startDate} — ${endDate}`);

    // Calculate year position
    const startMs = new Date(startDate).getTime();
    const endMs = new Date(endDate).getTime();
    const nowMs = Date.now();
    const fraction = (endMs - startMs) > 0
      ? Math.max(0, Math.min(1, (nowMs - startMs) / (endMs - startMs)))
      : 0.5;
    const position = yearPosition(fraction);
    cardDDetails.push(rightPanelDisplayCorpus.transitionGuidance[position]);

    // Next year preview
    const currentIdx = profections.findIndex((p) => p.current);
    if (currentIdx >= 0 && currentIdx < profections.length - 1) {
      const next = profections[currentIdx + 1];
      const nextHouse = Number(next.activated_house);
      const nextHouseTheme = houseDomains[nextHouse];
      cardDDetails.push(
        `下一年：第${nextHouse}宫${nextHouseTheme ? `（${nextHouseTheme.summary.split("，")[0]}）` : ""}`,
      );
    }
  }
  cards.push({
    id: "year-transition",
    icon: "⟐",
    title: "年度过渡",
    summary: cardDDetails.length > 1 ? corpusSentence(cardDDetails[1], "年度主题正在展开") : "年度节奏信息",
    details: cardDDetails,
    translation: "年度主题在生日前后转换，过渡期可能提前几周感受到。",
    action: "不必等到生日才调整节奏，提前留意新年度的主题信号。",
    caution: "年度过渡的感受可能提前或滞后，不必过于精确对应日期。",
  });

  // ── Card E: 年度建议 ──
  const tone = yearTone(timeLordIds);
  const cardEDetails: string[] = [
    `${rightPanelDisplayCorpus.adviceSlots.house.title}｜${houseTheme?.summary ?? "观察激活宫位的主题"}`,
    `${rightPanelDisplayCorpus.adviceSlots.lord.title}｜${lordTheme?.summary ?? rightPanelDisplayCorpus.currentYear.lordFallback}`,
    `${rightPanelDisplayCorpus.adviceSlots.year.title}｜${corpusSentence(tone, "持续稳健推进")}`,
  ];
  cards.push({
    id: "stage-advice",
    icon: "▷",
    title: "年度建议",
    summary: corpusSentence(tone, "持续观察年度主题"),
    details: cardEDetails,
    translation: "小限是理解年度节奏的工具，不是命运的精确时间表。",
    action: houseTheme?.advice ?? "围绕当前年度主题做持续微调。",
    caution: "不要把小限当成不可改变的时间表。它是理解节奏的工具，不是预测命运的手段。",
  });

  return { cards };
}
