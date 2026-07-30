"use client";

import { useMemo } from "react";
import type { NatalSnapshot } from "../../lib/interstellar-api";
import { buildProfectionsRightPanel, type ProfectionsRightPanel } from "../../lib/insight/annual-profections";

type ProfectionsInstantInsightProps = {
  latestNatalSnapshot: NatalSnapshot;
};

function compact(text: string): string {
  return text.split(/[。；]/)[0].replace(/：$/, "").trim();
}

function splitDetail(detail: string): { title: string; sentence: string } {
  if (detail.includes("｜")) {
    const [rawTitle, rawSentence] = detail.split("｜");
    return { title: rawTitle.trim(), sentence: compact(rawSentence) };
  }
  if (detail.includes("：")) {
    const [rawTitle, ...rest] = detail.split("：");
    return { title: rawTitle.trim(), sentence: compact(rest.join("：")) };
  }
  return { title: "", sentence: compact(detail) };
}

export function ProfectionsInstantInsight({ latestNatalSnapshot }: ProfectionsInstantInsightProps) {
  const rightPanel: ProfectionsRightPanel = useMemo(
    () => buildProfectionsRightPanel(latestNatalSnapshot),
    [latestNatalSnapshot],
  );

  const cards = rightPanel.cards;
  if (cards.length === 0) {
    return (
      <div className="insight-placeholder">
        <span>✦</span>
        <p>小限数据不可用</p>
      </div>
    );
  }

  const [cardA, cardB, cardC, cardD, cardE] = cards;

  return (
    <div className="instant-insight">
      {/* Card A: 当前年份 */}
      {cardA && <section className="insight-card-sp insight-card-stage">
        <header className="insight-card-sp-header">
          <span className="insight-card-sp-icon">{cardA.icon}</span>
          <div><b>{cardA.title}</b><small>{cardA.translation}</small></div>
        </header>
        <p className="insight-card-summary">{cardA.summary}</p>
        <div className="insight-card-details">
          {cardA.details.map((d: string, i: number) => <p key={i}>{d}</p>)}
        </div>
      </section>}

      {/* Card B: 时间主星 */}
      {cardB && <section className="insight-card-sp insight-card-themes">
        <header className="insight-card-sp-header">
          <span className="insight-card-sp-icon">{cardB.icon}</span>
          <div><b>{cardB.title}</b></div>
        </header>
        <p className="insight-card-summary">{cardB.summary}</p>
        <div className="insight-card-details">
          {cardB.details.map((d: string, i: number) => <p key={i}>{d}</p>)}
        </div>
      </section>}

      {/* Card C: 宫位+主星组合 */}
      {cardC && <section className="insight-card-sp insight-card-layers">
        <header className="insight-card-sp-header">
          <span className="insight-card-sp-icon">{cardC.icon}</span>
          <div><b>{cardC.title}</b></div>
        </header>
        <p className="insight-card-summary">{cardC.summary}</p>
        <div className="insight-card-details">
          {cardC.details.map((d: string, i: number) => <p key={i}>{d}</p>)}
        </div>
      </section>}

      {/* Card D: 年度过渡 */}
      {cardD && <section className="insight-card-sp insight-card-timeline">
        <header className="insight-card-sp-header">
          <span className="insight-card-sp-icon">{cardD.icon}</span>
          <div><b>{cardD.title}</b></div>
        </header>
        <p className="insight-card-summary">{cardD.summary}</p>
        <div className="insight-card-details">
          {cardD.details.map((d: string, i: number) => <p key={i}>{d}</p>)}
        </div>
      </section>}

      {/* Card E: 年度建议 */}
      {cardE && <section className="insight-card-sp insight-card-notes">
        <header className="insight-card-sp-header">
          <span className="insight-card-sp-icon">{cardE.icon}</span>
          <div><b>{cardE.title}</b></div>
        </header>
        <div className="advice-icon-list">
          {cardE.details.slice(0, 3).map((detail: string, i: number) => {
            const parsed = splitDetail(detail);
            return (
              <p key={i}>
                {parsed.title && <span className="advice-slot-title">{parsed.title}</span>}
                {parsed.sentence}
              </p>
            );
          })}
        </div>
        <div className="insight-card-caution">
          <small>{cardE.action}</small>
        </div>
      </section>}
    </div>
  );
}
