import AstroCore
import SwiftUI

extension AskView {
    func configurationView(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            AskConfigurationHero(
                mode: mode,
                title: modeTitle(mode),
                subtitle: modeSubtitle(mode),
                language: model.language
            )

            switch mode {
            case .yesNo:
                yesNoFields
            case .choice:
                choiceFields
            case .timing:
                timingFields
            case .bestTime:
                bestTimeFields
            }

            locationAndTime(mode)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            }

            if isCalculating {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: mode == .bestTime ? progress : nil)
                        .tint(AppTheme.violet)
                    HStack {
                        Text(
                            localized("ask.calculating-the-horary-chart", language: model.language)
                        )
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Button(localized("location.cancel", language: model.language)) {
                            calculationTask?.cancel()
                        }
                        .font(AppTypography.label)
                    }
                }
                .cardSurface()
            } else {
                Button {
                    generate(mode)
                } label: {
                    Label(
                        mode == .timing
                            ? localized("ask.ask-when", language: model.language)
                            : (mode == .bestTime
                                ? localized("ask.find-the-best-time.9e18bc9", language: model.language)
                                : localized("ask.ask-the-chart.22f1126", language: model.language)),
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        canGenerate(mode) ? AppTheme.violet : AppTheme.muted.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate(mode))
            }
        }
    }

    var yesNoFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldTitle(localized("ask.your-question", language: model.language))
            TextField(
                localized("ask.for-example-will-this-application-move-forward", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(14)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15))

            LifeAreaPickerButton(
                title: localized("ask.select-life-areas", language: model.language),
                primary: $primaryHouse,
                related: $relatedHouses,
                language: model.language
            )
        }
        .cardSurface()
    }

    var choiceFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                fieldTitle(localized("ask.name-each-option", language: model.language))
                Spacer()
                Button {
                    showLifeAreasHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("ask.life-areas-help", language: model.language))
            }

            VStack(alignment: .leading, spacing: 11) {
                Text(localized("ask.shared-life-areas", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(localized("ask.do-all-options-belong-mainly-to-the-same-life-area", language: model.language))
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 9) {
                    sharedModeButton(true, title: localized("common.yes", language: model.language))
                    sharedModeButton(false, title: localized("common.no", language: model.language))
                }

                if sharedSamePrimary == true {
                    LifeAreaPickerButton(
                        title: localized("ask.shared-primary-area", language: model.language),
                        primary: $sharedPrimaryHouse,
                        related: $sharedRelatedHouses,
                        language: model.language
                    )
                } else if sharedSamePrimary == false {
                    AdditionalLifeAreaPickerButton(
                        title: localized("ask.shared-related-areas-optional", language: model.language),
                        selection: $sharedRelatedHouses,
                        excluding: [],
                        language: model.language
                    )
                }
            }
            .padding(13)
            .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))

            ForEach($options) { $option in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(
                            localized("ask.option", language: model.language)
                                + " \(optionLetter(option.id))"
                        )
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                        Spacer()
                        if options.count > 2 {
                            Button {
                                options.removeAll { $0.id == option.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.coral)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField(
                        localized("ask.what-is-this-option", language: model.language),
                        text: $option.label
                    )
                    .focused($focusedInputID, equals: option.id.uuidString)
                    .submitLabel(.done)
                    .onSubmit { focusedInputID = nil }
                    .textFieldStyle(.plain)
                    .padding(13)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))

                    if sharedSamePrimary == true {
                        AdditionalLifeAreaPickerButton(
                            title: localized("ask.additional-life-areas-optional", language: model.language),
                            selection: $option.additionalHouses,
                            excluding: Set([sharedPrimaryHouse].compactMap { $0 }).union(sharedRelatedHouses),
                            language: model.language
                        )
                    } else if sharedSamePrimary == false {
                        LifeAreaPickerButton(
                            title: localized("ask.select-life-areas", language: model.language),
                            primary: $option.primaryHouse,
                            related: $option.additionalHouses,
                            excluding: sharedRelatedHouses,
                            language: model.language
                        )
                    }
                }
                .padding(13)
                .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            }

            if options.count < 3 {
                Button {
                    options.append(AskOptionDraft())
                } label: {
                    Label(
                        localized("ask.add-another-option", language: model.language),
                        systemImage: "plus.circle.fill"
                    )
                    .font(AppTypography.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.violet)
            }
        }
        .cardSurface()
    }

    var timingFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle(localized("ask.when-question", language: model.language))
            TextField(
                localized("ask.when-placeholder", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(14)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15))

            LifeAreaPickerButton(
                title: localized("ask.select-life-areas", language: model.language),
                primary: $primaryHouse,
                related: $relatedHouses,
                language: model.language
            )

            Text(localized("ask.when-chart-note", language: model.language))
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
    }

    var bestTimeFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle(localized("ask.best-time-question", language: model.language))
            TextField(
                localized("ask.best-time-placeholder", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(14)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15))

            LifeAreaPickerButton(
                title: localized("ask.select-life-areas", language: model.language),
                primary: $primaryHouse,
                related: $relatedHouses,
                language: model.language
            )

            VStack(alignment: .leading, spacing: 10) {
                fieldTitle(localized("ask.best-time-window", language: model.language))
                HStack(spacing: 8) {
                    ForEach(BestTimeSearchWindow.allCases) { window in
                        Button {
                            bestTimeWindow = window
                        } label: {
                            Text(window.title(language: model.language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(bestTimeWindow == window ? Color.white : AppTheme.text)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(
                                    bestTimeWindow == window ? AppTheme.violet : AppTheme.panelRaised,
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(localized("ask.best-time-note", language: model.language))
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
    }

    func locationAndTime(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            fieldTitle(
                mode == .bestTime
                    ? localized("ask.best-time-start-date", language: model.language)
                    : localized("ask.chart-moment", language: model.language)
            )
            if mode == .bestTime {
                DatePicker(
                    "",
                    selection: $chartDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                DatePicker(
                    "",
                    selection: $chartDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            fieldTitle(localized("ask.location", language: model.language))
            Button {
                showsLocationPicker = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(location?.name ?? localized("ask.choose-a-location", language: model.language))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        if let location {
                            Text(location.timezoneID)
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .cardSurface()
    }


    func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.label)
            .foregroundStyle(AppTheme.text)
    }


    func canGenerate(_ mode: HoraryQuestionMode) -> Bool {
        guard location != nil else { return false }
        switch mode {
        case .yesNo:
            return !question.trimmed.isEmpty && primaryHouse != nil
        case .choice:
            return options.count >= 2
                && sharedSamePrimary != nil
                && options.allSatisfy {
                    !$0.label.trimmed.isEmpty && effectivePrimaryHouse(for: $0) != nil
                }
        case .timing:
            return !question.trimmed.isEmpty && primaryHouse != nil
        case .bestTime:
            return !question.trimmed.isEmpty && primaryHouse != nil
        }
    }

    func optionLetter(_ id: UUID) -> String {
        guard let index = options.firstIndex(where: { $0.id == id }) else { return "" }
        return String(UnicodeScalar(65 + index)!)
    }

    func effectivePrimaryHouse(for option: AskOptionDraft) -> Int? {
        sharedSamePrimary == true ? sharedPrimaryHouse : option.primaryHouse
    }

    func effectiveRelatedHouses(for option: AskOptionDraft) -> Set<Int> {
        guard let primary = effectivePrimaryHouse(for: option) else { return [] }
        return sharedRelatedHouses
            .union(option.additionalHouses)
            .subtracting([primary])
    }

    func sharedModeButton(_ value: Bool, title: String) -> some View {
        let selected = sharedSamePrimary == value
        return Button {
            sharedSamePrimary = value
            if value {
                for index in options.indices {
                    options[index].primaryHouse = nil
                }
            } else {
                sharedPrimaryHouse = nil
            }
        } label: {
            Text(title)
                .font(AppTypography.label)
                .foregroundStyle(selected ? Color.white : AppTheme.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected ? AppTheme.violet : AppTheme.panelRaised,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }


    func modeTitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo: localized("ask.will-it-happen", language: model.language)
        case .choice: localized("ask.which-one", language: model.language)
        case .timing: localized("ask.when", language: model.language)
        case .bestTime: localized("ask.find-the-best-time", language: model.language)
        }
    }

    func modeSubtitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo:
            localized("ask.keep-the-question-specific-and-choose-the-area-it-belongs-to", language: model.language)
        case .choice:
            localized("ask.name-the-real-options-and-choose-their-life-areas", language: model.language)
        case .timing:
            localized("ask.when-subtitle", language: model.language)
        case .bestTime:
            localized("ask.best-time-subtitle", language: model.language)
        }
    }

}

struct AskConfigurationHero: View {
    let mode: HoraryQuestionMode
    let title: String
    let subtitle: String
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            visual
                .frame(maxWidth: .infinity)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var visual: some View {
        switch mode {
        case .yesNo:
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.16), lineWidth: 1).frame(width: 64, height: 64)
                Circle().stroke(AppTheme.violet.opacity(0.28), lineWidth: 1).frame(width: 42, height: 42)
                Circle().fill(AppTheme.violet.opacity(0.18)).frame(width: 16, height: 16)
            }
            .frame(height: 78)

        case .timing:
            HStack(spacing: 0) {
                Circle().fill(AppTheme.violet).frame(width: 10, height: 10)
                Rectangle().fill(AppTheme.violet.opacity(0.25)).frame(height: 1)
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .foregroundStyle(AppTheme.violet)
            }
            .overlay(alignment: .bottomLeading) {
                Text(localized("themes.horizon.now", language: language).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .offset(y: 23)
            }
            .padding(.horizontal, 24)
            .frame(height: 78)

        case .bestTime:
            HStack(spacing: 0) {
                Circle().fill(AppTheme.mint.opacity(0.38)).frame(width: 8, height: 8)
                Rectangle().fill(AppTheme.mint.opacity(0.18)).frame(height: 1)
                Circle().fill(AppTheme.mint).frame(width: 12, height: 12)
                Rectangle().fill(AppTheme.mint.opacity(0.18)).frame(height: 1)
                Circle().fill(AppTheme.mint.opacity(0.38)).frame(width: 8, height: 8)
            }
            .overlay(alignment: .top) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mint)
                    .offset(y: -15)
            }
            .padding(.horizontal, 28)
            .frame(height: 78)

        case .choice:
            HStack(spacing: 12) {
                ForEach(["A", "B", "C"], id: \.self) { label in
                    Text(label)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.violet.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 78)
        }
    }
}
