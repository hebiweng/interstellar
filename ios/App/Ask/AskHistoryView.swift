import SwiftUI

struct AskHistoryView: View {
    @ObservedObject private var deepAnalysisStore = AskDeepAnalysisStore.shared
    @Binding var entries: [AskHistoryEntry]
    let language: AppLanguage
    let onOpen: (AskHistoryEntry) -> Void
    let onDelete: (AskHistoryEntry) -> Void
    @State private var pendingDelete: AskHistoryEntry?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle(
                        eyebrow: localized("ask.ask-history", language: language),
                        title: localized("ask.history", language: language),
                        subtitle: localized("ask.local-results-only", language: language)
                    )
                    if entries.isEmpty {
                        Text(localized("ask.no-questions-yet", language: language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .cardSurface()
                    } else {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                if entry.session != nil {
                                    Button {
                                        onOpen(entry)
                                    } label: {
                                        historySummary(entry, showsDisclosure: true)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("ask-history-entry-\(entry.id)")
                                } else {
                                    historySummary(entry, showsDisclosure: false)
                                }

                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.coral)
                                .accessibilityLabel(localized("profile.delete", language: language))
                            }
                            .padding(13)
                            .cardSurface()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(localized("ask.history", language: language))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            localized("ask.delete-history-title", language: language),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { entry in
            Button(localized("profile.delete", language: language), role: .destructive) {
                onDelete(entry)
                entries.removeAll { $0.id == entry.id }
                pendingDelete = nil
            }
            Button(localized("location.cancel", language: language), role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text(localized("ask.delete-history-message", language: language))
        }
    }

    private func historySummary(_ entry: AskHistoryEntry, showsDisclosure: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.question)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(entry.answerTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                Text(shortDate(entry.createdAt))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted.opacity(0.8))
                if let status = deepAnalysisStatus(entry) {
                    Label(
                        localized(status == .pending ? "ask.deep-analysis-running" : "common.retry", language: language),
                        systemImage: status == .pending ? "sparkles" : "arrow.clockwise"
                    )
                    .font(.caption)
                    .foregroundStyle(status == .pending ? AppTheme.violet : AppTheme.coral)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .contentShape(Rectangle())
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func deepAnalysisStatus(_ entry: AskHistoryEntry) -> AskDeepRecordStatus? {
        guard let session = entry.session else { return nil }
        let fingerprint = AskDeepAIService().sessionFingerprint(session)
        let status = deepAnalysisStore.record(sessionFingerprint: fingerprint)?.status
        return status == .completed ? nil : status
    }
}
