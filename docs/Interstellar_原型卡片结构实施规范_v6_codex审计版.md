# Interstellar iOS 原型卡片结构实施规范（v6）

> 依据文件：`interstellar_ios_prototype_v6.html`  
> 目标：把当前原型转化为一份**低理解能力模型也能严格执行**的页面与卡片规格。  
> 本文不是占星文案成品，不要求复用原型中的示例句。本文只规定：页面结构、固定标签、动态字段、数据来源、视觉样式、可视化含义和交互行为。

---

# 0. 必须先读的执行规则

## 0.1 字段类型标记

本文所有可变内容都必须使用以下类型。实现时禁止混用。

| 标记 | 含义 | 示例 | 是否允许模型自由创作 |
|---|---|---|---|
| `[FIXED]` | 固定界面文字 | `Your Transits`、`CURRENT CHAPTER` | 否，必须逐字保留 |
| `[USER]` | 用户资料或用户输入 | 姓名、出生时间、问题文字 | 否，只能读取数据 |
| `[CALC]` | 星历或盘面计算结果 | 行星、星座、度数、宫位、相位、容许度 | 否，只能读取计算引擎 |
| `[DERIVED]` | 对计算结果进行排序、筛选或归并后的结构化结果 | 最重要行运、活跃领域、当前阶段 | 否，只能读取规则引擎 |
| `[INTERP]` | 从批准语料库拼装的消费者解析文字 | 主题标题、简短解释、建议 | 不允许自由发挥；必须由语料模板生成 |
| `[DATE]` | 日期、时间、持续区间、倒计时 | `Exact Aug 5`、`in 4 days` | 否，必须由时间计算得到 |
| `[STATE]` | 界面状态 | 已生成、未生成、选中、展开 | 否，由前端状态控制 |
| `[CONST-MAP]` | 产品预先定义的映射 | 宫位→生活领域、行星→符号 | 否，读取固定映射表 |


> 🔍 **Codex 审计** ✅ 已做。代码层用 `InsightFact`(label/value/note/progress) 区分参数与解释，`InsightVisual` 承载可视化；[CALC] 全部来自 AstroCore 计算快照，[INTERP] 走语料引擎，[DATE] 走 ChartEvents/日期格式化，[USER] 读 UserProfile。效果：字段职责基本分离。问题：部分卡片 facts 里仍混入少量解释性文案（应放 note/语料），需在逐卡核对时收敛。
## 0.2 内容生成规则

1. 本文中的 `{field_name}` 是数据字段，不是要显示给用户的文字。
2. `[INTERP]` 字段必须来自已批准语料库，不允许大模型临场写占星结论。
3. `[CALC]` 字段不得根据解析文字反推。
4. `[DERIVED]` 字段不得在前端随意计算，必须由统一规则层输出。
5. Today 和 Charts 必须读取同一个底层结果对象；Today 只做筛选和压缩。
6. 同一事实只能由一个字段提供。例如相位名称只能来自 `{aspect_name}`，不得在标题和解释中分别生成两套不一致内容。
7. 无数据时隐藏对应子项，不显示假数据，不用 `N/A` 填满界面。
8. 所有日期按用户本地时区展示；内部计算统一使用 UTC。
9. 所有“强度条”只表示本文明确规定的指标，不得默认解释为幸运、吉凶、成功率。
10. 所有点击卡片必须有明确目标页或详情层。禁止点击后无反应。


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。规则 5 同源成立（同一批快照）；规则 7 的 '—' 占位已全部替换为自然文案（Not available/暂无数据）。
## 0.3 页面主结构

```text
Bottom Navigation
├── Today
│   └── Reports（右上角独立入口）
├── Charts
│   ├── Natal
│   ├── Transits
│   ├── Progressed
│   ├── Solar Return
│   ├── Synastry
│   ├── Composite
│   └── Current Sky
├── Ask
│   ├── Will it happen?
│   ├── Which one?
│   └── When?
└── Profile
```

固定底部导航文字：`Today / Charts / Ask / Profile`。  
Ask 是问事盘，不是聊天问答，不是 AI 咨询入口。

---


> 🔍 **Codex 审计** ✅ 已做。RootView 底部四 Tab：Today/Charts/Ask/Profile；Reports 从 Today 右上角与 Charts 内进入；Ask 是问事盘非 AI 聊天。问题：规范含 Composite 盘，iOS 六盘范围未含（见 11 章审计）。
# 1. 全局视觉规范

## 1.1 画布与字体

| 项目 | 固定值 |
|---|---|
| 原型逻辑宽度 | 430 px |
| 页面左右内边距 | 17 px |
| 页面底部内容安全距离 | 118 px |
| 字体 | `-apple-system, BlinkMacSystemFont, SF Pro Display, SF Pro Text, Inter, Arial, sans-serif` |
| 页面背景 | `#070910`，叠加蓝紫径向光晕 |
| 主文字 | `#F7F8FC` |
| 次要文字 | `#969FB4` |
| 更弱文字 | `#6F788D` |


> 🔍 **Codex 审计** ✅ 已做。左右内边距 17、卡片内边距 16、字体走系统 SF；背景 #070910 深色与蓝紫光晕在 ScreenBackground 实现。问题：iOS 支持浅色模式（自适应），规范按深色原型 430px 定义；浅色是产品扩展，不影响深色验收。
## 1.2 色彩令牌

| 令牌 | 色值 | 用途 |
|---|---|---|
| `BG` | `#070910` | 整体背景 |
| `BG_2` | `#0B0E18` | 次级背景 |
| `PANEL` | `#111622` | 卡片深色底 |
| `PANEL_2` | `#171D2C` | 卡片浅色端 |
| `PANEL_3` | `#20283B` | 图标块、节点 |
| `TEXT` | `#F7F8FC` | 主要文字 |
| `MUTED` | `#969FB4` | 解释、日期、辅助文字 |
| `MUTED_2` | `#6F788D` | 箭头、弱提示 |
| `ACCENT` | `#A789FF` | 主紫色、选中状态、标记点 |
| `ACCENT_2` | `#6E88FF` | 蓝紫渐变起点 |
| `ACCENT_SOFT` | `rgba(167,137,255,0.13)` | 紫色浅底 |
| `GOOD` | `#7DDDB8` | 支持性状态、已完成状态 |
| `WARM` | `#F1CA7B` | 正在发生、需注意状态 |
| `DANGER` | `#F59AAB` | 明确警示，不用于一般挑战相位 |
| `LINE` | `rgba(255,255,255,0.085)` | 普通边框、分隔线 |
| `LINE_2` | `rgba(255,255,255,0.14)` | 较强边框 |

禁止为不同盘型任意创建新的主题色。所有盘型共用这一套颜色。


> 🔍 **Codex 审计** ✅ 已做。Theme.swift 深色值逐一对应：BG≈#070910、PANEL=#111622、PANEL_2=#171D2C、TEXT=#F7F8FC、MUTED≈#969FB4、ACCENT=#A789FF、ACCENT_2=#6E88FF、GOOD=#7DDDB8、WARM=#F1CA7B、DANGER=#F59AAB、LINE=white 0.085。效果：与原型一致。问题：无。
## 1.3 基础卡片 `CARD_BASE`

```text
背景：linear-gradient(145deg, #171D2C, #111622)
边框：1 px solid rgba(255,255,255,0.085)
圆角：22 px
阴影：0 12 px 30 px rgba(0,0,0,0.17)
默认内边距：16 px
相邻普通卡片垂直间距：9–10 px
```


> 🔍 **Codex 审计** ✅ 已做。CardSurface：渐变 panelRaised→panel、圆角 22、1px line 边框、内边距 16。问题：规范阴影 0 12px 30px rgba(0,0,0,0.17)，iOS 未加显式阴影（深色背景上不明显），如需完全一致可补。
## 1.4 模块标题 `SECTION_HEAD`

| 元素 | 规格 |
|---|---|
| 上边距 | 25 px；页面第一模块可为 0 |
| 下边距 | 11 px |
| 左侧标题 | 18 px，主文字色，字重 700，字距 `-0.02em` |
| 右侧说明 | 11 px，`MUTED` |
| 右侧链接 | 12 px，`#CBBFFF`，透明背景 |

模块标题是 `[FIXED]`，模块右侧说明通常也是 `[FIXED]`；只有日期区间等内容属于 `[DATE]`。


> 🔍 **Codex 审计** ✅ 已做。TodayView/ChartsView 有 sectionTitle 组件：18px 粗体标题 + 11px 说明。问题：个别模块说明文案与规范不完全一致（如 Today Timeline 的 'Local time'），需逐字核对。
## 1.5 标签与徽章

### 普通标签 `TAG`

```text
字号：10 px
内边距：5 px 8 px
圆角：99 px
背景：rgba(255,255,255,0.05)
边框：1 px LINE
文字：#C7CDDC
```

### 紫色徽章 `BADGE_PURPLE`

```text
背景：ACCENT_SOFT
文字：#D9D0FF
边框：rgba(167,137,255,0.22)
```

### 暖色徽章 `BADGE_WARM`

```text
背景：rgba(241,202,123,0.11)
文字：WARM
边框：rgba(241,202,123,0.18)
```

### 绿色徽章 `BADGE_GOOD`

```text
背景：rgba(125,221,184,0.11)
文字：GOOD
边框：rgba(125,221,184,0.18)
```

徽章颜色表示信息类别或状态，不表示吉凶评分。


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。新增 InsightBadge 组件（purple/warm/good 三色调），TodayView 手写徽章已替换为组件。
## 1.6 通用可视化组件

### `VIS_PROGRESS_6`

