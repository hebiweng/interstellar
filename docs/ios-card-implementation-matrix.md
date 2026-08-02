# iOS v6 六盘卡片实施矩阵

> 本文件是 v6 的卡片数量、顺序、事实与视觉验收合同。原型用于参考层级、密度和构图，不是字段权威；字段以真实计算能力、当前产品设计和本文件为准。

## 通用合同

每张卡片必须具备：

- 稳定 `cardID`、标题、独立 `visualKind`；
- 一个或多个带稳定 ID 的真实事实；每个事实明确 `metricLabel / calculatedValue / interpretationKey / sourceFactIDs / visualRole`；
- 首屏呈现“计算结果 + 一句自然解读”；短解读来自被 Git 忽略的私有、已审核内容包，Swift 不拼解释句；
- 点击后展开本机 `GeneratedChartArtifact.cardDetails[cardID]`；详情由整盘 AI 请求一次生成，不为单卡另发请求；
- 生成中、失败、离线、本地命中和事实不足的明确状态；事实不足时隐藏无效子项，整卡无事实才显示空状态；
- 中英文单语、浅色/深色/跟随系统、小屏和 Dynamic Type；
- 所有视觉由真实事实映射，不得使用示例分数、默认进度、固定节点或估算日期。

AI 详情不是固定 corpus。完整报告和卡片详情必须携带 `evidenceFactIDs`，只能引用请求中存在且该卡允许使用的事实 ID。

## 本命盘（10 张）

| 顺序 | cardID | 主题 | 事实核心 | 视觉职责 |
|---|---|---|---|---|
| 1 | `natal-interpretation` | 核心人格 | 太阳、月亮、上升 | 三点核心轨道 |
| 2 | `emotional-needs` | 情绪需要 | 月亮落座、落宫及其来源 ID | 计算标签 + 私有一句解读 |
| 3 | `love-connection` | 爱与连接 | 金星、月亮及相关结构 | 给予/需要双指标 |
| 4 | `career-direction` | 事业方向 | MC、MC 主星、主星落座落宫 | 真实三节点方向路径 |
| 5 | `strengths-growth` | 优势与成长面 | 结构重要的支持/挑战相位 | 双列对照 + 补充结构 |
| 6 | `element-balance` | 元素与模式 | 星体元素/模式权重 | 独立分布条，不表达吉凶 |
| 7 | `house-emphasis` | 宫位侧重 | 归一化宫位权重前三 | 领域条 |
| 8 | `chart-signature` | 星盘签名 | 命主星、优势星体、方向性 | 三指标签名块 |
| 9 | `planet-placements` | 行星位置 | 主要星体落座、度数、落宫、逆行 | 可展开位置行 |
| 10 | `key-aspects` | 关键相位 | 紧密度、日月/角点参与、重复结构排序 | 3–5 条相位事实 |

`emotional-needs` 必须位于 `love-connection` 之前。关键相位不得按“最吉利”排序。

## 天象盘（7 张）

| 顺序 | cardID | 事实核心 | 视觉职责 |
|---|---|---|---|
| 1 | `sky-overview` | 月相、活跃相位、逆行、周期事实 | 天空总览 |
| 2 | `moon-now` | 月相、照明、月亮落座、真实换座时刻 | 动态月面与进度 |
| 3 | `aspect-pattern` | 当前主要相位和结构比例 | 相位结构图 |
| 4 | `planetary-motion` | 星体速度、顺逆行、真实转向时刻 | 运动状态列表 |
| 5 | `sign-changes` | 真实 ingress/egress | 日期事件列 |
| 6 | `element-climate` | 天空元素权重 | 元素气候分布 |
| 7 | `upcoming-7-days` | 七天内真实换座、精确相位、转向 | 时间排序事件 |

## 行运盘（6 张）

| 顺序 | cardID | 事实核心 | 视觉职责 |
|---|---|---|---|
| 1 | `current-story` | 结构重要的当前行运与本命领域 | 多信号故事编织 |
| 2 | `current-cycles` | 长期/当前/日常周期及范围 | 分层周期切换 |
| 3 | `transit-timeline` | 真实入相、精确、离相、再次精确 | 7/30/90 天时间线 |
| 4 | `planet-paths` | 行运行星路径、宫位、逆行和换宫 | 路径行 |
| 5 | `life-areas` | 本命宫位映射和相对集中度 | 领域雷达/条形 |
| 6 | `active-transits` | 结构排序后的移动点 × 本命点相位 | 交叉相位事实列表 |

