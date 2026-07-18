"use client";

import { useMemo, useState, type ReactNode } from "react";

import {
  confirmRecipe,
  InterstellarApiError,
  resolveSampleRecipe,
  type RecipeDocument,
} from "./lib/interstellar-api";

type WorkspaceView = "dashboard" | "charts" | "reports" | "data";
type CatalogTab = "techniques" | "topics" | "intents";
type BuilderStep = 1 | 2 | 3 | 4 | 5;
type EntryPointId =
  | "entry.technique"
  | "entry.topic_model"
  | "entry.object_context"
  | "entry.personal_dashboard"
  | "entry.intent"
  | "entry.context_shortcut";

const topicModels = [
  ["personality.modern.v1", "现代本命结构", "人格与本命", "Alpha"],
  ["personality.psychodynamic.v1", "心理动力与内在冲突", "人格与本命", "Pro"],
  ["personality.shadow_archetype.v1", "阴影与原型倾向", "人格与本命", "V1"],
  ["personality.dominant_signature.v1", "主导行星与星盘签名", "人格与本命", "Beta"],
  ["personality.classical.v1", "古典本命判断", "人格与本命", "Beta"],
  ["personality.hellenistic.v1", "希腊化本命结构", "人格与本命", "Pro"],
  ["personality.integrated.v1", "多流派本命综合", "人格与本命", "Pro"],
  ["topic.career_vocation.v1", "职业、天赋与使命", "人生主题", "Beta"],
  ["topic.money_resources.v1", "财富、资源与成功", "人生主题", "Beta"],
  ["topic.fixed_star_story.v1", "恒星与人生主题", "人生主题", "V1"],
  ["topic.parent_child.v1", "亲子互动与成长", "人生主题", "Pro"],
  ["topic.life_stage_midlife.v1", "人生阶段与中年周期", "人生主题", "V1"],
  ["timing.short_term.v1", "短期行运周期", "时间与预测", "Alpha"],
  ["timing.annual_integrated.v1", "年度综合周期", "时间与预测", "Pro"],
  ["timing.long_cycle.v1", "长期人生周期", "时间与预测", "V1"],
  ["timing.personal_eclipse.v1", "个人食相周期", "时间与预测", "Pro"],
  ["relationship.comparison.v1", "关系比较与双向影响", "关系", "Alpha"],
  ["relationship.entity.v1", "关系实体与共同方向", "关系", "Beta"],
  ["relationship.dynamic.v1", "动态关系周期", "关系", "V1"],
  ["special.project_event.v1", "项目与事件周期", "专项", "V1"],
  ["special.horary.v1", "卜卦判定", "专项", "Pro"],
  ["special.electional.v1", "择时约束优化", "专项", "Pro"],
  ["special.mundane.v1", "世运与组织周期", "专项", "V1"],
  ["geography.location.v1", "地理、迁移与地点比较", "地理", "Pro"],
] as const;

const intents = [
  ["intent.natal_overview", "本命全貌", "自我与人生"],
  ["intent.core_psychodynamics", "核心人格动力", "自我与人生"],
  ["intent.talents_signature", "优势、天赋与主导特征", "自我与人生"],
  ["intent.shadow_growth", "内在矛盾、阴影与成长课题", "自我与人生"],
  ["intent.life_stage", "人生阶段与中年周期", "自我与人生"],
  ["intent.career_vocation", "职业方向与使命", "事业与财富"],
  ["intent.work_style", "工作方式与能力结构", "事业与财富"],
  ["intent.current_career_cycle", "当前事业周期", "事业与财富"],
  ["intent.career_transition", "职位变化与职业转型窗口", "事业与财富"],
  ["intent.money_resources", "财富与资源模式", "事业与财富"],
  ["intent.entrepreneurship_project_fit", "创业倾向与项目适配", "事业与财富"],
  ["intent.personal_relationship_pattern", "个人关系模式", "关系"],
  ["intent.attraction_compatibility", "两人吸引与兼容", "关系"],
  ["intent.relationship_entity", "关系作为独立实体", "关系"],
  ["intent.relationship_timing", "关系当前与未来周期", "关系"],
  ["intent.commitment_intimacy_conflict", "承诺、亲密与冲突结构", "关系"],
  ["intent.parent_child_family", "亲子与家庭互动", "关系"],
  ["intent.current_cycle", "当前处于什么周期", "时间与周期"],
  ["intent.next_7_30_90_days", "未来7、30或90天", "时间与周期"],
  ["intent.annual_cycle", "年度综合周期", "时间与周期"],
  ["intent.long_cycle_3_5_10_years", "未来3、5或10年长期周期", "时间与周期"],
  ["intent.eclipse_return_events", "个人食相、返照与重要天象", "时间与周期"],
  ["intent.project_or_event_chart", "项目或事件本身", "项目与决策"],
  ["intent.project_cycle_risk", "项目发展周期与风险窗口", "项目与决策"],
  ["intent.horary_question", "具体问题的卜卦判断", "项目与决策"],
  ["intent.electional_time", "为行动选择时间", "项目与决策"],
  ["intent.compare_candidate_dates", "比较多个候选日期", "项目与决策"],
  ["intent.relocation_effect", "迁移到某地的影响", "地理"],
  ["intent.compare_cities", "比较多个城市", "地理"],
  ["intent.astrocartography_lines", "查看全球占星地理线", "地理"],
  ["intent.local_space_paran", "Local Space与Paran分析", "地理"],
  ["intent.organization_analysis", "公司或组织分析", "组织与世运"],
  ["intent.country_city_cycle", "国家或城市周期", "组织与世运"],
  ["intent.ingress_lunation_eclipse", "四季进入盘、朔望与食相", "组织与世运"],
  ["intent.outer_planet_mundane", "重大行星周期与世运事件", "组织与世运"],
] as const;

const techniques = [
  ["本命盘", "natal.standard_chart", "单盘 · Alpha"],
  ["当前行运", "forecast.transits", "双轮 · Alpha"],
  ["太阳 / 月亮返照", "forecast.returns", "返照 · Alpha"],
  ["次限推运", "forecast.secondary_progression", "推运 · Beta"],
  ["太阳弧", "forecast.solar_arc", "弧向 · Beta"],
  ["比较盘", "relationship.synastry", "关系 · Alpha"],
  ["组合盘", "relationship.composite", "关系 · Alpha"],
  ["戴维森盘", "relationship.davison", "关系 · Beta"],
  ["年度小限", "timing.annual_profections", "古典 · Pro"],
  ["黄道释放", "timing.zodiacal_releasing", "古典 · Pro"],
  ["主限法", "forecast.primary_directions", "古典 · Pro"],
  ["卜卦占星", "special.horary", "专项 · Pro"],
  ["择时搜索", "special.electional", "专项 · Pro"],
  ["迁移盘", "geography.relocation", "地理 · Pro"],
  ["占星地理线", "geography.astrocartography", "地理 · Pro"],
] as const;

