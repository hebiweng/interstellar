import PhotosUI
import AstroCore
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsSettings = false
    @State private var showsEditor = false
    @State private var editingPerson: SavedPerson?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenTitle(
                            eyebrow: localized("YOUR PROFILE", "个人资料", language: model.language),
                            title: localized("Profile", "我的", language: model.language)
                        )
                        profileHero
                        birthDetails
                        Button {
                            showsEditor = true
                        } label: {
                            Label(
                                localized("Edit birth details", "编辑出生资料", language: model.language),
                                systemImage: "pencil"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)

                        peopleSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.text)
                    }
                    .accessibilityLabel(localized("Settings", "设置", language: model.language))
                }
            }
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showsEditor) {
                ProfileEditorView(profile: model.profile, language: model.language) { profile in
                    model.profile = profile
                    Task { await model.refresh() }
                }
            }
            .sheet(item: $editingPerson) { person in
                SavedPersonEditorView(person: person, language: model.language) {
                    model.savePerson($0)
                } onDelete: {
                    if let index = model.savedPeople.firstIndex(where: { $0.id == person.id }) {
                        model.deletePeople(at: IndexSet(integer: index))
                    }
                }
            }
        }
    }

    private var profileHero: some View {
        HStack(spacing: 16) {
            ProfileAvatarView(profile: model.profile, size: 68)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.profile.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(model.profile.placeName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
        .cardSurface()
    }

    private var birthDetails: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: "calendar",
                title: localized("Birth date & time", "出生日期与时间", language: model.language),
                value: formattedBirthDate
            )
            Divider().overlay(AppTheme.line)
            detailRow(
                icon: "mappin.and.ellipse",
                title: localized("Birth place", "出生地点", language: model.language),
                value: model.profile.placeName
            )
            Divider().overlay(AppTheme.line)
            detailRow(
                icon: "clock",
                title: localized("Time zone", "时区", language: model.language),
                value: model.profile.timezoneID
            )
            Divider().overlay(AppTheme.line)
            detailRow(
                icon: "location",
                title: localized("Coordinates", "经纬度", language: model.language),
                value: String(format: "%.4f, %.4f", model.profile.latitude, model.profile.longitude)
            )
        }
        .cardSurface()
    }

    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: model.profile.birthDateUTC)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(AppTheme.muted)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("PEOPLE", "人物档案", language: model.language))
                        .font(.footnote.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.violet)
                    Text(localized("People you know", "我认识的人", language: model.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
                Spacer()
                Button {
                    editingPerson = SavedPerson.new(using: model.profile)
                } label: {
                    Label(
                        localized("Add", "添加", language: model.language),
                        systemImage: "plus"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if model.savedPeople.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .foregroundStyle(AppTheme.violet)
                    Text(
                        localized(
                            "Add someone once, then reuse their birth details in future relationship charts.",
                            "人物资料只需添加一次，后续合盘可以直接选择使用。",
                            language: model.language
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.savedPeople.enumerated()), id: \.element.id) { index, person in
                        Button {
                            editingPerson = person
                        } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(profile: person.profile, size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(person.profile.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(
                                        "\(person.relationship.title(language: model.language)) · \(person.profile.placeName)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                    .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                model.deletePeople(at: IndexSet(integer: index))
                            } label: {
                                Label(
                                    localized("Delete", "删除", language: model.language),
                                    systemImage: "trash"
                                )
                            }
                        }
                        if index < model.savedPeople.count - 1 {
                            Divider().overlay(AppTheme.line)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.line))
            }
        }
    }

}

private struct ProfileAvatarView: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let data = profile.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(profile.initials.isEmpty ? "✦" : profile.initials)
                    .font(.system(size: size * 0.31, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.violet, AppTheme.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}

private struct SavedPersonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SavedPerson
    @State private var showsLocationSearch = false
    @State private var avatarItem: PhotosPickerItem?
    let language: AppLanguage
    let onSave: (SavedPerson) -> Void
    let onDelete: () -> Void

    init(
        person: SavedPerson,
        language: AppLanguage,
        onSave: @escaping (SavedPerson) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _draft = State(initialValue: person)
        self.language = language
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Person", "人物", language: language)) {
                    HStack {
                        ProfileAvatarView(profile: draft.profile, size: 58)
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Label(
                                localized("Change photo", "更换头像", language: language),
                                systemImage: "photo"
                            )
                        }
                        if draft.profile.avatarData != nil {
                            Button(localized("Remove", "移除", language: language), role: .destructive) {
                                draft.profile.avatarData = nil
                            }
                        }
                    }
                    TextField(
                        localized("Name", "姓名", language: language),
                        text: $draft.profile.name
                    )
                    Picker(
                        localized("Relationship to me", "与我的关系", language: language),
                        selection: $draft.relationship
                    ) {
                        ForEach(PersonRelationship.allCases) { relationship in
                            Text(relationship.title(language: language)).tag(relationship)
                        }
                    }
                }

                Section(localized("Birth", "出生资料", language: language)) {
                    DatePicker(
                        localized("Date & time", "日期与时间", language: language),
                        selection: $draft.profile.birthDateUTC,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField(
                        localized("Place", "地点", language: language),
                        text: $draft.profile.placeName
                    )
                    TextField(
                        localized("Time zone", "时区", language: language),
                        text: $draft.profile.timezoneID
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button {
                        showsLocationSearch = true
                    } label: {
                        Label(
                            localized("Choose on Apple Maps", "在 Apple 地图中选址", language: language),
                            systemImage: "map"
                        )
                    }
                    TextField(
                        localized("Latitude", "纬度", language: language),
                        value: $draft.profile.latitude,
                        format: .number.precision(.fractionLength(0 ... 6))
                    )
                    .keyboardType(.numbersAndPunctuation)
                    TextField(
                        localized("Longitude", "经度", language: language),
                        value: $draft.profile.longitude,
                        format: .number.precision(.fractionLength(0 ... 6))
                    )
                    .keyboardType(.numbersAndPunctuation)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label(
                            localized("Delete person", "删除人物", language: language),
                            systemImage: "trash"
                        )
                    }
                }
            }
            .environment(
                \.timeZone,
                TimeZone(identifier: draft.profile.timezoneID) ?? .current
            )
            .navigationTitle(localized("Person details", "人物资料", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Cancel", "取消", language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Save", "保存", language: language)) {
                        draft.profile.latitude = min(90, max(-90, draft.profile.latitude))
                        draft.profile.longitude = min(180, max(-180, draft.profile.longitude))
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || draft.profile.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || TimeZone(identifier: draft.profile.timezoneID) == nil
                    )
                }
            }
            .sheet(isPresented: $showsLocationSearch) {
                LocationSearchView(language: language) { apply($0) }
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { draft.profile.avatarData = data }
                    }
                }
            }
        }
    }

    private func apply(_ selection: LocationSelection) {
        draft.profile.placeName = selection.name == "Current Location"
            ? localized("Current Location", "当前位置", language: language)
            : selection.name
        draft.profile.latitude = selection.latitude
        draft.profile.longitude = selection.longitude
        draft.profile.timezoneID = selection.timezoneID
    }
}