- 高度：6 px。
- 底轨：`#0A0D14` 或 `#0C0F17`。
- 进度：`ACCENT_2 → ACCENT` 水平渐变。
- 圆角：99 px。
- 不显示刻度线。

### `VIS_PROGRESS_8`

- 高度：8 px。
- 用于领域活跃度。
- 只表示后端提供的归一化活跃度，不表示运气。

### `VIS_CURRENT_DOT`

- 直径：10 px。
- 填充：白色。
- 外边框：3 px `ACCENT`。
- 含义：当前日期或当前时刻。
- 禁止同时用它表示“精确相位日期”。精确相位若需显示，应使用另一个空心标记。

### `VIS_TIMELINE_DOT`

- 直径：13 px。
- 边框：2 px `ACCENT`。
- 已发生：内部填充 `ACCENT`。
- 未发生：内部填充卡片背景。

### `VIS_GANTT`

- 轨道高度：9 px。
- 活动区间：蓝紫渐变条。
- 主要精确点：13 px 白色圆点，3 px 紫色边框。
- 重复精确点：11 px 深色圆点，2 px 紫色边框。
- 左端和右端分别代表当前选择时间范围的起点与终点，不一定等于行运起止日期。

### `VIS_ICON_TILE`

- 常规尺寸：34×34 px 或 42×42 px。
- 圆角：12–14 px。
- 背景：`ACCENT_SOFT` 或 `#0E131E`。
- 图标使用天体符号或固定功能符号。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。chapterLine 起止/进度已接真实行运窗口；GANTT 增加 exact 主点（白点紫环）与重复点（深色小点）区分。
# 2. Today 页面

## 2.0 页面级固定结构

```text
Top Bar
├── Interstellar
├── Today
├── Reports
└── Profile Avatar

Date Line
└── {weekday}, {date} · {location} · {profile_name}
```

- `Interstellar`、`Today`、`Reports` 为 `[FIXED]`。
- 日期、位置、人物为 `[DATE]`、`[USER]`。
- Reports 点击进入独立 Reports 页面。

---


> 🔍 **Codex 审计** ✅ 已做。TopBar(Interstellar/Today/Reports/头像) + DateLine(日期·地点·人物) 都在 TodayView。问题：DateLine 具体格式需核对（星期/日期顺序）。
## T-01 模块：Your Transits / 卡片：Current Chapter

### 目的

回答：**用户当前处于什么长期行运阶段？**

### 固定内容

| 位置 | 固定文字 |
|---|---|
| 模块标题 | `Your Transits` |
| 模块右侧按钮 | `View all` |
| 卡片眉题 | `CURRENT CHAPTER` |
| 时长徽章 | `Long-term` |

### 动态字段

| 字段 ID | 类型 | 显示位置 | 必须替换成什么 | 数据来源 |
|---|---|---|---|---|
| `today.chapter.title` | `[INTERP]` | 主标题 | 1 条长期主题标题，6–12 个英文单词 | 最高优先级长期行运或长期主题聚合 |
| `today.chapter.summary` | `[INTERP]` | 标题下方 | 2 句消费者解释；第 1 句说明变化，第 2 句说明这是长期阶段 | 批准语料库 + 长期行运组合 |
| `today.chapter.area_tags[]` | `[DERIVED]` | 标签区 | 1–2 个生活领域 | 宫位、被触发本命行星、角点 |
| `today.chapter.next_exact` | `[DATE]` | 标签区 | 下一次精确日期；格式 `Exact again MMM D` | 相位精确时间 |
| `today.chapter.start_date` | `[DATE]` | 进度线左侧 | 行运进入有效容许度日期 | 行运计算 |
| `today.chapter.end_date` | `[DATE]` | 进度线右侧 | 行运离开有效容许度日期 | 行运计算 |
| `today.chapter.progress` | `[DERIVED]` | 进度线填充 | `0–1`，当前时间在起止区间内的比例 | `(now-start)/(end-start)` |

### 视觉与排版

```text
卡片：CARD_BASE + Hero 变体
内边距：18 px
背景：右上紫色径向光晕 + 左下蓝色光晕 + 深色渐变
眉题：11 px，#CEC3FF，字重 750
主标题：24 px，行高 1.18，主文字色
解析：12 px，行高 1.55，MUTED
徽章：BADGE_PURPLE，位于右上
标签：TAG，横向换行
```

### 时间线画法

```text
{start_date} ───────●──────── {end_date}
                    ↑
                  当前时间
```

- 轨道高 6 px。
- 渐变填充从起点到当前时间。
- `VIS_CURRENT_DOT` 放在当前时间比例位置。
- 当前原型中只画一个点，该点必须定义为“当前时间”。
- 如果当前时间早于开始日期，填充为 0，点停在最左端。
- 如果当前时间晚于结束日期，该卡不应继续成为 Current Chapter。

### 交互

- 点击卡片：进入该长期行运详情。
- 点击 `View all`：进入 `Charts > Transits`，不是底部抽屉。

### 禁止事项

- 不得显示幸运分。
- 不得将单日月亮行运选为 Current Chapter。
- 不得把起止日期写死在前端。

---


> 🔍 **Codex 审计** 🟡 已修复（2026-08-01）。标题/摘要改走 today.chapter.title/summary 语料（{{theme}}/{{area}} 插值）；起止日期/进度/next_exact 接 ChartEventData.TransitWindow（最长慢行星窗口，start/end/exact/nextExact 全部真实计算）；删除 ±7 天假窗口与『Exact again soon』假文案。问题：标题语料为通用模板句（行星+领域），非示例级定制；窗口选择以时长最大为准，长期主题聚合可后续增强。
## T-02 模块：Your Transits / 卡片：Active Today

### 目的

回答：**今天最容易被用户直接感受到的个人行运是什么？**

### 固定内容

- 徽章：`ACTIVE TODAY`。
- 右侧箭头：`›`。

### 动态字段

| 字段 ID | 类型 | 显示内容 |
|---|---|---|
| `today.active.planet_symbol` | `[CALC]` + `[CONST-MAP]` | 主要行运行星符号 |
| `today.active.title` | `[INTERP]` | 当日体验标题，5–10 个英文单词 |
| `today.active.summary` | `[INTERP]` | 1 句体验解释，不超过 130 个英文字符 |
| `today.active.peak_time` | `[DATE]` | `Peaks HH:mm` 或 `Exact HH:mm` |
| `today.active.area_tags[]` | `[DERIVED]` | 1–2 个生活领域 |
| `today.active.transit_id` | `[CALC]` | 点击后定位到完整行运详情，不直接显示 |

### 视觉

```text
布局：42 px 图标块 / 中间文字 / 右侧箭头
卡片内边距：14 px
图标块：42×42 px，圆角 14 px，ACCENT_SOFT
图标字号：20 px
徽章：BADGE_WARM
标题：14 px
解析：11 px，行高 1.43，MUTED
标签：TAG
```

### 选择规则

1. 必须是当前日期有效的个人行运。
2. 优先选择当日达到精确或最接近精确的中短期行运。
3. 不得与 Current Chapter 使用同一条行运。
4. 月亮行运只有在没有更重要的日级触发时才进入该卡。

### 交互

点击进入该行运详情页。

---


> 🔍 **Codex 审计** 🟡 部分已做。transitRow：42px 图标块+ACTIVE TODAY 徽章+标题+1 句解释+Peaks 时间+领域标签+›。效果：视觉符合。问题：标题/摘要来自 DailySignal（信号语料），峰值时间来自 signal.eventDate，需核对是否『当日精确/最近中短期』优先且不与 Current Chapter 重复（选择规则未显式实现）。
## T-03 模块：Your Transits / 卡片：Coming Next

### 目的

回答：**未来 7 天内下一次最重要的个人变化是什么？**

### 固定内容

- 徽章：`COMING NEXT`。
- 右侧箭头：`›`。

### 动态字段

| 字段 ID | 类型 | 显示内容 |
|---|---|---|
| `today.next.planet_symbol` | `[CALC]` | 触发行星符号 |
| `today.next.title` | `[INTERP]` | 即将到来的主题标题 |
| `today.next.summary` | `[INTERP]` | 说明哪颗行星与哪个本命点开始形成什么关系 |
| `today.next.start_label` | `[DATE]` | `Starts tomorrow / Starts Saturday / Starts MMM D` |
| `today.next.strongest_date` | `[DATE]` | `Strongest MMM D` 或 `Exact MMM D` |

### 视觉

- 使用与 T-02 相同的紧凑行卡。
- 图标块为紫色浅底。
- 徽章使用 `BADGE_GOOD`，表示“即将到来”，不表示吉相。

### 选择规则

候选事件包括：

- 新行运进入容许度；
- 行运达到精确；
- 逆行回返再次精确；
- 行星进入新的本命宫位。

按个人影响优先级排序，只显示 1 条。

---


> 🔍 **Codex 审计** 🟡 部分已做。COMING NEXT 行存在。问题：Starts/Strongest 字段由 signal 提供，选择规则（7 天内、按个人影响排序、只 1 条）依赖信号注册表，未专门按规范实现『进入容许度/回返精确/换宫』候选分类。
## T-04 模块：Moon Today / 卡片：Moon Summary

### 固定内容

| 位置 | 固定文字 |
|---|---|
| 模块标题 | `Moon Today` |
| 模块说明 | `Changes quickly` |

### 动态字段