const entryModes = [
  { id: "entry.technique", title: "技法排盘", description: "直接选择本命、行运、推运、返照等方法", tab: "techniques", symbol: "◫", defaultItem: "natal.standard_chart", context: "只添加技法必需依赖；默认不添加解释模型" },
  { id: "entry.topic_model", title: "专题模型", description: "从24个已定义专题模型开始分析", tab: "topics", symbol: "◇", defaultItem: "personality.modern.v1", context: "核心配方锁定；允许声明过的参数与兼容扩展" },
  { id: "entry.intent", title: "分析目的", description: "从35个现实问题反推模型与计算", tab: "intents", symbol: "◎", defaultItem: "intent.natal_overview", context: "由目的解析专题、技法、对象角色与输出" },
  { id: "entry.object_context", title: "对象快捷", description: "人物、关系、项目、事件、组织或问题", tab: "topics", symbol: "↗", defaultItem: "personality.modern.v1", context: "预填当前对象，并按对象类型显示可执行动作" },
  { id: "entry.personal_dashboard", title: "时间与周期", description: "7/30/90天、年度或长期周期", tab: "intents", symbol: "⌁", defaultItem: "intent.current_cycle", context: "预填当前人物与当前时间；只复用已有缓存" },
  { id: "entry.context_shortcut", title: "关系／项目／地点", description: "预填双人、项目或地点上下文", tab: "intents", symbol: "⌖", defaultItem: "intent.attraction_compatibility", context: "根据快捷场景预填角色、时间范围或目标地点" },
] as const;

const entryRequirements: Record<EntryPointId, readonly string[]> = {
  "entry.technique": ["主对象：人物、事件、项目或组织", "先选择明确技法", "解释模型默认关闭"],
  "entry.topic_model": ["主对象由专题输入契约决定", "专题核心配方锁定", "缺失角色在预检中阻断"],
  "entry.object_context": ["当前对象已预填", "只展示该对象类型可执行动作", "允许更换对象版本"],
  "entry.personal_dashboard": ["当前人物已预填", "当前时间自动进入时间上下文", "页面只复用缓存，不自动批量计算"],
  "entry.intent": ["先选择现实分析目的", "后端反推对象角色与计算", "用户补齐缺失输入后再预检"],
  "entry.context_shortcut": ["关系需第二人物", "项目需事件时刻或锚点", "地理需目标地点；缺失项不会被猜测"],
};

const baseModels = [
  ["natal.modern.v1", "现代本命", "Alpha目标"], ["natal.classical.v1", "古典本命", "Beta目标"],
  ["natal.hellenistic.v1", "希腊化本命", "Beta目标"], ["natal.integrated.v1", "综合本命", "Pro目标"],
  ["forecast.short_transit.v1", "短期行运", "Alpha目标"], ["forecast.annual_integrated.v1", "年度综合", "Pro目标"],
  ["forecast.long_cycle.v1", "长期周期", "V1目标"], ["relationship.comparison.v1", "关系比较", "Alpha目标"],
  ["relationship.entity.v1", "关系实体", "Beta目标"], ["special.project_event.v1", "项目事件", "V1目标"],
  ["special.question_action.v1", "卜卦择时", "Pro目标"], ["geography.location.v1", "地理迁移", "Pro目标"],
] as const;

const chartFamilies = [
  ["基础轮盘", 17, "本命、事件、项目、卜卦、迁移、谐波"],
  ["多轮盘", 14, "双轮、三轮、四轮与自定义叠盘"],
  ["关系图", 14, "比较、组合、戴维森与动态关系"],
  ["表格与网格", 28, "位置、宫位、相位、尊贵、中点"],
  ["预测时间图", 24, "行运甘特、图形星历与时间主星"],
  ["地图", 13, "Astrocartography、Local Space、Paran"],
  ["高级技术图", 18, "刻度盘、网络、赤纬与可见性"],
  ["消费者扩展", 18, "V1后：主题曲线、热力图与反馈"],
] as const;

type ChartPreview = {
  name: string;
  viewId: string;
  status: string;
  tone: "neutral" | "green" | "amber" | "blue" | "violet";
  action?: "dashboard" | "data" | "transit";
  reason?: string;
};

