"""Deterministic, complete technical natal document projection.

This export is designed for professional review, archival copy/paste, and
optional downstream AI analysis.  It contains calculated facts and provenance;
it never asks a language model to recalculate the chart.
"""

from __future__ import annotations

import json
import math
from collections.abc import Mapping
from typing import Any, Literal


class NatalTechnicalExportError(ValueError):
    pass


POINT_LABELS_ZH = {
    "sun": "太阳",
    "moon": "月亮",
    "mercury": "水星",
    "venus": "金星",
    "mars": "火星",
    "jupiter": "木星",
    "saturn": "土星",
    "uranus": "天王星",
    "neptune": "海王星",
    "pluto": "冥王星",
    "asc": "上升点",
    "dsc": "下降点",
    "mc": "天顶",
    "ic": "天底",
    "vertex": "宿命点",
    "anti_vertex": "反宿命点",
    "east_point": "东方点",
    "west_point": "西方点",
    "true_north_node": "真北交点",
    "true_south_node": "真南交点",
    "mean_north_node": "平北交点",
    "mean_south_node": "平南交点",
    "mean_lilith": "平黑月莉莉丝",
    "true_lilith": "真黑月莉莉丝",
    "lunar_perigee": "月球近地点",
    "chiron": "凯龙星",
    "ceres": "谷神星",
    "pallas": "智神星",
    "juno": "婚神星",
    "vesta": "灶神星",
    "fortune": "福点",
    "spirit": "精神点",
}

SIGN_LABELS_ZH = {
    "aries": "白羊座",
    "taurus": "金牛座",
    "gemini": "双子座",
    "cancer": "巨蟹座",
    "leo": "狮子座",
    "virgo": "处女座",
    "libra": "天秤座",
    "scorpio": "天蝎座",
    "sagittarius": "射手座",
    "capricorn": "摩羯座",
    "aquarius": "水瓶座",
    "pisces": "双鱼座",
}

ASPECT_LABELS_ZH = {
    "conjunction": "合相",
    "semiduodecile": "半十二分相",
    "semioctile": "半八分相",
    "semisextile": "半六分相",
    "undecile": "十一分相",
    "decile": "十分相",
    "novile": "九分相",
    "semisquare": "半刑相",
    "septile": "七分相",
    "sextile": "六分相",
    "quintile": "五分相",
    "square": "四分相",
    "biseptile": "双七分相",
    "trine": "三分相",
    "sesquisquare": "拱半相",
    "biquintile": "双五分相",
    "quincunx": "梅花相",
    "triseptile": "三七分相",
    "opposition": "对冲相",
}


def _nested(document: Mapping[str, Any], *path: str) -> Any:
    value: Any = document
    for key in path:
        if not isinstance(value, Mapping) or key not in value:
            return None
        value = value[key]
    return value


def _number(value: Any, digits: int = 6) -> str:
    if value is None:
        return "不适用/未计算"
    numeric = float(value)
    if not math.isfinite(numeric):
        return "非有限值"
    return f"{numeric:.{digits}f}"


def _degree(value: Any) -> str:
    if value is None:
        return "不适用/未计算"
    total_seconds = round((float(value) % 360) * 3600)
    degrees, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{degrees}°{minutes:02d}′{seconds:02d}″"


def _signed_degree(value: Any) -> str:
    """Format latitude/declination without wrapping negative values to 0–360°."""
    if value is None:
        return "不适用/未计算"
    numeric = float(value)
    if not math.isfinite(numeric):
        return "非有限值"
    sign = "−" if numeric < 0 else "+"
    total_seconds = round(abs(numeric) * 3600)
    degrees, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{sign}{degrees}°{minutes:02d}′{seconds:02d}″"


def _label_point(point_id: str) -> str:
    return f"{POINT_LABELS_ZH.get(point_id, point_id)} ({point_id})"


def _label_sign(sign_id: Any) -> str:
    key = str(sign_id)
    return f"{SIGN_LABELS_ZH.get(key, key)} ({key})"


