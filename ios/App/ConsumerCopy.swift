import AstroCore
import Foundation

enum ConsumerCopy {
    static func bodyTheme(_ body: CelestialBody?, language: AppLanguage) -> String {
        guard let body else {
            return localized("an important need", "一项重要需要", language: language)
        }
        if language == .simplifiedChinese {
            return switch body {
            case .sun: "自我方向"
            case .moon: "情绪需要"
            case .mercury: "思考与沟通"
            case .venus: "亲密感与价值选择"
            case .mars: "行动力与边界"
            case .jupiter: "成长与信心"
            case .saturn: "责任与限制"
            case .uranus: "自由与改变"
            case .neptune: "想象力与敏感度"
            case .pluto: "掌控感与更新"
            case .trueNode: "未来方向"
            }
        }
        return switch body {
        case .sun: "self-direction"
        case .moon: "emotional needs"
        case .mercury: "thinking and communication"
        case .venus: "closeness and values"
        case .mars: "drive and boundaries"
        case .jupiter: "growth and confidence"
        case .saturn: "responsibility and limits"
        case .uranus: "freedom and change"
        case .neptune: "imagination and sensitivity"
        case .pluto: "control and renewal"
        case .trueNode: "future direction"
        }
    }

    static func connectionTitle(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let first = bodyTheme(CelestialBody(rawValue: aspect.firstID), language: language)
        let second = bodyTheme(CelestialBody(rawValue: aspect.secondID), language: language)
        if aspect.kind.supportive {
            return localized(
                "\(first) and \(second) work well together",
                "\(first)与\(second)彼此支持",
                language: language
            )
        }
        if aspect.kind.challenging {
            return localized(
                "\(first) and \(second) can pull in different directions",
                "\(first)与\(second)容易互相拉扯",
                language: language
            )
        }
        return localized(
            "\(first) and \(second) become important together",
            "\(first)与\(second)会同时变得重要",
            language: language
        )
    }

    static func connectionLabel(_ kind: AspectKind, language: AppLanguage) -> String {
        if kind.supportive {
            return localized("work together smoothly", "彼此支持", language: language)
        }
        if kind.challenging {
            return localized("need active balancing", "需要主动协调", language: language)
        }
        return localized("become active together", "同时变得活跃", language: language)
    }

    static func timing(_ phase: AspectPhase, language: AppLanguage) -> String {
        switch phase {
        case .applying:
            localized("The influence is building", "影响正在增强", language: language)
        case .exact:
            localized("The influence is clearest now", "此刻表现最明显", language: language)
        case .separating:
            localized("The influence is easing", "影响正在缓和", language: language)
        }
    }

    static func intensity(_ strength: Double, language: AppLanguage) -> String {
        if strength >= 0.78 {
            return localized("very noticeable", "非常明显", language: language)
        }
        if strength >= 0.52 {
            return localized("noticeable", "比较明显", language: language)
        }
        return localized("subtle but present", "较轻但仍可感受到", language: language)
    }

    static func lifeArea(_ house: Int?, language: AppLanguage) -> String {
        guard let house, (1 ... 12).contains(house) else {
            return localized("everyday choices", "日常选择", language: language)
        }
        let english = [
            "identity and first impressions",
            "money and personal resources",
            "learning and communication",
            "home and emotional security",
            "creativity and romance",
            "work, habits, and health",
            "close relationships",
            "trust and shared resources",
            "beliefs and exploration",
            "career and public role",
            "friends and long-term goals",
            "rest and inner life",
        ]
        let chinese = [
            "自我表达与第一印象",
            "金钱与个人资源",
            "学习与沟通",
            "家庭与安全感",
            "创造力与恋爱",
            "工作、习惯与健康",
            "亲密关系与合作",
            "信任与共同资源",
            "信念、学习与远行",
            "事业与社会角色",
            "朋友与长期目标",
            "休息与内在感受",
        ]
        return language == .english ? english[house - 1] : chinese[house - 1]
    }

    static func style(signIndex: Int, language: AppLanguage) -> String {
        let english = [
            "direct and decisive",
            "steady and practical",
            "curious and flexible",
            "protective and intuitive",
            "expressive and warm",
            "careful and precise",
            "cooperative and balanced",
            "private and intense",
            "open and exploratory",
            "disciplined and deliberate",
            "independent and original",
            "sensitive and imaginative",
        ]
        let chinese = [
            "直接果断",
            "稳定务实",
            "好奇灵活",
            "重视保护与感受",
            "热情且愿意表达",
            "谨慎细致",
            "重视合作与平衡",
            "深入而有分寸",
            "开放且愿意探索",
            "自律而审慎",
            "独立且有新意",
            "敏感而富有想象力",
        ]
        let index = max(0, min(11, signIndex))
        return language == .english ? english[index] : chinese[index]
    }

    static func motion(isRetrograde: Bool, language: AppLanguage) -> String {
        isRetrograde
            ? localized("A review-and-adjust period", "适合回顾和调整", language: language)
            : localized("Moving forward steadily", "正在稳定向前推进", language: language)
    }

    static func cycleStage(angle: Double, language: AppLanguage) -> String {
        switch angle {
        case 0 ..< 90:
            localized("a beginning-and-building stage", "开始并逐步积累的阶段", language: language)
        case 90 ..< 180:
            localized("an active development stage", "主动推进和发展的阶段", language: language)
        case 180 ..< 270:
            localized("a visibility-and-review stage", "成果显现并重新评估的阶段", language: language)
        default:
            localized("a completion-and-reset stage", "收尾并准备更新的阶段", language: language)
        }
    }
}
