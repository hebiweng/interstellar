/**
 * 法达盘 insight builder
 * 从本命盘快照的 firdaria 数据中提取事实，选择语料，构建右侧即时解读卡片。
 * 服务器提供权威事实（周期时间线、行星标识、昼夜），客户端负责选择语料和展示。
 */

import type { NatalSnapshot } from "../interstellar-api";
import { asRecord, asRecords } from "../../components/lib/chart-utils";
import { pointNames } from "../../components/lib/chart-constants";
import {
  type FirdariaRightPanel,
  planetThemes,
  sectRules,
  majorMinorCombinations,
  rightPanelDisplayCorpus,
} from "./firdaria-corpus";

export type { FirdariaRightPanel } from "./firdaria-corpus";

function corpusSentence(text: string | undefined, fallback: string): string {
  return (text ?? fallback).split(/[。；]/)[0].replace(/：$/, "").trim();
}

/**
 * 判断主运在整体时间线中的位置（前期/中期/后期）
 */
function periodPosition(fraction: number): "approaching" | "midpoint" | "approachingEnd" {
  if (fraction < 0.33) return "approaching";
  if (fraction < 0.66) return "midpoint";
  return "approachingEnd";
}

/**
 * 根据主运行星判断阶段调性
 */
function periodTone(majorLord: string): string {
  if (["saturn"].includes(majorLord)) return rightPanelDisplayCorpus.aspectTone.structured;
  if (["jupiter", "venus"].includes(majorLord)) return rightPanelDisplayCorpus.aspectTone.expansive;
  if (["mars", "sun"].includes(majorLord)) return rightPanelDisplayCorpus.aspectTone.active;
  if (["moon"].includes(majorLord)) return rightPanelDisplayCorpus.aspectTone.reflective;
  return rightPanelDisplayCorpus.aspectTone.steady;
}

