import type { CSSProperties } from "react";
import type { ChartComparison, NatalSnapshot, SecondaryProgressionResult } from "../../lib/interstellar-api";
import type { SecondaryProgressionRightPanel } from "../../lib/insight/secondary";
import { lunarPhaseCorpus, moonSignPhases, rightPanelDisplayCorpus, sunSignPhases } from "../../lib/insight/secondary-corpus";
import { aspectNames, pointNames, signNames } from "../lib/chart-constants";
import { asRecord } from "../lib/chart-utils";

type SecondaryInstantInsightProps = {
  comparison: ChartComparison | null;
  progressedSnapshot: NatalSnapshot | null;
  rightPanel: SecondaryProgressionRightPanel;
  signPeriods: NonNullable<SecondaryProgressionResult["progressed_sign_periods"]>;
};

function compact(text: string): string {
  return text.split(/[。；]/)[0].replace(/：$/, "").trim();
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, value));
}

function phaseInfo(angle: number): { key: string; name: string; meaning: string } {
  const key = angle < 90 ? "new" : angle < 180 ? "first_quarter" : angle < 270 ? "full" : "last_quarter";
  const names: Record<string, string> = { new: "新月期", first_quarter: "上弦期", full: "满月期", last_quarter: "下弦期" };
  return { key, name: names[key], meaning: lunarPhaseCorpus[key]?.summary ?? "内在节奏正在转换" };
}

function phaseNodeNearBoundary(angle: number): boolean {
  return Math.min(angle % 90, 90 - (angle % 90)) < 5;
}

function formatSignPeriod(period: NonNullable<SecondaryProgressionResult["progressed_sign_periods"]>[number] | undefined): string {
  if (!period?.ingress_date || !period.egress_date) return "阶段日期待确认";
  const ingressMonth = period.ingress_date.slice(0, 7);
  const egressMonth = period.egress_date.slice(0, 7);
  const start = period.ingress_status === "birth_or_before" ? `出生前/${ingressMonth}` : ingressMonth;
  return `${start}—${egressMonth}`;
}

const signOrder = ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"];

function adjacentSign(sign: string | undefined, direction: -1 | 1): string {
  const index = sign ? signOrder.indexOf(sign) : -1;
  if (index < 0) return "上一阶段";
  return signNames[signOrder[(index + direction + signOrder.length) % signOrder.length]] ?? "下一阶段";
}

function splitTheme(detail: string): { icon: string; title: string; meta: string; sentence: string } {
  const [rawTitle, rawSentence] = detail.includes("｜")
    ? detail.split("｜")
    : (() => {
        const [titlePart, ...sentenceParts] = detail.split("：");
        return [titlePart, sentenceParts.join("：") || detail];
      })();
  const [titlePart, ...metaParts] = rawTitle.split("：");
  const title = titlePart.trim() || "长期主题";
  const meta = metaParts.join("：").trim();
  const sentence = compact(rawSentence || detail);
  const icon = title.includes("情绪") ? "●" : title.includes("身份") || title.includes("事业") ? "◆" : title.includes("关系") ? "◇" : "✦";
  return { icon, title, meta, sentence };
}

function splitAdvice(detail: string): { icon: string; text: string } {
  const [topic, sentence] = detail.includes("｜") ? detail.split("｜") : ["", detail];
  if (topic.includes("情绪")) return { icon: rightPanelDisplayCorpus.adviceSlots.emotion.icon, text: `${topic}：${compact(sentence)}` };
  if (topic.includes("长期")) return { icon: rightPanelDisplayCorpus.adviceSlots.identity.icon, text: `${topic}：${compact(sentence)}` };
  if (topic.includes("相位")) return { icon: rightPanelDisplayCorpus.adviceSlots.aspect.icon, text: `${topic}：${compact(sentence)}` };
  return { icon: "✦", text: compact(sentence) };
}