## 次限盘（6 张）

| 顺序 | cardID | 事实核心 | 视觉职责 |
|---|---|---|---|
| 1 | `developmental-chapter` | 次限日月阶段和真实落座 | 发展阶段流 |
| 2 | `progressed-moon` | 次限月亮落座、落宫、在座时长、换座日 | 月亮长期进度 |
| 3 | `identity-development` | 本命太阳与次限太阳 | 双节点身份对照 |
| 4 | `turning-points` | 次限—本命精确触发及日期/容许度 | 转折事件行 |
| 5 | `areas-maturing` | 发展集中度最高领域 | 领域条 |
| 6 | `timeline` | 24 个月真实转折与换座 | 长期时间线 |

次限本轮不开放独立地点或 relocation，不能因 v6 重构退化既有六模块。

## 日返盘（7 张）

| 顺序 | cardID | 事实核心 | 视觉职责 |
|---|---|---|---|
| 1 | `year-theme` | 精确回归盘日月、上升、年度主结构 | 年度轨道 |
| 2 | `year-anchors` | 日返上升、命主星、太阳落宫、角点星体 | 锚点网格 |
| 3 | `priority-areas` | 日返宫位与本命映射权重 | 优先领域 |
| 4 | `year-dynamics` | 支持/挑战结构与重要相位 | 年度动态对照 |
| 5 | `year-timeline` | 从精确回归时刻切分的四阶段 | 年度时间线 |
| 6 | `natal-overlay` | 日返点位与本命角点/星体叠加 | 双盘锚点对照 |
| 7 | `year-aspects` | 日返内部及日返—本命关键相位 | 相位事实列表 |

## 合盘（8 张）

| 顺序 | cardID | 事实核心 | 视觉职责 |
|---|---|---|---|
| 1 | `relationship-overview` | 两张本命盘的主要跨盘结构 | 关系总览轨道 |
| 2 | `perspectives` | 双方分别接收的触发 | 双视角切换 |
| 3 | `emotional-connection` | 月亮及情绪相关跨盘相位 | 情绪连接网格 |
| 4 | `communication` | 水星及沟通相关跨盘相位 | 沟通路径 |
| 5 | `chemistry` | 金星/火星及吸引结构 | 吸引双指标 |
| 6 | `commitment` | 土星及长期结构 | 承诺结构 |
| 7 | `house-overlays` | 双方星体进入对方宫位 | 落宫叠加行 |
| 8 | `key-inter-aspects` | 结构排序后的跨盘相位 | 主要相互相位列表 |

合盘人物有序，缓存指纹不包含当前时间。Composite 明确延期，不得偷偷加入 `ChartKind`、卡片合同或 Today 分支。

## Today v6 固定模块

按顺序检查：`Current Chapter → Active Today → Coming Next → Moon Today → Timeline → Upcoming Sky → Retrogrades → Current Sky`。所有链接、事件行和详情入口必须可导航到真实盘型、日期和上下文。

## Ask 与 Profile

Ask 和 Profile 不受原型覆盖范围限制，保留既有产品设计：

- Ask 三流程、概率/适合度、历史、专业事实和局部轮盘；AI 只解释已计算事实；
- Profile 的本人/其他人物、关系、头像、出生资料、Apple 地图、时区、经纬度、主题、字体、预设、AI 授权与本地数据管理；
- DeepSeek 新增内容逐项审阅，符合真实数据、消费者语言、私有内容和架构边界的保留，否则修正或删除。

## 自动与人工验收

- `scripts/check-ios-card-contract.sh`：六盘 44 个固定 ID、顺序和禁止的 Composite；
- iOS 构建与单元测试；AstroCore 事件、指纹和 Artifact 测试；
- Relay 契约、证据引用、非法 JSON 修复、24 小时加密缓存、鉴权、审计、限流与配额测试；
- `npm run architecture:check`、`npm run lint -- --quiet`、私有内容泄漏检查；
- iPhone 12 mini 的英文/中文、浅色/深色、标准/大字体截图逐张核对。

构建通过不能替代视觉、内容、真实数据、空状态和无障碍验收。
