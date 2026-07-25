import { useState, useEffect } from 'react';
import type { ItemInterpretation, NatalSnapshot } from '../../lib/interstellar-api';
import type { InterpretationTarget } from '../lib/chart-types';
import { getNatalItemInterpretation } from '../../lib/interstellar-api';
import { buildLocalInterpretation } from '../lib/local-interpretation';
import { isDateLevelSnapshot } from '../lib/chart-utils';

export function InterpretationDrawer({ target, snapshot, onClose }: { target: InterpretationTarget; snapshot: NatalSnapshot; onClose: () => void }) {
  const [result, setResult] = useState<ItemInterpretation>(() => buildLocalInterpretation(target, snapshot));
  const [loading, setLoading] = useState(snapshot.id.startsWith("calculation-") && Boolean(target.resultPath));
  useEffect(() => {
    let active = true;
    if (!snapshot.id.startsWith("calculation-") || !target.resultPath) return () => { active = false; };
    getNatalItemInterpretation(snapshot.id, target.type, target.resultPath, { includeTimeDependent: !isDateLevelSnapshot(snapshot) })
      .then((value) => {
        if (active) {
          setResult({
            ...value,
            title: value.title ?? target.title,
            facts: [...(target.facts ?? [target.fact]), ...(value.facts ?? [])],
          });
        }
      })
      .catch(() => undefined)
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [snapshot, target.fact, target.facts, target.id, target.resultPath, target.title, target.type]);
  const readableLayers = (result.layers ?? []).filter((layer) => Boolean(layer.meaning) && layer.status === "published");
  const visibleFacts = [...new Set(result.facts ?? [target.fact])].filter((fact) => {
    const value = fact.trim();
    return value.length > 0 && !value.startsWith("{") && !value.startsWith("[");
  });
  const unavailableTitle = result.status === "blocked_by_input_quality"
    ? "出生资料不足"
    : result.status === "not_applicable"
      ? "此项不适用"
      : "解读内容准备中";
  const unavailableCopy = result.status === "blocked_by_input_quality"
    ? result.unavailable_reason
    : result.status === "not_applicable"
      ? result.unavailable_reason
      : result.unavailable_reason || "这项计算已经完成，专门解读仍在补充中。";
  return (
    <div className="drawer-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <aside className="interpretation-drawer" role="dialog" aria-modal="true" aria-label="逐项解读">
        <header><div><span>逐项解读</span><h2>{result.title ?? target.title}</h2></div><button onClick={onClose} aria-label="关闭">×</button></header>
        {loading && <div className="drawer-loading">正在读取这项结果的解读…</div>}
        {visibleFacts.length > 0 && <section><h3>计算事实</h3>{visibleFacts.map((fact, index) => <p className="fact-line" key={`${index}:${fact}`}>{fact}</p>)}</section>}
        {readableLayers.length ? <section><h3>解读</h3><div className="interpretation-layers">{readableLayers.map((layer) => <article key={`${layer.item_kind}:${layer.content_hash}`} className="interpretation-layer status-published"><header><h4>{layer.label}</h4></header><p>{layer.meaning}</p></article>)}</div></section> : result.status === "available" && result.meaning ? <section><h3>解读</h3><p>{result.meaning}</p></section> : <section><h3>{unavailableTitle}</h3><p>{unavailableCopy}</p></section>}
      </aside>
    </div>
  );
}