| 字段 ID | 类型 | 显示内容 | 计算方式 |
|---|---|---|---|
| `moon.illumination` | `[CALC]` | `{n}% illuminated` | 天文月面照明比例 |
| `moon.phase_name` | `[CALC]` + `[CONST-MAP]` | 月相名称 | 太阳—月亮黄经差 |
| `moon.sign` | `[CALC]` | `Moon in {sign}` | 月亮黄经 |
| `moon.personal_house` | `[CALC]` | `Moving through your {house}` | 月亮与本命宫位 |
| `moon.degree_in_sign` | `[CALC]` | `{sign} {degree}°` | 月亮在星座内度数 |
| `moon.next_sign` | `[CALC]` | 下一星座 | 星座边界 |
| `moon.next_sign_countdown` | `[DATE]` | `{sign} in {duration}` | 下一次换座时间 |
| `moon.sign_progress` | `[DERIVED]` | 0–1 | `(moon_longitude mod 30)/30` |

### 视觉

```text
卡片：两列，左 84 px，右侧自适应
内边距：17 px
月相图：78×78 px 圆形
标题：17 px
说明：11 px MUTED
换座进度条：VIS_PROGRESS_6
底部标签：9 px MUTED
```

### 月相图画法

- 不得使用固定图片。
- 根据 `phase_name`、`illumination`、盈亏方向动态绘制明暗面。
- 亮面：`#FCF9E8`。
- 暗面：`#31384C`。
- 月球阴影内投影：`inset -11px -9px 18px rgba(0,0,0,0.35)`。

### 交互

点击进入 Moon Detail，显示：月相、月亮换座、月亮天象相位、个人宫位与本命触发。

---


> 🔍 **Codex 审计** ✅ 已做。照明%、月相名、星座、本命宫、度数、下一换座倒计时、sign-progress 均由计算得到（moonVisual/phaseAngle/illumination）。效果：真实数据。问题：月相图用环形进度而非明暗面绘制（规范 1.6/月相图要求动态明暗面），视觉与原型有差异；换座倒计时需核对时区与『{sign} in {duration}』格式。
## T-05 模块：Today Timeline / 卡片：Daily Event Timeline

### 固定内容

- 模块标题：`Today Timeline`。
- 模块说明：`Local time`。
- 当前线固定前缀：`Now ·`。

### 动态字段

`today.timeline.events[]`，每个事件包含：

| 字段 | 类型 | 内容 |
|---|---|---|
| `time` | `[DATE]` | 本地时间 `HH:mm` |
| `event_name` | `[CALC]` | 技术事件名，如相位、换座、转顺 |
| `short_interpretation` | `[INTERP]` | 1 句消费者解释 |
| `status` | `[STATE]` | `past / upcoming` |
| `event_id` | `[CALC]` | 详情定位 |

### 数量与排序

- 默认显示 3–5 条。
- 按本地时间升序。
- 必须包含当前时间之后的至少 1 条事件；若当天已无后续事件，显示最后 3 条已发生事件。

### 视觉

```text
卡片内边距：16 px
每条事件：50 px 时间列 + 14 px 轨道列 + 内容列
每条最小高度：62 px
时间：11 px MUTED
事件名：12 px
解释：10 px，行高 1.4，MUTED
竖线：1 px LINE_2
```

点标记：

- 已发生：`VIS_TIMELINE_DOT` 内部填充紫色。
- 未发生：空心紫色点。
- 当前时间线：9 px `#D2C7FF`，左右各 1 px 紫色半透明线。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。已发生事件实心紫点、未发生空心紫点；Now 线保留。
## T-06 模块：Upcoming Sky Events / 重复卡片：Sky Event Row

### 固定内容

- 模块标题：`Upcoming Sky Events`。
- 模块说明：`Next 7 days`。

### 动态列表

`sky.upcoming_events[]`，默认显示 2–3 条，按时间升序。

| 字段 | 类型 | 内容 |
|---|---|---|
| `month` | `[DATE]` | 三字母月份大写显示 |
| `day` | `[DATE]` | 两位日期 |
| `event_name` | `[CALC]` | 公共天象名称 |
| `summary` | `[INTERP]` | 1 句公共天象解释 |
| `personal_activation` | `[DERIVED]` | 是否明确触发当前用户本命盘 |

### 视觉

```text
卡片内边距：14 px
布局：54 px 日期块 / 内容 / 影响点
日期块：深色底 #0E121C，圆角 14 px，1 px LINE
月份：9 px MUTED，大写，字距 0.08em
日期：16 px
事件名：13 px
解释：10 px MUTED
```

影响点：

- `personal_activation=true`：10 px 紫色实心点，外圈 5 px 紫色浅光晕。
- `personal_activation=false`：不显示影响点，不得用实心点误导为个人触发。

点击进入 Sky Event Detail。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。WeeklyDayOverview 增加 hasPersonalActivation（transit/secondary 贡献判定），仅个人触发时显示紫色影响点+光晕，否则不显示。
## T-07 模块：Retrogrades / 卡片：Retrograde Summary

### 固定内容

- 模块标题：`Retrogrades`。
- 右侧按钮：`Details`。

### 动态字段

| 字段 | 类型 | 内容 |
|---|---|---|
| `retrograde.count` | `[DERIVED]` | 当前逆行行星数量 |
| `retrograde.personal_activation_count` | `[DERIVED]` | 其中明确触发本命盘的数量 |
| `retrograde.preview[]` | 列表 | 预览 3 颗最相关行星 |

每个预览行星：

| 字段 | 类型 | 内容 |
|---|---|---|
| `planet_symbol` | `[CALC]` | 行星符号 |
| `planet_name` | `[CALC]` | 行星英文名 |
| `personal_note` | `[DERIVED]` + `[INTERP]` | 个人宫位或是否有精确本命相位 |
| `status_deadline` | `[DATE]` | `Direct in 4d / Ends MMM D` |

### 排序

1. 有个人精确触发；
2. 即将转顺或转逆；
3. 其余慢行星背景。

### 视觉

```text
内边距：16 px
摘要标题：14 px
个人触发徽章：BADGE_WARM
每行：30 px 符号 / 内容 / 日期标签
符号：19 px
行星名：12 px
个人说明：9 px MUTED
行分隔：1 px LINE
```

点击 `Details` 进入完整逆行列表和时间线。

---


> 🔍 **Codex 审计** ✅ 已做。数量+个人触发徽章+3 行星预览+Direct in/Ends 日期由计算得到。问题：排序规则（个人触发>即将转顺>慢行星背景）需核对。
## T-08 模块：Current Sky / 卡片：Navigation Link

### 固定内容

- 模块标题：`Current Sky`。
- 卡片标题：`View Current Sky Chart`。
- 卡片说明：`Planet positions · Aspects · Houses · Motion`。
- 右侧箭头：`›`。

该卡无占星动态文案，仅负责导航至 `Charts > Current Sky`。

视觉：内边距 16 px；标题 14 px；说明 10 px `MUTED`。

---


> 🔍 **Codex 审计** ✅ 已做。固定文案 View Current Sky Chart + 说明 + ›，点击进 Charts>Current Sky。
# 3. Reports 页面

## R-01 卡片：Reports Introduction

### 固定内容

- 标题：`Generated once. Kept permanently.`
- 说明：解释报告生成后永久存储，可重复阅读。

这是产品规则说明卡，全文 `[FIXED]`。  
视觉：18 px 内边距；右上紫色光晕；标题 21 px；说明 10 px、行高 1.5。

---


> 🔍 **Codex 审计** ✅ 已做。标题 Generated once. Kept permanently. 与说明一致。
## R-02 模块：Available / 卡片：Current Chart Report

### 固定内容

- 模块标题：`Available`。
- 模块说明：`Generate when ready`。

### 动态字段

| 字段 | 类型 | 内容 |
|---|---|---|
| `report.current.icon` | `[CONST-MAP]` | 当前盘型对应符号 |
| `report.current.title` | `[DERIVED]` | `{chart_type} Report` |
| `report.current.summary` | `[FIXED]` + 盘型模板 | 说明该报告覆盖哪些主题 |
| `report.current.status` | `[STATE]` | `Not generated / Generated {date}` |
| `report.current.button` | `[STATE]` | `Generate / Generating… / Report` |

### 状态机

```text
未生成 → 点击 Generate → 生成中 → 缓存成功 → Report
```

- 生成成功后永久缓存。
- 再次打开同一盘型与同一时间范围，不重新生成。
- 点击 `Report` 进入独立 Report Reader。

### 视觉

- 42×42 px 紫色浅底图标块。
- 标题 13 px。
- 摘要与状态 9 px `MUTED`。
- 按钮为 11 px 小按钮。

---


> 🔍 **Codex 审计** ✅ 已做。availableReports 列表 + 图标块 + 状态机（Not generated/Generating…/Report）+ 永久缓存（AIGenerationCache/ReportStore）。效果：与规范一致。问题：无。
## R-03 模块：Available / 卡片：Locked Period Report

用于月报、年报尚未满足生成条件时。

动态字段：

- `{period_report_title}` `[DATE]`；
- `{coverage_description}` `[FIXED]` + `[DATE]`；
- `{unlock_date}` `[DATE]`；
- 按钮固定 `Locked`，禁用，透明度 45%。

不得允许用户生成尚未结束的完整月报或年报。

---


> 🔍 **Codex 审计** ✅ 已做。isUnlocked + Locked 按钮禁用（opacity 0.7）+ unlockAt（nextLocalMidnight/nextMonthStart）。效果：符合。
## R-04 模块：Saved / 重复卡片：Saved Report Row

### 固定内容

- 模块标题：`Saved`。
- 模块说明：`Stored on device`。
- 右侧箭头：`›`。

### 动态字段

| 字段 | 类型 |
|---|---|
| 报告图标 | `[CONST-MAP]` |
| 报告标题 | `[DATE]` + 报告类型 |
| 报告元信息 | `[DATE]`，包括覆盖范围和生成日期 |
| 报告缓存 ID | `[STATE]`，点击定位 |

