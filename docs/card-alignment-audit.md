# 卡片结构对齐审计（原型 → iOS）

> 结构提取源：`docs/prototype-card-structure-audit.md`（六盘）、`docs/prototype-today-structure-audit.md`（Today）。
> 原则：每张卡按原型**自己的**元素结构对齐，不统一套用一种结构。

## TODAY

| 模块 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| Your Transits 主线 | transit-hero：kicker CURRENT CHAPTER + h2 + p + badge(Long-term) + meta 2 tag + chapter-line(起止+轨道) | TodayView.chapterHero | 结构已建，逐元素核对中 |
| 进行中/即将到来 | transit-row ×2：icon + badge(ACTIVE TODAY/COMING NEXT) + strong + p + meta 2 tag | TodayView.transitsSection | 结构已建，核对中 |
| Moon Today | moon-card：badge 72% + h3 Moon in Taurus + p + sign-progress + sign-labels(度数/下次) | TodayView.moonSection | 结构已建，核对中 |
| Today Timeline | timeline-card：time-event ×3(time+rail+strong+p) + now-line | TodayView.timelineSection | 结构已建，核对中 |
| Upcoming Sky Events | event-card ×2：date-box(月/日) + strong + p + impact-dot | TodayView.upcomingSection | 结构已建，核对中 |
| Retrogrades | retro-card：summary(strong+badge) + planet-status ×3(symbol+strong+p+tag) | TodayView.retrogradesSection | 结构已建，核对中 |
| Current Sky | sky-link：strong + p + › | TodayView.skyLinkCard | 已对齐 |

## NATAL（9 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| natal-interpretation | natal-lead：kicker + h2 + p + big-three(sun/moon/rise) + 3 行 big-three-list(span+strong) | natalCore(orbitCircle) | 核对 |
| love-connection | natal-card：icon + strong + p + mini-label | themeCards | 核对 |
| career-direction | path-flow 3 节点(span+strong) + kicker + p | growthPath(pathFlow) | 核对 |
| strengths-growth | dual-insight + edge-list 2 行(mark+strong+p) | edgeDual | 核对 |
| element-balance | balance-row ×4(span+track+i+span) + meta tag | elementRows | 核对 |
| house-emphasis | area-row ×3(strong+span+track) | houseRadar | 核对 |
| chart-signature | metric-trio ×3(span+strong) + interpret-note | signatureTrio | 核对 |
| planet-placements | position-row ×N(glyph+strong+p+state) | placementRows | 核对 |
| key-aspects | transit-item ×3(icon+strong+p+technical) | aspectRows | 核对 |

## CURRENT SKY（7 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| sky-overview | chart-hero：kicker + h2 + p + sky-summary + sky-pulse | skyOverview | 核对 |
| moon-now | progress-moon：phase-dial + phase-copy + meta | phaseDial + facts | 核对 |
| aspect-pattern | aspect-network(nodes+lines+center) + interpret-note | structureMap | 核对 |
| planetary-motion | position-list(glyph+strong+p+state) | motionList | 核对 |
| sign-changes | time-event ×3(time+rail+strong+p) | eventTimeline | 已改（真实 ingress） |
| element-climate | balance-row ×4 + meta | elementRows | 核对 |
| upcoming-7-days | event-card ×3(date-box+strong+p+impact-dot) | eventTimeline | 已改（真实事件） |

## TRANSITS（6 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| current-story | story-card：kicker + h3 + p + meta | storyWeave | 核对 |
| current-cycles | cycle-tabs ×3 + cycle-body rows | cycleTabs | 核对 |
| transit-timeline | gantt-row ×N(head strong+span + track i+b) | gantt | 已改（真实起止） |
| planet-paths | position-list(glyph+strong+p+state) | positionRows | 核对 |
| life-areas | area-row(strong+span+track) | areaRows | 核对 |
| active-transits | transit-item(icon+strong+p+technical) | aspectList | 核对 |

## SECONDARY（6 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| developmental-chapter | chart-hero：kicker + h2 + p + stage-flow 3 节点 | stageFlow | 结构已建；stage 文案需计算化 |
| progressed-moon | progress-moon + meta(In sign/Ingress) | moonProgress | 已加事件数据；核对渲染 |
| identity-development | compare-strip(span+strong ↔ span+strong) + interpret-note | identityCompare | 结构已建；语料待修 |
| turning-points | transit-item ×3(icon+strong+p+technical) | turningRows | 已改（真实月份） |
| areas-maturing | area-row ×4 | areaRows | 已对齐 |
| timeline | gantt-row ×3(head strong+span + track i+b) | gantt | 已改（真实区间） |

## SOLAR RETURN（7 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| year-theme | chart-hero：kicker + h2 + p + year-orbit(☉↑♄♃) + metric-trio ×3 | yearOrbit + trioCell | 结构已对齐；语料 hardcode 待修 |
| year-anchors | connection-grid 2×2：4 格(span 角度 + strong 参数 + p 一句解释) | anchorGrid(factGrid) | **结构不符，需改** |
| priority-areas | area-row ×4 | areaRows | 已对齐 |
| year-dynamics | dual-insight(span+strong ×2) + interpret-note | dualInsight | 结构已对齐；语料重复待修 |
| year-timeline | quarter-tabs ×4 + quarter-copy(strong 主题 + p 一句解释) | quarterTabs | **缺一句解释，需增强** |
| natal-overlay | compare-strip 2 节点(span+strong ↔ span+strong) + interpret-note | overlayCompare + 4 aspects | **结构不符，需改** |
| year-aspects | transit-item ×3(icon+strong+p+technical) | aspectList | 结构已对齐；语料待修 |

## SYNASTRY（8 卡）

| 卡 | 原型元素 | iOS 现状 | 判定 |
|---|---|---|---|
| relationship-overview | chart-hero：kicker + h2 + p + bond-orbit + meta | bondOrbit | 核对 |
| perspectives | perspective-tabs + panel | perspectiveTabs | 核对 |
| emotional-connection | connection-grid ×2(span+strong+p) | connectionGrid | 核对 |
| communication | path-flow + interpret-note | pathFlow | 核对 |
| chemistry | dual-insight + interpret-note | dualInsight | 核对 |
| commitment | connection-grid ×2 | connectionGrid | 核对 |
| house-overlays | area-row ×4 | houseOverlayRows | 核对 |
| key-inter-aspects | transit-item rows | aspectList | 核对 |
