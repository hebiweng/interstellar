import AstroCore
import Foundation

/// One-sentence explanations for the four solar-return anchors, written as
/// consumer copy. Each anchor is "analysis angle + calculated parameter + one
/// clear sentence" — the sentence never repeats the parameter.
enum YearAnchorCopy {
    static func ascendantNote(signIndex: Int, language: AppLanguage) -> String {
        let en = [
            "The year opens with direct action and a fresh start.",
            "The year opens around steady ground, resources and patience.",
            "The year opens through conversation, ideas and movement.",
            "The year opens around home, family and emotional security.",
            "The year opens with more visibility and personal expression.",
            "The year opens with careful process, health and useful refinement.",
            "The year opens through partnership, balance and shared decisions.",
            "The year opens with deeper commitment and honest exchange.",
            "The year opens with wider horizons and more room to grow.",
            "The year opens with structure, responsibility and long-term goals.",
            "The year opens with new networks and a fresh way of doing things.",
            "The year opens with intuition, imagination and softer boundaries.",
        ]
        let zh = [
            "这一年以主动出击、开新局的方式开场。",
            "这一年从打稳基础、经营资源、慢慢来开始。",
            "这一年从多交流、多尝试、多走动开始。",
            "这一年从安顿家与内心安全感开始。",
            "这一年从更被看见、更敢表达自己开始。",
            "这一年从梳理流程、照顾健康、把细节做扎实开始。",
            "这一年从关系、平衡与共同决定开始。",
            "这一年从深谈、交底和更认真的承诺开始。",
            "这一年从视野放宽、给自己更多空间开始。",
            "这一年从立目标、扛责任、搭框架开始。",
            "这一年从换圈子、换思路开始。",
            "这一年从凭直觉走、让感受参与决定开始。",
        ]
        return language == .english ? en[signIndex] : zh[signIndex]
    }

    static func rulerNote(_ body: CelestialBody, language: AppLanguage) -> String {
        switch language {
        case .english:
            return switch body {
            case .sun: "The year's direction runs through your identity and what you choose to stand for."
            case .moon: "The year's direction runs through your feelings, home and what makes you feel safe."
            case .mercury: "The year's direction runs through learning, conversation and how you handle information."
            case .venus: "The year's direction runs through relationships, values and what feels good to build."
            case .mars: "The year's direction runs through initiative, drive and how you take action."
            case .jupiter: "The year's direction runs through growth, opportunity and a wider view."
            case .saturn: "The year's direction runs through structure, discipline and long-term responsibility."
            case .uranus: "The year's direction runs through change, freedom and doing things differently."
            case .neptune: "The year's direction runs through imagination, inspiration and intuition."
            case .pluto: "The year's direction runs through transformation, power and letting go of what no longer fits."
            case .trueNode: "The year's direction runs toward where you are genuinely meant to grow."
            }
        case .simplifiedChinese:
            return switch body {
            case .sun: "这一年的主线，是你想成为谁、愿意为什么站出来。"
            case .moon: "这一年的主线，是你的感受、家和安全感。"
            case .mercury: "这一年的主线，是学习、沟通和信息处理。"
            case .venus: "这一年的主线，是关系、价值观和你想经营好的东西。"
            case .mars: "这一年的主线，是行动力、冲劲和你怎么出手。"
            case .jupiter: "这一年的主线，是成长、机会和更大的视野。"
            case .saturn: "这一年的主线，是结构、自律和长期的责任。"
            case .uranus: "这一年的主线，是改变、自由和不走老路。"
            case .neptune: "这一年的主线，是想象、灵感与直觉。"
            case .pluto: "这一年的主线，是深度转变、重新掌控，以及放下不再合适的东西。"
            case .trueNode: "这一年的主线，是走向你真正该成长的地方。"
            }
        }
    }

    static func sunHouseNote(house: Int, language: AppLanguage) -> String {
        let en = [
            "Personal presence and first impressions need your attention.",
            "Money, income and personal resources are the year's focus.",
            "Learning, communication and daily exchanges carry the year.",
            "Home, family and inner foundation need your attention.",
            "Creativity, romance and personal joy come forward.",
            "Work, routines and sustainable pace need attention.",
            "Partnership and one-to-one agreements are the year's theme.",
            "Shared resources, trust and deeper commitments matter.",
            "Beliefs, study and broader horizons expand the year.",
            "Career, reputation and public role are the year's focus.",
            "Friends, networks and long-term goals move forward.",
            "Rest, inner life and letting go shape the year quietly.",
        ]
        let zh = [
            "自我形象与第一印象，需要你认真对待。",
            "收入与个人资源，是今年的重点。",
            "学习、沟通与日常交流，撑起这一年。",
            "家、家人与内在根基，需要你安顿。",
            "创造力、恋爱与个人乐趣，会走到台前。",
            "工作、习惯与可持续的节奏，需要认真打理。",
            "关系与合作约定，是今年的主题。",
            "共同资源、信任与更深层的承诺，是今年的功课。",
            "信念、深造与更远的视野，会打开这一年。",
            "事业、名声与公共角色，是今年的焦点。",
            "朋友、圈子与长期目标，会向前推进。",
            "休息、内心生活与放下，会安静地塑造这一年。",
        ]
        let index = max(1, min(12, house)) - 1
        return language == .english ? en[index] : zh[index]
    }

    static func angularNote(axis: String, language: AppLanguage) -> String {
        let en: [String: String] = [
            "MC": "Growth becomes visible through career and public reach.",
            "IC": "The year runs through home, family and inner foundation.",
            "ASC": "The year begins through personal initiative and presence.",
            "DSC": "The year moves through partnership and one-to-one agreements.",
        ]
        let zh: [String: String] = [
            "MC": "成长会通过事业和公共身份变得可见。",
            "IC": "这一年的主线，落在家庭、家人与内在根基上。",
            "ASC": "这一年从你亲自出手、亲自亮相开始。",
            "DSC": "这一年经关系与合作约定展开。",
        ]
        return (language == .english ? en[axis] : zh[axis]) ?? ""
    }

    static func angularAxisName(_ axis: String, language: AppLanguage) -> String {
        let en: [String: String] = ["MC": "Midheaven", "IC": "IC", "ASC": "Ascendant", "DSC": "Descendant"]
        let zh: [String: String] = ["MC": "天顶", "IC": "天底", "ASC": "上升", "DSC": "下降"]
        return (language == .english ? en[axis] : zh[axis]) ?? axis
    }
}