const chartPreviews: Record<(typeof chartFamilies)[number][0], readonly ChartPreview[]> = {
  "基础轮盘": [
    { name: "本命盘轮盘", viewId: "wheel.natal", status: "已有演示快照", tone: "green", action: "dashboard" },
    { name: "无出生时间盘", viewId: "wheel.unknown_time", status: "M6", tone: "amber", reason: "等待未知出生时间计算链路" },
    { name: "当前天空盘", viewId: "wheel.current_sky", status: "可发起预检", tone: "blue", action: "transit" },
    { name: "事件盘", viewId: "wheel.event", status: "M6", tone: "amber", reason: "等待真实事件对象输入" },
    { name: "项目启动盘", viewId: "wheel.project_start", status: "M18", tone: "amber", reason: "等待项目对象与专项规则" },
    { name: "公司盘", viewId: "wheel.organization", status: "M24", tone: "neutral", reason: "列入世运与组织阶段" },
    { name: "国家盘", viewId: "wheel.country", status: "M24", tone: "neutral", reason: "列入世运阶段" },
    { name: "问事盘", viewId: "wheel.horary", status: "M18", tone: "amber", reason: "等待卜卦规则引擎" },
  ],
  "多轮盘": [
    { name: "本命＋行运双轮", viewId: "multi.natal_transit", status: "M6", tone: "amber", reason: "等待双轮渲染器" },
    { name: "本命＋次限双轮", viewId: "multi.natal_secondary", status: "M12", tone: "amber", reason: "等待次限计算" },
    { name: "本命＋太阳弧双轮", viewId: "multi.natal_solar_arc", status: "M12", tone: "amber", reason: "等待太阳弧计算" },
    { name: "本命＋太阳返照双轮", viewId: "multi.natal_solar_return", status: "M6", tone: "amber", reason: "等待返照与双轮渲染" },
    { name: "A＋B比较盘", viewId: "multi.synastry", status: "M6", tone: "amber", reason: "等待双对象输入" },
    { name: "本命＋迁移盘", viewId: "multi.relocation", status: "M18", tone: "amber", reason: "等待地理引擎" },
    { name: "本命＋行运＋推运三轮", viewId: "multi.timing_triple", status: "M12", tone: "amber", reason: "等待多轮渲染器" },
    { name: "自定义四轮盘", viewId: "multi.custom_quad", status: "M12", tone: "neutral", reason: "等待多轮编排协议" },
  ],
  "关系图": [
    { name: "比较盘", viewId: "relationship.synastry", status: "M6", tone: "amber", reason: "等待双对象输入" },
    { name: "双向宫位覆盖", viewId: "relationship.house_overlay", status: "M12", tone: "amber", reason: "等待关系派生数据" },
    { name: "组合盘", viewId: "relationship.composite", status: "M6", tone: "amber", reason: "等待组合盘计算" },
    { name: "戴维森盘", viewId: "relationship.davison", status: "M12", tone: "amber", reason: "等待时空中点计算" },
    { name: "推运合盘", viewId: "relationship.progressed", status: "M24", tone: "neutral", reason: "等待动态关系阶段" },
    { name: "关系相位网络", viewId: "relationship.aspect_network", status: "M12", tone: "amber", reason: "等待关系网络渲染器" },
    { name: "家庭多人关系网络", viewId: "relationship.family_network", status: "V1后", tone: "violet", reason: "不在专业 V1 承诺范围" },
    { name: "双方时间周期对照", viewId: "relationship.timing_compare", status: "M24", tone: "neutral", reason: "等待动态关系阶段" },
  ],
  "表格与网格": [
    { name: "行星位置表", viewId: "table.planet_positions", status: "已有演示数据", tone: "green", action: "data" },
    { name: "宫头表", viewId: "table.house_cusps", status: "M6", tone: "amber", reason: "等待真实计算快照" },
    { name: "本命相位表", viewId: "table.natal_aspects", status: "M6", tone: "amber", reason: "等待相位计算快照" },
    { name: "相位网格", viewId: "grid.aspects", status: "M6", tone: "amber", reason: "等待网格渲染器" },
    { name: "尊贵表", viewId: "table.dignities", status: "M12", tone: "amber", reason: "等待古典派生指标" },
    { name: "中点树", viewId: "tree.midpoints", status: "M12", tone: "amber", reason: "等待中点引擎" },
    { name: "定位星链", viewId: "graph.dispositor", status: "M12", tone: "amber", reason: "等待守护与接纳规则" },
    { name: "未来事件列表", viewId: "table.future_events", status: "M12", tone: "neutral", reason: "等待统一事件搜索器" },
  ],
  "预测时间图": [
    { name: "行运甘特时间轴", viewId: "timeline.transit_gantt", status: "M12", tone: "amber", reason: "等待事件搜索器" },
    { name: "行运强度曲线", viewId: "timeline.transit_strength", status: "M12", tone: "amber", reason: "等待时间窗口数据" },
    { name: "图形星历", viewId: "timeline.graphical_ephemeris", status: "M12", tone: "amber", reason: "等待高密度渲染器" },
    { name: "逆行日历", viewId: "calendar.retrogrades", status: "M12", tone: "amber", reason: "等待事件搜索器" },
    { name: "返照日历", viewId: "calendar.returns", status: "M12", tone: "amber", reason: "等待返照搜索" },
    { name: "次限时间线", viewId: "timeline.secondary", status: "M12", tone: "amber", reason: "等待次限计算" },
    { name: "黄道释放 L1—L4", viewId: "timeline.zodiacal_releasing", status: "M18", tone: "neutral", reason: "等待古典时间主星" },
    { name: "多方法联合时间线", viewId: "timeline.integrated", status: "M24", tone: "neutral", reason: "等待多技法联合阶段" },
  ],
  "地图": [
    { name: "全球占星地图", viewId: "map.astrocartography", status: "M18", tone: "amber", reason: "等待地理引擎" },
    { name: "ASC 线地图", viewId: "map.asc_lines", status: "M18", tone: "amber", reason: "等待地理线计算" },
    { name: "DSC 线地图", viewId: "map.dsc_lines", status: "M18", tone: "amber", reason: "等待地理线计算" },
    { name: "MC 线地图", viewId: "map.mc_lines", status: "M18", tone: "amber", reason: "等待地理线计算" },
    { name: "IC 线地图", viewId: "map.ic_lines", status: "M18", tone: "amber", reason: "等待地理线计算" },
    { name: "Paran 地图", viewId: "map.paran", status: "M18", tone: "amber", reason: "等待恒星与地平计算" },
    { name: "Local Space 地图", viewId: "map.local_space", status: "M18", tone: "amber", reason: "等待本地空间计算" },
    { name: "日食路径图", viewId: "map.eclipse_path", status: "M24", tone: "neutral", reason: "等待食相地理投影" },
  ],
  "高级技术图": [
    { name: "90°刻度盘", viewId: "dial.90", status: "M12", tone: "amber", reason: "等待刻度盘渲染器" },
    { name: "45°刻度盘", viewId: "dial.45", status: "M12", tone: "amber", reason: "等待刻度盘渲染器" },
    { name: "22.5°刻度盘", viewId: "dial.22_5", status: "M12", tone: "amber", reason: "等待刻度盘渲染器" },
    { name: "谐波轮盘", viewId: "wheel.harmonic", status: "M12", tone: "amber", reason: "等待谐波计算" },
    { name: "中点指针盘", viewId: "dial.midpoint_pointer", status: "M12", tone: "amber", reason: "等待中点计算" },
    { name: "相位网络图", viewId: "graph.aspects", status: "M12", tone: "amber", reason: "等待网络渲染器" },
    { name: "3D赤纬星盘", viewId: "chart.declination_3d", status: "M24", tone: "neutral", reason: "等待高级赤纬能力" },
    { name: "恒星 Paran 图", viewId: "chart.fixed_star_paran", status: "M18", tone: "neutral", reason: "等待恒星与 Paran 引擎" },
  ],
  "消费者扩展": [
    { name: "今日主题活跃度", viewId: "consumer.topic_today", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "本周周期曲线", viewId: "consumer.week_curve", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "月度主题热力图", viewId: "consumer.month_heatmap", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "年度主题热力图", viewId: "consumer.year_heatmap", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "事业活动曲线", viewId: "consumer.career_curve", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "关系稳定趋势", viewId: "consumer.relationship_curve", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "项目推进窗口", viewId: "consumer.project_window", status: "V1后", tone: "violet", reason: "消费者产品路线" },
    { name: "事件与行运对照", viewId: "consumer.event_transit", status: "V1后", tone: "violet", reason: "消费者产品路线" },
  ],
};

const reports = [
  ["计算记录报告", "原始输入、参数、计算结果、版本和警告", "M6"],
  ["技法分析报告", "单一技法的配置、时间窗口与技术解释", "M6"],
  ["专题模型报告", "基线、优势、压力、矛盾、激活和证据", "结构预览"],
  ["目的综合报告", "跨模型发现、时间窗口、反证和确定度", "M18"],
  ["对象档案报告", "选择多个本命、预测、关系或项目模块", "M18"],
  ["研究比较报告", "样本、方法、共同点、差异与可复现附录", "M24"],
] as const;

const planets = [
  ["☉", "太阳", "白羊 08°14′", "5宫"], ["☽", "月亮", "水瓶 21°03′", "3宫"],
  ["☿", "水星", "双鱼 27°46′", "4宫"], ["♀", "金星", "金牛 13°22′", "6宫"],
  ["♂", "火星", "水瓶 05°18′", "2宫"], ["♃", "木星", "处女 06°41′ R", "10宫"],
] as const;