def _section(lines: list[str], title: str, *, markdown: bool) -> None:
    lines.extend(("", f"## {title}" if markdown else f"=== {title} ==="))


def _bullet(lines: list[str], text: str) -> None:
    lines.append(f"- {text}")


def _subject_name(snapshot: Mapping[str, Any]) -> str:
    subject = _nested(snapshot, "normalized_input", "subject_version") or {}
    return str(subject.get("display_name") or subject.get("id") or "未命名对象")


def render_natal_technical_document(
    snapshot: Mapping[str, Any],
    *,
    output_format: Literal["markdown", "plaintext"] = "markdown",
) -> str:
    result = snapshot.get("result")
    if not isinstance(result, Mapping) or not result.get("charts"):
        raise NatalTechnicalExportError("snapshot has no generated natal chart")
    chart = result["charts"][0]
    if not isinstance(chart, Mapping) or chart.get("family") != "natal":
        raise NatalTechnicalExportError("technical natal export requires a natal chart")
    markdown = output_format == "markdown"
    lines: list[str] = [
        "# Interstellar 本命盘专业技术推演" if markdown else "【Interstellar 本命盘专业技术推演】",
        "",
        (
            "说明：本文档由确定性星历与规则引擎生成，可复制给外部模型分析；"
            "AI 不参与星历、宫位或相位计算。"
        ),
    ]

    subject = _nested(snapshot, "normalized_input", "subject_version") or {}
    time_spec = subject.get("time_spec") or chart.get("time_spec") or {}
    location = subject.get("location") or chart.get("location") or {}
    context = result.get("astronomical_context") or {}
    settings = chart.get("settings") or {}
    source_text = json.dumps(
        {"time": time_spec.get("source"), "location": location.get("source")},
        ensure_ascii=False,
        sort_keys=True,
    )
    _section(lines, "对象、时间与地点", markdown=markdown)
    for value in (
        f"对象：{_subject_name(snapshot)}",
        f"原始当地时间：{time_spec.get('local_value') or '未提供'}",
        (
            f"时间精度：{time_spec.get('precision') or '未提供'}；"
            f"可信度：{time_spec.get('confidence') or '未提供'}"
        ),
        f"IANA 时区：{time_spec.get('timezone_id') or location.get('timezone_id') or '未提供'}",
        f"选定 UTC：{time_spec.get('selected_utc') or context.get('utc') or '未解析'}",
        (
            f"地点：{location.get('name') or '未命名'}；"
            f"经纬度：{_number(location.get('longitude'))}, "
            f"{_number(location.get('latitude'))}"
        ),
        f"地点与时间来源：{source_text}",
    ):
        _bullet(lines, value)

    _section(lines, "计算设置", markdown=markdown)
    for key, label in (
        ("calculation_profile_id", "计算配置"),
        ("analysis_system_id", "分析体系"),
        ("zodiac", "黄道"),
        ("ayanamsa", "岁差系统"),
        ("house_system", "宫制"),
        ("center", "中心"),
        ("coordinate_frame", "坐标"),
        ("node_type", "交点类型"),
        ("aspect_set_id", "相位集合"),
        ("orb_profile_id", "容许度配置"),
    ):
        _bullet(lines, f"{label}：{settings.get(key) or '未设置'}")
    _bullet(lines, f"点位集合：{', '.join(settings.get('included_points') or []) or '由配置决定'}")
    _bullet(
        lines, f"相位筛选：{', '.join(settings.get('included_aspect_ids') or []) or '所选集合全部'}"
    )
    orb_overrides = json.dumps(
        settings.get("orb_overrides") or [], ensure_ascii=False, sort_keys=True
    )
    _bullet(lines, f"容许度覆盖：{orb_overrides}")

    _section(lines, "天文计算上下文", markdown=markdown)
    for value in (
        f"儒略日 UT：{_number(context.get('julian_day_ut'), 9)}",
        f"儒略日 TT：{_number(context.get('julian_day_tt'), 9)}",
        f"Delta-T：{_number(context.get('delta_t_seconds'), 3)} 秒",
        f"格林尼治恒星时：{_degree(context.get('greenwich_sidereal_time_deg'))}",
        f"地方恒星时：{_degree(context.get('local_sidereal_time_deg'))}",
        f"真黄赤交角：{_degree(context.get('obliquity_deg'))}",
        (
            f"昼夜状态：{context.get('day_night_status') or '未判定'}；"
            f"太阳高度：{_number(context.get('sun_altitude_deg'), 4)}°"
        ),
        (
            f"日出/日落：{context.get('sunrise_utc') or '当前未计算'} / "
            f"{context.get('sunset_utc') or '当前未计算'}"
        ),
    ):
        _bullet(lines, value)

    _section(lines, "星座索引", markdown=markdown)
    _bullet(
        lines,
        ", ".join(
            f"{index}:{SIGN_LABELS_ZH[sign]}({sign})"
            for index, sign in enumerate(SIGN_LABELS_ZH, start=1)
        ),
    )

    _section(lines, "完整点位", markdown=markdown)
    for point in result.get("points") or []:
        velocity = _nested(point, "position", "velocity") or {}
        ecliptic = _nested(point, "position", "ecliptic") or {}
        equatorial = _nested(point, "position", "equatorial") or {}
        flags = []
        if point.get("retrograde"):
            flags.append("逆行")
        if _nested(point, "position", "motion_state") == "stationary":
            flags.append("停滞")
        if point.get("out_of_bounds"):
            flags.append("越界")
        if point.get("solar_relation") not in {None, "free", "not_applicable"}:
            flags.append(str(point["solar_relation"]))
        longitude_text = _degree(ecliptic.get("longitude_deg"))
        latitude_text = _signed_degree(ecliptic.get("latitude_deg"))
        ra_text = _degree(equatorial.get("right_ascension_deg"))
        declination_text = _signed_degree(equatorial.get("declination_deg"))
        previous_cusp_text = _degree(point.get("distance_from_previous_cusp_deg"))
        next_cusp_text = _degree(point.get("distance_to_next_cusp_deg"))
        object_ref = point.get("formula_ref") or point.get("catalog_object_ref") or "星历直算"
        _bullet(
            lines,
            (
                f"{_label_point(str(point['point_id']))}：{_label_sign(point.get('sign'))} "
                f"{_degree(point.get('degree_in_sign'))}；第{point.get('house') or '—'}宫；"
                f"黄经 {longitude_text}，黄纬 {latitude_text}；"
                f"赤经 {ra_text}，赤纬 {declination_text}；"
                f"日运动 {_number(velocity.get('longitude_deg_per_day'), 8)}°/日；"
                f"运动 {(_nested(point, 'position', 'motion_state') or '未判定')}；"
                f"距前宫头 {previous_cusp_text}，距后宫头 {next_cusp_text}；"
                f"太阳角距 {_degree(point.get('solar_elongation_deg'))}；"
                f"状态 {','.join(flags) or '无附加状态'}；公式/目录 {object_ref}"
            ),
        )

    _section(lines, "十二宫", markdown=markdown)
    for house in result.get("houses") or []:
        _bullet(
            lines,
            (
                f"第{house.get('number')}宫：宫头 {_label_sign(house.get('sign'))} "
                f"{_degree(house.get('degree_in_sign'))}；跨度 {_degree(house.get('span_deg'))}；"
                f"传统宫主 {','.join(house.get('traditional_ruler_ids') or []) or '—'}；"
                f"现代宫主 {','.join(house.get('modern_ruler_ids') or []) or '—'}；"
                f"宫内点 {','.join(house.get('point_ids') or []) or '无'}；"
                f"截夺 {','.join(house.get('intercepted_signs') or []) or '无'}"
            ),
        )

    _section(lines, "完整相位", markdown=markdown)
    for aspect in result.get("aspects") or []:
        aspect_angle = _degree(aspect.get("actual_angle_deg"))
        orb_ratio = _number(aspect.get("orb_ratio"), 4)
        _bullet(
            lines,
            (
                f"{_label_point(str(aspect.get('point_a')))} "
                f"{ASPECT_LABELS_ZH.get(str(aspect.get('type')), aspect.get('type'))} "
                f"{_label_point(str(aspect.get('point_b')))}；实际夹角 {aspect_angle}；"
                f"容许 {_degree(aspect.get('orb_deg'))}；容许度比例 {orb_ratio}；"
                f"{aspect.get('applying_state')}；强度 {_number(aspect.get('strength'), 4)}"
            ),
        )

    _section(lines, "分布与盘面结构", markdown=markdown)
    for distribution in result.get("distributions") or []:
        categories = ", ".join(
            f"{item.get('category_id')}={_number(item.get('percentage'), 2)}%"
            for item in distribution.get("categories") or []
        )
        _bullet(lines, f"{distribution.get('dimension')}：{categories or '不可用'}")
    structure = result.get("structure") or {}
    _bullet(lines, f"结构可用性：{structure.get('availability') or '未计算'}")
    for pattern in result.get("patterns") or []:
        pattern_type = pattern.get("pattern_type") or pattern.get("kind")
        participant_ids = ",".join(pattern.get("participant_ids") or [])
        _bullet(
            lines,
            f"格局 {pattern_type}：{participant_ids}",
        )
    jones_shape = json.dumps(structure.get("jones_shape"), ensure_ascii=False, sort_keys=True)
    _bullet(
        lines,
        f"Jones 盘型：{jones_shape}",
    )

    _section(lines, "古典与希腊化事实", markdown=markdown)
    classical = result.get("classical") or {}
    _bullet(lines, f"可用性：{classical.get('availability') or '未计算'}")
    _bullet(
        lines,
        f"昼夜与 Sect：{json.dumps(classical.get('sect'), ensure_ascii=False, sort_keys=True)}",
    )
    for dignity in result.get("dignities") or []:
        active = [item.get("kind") for item in dignity.get("dignities") or []]
        debilities = [item.get("kind") for item in dignity.get("debilities") or []]
        dignity_label = _label_point(str(dignity.get("point_id")))
        _bullet(
            lines,
            (
                f"{dignity_label}：尊贵 {','.join(active) or '无'}；"
                f"失势/落陷 {','.join(debilities) or '无'}；"
                f"游走 {dignity.get('peregrine')}"
            ),
        )
    _bullet(
        lines,
        f"定位星链：{json.dumps(classical.get('dispositors'), ensure_ascii=False, sort_keys=True)}",
    )
    _bullet(
        lines,
        f"接纳：{json.dumps(classical.get('receptions'), ensure_ascii=False, sort_keys=True)}",
    )
    for lot in result.get("lots") or []:
        lot_label = _label_point(str(lot.get("lot_id")))
        lot_sign = _label_sign(lot.get("sign_id"))
        _bullet(
            lines,
            (
                f"{lot_label}：{lot_sign} {_degree(lot.get('degree_in_sign'))}；"
                f"公式 {lot.get('formula_expression')} ({lot.get('formula_id')})"
            ),
        )

    _section(lines, "警告、版本与复现信息", markdown=markdown)
    for warning in snapshot.get("warnings") or []:
        _bullet(lines, f"{warning.get('code')}：{warning.get('message')}")
    _bullet(lines, f"快照 ID：{snapshot.get('id')}")
    _bullet(lines, f"输入指纹：{snapshot.get('input_fingerprint')}")
    _bullet(
        lines, f"引擎：{json.dumps(snapshot.get('engine'), ensure_ascii=False, sort_keys=True)}"
    )
    _bullet(
        lines, f"数据集：{json.dumps(snapshot.get('datasets'), ensure_ascii=False, sort_keys=True)}"
    )
    _bullet(lines, f"Rule Pack：{snapshot.get('rule_pack_hash')}")
    _bullet(lines, f"成熟度：{snapshot.get('maturity')}；状态：{snapshot.get('status')}")
    _bullet(
        lines, "解释边界：本文档是技术事实，不提供确定性事件概率、医疗/法律/投资结论或寿命判断。"
    )
    return "\n".join(lines).strip() + "\n"
