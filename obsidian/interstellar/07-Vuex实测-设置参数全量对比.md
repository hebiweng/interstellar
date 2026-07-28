---
tags: [竞品调研, 爱占星, 实测, Vuex]
source: Vuex store chartSettings.chartSettingMap
updated: 2026-07-21
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '7a0ec8c7-267a-4e34-b064-f23ebb6c3c29'
  PropagateID: '7a0ec8c7-267a-4e34-b064-f23ebb6c3c29'
  ReservedCode1: 'cf1c7342-beeb-4496-b170-4f2b82935414'
  ReservedCode2: 'cf1c7342-beeb-4496-b170-4f2b82935414'
---

# 07 Vuex 实测：设置参数全量对比

## 一、数据来源与方法

从爱占星 app 的 Vuex store (`chartSettings.chartSettingMap`) 直接提取，覆盖 45 个 chartName × 3 体系（现代/古典/特殊）的完整设置数据。实测时间：2026-07-21。**这是应用内部数据，非 DOM 读取或推断，100% 准确。**

数据提取方式：通过 Playwright 在 app 页面执行 `page.evaluate()` 直接读取 Vuex store 中的 `chartSettings.chartSettingMap` 对象和 `settings` 模块，序列化为 JSON 输出。

## 二、容许度两族分类（实测结论）

全站 45 个 chartName 按默认容许度（orbs 字段）分为且仅分为 2 族：

### A 族：7/6/6/6/6/3/3/3/3/3（本命盘级）

| # | chartName | 中文名 | type |
|---|-----------|--------|------|
| 1 | natal | 本命盘 | 2 |
| 2 | datetime | 天象盘 | 0 |
| 3 | combination | 组合中点盘 | 0 |
| 4 | mid | 中点盘 | 0 |
| 5 | marks | 马克斯盘 | 0 |
| 6 | lunarReturn | 月返盘 | 0 |
| 7 | solarReturn | 日返盘 | 0 |
| 8 | divisional12 | 十二分盘 | 0 |
| 9 | divisional13 | 十三分盘 | 0 |
| 10 | firdaria | 法达盘 | 0 |
| 11 | profection | 年小限盘 | 0 |
| 12 | reLocation | 重置盘 | 0 |
| 13 | draconic | 龙首盘 | 0 |
| 14 | decennials | 希腊十年大运盘 | 0 |
| 15 | harmonic | 泛音盘 | 0 |
| 16 | secondaryProgressionSolarReturn | 次限日返盘 | 0 |

**A 族共 16 个盘型。** 这些盘型使用较宽的本命盘级容许度（合 7°、冲 6°、刑 6°等），适用于静态/本命类分析。

### B 族：2/1/1/1/1/1/1/1/1/1（推运盘级）

| # | chartName | 中文名 | type |
|---|-----------|--------|------|
| 1 | primaryDirection | 主限盘 | 0 |
| 2 | circumambulation | 绕行盘 | 0 |
| 3 | continuousProfection | 连续小限盘 | 0 |
| 4 | secondaryProgression | 次限盘 | 0 |
| 5 | tertiaryProgression | 三限盘 | 0 |
| 6 | minorProgression | 小限推运盘 | 0 |
| 7 | solarArc | 日弧盘 | 0 |
| 8 | transit | 行运盘 | 2 |
| 9 | compare | 对比盘 | 0 |
| 10 | combinationCompareDatetime | 组合天象对比盘 | 0 |
| 11 | secondaryProgressionCombination | 次限组合盘 | 0 |
| 12 | secondaryProgressionCombinationCompare | 次限组合对比盘 | 0 |
| 13 | tertiaryProgressionCombination | 三限组合盘 | 0 |
| 14 | tertiaryProgressionCombinationCompare | 三限组合对比盘 | 0 |
| 15 | midTransit | 中点行运盘 | 0 |
| 16 | midSecondaryProgression | 中点次限盘 | 0 |
| 17 | midTertiaryProgression | 中点三限盘 | 0 |
| 18 | marksSecondaryProgression | 马克斯次限盘 | 0 |
| 19 | marksTertiaryProgression | 马克斯三限盘 | 0 |
| 20 | secondaryProgressionCompare | 次限对比盘 | 0 |
| 21 | tertiaryProgressionCompare | 三限对比盘 | 2 |
| 22 | minorProgressionCompare | 小限推运对比盘 | 0 |
| 23 | solarReturnCompare | 日返对比盘 | 0 |
| 24 | lunarReturnCompare | 月返对比盘 | 0 |
| 25 | divisional12Compare | 十二分对比盘 | 0 |
| 26 | divisional13Compare | 十三分对比盘 | 0 |
| 27 | draconicCompare | 龙首对比盘 | 0 |
| 28 | harmonicCompare | 泛音对比盘 | 0 |
| 29 | secondaryProgressionSolarReturnCompare | 次限日返对比盘 | 0 |