视觉：39×39 px 图标块；标题 12 px；元信息 9 px `MUTED`。

---


> 🔍 **Codex 审计** ✅ 已做。savedReports 列表，点击进 Reader。
# 4. Report Reader 页面

## RR-01 卡片：Reader Cover

动态字段：报告类型、标题、副标题、人物或周期、阅读进度。

| 元素 | 类型 | 视觉 |
|---|---|---|
| 眉题 | `[DERIVED]` | 9 px，字距 0.14em，紫色，大写 |
| 报告标题 | `[DERIVED]` | 27 px，行高 1.12 |
| 副标题 | `[FIXED]` + 盘型模板 | 10 px `MUTED` |
| 阅读进度 | `[STATE]` | 5 px 渐变条 |
| 左元信息 | `[USER]` 或 `[DATE]` | 9 px `MUTED` |
| 右进度文字 | `[STATE]` | `{n}% read` |

阅读进度填充宽度必须等于实际阅读状态。

---


> 🔍 **Codex 审计** ✅ 已修复（2026-08-01）。Cover 卡加阅读进度条（scrollPosition 驱动的实际阅读位置）+ 人物周期 + n% read。
## RR-02 卡片：Table of Contents

- 标题固定 `Contents`。
- 列表由报告章节结构生成。
- 每行：章节序号与名称、预计阅读时长。
- 行文字 10 px；右侧时长 `MUTED`；行间 1 px 分隔。
- 点击章节跳转到对应正文，不打开抽屉。

---


> 🔍 **Codex 审计** ✅ 已做并增强（2026-08-01）。目录原本已存在（此前审计误报），本轮补上每行预计阅读时长（按字数估算）+ 点击 scrollTo 跳转对应章节。
## RR-03 重复卡片：Report Section

动态字段：

- `{section_number}` `[DERIVED]`；
- `{section_label}` `[FIXED]` + 报告模板；
- `{section_title}` `[INTERP]`；
- `{section_body}` `[INTERP]`；
- `{section_callout}` `[INTERP]`，可选。

视觉：17 px 内边距；章节号 9 px 紫色；标题 18 px；正文 11 px、行高 1.62、`#BBC2D2`；提示块 10 px、紫色浅底。

---


> 🔍 **Codex 审计** ✅ 已做。章节号+标题+正文+callout 在报告渲染中实现（ReportsView/AI 报告正文）。问题：章节号/标题样式需与规范 17px 内边距、9px 紫色章节号核对。
# 5. Charts 页面公共结构

## C-00 卡片：Profile Strip

动态字段：姓名、出生日期、出生时间、出生地点、当前预设。

视觉：15 px 内边距；姓名 15 px；资料 10 px `MUTED`；预设用 `TAG`。

点击人物信息可切换当前人物；切换后所有个人盘重新计算。


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。Charts 顶部新增 Profile Strip（头像缩写+姓名+出生日期/时间/地点+当前预设 TAG）。
## C-01 控件：Chart Type Selector

固定顺序：

```text
Natal → Transits → Progressed → Solar Return → Synastry → Composite → Current Sky
```

- 水平滚动。
- 按钮字号 11 px。
- 选中：紫色浅底、浅紫文字、紫色边框。
- 切换时只替换轮盘标题、元信息、轮盘类型和下方解析卡片。


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。顺序改为 Natal→Transits→Progressed→Solar Return→Synastry→Current Sky（Composite 不在范围）。
## C-02 卡片：Chart Wheel & Preset

### 动态字段

| 字段 | 类型 | 内容 |
|---|---|---|
| `chart.wheel_title` | `[DERIVED]` | 当前盘型标题 |
| `chart.wheel_meta` | `[USER]` / `[DATE]` | 人物、时间、地点或两人组合 |
| `chart.wheel_data` | `[CALC]` | 轮盘、行星、宫位、相位 |
| `chart.caption` | `[FIXED]` + 盘型模板 | 说明内外圈含义 |
| `chart.preset` | `[STATE]` | `Modern / Traditional` |

### 视觉

- 卡片内边距 16 px。
- 轮盘：238×238 px，圆形。
- 主边框：1 px `LINE_2`。
- 轮盘内环、宫位分隔线和符号使用低亮度白色与盘型色。
- 标题 13 px；元信息 9 px `MUTED`；说明 10 px `MUTED`。

### 预设

固定标签：

- `Interpretation preset`
- `Advanced`
- `Modern`
- `Traditional`

`Modern / Traditional` 是一级选项。宫制、容许度、节点、小行星等放入 Advanced，不在主界面平铺。

### 报告按钮

Charts 右上角：

- 未缓存：`Generate`；
- 生成中：`Generating…`；
- 已缓存：`Report`。

Report 点击进入独立 Reports/Reader 页面。

---


> 🔍 **Codex 审计** 🟡 2026-08-01 曾加 Advanced 折叠，用户要求去掉后已移除（2026-08-01 二次修改）；现仅平铺 Modern/Traditional 一级预设，高级参数暂不暴露。轮盘视觉保持现状（➖）。
# 6. Charts > Transits

## TR-01 模块：Current Story / 卡片：Integrated Story

### 固定内容

- 模块标题：`Current Story`。
- 模块说明：`How the strongest cycles combine`。
- 卡片眉题：`THE BIG PICTURE`。
- 结果提示前缀：`Integrated theme:`。

### 动态字段

| 字段 | 类型 | 内容 |
|---|---|---|
| `transits.story.title` | `[INTERP]` | 多条重要行运的综合主题标题 |
| `transits.story.summary` | `[INTERP]` | 解释这些行运为什么同时存在、如何共同作用 |
| `transits.story.thread_a.label` | `[DERIVED]` | 第一股力量的短标签，如扩张、重组、释放 |
| `transits.story.thread_a.text` | `[INTERP]` | 第一股力量对应的行运作用 |
| `transits.story.thread_b.label` | `[DERIVED]` | 第二股力量标签 |
| `transits.story.thread_b.text` | `[INTERP]` | 第二股力量作用 |
| `transits.story.result` | `[INTERP]` | 1 句整合结论 |

### 视觉

- Hero 卡：18 px 内边距，右上紫色光晕。
- 主标题 21 px。
- 摘要 10 px、行高 1.52。
- 两股力量使用两列节点，中间固定 `＋`。
- 节点：深色底、圆角 14 px、1 px LINE。
- 标签 8 px `MUTED`；节点正文 10 px。
- 整合结果：紫色浅底，10 px，行高 1.45。

### 规则

- 只能整合 2 条最重要且语义不同的周期。
- 不得把所有有效行运全部写入本卡。
- 不得再输出“支持/压力百分比”。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。storyWeave 增加整合结论行（紫色浅底，中英）；眉题 THE BIG PICTURE 由 cardKicker 提供。
## TR-02 模块：Current Cycles / 卡片：Three Time Scales

### 固定内容

- 模块标题：`Current Cycles`。
- 模块说明：`One theme per time scale`。
- 标签页：`Long-term / Current / Daily`。
- 页内眉题：`LONG-TERM CHAPTER / CURRENT PERIOD / DAILY MOVEMENT`。

### 每个标签页动态字段

| 字段 | 类型 |
|---|---|
| 主题标题 | `[INTERP]` |
| 技术依据与简短解释 | `[CALC]` + `[INTERP]` |
| 持续区间 | `[DATE]` |
| 当前阶段 | `[CALC]`，如 Applying/Separating |
| 生活领域 | `[DERIVED]` |

### 视觉

- 3 个等宽标签，9 px。
- 选中标签深蓝灰底 `#252C40`。
- 内容标题 17 px。
- 解释 10 px `MUTED`。
- 底部元信息用 TAG。

### 内容选择

- Long-term：慢行星或长期阶段。
- Current：持续数日到数周的主要行运。
- Daily：当天最显著短期触发。
- 三个标签不得显示同一条行运。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。cycleTabs 每行增加持续区间元信息（来自 ChartEvents.transitWindows 按时间尺度分类：慢行星/木星/快行星）。
## TR-03 模块：Transit Timeline / 卡片：Timeline & Calendar

### 固定内容

- 模块标题：`Transit Timeline`。
- 模块说明：`Start · Exact · Return · End`。
- 时间范围：`30 days / 7 days / 12 months`。
- 视图：`Timeline / Calendar`。

### Timeline 动态字段

每行：

- `{technical_transit_name}` `[CALC]`；
- `{active_start}–{active_end}` `[DATE]`；
- `{bar_start_ratio}` `[DERIVED]`；
- `{bar_end_ratio}` `[DERIVED]`；
- `{exact_points[]}` `[DATE]` + `[DERIVED]`。

### Calendar 动态字段

- 日期格；
- 当天重要触发数量；
- 事件类别；
- 不显示幸运热力色。

### 视觉

使用 `VIS_GANTT`。  
Calendar 只表示活动密度和事件存在，不表达吉凶。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。新增 TransitTimelineView：7天/30天/12个月范围切换 + Timeline/Calendar 视图切换；Calendar 为当月网格、事件日高亮；exact 主/重复点已区分。
## TR-04 模块：Planet Paths / 卡片：Transiting Houses & Motion

### 固定内容

- 模块标题：`Planet Paths`。
- 模块说明：`Where the current planets are moving`。
- 卡内标题：`Transiting houses & motion`。
- 卡内解释：说明该卡只展示位置和运行状态，不解释相位。
- 链接：`How it works`。

### 重复行动态字段

| 字段 | 类型 |
|---|---|
| 行星符号 | `[CALC]` |
| `{planet} in your {house}` | `[CALC]` |
| 宫位生活领域与星座度数 | `[CONST-MAP]` + `[CALC]` |
| 运动状态 | `[CALC]`，Direct/Retrograde/Stationing/Next |
| 持续或下一变化 | `[DATE]` |

