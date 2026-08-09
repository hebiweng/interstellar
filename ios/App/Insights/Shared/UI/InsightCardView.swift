import SwiftUI

// MARK: - Card container (prototype .card surface)

struct InsightCardView: View {
    let card: InsightCardModel
    let language: AppLanguage
    var prototypeTransitStyle = false
    var externalHeaderStyle = false
    @State private var showsSynastryOverviewDetail = false
    @State private var showsSynastryCardDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !externalHeaderStyle,
               (!isPrototypeTransitCard || card.id == "current-story"),
               let kicker = cardKicker(card.id, language: language),
               !kicker.isEmpty
            {
                Text(kicker.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.violet)
            }
            if !externalHeaderStyle {
                Text(card.title.isEmpty ? card.summary : card.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let presentation = synastryOverviewPresentation {
                Text("\(presentation.firstName) + \(presentation.secondName)".uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.80, green: 0.75, blue: 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("\(presentation.firstName) and \(presentation.secondName)")
            }

            if showsGenericCopy, let text = card.text {
                if let headline = text.headline, !headline.isEmpty, headline != card.title {
                    Text(headline)
                        .font(.system(size: heroHeadline ? 21 : 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = text.body, !body.isEmpty, body != text.headline {
                    Text(body)
                        .font(.system(size: heroHeadline ? 11 : 11.5, weight: .medium))
                        .foregroundStyle(heroHeadline ? AppTheme.muted : AppTheme.text.opacity(0.95))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.id != "current-story",
                   let secondary = text.secondaryBody,
                   !secondary.isEmpty
                {
                    Text(secondary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if showsGenericCopy,
                      !card.facts.isEmpty,
                      !card.summary.isEmpty,
                      card.summary != card.title
            {
                Text(card.summary)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.text.opacity(0.95))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if card.id == "current-story",
               let roleTexts = card.text?.roleTexts,
               !roleTexts.isEmpty
            {
                storyRoleWeave(roleTexts, result: card.text?.secondaryBody)
            } else {
                InsightVisualView(visual: card.visual, facts: card.facts, text: card.text, language: language)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [AppTheme.panelRaised, AppTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            if synastryOverviewPresentation != nil {
                showsSynastryOverviewDetail = true
            } else if synastryDetailCardIDs.contains(card.id) {
                showsSynastryCardDetail = true
            }
        }
        .sheet(isPresented: $showsSynastryOverviewDetail) {
            if let presentation = synastryOverviewPresentation {
                SynastryOverviewDetailSheet(
                    card: card,
                    presentation: presentation,
                    language: language
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.panel)
            }
        }
        .sheet(isPresented: $showsSynastryCardDetail) {
            SynastryCardDetailSheet(card: card, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.panel)
        }
    }

    private var isPrototypeTransitCard: Bool {
        prototypeTransitStyle && TransitContentPlan.cardIDs.contains(card.id)
    }

    private var showsGenericCopy: Bool {
        (!isPrototypeTransitCard || card.id == "current-story")
            && !synastryStructuredCardIDs.contains(card.id)
    }

    private var heroHeadline: Bool {
        card.id == "current-story" || card.id == "relationship-overview"
    }

    private var synastryOverviewPresentation: SynastryOverviewPresentation? {
        guard card.id == "relationship-overview",
              case let .bondOrbit(presentation) = card.visual
        else { return nil }
        return presentation
    }

    private var synastryStructuredCardIDs: Set<String> {
        ["perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"]
    }

    private var synastryDetailCardIDs: Set<String> {
        ["emotional-connection", "communication", "chemistry", "commitment"]
    }

}

func cardKicker(_ id: String, language: AppLanguage) -> String? {
    switch id {
    case "sky-overview": return localized("card.sky-overview.eyebrow", default: "SKY NOW", chinese: "当前天空", language: language)
    case "moon-now": return localized("MOON NOW", "此刻月亮", language: language)
    case "aspect-pattern": return localized("ASPECT PATTERN", "连接结构", language: language)
    case "planetary-motion": return localized("PLANETARY MOTION", "行星运动", language: language)
    case "sign-changes": return localized("SIGN CHANGES", "换座", language: language)
    case "element-climate": return localized("ELEMENT CLIMATE", "元素气候", language: language)
    case "upcoming-7-days": return localized("UPCOMING 7 DAYS", "未来七天", language: language)
    case "natal-interpretation": return localized("CORE PERSONALITY", "核心性格", language: language)
    case "emotional-needs": return localized("EMOTIONAL NEEDS", "情绪需要", language: language)
    case "love-connection": return localized("LOVE & CONNECTION", "爱与连接", language: language)
    case "career-direction": return localized("PUBLIC DIRECTION", "公共方向", language: language)
    case "strengths-growth": return localized("YOUR EDGES", "你的优势与成长面", language: language)
    case "element-balance": return localized("TEMPERAMENT", "气质", language: language)
    case "house-emphasis": return localized("CONCENTRATION", "侧重", language: language)
    case "chart-signature": return localized("SIGNATURE", "签名", language: language)
    case "planet-placements": return localized("PLACEMENTS", "落座", language: language)
    case "key-aspects": return localized("KEY ASPECTS", "关键连接", language: language)
    case "current-story": return localized("THE BIG PICTURE", "大局", language: language)
    case "current-cycles": return localized("CYCLES", "周期", language: language)
    case "transit-timeline": return localized("TIMELINE", "时间线", language: language)
    case "planet-paths": return localized("PLANET PATHS", "行星路径", language: language)
    case "life-areas": return localized("LIFE AREAS", "生活领域", language: language)
    case "active-transits": return localized("ACTIVE TRANSITS", "进行中的变化", language: language)
    case "developmental-chapter": return localized("CURRENT DEVELOPMENT", "当前发展", language: language)
    case "progressed-moon": return localized("PROGRESSED MOON", "长期月亮", language: language)
    case "identity-development": return localized("IDENTITY", "身份", language: language)
    case "turning-points": return localized("TURNING POINTS", "转折点", language: language)
    case "areas-maturing": return localized("MATURING", "成熟领域", language: language)
    case "timeline": return localized("24-MONTH TIMELINE", "长期时间线", language: language)
    case "year-theme": return localized("YEAR THEME", "年度主题", language: language)
    case "year-anchors": return localized("YEAR ANCHORS", "年度锚点", language: language)
    case "priority-areas": return localized("PRIORITY AREAS", "优先领域", language: language)
    case "year-dynamics": return localized("YEAR DYNAMICS", "年度动态", language: language)
    case "year-timeline": return localized("YEAR TIMELINE", "年度时间线", language: language)
    case "natal-overlay": return localized("NATAL OVERLAY", "与本命叠加", language: language)
    case "year-aspects": return localized("YEAR ASPECTS", "年度连接", language: language)
    case "relationship-overview": return localized("THE BOND", "这段关系", language: language)
    case "perspectives": return localized("PERSPECTIVES", "彼此的体验", language: language)
    case "emotional-connection": return localized("EMOTIONAL CONNECTION", "情感连接", language: language)
    case "communication": return localized("COMMUNICATION", "沟通", language: language)
    case "chemistry": return localized("CHEMISTRY", "化学反应", language: language)
    case "commitment": return localized("COMMITMENT", "承诺", language: language)
    case "house-overlays": return localized("HOUSE OVERLAYS", "落宫叠加", language: language)
    case "key-inter-aspects": return localized("KEY INTER-ASPECTS", "主要相互连接", language: language)
    default: return nil
    }
}