**B 族共 29 个盘型。** 这些盘型使用较窄的推运盘级容许度（合 2°、其余 1°），适用于动态/推运类分析。

**分类规律总结：**
- A 族 = 本命类 + 返照类 + 古典技法类盘型的基盘（不含 Compare 后缀）
- B 族 = 所有推运盘（次限/三限/日弧/行运/主限等）+ 所有带 Compare 后缀的合盘对比盘
- type=2 的盘型：natal（本命）、transit（行运）、tertiaryProgressionCompare（三限对比）——这三个是双盘叠加结构

## 三、三体系预设差异（全站 100% 一致，实测结论）

以下差异在全部 45 个 chartName 中完全一致，无一例外：

| 维度 | 现代 | 古典 | 特殊 |
|---|---|---|---|
| orbsType | 0（按相位） | 1（按星光） | 0（按相位） |
| houseTypeIndex | 0（Placidus） | 4（Alcabitus） | 2（Whole Sign） |
| zodiacTypeIndex | 0 | 0 | 0 |
| sidModeIndex | 0 | 0 | 0 |
| ayanT0 | 0 | 0 | 0 |
| hasArabic | false | false | false |
| orbs（容许度值） | A族7/6/6/6/6/3/3/3/3/3，B族2/1/1/1/1/1/1/1/1/1 | 同现代 | 同现代 |
| orbsLight | 全同 | 全同 | 全同 |
| 天海冥显示 | 显示 | 隐藏 | 隐藏 |
| Juno（婚神星）显示 | A族显示/B族隐藏 | 隐藏 | 隐藏 |
| Lilith（莉莉丝）显示 | A族显示/B族隐藏 | 隐藏 | 隐藏 |
| Fortune（福点）显示 | A族显示/B族隐藏 | 显示 | 显示 |
| 其余参数 | 全同 | 全同 | 全同 |

**关键发现：** orbs 容许度数值在三体系间完全相同（同族内），差异仅在于 orbsType 的解释方式不同——现代/特殊按相位分配（orbsType=0），古典按星光分配（orbsType=1）。

## 四、星光容许度（orbsLight，全站全体系一致）

14 个星体的 orbsLight 值在所有 45 个 chartName × 3 体系中完全相同：

| 星体 | orbsLight（度） |
|---|---|
| Sun（太阳） | 15 |
| Moon（月亮） | 12 |
| Mercury（水星） | 7 |
| Venus（金星） | 7 |
| Mars（火星） | 8 |
| Jupiter（木星） | 9 |
| Saturn（土星） | 9 |
| Uranus（天王星） | 5 |
| Neptune（海王星） | 5 |
| Pluto（冥王星） | 5 |
| NorthNode（北交点） | 5 |
| Asc（上升点） | 5 |
| Mc（天顶） | 5 |
| Other（其他） | 5 |