private enum LocalDataClear: Identifiable {
    case reports
    case askHistory
    case aiCache
    case currentPersonArtifacts
    case chartArtifacts(ChartKind)
    case personArtifacts(SavedPerson)

    var id: String {
        switch self {
        case .reports: "reports"
        case .askHistory: "askHistory"
        case .aiCache: "aiCache"
        case .currentPersonArtifacts: "currentPersonArtifacts"
        case let .chartArtifacts(chart): "chartArtifacts.\(chart.rawValue)"
        case let .personArtifacts(person): "personArtifacts.\(person.id.uuidString)"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .reports:
            localized("This removes all saved chart reports from this device.", "这会删除本机保存的全部星盘报告。", language: language)
        case .askHistory:
            localized("This removes your saved horary questions.", "这会删除你保存的问事记录。", language: language)
        case .aiCache:
            localized("Generated interpretations will be regenerated next time you open them.", "下次打开时，生成内容会重新请求。", language: language)
        case .currentPersonArtifacts:
            localized("This removes locally generated chart reports linked to your current birth profile.", "这会删除与当前本人出生资料关联的本机生成报告。", language: language)
        case let .chartArtifacts(chart):
            localized(
                "This removes locally generated reports for \(chart.title(language: .english)).",
                "这会删除本机的\(chart.title(language: .simplifiedChinese))生成报告。",
                language: language
            )
        case let .personArtifacts(person):
            localized(
                "This removes locally generated reports linked to \(person.profile.name).",
                "这会删除与\(person.profile.name)关联的本机生成报告。",
                language: language
            )
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label(localized("Appearance", "外观", language: model.language), systemImage: "circle.lefthalf.filled")
            }
            NavigationLink {
                InterpretationDefaultsSettingsView()
            } label: {
                Label(localized("Interpretation Defaults", "解读预设", language: model.language), systemImage: "slider.horizontal.3")
            }
            NavigationLink {
                LanguageSettingsView()
            } label: {
                Label(localized("Language", "语言", language: model.language), systemImage: "globe")
            }
            NavigationLink {
                LocalDataSettingsView()
            } label: {
                Label(localized("Local Data", "本地数据", language: model.language), systemImage: "internaldrive")
            }
            NavigationLink {
                SupportSettingsView()
            } label: {
                Label(localized("Support", "支持", language: model.language), systemImage: "questionmark.bubble")
            }
            NavigationLink {
                AboutSettingsView()
            } label: {
                Label(localized("About", "关于", language: model.language), systemImage: "info.circle")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(localized("Settings", "设置", language: model.language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker(localized("Theme", "主题", language: model.language), selection: $model.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title(language: model.language)).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Picker(localized("Text size", "字体大小", language: model.language), selection: $model.fontSize) {
                ForEach(AppFontSize.allCases) { size in
                    Text(size.title(language: model.language)).tag(size)
                }
            }
            .pickerStyle(.navigationLink)
        }
        .settingsDetailStyle(title: localized("Appearance", "外观", language: model.language))
    }
}

private struct InterpretationDefaultsSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ChartKind.allCases) { chart in
                    Picker(
                        chart.title(language: model.language),
                        selection: Binding(
                            get: { model.preset(for: chart) },
                            set: { model.setPreset($0, for: chart) }
                        )
                    ) {
                        ForEach(CalculationPreset.consumerCases) { preset in
                            Text(preset.title(language: model.language)).tag(preset)
                        }
                    }
                }
            } footer: {
                Text(localized(
                    "Modern and Classical change how each chart is calculated.",
                    "现代与古典会改变每张盘的计算方式。",
                    language: model.language
                ))
            }
        }
        .settingsDetailStyle(title: localized("Interpretation Defaults", "解读预设", language: model.language))
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker(localized("App language", "应用语言", language: model.language), selection: $model.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.inline)
        }
        .settingsDetailStyle(title: localized("Language", "语言", language: model.language))
    }
}

