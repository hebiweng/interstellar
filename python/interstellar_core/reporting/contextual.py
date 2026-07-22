"""Deterministic, item-level natal interpretation.

The service consumes one existing immutable snapshot fact addressed by JSON
Pointer.  It does not calculate missing astronomy, synthesize whole-chart
claims, or call a language model.  An absent rule or template is a first-class
``unavailable`` result so the UI can still show the underlying fact honestly.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Any


class ContextualInterpretationInputError(ValueError):
    """The requested snapshot path or fact shape is invalid."""


class ContextualItemKind(StrEnum):
    POINT_INTRINSIC = "point_intrinsic"
    POINT_IN_SIGN = "point_in_sign"
    POINT_IN_HOUSE = "point_in_house"
    MOTION = "motion"
    NATAL_ASPECT = "natal_aspect"
    HOUSE_CUSP_RULER = "house_cusp_ruler"
    STRUCTURE_INDICATOR = "structure_indicator"
    CLASSICAL_CONDITION = "classical_condition"


class InterpretationStatus(StrEnum):
    PUBLISHED = "published"
    UNAVAILABLE = "unavailable"
    NOT_APPLICABLE = "not_applicable"
    BLOCKED_BY_INPUT_QUALITY = "blocked_by_input_quality"


class InterpretationLocale(StrEnum):
    ZH_CN = "zh-CN"
    EN_US = "en-US"


@dataclass(frozen=True, slots=True)
class InterpretationRequest:
    item_kind: ContextualItemKind
    result_path: str
    locale: InterpretationLocale = InterpretationLocale.ZH_CN


@dataclass(frozen=True, slots=True)
class ContextualInterpretation:
    interpretation_id: str
    schema_version: str
    snapshot_id: str
    item_kind: str
    item_ref: str
    locale: str
    status: str
    fact: dict[str, Any]
    meaning: dict[str, Any] | None
    unavailable_reason: str | None
    warnings: tuple[str, ...]
    provenance: dict[str, Any]
    content_hash: str

    def to_dict(self) -> dict[str, Any]:
        return json.loads(json.dumps(asdict(self), ensure_ascii=False))


SERVICE_ID = "reporting.contextual_item_interpretation"
SERVICE_VERSION = "1.0.0"
SCHEMA_VERSION = "1.0.0"
ALGORITHM_CARD_ID = "ALG-REPORT-003"
RULE_PACK_ID = "official.natal.contextual.zh-CN.v1"
RULE_PACK_VERSION = "1.0.0"

_POINT_LABELS = {
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
    "mean_lilith": "平黑月莉莉丝",
    "true_lilith": "真黑月莉莉丝",
    "lunar_perigee": "月球近地点",
    "true_north_node": "真北交点",
    "true_south_node": "真南交点",
    "mean_north_node": "平北交点",
    "mean_south_node": "平南交点",
    "fortune": "福点",
    "spirit": "精神点",
    "lot_basis": "基础点",
    "lot_eros": "爱欲点",
    "lot_necessity": "必然点",
    "lot_courage": "勇气点",
    "lot_victory": "胜利点",
    "lot_nemesis": "报应点",
    "lot_exaltation": "擢升点",
    "chiron": "凯龙星",
    "ceres": "谷神星",
    "pallas": "智神星",
    "juno": "婚神星",
    "vesta": "灶神星",
    "pholus": "福洛斯",
    "nessus": "涅索斯",
    "chariklo": "查里克洛",
    "asteroid_eros": "爱神星",
    "psyche": "灵神星",
    "eris": "阋神星",
    "sedna": "赛德娜",
    "haumea": "妊神星",
    "makemake": "鸟神星",
    "quaoar": "创神星",
    "orcus": "亡神星",
    "ixion": "伊克西翁",
    "varuna": "伐楼拿",
    "astraea": "义神星",
    "hygiea": "健神星",
    "cupido": "丘比特",
    "hades": "哈得斯",
    "zeus": "宙斯",
    "kronos": "克洛诺斯",
    "apollon": "阿波罗",
    "admetos": "阿得门图斯",
    "vulkanus": "弗卡奴斯",
    "poseidon": "波塞冬",
}

_POINT_MEANINGS = {
    "sun": "太阳描述核心意志、身份方向与主动表达的中心。",
    "moon": "月亮描述情绪反应、安全需要与习惯性的照料方式。",
    "mercury": "水星描述信息处理、学习、表达与连接事物的方式。",
    "venus": "金星描述价值判断、吸引、关系协调与审美取向。",
    "mars": "火星描述行动、主张、竞争以及处理阻力的方式。",
    "jupiter": "木星描述扩展视野、形成信念与寻求成长空间的方式。",
    "saturn": "土星描述边界、责任、结构以及通过时间形成能力的过程。",
    "uranus": "天王星描述更新、独立、偏离惯例与突变式调整的倾向。",
    "neptune": "海王星描述想象、共感、理想化以及边界变得模糊的领域。",
    "pluto": "冥王星描述深层压力、控制议题以及彻底重组的过程。",
    "asc": "上升点描述个体进入环境、启动行动和被外界首先感知的方式。",
    "dsc": "下降点描述一对一关系、合作对象与互补经验的入口。",
    "mc": "天顶描述公共方向、职业能见度与社会角色的入口。",
    "ic": "天底描述私人根基、家庭经验与内在归属的入口。",
    "true_north_node": "真北交点是月球轨道与黄道的交点，解读上用于标记发展方向。",
    "true_south_node": "真南交点是真北交点的对点，解读上用于标记熟悉或惯性的路径。",
    "mean_north_node": "平北交点是平滑化的月球交点，解读上用于标记发展方向。",
    "mean_south_node": "平南交点是平北交点的对点，解读上用于标记熟悉或惯性的路径。",
    "vertex": "宿命点是由黄道与主垂圈交点计算出的关系敏感点，常用于观察被动相遇与外部触发。",
    "anti_vertex": "反宿命点是宿命点的对点，与宿命点共同构成一条关系触发轴。",
    "east_point": "东方点是以当地东方地平语义构造的敏感点，用于补充个体面向环境的呈现方式。",
    "west_point": "西方点是东方点的对点，用于补充一对一回应与环境反馈的象征主题。",
    "mean_lilith": "平黑月莉莉丝是月球远地点的平滑化位置，用于观察疏离、边界和未被驯化的情绪主题。",
    "true_lilith": "真黑月莉莉丝是月球远地点的振荡位置，用于观察疏离、边界和未被驯化的情绪主题。",
    "lunar_perigee": (
        "月球近地点标记月球轨道最接近地球的一端，"
        "用于补充本能反应与依附强度的象征阅读。"
    ),
    "fortune": "福点以昼夜公式结合上升、太阳与月亮，用于组织身体条件、物质处境与非意志性经验。",
    "spirit": "精神点以昼夜公式结合上升、太阳与月亮，用于组织意向、选择与个人能动性。",
    "lot_basis": "基础点用于观察福点与精神点之间的结构关系，以及行动与处境的承载基础。",
    "lot_eros": "爱欲点用于组织吸引、欲求、联结动力与价值追求的象征主题。",
    "lot_necessity": "必然点用于组织约束、责任、强制条件与必须处理之事的象征主题。",
    "lot_courage": "勇气点用于组织主张、冒险、竞争与面对阻力的象征主题。",
    "lot_victory": "胜利点用于组织成就、认可、支持条件与目标推进的象征主题。",
    "lot_nemesis": "报应点用于组织限制、代价、反复压力与承担后果的象征主题。",
    "lot_exaltation": "擢升点用于组织抬升、荣誉、能见度与更高期待的象征主题。",
    "chiron": "凯龙星常用于观察创伤经验、修复过程以及把个人经验转化为帮助他人的方式。",
    "ceres": "谷神星常用于观察照料、滋养、分离与重新建立安全感的方式。",
    "pallas": "智神星常用于观察模式识别、策略判断与以技巧解决问题的方式。",
    "juno": "婚神星常用于观察承诺、平等、契约与长期伴侣关系中的期待。",
    "vesta": "灶神星常用于观察专注、奉献、内在秩序与需要保留的私人空间。",
    "pholus": "福洛斯常用于观察小触发引发连锁变化、释放积累议题的过程。",
    "nessus": "涅索斯常用于观察权力边界、伤害循环与停止重复模式的责任。",
    "chariklo": "查里克洛常用于观察容纳、见证、疗愈边界与为复杂经验保留空间的能力。",
    "asteroid_eros": "爱神星常用于观察欲望、迷恋、创造冲动与亲密吸引的表达。",
    "psyche": "灵神星常用于观察敏感性、信任、内在联结与被理解的需要。",
    "eris": "阋神星常用于观察排斥感、不平等经验以及对既有秩序提出挑战的方式。",
    "sedna": "赛德娜常用于观察长期孤立、背弃经验以及在极端处境中重建力量的主题。",
    "haumea": "妊神星常用于观察再生、创造、身体自主与从内部生成新形式的能力。",
    "makemake": "鸟神星常用于观察生存智慧、资源适应与独立创造秩序的方式。",
    "quaoar": "创神星常用于观察通过节律、规则和命名把混沌组织成可持续形式的倾向。",
    "orcus": "亡神星常用于观察誓言、承诺、违约后果与个人原则的边界。",
    "ixion": "伊克西翁常用于观察越界、特权与为重复选择承担责任的主题。",
    "varuna": "伐楼拿常用于观察规则、誓约、道德秩序与维护整体结构的责任。",
    "astraea": "义神星常用于观察公平、判断、理想标准与何时选择退出失衡环境。",
    "hygiea": "健神星常用于观察预防、日常维护、清洁秩序与持续照顾身心的习惯。",
    "cupido": "丘比特是汉堡学派假想点，用于组织结合、群体、艺术与组织关系的主题。",
    "hades": "哈得斯是汉堡学派假想点，用于组织隐蔽、消耗、陈旧与困难条件的主题。",
    "zeus": "宙斯是汉堡学派假想点，用于组织定向意志、创造冲动与发动能力的主题。",
    "kronos": "克洛诺斯是汉堡学派假想点，用于组织权威、独立、地位与高标准的主题。",
    "apollon": "阿波罗是汉堡学派假想点，用于组织扩展、知识、商业与多重连接的主题。",
    "admetos": "阿得门图斯是汉堡学派假想点，用于组织收缩、凝固、耐力与停滞的主题。",
    "vulkanus": "弗卡奴斯是汉堡学派假想点，用于组织力量、强度、执行与推动力的主题。",
    "poseidon": "波塞冬是汉堡学派假想点，用于组织思想、精神取向、澄清与理念传播的主题。",
}

_SIGN_LABELS = {
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

_SIGN_MEANINGS = {
    "aries": "以直接、启动和先行的方式表达",
    "taurus": "以稳定、持续和重视具体价值的方式表达",
    "gemini": "以比较、交流和快速切换视角的方式表达",
    "cancer": "以保护、回应感受和建立归属的方式表达",
    "leo": "以创造、展示和强调个人中心的方式表达",
    "virgo": "以分析、校正和改善实际流程的方式表达",
    "libra": "以衡量关系、协商和平衡差异的方式表达",
    "scorpio": "以深入、集中和处理复杂情绪张力的方式表达",
    "sagittarius": "以探索、概括和追求更大意义的方式表达",
    "capricorn": "以规划、承担责任和建立长期结构的方式表达",
    "aquarius": "以独立、系统思考和连接群体议题的方式表达",
    "pisces": "以感受、想象和渗透边界的方式表达",
}

_SIGN_STRENGTHS = {
    "aries": "果断、勇于开始、反应迅速",
    "taurus": "稳定、耐心、重视实际成果",
    "gemini": "好奇、灵活、善于交换信息",
    "cancer": "体贴、保护、重视情感联结",
    "leo": "热情、创造、自信表达",
    "virgo": "细致、务实、善于改进",
    "libra": "公平、合作、善于协调",
    "scorpio": "专注、洞察、面对复杂议题",
    "sagittarius": "开放、乐观、追求成长",
    "capricorn": "负责、克制、长期建设",
    "aquarius": "独立、创新、系统思考",
    "pisces": "共情、想象、包容细腻",
}

_SIGN_CHALLENGES = {
    "aries": "急躁、过快定论或忽略他人节奏",
    "taurus": "固执、抗拒变化或过度依赖熟悉感",
    "gemini": "分散、反复或停留在信息表面",
    "cancer": "防御、情绪化或难以离开安全区",
    "leo": "自尊敏感、戏剧化或过度需要认可",
    "virgo": "挑剔、焦虑或过度追求完美",
    "libra": "犹豫、回避冲突或过度迁就",
    "scorpio": "猜疑、控制或难以放下紧张关系",
    "sagittarius": "夸大、跳过细节或承诺过多",
    "capricorn": "严苛、悲观或把责任扩大为压力",
    "aquarius": "疏离、固守观点或忽视个体感受",
    "pisces": "逃避、理想化或边界不清",
}

_HOUSE_MEANINGS = {
    1: "自我呈现、身体经验与行动起点",
    2: "个人资源、价值感与维持方式",
    3: "学习、沟通、近邻环境与日常移动",
    4: "家庭、私人根基、居所与归属",
    5: "创造、游戏、恋爱表达与子女议题",
    6: "日常工作、服务、技能维护与生活秩序",
    7: "伴侣、合作、契约与公开对手",
    8: "共同资源、亲密交换、债务与深层转化",
    9: "高等学习、信念、远行与意义体系",
    10: "职业方向、公共角色、声誉与责任",
    11: "朋友、群体、联盟与长期愿景",
    12: "退隐、隐性过程、结束与难以直接看见的领域",
}

_MOTION_MEANINGS = {
    "direct": "顺行表示该天体的黄经运动方向为通常方向；解读仅指功能较直接地向外展开，不代表吉凶。",
    "retrograde": "逆行表示该天体的黄经运动方向反转；解读可指向回看、内化或反复修订，不代表吉凶。",
    "stationary": (
        "停滞表示该天体黄经速度接近规则阈值；解读上强调该功能处于转向附近，具体阈值以快照为准。"
    ),
}

_ASPECT_LABELS = {
    "conjunction": "合相",
    "semiduodecile": "半十二分相",
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

_ASPECT_MEANINGS = {
    "conjunction": "两项功能集中在同一方向，容易彼此放大或难以分开运作。",
    "semiduodecile": "两项功能形成细微联系，通常需要结合更强证据才进入综合判断。",
    "semisextile": "两项功能相邻但表达逻辑不同，需要小幅调整才能互相接续。",
    "undecile": "两项功能形成十一分关系，属于实验性次要相位，不单独承担核心结论。",
    "decile": "两项功能形成十分关系，常用于描述专门化的组织或表达。",
    "novile": "两项功能形成九分关系，常用于描述内在整合与逐步成熟。",
    "semisquare": "两项功能存在持续的小幅摩擦，容易促使调整。",
    "septile": "两项功能形成七分关系，属于非主流次要相位，应保留流派标签。",
    "sextile": "两项功能存在可开发的协作通道，通常需要主动使用。",
    "quintile": "两项功能形成五分关系，常用于描述有意识的组织与创造性组合。",
    "square": "两项功能形成直接张力，需要通过行动、调整或分工来处理。",
    "biseptile": "两项功能形成双七分关系，属于非主流次要相位，应结合规则来源。",
    "trine": "两项功能运作方式相容，较容易形成自然流动，也可能因熟悉而少被察觉。",
    "sesquisquare": "两项功能形成持续压力，通常通过累积摩擦推动修正。",
    "biquintile": "两项功能形成双五分关系，常用于描述较成熟的创造性组织。",
    "quincunx": "两项功能缺少共同节奏，需要反复校准、取舍或重新安排。",
    "triseptile": "两项功能形成三七分关系，属于非主流次要相位，应结合规则来源。",
    "opposition": "两项功能位于对向位置，常通过他人、环境或两极拉扯被体验。",
}

_STRUCTURE_LABELS = {
    "same_sign": "同星座群星",
    "same_house": "同宫群星",
    "longitude_cluster": "黄经聚集群星",
    "grand_trine": "大三角",
    "t_square": "T三角",
    "grand_cross": "大十字",
    "yod": "Yod",
    "kite": "风筝",
    "mystic_rectangle": "神秘矩形",
    "on_angle": "合轴",
    "near_angle": "近轴",
    "not_near_angle": "非近轴",
}

_STRUCTURE_MEANINGS = {
    "same_sign": "多颗参与点集中在同一星座，使该星座的表达方式在盘面结构中被重复强调。",
    "same_house": "多颗参与点集中在同一宫位，使该生活领域成为盘面中的高密度区域。",
    "longitude_cluster": (
        "多颗参与点落在规则规定的黄经跨度内，构成局部能量集中；跨度阈值以结构配置为准。"
    ),
    "grand_trine": "三个点以三分相闭合，形成相容功能的循环；这是几何结构描述，不等于结果保证。",
    "t_square": "一个对冲轴由第三点分别形成四分相，焦点与对冲两端构成持续调节结构。",
    "grand_cross": "四个点形成两个对冲与四条四分相，显示多个方向同时要求协调。",
    "yod": "两个点以六分相连接，并共同与第三点形成梅花相，第三点是持续校准的焦点。",
    "kite": "大三角结构外加一个对冲焦点，使流动结构同时获得明确的牵引方向。",
    "mystic_rectangle": "两组对冲由三分相和六分相交织连接，支持与张力同时存在。",
    "on_angle": "该点位于配置规定的合轴容许度内，因此在盘面结构中具有较高可见度。",
    "near_angle": "该点接近四轴但未进入合轴容许度，结构强调程度低于合轴。",
    "not_near_angle": "该点不在配置规定的近轴范围内；这只是位置事实，不表示该点不重要。",
}

_STRUCTURE_DIMENSION_LABELS = {
    "hemispheres": "半球分布",
    "quadrants": "象限分布",
    "house_modes": "角续果分布",
}

_STRUCTURE_CATEGORY_LABELS = {
    "east": "东半球",
    "west": "西半球",
    "above": "上半球",
    "below": "下半球",
    "eastern": "东半球",
    "western": "西半球",
    "above_horizon": "上半球",
    "below_horizon": "下半球",
    "quadrant_1": "第一象限",
    "quadrant_2": "第二象限",
    "quadrant_3": "第三象限",
    "quadrant_4": "第四象限",
    "angular": "角宫",
    "succedent": "续宫",
    "cadent": "果宫",
}

_DIGNITY_LABELS = {
    "domicile": "本垣",
    "exaltation": "擢升",
    "triplicity": "三分性",
    "term": "界",
    "face": "面",
    "detriment": "失势",
    "fall": "落陷",
}

_DIGNITY_MEANINGS = {
    "domicile": "本垣表示行星位于自身传统守护的星座，描述其本质功能可以直接调用自身资源。",
    "exaltation": "擢升表示行星位于传统上被抬高的位置，描述其功能得到特定形式的支持。",
    "triplicity": "三分性尊贵描述行星在元素与昼夜条件中获得的支持，是否生效以快照字段为准。",
    "term": "界尊贵描述行星在该度数区间内获得的有限管辖条件。",
    "face": "面尊贵描述行星在该十度区间内获得的较弱、局部支持。",
    "detriment": "失势表示行星位于自身本垣的对宫，描述其功能需要借用不熟悉的表达条件。",
    "fall": "落陷表示行星位于擢升位置的对宫，描述其功能在该表达条件下需要更多调整。",
    "peregrine": (
        "游走表示当前规则表中没有命中有效本质尊贵或主要失势条件；它不是能力高低的客观分数。"
    ),
}

_SOLAR_MEANINGS = {
    "cazimi": "日核表示行星与太阳的角距进入规则规定的极小范围；传统解释将其与太阳中心性紧密联系。",
    "combust": "燃烧表示行星与太阳距离很近；传统解释认为其独立可见性和表达条件受太阳影响。",
    "under_beams": "日光下表示行星进入太阳光束范围；传统解释强调其可见性受限。",
    "free": "离日表示行星不在当前日核、燃烧或光束阈值内。",
}

_SECT_MEANINGS = {
    "day": "昼盘以太阳为昼夜主光体，并按所选古典规则区分昼行星与夜行星的条件。",
    "night": "夜盘以月亮为昼夜主光体，并按所选古典规则区分昼行星与夜行星的条件。",
}

_LOT_MEANINGS = {
    "fortune": "福点在希腊化传统中用于组织身体条件、物质处境与非意志性经验这一象征主题。",
    "spirit": "精神点用于组织意向、选择、行动方向与个人能动性这一象征主题。",
    "lot_basis": "基础点用于观察福点与精神点之间的结构关系，描述承载行动与处境的象征基础。",
    "lot_eros": "爱欲点用于组织吸引、欲求、联结动力与价值追求这一象征主题。",
    "lot_necessity": "必然点用于组织约束、责任、强制条件与必须处理之事这一象征主题。",
    "lot_courage": "勇气点用于组织主张、冒险、竞争与面对阻力的象征主题。",
    "lot_victory": "胜利点用于组织成就、认可、支持条件与目标推进这一象征主题。",
    "lot_nemesis": "报应点用于组织限制、代价、反复压力与需要承担后果这一象征主题。",
    "lot_exaltation": "擢升点用于组织抬升、荣誉、能见度与被赋予更高期待这一象征主题。",
}

_PROHIBITED_FATALISTIC_PHRASES = (
    "一定发生",
    "必然死亡",
    "注定死亡",
    "寿命长度",
    "保证成功",
    "保证复合",
    "必然离婚",
    "必然发财",
    "项目一定成功",
)

_SOURCES = {
    "ALG-REPORT-003": {
        "source_id": "ALG-REPORT-003",
        "title": "配置与计算项的就地确定性解读算法卡",
        "kind": "algorithm_card",
        "origin": "repository",
        "version": "1.0.0",
    },
    "interstellar.modern_semantic_lexicon.v1": {
        "source_id": "interstellar.modern_semantic_lexicon.v1",
        "title": "Interstellar 现代占星原子语义词表 v1",
        "kind": "project_authored_rule_source",
        "origin": "project_authored",
        "version": "1.0.0",
    },
    "interstellar.traditional_semantic_lexicon.v1": {
        "source_id": "interstellar.traditional_semantic_lexicon.v1",
        "title": "Interstellar 古典条件原子语义词表 v1",
        "kind": "project_authored_rule_source",
        "origin": "project_authored",
        "version": "1.0.0",
    },
}


def _canonical_hash(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


_RULE_PACK_HASH = _canonical_hash(
    {
        "id": RULE_PACK_ID,
        "version": RULE_PACK_VERSION,
        "points": _POINT_MEANINGS,
        "signs": _SIGN_MEANINGS,
        "sign_strengths": _SIGN_STRENGTHS,
        "sign_challenges": _SIGN_CHALLENGES,
        "houses": _HOUSE_MEANINGS,
        "motion": _MOTION_MEANINGS,
        "aspects": _ASPECT_MEANINGS,
        "structure": _STRUCTURE_MEANINGS,
        "structure_dimensions": _STRUCTURE_DIMENSION_LABELS,
        "structure_categories": _STRUCTURE_CATEGORY_LABELS,
        "dignity": _DIGNITY_MEANINGS,
        "solar": _SOLAR_MEANINGS,
        "sect": _SECT_MEANINGS,
        "lots": _LOT_MEANINGS,
    }
)


def interpret_snapshot_item(
    snapshot: Mapping[str, Any],
    request: InterpretationRequest,
) -> ContextualInterpretation:
    """Interpret exactly one existing natal fact, without adding dependencies."""

    snapshot_id = str(snapshot.get("id") or "")
    if not snapshot_id:
        raise ContextualInterpretationInputError("snapshot requires a non-empty id")
    if request.locale is not InterpretationLocale.ZH_CN:
        fact = _fact_only(_resolve_pointer(snapshot, request.result_path))
        return _build_result(
            snapshot_id=snapshot_id,
            request=request,
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="TEMPLATE_LOCALE_UNAVAILABLE",
            rule_id=f"contextual.{request.item_kind.value}.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003",),
        )

    value = _resolve_pointer(snapshot, request.result_path)
    if not isinstance(value, Mapping):
        raise ContextualInterpretationInputError(
            "contextual interpretation requires an object-valued result path"
        )

    handlers = {
        ContextualItemKind.POINT_INTRINSIC: _point_intrinsic,
        ContextualItemKind.POINT_IN_SIGN: _point_in_sign,
        ContextualItemKind.POINT_IN_HOUSE: _point_in_house,
        ContextualItemKind.MOTION: _motion,
        ContextualItemKind.NATAL_ASPECT: lambda item: _natal_aspect(item, snapshot),
        ContextualItemKind.HOUSE_CUSP_RULER: _house_cusp_ruler,
        ContextualItemKind.STRUCTURE_INDICATOR: _structure_indicator,
        ContextualItemKind.CLASSICAL_CONDITION: _classical_condition,
    }
    item_result = handlers[request.item_kind](value)
    return _build_result(
        snapshot_id=snapshot_id,
        request=request,
        **item_result,
    )


def _resolve_pointer(document: Mapping[str, Any], pointer: str) -> Any:
    if not pointer.startswith("/result/"):
        raise ContextualInterpretationInputError("result_path must be a JSON Pointer below /result")
    value: Any = document
    for raw_segment in pointer[1:].split("/"):
        segment = raw_segment.replace("~1", "/").replace("~0", "~")
        if isinstance(value, Mapping):
            if segment not in value:
                raise ContextualInterpretationInputError(f"result_path does not exist: {pointer}")
            value = value[segment]
        elif isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            if not segment.isdigit():
                raise ContextualInterpretationInputError(
                    f"result_path list segment is not an index: {segment}"
                )
            index = int(segment)
            if index >= len(value):
                raise ContextualInterpretationInputError(
                    f"result_path index is out of range: {pointer}"
                )
            value = value[index]
        else:
            raise ContextualInterpretationInputError(
                f"result_path traverses a scalar value: {pointer}"
            )
    return value


def _point_id(item: Mapping[str, Any]) -> str:
    point_id = item.get("point_id")
    if not isinstance(point_id, str) or not point_id:
        raise ContextualInterpretationInputError("point fact requires point_id")
    return point_id


def _point_label(point_id: str) -> str:
    return _POINT_LABELS.get(point_id, point_id)


def _degree(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return round(number, 6) if math.isfinite(number) else None


def _fact_only(item: Any) -> dict[str, Any]:
    if isinstance(item, Mapping):
        return json.loads(json.dumps(dict(item), ensure_ascii=False))
    return {"value": item}


def _point_fact(item: Mapping[str, Any]) -> dict[str, Any]:
    point_id = _point_id(item)
    position = item.get("position") if isinstance(item.get("position"), Mapping) else {}
    ecliptic = position.get("ecliptic") if isinstance(position.get("ecliptic"), Mapping) else {}
    motion_state = position.get("motion_state")
    return {
        "point_id": point_id,
        "point_label": _point_label(point_id),
        "kind": item.get("kind"),
        "longitude_deg": _degree(ecliptic.get("longitude_deg")),
        "sign_id": item.get("sign"),
        "degree_in_sign": _degree(item.get("degree_in_sign")),
        "house": item.get("house"),
        "motion_state": motion_state,
        "retrograde": item.get("retrograde"),
    }


def _statement(key: str, text: str, parameters: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "statement_key": key,
        "text": text,
        "parameters": json.loads(json.dumps(dict(parameters), ensure_ascii=False)),
    }


def _handler_result(
    *,
    status: InterpretationStatus,
    fact: dict[str, Any],
    meaning: dict[str, Any] | None,
    reason: str | None = None,
    rule_id: str,
    template_key: str | None,
    source_ids: tuple[str, ...],
    warnings: tuple[str, ...] = (),
    maturity: str = "experimental",
) -> dict[str, Any]:
    return {
        "status": status,
        "fact": fact,
        "meaning": meaning,
        "reason": reason,
        "rule_id": rule_id,
        "template_key": template_key,
        "source_ids": source_ids,
        "warnings": warnings,
        "maturity": maturity,
    }


def _point_intrinsic(item: Mapping[str, Any]) -> dict[str, Any]:
    fact = _point_fact(item)
    point_id = fact["point_id"]
    meaning = _POINT_MEANINGS.get(point_id)
    if meaning is None:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="POINT_INTRINSIC_RULE_UNAVAILABLE",
            rule_id="contextual.point_intrinsic.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            f"point.intrinsic.{point_id}",
            meaning,
            {"point_id": point_id},
        ),
        rule_id="contextual.point_intrinsic.v1",
        template_key=f"point.intrinsic.{point_id}.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _point_in_sign(item: Mapping[str, Any]) -> dict[str, Any]:
    fact = _point_fact(item)
    point_id = fact["point_id"]
    sign_id = fact["sign_id"]
    point_meaning = _POINT_MEANINGS.get(point_id)
    sign_meaning = _SIGN_MEANINGS.get(str(sign_id))
    if point_meaning is None or sign_meaning is None:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason=(
                "POINT_INTRINSIC_RULE_UNAVAILABLE"
                if point_meaning is None
                else "SIGN_RULE_UNAVAILABLE"
            ),
            rule_id="contextual.point_in_sign.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    sign_label = _SIGN_LABELS[str(sign_id)]
    text = (
        f"{_point_label(point_id)}落在{sign_label}：{point_meaning}在这里，这项功能{sign_meaning}。"
        f"可用优势包括{_SIGN_STRENGTHS[str(sign_id)]}；需要留意"
        f"{_SIGN_CHALLENGES[str(sign_id)]}。"
    )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            "point.in_sign",
            text,
            {"point_id": point_id, "sign_id": sign_id},
        ),
        rule_id="contextual.point_in_sign.v1",
        template_key="point.in_sign.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _point_in_house(item: Mapping[str, Any]) -> dict[str, Any]:
    fact = _point_fact(item)
    point_id = fact["point_id"]
    house = fact["house"]
    if house is None:
        return _handler_result(
            status=InterpretationStatus.BLOCKED_BY_INPUT_QUALITY,
            fact=fact,
            meaning=None,
            reason="MISSING_HOUSE_ASSIGNMENT",
            rule_id="contextual.point_in_house.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    if isinstance(house, bool) or not isinstance(house, int) or house not in _HOUSE_MEANINGS:
        raise ContextualInterpretationInputError("point house must be an integer in [1, 12]")
    point_meaning = _POINT_MEANINGS.get(point_id)
    if point_meaning is None:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="POINT_INTRINSIC_RULE_UNAVAILABLE",
            rule_id="contextual.point_in_house.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    text = (
        f"{_point_label(point_id)}落在第{house}宫：{point_meaning}"
        f"这项功能主要通过{_HOUSE_MEANINGS[house]}被体验和表达。"
        "与其他点位的支持性或张力相位会改变表达难度，需要回到整盘相位共同判断。"
    )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            "point.in_house",
            text,
            {"point_id": point_id, "house": house},
        ),
        rule_id="contextual.point_in_house.v1",
        template_key="point.in_house.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _motion(item: Mapping[str, Any]) -> dict[str, Any]:
    fact = _point_fact(item)
    interpretation = item.get("motion_interpretation")
    if interpretation == "not_applicable":
        return _handler_result(
            status=InterpretationStatus.NOT_APPLICABLE,
            fact=fact,
            meaning=None,
            reason="MOTION_INTERPRETATION_NOT_APPLICABLE",
            rule_id="contextual.motion.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    motion_state = fact["motion_state"]
    meaning = _MOTION_MEANINGS.get(str(motion_state))
    if interpretation != "meaningful" or meaning is None:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="MOTION_RULE_OR_FACT_UNAVAILABLE",
            rule_id="contextual.motion.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            f"motion.{motion_state}",
            f"{_point_label(fact['point_id'])}{meaning}",
            {"point_id": fact["point_id"], "motion_state": motion_state},
        ),
        rule_id="contextual.motion.v1",
        template_key=f"motion.{motion_state}.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _snapshot_points(snapshot: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    result = snapshot.get("result")
    points = result.get("points") if isinstance(result, Mapping) else None
    if not isinstance(points, Sequence):
        return {}
    return {
        str(point["point_id"]): point
        for point in points
        if isinstance(point, Mapping) and isinstance(point.get("point_id"), str)
    }


def _natal_aspect(item: Mapping[str, Any], snapshot: Mapping[str, Any]) -> dict[str, Any]:
    required = ("aspect_id", "point_a", "point_b", "type")
    if any(not isinstance(item.get(key), str) or not item.get(key) for key in required):
        raise ContextualInterpretationInputError(
            "natal aspect requires aspect_id, point_a, point_b, and type"
        )
    aspect_type = str(item["type"])
    fact = {
        key: item.get(key)
        for key in (
            "aspect_id",
            "point_a",
            "point_b",
            "context",
            "type",
            "exact_angle_deg",
            "actual_angle_deg",
            "orb_deg",
            "orb_ratio",
            "applying_state",
            "direction",
            "strength",
        )
    }
    if item.get("context") not in {None, "within_chart"}:
        return _handler_result(
            status=InterpretationStatus.NOT_APPLICABLE,
            fact=fact,
            meaning=None,
            reason="ASPECT_IS_NOT_NATAL_WITHIN_CHART",
            rule_id="contextual.natal_aspect.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    points = _snapshot_points(snapshot)
    point_a = str(item["point_a"])
    point_b = str(item["point_b"])
    aspect_meaning = _ASPECT_MEANINGS.get(aspect_type)
    if (
        point_a not in points
        or point_b not in points
        or point_a not in _POINT_MEANINGS
        or point_b not in _POINT_MEANINGS
        or aspect_meaning is None
    ):
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="ASPECT_PARTICIPANT_OR_TYPE_RULE_UNAVAILABLE",
            rule_id="contextual.natal_aspect.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    label = _ASPECT_LABELS[aspect_type]
    text = (
        f"{_point_label(point_a)}与{_point_label(point_b)}形成{label}："
        f"{aspect_meaning}具体表达需同时保留两颗星体各自的功能与容许度事实。"
    )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            f"aspect.{aspect_type}",
            text,
            {"point_a": point_a, "point_b": point_b, "aspect_type": aspect_type},
        ),
        rule_id="contextual.natal_aspect.v1",
        template_key="aspect.pair.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _house_cusp_ruler(item: Mapping[str, Any]) -> dict[str, Any]:
    house = item.get("number")
    if isinstance(house, bool) or not isinstance(house, int) or house not in _HOUSE_MEANINGS:
        raise ContextualInterpretationInputError("house cusp fact requires number in [1, 12]")
    sign_id = item.get("sign")
    fact = {
        "house_number": house,
        "cusp_longitude_deg": _degree(item.get("cusp_longitude_deg")),
        "sign_id": sign_id,
        "degree_in_sign": _degree(item.get("degree_in_sign")),
        "traditional_ruler_ids": list(item.get("traditional_ruler_ids") or ()),
        "modern_ruler_ids": list(item.get("modern_ruler_ids") or ()),
        "intercepted_signs": list(item.get("intercepted_signs") or ()),
        "repeated_cusp_sign": item.get("repeated_cusp_sign"),
    }
    if str(sign_id) not in _SIGN_MEANINGS:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="HOUSE_CUSP_SIGN_RULE_UNAVAILABLE",
            rule_id="contextual.house_cusp_ruler.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    rulers = list(dict.fromkeys([*fact["traditional_ruler_ids"], *fact["modern_ruler_ids"]]))
    if not rulers:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="HOUSE_RULER_FACT_MISSING",
            rule_id="contextual.house_cusp_ruler.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    ruler_text = "、".join(_point_label(point_id) for point_id in rulers)
    text = (
        f"第{house}宫关联{_HOUSE_MEANINGS[house]}；宫头落{_SIGN_LABELS[str(sign_id)]}，"
        f"以{_SIGN_MEANINGS[str(sign_id)]}。当前规则列出的宫主星为{ruler_text}；"
        "传统与现代守护必须按字段分别读取。"
    )
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            "house.cusp_ruler",
            text,
            {"house": house, "sign_id": sign_id, "ruler_ids": rulers},
        ),
        rule_id="contextual.house_cusp_ruler.v1",
        template_key="house.cusp_ruler.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _structure_indicator(item: Mapping[str, Any]) -> dict[str, Any]:
    dimension = item.get("dimension")
    if isinstance(dimension, str) and isinstance(item.get("categories"), Sequence):
        fact = _fact_only(item)
        dimension_label = _STRUCTURE_DIMENSION_LABELS.get(dimension)
        if dimension_label is None:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason="STRUCTURE_CATEGORICAL_RULE_UNAVAILABLE",
                rule_id="contextual.structure_indicator.categorical.v1",
                template_key=None,
                source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
            )
        category_facts: list[dict[str, Any]] = []
        category_texts: list[str] = []
        for category in item.get("categories") or ():
            if not isinstance(category, Mapping):
                continue
            category_id = str(category.get("category_id") or "")
            if category_id not in _STRUCTURE_CATEGORY_LABELS:
                continue
            count = int(category.get("count") or 0)
            point_ids = [str(point_id) for point_id in category.get("point_ids") or ()]
            category_facts.append(
                {"category_id": category_id, "count": count, "point_ids": point_ids}
            )
            category_texts.append(f"{_STRUCTURE_CATEGORY_LABELS[category_id]} {count} 个点")
        if not category_texts:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason="STRUCTURE_CATEGORICAL_FACT_MISSING",
                rule_id="contextual.structure_indicator.categorical.v1",
                template_key=None,
                source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
            )
        text = (
            f"{dimension_label}：{'；'.join(category_texts)}。"
            "这是所选点集的位置数量描述，不是人格、吉凶或事件概率评分；"
            "结论还会随纳入点位、宫位制和出生时间质量变化。"
        )
        return _handler_result(
            status=InterpretationStatus.PUBLISHED,
            fact=fact,
            meaning=_statement(
                f"structure.categorical.{dimension}",
                text,
                {"dimension": dimension, "categories": category_facts},
            ),
            rule_id="contextual.structure_indicator.categorical.v1",
            template_key="structure.categorical.zh-CN",
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )

    structure_type = item.get("pattern_type") or item.get("kind") or item.get("band")
    fact = _fact_only(item)
    meaning = _STRUCTURE_MEANINGS.get(str(structure_type))
    if meaning is None:
        return _handler_result(
            status=InterpretationStatus.UNAVAILABLE,
            fact=fact,
            meaning=None,
            reason="STRUCTURE_INDICATOR_RULE_UNAVAILABLE",
            rule_id="contextual.structure_indicator.v1",
            template_key=None,
            source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
        )
    participants = list(item.get("participant_ids") or ())
    if not participants and isinstance(item.get("point_id"), str):
        participants = [str(item["point_id"])]
    label = _STRUCTURE_LABELS[str(structure_type)]
    participant_text = "、".join(_point_label(point_id) for point_id in participants)
    text = f"{label}"
    if participant_text:
        text += f"（{participant_text}）"
    text += f"：{meaning}"
    return _handler_result(
        status=InterpretationStatus.PUBLISHED,
        fact=fact,
        meaning=_statement(
            f"structure.{structure_type}",
            text,
            {"structure_type": structure_type, "participant_ids": participants},
        ),
        rule_id="contextual.structure_indicator.v1",
        template_key="structure.indicator.zh-CN",
        source_ids=("ALG-REPORT-003", "interstellar.modern_semantic_lexicon.v1"),
    )


def _condition_source_ids(item: Mapping[str, Any]) -> tuple[str, ...]:
    ids: list[str] = ["ALG-REPORT-003", "interstellar.traditional_semantic_lexicon.v1"]
    for source_id in item.get("source_ids") or ():
        if isinstance(source_id, str):
            ids.append(source_id)
    for conditions in (item.get("dignities") or (), item.get("debilities") or ()):
        for condition in conditions:
            if not isinstance(condition, Mapping):
                continue
            table_ref = condition.get("table_ref")
            if isinstance(table_ref, Mapping):
                ids.extend(
                    source_id
                    for source_id in table_ref.get("source_ids") or ()
                    if isinstance(source_id, str)
                )
    return tuple(dict.fromkeys(ids))


def _classical_condition(item: Mapping[str, Any]) -> dict[str, Any]:
    fact = _fact_only(item)
    source_ids = _condition_source_ids(item)
    if "dignities" in item or "debilities" in item:
        if item.get("applicable") is False:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason=str(item.get("unavailable_reason") or "CLASSICAL_RULE_UNAVAILABLE"),
                rule_id="contextual.classical_condition.essential_dignity.v1",
                template_key=None,
                source_ids=source_ids,
                maturity="experimental",
            )
        conditions: list[str] = []
        kinds: list[str] = []
        for group_name in ("dignities", "debilities"):
            for condition in item.get(group_name) or ():
                if not isinstance(condition, Mapping):
                    continue
                kind = str(condition.get("kind") or "")
                if kind in _DIGNITY_MEANINGS:
                    kinds.append(kind)
                    conditions.append(_DIGNITY_MEANINGS[kind])
        if item.get("peregrine") is True:
            kinds.append("peregrine")
            conditions.append(_DIGNITY_MEANINGS["peregrine"])
        if not conditions:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason="CLASSICAL_CONDITION_RULE_UNAVAILABLE",
                rule_id="contextual.classical_condition.essential_dignity.v1",
                template_key=None,
                source_ids=source_ids,
            )
        labels = "、".join(_DIGNITY_LABELS.get(kind, "游走") for kind in kinds)
        point_id = str(item.get("point_id") or "")
        text = f"{_point_label(point_id)}的本质状态命中{labels}。" + "".join(conditions)
        text += "各分项并列保留，不合成为客观吉凶分数。"
        return _handler_result(
            status=InterpretationStatus.PUBLISHED,
            fact=fact,
            meaning=_statement(
                "classical.essential_condition",
                text,
                {"point_id": point_id, "condition_kinds": kinds},
            ),
            rule_id="contextual.classical_condition.essential_dignity.v1",
            template_key="classical.essential_condition.zh-CN",
            source_ids=source_ids,
        )

    if isinstance(item.get("relation"), str):
        relation = str(item["relation"])
        if relation == "not_applicable":
            return _handler_result(
                status=InterpretationStatus.NOT_APPLICABLE,
                fact=fact,
                meaning=None,
                reason="SOLAR_RELATION_NOT_APPLICABLE",
                rule_id="contextual.classical_condition.solar.v1",
                template_key=None,
                source_ids=source_ids,
            )
        meaning = _SOLAR_MEANINGS.get(relation)
        if meaning is not None:
            point_id = str(item.get("point_id") or "")
            return _handler_result(
                status=InterpretationStatus.PUBLISHED,
                fact=fact,
                meaning=_statement(
                    f"classical.solar.{relation}",
                    f"{_point_label(point_id)}：{meaning}",
                    {"point_id": point_id, "relation": relation},
                ),
                rule_id="contextual.classical_condition.solar.v1",
                template_key=f"classical.solar.{relation}.zh-CN",
                source_ids=source_ids,
            )

    if isinstance(item.get("sect"), str) and "lot_id" not in item:
        sect = str(item["sect"])
        meaning = _SECT_MEANINGS.get(sect)
        if meaning is not None:
            return _handler_result(
                status=InterpretationStatus.PUBLISHED,
                fact=fact,
                meaning=_statement(
                    f"classical.sect.{sect}",
                    meaning,
                    {"sect": sect, "sect_light_id": item.get("sect_light_id")},
                ),
                rule_id="contextual.classical_condition.sect.v1",
                template_key=f"classical.sect.{sect}.zh-CN",
                source_ids=source_ids,
            )

    if all(isinstance(item.get(key), str) for key in ("host_point_id", "guest_point_id")):
        dignity_kind = str(item.get("dignity_kind") or "")
        if dignity_kind in _DIGNITY_MEANINGS:
            host = str(item["host_point_id"])
            guest = str(item["guest_point_id"])
            text = (
                f"{_point_label(host)}以{_DIGNITY_LABELS[dignity_kind]}接纳"
                f"{_point_label(guest)}；这描述尊贵范围中的关系，不自动等同于相位完成或结果保证。"
            )
            return _handler_result(
                status=InterpretationStatus.PUBLISHED,
                fact=fact,
                meaning=_statement(
                    "classical.reception",
                    text,
                    {"host_point_id": host, "guest_point_id": guest, "dignity_kind": dignity_kind},
                ),
                rule_id="contextual.classical_condition.reception.v1",
                template_key="classical.reception.zh-CN",
                source_ids=source_ids,
            )

    if isinstance(item.get("edges"), Sequence):
        edges = [edge for edge in item.get("edges") or () if isinstance(edge, Mapping)]
        cycles = [cycle for cycle in item.get("cycles") or () if isinstance(cycle, Sequence)]
        final_dispositors = [str(point_id) for point_id in item.get("final_dispositor_ids") or ()]
        if not edges:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason="DISPOSITOR_GRAPH_FACT_MISSING",
                rule_id="contextual.classical_condition.dispositor.v1",
                template_key=None,
                source_ids=source_ids,
            )
        final_text = (
            "、".join(_point_label(point_id) for point_id in final_dispositors)
            or "无单一最终定位星"
        )
        cycle_text = (
            "；".join(
                " → ".join(_point_label(str(point_id)) for point_id in cycle) for cycle in cycles
            )
            or "无闭合循环"
        )
        text = (
            f"传统定位星链包含 {len(edges)} 条守护关系；"
            f"最终定位星：{final_text}；循环：{cycle_text}。"
            "它描述各行星经由星座守护形成的结构传递路径，不等于主导人格排名、吉凶分数或事件结果。"
        )
        return _handler_result(
            status=InterpretationStatus.PUBLISHED,
            fact=fact,
            meaning=_statement(
                "classical.dispositor_graph",
                text,
                {
                    "edge_count": len(edges),
                    "cycle_count": len(cycles),
                    "final_dispositor_ids": final_dispositors,
                },
            ),
            rule_id="contextual.classical_condition.dispositor.v1",
            template_key="classical.dispositor_graph.zh-CN",
            source_ids=source_ids,
        )

    if "receptions" in item or "mutual_receptions" in item:
        receptions = [row for row in item.get("receptions") or () if isinstance(row, Mapping)]
        mutual = [row for row in item.get("mutual_receptions") or () if isinstance(row, Mapping)]
        text = (
            f"当前规则命中 {len(receptions)} 条单向接纳与 {len(mutual)} 组互容。"
            "接纳描述一颗行星位于另一颗行星的本质尊贵范围；互容表示这种关系双向成立。"
            "当前文档不要求相位，因此接纳本身不自动表示事件完成、关系和谐或压力已被化解。"
        )
        return _handler_result(
            status=InterpretationStatus.PUBLISHED,
            fact=fact,
            meaning=_statement(
                "classical.reception_document",
                text,
                {
                    "reception_count": len(receptions),
                    "mutual_reception_count": len(mutual),
                    "aspect_required": bool(item.get("aspect_required")),
                },
            ),
            rule_id="contextual.classical_condition.reception_document.v1",
            template_key="classical.reception_document.zh-CN",
            source_ids=source_ids,
        )

    if isinstance(item.get("lot_id"), str):
        lot_id = str(item["lot_id"])
        meaning = _LOT_MEANINGS.get(lot_id)
        if meaning is None:
            return _handler_result(
                status=InterpretationStatus.UNAVAILABLE,
                fact=fact,
                meaning=None,
                reason="LOT_INTERPRETATION_RULE_UNAVAILABLE",
                rule_id="contextual.classical_condition.lot.v1",
                template_key=None,
                source_ids=source_ids,
            )
        sect_label = str(item.get("sect") or "未声明")
        formula_expression = str(item.get("formula_expression") or "—")
        text = (
            f"{_point_label(lot_id)}：{meaning}"
            f"当前结果采用{sect_label}盘公式“{formula_expression}”。"
            "该点只提供版本化公式与象征主题，不给出现实事件的确定预测。"
        )
        return _handler_result(
            status=InterpretationStatus.PUBLISHED,
            fact=fact,
            meaning=_statement(
                f"classical.lot.{lot_id}",
                text,
                {
                    "lot_id": lot_id,
                    "sect": item.get("sect"),
                    "formula_id": item.get("formula_id"),
                    "formula_version": item.get("formula_version"),
                },
            ),
            rule_id="contextual.classical_condition.lot.v1",
            template_key="classical.lot.zh-CN",
            source_ids=source_ids,
        )

    return _handler_result(
        status=InterpretationStatus.UNAVAILABLE,
        fact=fact,
        meaning=None,
        reason="CLASSICAL_CONDITION_RULE_UNAVAILABLE",
        rule_id="contextual.classical_condition.v1",
        template_key=None,
        source_ids=source_ids,
    )


def _source_documents(source_ids: tuple[str, ...]) -> list[dict[str, Any]]:
    documents: list[dict[str, Any]] = []
    for source_id in dict.fromkeys(source_ids):
        documents.append(
            dict(
                _SOURCES.get(
                    source_id,
                    {
                        "source_id": source_id,
                        "title": source_id,
                        "kind": "snapshot_declared_source",
                        "origin": "snapshot_provenance",
                        "version": "snapshot_declared",
                    },
                )
            )
        )
    return documents


def _build_result(
    *,
    snapshot_id: str,
    request: InterpretationRequest,
    status: InterpretationStatus,
    fact: dict[str, Any],
    meaning: dict[str, Any] | None,
    reason: str | None,
    rule_id: str,
    template_key: str | None,
    source_ids: tuple[str, ...],
    warnings: tuple[str, ...] = (),
    maturity: str = "experimental",
) -> ContextualInterpretation:
    if meaning is not None:
        meaning_text = str(meaning.get("text") or "")
        prohibited = [phrase for phrase in _PROHIBITED_FATALISTIC_PHRASES if phrase in meaning_text]
        if prohibited:
            raise RuntimeError(
                "contextual interpretation contains prohibited fatalistic claim: "
                + ", ".join(prohibited)
            )
    template_hash = (
        _canonical_hash(
            {
                "template_key": template_key,
                "locale": request.locale.value,
                "text": meaning.get("text") if meaning else None,
            }
        )
        if template_key is not None and meaning is not None
        else None
    )
    provenance = {
        "service": {"id": SERVICE_ID, "version": SERVICE_VERSION},
        "algorithm_card": {"id": ALGORITHM_CARD_ID, "version": "1.0.0"},
        "rule_pack": {
            "id": RULE_PACK_ID,
            "version": RULE_PACK_VERSION,
            "content_hash": _RULE_PACK_HASH,
        },
        "rule": {
            "id": rule_id,
            "version": "1.0.0",
            "content_hash": _canonical_hash(
                {"rule_id": rule_id, "rule_pack_hash": _RULE_PACK_HASH}
            ),
        },
        "template": {
            "id": template_key,
            "version": "1.0.0" if template_key else None,
            "locale": request.locale.value,
            "content_hash": template_hash,
            "status": "available" if template_key else "unavailable",
        },
        "sources": _source_documents(source_ids),
        "maturity": maturity,
        "generation_mode": "deterministic_rule_template",
        "ai_used": False,
    }
    semantic_payload = {
        "schema_version": SCHEMA_VERSION,
        "snapshot_id": snapshot_id,
        "item_kind": request.item_kind.value,
        "item_ref": request.result_path,
        "locale": request.locale.value,
        "status": status.value,
        "fact": fact,
        "meaning": meaning,
        "unavailable_reason": reason,
        "warnings": list(warnings),
        "provenance": provenance,
    }
    content_hash = _canonical_hash(semantic_payload)
    interpretation_id = "interpretation-" + content_hash.removeprefix("sha256:")[:24]
    return ContextualInterpretation(
        interpretation_id=interpretation_id,
        schema_version=SCHEMA_VERSION,
        snapshot_id=snapshot_id,
        item_kind=request.item_kind.value,
        item_ref=request.result_path,
        locale=request.locale.value,
        status=status.value,
        fact=fact,
        meaning=meaning,
        unavailable_reason=reason,
        warnings=warnings,
        provenance=provenance,
        content_hash=content_hash,
    )