export function buildFirdariaRightPanel(
  snapshot: NatalSnapshot,
): FirdariaRightPanel {
  const result = asRecord(snapshot.result);
  const firdaria = asRecord(result.firdaria);
  const majorPeriods = asRecords(firdaria.major_periods);
  const subPeriods = asRecords(firdaria.sub_periods);
  const sect = String(firdaria.sect ?? "");
  const cards: FirdariaRightPanel["cards"] = [];

  /* Current period data */
  const currentMajor = majorPeriods.find((p) => p.current);
  const currentMinor = subPeriods.find((p) => p.current);
  const majorLord = String(currentMajor?.major_lord_id ?? "");
  const minorLord = String(currentMinor?.minor_lord_id ?? "");

  // ── Card A: 当前周期 ──
  const cardADetails: string[] = [];
  if (currentMajor) {
    const theme = planetThemes[majorLord];
    cardADetails.push(theme ? theme.summary : rightPanelDisplayCorpus.currentPeriod.majorFallback);
    if (theme?.challenge) {
      cardADetails.push(`注意：${corpusSentence(theme.challenge, "")}`);
    }
  }
  if (currentMinor) {
    const minorTheme = planetThemes[minorLord];
    cardADetails.push(minorTheme ? `次运：${minorTheme.summary}` : rightPanelDisplayCorpus.currentPeriod.minorFallback);
  }
  cards.push({
    id: "current-period",
    icon: "\u25C8",
    title: "当前周期",
    summary: currentMajor
      ? (planetThemes[majorLord]?.summary ?? rightPanelDisplayCorpus.currentPeriod.majorFallback)
      : "法达周期数据不可用",
    details: cardADetails,
    translation: `主运${pointNames[majorLord] ?? majorLord}${currentMinor ? ` · 次运${pointNames[minorLord] ?? minorLord}` : ""}`,
    action: planetThemes[majorLord]?.advice ?? "观察当前主运主题如何在实际生活中展开。",
    caution: "法达描述的是长期基调，不是精确到每一天的事件预测。",
  });

  // ── Card B: 主次组合 ──
  const comboKey = `${majorLord}-${minorLord}`;
  const combination = majorMinorCombinations[comboKey];
  const cardBDetails: string[] = [];
  if (combination) {
    cardBDetails.push(combination.summary);
    if (combination.detail) cardBDetails.push(combination.detail);
    if (combination.advice) cardBDetails.push(`建议：${combination.advice}`);
  } else {
    cardBDetails.push(
      currentMajor && currentMinor
        ? `${pointNames[majorLord] ?? majorLord}主运与${pointNames[minorLord] ?? minorLord}次运的组合，正在共同影响当前阶段。主运决定大方向，次运决定具体色调。`
        : rightPanelDisplayCorpus.currentPeriod.combinationFallback,
    );
  }
  cards.push({
    id: "period-combination",
    icon: "\u21CC",
    title: "主次组合",
    summary: combination
      ? combination.summary
      : rightPanelDisplayCorpus.currentPeriod.combinationFallback,
    details: cardBDetails,
    translation: `主运定方向，次运调色调`,
    action: combination?.advice ?? "留意主运和次运主题在生活中如何交替出现。",
    caution: "两个行星的主题可能同时出现，也可能交替出现，不需要每时每刻都同时感受到两者。",
  });

  // ── Card C: 昼夜与起序 ──
  const sectInfo = sect === "day" ? sectRules.day : sectRules.night;
  const cardCDetails: string[] = [
    sectInfo.detail,
  ];
  // Add next major period transition
  const currentMajorIdx = majorPeriods.findIndex((p) => p.current);
  if (currentMajorIdx >= 0 && currentMajorIdx < majorPeriods.length - 1) {
    const next = majorPeriods[currentMajorIdx + 1];
    const nextLord = String(next.major_lord_id);
    const nextStart = new Date(String(next.start_utc)).toLocaleDateString("zh-CN");
    cardCDetails.push(`下一次主运转换：${pointNames[nextLord] ?? nextLord}主运，约 ${nextStart} 开始。`);
  }
  cards.push({
    id: "sect-context",
    icon: "\u2600",
    title: sect === "day" ? "昼盘起序" : "夜盘起序",
    summary: sectInfo.summary,
    details: cardCDetails,
    translation: "起序决定了你人生各阶段的大致顺序。",
    action: "了解起序有助于预判未来阶段，但不必过度提前焦虑尚未到来的主运。",
    caution: "昼夜区分依赖准确出生时刻；如果出生时刻不确定，法达起序可能有差异。",
  });

  // ── Card D: 阶段过渡 ──
  const cardDDetails: string[] = [];
  if (currentMajor) {
    const majorStart = new Date(String(currentMajor.start_utc)).getTime();
    const majorEnd = new Date(String(currentMajor.end_utc)).getTime();
    const totalMs = majorEnd - majorStart;
    const nowMs = Date.now();
    const fraction = totalMs > 0 ? Math.max(0, Math.min(1, (nowMs - majorStart) / totalMs)) : 0.5;
    const position = periodPosition(fraction);

    const transitionText = rightPanelDisplayCorpus.transitionGuidance[position];
    cardDDetails.push(transitionText);

    // Sub-period transitions
    if (currentMinor) {
      const minorStart = new Date(String(currentMinor.start_utc)).getTime();
      const minorEnd = new Date(String(currentMinor.end_utc)).getTime();
      const minorTotalMs = minorEnd - minorStart;
      const minorFraction = minorTotalMs > 0 ? Math.max(0, Math.min(1, (nowMs - minorStart) / minorTotalMs)) : 0.5;
      if (minorFraction < 0.2) {
        cardDDetails.push(`次运${pointNames[minorLord] ?? minorLord}刚开始，主题正在形成中。`);
      } else if (minorFraction > 0.8) {
        cardDDetails.push(`次运${pointNames[minorLord] ?? minorLord}即将结束，下一个次运的主题可能在酝酿。`);
      }
    }
  }
  if (cardDDetails.length === 0) {
    cardDDetails.push("无法判断当前阶段位置，请确认法达数据完整。");
  }
  cards.push({
    id: "transition",
    icon: "\u27D0",
    title: "阶段过渡",
    summary: cardDDetails[0].split("。")[0],
    details: cardDDetails,
    translation: "主运通常持续数年，次运约一年左右。过渡期感受可能先于日期到达。",
    action: "过渡期按节奏调整，不需要立刻切换模式。",
    caution: "阶段过渡的「感受」可能提前或滞后几天到几周，不必过于精确地对应日期。",
  });

  // ── Card E: 阶段建议 ──
  const tone = periodTone(majorLord);
  const cardEDetails: string[] = [
    `${rightPanelDisplayCorpus.adviceSlots.period.title}｜${planetThemes[majorLord]?.summary ?? "观察主运主题如何展开"}`,
    `${rightPanelDisplayCorpus.adviceSlots.combination.title}｜${combination?.summary ?? "主运和次运正在共同影响当前节律"}`,
    `${rightPanelDisplayCorpus.adviceSlots.transition.title}｜${corpusSentence(tone, "当前阶段节奏平稳")}`,
  ];
  cards.push({
    id: "stage-advice",
    icon: "\u25B7",
    title: "阶段建议",
    summary: corpusSentence(tone, "持续观察当前阶段主题"),
    details: cardEDetails,
    translation: "法达不是命运时间表，是理解当前长期节奏的工具。",
    action: planetThemes[majorLord]?.advice ?? "围绕当前主运主题做持续微调。",
    caution: "不要把法达周期当成不可改变的时间表。它是理解节奏的工具，不是命运的决定。",
  });

  return { cards };
}