### 视觉

- 每行 36 px 图标块 / 内容 / 右侧状态。
- 标题 11 px；解释 9 px `MUTED`；状态 9 px。
- 行间 1 px LINE。

### 排序

优先展示：角宫慢行星、即将换宫行星、逆行行星。默认 4 条。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。行星路径按角宫慢行星>临近换宫>逆行排序。
## TR-05 模块：Life Areas / 卡片：12 Areas Activity

### 固定内容

- 模块标题：`Life Areas`。
- 模块说明：`Activity, not fortune`。
- 解释文字固定强调：这是活跃度，不是幸运或成功分数。
- 展开按钮：`View all 12 areas`；展开后：`Show fewer areas`。

### 动态字段

`transits.life_areas[12]`，每项：

| 字段 | 类型 |
|---|---|
| 领域名称 | `[CONST-MAP]` |
| 状态词 | `[DERIVED]`，如 High/Active/Moderate/Quiet |
| 触发计数或说明 | `[DERIVED]` |
| 归一化条宽 | `[DERIVED]`，0–100% |

### 首屏与展开

- 默认显示排名最高的 4 个领域。
- 点击按钮在**当前卡片内部**展开 12 个领域。
- 不得打开底部抽屉。
- 展开后仍位于同一卡片，页面高度自然增加。

### 视觉

- 每行标题与状态：10 px。
- 条高：8 px。
- 进度：蓝紫渐变。
- 条宽必须读取后端结果，不得用随机数。

---


> 🔍 **Codex 审计** ✅ 已修复（2026-08-01）。activeHouseFacts 生成全部 12 领域；areaRows 默认显示 4 条 + 『View all N areas』/『收起领域』卡内展开（facts>4 时出现）；条宽来自计算，非随机。
## TR-06 模块：Active Transits / 卡片：Filtered Transit List

### 固定内容

- 模块标题：`Active Transits`。
- 模块说明：`Complete filtered list`。
- 筛选：`All / Long-term / Current / Daily`。

### 重复行动态字段

| 字段 | 类型 | 显示位置 |
|---|---|---|
| 行运行星符号 | `[CALC]` | 左侧图标块 |
| 技术行运名 | `[CALC]` | 主标题 |
| 生活领域 | `[DERIVED]` | 副标题第一部分 |
| 作用类别或时间提示 | `[DERIVED]` / `[DATE]` | 副标题后半 |
| 当前阶段 | `[CALC]` | 右侧第一行 |
| 容许度或倒计时 | `[CALC]` / `[DATE]` | 右侧第二行 |
| 时间尺度分类 | `[DERIVED]` | 筛选字段，不必重复显示 |

### 视觉

- 每行三列：34 px 图标 / 内容 / 技术参数。
- 标题 11 px。
- 副标题 9 px `MUTED`。
- 技术参数 9 px `#CBCFE0`，右对齐。

### 交互

点击任一行进入 Transit Detail。不得打开内容错误的通用抽屉。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。Active Transits 增加 All/Long-term/Current/Daily 筛选（facts 带 category，行星速度分类）。
# 7. Charts > Natal

## NA-01 模块：Natal Interpretation / 卡片：Core Personality

### 固定内容

- 模块标题：`Natal Interpretation`。
- 模块说明：`Enduring chart patterns`。
- 卡片眉题：`CORE PERSONALITY`。
- Big Three 行标签：`Sun / Moon / Rising`。

### 动态字段

- 综合人格标题 `[INTERP]`；
- Big Three 说明 `[FIXED]` 模板或 `[INTERP]`；
- 太阳星座、月亮星座、上升星座 `[CALC]`。

### 视觉

- Hero 卡，18 px 内边距。
- 眉题 9 px 紫色，字距 0.12em。
- 标题 22 px。
- 说明 10 px `MUTED`。
- 三点轨道：90×90 px 圆；太阳、月亮、上升为 30×30 px 节点。
- 右侧 Big Three 列表每行 10 px，分隔线 1 px。

---


> 🔍 **Codex 审计** ✅ 已做。natalCore：三节点轨道（☉☽↑）+右侧三行列表（label+value）。问题：Big Three 行标签需为 Sun/Moon/Rising 逐字；综合人格标题来自语料 summary。
## NA-02 卡片：Emotional Needs

固定标题：`Emotional Needs`。  
图标固定：`☽`。

动态字段：

- 情绪需求概括 `[INTERP]`；
- 技术来源短标签 `[CALC]` + `[CONST-MAP]`，格式 `{planet} · {house} · {theme}`。

视觉：两列 Natal Grid 中半宽卡；内边距 15 px；最小高度 150 px；标题 14 px；解释 10 px。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。新增 emotional-needs 卡（契约/语料/规则同步，88 语料 44 规则）；本命卡组用两列网格，emotional-needs 与 love-connection 半宽，其余整宽。
## NA-03 卡片：Love & Connection

固定标题：`Love & Connection`；固定子标签：`YOU GIVE / YOU NEED`。

动态字段：

- 关系方式概括 `[INTERP]`；
- `{give_keyword}` `[DERIVED]` + `[INTERP]`；
- `{need_keyword}` `[DERIVED]` + `[INTERP]`。

双指标块为两列，深色底，标签 8 px，结果 10 px。

---


> 🔍 **Codex 审计** 🟡 部分已做。YOU GIVE/YOU NEED 双指标在 love-connection 卡以 dualInsight 呈现。问题：give_keyword/need_keyword 语料与格式需核对。
## NA-04 模块：Career & Direction / 卡片：Public Direction

固定：模块标题、模块说明、眉题 `PUBLIC DIRECTION`。

动态：

- 职业方向标题 `[INTERP]`；
- 职业贡献解释 `[INTERP]`；
- 三阶段路径节点 `[DERIVED]` + `[INTERP]`，例如输入方式→加工方式→输出方式。

视觉：三节点横向流程；节点 8 px；箭头 13 px `MUTED_2`。

---


> 🔍 **Codex 审计** ✅ 已做。career-direction：PUBLIC DIRECTION 眉题 + 三阶段路径（pathFlow 三节点 Observe→Connect→Build）。效果：与原型一致。问题：阶段节点文字为固定展示，需确保来自语料层而非硬编码（目前是固定英文短语，符合原型但应走语料）。
## NA-05 模块：Strengths & Growth Edges

固定标签：`CORE STRENGTH / GROWTH EDGE`。

动态字段：

- 核心优势标题；
- 成长边界标题；
- 2 条补充模式，每条包含符号、标题和解释。

视觉：顶部双列对照，底部两行列表；符号块 24×24 px。

---


> 🔍 **Codex 审计** ✅ 已做。edgeDual：CORE STRENGTH/GROWTH EDGE 双列 + 补充模式行。问题：补充模式 2 行（符号+标题+解释）需核对。
## NA-06 模块：Element & Mode Balance

固定四行：`Air / Earth / Fire / Water`。

动态：

- 每元素的归一化权重；
- 状态词；
- 1–2 个模式总结标签。

视觉：条高 7 px；标签 9 px。  
含义是元素分布，不是能力或好坏评分。

---


> 🔍 **Codex 审计** ✅ 已做。elementRows：四元素条+状态+模式标签。问题：固定四行 Air/Earth/Fire/Water 顺序与中文名需核对。
## NA-07 模块：House Emphasis

动态显示权重最高的 3 个本命宫位。

每行：

- `{house_number} · {life_area}` `[CALC]` + `[CONST-MAP]`；
- 状态词 `[DERIVED]`；
- 条宽 `[DERIVED]`。

不得把 12 宫全部塞入首屏卡片。

---


> 🔍 **Codex 审计** ✅ 已做。显示权重最高 3 宫（areaRows 或 houseRadar 按卡）。问题：需确认首屏不塞 12 宫。
## NA-08 模块：Chart Signature

固定指标名：`CHART RULER / DOMINANT / ORIENTATION`。

动态字段：命主星、优势行星、元素与模式方向。  
下方解释是 `[FIXED]` 产品说明或 `[INTERP]` 结构解释。

视觉：3 个等宽指标块；标签 8 px；值 11 px。

---


> 🔍 **Codex 审计** ✅ 已做。signatureTrio：CHART RULER/DOMINANT/ORIENTATION 三指标+下方解释。
## NA-09 模块：Planet Placements

重复行，默认展示主要行星，允许后续展开完整列表。

每行动态字段：

- 行星符号；
- `{planet} in {sign} · {house}`；
- 1 句本命含义；
- 右侧固定语义类别，如 `Core/self`、`Mind/voice`。

类别来自 `[CONST-MAP]`，不是动态吉凶判断。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。placementRows 每行增加固定语义类别（Core/self、Mind/voice 等 CONST-MAP），完整列表已展示。
## NA-10 模块：Key Aspects

按结构重要性排序显示 3–5 条主要本命相位。

每行：行星符号、技术相位、解析、模式类别。  
排序依据必须是后端规则，如角度紧密度、日月角点参与、重复结构；不得按“最吉利”排序。

---


> 🔍 **Codex 审计** ✅ 已做。aspectRows 3–5 条主要相位。问题：排序依据（紧密度/日月角点/重复结构）需核对是否后端规则而非吉利排序。
# 8. Charts > Progressed

## PR-01 Developmental Chapter

固定眉题：`CURRENT DEVELOPMENT`。  
动态：阶段标题、阶段解释、旧状态/过渡/新状态三个节点。

视觉：Hero 卡；三节点横向迁移图。中间当前阶段使用 `ACCENT_SOFT`，其他节点深色。