private struct LocalDataSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pendingClear: LocalDataClear?

    var body: some View {
        Form {
            Section {
                Label(localized("Local-first calculations", "本地优先计算", language: model.language), systemImage: "lock.shield")
                Text(localized(
                    "Interstellar does not require an account for chart calculation.",
                    "Interstellar 的星盘计算不要求注册账户。",
                    language: model.language
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                Toggle(
                    localized("Allow new AI generation", "允许新的 AI 生成", language: model.language),
                    isOn: Binding(
                        get: { model.aiConsentGranted },
                        set: { $0 ? model.grantAIConsent() : model.revokeAIConsent() }
                    )
                )
                Text(localized(
                    "Turning this off stops future network requests. Reports already stored on this device remain readable.",
                    "关闭后不再发送新的联网请求；已经保存在本机的报告仍可阅读。",
                    language: model.language
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Button { pendingClear = .reports } label: {
                    Label(localized("Clear saved reports", "清除已保存报告", language: model.language), systemImage: "doc.text")
                }
                Button { pendingClear = .askHistory } label: {
                    Label(localized("Clear ask history", "清除问事历史", language: model.language), systemImage: "questionmark.circle")
                }
                Button { pendingClear = .aiCache } label: {
                    Label(localized("Clear generated content cache", "清除生成内容缓存", language: model.language), systemImage: "sparkles")
                }
                Menu {
                    Button(model.profile.name) { pendingClear = .currentPersonArtifacts }
                    ForEach(model.savedPeople) { person in
                        Button(person.profile.name) { pendingClear = .personArtifacts(person) }
                    }
                } label: {
                    Label(localized("Clear by person", "按人物清除", language: model.language), systemImage: "person.crop.circle.badge.minus")
                }
                Menu {
                    ForEach(ChartKind.allCases) { chart in
                        Button(chart.title(language: model.language)) { pendingClear = .chartArtifacts(chart) }
                    }
                } label: {
                    Label(localized("Clear by chart type", "按盘型清除", language: model.language), systemImage: "square.stack.3d.up.slash")
                }
            } footer: {
                Text(localized(
                    "Clearing removes data stored on this device only.",
                    "清除只会删除保存在本机的数据。",
                    language: model.language
                ))
            }
        }
        .settingsDetailStyle(title: localized("Local Data", "本地数据", language: model.language))
        .confirmationDialog(
            localized("Clear data?", "确认清除？", language: model.language),
            isPresented: Binding(
                get: { pendingClear != nil },
                set: { if !$0 { pendingClear = nil } }
            ),
            presenting: pendingClear
        ) { item in
            Button(localized("Clear", "清除", language: model.language), role: .destructive) {
                switch item {
                case .reports: model.clearReports()
                case .askHistory: model.clearAskHistory()
                case .aiCache: model.clearAICache()
                case .currentPersonArtifacts: model.clearGeneratedArtifactsForCurrentPerson()
                case let .chartArtifacts(chart): model.clearGeneratedArtifacts(for: chart)
                case let .personArtifacts(person): model.clearGeneratedArtifacts(for: person)
                }
                pendingClear = nil
            }
            Button(localized("Cancel", "取消", language: model.language), role: .cancel) {
                pendingClear = nil
            }
        } message: { item in
            Text(item.message(language: model.language))
        }
    }
}

private struct SupportSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            NavigationLink {
                FeedbackView(language: model.language)
            } label: {
                Label(
                    localized("Report or suggest a feature", "问题反馈与功能建议", language: model.language),
                    systemImage: "exclamationmark.bubble"
                )
            }
        }
        .settingsDetailStyle(title: localized("Support", "支持", language: model.language))
    }
}

