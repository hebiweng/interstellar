"use client";

import { useMemo, useRef, useState } from "react";
import type { NatalSnapshot, NatalPersonInput } from "../../lib/interstellar-api";
import type { ThemeMode } from "../lib/chart-types";
import type { WorkspacePerson } from "../../lib/account-workspace";
import { pointNames, signNames } from "../lib/chart-constants";
import { asRecord, asRecords, pointList } from "../lib/chart-utils";
import { TechniqueGuideDialog } from "../forms/technique-guide-dialog";
import { ProfectionsInstantInsight } from "./annual-profections-instant-insight";
import "../../styles/secondary.css";

export function AnnualProfectionsWorkspace({
  theme,
  person,
  latestNatalSnapshot,
  savedPeople,
  selectedPersonId,
  onSelectPerson,
}: {
  theme: ThemeMode;
  person: NatalPersonInput;
  latestNatalSnapshot: NatalSnapshot;
  savedPeople: WorkspacePerson[];
  selectedPersonId: string | null;
  onSelectPerson: (person: WorkspacePerson) => void;
}) {
  const [guideOpen, setGuideOpen] = useState(false);
  const [personMenuOpen, setPersonMenuOpen] = useState(false);
  const personMenuRef = useRef<HTMLDivElement>(null);

  const result = asRecord(latestNatalSnapshot.result);
  const profections = asRecords(asRecord(result.profections).periods);
  const hasData = profections.length > 0;

  /* Current period highlighting */
  const currentPeriod = useMemo(
    () => profections.find((p) => p.current),
    [profections],
  );

  return (
    <div className="timing-workspace">
      {/* Left panel — person selector + technique info */}
      <article className="params-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>ANNUAL PROFECTIONS</small><h2>年度小限</h2></div>
        </div>

        <div className="params-section">
          <label>人物</label>
          <div className="person-selector" ref={personMenuRef}>
            <button className="person-selector-trigger" onClick={() => setPersonMenuOpen(!personMenuOpen)}>
              {person.displayName || "选择人物"}
            </button>
            {personMenuOpen && (
              <div className="person-selector-menu">
                {savedPeople.map((p) => (
                  <button
                    key={p.id}
                    className={p.id === selectedPersonId ? "active" : ""}
                    onClick={() => { onSelectPerson(p); setPersonMenuOpen(false); }}
                  >
                    {p.person.displayName}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {currentPeriod && (
          <div className="params-section current-period">
            <label>当前年份</label>
            <b>{String(currentPeriod.age)} 岁</b>
            <small>第{String(currentPeriod.activated_house)}宫 · {signNames[String(currentPeriod.activated_sign)] ?? String(currentPeriod.activated_sign)}</small>
            <small>时间主星：{pointList(currentPeriod.time_lord_ids)}</small>
            <small>
              {String(currentPeriod.start_date)} — {String(currentPeriod.end_date)}
            </small>
          </div>
        )}

        <div className="params-section technique-info">
          <button className="text-link" onClick={() => setGuideOpen(true)}>技法说明</button>
        </div>

        {guideOpen && (
          <TechniqueGuideDialog
            open={guideOpen}
            title="年度小限"
            path="/guides/annual-profections.md"
            onClose={() => setGuideOpen(false)}
          />
        )}
      </article>

      {/* Center panel — profections timeline */}
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>PROFECTIONS TIMELINE</small><h2>小限时间线</h2></div>
        </div>
        <div className="timing-timeline-content">
          {hasData ? (
            <>
              <div className="result-filter-chips">
                <span>起点：上升／第一宫</span>
                <span>年度小限</span>
                <span>生日边界</span>
              </div>

              <div className="wide-result-table profection-result-table">
                <div className="wide-result-head">
                  <span>年龄</span><span>起始</span><span>结束</span><span>宫位</span><span>星座</span><span>主星</span><span>当前</span>
                </div>
                {profections.map((period, index) => (
                  <div className={`wide-result-row${period.current ? " current-period-row" : ""}`} key={String(period.age ?? index)}>
                    <b>{String(period.age)} 岁</b>
                    <span>{String(period.start_date)}</span>
                    <span>{String(period.end_date)}</span>
                    <span>第{String(period.activated_house)}宫</span>
                    <span>{signNames[String(period.activated_sign)] ?? String(period.activated_sign)}</span>
                    <span>{pointList(period.time_lord_ids)}</span>
                    <span>{period.current ? "当前" : ""}</span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="empty-state">
              <span>◌</span>
              <h2>小限未计算</h2>
              <p>年度小限需要上升星座与可靠出生日期。请确认本命盘已计算。</p>
            </div>
          )}
        </div>
      </article>

      {/* Right panel — profections insight */}
      <article className="insight-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>INSIGHT</small><h2>解读</h2></div>
        </div>
        {hasData ? (
          <ProfectionsInstantInsight latestNatalSnapshot={latestNatalSnapshot} />
        ) : (
          <div className="insight-placeholder">
            <span>✦</span>
            <p>小限数据不可用</p>
          </div>
        )}
      </article>
    </div>
  );
}