export function SecondaryInstantInsight({ comparison, progressedSnapshot, rightPanel, signPeriods }: SecondaryInstantInsightProps) {
  const cardById = new Map(rightPanel.cards.map((card) => [card.id, card]));
  const stageCard = cardById.get("current-stage");
  const themeCard = cardById.get("change-themes");
  const turningCard = cardById.get("turning-points");
  const adviceCard = cardById.get("stage-advice");
  const natalCard = cardById.get("natal-link");
  const allCrossAspects = comparison?.result.cross_aspects ?? [];
  const strongest = [...allCrossAspects].sort((left, right) => right.strength - left.strength || left.orb_deg - right.orb_deg).slice(0, 5);
  const progressedMoon = progressedSnapshot?.result.points.find((point) => point.point_id === "moon");
  const progressedSun = progressedSnapshot?.result.points.find((point) => point.point_id === "sun");
  const lunarPhase = asRecord(asRecord(progressedSnapshot?.result.astronomical_context).lunar_phase);
  const lunarPhaseAngle = Number(lunarPhase.angle ?? lunarPhase.elongation_deg ?? 0);
  const lunarPhaseLight = Math.round(Number(lunarPhase.illumination_fraction ?? 0) * 100);
  const moonProgress = progressedMoon ? clampPercent(progressedMoon.degree_in_sign / 30 * 100) : 0;
  const sunProgress = progressedSun ? clampPercent(progressedSun.degree_in_sign / 30 * 100) : 0;
  const currentPhase = phaseInfo(lunarPhaseAngle);
  const moonSign = progressedMoon ? (signNames[progressedMoon.sign] ?? progressedMoon.sign) : "—";
  const sunSign = progressedSun ? (signNames[progressedSun.sign] ?? progressedSun.sign) : "—";
  const moonStageCopy = progressedMoon ? compact(moonSignPhases[progressedMoon.sign]?.summary ?? rightPanelDisplayCorpus.currentStage.moonFallback) : "等待计算";
  const sunStageCopy = progressedSun ? compact(sunSignPhases[progressedSun.sign]?.summary ?? rightPanelDisplayCorpus.currentStage.sunFallback) : "等待计算";
  const moonYears = formatSignPeriod(signPeriods.find((period) => period.point_id === "moon"));
  const sunYears = formatSignPeriod(signPeriods.find((period) => period.point_id === "sun"));
  const supportiveCount = allCrossAspects.filter((aspect) => ["sextile", "trine"].includes(aspect.type)).length;
  const tensionCount = allCrossAspects.filter((aspect) => ["square", "opposition"].includes(aspect.type)).length;
  const neutralCount = Math.max(0, allCrossAspects.length - supportiveCount - tensionCount);
  const actionLabel = tensionCount > supportiveCount ? "适合调整" : supportiveCount > tensionCount ? "适合推进" : "适合整合";
  const coreTurnPointIds = new Set<string>(rightPanelDisplayCorpus.coreTurningPointIds);
  const slowPointIds = new Set(["jupiter", "saturn", "uranus", "neptune", "pluto"]);
  const rightPanelAspectCandidates = strongest.filter((aspect) => {
    if (aspect.moving_point_id === aspect.reference_point_id && slowPointIds.has(aspect.moving_point_id)) return false;
    return coreTurnPointIds.has(aspect.moving_point_id) && coreTurnPointIds.has(aspect.reference_point_id);
  });
  const strengthened = rightPanelAspectCandidates.filter((aspect) => ["sextile", "trine"].includes(aspect.type)).slice(0, 2);
  const challenged = rightPanelAspectCandidates.filter((aspect) => ["square", "opposition"].includes(aspect.type)).slice(0, 2);
  const primaryAspect = rightPanelAspectCandidates.find((aspect) => aspect.applying_state === "exact") ?? null;
  const newPotentials = rightPanelAspectCandidates.filter((aspect) => !["sextile", "trine", "square", "opposition"].includes(aspect.type)).slice(0, 2);
  const moonTransition = progressedMoon && (progressedMoon.degree_in_sign < 3 || progressedMoon.degree_in_sign > 27)
    ? {
        tone: "warning",
        title: progressedMoon.degree_in_sign < 3 ? `次限月亮刚进入${moonSign}` : `次限月亮即将离开${moonSign}`,
        route: progressedMoon.degree_in_sign < 3 ? `${adjacentSign(progressedMoon.sign, -1)} → ${moonSign}` : `${moonSign} → ${adjacentSign(progressedMoon.sign, 1)}`,
        status: progressedMoon.degree_in_sign < 3
          ? rightPanelDisplayCorpus.turningPoint.moonIngress
          : `${rightPanelDisplayCorpus.turningPoint.moonEgress} 下个阶段约 ${formatSignPeriod(signPeriods.find((period) => period.point_id === "moon")).split("—")[1] ?? "待确认"} 开始。`,
      }
    : null;
  const steadyMoonNode = {
    tone: "quiet",
    title: progressedMoon ? `次限月亮在${moonSign}阶段推进` : "次限月亮阶段待确认",
    route: progressedMoon ? `${moonSign} ${progressedMoon.degree_in_sign.toFixed(1)}° / 30°` : "等待计算",
    status: progressedMoon ? rightPanelDisplayCorpus.turningPoint.moonSteady : "需要计算后确认",
  };
  const aspectNode = primaryAspect
    ? {
        tone: "urgent",
        icon: "🔴",
        title: `次限${pointNames[primaryAspect.moving_point_id] ?? primaryAspect.moving_point_id}精确${aspectNames[primaryAspect.type] ?? primaryAspect.type}本命${pointNames[primaryAspect.reference_point_id] ?? primaryAspect.reference_point_id}`,
        status: rightPanelDisplayCorpus.turningPoint.exactAspect,
      }
    : {
        tone: "quiet",
        icon: "⚪",
        title: "当前没有精确次限相位",
        status: rightPanelDisplayCorpus.turningPoint.noExactAspect,
      };
  const phaseNode = {
    tone: phaseNodeNearBoundary(lunarPhaseAngle) ? "warning" : "quiet",
    title: `次限月相处于${currentPhase.name}${phaseNodeNearBoundary(lunarPhaseAngle) ? "起始" : ""}`,
    status: phaseNodeNearBoundary(lunarPhaseAngle) ? rightPanelDisplayCorpus.turningPoint.phaseBoundary : currentPhase.meaning,
  };

  return <article className="instant-insight">
    {stageCard && <section className="insight-card-sp insight-card-stage">
      <header className="stage-card-head">
        <span className="insight-card-sp-icon">{stageCard.icon}</span>
        <div><small>{stageCard.title}</small><h3>{progressedMoon ? `次限月亮在${moonSign}` : compact(stageCard.summary)}</h3></div>
      </header>
      <div className="secondary-stage-visual">
        <div
          className="secondary-phase-orb"
          style={{ "--phase-angle": `${lunarPhaseAngle}deg`, "--phase-light": `${lunarPhaseLight}%` } as CSSProperties}
          aria-label={`次限月相角度 ${lunarPhaseAngle.toFixed(1)} 度，亮面约 ${lunarPhaseLight}%`}
        >
          <span>{lunarPhaseLight}%</span>
        </div>
        <div className="secondary-stage-bars">
          <div>
            <header><b>次限月亮在{moonSign}</b><small>{moonYears}</small></header>
            <i><span style={{ width: `${moonProgress}%` }} /></i>
            <p>{progressedMoon ? `${moonStageCopy} · ${progressedMoon.degree_in_sign.toFixed(1)}° / 30°` : "等待计算"}</p>
          </div>
          <div>
            <header><b>次限太阳在{sunSign}</b><small>{sunYears}</small></header>
            <i><span style={{ width: `${sunProgress}%` }} /></i>
            <p>{progressedSun ? `${sunStageCopy} · ${progressedSun.degree_in_sign.toFixed(1)}° / 30°` : "等待计算"}</p>
          </div>
        </div>
      </div>
      <div className="secondary-stage-legend">
        <span className="moon-tag">月亮 · {moonSign}</span>
        <span className="sun-tag">太阳 · {sunSign}</span>
      </div>
      <p className="secondary-stage-phase">月相：{currentPhase.name}（{currentPhase.meaning}）</p>
    </section>}

    {themeCard && <section className="insight-card-sp insight-card-radar">
      <header className="insight-card-sp-header">
        <span className="insight-card-sp-icon">{themeCard.icon}</span>
        <div><b>{themeCard.title}</b></div>
      </header>
      <div className="secondary-trigger-bars" aria-hidden="true">
        <span className="supportive" style={{ flex: supportiveCount || 0.2 }} />
        <span className="tension" style={{ flex: tensionCount || 0.2 }} />
        <span className="neutral" style={{ flex: neutralCount || 0.2 }} />
      </div>
      <div className="trigger-legend">
        <span className="supportive">支持 {supportiveCount}</span>
        <span className="tension">挑战 {tensionCount}</span>
        <span className="neutral">中性 {neutralCount}</span>
      </div>
      <div className="theme-card-list">
        {themeCard.details.slice(0, 3).map((detail, index) => {
          const theme = splitTheme(detail);
          return <article key={index}>
            <i>{theme.icon}</i>
            <div><b>{theme.title}{theme.meta && <em>{theme.meta}</em>}</b><span>{theme.sentence}</span></div>
          </article>;
        })}
      </div>
    </section>}

    {turningCard && <section className="insight-card-sp insight-card-timeline">
      <header className="insight-card-sp-header">
        <span className="insight-card-sp-icon">{turningCard.icon}</span>
        <div><b>{turningCard.title}</b></div>
      </header>
      <div className="turning-point-list">
        <div className={aspectNode.tone} key="aspect-node">
          <span>{aspectNode.icon}</span><p><b>{aspectNode.title}</b><small>{aspectNode.status}</small></p>
        </div>
        <div className={moonTransition?.tone ?? steadyMoonNode.tone} key="moon-transition">
          <span>{moonTransition ? "🟡" : "⚪"}</span><p><b>{moonTransition?.title ?? steadyMoonNode.title}</b><small>{moonTransition?.route ?? steadyMoonNode.route}</small><em>{moonTransition?.status ?? steadyMoonNode.status}</em></p>
        </div>
        <div className={phaseNode.tone}>
          <span>{phaseNode.tone === "warning" ? "🟡" : "⚪"}</span><p><b>{phaseNode.title}</b><small>{phaseNode.status}</small></p>
        </div>
      </div>
    </section>}

    {adviceCard && <section className="insight-card-sp insight-card-notes">
      <header className="insight-card-sp-header">
        <span className="insight-card-sp-icon">{adviceCard.icon}</span>
        <div><b>{adviceCard.title}</b></div>
      </header>
      <span className={`action-direction ${actionLabel === "适合推进" ? "supportive" : actionLabel === "适合调整" ? "adjust" : "neutral"}`}>{actionLabel}</span>
      <p className="secondary-plain-note">次限盘描述内在变化节奏，不是事件预测。</p>
      <div className="advice-icon-list">{adviceCard.details.slice(0, 3).map((detail, i) => {
        const advice = splitAdvice(detail);
        return <p key={i}><span>{advice.icon}</span>{advice.text}</p>;
      })}</div>
    </section>}

    {natalCard && <section className="insight-card-sp insight-card-layers">
      <header className="insight-card-sp-header">
        <span className="insight-card-sp-icon">{natalCard.icon}</span>
        <div><b>{natalCard.title}</b></div>
      </header>
      <div className="natal-link-columns">
        <div><b>✦ 被强化</b>{strengthened.length ? strengthened.map((aspect) => <span key={aspect.aspect_id}>次限{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}强化了本命{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span>) : <span>当前没有突出的强化线索</span>}</div>
        <div><b>✦ 被挑战</b>{challenged.length ? challenged.map((aspect) => <span key={aspect.aspect_id}>次限{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}挑战了本命{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span>) : <span>当前没有突出的挑战线索</span>}</div>
      </div>
      <div className="new-potential-line">
        <b>✧ 新出现的内在可能</b>
        {newPotentials.length
          ? newPotentials.map((aspect) => <span key={aspect.aspect_id}>次限{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}{aspectNames[aspect.type] ?? aspect.type}本命{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span>)
          : <span>当前以内在既有主题的强化与调整为主。</span>}
      </div>
    </section>}
  </article>;
}
