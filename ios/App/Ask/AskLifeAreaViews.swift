import AstroCore
import SwiftUI

struct LifeAreaPickerButton: View {
    let title: String
    @Binding var primary: Int?
    @Binding var related: Set<Int>
    var excluding: Set<Int> = []
    let language: AppLanguage
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                    Text(summary)
                        .font(AppTypography.supporting)
                        .foregroundStyle(primary == nil ? AppTheme.muted : AppTheme.violet)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ask-life-area-picker")
        .sheet(isPresented: $isPresented) {
            LifeAreaPickerSheet(
                title: title,
                primary: $primary,
                related: $related,
                excluding: excluding,
                allowsPrimary: true,
                language: language
            )
        }
    }

    private var summary: String {
        guard let primary else {
            return localized("ask.select-life-areas", language: language)
        }
        let relatedNames = related.subtracting([primary]).sorted().map {
            askLifeAreaTitle($0, language: language)
        }
        if relatedNames.isEmpty {
            return askLifeAreaTitle(primary, language: language)
        }
        return askLifeAreaTitle(primary, language: language) + " · " + relatedNames.joined(separator: ", ")
    }
}

struct AdditionalLifeAreaPickerButton: View {
    let title: String
    @Binding var selection: Set<Int>
    let excluding: Set<Int>
    let language: AppLanguage
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                    Text(summary)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            LifeAreaPickerSheet(
                title: title,
                primary: .constant(nil),
                related: $selection,
                excluding: excluding,
                allowsPrimary: false,
                language: language
            )
        }
    }

    private var summary: String {
        let names = selection.subtracting(excluding).sorted().map {
            askLifeAreaTitle($0, language: language)
        }
        return names.isEmpty
            ? localized("common.none", language: language)
            : names.joined(separator: ", ")
    }
}

struct LifeAreaPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var primary: Int?
    @Binding var related: Set<Int>
    let excluding: Set<Int>
    let allowsPrimary: Bool
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            List(1 ... 12, id: \.self) { house in
                let selected = primary == house || related.contains(house)
                let disabled = excluding.contains(house) && !selected
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 12) {
                        Button { toggle(house) } label: {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? AppTheme.violet : AppTheme.muted)
                                .frame(width: 32, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                        .accessibilityIdentifier("ask-life-area-toggle-\(house)")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(askLifeAreaTitle(house, language: language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(disabled ? AppTheme.muted : AppTheme.text)
                            Text(askLifeAreaDescription(house, language: language))
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 4)
                        if allowsPrimary, primary == house {
                            Text(localized("ask.primary", language: language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 9)
                                .frame(minHeight: 32)
                                .background(AppTheme.violet, in: Capsule())
                        } else if allowsPrimary, related.contains(house) {
                            Text(localized("ask.related", language: language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.violet)
                        }
                    }

                    if allowsPrimary, related.contains(house) {
                        Button { makePrimary(house) } label: {
                            Label(
                                localized("ask.set-as-primary", language: language),
                                systemImage: "arrow.up.circle"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .padding(.leading, 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ask-life-area-set-primary-\(house)")
                    }
                }
                .contentShape(Rectangle())
                .opacity(disabled ? 0.55 : 1)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: language)) { dismiss() }
                        .disabled(allowsPrimary && primary == nil && !related.isEmpty)
                }
            }
        }
    }

    private func toggle(_ house: Int) {
        guard !excluding.contains(house) || primary == house || related.contains(house) else { return }
        if primary == house {
            primary = nil
        } else if related.contains(house) {
            related.remove(house)
        } else if allowsPrimary, primary == nil, related.isEmpty {
            primary = house
        } else {
            related.insert(house)
        }
    }

    private func makePrimary(_ house: Int) {
        guard allowsPrimary else { return }
        if let previous = primary, previous != house {
            related.insert(previous)
        }
        related.remove(house)
        primary = house
    }
}

struct ABCLifeAreasHelpView: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(ScreenBackground())
            .navigationTitle(localized("ask.life-areas-help", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: language)) { dismiss() }
                }
            }
        }
    }

    private var attributedText: AttributedString {
        let resource = "abc-life-areas-help-\(language.helpResourceCode)"
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8),
              let value = try? AttributedString(markdown: markdown)
        else {
            return AttributedString(localized("ask.help-unavailable", language: language))
        }
        return value
    }
}

private extension AppLanguage {
    var helpResourceCode: String {
        switch self {
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .spanish: "es"
        case .french: "fr"
        case .turkish: "tr"
        case .german: "de"
        case .italian: "it"
        case .portugueseBrazil: "pt-BR"
        case .korean: "ko"
        }
    }
}

private func askLifeAreaTitle(_ house: Int, language: AppLanguage) -> String {
    let keys = [
        "ask.house-area.1", "ask.house-area.2", "ask.house-area.3", "ask.house-area.4",
        "ask.house-area.5", "ask.house-area.6", "ask.house-area.7", "ask.house-area.8",
        "ask.house-area.9", "ask.house-area.10", "ask.house-area.11", "ask.house-area.12",
    ]
    return localized(keys[min(12, max(1, house)) - 1], language: language)
}

private func askLifeAreaDescription(_ house: Int, language: AppLanguage) -> String {
    let keys = [
        "ask.house-area-description.1", "ask.house-area-description.2",
        "ask.house-area-description.3", "ask.house-area-description.4",
        "ask.house-area-description.5", "ask.house-area-description.6",
        "ask.house-area-description.7", "ask.house-area-description.8",
        "ask.house-area-description.9", "ask.house-area-description.10",
        "ask.house-area-description.11", "ask.house-area-description.12",
    ]
    return localized(keys[min(12, max(1, house)) - 1], language: language)
}