**解读：** 星光容许度（orbsLight）按星体分配，日月宽、个人行星中、外行星窄，全部体系一致。古典体系（orbsType=1）使用此值替代按相位的 orbs；现代/特殊体系（orbsType=0）使用按相位的 orbs 字符串值。

## 五、星体可见性对比（现代 vs 古典/特殊）

### 5.1 A 族（本命盘级）shownPlanets

| 体系 | shownPlanets（显示的星体） | 数量 |
|---|---|---|
| 现代 | Uranus, Neptune, Pluto, Juno, Lilith, Fortune, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 16 |
| 古典 | Fortune, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 11 |
| 特殊 | Fortune, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 11 |

### 5.2 B 族（推运盘级）shownPlanets

| 体系 | shownPlanets（显示的星体） | 数量 |
|---|---|---|
| 现代 | Uranus, Neptune, Pluto, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 13 |
| 古典 | Fortune, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 11 |
| 特殊 | Fortune, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Asc, Mc, NorthNode | 11 |

### 5.3 差异矩阵

| 星体 | 现代 A族 | 现代 B族 | 古典 | 特殊 |
|---|---|---|---|---|
| Uranus（天王星） | ✅ | ✅ | ❌ | ❌ |
| Neptune（海王星） | ✅ | ✅ | ❌ | ❌ |
| Pluto（冥王星） | ✅ | ✅ | ❌ | ❌ |
| Juno（婚神星） | ✅ | ❌ | ❌ | ❌ |
| Lilith（莉莉丝） | ✅ | ❌ | ❌ | ❌ |
| Fortune（福点） | ✅ | ❌ | ✅ | ✅ |
| 七政+Asc/Mc/NN | ✅ | ✅ | ✅ | ✅ |

**核心差异：**
1. 古典/特殊体系：隐藏天海冥 + 隐藏 Juno/Lilith → 比现代少 5 个星体
2. 现代 A族 vs B族：A族额外显示 Juno、Lilith、Fortune（3个），B族隐藏这 3 个
3. Fortune（福点）：古典/特殊显示，现代 B族隐藏，现代 A族显示——是体系差异与族差异的交叉点

### 5.4 hiddenPlanets 完整清单

**现代 A 族 hiddenPlanets（24个）：** SouthNode, Chiron, Ceres, Pallas, Vesta, Pholus, SpiritPoint, Ic, Des, Vertex, EP, Ziqi, Syzygy, Cupido, Hades, Zeus, Kronos, Apollon, Admetos, Vulcanus, Poseidon, Eros, Psyche, Quaoar

**现代 B 族 hiddenPlanets（26个）：** Juno, Lilith, Fortune, SouthNode, Chiron, Ceres, Pallas, Vesta, Pholus, SpiritPoint, Ic, Des, Vertex, EP, Ziqi, Syzygy, Cupido, Hades, Zeus, Kronos, Apollon, Admetos, Vulcanus, Poseidon, Eros, Psyche, Quaoar

**古典/特殊 hiddenPlanets（27个）：** Uranus, Neptune, Pluto, Juno, Lilith, SouthNode, Chiron, Ceres, Pallas, Vesta, Pholus, SpiritPoint, Ic, Des, Vertex, EP, Ziqi, Syzygy, Cupido, Hades, Zeus, Kronos, Apollon, Admetos, Vulcanus, Poseidon, Eros, Psyche, Quaoar

## 六、新发现/与文档矛盾项

### 6.1 容许度分类修正

| # | chartName | Vuex 实测 orbs | 原文档归类 | 修正后归类 |
|---|-----------|---------------|-----------|-----------|
| 1 | compare（对比盘） | 2/1/1/1/1/1/1/1/1/1 | 推断为"本命盘级 7°/6°/3°" | **推运盘级 B 族** |
| 2 | secondaryProgressionSolarReturn（次限日返） | 7/6/6/6/6/3/3/3/3/3 | 归为"推运盘级" | **本命盘级 A 族** |
| 3 | decennials（希腊十年） | 7/6/6/6/6/3/3/3/3/3 | 未明确归类 | **本命盘级 A 族**（古典进阶技法但使用本命级容许度） |
| 4 | circumambulation（绕行） | 2/1/1/1/1/1/1/1/1/1 | 未明确归类 | **推运盘级 B 族** |

