---
name: interstellar-pre-release-check
description: Use when completing code changes on the interstellar-v1 project before commit, deploy, or PR — runs lint, build, tests, standalone size check, and Docker build verification
---

# Interstellar Pre-Release Check

## Overview

Project-specific verification pipeline for the **interstellar-v1** Next.js + vinext astrology workbench.
Runs five stages sequentially; any failure blocks release.

## When to Use

- After any code change to `app/`, `scripts/`, `infra/`, or config files (`vite.config.ts`, `next.config.ts`, `package.json`)
- Before creating a commit, PR, or Docker deployment
- When the user says "测试一下"、"检查一下"、"发布前检查"、"跑一下测试"

## When NOT to Use

- Pure documentation changes (`.md` files only)
- Changes to `tests/` that don't affect app code
- Quick typo fixes in comments

## Pipeline Stages

### Stage 1 — Lint Check

```bash
npx next lint
```

- **Pass criteria**: 0 errors (warnings acceptable)
- **On failure**: Fix the error, re-run. Common issues: unescaped quotes in JSX, setState in useEffect without dependency.

### Stage 2 — Build

**Windows (PowerShell):**
```powershell
$env:WRANGLER_LOG_PATH=".wrangler/wrangler.log"; npx vinext build
```

**Linux / Docker:**
```bash
npm run build
```

- **Pass criteria**: All 5 vinext build stages complete (`analyze client → analyze server → build rsc → build client → build ssr`), output in `dist/standalone/`
- **On failure**: Check import paths, export keywords, type mismatches. vinext does NOT tolerate `'export'` inside nested functions.

### Stage 3 — Prune Standalone

```bash
node scripts/prune-standalone.mjs
```

- **Pass criteria**: Script runs without error, reports removed packages
- **Expected output**: removes 31 packages + 470 source map files
- **On failure**: Check `scripts/prune-standalone.mjs` exists and `dist/standalone/` is present

### Stage 4 — Tests

```bash
node --test tests/rendered-html.test.mjs
```

- **Pass criteria**: All tests pass (currently 12 tests)
- **On failure**: 
  - Check if test assertions match refactored file locations (use `readAppSource()` helper)
  - SSR rendering tests: verify `chartTechniques.slice(0, 11)` logic — `13分盘` is NOT in SSR output
  - Windows path issues: ensure `fileURLToPath()` is used, not `.pathname` on `import.meta.url`

### Stage 5 — Standalone Size Check

```bash
# Windows
Get-ChildItem -Recurse dist\standalone | Measure-Object -Property Length -Sum | ForEach-Object { "{0:N2} MB" -f ($_.Sum / 1MB) }

# Linux
du -sh dist/standalone
```

- **Pass criteria**: ≤ 10 MB total
- **Current baseline**: ~8.4 MB
- **On failure**: Check for new heavy dependencies, run `scripts/prune-standalone.mjs` again

### Stage 6 — Docker Build (Optional, for deployment)

```bash
docker build -f infra/deploy/Dockerfile.web -t interstellar-web:local .
docker run -d -p 3000:3000 interstellar-web:local
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/
```

- **Pass criteria**: HTTP 200 from `/`
- **On failure**: Check `Dockerfile.web` has `COPY scripts ./scripts`, check base image `node:22-bookworm-slim` is available

## Quick Reference

| Stage | Command | Pass Criteria | Timeout |
|-------|---------|---------------|---------|
| Lint | `npx next lint` | 0 errors | 60s |
| Build | `npx vinext build` | 5 stages complete | 300s |
| Prune | `node scripts/prune-standalone.mjs` | No errors | 30s |
| Test | `node --test tests/rendered-html.test.mjs` | All pass | 120s |
| Size | `du -sh dist/standalone` | ≤ 10 MB | 10s |
| Docker | `docker build + run + curl` | HTTP 200 | 600s |

## Common Issues

### Build fails with `WRANGLER_LOG_PATH` error on Windows
Use PowerShell: `$env:WRANGLER_LOG_PATH=".wrangler/wrangler.log"; npx vinext build`

### Test fails on `13分盘` assertion
`13分盘` is at index 13 in `chartTechniques`, but SSR only renders `slice(0, 11)`. Use `重置盘` (last in slice) + `更多盘型` instead.

### Test fails reading `app/page.tsx` for Chinese text
After refactoring, text is spread across component files. Tests use `readAppSource()` which reads all `.tsx`/`.ts` files in `app/` recursively.

### Standalone size exceeds 10 MB
Run `node scripts/prune-standalone.mjs` — it removes `@vercel/og` (dead weight from vinext) + 30 build-tool packages + source maps.

### Docker build fails on `scripts/prune-standalone.mjs`
Ensure `Dockerfile.web` contains `COPY scripts ./scripts` before the build step.

## Project Context

- **Stack**: Next.js 15 + vinext 0.0.50 + React 19 + TypeScript
- **Build tool**: vinext (Vite 8 + rolldown), NOT standard next build
- **Production OS**: Linux (Docker `node:22-bookworm-slim`)
- **Dev OS**: Windows (PowerShell)
- **Key constraint**: `node -e` with `require()` doesn't work in Node 25 ESM mode on Windows — use `.cjs` temp files for file operations