private struct AboutSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            LabeledContent(localized("Version", "版本", language: model.language), value: "0.1.0")
            LabeledContent(localized("Calculation", "计算引擎", language: model.language), value: "Swiss Ephemeris")
            LabeledContent(localized("Editorial content", "原创解读内容", language: model.language), value: "© 2026 Interstellar")
            NavigationLink(localized("Open-source licenses", "开源许可证", language: model.language)) {
                LicenseView(language: model.language)
            }
        }
        .settingsDetailStyle(title: localized("About", "关于", language: model.language))
    }
}

private extension View {
    func settingsDetailStyle(title: String) -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bug
    case feature
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .bug: localized("Bug", "问题", language: language)
        case .feature: localized("Feature", "功能建议", language: language)
        case .other: localized("Other", "其他", language: language)
        }
    }
}

private struct FeedbackRequestBody: Encodable {
    let type: String
    let content: String
    let contact: String
}

private enum FeedbackSubmissionError: LocalizedError {
    case invalidResponse
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The feedback service returned an invalid response."
        case let .rejected(status): "The feedback service returned status \(status)."
        }
    }
}

private enum FeedbackService {
    private static let endpoint = URL(
        string: "https://fate.xiaoguiwk.top/api/v1/feedback"
    )!

    static func submit(
        category: FeedbackCategory,
        content: String,
        contact: String
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FeedbackRequestBody(
                type: category.rawValue,
                content: content,
                contact: contact
            )
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackSubmissionError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw FeedbackSubmissionError.rejected(http.statusCode)
        }
    }
}