### 6.2 新发现的 chartName（文档未记录）

| # | chartName | 中文名 | 族 | 说明 |
|---|-----------|--------|---|------|
| 1 | continuousProfection | 连续小限盘 | B 族 | 年小限的连续推运变体，文档中未提及 |
| 2 | minorProgression | 小限推运盘 | B 族 | 独立于 tertiaryProgression 的新推运盘型，文档中未提及 |

### 6.3 合盘子盘型独立条目

所有 A 族基盘在 chartSettingMap 中都有对应的 Compare 变体（B 族），证实合盘对比功能为每个基盘都创建了独立设置条目：

| A 族基盘 | 对应的 B 族 Compare 盘 |
|-----------|----------------------|
| solarReturn | solarReturnCompare |
| lunarReturn | lunarReturnCompare |
| divisional12 | divisional12Compare |
| divisional13 | divisional13Compare |
| draconic | draconicCompare |
| harmonic | harmonicCompare |
| secondaryProgressionSolarReturn | secondaryProgressionSolarReturnCompare |
| — | compare（通用对比盘） |
| combination | combinationCompareDatetime |
| secondaryProgression | secondaryProgressionCombination + secondaryProgressionCombinationCompare + secondaryProgressionCompare |
| tertiaryProgression | tertiaryProgressionCombination + tertiaryProgressionCombinationCompare + tertiaryProgressionCompare |
| minorProgression | minorProgressionCompare |
| mid | midTransit + midSecondaryProgression + midTertiaryProgression |
| marks | marksSecondaryProgression + marksTertiaryProgression |

**规律：** Compare 类盘型一律为 B 族（2/1/1 推运级容许度），基盘类保持原族归属。

### 6.4 type 字段分布

- **type=2**（3个）：natal、transit、tertiaryProgressionCompare — 双盘叠加结构
- **type=0**（42个）：其余所有盘型 — 单盘结构

## 七、完整 chartName 清单（45 个）

### A 族（本命盘级 7/6/6/6/6/3/3/3/3/3）— 16 个

| # | chartName | 中文名 | type |
|---|-----------|--------|------|
| 1 | natal | 本命盘 | 2 |
| 2 | datetime | 天象盘 | 0 |
| 3 | combination | 组合中点盘 | 0 |
| 4 | mid | 中点盘 | 0 |
| 5 | marks | 马克斯盘 | 0 |
| 6 | lunarReturn | 月返盘 | 0 |
| 7 | solarReturn | 日返盘 | 0 |
| 8 | divisional12 | 十二分盘 | 0 |
| 9 | divisional13 | 十三分盘 | 0 |
| 10 | firdaria | 法达盘 | 0 |
| 11 | profection | 年小限盘 | 0 |
| 12 | reLocation | 重置盘 | 0 |
| 13 | draconic | 龙首盘 | 0 |
| 14 | decennials | 希腊十年大运盘 | 0 |
| 15 | harmonic | 泛音盘 | 0 |
| 16 | secondaryProgressionSolarReturn | 次限日返盘 | 0 |

### B 族（推运盘级 2/1/1/1/1/1/1/1/1/1）— 29 个