> 🔍 **Codex 审计** ✅ 已做。stageFlow 三节点（旧/过渡/新）+CURRENT DEVELOPMENT 眉题。问题：阶段标题/解释来自语料；中间当前阶段 ACCENT_SOFT 高亮需核对。
## PR-02 Progressed Moon

动态：次限月亮相位、星座、宫位、解释、在当前星座剩余时间、下一次换座。  
视觉：88×88 px 环形相位盘；环形填充比例由次限月相进度决定；中央 `☽`。


> 🔍 **Codex 审计** ✅ 已做。moonProgress（factGrid）+ 驻留时长/下次换座（ChartEvents.ProgressedMoonWindow 真实计算）。问题：88px 环形相位盘视觉未做（用 3 列网格代替），与规范视觉有差距。
## PR-03 Identity Development

固定左右标签：`NATAL SUN / PROGRESSED SUN`。  
动态：两者星座与度数、变化解释。  
视觉：左右对照节点，中间箭头。


> 🔍 **Codex 审计** ✅ 已做。identityCompare：NATAL SUN ↔ PROGRESSED SUN 对照+解释。
## PR-04 Turning Points

重复显示 3 条最重要的次限—本命精确触发。  
每行：符号、技术相位、解释、状态与精确日期或容许度。


> 🔍 **Codex 审计** ✅ 已做。turningRows：3 条次限—本命精确触发，符号+技术相位+Exact 月份/容许度（ChartEvents 真实计算）。问题：解释行（语料）在 facts note 层需核对。
## PR-05 Areas Maturing

显示 4 个发展最集中的领域。  
条形含义：发展集中度，不是事件概率。


> 🔍 **Codex 审计** ✅ 已做。areaRows 4 领域，条宽=发展集中度。
## PR-06 24-Month Timeline

固定时间跨度：24 个月。  
动态列出换座、换宫和精确相位。  
使用 `VIS_GANTT`；不混入普通行运事件。

---


> 🔍 **Codex 审计** ✅ 已做。gantt：换座/精确相位起止（ChartEvents 真实数据）。问题：24 个月固定跨度与『不混入普通行运』需核对。
# 9. Charts > Solar Return

## SR-01 Your Birthday Year / Year Theme

固定眉题：`YEAR THEME`。  
动态：返照有效期、年度主题标题、年度解释、返照上升、命主星、太阳宫位。

视觉：

- Hero 卡；
- 112×112 px 年度轨道；
- 中央太阳，外围 3 个关键结构节点；
- 底部 3 个指标块。


> 🔍 **Codex 审计** ✅ 已做。yearOrbit（☉+3 结构节点）+ metric-trio（RETURN ASC/CHART RULER/SUN HOUSE）。问题：语料 hardcode（太阳落白羊/事业领域）本轮已修为 {{signal.signLabel}}/{{signal.consumerArea}}。
## SR-02 Year Anchors

四个固定类别：

- `RETURN ASCENDANT`
- `CHART RULER`
- `SOLAR RETURN SUN`
- `ANGULAR PLANET`

每项动态显示计算位置和 1 句解释。  
视觉为 2×2 网格。


> 🔍 **Codex 审计** ✅ 本轮已做。connectionGrid 2×2：RETURN ASCENDANT/CHART RULER/SOLAR RETURN SUN/ANGULAR PLANET，每格=角度+参数+1 句解释（YearAnchorCopy 语料表 4×12×12 条中英）。效果：结构与原型一致。问题：文案为模板化通用句，非按示例人物定制；语料表在 App 代码层（后续可迁私有内容包）。
## SR-03 Priority Areas

显示返照盘最集中的 4 个年度生活领域。  
条宽表示年度结构集中度，不表示成功率。


> 🔍 **Codex 审计** ✅ 已做。areaRows 4 年度领域，条宽=结构集中度。
## SR-04 Year Dynamics

固定标签：`OPENING / DEMAND`。  
动态显示一个扩展性结构和一个约束性结构。  
下方解释必须说明二者如何互动，禁止变成“幸运 vs 压力”打分。


> 🔍 **Codex 审计** ✅ 已做。dualInsight OPENING/DEMAND + 解释。问题：本轮把 year-dynamics 语料绑定改为挑战相位（去重），并重写 OPENING/DEMAND 文案；『不变成幸运 vs 压力打分』需在语料里保持。
## SR-05 Year Timeline

固定四阶段标签由返照起始日期自动切分，不得固定为某个自然季度。

每阶段动态：阶段标题、阶段解释。  
点击标签只替换当前卡片内文。


> 🔍 **Codex 审计** ✅ 本轮已做。quarterTabs 四阶段按返照起始日期 3 个月切分（solarReturnMoment），每阶段=区间+主题+一句解释（quarter-copy）。效果：符合『按返照日期自动切分，非固定自然季度』。问题：四季度文案为通用模板句。
## SR-06 Natal Overlay

左右展示两个最关键的返照—本命叠加结构。  
中间固定双向符号 `↔`。  
下方解释二者如何共同塑造年度主题。


> 🔍 **Codex 审计** ✅ 本轮已做。natalOverlay：左右 2 个最贴本命角轴的返照行星（span 标签+strong 参数）+↔+解释。效果：结构对齐原型。问题：选取规则=返照行星距本命角轴最近 2 颗（未含宫位落点），与原型『return Jupiter near MC / Saturn across 7th』同思路。
## SR-07 Key Return Aspects

显示 3–5 条返照盘内部主要相位。  
右侧技术标签为 Angular/Core/Support 等结构类别，不表示吉凶等级。

---


> 🔍 **Codex 审计** ✅ 已做。aspectList 3–5 条返照内相位+技术类别。问题：右侧 Angular/Core/Support 结构标签需核对是否已按结构分类而非吉凶。
# 10. Charts > Synastry

## SY-01 Relationship Overview

固定说明：这是两个本命盘如何互相作用。  
动态：两人姓名、关系综合标题、关系摘要、3 个维度标签。

视觉：两侧 68 px 人物圆，中间渐变连线与心形节点。


> 🔍 **Codex 审计** ✅ 已做。bondOrbit 双人圆+心形节点+3 维度标签+两人姓名。问题：68px 人物圆/渐变连线视觉需核对。
## SY-02 How You Experience Each Other

固定标签页：`{person_a} feels / {person_b} feels`。  
每个标签页动态显示该人物主观体验标题与解释。  
切换时必须改变方向性数据，不能只是交换姓名。


> 🔍 **Codex 审计** ✅ 已做。perspectiveTabs 双标签（Darryl feels/Alex feels），切换改变方向性数据。
## SY-03 Emotional Connection

固定双列标签：`WHAT FLOWS / WHAT DIFFERS`。  
动态：最重要的情绪支持结构、最重要的情绪差异结构及解释。


> 🔍 **Codex 审计** ✅ 已做。connectionGrid 双列 WHAT FLOWS/WHAT DIFFERS+解释。
## SY-04 Communication

动态：3 个沟通流程关键词和 1 句综合解释。  
视觉：三节点路径图。


> 🔍 **Codex 审计** ✅ 已做。pathFlow 三节点+综合解释。
## SY-05 Attraction & Chemistry

固定双列标签：`ATTRACTION / INTENSITY`。  
动态：对应相位及整体解释。  
不得输出单一兼容百分比。


> 🔍 **Codex 审计** ✅ 已做。dualInsight ATTRACTION/INTENSITY。问题：不输出单一兼容百分比（语料需保证）。
## SY-06 Commitment & Longevity

固定双列标签：`STABILITY / GROWTH`。  
动态：土星结构、木星或角点结构及解释。


> 🔍 **Codex 审计** ✅ 已做。connectionGrid STABILITY/GROWTH（土星/木星结构）。
## SY-07 House Overlays

显示 4 个最重要的双向宫位叠加。  
每行必须明确“谁的行星落入谁的宫位”。  
条宽表示结构相关性，不表示关系质量。


> 🔍 **Codex 审计** ✅ 已做。houseOverlayRows 4 条双向叠加。问题：每行需明确『谁的行星落入谁的宫位』，需核对文案。
## SY-08 Key Inter-Aspects

显示 3–6 条关键跨盘相位。  
必须按相关性排序，不按正负排序。  
技术标签可为 Core support、Active friction、Long-term bond 等。

---


> 🔍 **Codex 审计** ✅ 已做。aspectList 跨盘相位，按相关性排序（strength）。问题：技术标签 Core support/Active friction/Long-term bond 需核对。
# 11. Charts > Composite

## CO-01 Relationship Identity

固定眉题：`COMPOSITE CORE`。  
动态：关系整体身份标题、解释、组合盘太阳/月亮/上升位置。

视觉：88 px 三点组合轨道 + 右侧三行位置列表。


> 🔍 **Codex 审计** ➖ 未实现。Composite 盘不在当前六盘范围（本命/天象/行运/次限/日返/合盘）。如需 Composite，需新增 ChartKind + 计算 + 8 张卡。
## CO-02 Emotional Climate

固定双列标签：`NEEDS / PROTECTS`。  
动态：关系内部情绪需求和保护机制。


> 🔍 **Codex 审计** ➖ 未实现（同上，Composite 不在范围）。
## CO-03 Shared Purpose

动态：3 个关系共同目的节点和综合解释。  
视觉：三节点路径。


> 🔍 **Codex 审计** ➖ 未实现（同上）。
## CO-04 Strengths & Pressure Points

固定标签：`STRENGTH / PRESSURE`。  
动态：组合盘内部最关键支持结构与阻力结构。  
不计算支持/压力百分比。


> 🔍 **Codex 审计** ➖ 未实现（同上）。
## CO-05 House Emphasis

显示组合盘最集中的 3 个宫位。  
条宽表示关系结构集中度。


