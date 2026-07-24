from pathlib import Path
path = Path("app/page.tsx")
text = path.read_text(encoding="utf-8")
old = 'return <div className="modal-backdrop" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose(); }}><section className="modal-card natal-guide-modal"' new
=
"'return <div className=modal-backdrop
guide-modal-backdrop onMouseDown={(event) => { if (event.currentTarget === event.target) onClose(); }}><section className=modal-card
natal-guide-modal'"
if old not in text:
    raise SystemExit("marker not found")
text = text.replace(old, new)
path.write_text(text, encoding="utf-8")
print("patched")
