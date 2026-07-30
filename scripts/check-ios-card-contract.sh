#!/usr/bin/env bash
set -euo pipefail

factory="ios/App/InsightFactory.swift"
models="ios/App/Models.swift"
views="ios/App/InsightCards.swift"

expected_ids=(
  core-structure strongest-themes core-strengths blind-spot growth-direction
  sky-overview core-themes key-events structure-tension collective-domains observation-focus sky-evolution planet-overview
  daily-activity transit-overview trigger-themes support-pressure life-domains action-guidance transit-timeline intensity-calendar
  current-stage change-themes turning-points stage-advice natal-link
)

for id in "${expected_ids[@]}"; do
  if ! rg -q "id: \"$id\"" "$factory"; then
    echo "Missing iOS insight card: $id" >&2
    exit 1
  fi
done

required_manifests=(
  '.natal: ["core-structure", "strongest-themes", "core-strengths", "blind-spot", "growth-direction"]'
  '.currentSky: ["sky-overview", "core-themes", "key-events", "structure-tension", "collective-domains", "observation-focus", "sky-evolution", "planet-overview"]'
  '.transit: ["daily-activity", "transit-overview", "trigger-themes", "key-events", "support-pressure", "life-domains", "action-guidance", "transit-timeline", "planet-overview", "intensity-calendar"]'
  '.secondary: ["current-stage", "change-themes", "turning-points", "stage-advice", "natal-link"]'
)

for manifest in "${required_manifests[@]}"; do
  if ! rg -Fq "$manifest" "$factory"; then
    echo "Missing or reordered iOS card manifest: $manifest" >&2
    exit 1
  fi
done

required_visuals=(
  natalCore rankedThemes strengthOrbit blindSpot growthPath
  skyOverview themeCards eventTimeline structureMap domainBars observation evolution planetTable
  activityGauge transitOverview gantt balanceRing houseRadar actionGuidance arcTimeline doubleRing calendar
  progressedStage progressedThemes turningTimeline comparison
)

for visual in "${required_visuals[@]}"; do
  if ! rg -q "case (let )?\\.$visual|case $visual" "$views" "$models"; then
    echo "Missing iOS insight visual: $visual" >&2
    exit 1
  fi
done

for removed in identity-expression emotional-needs aspect-balance career-direction; do
  if rg -q "id: \"$removed\"" "$factory"; then
    echo "Obsolete natal card still present: $removed" >&2
    exit 1
  fi
done

rg -q 'values.count == 8' "$factory"
rg -q 'values.count == 12' "$factory"
rg -q 'values.count == 7' "$factory"
rg -q 'card.facts.count >= 10' "$factory"
rg -q '!\$0.summary.isEmpty && !\$0.detail.isEmpty' "$factory"

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