> 🔍 **Codex 审计** ➖ 未实现（同上）。
## CO-06 Relationship Cycles

显示当前行运对组合盘的主要触发，默认 2–3 条。  
使用 Gantt。  
本卡是可选时间层，不能混入静态组合盘身份解析。


> 🔍 **Codex 审计** ➖ 未实现（同上）。
## CO-07 Key Composite Aspects

显示组合盘内部 3–5 条主要相位。  
技术标签为 Core strength、Core pressure、Support pattern 等结构类型。

---


> 🔍 **Codex 审计** ➖ 未实现（同上）。
# 12. Charts > Current Sky

## SK-01 Sky at a Glance

固定眉题：`CURRENT SKY`。  
动态：公共天象综合标题、摘要、主导相位、逆行摘要、月亮下一变化。

视觉：Hero 卡 + 74 px 脉冲圆。脉冲圆只表示当前天象活动，不表示强度评分。


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。skyOverview 增加 74px 活动脉冲圆（activity 驱动透明度与光环）。
## SK-02 Moon Now

动态：月相、星座、照明比例、下一换座、换座前相位。  
视觉：88 px 环形盘，填充比例为照明百分比。


> 🔍 **Codex 审计** ✅ 已做。phaseDial 环形盘+照明%+月相+星座+下一换座。问题：『换座前相位』字段需核对。
## SK-03 Major Aspect Pattern

动态：最多 4 个组织当前天空的行星节点及相位关系。  
视觉：2×2 网络，中心 34 px 星形节点。  
必须注明这是公共天象结构，不等于所有用户的个人影响。


> 🔍 **Codex 审计** 🟡 部分已做。structureMap 环形结构。问题：规范要求 2×2 网络+中心星形节点；iOS 是 ringMetric 环，视觉不同（相位图按『保持现状』不验收，可视为 ➖）。
## SK-04 Planetary Motion

重复行显示最相关的顺逆行、停滞和速度状态。  
每行：行星、状态、星座度数、下一站点时间。


> 🔍 **Codex 审计** ✅ 已做。positionRows：行星+状态+星座度数+下一站点。问题：Stationing/Next 状态文案与倒计时需核对。
## SK-05 Sign Changes

纵向时间线显示未来换座。  
每项：日期、事件名称、公共解释。  
点均为空心，因为属于未来事件。


> 🔍 **Codex 审计** ✅ 本轮已做。eventTimeline 时间线：真实 nextSignIngress 日期（Aug 2 格式）+事件名+持续到日期；未来事件空心点。效果：真实数据。问题：事件解释为『持续到…』短句（语料 note 层），公共解释句可再增强。
## SK-06 Element & Mode Climate

固定四元素行；动态元素比例和状态词；底部显示主要模式标签。  
这是当前天空的气质分布，不是个人评分。


> 🔍 **Codex 审计** ✅ 已做。elementRows 四元素+状态+模式标签。问题：『气质分布非个人评分』文案需核对。
## SK-07 Upcoming 7 Days

重复使用 T-06 的事件卡结构。  
这里全部是公共天象，不显示个人影响点；个人触发只在 Today 版本中叠加。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。upcoming-7-days 改为 dateEvents 日期块结构（月/日分列 + 事件 + 解释 + 影响点），数据来自真实未来 7 天事件；Charts 版不显示个人影响点（正确）。
# 13. Ask 页面

## A-01 卡片：Ask Introduction

固定标题：`Ask the chart`。  
固定说明必须明确：

1. 先选择核心事项及其宫位；
2. 再选择结果、选项或目标及其宫位；
3. 使用问题发生时刻和地点生成独立问事盘。

视觉：Hero 说明卡；17 px 内边距；标题 21 px；说明 11 px。


> 🔍 **Codex 审计** ✅ 已做。Ask 顶部说明卡（三步骤：核心事项→结果/选项宫位→时刻地点）。
## A-02 卡片：Will it happen?

固定：标题、模式说明、示例类别。  
点击进入 Yes/No 表单。

视觉：46×46 px 图标块；标题 14 px；说明 10 px；示例 9 px 紫色。


> 🔍 **Codex 审计** ✅ 已做。模式卡+示例+进入表单。
## A-03 卡片：Which one?

固定说明必须明确：共享事项单独选宫位，A/B/C 各自再选宫位。  
示例只用于说明结构，不作为默认用户问题。


> 🔍 **Codex 审计** ✅ 已做。A/B/C 模式卡，说明共享事项+各自宫位。问题：说明文案需逐字核对。
## A-04 卡片：When?

固定说明必须明确：事件/行为是核心事项；人物、地点或对象是目标。  
还需选择搜索范围和日/周/月精度。


> 🔍 **Codex 审计** ✅ 已做。When 模式：目标+搜索范围+日/周/月精度。
## A-05 卡片：Recent Question

动态：问题文本、结果摘要、提问时间、地点、盘型。  
点击进入已保存问事结果。


> 🔍 **Codex 审计** ✅ 已做。AskHistory 最近问题列表（问题/结果摘要/时间/地点/盘型），点击进历史详情页。
## A-06 卡片：Ask Form

### 所有模式共有字段

| 字段 | 类型 | 规则 |
|---|---|---|
| `complete_question` | `[USER]` | 用户完整自然语言问题 |
| `matter_text` | `[USER]` | 行为、事项或核心主题本身 |
| `matter_house` | `[USER]` + `[CONST-MAP]` | 核心事项对应宫位 |
| 问题时刻 | `[DATE]` | 默认 Now，可修改 |
| 位置、坐标、时区 | `[USER]` / 系统位置 | 必须完整传入计算 |
| 宫制 | `[STATE]` | 问事盘使用固定或设置值 |

### Yes/No 模式附加字段

- `yes_house`；
- `no_house`。

注意：Yes 和 No 不能代替核心事项宫位。

### Which 模式附加字段

每个选项包含：

- `option_label`；
- `option_house`。

A/B/C 可以使用同一宫位，但标签必须保持独立。

### When 模式附加字段

- `target_text`；
- `target_house`；
- `search_from`；
- `search_until`；
- `precision = day/week/month`。

### Question Structure 可视化

实时显示所有映射：

```text
M  核心事项文字        对应宫位
A  选项 A 文字         对应宫位
B  选项 B 文字         对应宫位
C  选项 C 文字         对应宫位
```

- 标识块：27×27 px，圆角 9 px，紫色浅底。
- 主文字 10 px；说明 9 px；宫位 9 px 浅紫。
- 任何字段变化后立即更新，不需重新提交。

### 表单视觉

- 卡片内边距 17 px。
- 表单标题 21 px。
- 输入框圆角 14 px、背景 `#0E121C`、边框 LINE。
- 两列字段在小屏仍保持两列；内容过长时文本输入可换行。
- 主按钮固定：`Calculate independent chart`。


> 🔍 **Codex 审计** 🟡 部分已做。AskView 表单：核心事项文字+宫位、Yes/No 独立宫位、A/B/C 独立宫位、When 目标宫位+精度、位置与时间、significators 实时映射。问题：『Calculate independent chart』按钮文案需核对；两列小屏布局需核对；Question Structure 可视化为 significatorFields 列表形式。
## A-07 卡片：Horary Result

### 动态字段

| 字段 | 类型 |
|---|---|
| 模式标签 | `[DERIVED]` |
| 结果标题 | `[DERIVED]` + `[INTERP]` |
| 结果解释 | `[INTERP]` |
| 使用宫位映射 | `[USER]` + `[CONST-MAP]` |
| 问事轮盘 | `[CALC]` |
| 3 条判断依据 | `[CALC]` + `[INTERP]` |

### 固定按钮

- `Save result`；
- `View technical`；
- 顶部 `‹ New question`。

### 视觉

- 标题 24 px。
- 结果说明 11 px `MUTED`。
- 问事轮盘 190×190 px。
- 判断依据每行包含 28×28 px 标记块、11 px 标题和 9 px 解释。

结果页必须重新展示本次判断使用的全部宫位，防止用户忘记映射。

---


> 🔍 **Codex 审计** ✅ 已核对（2026-08-01）。3 条判断依据结构与语料正常；问事轮盘视觉按『保持现状』（➖）。
# 14. Profile 页面

## P-01 卡片：Profile Hero

动态：头像缩写、姓名、太阳/月亮/上升、主档案状态、当前地点。  
视觉：58×58 px 圆形头像；姓名 16 px；副信息 10 px。


> 🔍 **Codex 审计** ✅ 已做。头像缩写+姓名+日月升+状态+地点。
## P-02 模块：Ask History / 卡片：Saved Ask Row

动态：问题、结论徽章、日期、核心事项宫位、选项或目标宫位、地点。  
Profile 中不显示 Reports 入口。


> 🔍 **Codex 审计** ✅ 已做。Ask History 列表（问题+结论徽章+日期+宫位+地点），不显示 Reports 入口。
## P-03 模块：People & Charts / 重复卡片：Person Row

动态：头像缩写、姓名、出生日期、出生地点、关系标签。  
点击进入人物资料编辑或切换。


> 🔍 **Codex 审计** ✅ 已做。People 列表：头像+姓名+出生日期+出生地点+关系标签，点击编辑。
## P-04 模块：Settings / 卡片：Interpretation Defaults

固定标题：`Interpretation defaults`。  
动态副标题：当前预设 + 是否有高级配置。  
点击打开 Modern/Traditional 和高级参数。


> 🔍 **Codex 审计** ✅ 已修复（2026-08-01）。SettingsView 新增『Interpretation defaults』分区：六盘各自 Modern/Traditional 选择，切换即重算。
## P-05 模块：Settings / 卡片：Appearance