| # | chartName | 中文名 | type |
|---|-----------|--------|------|
| 1 | primaryDirection | 主限盘 | 0 |
| 2 | circumambulation | 绕行盘 | 0 |
| 3 | continuousProfection | 连续小限盘 | 0 |
| 4 | secondaryProgression | 次限盘 | 0 |
| 5 | tertiaryProgression | 三限盘 | 0 |
| 6 | minorProgression | 小限推运盘 | 0 |
| 7 | solarArc | 日弧盘 | 0 |
| 8 | transit | 行运盘 | 2 |
| 9 | compare | 对比盘 | 0 |
| 10 | combinationCompareDatetime | 组合天象对比盘 | 0 |
| 11 | secondaryProgressionCombination | 次限组合盘 | 0 |
| 12 | secondaryProgressionCombinationCompare | 次限组合对比盘 | 0 |
| 13 | tertiaryProgressionCombination | 三限组合盘 | 0 |
| 14 | tertiaryProgressionCombinationCompare | 三限组合对比盘 | 0 |
| 15 | midTransit | 中点行运盘 | 0 |
| 16 | midSecondaryProgression | 中点次限盘 | 0 |
| 17 | midTertiaryProgression | 中点三限盘 | 0 |
| 18 | marksSecondaryProgression | 马克斯次限盘 | 0 |
| 19 | marksTertiaryProgression | 马克斯三限盘 | 0 |
| 20 | secondaryProgressionCompare | 次限对比盘 | 0 |
| 21 | tertiaryProgressionCompare | 三限对比盘 | 2 |
| 22 | minorProgressionCompare | 小限推运对比盘 | 0 |
| 23 | solarReturnCompare | 日返对比盘 | 0 |
| 24 | lunarReturnCompare | 月返对比盘 | 0 |
| 25 | divisional12Compare | 十二分对比盘 | 0 |
| 26 | divisional13Compare | 十三分对比盘 | 0 |
| 27 | draconicCompare | 龙首对比盘 | 0 |
| 28 | harmonicCompare | 泛音对比盘 | 0 |
| 29 | secondaryProgressionSolarReturnCompare | 次限日返对比盘 | 0 |

## 八、单双盘对应关系（12 对）

推运类和返照/分盘类各有单双盘配对，容许度规律不同：

### 8.1 推运类 5 对（单双盘容许度相同，均为 B 族 2/1）

| 单盘 | 双盘（Compare 后缀） | 说明 |
|---|---|---|
| secondaryProgression | secondaryProgressionCompare | 次限盘 ↔ 次限对比盘 |
| tertiaryProgression | tertiaryProgressionCompare | 三限盘 ↔ 三限对比盘 |
| minorProgression | minorProgressionCompare | 小限推运盘 ↔ 小限推运对比盘 |
| secondaryProgressionCombination | secondaryProgressionCombinationCompare | 次限组合盘 ↔ 次限组合对比盘 |
| tertiaryProgressionCombination | tertiaryProgressionCombinationCompare | 三限组合盘 ↔ 三限组合对比盘 |

### 8.2 返照/分盘类 7 对（单盘 A 族 7/6，双盘 B 族 2/1，**容许度不同**）

| 单盘 | 双盘（Compare 后缀） | 单盘 orbs | 双盘 orbs |
|---|---|---|---|
| solarReturn | solarReturnCompare | 7/6/6/6/6/3/3/3/3/3 | 2/1/1/1/1/1/1/1/1/1 |
| lunarReturn | lunarReturnCompare | 同上 | 同 |
| divisional12 | divisional12Compare | 同上 | 同 |
| divisional13 | divisional13Compare | 同上 | 同 |
| draconic | draconicCompare | 同上 | 同 |
| harmonic | harmonicCompare | 同上 | 同 |
| secondaryProgressionSolarReturn | secondaryProgressionSolarReturnCompare | 同上 | 同 |

**关键发现：** 返照/分盘类的双盘（Compare 版）容许度从本命级（7/6/3）缩小到推运级（2/1/1），说明双盘模式下爱占星认为应使用更严格的相位筛选。

## 九、相位可见性（aspectHidden，全站全体系一致）

10 个相位的 hidden 标记在所有 45 个 chartName × 3 体系中完全相同：

