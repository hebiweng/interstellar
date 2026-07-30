"use client";

import { useMemo, useRef, useState } from "react";
import type { NatalSnapshot, NatalPersonInput } from "../../lib/interstellar-api";
import type { ThemeMode } from "../lib/chart-types";
import type { WorkspacePerson } from "../../lib/account-workspace";
import { pointNames, signNames } from "../lib/chart-constants";
import { asRecord, asRecords, pointList } from "../lib/chart-utils";
import { TechniqueGuideDialog } from "../forms/technique-guide-dialog";
import { FirdariaInstantInsight } from "./firdaria-instant-insight";
import "../../styles/secondary.css";

export function FirdariaWorkspace({
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
  const firdaria = asRecord(result.firdaria);
  const firdariaMajor = asRecords(firdaria.major_periods);
  const firdariaMinor = asRecords(firdaria.sub_periods);
  const hasData = firdariaMajor.length > 0;
  const sect = String(firdaria.sect ?? "");

  /* Current period highlighting */
  const currentMajor = useMemo(
    () => firdariaMajor.find((p) => p.current),
    [firdariaMajor],
  );
  const currentMinor = useMemo(
    () => firdariaMinor.find((p) => p.current),
    [firdariaMinor],
  );

  return (
    <div className="timing-workspace">
      {/* Left panel — person selector + technique info */}
      <article className="params-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>FIRDARIA</small><h2>法达周期</h2></div>
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

        {hasData && (
          <div className="params-section">
            <label>昼夜</label>
            <span className="param-value">{sect === "day" ? "昼盘起序" : "夜盘起序"}</span>
          </div>
        )}

        {currentMajor && (
          <div className="params-section current-period">
            <label>当前主运</label>
            <b>{pointNames[String(currentMajor.major_lord_id)] ?? String(currentMajor.major_lord_id)}</b>
            <small>
              {new Date(String(currentMajor.start_utc)).toLocaleDateString("zh-CN")} —
              {" "}{new Date(String(currentMajor.end_utc)).toLocaleDateString("zh-CN")}
            </small>
          </div>
        )}

        {currentMinor && (
          <div className="params-section current-period">
            <label>当前次运</label>
            <b>{pointNames[String(currentMinor.minor_lord_id)] ?? String(currentMinor.minor_lord_id)}</b>
            <small>
              {new Date(String(currentMinor.start_utc)).toLocaleDateString("zh-CN")} —
              {" "}{new Date(String(currentMinor.end_utc)).toLocaleDateString("zh-CN")}
            </small>
          </div>
        )}

        <div className="params-section technique-info">
          <button className="text-link" onClick={() => setGuideOpen(true)}>技法说明</button>
        </div>

        {guideOpen && (
          <TechniqueGuideDialog
            open={guideOpen}
            title="法达周期"
            path="/guides/firdaria.md"
            onClose={() => setGuideOpen(false)}
          />
        )}
      </article>

      {/* Center panel — firdaria timeline */}
      <article className="wheel-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>FIRDARIA TIMELINE</small><h2>法达时间线</h2></div>
        </div>
        <div className="timing-timeline-content">
          {hasData ? (
            <>
              <div className="result-filter-chips">
                <span>{sect === "day" ? "昼盘起序" : "夜盘起序"}</span>
                <span>主运＋次运</span>
              </div>

              <h3 className="table-group-title">主运</h3>
              <div className="wide-result-table firdaria-result-table">
                <div className="wide-result-head">
                  <span>主运星</span><span>起始</span><span>结束</span><span>年数</span><span>当前</span>
                </div>
                {firdariaMajor.map((period, index) => (
                  <div className={`wide-result-row${period.current ? " current-period-row" : ""}`} key={String(period.period_id ?? index)}>
                    <b>{pointNames[String(period.major_lord_id)] ?? String(period.major_lord_id)}</b>
                    <span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span>
                    <span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span>
                    <span>{String(period.duration_years)} 年</span>
                    <span>{period.current ? "当前主运" : ""}</span>
                  </div>
                ))}
              </div>

              <h3 className="table-group-title">次运</h3>
              <div className="wide-result-table firdaria-sub-result-table">
                <div className="wide-result-head">
                  <span>主运星</span><span>次运星</span><span>起始</span><span>结束</span><span>当前</span>
                </div>
                {firdariaMinor.map((period, index) => (
                  <div className={`wide-result-row${period.current ? " current-period-row" : ""}`} key={String(period.period_id ?? index)}>
                    <span>{pointNames[String(period.major_lord_id)] ?? String(period.major_lord_id)}</span>
                    <b>{pointNames[String(period.minor_lord_id)] ?? String(period.minor_lord_id)}</b>
                    <span>{new Date(String(period.start_utc)).toLocaleDateString("zh-CN")}</span>
                    <span>{new Date(String(period.end_utc)).toLocaleDateString("zh-CN")}</span>
                    <span>{period.current ? "当前次运" : ""}</span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="empty-state">
              <span>◌</span>
              <h2>法达未计算</h2>
              <p>法达需要可判定的昼夜盘与可靠出生时刻。请确认本命盘已计算且出生时刻完整。</p>
            </div>
          )}
        </div>
      </article>

      {/* Right panel — firdaria insight */}
      <article className="insight-panel chart-workspace-card">
        <div className="panel-heading">
          <div><small>INSIGHT</small><h2>解读</h2></div>
        </div>
        {hasData ? (
          <FirdariaInstantInsight latestNatalSnapshot={latestNatalSnapshot} />
        ) : (
          <div className="insight-placeholder">
            <span>✦</span>
            <p>法达数据不可用</p>
          </div>
        )}
      </article>
    </div>
  );
}
