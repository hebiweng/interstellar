import type { InterpretationTarget, ItemInterpretation, NatalSnapshot } from "../../lib/interstellar-api";
import {
  houseDomains,
  patternNames,
  pointFunctions,
  pointNames,
  signNames,
  signStyles,
} from "./chart-constants";
import { aspectPhaseLabel } from "./chart-labels";
import { isDateLevelSnapshot } from "./chart-utils";

export function buildLocalInterpretation(target: InterpretationTarget, snapshot: NatalSnapshot): ItemInterpretation {
  const fixtureLayer = (
    itemKind: string,
    label: string,
    status: "published" | "unavailable" | "not_applicable" | "blocked_by_input_quality",
    fact: Record<string, unknown>,
    meaning?: string,
    unavailableReason?: string,
  ): NonNullable<ItemInterpretation["layers"]>[number] => ({
    item_kind: itemKind,
    label,
    status,
    fact,
    meaning,
    unavailable_reason: unavailableReason,
    warnings: [],
    content_hash: `reference-fixture:${snapshot.input_fingerprint}:${target.id}:${itemKind}`,
    rule_ref: `reference_fixture.${itemKind}.v1`,
    template_version: "1.0.0",
    maturity: "Reference fixture",
    source_refs: ["internal.authored.natal-reference-fixture.v1"],
  });
  if (target.type === "point") {
    const point = snapshot.result.points.find((item) => item.point_id === target.id);
    if (!point) return { status: "unavailable", unavailable_reason: "未找到对应点位事实。" };
    const fn = pointFunctions[point.point_id] ?? "此点位的专门解释模板尚未发布";
    const style = signStyles[point.sign] ?? "该星座的表达方式";
    const dateLevel = isDateLevelSnapshot(snapshot);
    const domain = point.house ? houseDomains[point.house - 1] : "宫位未计算（需要可靠出生时刻）";
    const pointLabel = pointNames[point.point_id] ?? point.point_id;
    const signLabel = signNames[point.sign] ?? point.sign;
    const pointFact = {
      point_id: point.point_id,
      sign_id: point.sign,
      degree_in_sign: point.degree_in_sign,
      house: point.house,
      motion_state: point.position.motion_state,
      retrograde: point.retrograde,
    };
    const intrinsicPublished = Boolean(pointFunctions[point.point_id]);
    const signPublished = Boolean(signStyles[point.sign]) && intrinsicPublished;
    const layers: NonNullable<ItemInterpretation["layers"]> = [
      fixtureLayer(
        "point_intrinsic",
        "星体自身功能",
        intrinsicPublished ? "published" : "unavailable",
        pointFact,
        intrinsicPublished ? `${pointLabel}：${fn}。` : undefined,
        intrinsicPublished ? undefined : "POINT_INTRINSIC_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "point_in_sign",
        "星座表达方式",
        signPublished ? "published" : "unavailable",
        pointFact,
        signPublished ? `${pointLabel}落在${signLabel}：这项功能倾向${style}。` : undefined,
        signPublished ? undefined : "POINT_OR_SIGN_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "point_in_house",
        "所在宫位领域",
        dateLevel || point.house == null ? "blocked_by_input_quality" : intrinsicPublished ? "published" : "unavailable",
        pointFact,
        !dateLevel && point.house != null && intrinsicPublished
          ? `${pointLabel}落在第${point.house}宫：这项功能主要通过${domain}被体验和表达。`
          : undefined,
        dateLevel || point.house == null ? "MISSING_HOUSE_ASSIGNMENT" : intrinsicPublished ? undefined : "POINT_INTRINSIC_RULE_UNAVAILABLE",
      ),
      fixtureLayer(
        "motion",
        "运动状态",
        point.motion_interpretation === "not_applicable" ? "not_applicable" : "published",
        pointFact,
        point.motion_interpretation === "not_applicable"
          ? undefined
          : `${pointLabel}${point.retrograde ? "逆行" : "顺行"}；这是运动状态，不单独表示吉凶。`,
        point.motion_interpretation === "not_applicable" ? "MOTION_INTERPRETATION_NOT_APPLICABLE" : undefined,
      ),
    ];
    return {
      status: "available", title: `${pointNames[point.point_id] ?? point.point_id} · ${signNames[point.sign] ?? point.sign}${point.house ? ` · 第${point.house}宫` : ""}`,
      facts: target.facts ?? [target.fact, `运动状态：${point.retrograde === true ? "逆行" : point.motion_interpretation === "not_applicable" ? "不适用" : "顺行"}`],
      meaning: dateLevel
        ? `${fn}。日期范围内的参考位置落在${signNames[point.sign] ?? point.sign}，可用"${style}"作为星座层阅读；这不是伪造的出生时刻。`
        : `${fn}，通过"${style}"的方式表达，主要落在"${domain}"这一生活领域。`,
      synthesis: dateLevel
        ? "出生时刻未知，因此不生成上升、宫位、相位、阿拉伯点、昼夜体系或其他时刻依赖结论；若该点在日期内跨星座或改变运动状态，必须同时阅读不确定范围。"
        : "这是结构化单项解释，不替代整盘综合；相位、宫主星、尊贵与重复主题可能强化、修正或抵消这条倾向。",
      rule_refs: ["reporting.contextual_item_interpretation.v1", "natal.point_sign_house.composition.v1"],
      source_refs: ["internal.authored.natal-basic-template.v1"], template_version: "1.0.0", maturity: "Beta",
      content_hash: layers.map((layer) => layer.content_hash).join(" · "),
      layers,
    };
  }
  if (target.type === "house") {
    const house = snapshot.result.houses.find((item) => String(item.number) === target.id);
    const houseMeaning = house
      ? `第${house.number}宫对应"${houseDomains[house.number - 1]}"。宫头落在${signNames[house.sign] ?? house.sign}，表示这个领域倾向以"${signStyles[house.sign] ?? "对应星座"}"的方式启动。`
      : undefined;
    return house ? {
      status: "available", title: `第${house.number}宫 · ${signNames[house.sign] ?? house.sign}`,
      facts: [target.fact, `宫内点位：${house.point_ids.map((id) => pointNames[id] ?? id).join("、") || "无"}`],
      meaning: houseMeaning,
      synthesis: "完整判断还需要宫主星落座、落宫、相位、宫内天体和宫位制共同参与。",
      rule_refs: ["natal.house.cusp_ruler.v1"], source_refs: ["internal.authored.house-domain.v1"], template_version: "1.0.0", maturity: "Beta",
      layers: [fixtureLayer("house_cusp_ruler", "宫头与宫主链", "published", house as unknown as Record<string, unknown>, houseMeaning)],
    } : { status: "unavailable", unavailable_reason: "未找到宫位事实。" };
  }
  if (target.type === "aspect") {
    const aspect = snapshot.result.aspects.find((item) => item.aspect_id === target.id);
    if (!aspect) return { status: "unavailable", unavailable_reason: "未找到相位事实。" };
    const interaction: Record<string, string> = {
      conjunction: "两种功能紧密融合并彼此放大", opposition: "两端形成拉扯，需要在关系或情境中寻找平衡", square: "两种功能形成摩擦并推动行动",
      trine: "两种功能较自然地互相支持", sextile: "两种功能存在可被主动使用的协作机会", quincunx: "两种功能需要持续调整",
    };
    const aspectMeaning = `${pointNames[aspect.point_a] ?? aspect.point_a}与${pointNames[aspect.point_b] ?? aspect.point_b}${interaction[aspect.type] ?? "形成一种需要结合具体定义阅读的关系"}。`;
    const phase = aspectPhaseLabel(aspect.applying_state);
    return {
      status: "available", title: target.title, facts: [target.fact, ...(phase ? [`阶段：${phase}`] : []), `强度：${Math.round(aspect.strength * 100)}%`],
      meaning: aspectMeaning,
      synthesis: "容许度越小通常越接近精确；入相/出相只在两点运动语义都明确时判断。次要相位不应压过太阳、月亮、四轴和紧密主要相位。",
      rule_refs: aspect.rule_refs ?? ["official.aspects.professional_natal.v1"], source_refs: ["internal.authored.aspect-template.v1"], template_version: "1.0.0", maturity: "Beta",
      layers: [fixtureLayer("natal_aspect", "相位互动", "published", aspect as unknown as Record<string, unknown>, aspectMeaning)],
    };
  }
  return {
    status: "unavailable", title: target.title, facts: [target.fact],
    unavailable_reason: "REFERENCE_FIXTURE_SEMANTIC_RULE_UNAVAILABLE",
    synthesis: "请与点位、宫位、相位以及其他同向或反向证据一起阅读。",
    rule_refs: [target.type === "classical" ? "ALG-NATAL-004" : "ALG-NATAL-003"],
    source_refs: ["interstellar.versioned-rule-pack"], template_version: "1.0.0", maturity: "Experimental",
    layers: [fixtureLayer(
      target.type === "classical" ? "classical_condition" : "structure_indicator",
      target.type === "classical" ? "古典条件" : "盘面结构",
      "unavailable",
      { reference_fact: target.fact },
      undefined,
      "REFERENCE_FIXTURE_SEMANTIC_RULE_UNAVAILABLE",
    )],
  };
}

void patternNames;