```
合/冲/刑/六合/三合/半刑/倍半刑/五分/十分/梅花 = 0/0/0/0/0/1/1/1/1/1
```

| 相位 | 角度 | 默认显示 |
|---|---|---|
| 合相 | 0° | ✅ |
| 冲相 | 180° | ✅ |
| 刑相 | 90° | ✅ |
| 六合 | 60° | ✅ |
| 三合 | 120° | ✅ |
| 半刑 | 45° | ❌ |
| 倍半刑 | 135° | ❌ |
| 五分 | 72° | ❌ |
| 十分 | 36° | ❌ |
| 梅花 | 150° | ❌ |

前 5 个主相位默认显示，后 5 个次相位默认隐藏。

## 十、专属参数（settings 模块，实测）

从 Vuex `settings` 模块提取的盘型专属参数：

### 10.1 法达盘（settingsFirdaria）

| 参数 | 默认值 | 说明 |
|---|---|---|
| fadaType | 0 | 法达类型 |
| fadaCalcType | 0 | 法达计算类型 |
| fadaTableStyleType | 0 | 法达表样式 |
| fadaDayNumberPerYearType | 0 | 每年天数类型 |

### 10.2 小限盘（settingsAnnualProfections）

| 参数 | 默认值 | 说明 |
|---|---|---|
| profectionCalcType | 0 | 小限计算类型 |
| profectionYearType | 0 | 小限年类型 |
| profectionFrom | "Des" | 小限起点（下降点） |
| profectionMonthStart | 0 | 月限起始 |
| profectionMonthDirection | 0 | 月限方向（顺/逆时针） |
| profectionMonthType | 0 | 月限类型 |
| profectionDayType | 0 | 日限类型 |

### 10.3 返照盘（settingsReturnChart）

| 参数 | 默认值 | 说明 |
|---|---|---|
| returnChartIn | 0 | 返照内盘设置 |
| returnAddressType | 0 | 返照地址类型 |
| useSiderealForSolarReturnChart | false | 日返盘使用恒星黄道 |
| useSiderealForLunarReturnChart | false | 月返盘使用恒星黄道 |

### 10.4 主限盘（settingsPrimaryDirections）

| 参数 | 默认值 | 说明 |
|---|---|---|
| keyType | 2 | 按键类型 |
| houseSystem | "PS" | 宫制（Placidus Sidereal？） |
| calcMethod | 2 | 计算方法 |
| directionMethod | 3 | 方向方法 |
| zodiacalLatitude | 1 | 黄道纬度 |
| significators | ["Mc","Asc"] | 指示星 |
| promissors | [10星+NorthNode+Fortune] | 承诺星 |
| ageRange | [0,120] | 年龄范围 |

### 10.5 希腊十年（settingsDecennials）

| 参数 | 默认值 | 说明 |
|---|---|---|
| decennialType | 0 | 十年类型 |
| decennialCalcType | 0 | 十年计算类型 |
| decennialDayNumberPerYearType | 0 | 每年天数类型 |

### 10.6 黄道释放（settingsZodiacalReleasing）

| 参数 | 默认值 | 说明 |
|---|---|---|
| zodiacalReleasingPointSameAllowed | false | 同点是否允许 |
| zodiacalReleasingBold | 0 | 加粗设置 |

### 10.7 古典计算（settingsClassicalCalcs）

| 参数 | 默认值 | 说明 |
|---|---|---|
| fixedStarOrb | 1 | 恒星容许度 |
| antiscoinOrb | 2 | 映点容许度 |
| antisciaAxiosLng | 90 | 映点轴经度 |
| viaCombustType | 0 | 燃烧径类型 |
| receptionType | 0 | 接纳类型 |
| triplicityType | 0 | 三方性类型 |
| wellDegreeType | 0 | 得力度数类型 |

### 10.8 基础计算（settingsBasicCalcs）