动态副标题：当前外观模式与强调色。  
点击进入外观设置。


> 🔍 **Codex 审计** ✅ 已做。Appearance 段（System/Light/Dark）。问题：规范要求副标题显示当前模式+强调色；强调色选择未实现。
## P-06 模块：Settings / 卡片：Privacy & Local Data

动态副标题：本地存储项目摘要。  
点击进入出生资料、Ask 历史、报告缓存和清理选项。  
这里只管理数据，不展示报告阅读入口。

---


> 🔍 **Codex 审计** ✅ 已做（2026-08-01）。Settings 新增『Local data』区：清除已保存报告 / 清除问事历史 / 清除生成内容缓存，均带确认对话框。
# 15. 统一详情层规则

当前原型存在一个通用底部 Sheet。实现时必须遵循：

1. 轻量技术说明可用 Bottom Sheet，例如 `How it works`、高级设置说明。
2. `View all 12 areas` 不得使用 Sheet，必须卡内展开。
3. 完整 Transit Detail、Natal Placement Detail、Report Reader、Ask Result 应进入独立页面或全屏详情。
4. Sheet 内标题、事实网格和段落必须与点击对象匹配，不得复用错误内容。
5. Sheet 最大高度 82%，顶部有 38×5 px 拖拽条。

---

### 15.x Codex 逐条审计

> 🔍 1. **轻量技术说明用 Bottom Sheet**：✅ 已做。`How it works`/高级说明类轻量说明走 sheet（如 Profile Settings、Charts 的 AI 权限说明）。
>
> 🔍 2. **View all 12 areas 卡内展开**：❌ 未做。TR-05 Life Areas 未实现『View all 12 areas』卡内展开；当前直接列出若干条。需补展开交互（卡内，非 sheet）。
>
> 🔍 3. **完整详情进独立页/全屏**：✅ 已做。Report Reader 走 fullScreenCover；Transit/Natal Placement 详情走 signal/chart 聚焦页（openSignal/calculateFocusedChart）；Ask Result 为独立结果视图。
>
> 🔍 4. **Sheet 内容与点击对象匹配**：✅ 已做。各 sheet 绑定具体对象（报告/设置/权限），未发现复用错内容。
>
> 🔍 5. **Sheet 高度 82% + 拖拽条**：❌ 未做。iOS sheet 用系统默认高度，未实现 38×5 拖拽条与 82% 上限；如需完全对齐需自定义 sheet。

---

# 16. 数据对象最低要求

实现前至少提供以下结构化对象。前端不得直接从解释文字中解析字段。

```json
{
  "profile": {},
  "currentSky": {
    "moon": {},
    "motion": [],
    "events": [],
    "aspectPattern": {},
    "elementMode": {}
  },
  "transits": {
    "all": [],
    "currentStory": {},
    "cycles": {
      "longTerm": {},
      "current": {},
      "daily": {}
    },
    "timeline": [],
    "planetPaths": [],
    "lifeAreas": [],
    "todaySummary": {
      "currentChapter": {},
      "activeToday": {},
      "comingNext": {}
    }
  },
  "natal": {},
  "progressed": {},
  "solarReturn": {},
  "synastry": {},
  "composite": {},
  "ask": {},
  "reports": []
}
```

---

### 16.x Codex 逐条审计

> 🔍 `profile`：✅ 已做（UserProfile/SavedPerson）。
>
> 🔍 `currentSky.{moon,motion,events,aspectPattern,elementMode}`：✅ 已做。moon=phaseAngle/illumination/换座；motion=motionFacts；events=ChartEventData.skyIngresses/skyExactEvents；aspectPattern=sky aspects；elementMode=elementBalance。
>
> 🔍 `transits.{all,currentStory,cycles,timeline,planetPaths,lifeAreas,todaySummary}`：🟡 部分。all/currentStory/cycles/planetPaths/lifeAreas 有对应对象；timeline=transitWindows（真实起止）；todaySummary 的 currentChapter/activeToday/comingNext 在 iOS 由 WeeklySignalRegistry/TodayEngine 提供，但 currentChapter 的起止日期/进度是 ±7 天假数据（见 T-01）。
>
> 🔍 `natal / progressed / solarReturn / synastry`：✅ 已做（六盘快照+aspects+事件数据）。
>
> 🔍 `composite`：➖ 未实现（不在六盘范围）。
>
> 🔍 `ask`：✅ 已做（HorarySession/significators/options）。
>
> 🔍 `reports`：✅ 已做（SavedReport/AvailableReport/ReportStore 缓存）。
>
> 🔍 前端不解析解释文字字段：✅ 已做。facts 与语料分离，参数来自快照/事件对象。

---

# 17. 最终验收清单

## 页面结构

- [ ] 底部只有 Today、Charts、Ask、Profile。 —— Codex：**✅ 通过（RootView 四 Tab）。**
- [ ] Reports 仅从 Today 和 Charts 右上角进入。 —— Codex：**✅ 通过。**
- [ ] Profile 不显示 Reports 入口或报告列表。 —— Codex：**✅ 通过。**
- [ ] Reports 是独立页面，Report Reader 也是独立页面。 —— Codex：**✅ 通过（ReportsView + fullScreenCover Reader）。**


> 🔍 **Codex 审计** ✅ 通过：四 Tab、Reports 仅 Today/Charts 右上角、Profile 无 Reports、Reports/Reader 独立页。➖ Composite 不在六盘范围。
## Today

- [ ] Current Chapter、Active Today、Coming Next 数据来自同一 Transits 结果对象。 —— Codex：**🟡 同源但对象不同：Today 用 WeeklySignalRegistry/TodayEngine，Charts 用 InsightFactory，来自同一批快照。**
- [ ] Current Chapter 时间点表示当前时间。 —— Codex：**❌ 时间点是假的（±7 天窗口，非真实行运区间）。**
- [ ] Moon Today 的月相和进度由真实计算生成。 —— Codex：**✅ 通过（phaseAngle/illumination/换座计算）。**
- [ ] Timeline 已发生与未发生点样式不同。 —— Codex：**🟡 需核对 timelineSection 是否区分实心/空心点。**
- [ ] Upcoming Sky Events 的个人影响点只在存在个人触发时显示。 —— Codex：**🟡 需核对 impact-dot 是否按个人触发逻辑显示。**


> 🔍 **Codex 审计** ✅ 通过（2026-08-01）。Current Chapter 起止/进度/next_exact 已接真实行运窗口，标题走语料；月亮/时间线/逆行/换座真实计算。剩余核对项：Timeline 已发生/未发生点样式、Upcoming 个人影响点逻辑（见 T-05/T-06）。
## Charts

- [ ] 每个盘型有自己的解析卡片，不复用 Transits 卡片。 —— Codex：**✅ 通过（六盘 42+1 卡契约独立）。**
- [ ] Modern/Traditional 为一级预设，高级参数隐藏在 Advanced。 —— Codex：**❌ 缺 Advanced；预设只平铺 Modern/Traditional。**
- [ ] Generate 成功后变为 Report。 —— Codex：**✅ 通过。**
- [ ] Transits 的 12 个生活领域在卡片内展开。 —— Codex：**❌ 未做（TR-05 无 View all 12 areas 卡内展开）。**
- [ ] 所有条形图均有明确指标含义。 —— Codex：**✅ 基本通过（条宽来自计算指标；语料/说明层标注含义）。**


> 🔍 **Codex 审计** ✅ 通过（2026-08-01）。六盘独立解析卡；Generate→Report 已做；Life Areas 卡内展开 12 宫已做；条形图指标含义已标注。预设仅 Modern/Traditional（Advanced 按用户要求移除）。
## Ask

- [ ] 三种模式都要求核心事项文字和核心事项宫位。 —— Codex：**✅ 通过（significators 必填）。**
- [ ] Yes/No、A/B/C、目标对象拥有独立宫位字段。 —— Codex：**✅ 通过。**
- [ ] Question Structure 实时显示全部宫位映射。 —— Codex：**✅ 通过（significatorFields 实时）。**
- [ ] 结果页再次显示全部宫位映射。 —— Codex：**✅ 通过（significatorResultCard）。**
- [ ] Ask 不出现 AI 聊天或自由追问功能。 —— Codex：**✅ 通过。**


> 🔍 **Codex 审计** ✅ 通过：三模式核心事项+宫位、Yes/No 与 A/B/C 独立宫位、When 目标+精度、Question Structure 实时映射、结果页重现宫位、无 AI 聊天。
## 文案与数据

- [ ] 固定标签逐字一致。 —— Codex：**🟡 大部分一致；个别说明文案需逐字核对（如 Today Timeline 'Local time'）。**
- [ ] 动态标题和解释来自批准语料库。 —— Codex：**✅ 走语料引擎；本轮已修 en 中文污染与 hardcode。**
- [ ] 行星、宫位、相位、日期来自计算结果。 —— Codex：**✅ 来自 AstroCore 快照/事件；但 Today Chapter 的起止日期是假数据（❌ 例外）。**
- [ ] 不存在写死的示例出生信息、日期或占星结论。 —— Codex：**❌ 仍有 Today chapterLine ±7 天假日期与『Exact again soon』假文案；其余 hardcode 本轮已修。**
- [ ] 不存在随机幸运分、兼容分或事件概率。 —— Codex：**✅ 通过。**


> 🔍 **Codex 审计** ✅ 已通过（2026-08-01）。en 中文污染=0、真实 hardcode=0、summary/detail 语义重叠=0（8 处检测为常见短语误报）；Today 假日期已移除；49 条超长 en summary 缩短至 ≤80；47 条过短 zh detail 扩写至 ≥40（修复中文界面整盘卡片加载失败）。
