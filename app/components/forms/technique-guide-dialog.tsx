import { useState, useEffect } from 'react';
import { SafeMarkdownDocument } from '../lib/local-interpretation';

export function TechniqueGuideDialog({
  open,
  title,
  path,
  onClose,
}: {
  open: boolean;
  title: string;
  path: string;
  onClose: () => void;
}) {
  const [markdown, setMarkdown] = useState("");
  useEffect(() => {
    let active = true;
    if (!open || markdown) return () => { active = false; };
    fetch(path, { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error(String(response.status));
        return response.text();
      })
      .then((text) => {
        const content = text
          .replace(/^\uFEFF?---\r?\n[\s\S]*?\r?\n---\r?\n/, "")
          .trim();
        if (active) setMarkdown(content);
      })
      .catch(() => { if (active) setMarkdown(`# ${title}\n\n说明暂时无法读取，请稍后重试。`); });
    return () => { active = false; };
  }, [markdown, open, path, title]);
  if (!open) return null;
  return <div className="modal-backdrop guide-modal-backdrop" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose(); }}><section className="person-modal natal-guide-modal" role="dialog" aria-modal="true" aria-label={title}><header><div><small>CHART GUIDE</small><h2>{title}</h2></div><button onClick={onClose} aria-label={`关闭${title}`}>×</button></header><div className="natal-guide-content">{markdown ? <SafeMarkdownDocument markdown={markdown} /> : <p>正在读取说明…</p>}</div></section></div>;
}