| 参数 | 默认值 | 说明 |
|---|---|---|
| nodeTrue | false | 真交点 |
| lilithTrue | false | 真莉莉丝 |
| dayNumPerYear | 0 | 年天数（365/365.25/366） |
| toHouseMcType | 1 | 到宫MC类型 |
| harmonicAgeType | 0 | 泛音年龄类型 |
| midLngType | 0 | 中点经度类型 |

### 10.9 显示设置（settingsChart）

| 参数 | 默认值 | 说明 |
|---|---|---|
| chartStyleArr | 5种风格 | 星夜黑/日光白/专业黑/专业白/深空蓝 |
| cChartType | 0 | 当前风格索引 |
| cChartProfessional | 1 | 专业模式 |
| cChartClassicSign | false | 古典符号 |
| cChartShowSignLine | false | 符号线 |
| cChartPlanetColorType | 0 | 星体颜色类型 |

### 10.10 光线设置（settingsLight）

| 参数 | 默认值 | 说明 |
|---|---|---|
| lightType | 1 | 光线类型 |
| lightSuroundType | 0 | 光晕类型 |

### 10.11 界面设置（settingsInterface）

| 参数 | 默认值 | 说明 |
|---|---|---|
| hideBirthInfo | false | 隐藏出生信息 |
| aspectLineSolid | false | 相位线实线 |
| aspectLineHidden | false | 隐藏相位线 |
| aspectLineIcon | false | 相位线图标 |
| birthTypeDefault | 2 | 出生类型默认值 |
| planetModalShowAllAspect | false | 行星弹窗显示全部相位 |
| showTerm | false | 显示界限 |
| hideSlogan | false | 隐藏标语 |
| paramPlugInClassical | true | 古典参数插件 |
| birthAdjustable | false | 出生可调整 |
| manualShowAspectTable | false | 手动显示相位表 |
| autoViewStyleControl | 0 | 自动视图样式控制 |

## 十一、45 个 chartName 不包含的内容

以下内容在 `chartSettingMap` 中**不存在**，需从其他 Vuex 模块获取：

1. **印占星盘**：完全不在 chartSettingMap 中，数据在 Vuex `state.vedic` 模块
2. **古典进阶 4 技法**（不在 chartSettingMap 中的）：阿拉伯点、中世纪小限、黄道释放、月限
   - 注：主限盘（primaryDirection）、绕行盘（circumambulation）、希腊十年（decennials）、次限日返（secondaryProgressionSolarReturn）已在 chartSettingMap 中

## 十二、与旧文档 5 族分类的修正对照

旧文档曾归纳为 5 大家族（本命盘级/返照盘级/天象盘级/应期盘级/推运盘级），Vuex 实测后修正为 2 族：

| 旧家族 | 旧容许度 | 实测族 | 实测容许度 | 修正原因 |
|---|---|---|---|---|
| 本命盘级 | 7/6/3 | A 族 | 7/6/6/6/6/3/3/3/3/3 | 容许度展开（之前只写了主相位） |
| 返照盘级 | 7/6/3 | A 族 | 同上 | 返照盘容许度与本命盘**完全相同**，无独立族 |
| 天象盘级 | 7/6/3 | A 族 | 同上 | 天象盘（datetime）也在 A 族 |
| 应期盘级 | 7/6/3 | A 族 | 同上 | 法达/小限/重置/希腊十年/泛音均 A 族 |
| 推运盘级 | 2/1/1 | B 族 | 2/1/1/1/1/1/1/1/1/1 | 容许度展开 |

**结论：** 5 族实为 2 族（A/B），旧分类中返照盘级、天象盘级、应期盘级与本命盘级的容许度完全相同，只是 UI 上的"专业参数插件"不同（如返照盘有岁差开关、小限盘有起点方向等），不影响核心容许度。

---

*原始数据文件：`raw/Vuex-store-chartSettingMap-全量.json`*

> AI生成