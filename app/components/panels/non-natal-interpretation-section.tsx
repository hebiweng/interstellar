import { useState } from 'react';
import type { ReactNode } from 'react';
import type { InterpretationSection, ConsumerInsight } from '../../lib/consumer-insight';
import { ConsumerInsightCards } from './consumer-insight-cards';

export function NonNatalInterpretationSection({
  insight,
  sections,
  empty,
}: {
  insight: ConsumerInsight | null;
  sections: InterpretationSection[];
  empty?: ReactNode;
}) {
  const [activeTab, setActiveTab] = useState("overview");
  const tabs = [{ id: "overview", label: "整体解读" }, ...sections.map((s) => ({ id: s.id, label: s.label }))];
  return (
    <section className="result-section non-natal-interpretation" id="non-natal-interpretation">
      <div className="result-tabs">
        {tabs.map((tab) => <button key={tab.id} className={activeTab === tab.id ? "active" : ""} onClick={() => setActiveTab(tab.id)}>{tab.label}</button>)}
      </div>
      <div className="result-content">
        {activeTab === "overview" && (insight
          ? <ConsumerInsightCards
              insight={insight}
              themeLabel="整体解读"
              signalsTitle="最值得留意的信号"
              signalsHint="数字越高，当前关系越紧密"
              advice={<><div><b>比较适合做的事</b>{insight.strengths.map((item) => <p key={item}>• {item}</p>)}</div><div><b>需要注意的方面</b>{insight.reminders.map((item) => <p key={item}>• {item}</p>)}</div></>}
              closing={insight.closing}
            />
          : (empty ?? <div className="interpretation-empty"><p>等待计算完成后查看整体解读。</p></div>)
        )}
        {activeTab !== "overview" && <div className="interpretation-grid">
          {sections.find((s) => s.id === activeTab)?.cards.map((card) => (
            <article className="professional-card interpretation-card" key={card.id}>
              <header><div><small>{card.subtitle}</small><h3>{card.title}</h3></div></header>
              <ul>{card.bullets.map((bullet, index) => <li key={index}>{bullet}</li>)}</ul>
              {card.emphasis && <p>{card.emphasis}</p>}
            </article>
          ))}
        </div>}
      </div>
    </section>
  );
}
