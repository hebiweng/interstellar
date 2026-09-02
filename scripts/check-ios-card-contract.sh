#!/usr/bin/env bash
set -euo pipefail

factory="ios/App/Insights"
models="ios/App/Models.swift"
definitions="ios/App/ChartDefinition.swift"
manifest="ios/ContentSchema/card-contracts.json"
views="ios/App/Insights"

python3 - "$manifest" "$factory" "$definitions" <<'PY'
import json, pathlib, sys
manifest_path, factory_path, definitions_path = map(pathlib.Path, sys.argv[1:])
payload = json.loads(manifest_path.read_text())
expected_charts = {
    "natal", "current-sky", "transit", "secondary", "solar-return", "synastry",
    "tertiary", "lunar-return", "solar-arc", "relocation", "twelfth-harmonic", "thirteenth-harmonic",
}
if payload.get("schemaVersion", 0) < 4:
    raise SystemExit("card-contracts.json must use schemaVersion >= 4")
if set(payload.get("cards", {})) != expected_charts:
    raise SystemExit("card-contracts.json must declare all 12 chart kinds")
source = "\n".join(p.read_text() for p in factory_path.rglob("*.swift"))
for chart, card_ids in payload["cards"].items():
    for card_id in card_ids:
        if f'"{card_id}"' not in source:
            raise SystemExit(f"Missing iOS insight card: {chart}.{card_id}")
for chart in ["tertiary", "lunar-return", "solar-arc", "relocation", "twelfth-harmonic", "thirteenth-harmonic"]:
    if payload["cards"][chart]:
        raise SystemExit(f"{chart} must remain AI-report-only in this release")
definitions = definitions_path.read_text()
for prefix in expected_charts:
    if f'contentPrefix: "{prefix}"' not in definitions:
        raise SystemExit(f"ChartDefinition missing contentPrefix: {prefix}")
PY

required_visuals=(
  natalCore rankedThemes strengthOrbit blindSpot growthPath
  skyOverview themeCards eventTimeline structureMap domainBars observation evolution planetTable
  activityGauge transitOverview gantt balanceRing houseRadar actionGuidance arcTimeline doubleRing calendar
  progressedStage progressedThemes turningTimeline comparison
  signatureTrio placementList aspectList storyWeave cycleTabs positionRows areaRows phaseDial motionList elementRows
  stageFlow moonProgress identityCompare turningRows yearOrbit anchorGrid dualInsight quarterTabs overlayCompare
  bondOrbit perspectiveTabs synastryConnectionGrid synastryPathFlow synastryHouseOverlayRows synastryInterAspectRows
)

for visual in "${required_visuals[@]}"; do
  if ! rg -q "case (let )?\\.$visual|case $visual" "$views" "$models"; then
    echo "Missing iOS insight visual: $visual" >&2
    exit 1
  fi
done

for removed in core-structure strongest-themes core-strengths blind-spot growth-direction daily-activity current-stage change-themes stage-advice natal-link; do
  if rg -q "id: \"$removed\"" "$factory"; then
    echo "Obsolete card still present: $removed" >&2
    exit 1
  fi
done

rg -q 'let calculatedValue: String' "$models"
rg -q 'let interpretationKey: String?' "$models"
rg -q 'let sourceFactIDs: \[String\]' "$models"
rg -q 'let conclusionKey: String?' "$models"

if rg -q 'paddedFacts|No close signal|Nothing close enough to display' "$factory"; then
  echo "Placeholder or padded facts remain in the iOS card builder." >&2
  exit 1
fi

if rg -qi 'composite' "$factory" "$definitions" "$manifest"; then
  echo "Composite must remain outside the current chart/card factory contract." >&2
  exit 1
fi

for phrase in \
  "当前适合观察公共讨论与制度调整" \
  "个人感受仍需结合本命盘判断" \
  "行星位置与运行状态提供当前天象的基础事实" \
  "不同公共领域承载着密度不同的当前天象信号" \
  "不能预测具体社会事件" \
  "被反复触发的本命点与宫位形成当前核心主题"
do
  if rg -q "$phrase" ios/App --glob '*.swift'; then
    echo "Internal editorial wording leaked into consumer Swift: $phrase" >&2
    exit 1
  fi
done

echo "iOS card contract check passed."