private struct FeedbackView: View {
    let language: AppLanguage
    @State private var category: FeedbackCategory = .bug
    @State private var subject = ""
    @State private var message = ""
    @State private var contact = ""
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var lastSubmission: String?

    var body: some View {
        Form {
            Section(localized("Feedback type", "反馈类型", language: language)) {
                Picker(
                    localized("Type", "类型", language: language),
                    selection: $category
                ) {
                    ForEach(FeedbackCategory.allCases) { item in
                        Text(item.title(language: language)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(localized("feedback.details.section", default: "Details", chinese: "反馈内容", language: language)) {
                TextField(
                    localized("Short title", "简短标题", language: language),
                    text: $subject
                )
                TextField(
                    localized(
                        "What happened, or what would you like us to add?",
                        "请描述遇到的问题，或希望增加的功能。",
                        language: language
                    ),
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(5 ... 12)
                TextField(
                    localized("Contact (optional)", "联系方式（可选）", language: language),
                    text: $contact
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().padding(.trailing, 6)
                        }
                        Text(
                            isSubmitting
                                ? localized("Sending…", "正在提交…", language: language)
                                : localized("Send feedback", "提交反馈", language: language)
                        )
                        .font(AppTypography.label)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .disabled(isSubmitting || subject.trimmed.isEmpty || message.trimmed.isEmpty)
            } footer: {
                Text(
                    localized(
                        "Feedback uses the network and includes the app version and device model, but never chart or birth data. AI interpretation uses the network only after separate consent in Settings.",
                        "反馈会联网并附带应用版本和设备型号，但不会附带星盘或出生资料。AI 解读只有在你另行授权后才会联网。",
                        language: language
                    )
                )
                .font(AppTypography.supporting)
            }

            if let resultMessage {
                Section {
                    Label(
                        resultMessage,
                        systemImage: lastSubmission == nil
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(lastSubmission == nil ? AppTheme.mint : AppTheme.amber)
                    if let lastSubmission {
                        Button {
                            UIPasteboard.general.string = lastSubmission
                            self.resultMessage = localized(
                                "Feedback text copied.",
                                "反馈文字已复制。",
                                language: language
                            )
                            self.lastSubmission = nil
                        } label: {
                            Label(
                                localized("Copy feedback text", "复制反馈文字", language: language),
                                systemImage: "doc.on.doc"
                            )
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
        .navigationTitle(localized("Report", "反馈", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        let payload = composedMessage
        isSubmitting = true
        resultMessage = nil
        lastSubmission = nil
        Task {
            do {
                try await FeedbackService.submit(
                    category: category,
                    content: payload,
                    contact: contact.trimmed
                )
                await MainActor.run {
                    isSubmitting = false
                    subject = ""
                    message = ""
                    contact = ""
                    resultMessage = localized(
                        "Feedback sent. Thank you.",
                        "反馈已提交，谢谢。",
                        language: language
                    )
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    lastSubmission = payload
                    resultMessage = localized(
                        "Could not send feedback. You can copy it and try again later.",
                        "反馈暂时无法提交，你可以复制内容后稍后重试。",
                        language: language
                    )
                }
            }
        }
    }

    private var composedMessage: String {
        """
        \(subject.trimmed)

        \(message.trimmed)

        App: Interstellar 0.1.0
        Device: \(UIDevice.current.model)
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Locale: \(language.rawValue)
        """
    }
}

private struct LicenseView: View {
    let language: AppLanguage

    var body: some View {
        List {
            Section("Swiss Ephemeris") {
                Text(
                    localized(
                        "Swiss Ephemeris 2.10.3 is used under the GNU Affero General Public License. Copyright notices are preserved below.",
                        "Swiss Ephemeris 2.10.3 依据 GNU Affero 通用公共许可证使用，版权声明完整保留如下。",
                        language: language
                    )
                )
                .font(.footnote)
                NavigationLink(
                    localized("Swiss Ephemeris license notice", "Swiss Ephemeris 许可声明", language: language)
                ) {
                    LicenseTextView(
                        title: "Swiss Ephemeris",
                        resource: "LICENSE",
                        extension: nil,
                        language: language
                    )
                }
                NavigationLink(localized("GNU AGPL 3.0", "GNU AGPL 3.0 全文", language: language)) {
                    LicenseTextView(
                        title: "GNU AGPL 3.0",
                        resource: "agpl-3.0",
                        extension: "txt",
                        language: language
                    )
                }
            }

            Section(localized("Content rights", "内容权利", language: language)) {
                Text(
                    localized(
                        "Original interpretations, translations, editorial selection, and arrangement are separately copyrighted content and are not licensed under the AGPL merely because the application can load them.",
                        "原创解读、翻译、编辑选择与编排属于单独享有版权的内容；应用能够加载这些内容，不表示其自动依据 AGPL 授权。",
                        language: language
                    )
                )
                .font(.footnote)
            }
        }
        .navigationTitle(localized("Licenses", "许可证", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseTextView: View {
    let title: String
    let resource: String
    let `extension`: String?
    let language: AppLanguage

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(text)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: `extension`),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return localized(
                "License text is unavailable.",
                "许可证全文暂不可用。",
                language: language
            )
        }
        return text
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UserProfile
    @State private var showsLocationSearch = false
    @State private var avatarItem: PhotosPickerItem?
    let language: AppLanguage
    let onSave: (UserProfile) -> Void

    init(profile: UserProfile, language: AppLanguage, onSave: @escaping (UserProfile) -> Void) {
        _draft = State(initialValue: profile)
        self.language = language
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Identity", "人物", language: language)) {
                    HStack {
                        ProfileAvatarView(profile: draft, size: 58)
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Label(
                                localized("Change photo", "更换头像", language: language),
                                systemImage: "photo"
                            )
                        }
                        if draft.avatarData != nil {
                            Button(localized("Remove", "移除", language: language), role: .destructive) {
                                draft.avatarData = nil
                            }
                        }
                    }
                    TextField(localized("Name", "姓名", language: language), text: $draft.name)
                }
                Section(localized("Birth", "出生资料", language: language)) {
                    DatePicker(
                        localized("Date & time", "日期与时间", language: language),
                        selection: $draft.birthDateUTC,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField(localized("Place", "地点", language: language), text: $draft.placeName)
                    TextField(localized("Time zone", "时区", language: language), text: $draft.timezoneID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        showsLocationSearch = true
                    } label: {
                        Label(
                            localized("Choose on Apple Maps", "在 Apple 地图中选址", language: language),
                            systemImage: "map"
                        )
                    }
                    TextField(localized("Latitude", "纬度", language: language), value: $draft.latitude, format: .number.precision(.fractionLength(0 ... 6)))
                        .keyboardType(.numbersAndPunctuation)
                    TextField(localized("Longitude", "经度", language: language), value: $draft.longitude, format: .number.precision(.fractionLength(0 ... 6)))
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .environment(\.timeZone, TimeZone(identifier: draft.timezoneID) ?? .current)
            .navigationTitle(localized("Birth details", "出生资料", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Cancel", "取消", language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Save", "保存", language: language)) {
                        draft.latitude = min(90, max(-90, draft.latitude))
                        draft.longitude = min(180, max(-180, draft.longitude))
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || TimeZone(identifier: draft.timezoneID) == nil
                    )
                }
            }
            .sheet(isPresented: $showsLocationSearch) {
                LocationSearchView(language: language) { selection in
                    apply(selection)
                }
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { draft.avatarData = data }
                    }
                }
            }
        }
    }

    private func apply(_ selection: LocationSelection) {
        draft.placeName = selection.name == "Current Location"
            ? localized("Current Location", "当前位置", language: language)
            : selection.name
        draft.latitude = selection.latitude
        draft.longitude = selection.longitude
        draft.timezoneID = selection.timezoneID
    }
}