function IconButton({ children, label, onClick, unavailableReason }: { children: ReactNode; label: string; onClick?: () => void; unavailableReason?: string }) {
  return <button className="icon-button" aria-label={label} onClick={onClick} disabled={!onClick} title={!onClick ? unavailableReason : undefined}>{children}</button>;
}

function AstrologyWheel() {
  const zodiac = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"];
  return (
    <div className="astro-wheel" role="img" aria-label="虚拟示例人物的缓存本命盘">
      <div className="wheel-ring wheel-ring-one" />
      <div className="wheel-ring wheel-ring-two" />
      <div className="wheel-cross wheel-cross-a" />
      <div className="wheel-cross wheel-cross-b" />
      <div className="aspect-web"><i /><i /><i /><i /><i /></div>
      {zodiac.map((symbol, index) => {
        const angle = index * 30 + 15;
        return <span key={symbol} className="zodiac" style={{ transform: `rotate(${angle}deg) translateY(-138px) rotate(${-angle}deg)` }}>{symbol}</span>;
      })}
      {planets.map((planet, index) => {
        const angle = [8, 321, 357, 43, 305, 156][index];
        return <span key={planet[0]} className="planet" style={{ transform: `rotate(${angle}deg) translateY(-106px) rotate(${-angle}deg)` }}>{planet[0]}</span>;
      })}
      <div className="wheel-center"><small>ASC</small><strong>19°07′</strong><span>天蝎</span></div>
      <span className="axis-label axis-asc">ASC 19°</span>
      <span className="axis-label axis-mc">MC 24°</span>
    </div>
  );
}

function StatusPill({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "green" | "amber" | "blue" | "violet" }) {
  return <span className={`status-pill ${tone}`}>{children}</span>;
}

function PreflightPlan({
  status,
  error,
  recipe,
  entryPointId,
  selectedItem,
}: {
  status: "idle" | "resolving" | "ready" | "blocked";
  error: string | null;
  recipe: RecipeDocument | null;
  entryPointId: EntryPointId;
  selectedItem: string;
}) {
  if (status === "resolving") {
    return <div className="preflight-state"><span className="state-spinner" /><strong>正在生成真实 Recipe 预检</strong><p>创建虚拟示例对象版本，解析入口、依赖、输入缺口、输出和资源预算。</p></div>;
  }
  if (status === "blocked" || !recipe) {
    return <div className="preflight-state blocked"><span>!</span><strong>当前不能生成预检</strong><p>{error ?? "请从上一步生成预检。"}</p><small>没有真实 Recipe 时，“确认并运行”保持禁用；页面不会创建模拟快照。</small></div>;
  }

  const required = recipe.nodes.filter((node) => node.selected && node.tier === "required" && node.availability !== "blocked");
  const recommended = recipe.nodes.filter((node) => node.selected && node.tier === "recommended" && node.availability !== "blocked");
  const optional = recipe.nodes.filter((node) => !node.selected || node.tier === "optional");
  const blocked = recipe.nodes.filter((node) => node.availability === "blocked");
  const groups = [
    { title: "必需", nodes: required, tone: "green" as const },
    { title: "推荐", nodes: recommended, tone: "blue" as const },
    { title: "可选", nodes: optional, tone: "amber" as const },
    { title: "阻断", nodes: blocked, tone: "neutral" as const },
  ];
  return <>
    <div className="preflight-grid">
      {groups.map((group) => <article key={group.title}><header><StatusPill tone={group.tone}>{group.title} · {group.nodes.length}</StatusPill><span>{group.nodes.length ? "服务端解析" : "无"}</span></header><ul>{group.nodes.length ? group.nodes.slice(0, 6).map((node) => <li key={node.node_id}><b>{node.calculation_id}</b><small>{node.availability === "blocked" ? node.blocking_reasons.map((reason) => reason.code).join(" · ") || "依赖阻断" : `${node.availability}${node.locked ? " · 锁定" : ""}`}</small></li>) : <li><b>本组没有节点</b><small>不会为填满界面而添加计算</small></li>}</ul></article>)}
    </div>
    <div className="recipe-summary">
      <div><span>入口 / 选择</span><code>{entryPointId}<br />{selectedItem}</code></div>
      <div><span>Recipe</span><code>{recipe.recipe_id}<br />{recipe.content_hash.slice(0, 20)}…</code></div>
      <div><span>资源预算</span><strong>{recipe.resource_estimate.class} · {recipe.resource_estimate.execution_mode}<br />{recipe.resource_estimate.duration_ms_p50}ms / {recipe.resource_estimate.search_points}点</strong></div>
      <div><span>输出 / 警告</span><strong>{recipe.outputs.view_ids.length}图 · {recipe.outputs.report_profile_ids.length}报告 · {recipe.warnings.length}警告</strong></div>
    </div>
  </>;
}

