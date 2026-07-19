"""Deterministic, user-facing natal analysis document projection.

This export is designed for professional review, copy/paste, and optional
downstream AI analysis. It contains analysis-ready calculated facts, but not
developer manifests, evidence payloads, internal graph structures, or raw
engine objects. The complete immutable snapshot remains available separately
as JSON for audit and reproducibility.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Mapping
from typing import Any, Literal


class NatalTechnicalExportError(ValueError):
    pass


TECHNICAL_DOCUMENT_SCHEMA = "interstellar.natal.analysis-document.v2"


def natal_technical_document_content_hash(snapshot: Mapping[str, Any]) -> str:
    """Hash the immutable semantic payload shared by every text representation.

    Markdown and plaintext are presentation formats of one technical document,
    rather than independently assembled reports.  Snapshot identity and
    creation timestamps are deliberately excluded: the digest describes the
    normalized inputs, settings, materialized facts, warnings, and provenance.
    """

    result = snapshot.get("result")
    if not isinstance(result, Mapping) or not result.get("charts"):
        raise NatalTechnicalExportError("snapshot has no generated natal chart")
    chart = result["charts"][0]
    if not isinstance(chart, Mapping) or chart.get("family") != "natal":
        raise NatalTechnicalExportError("technical natal export requires a natal chart")
    chart_settings = chart.get("settings") if isinstance(chart.get("settings"), Mapping) else {}
    classical = result.get("classical") if isinstance(result.get("classical"), Mapping) else {}
    semantic_payload = {
        "schema": TECHNICAL_DOCUMENT_SCHEMA,
        "input_fingerprint": snapshot.get("input_fingerprint"),
        "normalized_input": snapshot.get("normalized_input"),
        "chart": {
            "family": chart.get("family"),
            "technique": chart.get("technique"),
            "settings": chart_settings,
        },
        "analysis_facts": {
            "astronomical_context": result.get("astronomical_context"),
            "points": result.get("points"),
            "houses": result.get("houses"),
            "aspects": result.get("aspects"),
            "distributions": result.get("distributions"),
            "structure": result.get("structure"),
            "patterns": result.get("patterns"),
            "classical": {
                "availability": classical.get("availability"),
                "sect": classical.get("sect"),
            },
            "dignities": result.get("dignities"),
            "receptions": result.get("receptions"),
            "lots": result.get("lots"),
        },
        "warnings": snapshot.get("warnings") or [],
    }
    encoded = json.dumps(
        semantic_payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


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
    "lot_eros": "爱神点",
    "lot_necessity": "必然点",
    "lot_courage": "勇气点",
    "lot_victory": "胜利点",
    "lot_nemesis": "复仇点",
    "lot_exaltation": "擢升点",
    "cupido": "丘比特",
    "hades": "哈得斯",
    "zeus": "宙斯",
    "kronos": "克洛诺斯",
    "apollon": "阿波罗",
    "admetos": "阿得门图斯",
    "vulkanus": "弗卡奴斯",
    "poseidon": "波塞冬",
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

SETTING_LABELS_ZH = {
    "modern_natal_v1": "现代本命",
    "classical_natal_v1": "古典本命",
    "professional_natal_v1": "专业综合本命",
    "integrated": "专业综合本命",
    "modern": "现代本命",
    "classical": "古典本命",
    "tropical": "回归黄道",
    "sidereal": "恒星黄道",
    "geocentric": "地心",
    "heliocentric": "日心",
    "topocentric": "拓扑中心",
    "ecliptic": "黄道坐标",
    "equatorial": "赤道坐标",
    "horizontal": "地平坐标",
    "true": "真交点",
    "mean": "平均交点",
    "both": "真／平均交点",
    "placidus": "Placidus 普拉西德宫制",
    "whole_sign": "Whole Sign 整宫制",
    "koch": "Koch 柯赫宫制",
    "porphyry": "Porphyry 波菲利宫制",
    "regiomontanus": "Regiomontanus 宫制",
    "campanus": "Campanus 宫制",
    "equal": "Equal 等宫制",
    "equal_mc": "Equal MC 宫制",
    "equal_aries": "Equal Aries 宫制",
    "alcabitius": "Alcabitius 宫制",
    "morinus": "Morinus 宫制",
    "krusinski": "Krusinski 宫制",
    "vehlow": "Vehlow 宫制",
    "meridian": "Meridian 子午线宫制",
    "carter_poli_equatorial": "Carter Poli-Equatorial 宫制",
    "apc": "APC 宫制",
    "pullen_sd": "Pullen SD 宫制",
    "pullen_sr": "Pullen SR 宫制",
    "sunshine_treindl": "Sunshine / Treindl 宫制",
    "sripati": "Sripati 宫制",
    "professional_natal_aspects_v1": "专业本命相位集",
    "modern_natal_orbs_v1": "现代本命容许度",
    "classical_natal_orbs_v1": "古典本命容许度",
}

MOTION_LABELS_ZH = {
    "direct": "顺行",
    "retrograde": "逆行",
    "stationary": "停滞",
    "not_applicable": "不适用",
}

SOLAR_RELATION_LABELS_ZH = {
    "cazimi": "日核",
    "combust": "燃烧",
    "under_beams": "光束下",
    "free": "不受太阳光束影响",
    "not_applicable": "不适用",
}

DIGNITY_LABELS_ZH = {
    "domicile": "入庙",
    "exaltation": "擢升",
    "triplicity": "三分性",
    "term": "界",
    "face": "面",
    "detriment": "失势",
    "fall": "落陷",
}

DISTRIBUTION_LABELS_ZH = {
    "elements": "四元素",
    "modalities": "三模式",
    "polarities": "阴阳属性",
    "fire": "火",
    "earth": "土",
    "air": "风",
    "water": "水",
    "cardinal": "基本",
    "fixed": "固定",
    "mutable": "变动",
    "positive": "阳性",
    "negative": "阴性",
}

AVAILABILITY_LABELS_ZH = {
    "available": "可用",
    "indeterminate": "条件不足",
    "unavailable": "不可用",
    "partial": "部分可用",
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
    return POINT_LABELS_ZH.get(point_id, point_id)


def _label_sign(sign_id: Any) -> str:
    key = str(sign_id)
    return SIGN_LABELS_ZH.get(key, key)


def _label_setting(value: Any) -> str:
    key = str(value or "")
    return SETTING_LABELS_ZH.get(key, key or "未设置")


def _label_availability(value: Any) -> str:
    key = str(value or "")
    return AVAILABILITY_LABELS_ZH.get(key, key or "未计算")


def _label_boolean(value: Any) -> str:
    if value is True:
        return "是"
    if value is False:
        return "否"
    return "不适用/未判定"


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
        "# Interstellar 本命盘分析数据" if markdown else "【Interstellar 本命盘分析数据】",
        "",
        (
            "说明：本文档只包含可供占星师或外部模型分析的已计算结果；"
            "AI 不参与星历、宫位或相位计算；完整 JSON 可单独导出。"
        ),
    ]

    subject = _nested(snapshot, "normalized_input", "subject_version") or {}
    time_spec = subject.get("time_spec") or chart.get("time_spec") or {}
    location = subject.get("location") or chart.get("location") or {}
    context = result.get("astronomical_context") or {}
    uncertainty = context.get("uncertainty") or {}
    date_level_mode = uncertainty.get("mode") == "civil_day_range"
    settings = chart.get("settings") or {}
    _section(lines, "对象、时间与地点", markdown=markdown)
    for value in (
        f"对象：{_subject_name(snapshot)}",
        f"原始当地时间：{time_spec.get('local_value') or '未提供'}",
        (
            f"时间精度：{time_spec.get('precision') or '未提供'}；"
            f"可信度：{time_spec.get('confidence') or '未提供'}"
        ),
        f"IANA 时区：{time_spec.get('timezone_id') or location.get('timezone_id') or '未提供'}",
        (
            "选定 UTC：未解析（出生时刻未知，未伪造）"
            if date_level_mode
            else f"选定 UTC：{time_spec.get('selected_utc') or context.get('utc') or '未解析'}"
        ),
        *(
            [
                (
                    f"日期范围 UTC：{uncertainty.get('interval_start_utc') or '未解析'} 至 "
                    f"{uncertainty.get('interval_end_utc') or '未解析'}"
                ),
                (
                    f"日期中点参考 UTC：{uncertainty.get('reference_utc') or '未解析'}；"
                    "仅用于显示参考位置，不是出生时刻"
                ),
            ]
            if date_level_mode
            else []
        ),
        (
            f"地点：{location.get('name') or '未命名'}；"
            f"经纬度：{_number(location.get('longitude'))}, "
            f"{_number(location.get('latitude'))}"
        ),
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
        _bullet(lines, f"{label}：{_label_setting(settings.get(key))}")
    included_points_text = ", ".join(
        _label_point(item) for item in settings.get("included_points") or []
    )
    _bullet(lines, f"点位集合：{included_points_text or '由配置决定'}")
    included_aspects_text = ", ".join(
        ASPECT_LABELS_ZH.get(item, item) for item in settings.get("included_aspect_ids") or []
    )
    _bullet(
        lines,
        f"相位筛选：{included_aspects_text or '所选集合全部'}",
    )
    orb_overrides = settings.get("orb_overrides") or []
    if isinstance(orb_overrides, Mapping):
        orb_text = "；".join(
            f"{ASPECT_LABELS_ZH.get(str(key), str(key))} {value}°"
            for key, value in orb_overrides.items()
        )
        _bullet(lines, f"容许度覆盖：{orb_text or '使用当前配置默认值'}")

    _section(lines, "天文计算上下文", markdown=markdown)
    if date_level_mode:
        _bullet(
            lines,
            "计算模式：完整当地民用日范围；宫位、四轴、相位、结构、Lots 与古典结果已阻断",
        )
    day_night_label = {
        "day": "昼盘",
        "night": "夜盘",
    }.get(str(context.get("day_night_status")), "未判定")
    for value in (
        f"儒略日 UT：{_number(context.get('julian_day_ut'), 9)}",
        f"儒略日 TT：{_number(context.get('julian_day_tt'), 9)}",
        f"Delta-T：{_number(context.get('delta_t_seconds'), 3)} 秒",
        f"格林尼治恒星时：{_degree(context.get('greenwich_sidereal_time_deg'))}",
        f"地方恒星时：{_degree(context.get('local_sidereal_time_deg'))}",
        f"真黄赤交角：{_degree(context.get('obliquity_deg'))}",
        f"昼夜状态：{day_night_label}；太阳高度：{_number(context.get('sun_altitude_deg'), 4)}°",
        (
            f"日出/日落：{context.get('sunrise_utc') or '当前未计算'} / "
            f"{context.get('sunset_utc') or '当前未计算'}"
        ),
    ):
        _bullet(lines, value)

    _section(lines, "星座索引", markdown=markdown)
    _bullet(
        lines,
        "，".join(
            f"{index}:{SIGN_LABELS_ZH[sign]}" for index, sign in enumerate(SIGN_LABELS_ZH, start=1)
        ),
    )

    _section(lines, "完整点位", markdown=markdown)
    point_ranges = uncertainty.get("point_ranges") or {}
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
            flags.append(
                SOLAR_RELATION_LABELS_ZH.get(
                    str(point["solar_relation"]), str(point["solar_relation"])
                )
            )
        longitude_text = _degree(ecliptic.get("longitude_deg"))
        latitude_text = _signed_degree(ecliptic.get("latitude_deg"))
        ra_text = _degree(equatorial.get("right_ascension_deg"))
        declination_text = _signed_degree(equatorial.get("declination_deg"))
        previous_cusp_text = _degree(point.get("distance_from_previous_cusp_deg"))
        next_cusp_text = _degree(point.get("distance_to_next_cusp_deg"))
        point_range = point_ranges.get(str(point.get("point_id"))) or {}
        date_range_text = ""
        if date_level_mode:
            observed_motion_states = "、".join(
                MOTION_LABELS_ZH.get(str(item), str(item))
                for item in point_range.get("motion_states_observed") or []
            )
            observed_signs = "、".join(
                _label_sign(item) for item in point_range.get("signs_observed") or []
            )
            date_range_text = (
                f"日期最大不确定度 ±{_number(point_range.get('maximum_uncertainty_deg'), 6)}°；"
                f"观察星座 {observed_signs or '未判定'}；"
                f"星座稳定 {_label_boolean(point_range.get('sign_stable'))}；"
                f"运动状态 {observed_motion_states or '未判定'}；"
                f"运动稳定 {_label_boolean(point_range.get('motion_state_stable'))}；"
            )
        motion_state = str(_nested(point, "position", "motion_state"))
        motion_label = MOTION_LABELS_ZH.get(motion_state, "未判定")
        _bullet(
            lines,
            (
                f"{_label_point(str(point['point_id']))}：{_label_sign(point.get('sign'))} "
                f"{_degree(point.get('degree_in_sign'))}；第{point.get('house') or '—'}宫；"
                f"黄经 {longitude_text}，黄纬 {latitude_text}；"
                f"赤经 {ra_text}，赤纬 {declination_text}；{date_range_text}"
                f"日运动 {_number(velocity.get('longitude_deg_per_day'), 8)}°/日；"
                f"运动 {motion_label}；"
                f"距前宫头 {previous_cusp_text}，距后宫头 {next_cusp_text}；"
                f"太阳角距 {_degree(point.get('solar_elongation_deg'))}；"
                f"状态 {','.join(flags) or '无附加状态'}"
            ),
        )

    _section(lines, "十二宫", markdown=markdown)
    if date_level_mode and not (result.get("houses") or []):
        _bullet(lines, "不可用：出生时刻未知，未以 00:00 或日期中点伪造宫位。")
    for house in result.get("houses") or []:
        traditional_rulers = "、".join(
            _label_point(item) for item in house.get("traditional_ruler_ids") or []
        )
        modern_rulers = "、".join(
            _label_point(item) for item in house.get("modern_ruler_ids") or []
        )
        house_points = "、".join(_label_point(item) for item in house.get("point_ids") or [])
        intercepted_signs = "、".join(
            _label_sign(item) for item in house.get("intercepted_signs") or []
        )
        _bullet(
            lines,
            (
                f"第{house.get('number')}宫：宫头 {_label_sign(house.get('sign'))} "
                f"{_degree(house.get('degree_in_sign'))}；跨度 {_degree(house.get('span_deg'))}；"
                f"传统宫主 {traditional_rulers or '—'}；"
                f"现代宫主 {modern_rulers or '—'}；"
                f"宫内点 {house_points or '无'}；"
                f"截夺 {intercepted_signs or '无'}"
            ),
        )

    _section(lines, "完整相位", markdown=markdown)
    if date_level_mode and not (result.get("aspects") or []):
        _bullet(lines, "不可用：日期内快速天体会移动，未以日期中点伪造本命相位。")
    for aspect in result.get("aspects") or []:
        aspect_angle = _degree(aspect.get("actual_angle_deg"))
        orb_ratio = _number(aspect.get("orb_ratio"), 4)
        phase = {
            "applying": "入相",
            "separating": "出相",
            "exact": "精确",
            "stationary": "停滞",
            "unknown": "阶段未判定",
        }.get(str(aspect.get("applying_state")))
        _bullet(
            lines,
            (
                f"{_label_point(str(aspect.get('point_a')))} "
                f"{ASPECT_LABELS_ZH.get(str(aspect.get('type')), aspect.get('type'))} "
                f"{_label_point(str(aspect.get('point_b')))}；实际夹角 {aspect_angle}；"
                f"容许 {_degree(aspect.get('orb_deg'))}；容许度比例 {orb_ratio}；"
                f"{f'阶段 {phase}；' if phase else ''}强度 {_number(aspect.get('strength'), 4)}"
            ),
        )

    _section(lines, "分布与盘面结构", markdown=markdown)
    if date_level_mode:
        _bullet(lines, "不可用：完整本命盘结构需要可靠出生时刻。")
    for distribution in result.get("distributions") or []:
        category_texts = []
        for item in distribution.get("categories") or []:
            category_id = str(item.get("category_id"))
            category_label = DISTRIBUTION_LABELS_ZH.get(category_id, category_id)
            category_texts.append(
                f"{category_label} {_number(item.get('percentage'), 2)}%"
            )
        categories = "，".join(category_texts)
        dimension = str(distribution.get("dimension"))
        dimension_label = DISTRIBUTION_LABELS_ZH.get(dimension, dimension)
        _bullet(
            lines,
            f"{dimension_label}：{categories or '不可用'}",
        )
    structure = result.get("structure") or {}
    for pattern in result.get("patterns") or []:
        pattern_type = pattern.get("pattern_type") or pattern.get("kind")
        participant_ids = "、".join(
            _label_point(item) for item in pattern.get("participant_ids") or []
        )
        _bullet(
            lines,
            f"格局 {pattern_type}：{participant_ids or '未列出参与点位'}",
        )
    jones_shape = structure.get("jones_shape") or {}
    if isinstance(jones_shape, Mapping) and jones_shape.get("shape_id"):
        _bullet(lines, f"Jones 盘型：{jones_shape.get('shape_id')}")
    elif structure and structure.get("availability") not in {None, "available"}:
        _bullet(lines, f"盘面结构：{_label_availability(structure.get('availability'))}")

    _section(lines, "古典与希腊化事实", markdown=markdown)
    if date_level_mode:
        _bullet(lines, "不可用：Sect、宫位、Lots 与时刻依赖古典条件需要可靠出生时刻。")
    classical = result.get("classical") or {}
    sect = classical.get("sect") or {}
    if isinstance(sect, Mapping):
        sect_value = str(sect.get("sect") or classical.get("day_night_status") or "")
        sect_label = {"day": "昼盘", "night": "夜盘"}.get(sect_value, "未判定")
        diurnal_planets = "、".join(
            _label_point(item) for item in sect.get("diurnal_planet_ids") or []
        )
        nocturnal_planets = "、".join(
            _label_point(item) for item in sect.get("nocturnal_planet_ids") or []
        )
        _bullet(
            lines,
            (
                f"昼夜体系：{sect_label}；"
                f"当权光体 {_label_point(str(sect.get('sect_light_id')))}；"
                f"昼星 {diurnal_planets or '—'}；"
                f"夜星 {nocturnal_planets or '—'}"
            ),
        )
    for dignity in result.get("dignities") or []:
        active = [
            DIGNITY_LABELS_ZH.get(str(item.get("kind")), str(item.get("kind")))
            for item in dignity.get("dignities") or []
        ]
        debilities = [
            DIGNITY_LABELS_ZH.get(str(item.get("kind")), str(item.get("kind")))
            for item in dignity.get("debilities") or []
        ]
        dignity_label = _label_point(str(dignity.get("point_id")))
        _bullet(
            lines,
            (
                f"{dignity_label}：尊贵 {','.join(active) or '无'}；"
                f"失势/落陷 {','.join(debilities) or '无'}；"
                f"游走 {_label_boolean(dignity.get('peregrine'))}"
            ),
        )
    receptions = classical.get("receptions") or {}
    if isinstance(receptions, Mapping):
        for reception in receptions.get("receptions") or []:
            dignity_kind = str(reception.get("dignity_kind"))
            dignity_label = DIGNITY_LABELS_ZH.get(dignity_kind, dignity_kind)
            _bullet(
                lines,
                (
                    f"接纳：{_label_point(str(reception.get('host_point_id')))}接纳"
                    f"{_label_point(str(reception.get('guest_point_id')))}（"
                    f"{dignity_label}）"
                ),
            )
        for reception in receptions.get("mutual_receptions") or []:
            _bullet(
                lines,
                f"互容：{_label_point(str(reception.get('point_a')))}与{_label_point(str(reception.get('point_b')))}",
            )
    for lot in result.get("lots") or []:
        lot_label = _label_point(str(lot.get("lot_id")))
        lot_sign = _label_sign(lot.get("sign_id"))
        _bullet(
            lines,
            (
                f"{lot_label}：{lot_sign} {_degree(lot.get('degree_in_sign'))}；"
                f"公式 {lot.get('formula_expression')}"
            ),
        )

    _section(lines, "输入质量与分析提醒", markdown=markdown)
    if not (snapshot.get("warnings") or []):
        _bullet(lines, "没有影响本次分析范围的计算警告。")
    for warning in snapshot.get("warnings") or []:
        _bullet(lines, str(warning.get("message") or "本次结果包含一项需要注意的输入限制。"))
    _bullet(
        lines, "解释边界：本文档是计算事实，不提供确定性事件概率、医疗/法律/投资结论或寿命判断。"
    )
    return "\n".join(lines).strip() + "\n"
