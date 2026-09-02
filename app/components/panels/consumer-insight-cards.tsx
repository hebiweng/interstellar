import type { ReactNode } from 'react';
import type { ConsumerInsight } from '../../lib/consumer-insight';

export function ConsumerInsightCards({
  insight,
  themeLabel,
  signalsTitle,
  signalsHint,
  advice,
  closing,
}: {
  insight: ConsumerInsight;
  themeLabel: string;
  signalsTitle: string;
  signalsHint: string;
  advice: ReactNode;
  closing: string;
}) {
  return (
    <article className="instant-insight">
      <section className="instant-theme"><span>{themeLabel}</span><h3>{insight.title}</h3><p>{insight.summary}</p></section>
      <section className="insight-dimensions">{insight.dimensions.map((dimension) => <div key={dimension.id}><header><b>{dimension.label}</b><strong>{dimension.score}</strong></header><i><span style={{ width: `${dimension.score}%` }} /></i><small>{dimension.note}</small></div>)}</section>
      <section className="aspect-balance"><header><b>顺势的地方与容易卡住的地方</b></header><div><span className="supportive" style={{ flex: insight.aspectBalance.supportive || 0.25 }} /><span className="tension" style={{ flex: insight.aspectBalance.tension || 0.25 }} /><span className="neutral" style={{ flex: insight.aspectBalance.neutral || 0.25 }} /></div><footer><span>容易配合 {insight.aspectBalance.supportive}</span><span>需要协调 {insight.aspectBalance.tension}</span><span>彼此相连 {insight.aspectBalance.neutral}</span></footer><p>{insight.aspectBalance.meaning}</p></section>
      <section className="top-signals"><header><b>{signalsTitle}</b><small>{signalsHint}</small></header>{insight.signals.map((signal) => <div key={signal.id}><span>{signal.strength}</span><p><b>{signal.title}</b><small>{signal.detail}</small><em>{signal.meaning}</em></p></div>)}</section>
      <section className="insight-advice">{advice}</section>
      <section className="insight-closing"><b>最后提醒</b><p>{closing}</p></section>
    </article>
  );
}