export default function Home() {
  const [view, setView] = useState<WorkspaceView>("dashboard");
  const [analysisOpen, setAnalysisOpen] = useState(false);
  const [entryPointId, setEntryPointId] = useState<EntryPointId>("entry.topic_model");
  const [catalogTab, setCatalogTab] = useState<CatalogTab>("topics");
  const [builderStep, setBuilderStep] = useState<BuilderStep>(1);
  const [selectedItem, setSelectedItem] = useState("personality.modern.v1");
  const [search, setSearch] = useState("");
  const [subjectMode, setSubjectMode] = useState<"sample" | "new">("sample");
  const [running, setRunning] = useState(false);
  const [preflightStatus, setPreflightStatus] = useState<"idle" | "resolving" | "ready" | "blocked">("idle");
  const [preflightError, setPreflightError] = useState<string | null>(null);
  const [resolvedRecipe, setResolvedRecipe] = useState<RecipeDocument | null>(null);
  const [notice, setNotice] = useState("已加载 1 份虚拟示例缓存；本页未启动任何新计算");
  const [chartFamily, setChartFamily] = useState<(typeof chartFamilies)[number][0]>("基础轮盘");
  const [chartQuery, setChartQuery] = useState("");
  const [chartStatus, setChartStatus] = useState<"all" | "active" | "planned" | "post_v1">("all");
  const [reportDensity, setReportDensity] = useState("标准");
  const [displayDensity, setDisplayDensity] = useState<"comfortable" | "compact">("comfortable");

  const catalogItems = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (catalogTab === "topics") {
      return topicModels.filter((item) => `${item[0]} ${item[1]} ${item[2]}`.toLowerCase().includes(needle));
    }
    if (catalogTab === "intents") {
      return intents
        .map((item, index) => [item[0], item[1], item[2], index < 12 ? "Beta" : "Pro"] as const)
        .filter((item) => `${item[0]} ${item[1]} ${item[2]}`.toLowerCase().includes(needle));
    }
    return techniques
      .map((item) => [item[1], item[0], "计算技法", item[2]] as const)
      .filter((item) => `${item[0]} ${item[1]}`.toLowerCase().includes(needle));
  }, [catalogTab, search]);

  const visibleChartPreviews = useMemo(() => {
    const needle = chartQuery.trim().toLowerCase();
    return chartPreviews[chartFamily].filter((item) => {
      const matchesQuery = `${item.name} ${item.viewId}`.toLowerCase().includes(needle);
      const matchesStatus = chartStatus === "all"
        || (chartStatus === "active" && Boolean(item.action))
        || (chartStatus === "planned" && !item.action && item.status !== "V1后")
        || (chartStatus === "post_v1" && item.status === "V1后");
      return matchesQuery && matchesStatus;
    });
  }, [chartFamily, chartQuery, chartStatus]);

  const activeEntry = entryModes.find((entry) => entry.id === entryPointId) ?? entryModes[1];
  const selectedCatalogItem = catalogItems.find((item) => item[0] === selectedItem);

  const openAnalysis = (
    tab: CatalogTab = "topics",
    item?: string,
    requestedEntry?: EntryPointId,
  ) => {
    const fallbackEntry = tab === "techniques" ? "entry.technique" : tab === "intents" ? "entry.intent" : "entry.topic_model";
    const nextEntryId = requestedEntry ?? fallbackEntry;
    const entry = entryModes.find((candidate) => candidate.id === nextEntryId) ?? entryModes[1];
    setEntryPointId(nextEntryId);
    setCatalogTab(tab);
    setSelectedItem(item ?? entry.defaultItem);
    setSearch("");
    setBuilderStep(1);
    setPreflightStatus("idle");
    setPreflightError(null);
    setResolvedRecipe(null);
    setAnalysisOpen(true);
  };

  const changeCatalogTab = (tab: CatalogTab) => {
    const directEntryByTab: Record<CatalogTab, EntryPointId> = {
      techniques: "entry.technique",
      topics: "entry.topic_model",
      intents: "entry.intent",
    };
    const flexibleEntries: EntryPointId[] = ["entry.object_context", "entry.personal_dashboard", "entry.context_shortcut"];
    if (!flexibleEntries.includes(entryPointId)) setEntryPointId(directEntryByTab[tab]);
    setCatalogTab(tab);
    setSelectedItem(tab === "techniques" ? "natal.standard_chart" : tab === "intents" ? "intent.natal_overview" : "personality.modern.v1");
    setSearch("");
    setPreflightStatus("idle");
    setPreflightError(null);
    setResolvedRecipe(null);
  };

  const chooseCatalogItem = (itemId: string) => {
    setSelectedItem(itemId);
    setPreflightStatus("idle");
    setPreflightError(null);
    setResolvedRecipe(null);
  };

  const resolvePreflight = async () => {
    setBuilderStep(5);
    setPreflightStatus("resolving");
    setPreflightError(null);
    setResolvedRecipe(null);
    try {
      const recipe = await resolveSampleRecipe({ entryPointId, catalogKind: catalogTab, selectedItem });
      setResolvedRecipe(recipe);
      setPreflightStatus("ready");
    } catch (error) {
      const message = error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "预检请求失败，请检查前端与 API 连接。";
      setPreflightError(message);
      setPreflightStatus("blocked");
    }
  };

  const runAnalysis = async () => {
    if (!resolvedRecipe) return;
    setRunning(true);
    setNotice(`正在确认 Recipe ${resolvedRecipe.recipe_id}`);
    try {
      const result = await confirmRecipe(resolvedRecipe);
      setAnalysisOpen(false);
      setView("dashboard");
      setNotice(result.job_id ? `分析任务已排队：${result.job_id}` : `分析已创建：${result.id ?? result.status}`);
    } catch (error) {
      const message = error instanceof InterstellarApiError ? `${error.code}：${error.message}` : "确认 Recipe 失败。";
      setPreflightError(message);
      setPreflightStatus("blocked");
    } finally {
      setRunning(false);
    }
  };

  return (
    <main className={`app-shell density-comfortable density-${displayDensity}`}>
      <header className="topbar">
        <button className="brand" onClick={() => setView("dashboard")} aria-label="返回工作台首页">
          <span className="brand-orbit">✦</span>
          <span><strong>INTERSTELLAR</strong><small>PROFESSIONAL ASTROLOGY</small></span>
        </button>
        <nav className="top-nav" aria-label="工作台主导航">
          {(["dashboard", "charts", "reports", "data"] as const).map((item) => (
            <button key={item} className={view === item ? "active" : ""} onClick={() => setView(item)}>
              {item === "dashboard" ? "工作台" : item === "charts" ? "图表中心 · 146" : item === "reports" ? "报告" : "能力与数据"}
            </button>
          ))}
        </nav>
        <div className="top-actions">
          <span className="dataset-lock"><i /> SE 2.10 · IANA 2026c</span>
          <label className="density-control">
            <span>显示</span>
            <select
              aria-label="工作台显示密度"
              value={displayDensity}
              onChange={(event) => setDisplayDensity(event.target.value as "comfortable" | "compact")}
            >
              <option value="comfortable">舒适</option>
              <option value="compact">紧凑</option>
            </select>
          </label>
          <button className="primary-button compact" onClick={() => openAnalysis()}>＋ 新建分析</button>
          <IconButton label="任务中心" unavailableReason="任务中心完整界面将在持久化 Job 适配器完成后开放">⌁</IconButton>
          <IconButton label="账户" unavailableReason="账户与云端工作区尚未接入当前原型">XG</IconButton>
        </div>
      </header>

      <aside className="sidebar">
        <div className="side-section">
          <div className="section-label"><span>对象库</span><button onClick={() => openAnalysis("topics", "personality.modern.v1", "entry.object_context")}>新增并分析</button></div>
          <button className="subject-card active" onClick={() => setView("dashboard")}>
            <span className="subject-avatar">A</span>
            <span><strong>阿斯特拉</strong><small>1992.03.28 · 21:16</small></span>
            <StatusPill tone="violet">虚拟</StatusPill>
          </button>
          <p className="side-hint">这里只预置一个明确标记的虚拟人物。真实用户对象会在新增并分析后出现。</p>
        </div>

        <div className="side-section grow">
          <div className="section-label"><span>从对象开始</span></div>
          <button className="side-link active" onClick={() => setView("dashboard")}><span>◉</span>个人仪表盘<em>缓存</em></button>
          <button className="side-link" onClick={() => openAnalysis("intents", "intent.next_7_30_90_days", "entry.personal_dashboard")}><span>⌁</span>当前与短期周期<em>按需</em></button>
          <button className="side-link" onClick={() => openAnalysis("intents", "intent.annual_cycle", "entry.personal_dashboard")}><span>□</span>年度与长期周期<em>按需</em></button>
          <button className="side-link" onClick={() => openAnalysis("intents", "intent.attraction_compatibility", "entry.context_shortcut")}><span>⇄</span>关系分析<em>需2人</em></button>
          <button className="side-link" onClick={() => openAnalysis("intents", "intent.relocation_effect", "entry.context_shortcut")}><span>⌖</span>地理与迁移<em>需地点</em></button>
          <button className="side-link" onClick={() => setView("charts")}><span>▦</span>全部图表<em>146</em></button>
        </div>

        <div className="side-section registry-card">
          <div className="registry-row"><span>计算</span><strong>99</strong></div>
          <div className="registry-row"><span>基础模型</span><strong>12</strong></div>
          <div className="registry-row"><span>专题 / 目的</span><strong>24 / 35</strong></div>
          <div className="registry-row"><span>专业V1图</span><strong>128</strong></div>
          <small>目录已校验 · 不会打开即全算</small>
        </div>
      </aside>

      <section className="workspace">
        <div className="workspace-banner" role="status"><span>原型</span>{notice}</div>

        {view === "dashboard" && (
          <>
            <div className="subject-header">
              <div>
                <div className="subject-kicker"><StatusPill tone="violet">虚拟示例</StatusPill><StatusPill tone="green">时间质量 A</StatusPill><span>缓存快照 · CS-DEMO-001</span></div>
                <h1>阿斯特拉的专业占星工作台</h1>
                <p>杭州 · 1992年3月28日 21:16 · Asia/Shanghai · 现代本命预设</p>
              </div>
              <div className="subject-actions">
                <button className="secondary-button" onClick={() => setView("charts")}>查看 146 项图表目录</button>
                <button className="primary-button" onClick={() => openAnalysis()}>开始新的分析</button>
              </div>
            </div>

            <div className="dashboard-grid">
              <article className="panel natal-panel">
                <div className="panel-title">
                  <div><span className="eyebrow">CACHED RESULT</span><h2>现代本命 · 基础视图</h2></div>
                  <div className="segmented"><button className="active" disabled title="当前正在显示轮盘">轮盘</button><button onClick={() => setView("data")}>数据</button><button onClick={() => setView("reports")}>报告</button></div>
                </div>
                <div className="natal-content">
                  <AstrologyWheel />
                  <div className="planet-list">
                    <div className="list-head"><span>天体</span><span>位置</span><span>宫位</span></div>
                    {planets.map((planet) => <div className="planet-row" key={planet[1]}><b>{planet[0]}</b><strong>{planet[1]}</strong><span>{planet[2]}</span><em>{planet[3]}</em></div>)}
                    <button className="text-button" onClick={() => setView("data")}>打开完整位置、宫位、相位与证据 →</button>
                  </div>
                </div>
                <div className="snapshot-foot"><span>引擎：演示缓存</span><span>规则：official.modern_natal.v1</span><span>本页新增计算：0</span></div>
              </article>

              <aside className="panel current-plan">
                <div className="panel-title"><div><span className="eyebrow">CURRENT STATE</span><h2>当前没有分析任务</h2></div><StatusPill>空闲</StatusPill></div>
                <div className="plan-empty"><span>＋</span><strong>选择要分析的内容</strong><p>可以直接选技法，也可以按专题或现实目的进入。系统会先给出计算计划，不会立刻执行。</p><button className="primary-button wide" onClick={() => openAnalysis()}>打开统一分析中心</button></div>
                <div className="plan-rule"><b>运行前你会看到</b><span>必需且锁定</span><span>推荐默认</span><span>可选扩展</span><span>缺失与阻断</span><span>预计图表 / 报告 / 时间</span></div>
              </aside>
            </div>

            <section className="start-section">
              <div className="section-heading"><div><span className="eyebrow">SIX ENTRY PATHS</span><h2>你想从哪里开始？</h2><p>六种入口只负责预填上下文，最终都进入同一个 Recipe 预检和按需计算流程。</p></div><button className="text-button" onClick={() => openAnalysis("techniques")}>浏览全部能力 →</button></div>
              <div className="entry-grid">
                {entryModes.map((item) => <button key={item.id} className="entry-card" data-entry-point={item.id} onClick={() => openAnalysis(item.tab, item.defaultItem, item.id)}><span className="entry-icon">{item.symbol}</span><strong>{item.title}</strong><p>{item.description}</p><em>进入选择 →</em></button>)}
              </div>
            </section>

            <section className="model-strip">
              <div><span className="eyebrow">MODEL REGISTRY</span><h2>12 个后端分析模型</h2><p>它们是确定性能力编排，不是AI模型；卡片显示的是计划目标阶段，当前真实实现状态以能力矩阵为准。</p></div>
              <div className="model-chips">{baseModels.slice(0, 6).map((model) => <div key={model[0]}><span>{model[1]}</span><small>{model[2]}</small></div>)}</div>
              <button className="secondary-button" onClick={() => setView("data")}>查看全部12个</button>
            </section>
          </>
        )}

        {view === "charts" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">RENDER CATALOG</span><h1>146 项 V1 路线图 · 35 项已登记</h1><p>这里按八个图表家族展示当前登记项与后续阶段；未实现的视图明确禁用，不会伪装成已经可用。</p></div><button className="primary-button" onClick={() => openAnalysis("techniques")}>选择技法并生成图表</button></div>
            <div className="status-legend"><StatusPill tone="green">已有快照</StatusPill><StatusPill tone="blue">可直接渲染</StatusPill><StatusPill tone="amber">需追加计算</StatusPill><StatusPill>不可用</StatusPill><StatusPill tone="violet">V1后</StatusPill></div>
            <div className="chart-layout">
              <nav className="family-nav">{chartFamilies.map((family) => <button key={family[0]} className={chartFamily === family[0] ? "active" : ""} onClick={() => { setChartFamily(family[0]); setChartQuery(""); setChartStatus("all"); }}><span>{family[0]}<small>{family[2]}</small></span><strong>{family[1]}</strong></button>)}</nav>
              <div className="chart-results">
                <div className="result-toolbar"><div><h2>{chartFamily}</h2><span>{chartFamilies.find((item) => item[0] === chartFamily)?.[1]} 项路线图 · 当前展示 {visibleChartPreviews.length}</span></div><label>⌕ <input value={chartQuery} onChange={(event) => setChartQuery(event.target.value)} placeholder="按名称或 view_id 搜索" /></label><select aria-label="筛选图表状态" value={chartStatus} onChange={(event) => setChartStatus(event.target.value as typeof chartStatus)}><option value="all">全部状态</option><option value="active">当前可执行</option><option value="planned">V1计划</option><option value="post_v1">V1后</option></select></div>
                <div className="chart-card-grid">
                  {visibleChartPreviews.map((item, index) => <button key={item.viewId} className="chart-card" disabled={!item.action} title={!item.action ? item.reason : undefined} onClick={() => {
                    if (item.action === "dashboard") { setView("dashboard"); setNotice("已返回缓存本命轮盘"); }
                    if (item.action === "data") { setView("data"); setNotice("已打开虚拟示例的数据登记页"); }
                    if (item.action === "transit") openAnalysis("techniques", "forecast.transits", "entry.technique");
                  }}><div className="chart-thumb"><div className="mini-orbit" /><span>{String(index + 1).padStart(2, "0")}</span></div><strong>{item.name}</strong><code>{item.viewId}</code><StatusPill tone={item.tone}>{item.status}</StatusPill></button>)}
                </div>
                {visibleChartPreviews.length === 0 && <div className="catalog-empty"><strong>没有符合条件的登记项</strong><p>清除搜索词或切换状态筛选。完整 146 项会按 M6—M24 的能力门禁逐步登记。</p></div>}
                <div className="catalog-note"><strong>目录不是计算按钮集合</strong><p>点击“需追加计算”会带着目标 view_id 返回分析构建器，补齐依赖并重新预检；不会在后台静默计算。</p></div>
              </div>
            </div>
          </section>
        )}

        {view === "reports" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">REPORT ENGINE</span><h1>报告从证据生成，不从AI生成</h1><p>同一份 ReportDocument 可以切换三种密度。正式解释必须有 ReportRulePack，缺失时只输出技术记录或结构化 Finding。</p></div><button className="primary-button" onClick={() => openAnalysis("topics")}>创建可报告的分析</button></div>
            <div className="report-layout">
              <div className="report-profile-list">{reports.map((report, index) => <button key={report[0]} className={index === 2 ? "active" : ""} disabled={index !== 2} title={index !== 2 ? `该报告类型计划在 ${report[2]} 阶段完成；当前只展示专题报告结构` : undefined}><span className="report-number">0{index + 1}</span><span><strong>{report[0]}</strong><small>{report[1]}</small></span><StatusPill tone={index === 2 ? "blue" : "amber"}>{report[2]}</StatusPill></button>)}</div>
              <article className="report-preview">
                <div className="report-toolbar"><div><StatusPill tone="violet">原型预览</StatusPill><h2>专题模型报告</h2></div><div className="density-switch">{["摘要", "标准", "完整技术版"].map((density) => <button className={reportDensity === density ? "active" : ""} onClick={() => setReportDensity(density)} key={density}>{density}</button>)}</div></div>
                <div className="report-paper"><div className="paper-meta"><span>阿斯特拉 · 虚拟示例</span><span>{reportDensity}密度</span></div><h1>现代本命结构</h1><p className="lead">这份页面展示报告的结构与证据下钻方式，不代表真实占星结论。切换密度不会重新计算，也不会改变底层 Finding。</p><h3>01 · 基线结构</h3><div className="finding"><span className="finding-index">F-01</span><div><strong>结构化 Finding 最小解释单元</strong><p>每条结论分别保存支持、压力与反证，不合并成单一“好运分”。</p><button disabled title="证据抽屉将在报告运行时完成后开放">查看 3 条证据 →</button></div><StatusPill tone="blue">Beta</StatusPill></div><h3>02 · 激活与时间</h3><div className="timeline-placeholder"><i /><i /><i /><span>开始</span><span>精确</span><span>结束</span></div><h3>03 · 限制与来源</h3><p>规则包、模板、算法卡、数据版本、时间可信度和缺失章节都随报告保存。</p></div>
                <div className="evidence-chain"><span>RawFact</span><b>→</b><span>Evidence</span><b>→</b><span>Finding</span><b>→</b><span>Conclusion</span><b>→</b><span>Section</span><b>→</b><span>Document</span></div>
              </article>
            </div>
          </section>
        )}

        {view === "data" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">CAPABILITIES & DATA</span><h1>计算、模型和数据来源一目了然</h1><p>所有计算都返回引擎、数据、规则和模型版本。免费官方数据覆盖 V1 确定性计算，专业解释与规则仍需自建和评审。</p></div><button className="secondary-button" disabled title="目录导出接口尚未进入当前阶段">导出目录 JSON</button></div>
            <div className="metric-grid"><div><strong>99</strong><span>登记计算</span><small>均有 calculation_id</small></div><div><strong>12</strong><span>基础分析模型</span><small>确定性编排</small></div><div><strong>24</strong><span>专题模型</span><small>可选产品卡</small></div><div><strong>35</strong><span>分析目的</span><small>映射到模型和Recipe</small></div><div><strong>146</strong><span>图形目录</span><small>专业V1为1—128</small></div></div>
            <div className="data-grid">
              <article className="panel model-registry"><div className="panel-title"><div><span className="eyebrow">ANALYSIS MODELS</span><h2>12 个基础模型</h2></div><StatusPill tone="green">目录有效</StatusPill></div>{baseModels.map((model, index) => <div className="registry-model" key={model[0]}><span>{String(index + 1).padStart(2, "0")}</span><div><strong>{model[1]}</strong><code>{model[0]}</code></div><StatusPill tone="blue">{model[2]}</StatusPill></div>)}</article>
              <article className="panel source-registry"><div className="panel-title"><div><span className="eyebrow">VERSIONED SOURCES</span><h2>数据来源与用途</h2></div></div>{[["Swiss Ephemeris", "主星历、宫位与天体位置", "AGPL 免费"], ["JPL DE/SPICE", "独立天文差异校验", "免费"], ["IANA tzdb", "历史时区与DST", "免费"], ["GeoNames", "地名、经纬度与时区ID", "CC BY"], ["Natural Earth", "全球底图与静态导出", "公有领域"], ["MPC / Gaia / IERS", "小行星、恒星与地球定向", "免费/署名"]].map((source) => <div className="source-row" key={source[0]}><span className="source-dot" /><div><strong>{source[0]}</strong><small>{source[1]}</small></div><em>{source[2]}</em></div>)}<div className="source-warning"><strong>明确缺口</strong><p>1970年前部分历史时区、精确公众人物出生时间、商业中文解释文本、行业统一主题权重和真实事件验证集不能由免费数据自动解决。</p></div></article>
            </div>
          </section>
        )}
      </section>

      {analysisOpen && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setAnalysisOpen(false); }}>
          <section className="analysis-modal" role="dialog" aria-modal="true" aria-labelledby="analysis-title">
            <header className="modal-header">
              <div><span className="eyebrow">UNIFIED ANALYSIS CENTER · {entryPointId}</span><h1 id="analysis-title">{activeEntry.title}</h1><p>选择内容 → 对象与上下文 → 模型与参数 → 输出 → 预检</p></div>
              <button className="modal-close" onClick={() => setAnalysisOpen(false)} aria-label="关闭分析中心">×</button>
            </header>
            <div className="stepper">{["选择内容", "对象与输入", "模型与参数", "图表与报告", "预检并运行"].map((label, index) => <button key={label} className={builderStep === index + 1 ? "active" : builderStep > index + 1 ? "done" : ""} disabled={index + 1 > builderStep} onClick={() => setBuilderStep((index + 1) as BuilderStep)}><span>{builderStep > index + 1 ? "✓" : index + 1}</span>{label}</button>)}</div>

            <div className="entry-context" role="status">
              <span>{activeEntry.symbol}</span>
              <div><strong>{activeEntry.title}</strong><p>{activeEntry.context}</p></div>
              <code>{entryPointId}</code>
            </div>

            <div className="modal-body">
              {builderStep === 1 && <div className="catalog-selector">
                <div className="catalog-tabs"><button className={catalogTab === "techniques" ? "active" : ""} onClick={() => changeCatalogTab("techniques")}>计算技法 <b>99项底层</b></button><button className={catalogTab === "topics" ? "active" : ""} onClick={() => changeCatalogTab("topics")}>专题模型 <b>24</b></button><button className={catalogTab === "intents" ? "active" : ""} onClick={() => changeCatalogTab("intents")}>分析目的 <b>35</b></button></div>
                <label className="catalog-search">⌕<input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="搜索名称、ID、领域或技法…" /></label>
                <div className="catalog-list">{catalogItems.map((item) => <button key={item[0]} className={selectedItem === item[0] ? "selected" : ""} onClick={() => chooseCatalogItem(item[0])}><span className="catalog-item-icon">{catalogTab === "techniques" ? "◫" : catalogTab === "topics" ? "◇" : "◎"}</span><span><strong>{item[1]}</strong><code>{item[0]}</code></span><span className="catalog-meta">{item[2]}<small>{item[3]}</small></span><i>{selectedItem === item[0] ? "✓" : "→"}</i></button>)}</div>
              </div>}

              {builderStep === 2 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">SUBJECT ROLES</span><h2>这次要分析谁或什么？</h2><p>你不是在单纯新增人物；对象资料会和本次分析内容一起进入 Recipe。M4 纵向切片只允许虚拟示例，真实对象录入在 M5—M6 接通后开放。</p></div><div className="entry-requirements"><strong>{activeEntry.title}需要</strong>{entryRequirements[entryPointId].map((requirement) => <span key={requirement}>✓ {requirement}</span>)}</div><div className="choice-row"><button className={subjectMode === "sample" ? "active" : ""} onClick={() => setSubjectMode("sample")}><span className="subject-avatar small">A</span><strong>使用虚拟示例</strong><small>已有缓存本命，可复用部分结果</small></button><button disabled title="真实对象输入、地点解析和 SubjectVersion 持久化将在 M5—M6 接通"><span className="subject-avatar small empty">＋</span><strong>新增真实对象</strong><small>M5—M6：人物、关系、项目、事件、组织或问题</small></button></div></div>}

              {builderStep === 3 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">RESOLVED SELECTION</span><h2>确认所选内容与允许参数</h2><p>技法、专题和目的会解析为不同的确定性组件；最终锁定内容以服务端 Recipe 预检为准。</p></div><div className="resolved-model"><div className="resolved-head"><span className="model-mark">{catalogTab === "techniques" ? "T" : catalogTab === "topics" ? "M" : "I"}</span><div><strong>{selectedCatalogItem?.[1] ?? selectedItem}</strong><code>{selectedItem} · {entryPointId}</code></div><StatusPill tone="amber">{selectedCatalogItem?.[3] ?? "待预检"}</StatusPill></div><div className="component-flow"><span>入口上下文</span><b>→</b><span>对象与时间</span><b>→</b><span>目录选择</span><b>→</b><span>服务端依赖DAG</span><b>→</b><span>不可变Recipe</span></div></div><div className="parameter-grid read-only" aria-label="当前参数只读"><label>官方预设<select disabled><option>official.modern_natal.v1</option></select></label><label>黄道<select disabled><option>回归黄道 Tropical</option></select></label><label>宫位制<select disabled><option>Placidus</option></select></label><label>相位集<select disabled><option>主要相位</option></select></label></div><div className="locked-note"><span>锁</span><p><strong>M4 参数来自服务端默认规则包</strong>：参数可编辑契约在 M5 接通；在此之前不提供只改界面、不改 Recipe 的假控件。</p></div></div>}

              {builderStep === 4 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">OUTPUT MANIFEST</span><h2>本次输出清单</h2><p>M4 由服务端注册项决定输出，当前清单只读；M5 接通输出选择契约后，勾选变化才会真实改变 Recipe 节点。</p></div><div className="output-columns read-only"><div><h3>主输出 · 服务端锁定</h3>{["本命盘轮盘", "行星位置表", "相位网格", "计算记录报告"].map((item) => <label className="check-row" key={item}><input type="checkbox" defaultChecked disabled /><span>{item}</span><StatusPill tone="green">锁定</StatusPill></label>)}</div><div><h3>推荐输出 · M5开放</h3>{["元素与模式", "格局表", "主导行星", "SVG / PNG 导出"].map((item) => <label className="check-row" key={item}><input type="checkbox" disabled /><span>{item}</span><StatusPill tone="blue">M5</StatusPill></label>)}</div><div><h3>可选扩展 · 按能力阶段</h3>{["古典尊贵", "固定星接触", "未来一年行运", "专题模型报告"].map((item) => <label className="check-row" key={item}><input type="checkbox" disabled /><span>{item}</span><StatusPill tone="amber">后续</StatusPill></label>)}</div></div><div className="output-total"><span>当前服务端计划</span><strong>以预检返回的 output manifest 为准</strong><em>不会生成目录中其余图表</em></div></div>}

              {builderStep === 5 && <div className="preflight"><div className="builder-copy"><span className="eyebrow">PREFLIGHT PLAN</span><h2>确认后才开始计算</h2><p>这里显示 API 返回的真实依赖、输入缺口、输出和资源预算。没有成功生成 Recipe 时不会启动任务。</p></div><PreflightPlan status={preflightStatus} error={preflightError} recipe={resolvedRecipe} entryPointId={entryPointId} selectedItem={selectedItem} /></div>}
            </div>

            <footer className="modal-footer"><button className="secondary-button" onClick={() => builderStep === 1 ? setAnalysisOpen(false) : setBuilderStep((builderStep - 1) as BuilderStep)}>{builderStep === 1 ? "取消" : "上一步"}</button><div><span>{builderStep} / 5</span>{builderStep < 4 ? <button className="primary-button" onClick={() => setBuilderStep((builderStep + 1) as BuilderStep)}>继续</button> : builderStep === 4 ? <button className="primary-button" onClick={resolvePreflight}>生成真实预检</button> : <button className={`primary-button ${running ? "loading" : ""}`} onClick={runAnalysis} disabled={running || preflightStatus !== "ready" || !resolvedRecipe}>{running ? "正在运行…" : preflightStatus === "resolving" ? "正在预检…" : "确认 Recipe 并运行"}</button>}</div></footer>
          </section>
        </div>
      )}
    </main>
  );
}
