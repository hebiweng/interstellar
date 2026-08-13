import Foundation
import Security
import StoreKit
import SwiftUI

struct CommerceAccount: Codable, Sendable {
    struct Credits: Codable, Sendable {
        let allowance: Int
        let bonus: Int
        let purchased: Int
        let reserved: Int
        let total: Int
    }
    struct LedgerEntry: Codable, Identifiable, Sendable {
        let id: Int64
        let requestID: String?
        let action: String
        let delta: Int
        let createdAt: String
    }
    let userID: String
    let plan: String
    let planSource: String?
    let adminPlanOverride: String?
    let premiumExpiresAt: String?
    let creditsRenewAt: String?
    let credits: Credits
    let creditLedger: [LedgerEntry]?
}

@MainActor
final class CommerceStore: ObservableObject {
    static let shared = CommerceStore()
    static let monthlyID = "premium_monthly"
    static let annualID = "premium_annual"
    static let creditsID = "credits_10"
    static let credits20ID = "credits_20"

    @Published private(set) var products: [Product] = []
    @Published private(set) var account: CommerceAccount?
    @Published private(set) var isApplePremium = false
    @Published private(set) var accountError: String?
    @Published var showsPaywall = false
    @Published var showsCredits = false

	@Published private(set) var userID: UUID
    private var updatesTask: Task<Void, Never>?

    var isPremium: Bool {
        if account?.adminPlanOverride != nil {
            return account?.plan == "premium"
        }
        return isApplePremium || account?.plan == "premium"
    }
    var totalCredits: Int { account?.credits.total ?? 0 }
    var planTitle: String { isPremium ? "Pro" : "Free" }

    private init() {
        userID = CommerceIdentity.userID
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await self?.submit(transaction, signedTransaction: result.jwsRepresentation)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        do { products = try await Product.products(for: [Self.monthlyID, Self.annualID, Self.creditsID, Self.credits20ID]) } catch {}
        await refreshEntitlements()
        await syncAccount()
        await retryPendingAcknowledgements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  [Self.monthlyID, Self.annualID].contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            active = true
        }
        isApplePremium = active
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase(options: [.appAccountToken(userID)])
            guard case let .success(verification) = result,
                  case let .verified(transaction) = verification else { return }
            await submit(transaction, signedTransaction: verification.jwsRepresentation)
        } catch {}
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
        for await result in Transaction.all {
            if case let .verified(transaction) = result { await submit(transaction, signedTransaction: result.jwsRepresentation) }
        }
        await syncAccount()
    }

    func syncAccount() async {
        struct Body: Encodable { let userID: String }
        do {
            let data = try JSONEncoder().encode(Body(userID: userID.uuidString.lowercased()))
            let response = try await CommerceRelay.post(path: "v1/account/sync", body: data)
            account = try JSONDecoder().decode(CommerceAccount.self, from: response)
            accountError = nil
        } catch {
            accountError = error.localizedDescription
        }
    }

    func acknowledgeReport(requestID: String) async {
        let pending = PendingReportAcknowledgement(
            userID: userID.uuidString.lowercased(),
            requestID: requestID
        )
        PendingReportAcknowledgements.insert(pending)
        await sendAcknowledgement(pending)
        await syncAccount()
    }

    private func retryPendingAcknowledgements() async {
        for pending in PendingReportAcknowledgements.load() {
            await sendAcknowledgement(pending)
        }
        await syncAccount()
    }

    private func sendAcknowledgement(_ pending: PendingReportAcknowledgement) async {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        do {
            _ = try await CommerceRelay.post(path: "v1/reports/ack", body: data)
            PendingReportAcknowledgements.remove(pending)
        } catch CommerceRelayError.httpStatus(let status, _) where [404, 409, 410].contains(status) {
            // Relay has already released or finalized this reservation. It can
            // no longer be acknowledged and must not remain in the retry queue.
            PendingReportAcknowledgements.remove(pending)
        } catch {
            // The locally saved report remains deliverable. Retry the ACK on
            // the next launch so a transient network failure cannot skip billing.
        }
    }

    private func submit(_ transaction: StoreKit.Transaction, signedTransaction: String) async {
		if let restoredUserID = transaction.appAccountToken, restoredUserID != userID {
			CommerceIdentity.save(restoredUserID)
			userID = restoredUserID
		}
        // The server endpoint verifies this signed JWS before changing paid state.
        struct Body: Encodable { let userID: String; let signedTransaction: String }
        do {
            let data = try JSONEncoder().encode(Body(userID: userID.uuidString.lowercased(), signedTransaction: signedTransaction))
            _ = try await CommerceRelay.post(path: "v1/store/transactions", body: data)
            await transaction.finish()
            await refreshEntitlements()
            await syncAccount()
        } catch {
            // Keep the transaction unfinished so StoreKit can redeliver it.
        }
    }
}

enum CommerceIdentity {
    private static let service = "com.xiaoguiwk.interstellar.commerce"
    private static let account = "anonymous-user-id"
    static let userID: UUID = {
        if let data = KeychainValue.read(service: service, account: account),
           let raw = String(data: data, encoding: .utf8), let value = UUID(uuidString: raw) { return value }
        let value = UUID()
        KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account)
        return value
    }()
	static func save(_ value: UUID) { KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account) }
}

private struct PendingReportAcknowledgement: Codable, Hashable {
    let userID: String
    let requestID: String
}

private enum PendingReportAcknowledgements {
    private static let key = "commerce.pending-report-acknowledgements.v1"

    static func load() -> Set<PendingReportAcknowledgement> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode(Set<PendingReportAcknowledgement>.self, from: data)
        else { return [] }
        return values
    }

    static func insert(_ value: PendingReportAcknowledgement) {
        var values = load()
        values.insert(value)
        save(values)
    }

    static func remove(_ value: PendingReportAcknowledgement) {
        var values = load()
        values.remove(value)
        save(values)
    }

    private static func save(_ values: Set<PendingReportAcknowledgement>) {
        if values.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum CommerceRelay {
    static func post(path: String, body: Data) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://aaadmin.xiaoguiwk.top")!.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        let headers = try await AppAttestAuthorizer.shared.headers(for: body, baseURL: URL(string: "https://aaadmin.xiaoguiwk.top")!, forceTokenRefresh: false, language: .english)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw CommerceRelayError.httpStatus(http.statusCode, message)
        }
        return data
    }
}

enum CommerceRelayError: LocalizedError {
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case let .httpStatus(status, message):
            return message ?? "HTTP \(status)"
        }
    }
}

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    @State private var selectedProductID = CommerceStore.annualID
    @State private var legalDocument: LocalLegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                    Text("INTERSTELLAR PRO")
                        .font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(AppTheme.violet)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(AppTheme.violet.opacity(0.12), in: Capsule())
                    Text(localized("premium.see-full-picture", language: language)).font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                    Text(localized("premium.pro-description", language: language)).font(.subheadline).foregroundStyle(AppTheme.muted)

                    VStack(spacing: 10) {
                        ForEach(proProducts, id: \.id) { product in
                            productChoice(product)
                        }
                    }

                    VStack(spacing: 0) {
                        benefit("premium.all-insights", value: localized("premium.included", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.unlimited-people", value: localized("premium.unlimited", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.ten-credits", value: localized("premium.per-period", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.annual-welcome", value: localized("premium.annual-only", language: language), sparkle: true)
                    }

                    if commerce.products.isEmpty {
                        Text(localized("premium.storekit-testing-note", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
                    }

                    Button(localized("premium.start-pro", language: language)) {
                    guard let product = commerce.products.first(where: { $0.id == selectedProductID }) else { return }
                    Task { await commerce.purchase(product) }
                }
                    .font(.headline).foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16))
                    .buttonStyle(.plain)

                    Button(localized("location.cancel", language: language)) { dismiss() }
                        .font(.headline).foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
                        .buttonStyle(.plain)

                    Button(localized("premium.restore", language: language)) { Task { await commerce.restore() } }
                        .font(.footnote.weight(.semibold)).frame(maxWidth: .infinity)
                    Text(localized("premium.renewal-note", language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                    HStack {
                        Button(localized("legal.terms", language: language)) { legalDocument = .terms }
                        Spacer()
                        Button(localized("legal.privacy", language: language)) { legalDocument = .privacy }
                    }.font(.caption.weight(.semibold))
                }
                .padding(20)
            }.background(ScreenBackground())
            .sheet(item: $legalDocument) { LocalLegalView(document: $0, language: language) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var proProducts: [Product] {
        commerce.products.filter { [CommerceStore.annualID, CommerceStore.monthlyID].contains($0.id) }
            .sorted { $0.id == CommerceStore.annualID && $1.id != CommerceStore.annualID }
    }

    private func productChoice(_ product: Product) -> some View {
        Button { selectedProductID = product.id } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: selectedProductID == product.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(AppTheme.violet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.id == CommerceStore.annualID ? localized("premium.annual", language: language) : localized("premium.monthly", language: language))
                        .font(.headline).foregroundStyle(AppTheme.text)
                    if product.id == CommerceStore.annualID {
                        Text(localized("premium.annual-bonus", language: language)).font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer()
                Text(product.displayPrice).font(.title3.bold()).foregroundStyle(AppTheme.text)
            }.padding(16)
            .background(selectedProductID == product.id ? AppTheme.violet.opacity(0.13) : AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedProductID == product.id ? AppTheme.violet : AppTheme.line))
        }.buttonStyle(.plain)
    }

    private func benefit(_ key: String, value: String, sparkle: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sparkle ? "sparkles" : "checkmark").foregroundStyle(AppTheme.violet).frame(width: 20)
            Text(localized(key, language: language)).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
            Spacer()
            Text(value).font(.caption).foregroundStyle(AppTheme.muted)
        }.padding(.vertical, 13)
    }
}

struct CreditsPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    @State private var selectedProductID = CommerceStore.credits20ID
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                Text(localized("credits.need-more", language: language)).font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                Text(localized("credits.purchase-description", language: language)).font(.subheadline).foregroundStyle(AppTheme.muted)
                ForEach(creditProducts, id: \.id) { product in
                    Button { selectedProductID = product.id } label: {
                        HStack {
                            Image(systemName: selectedProductID == product.id ? "checkmark.circle.fill" : "circle").foregroundStyle(AppTheme.violet)
                            Text(product.id == CommerceStore.credits20ID ? "20 Credits" : "10 Credits").font(.headline).foregroundStyle(AppTheme.text)
                            Spacer()
                            Text(product.displayPrice).font(.title3.bold()).foregroundStyle(AppTheme.text)
                        }.padding(17)
                        .background(selectedProductID == product.id ? AppTheme.violet.opacity(0.13) : AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedProductID == product.id ? AppTheme.violet : AppTheme.line))
                    }.buttonStyle(.plain)
                }
                if creditProducts.isEmpty { Text(localized("premium.storekit-testing-note", language: language)).font(.footnote).foregroundStyle(AppTheme.muted) }
                Text(localized("credits.never-expire", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
                Button(localized("credits.buy", language: language)) {
                    guard let product = commerce.products.first(where: { $0.id == selectedProductID }) else { return }
                    Task { await commerce.purchase(product) }
                }.font(.headline).foregroundStyle(Color.white).frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16)).buttonStyle(.plain)
                Button(localized("location.cancel", language: language)) { dismiss() }
                    .font(.headline).foregroundStyle(AppTheme.text).frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line)).buttonStyle(.plain)
            }.padding(20).background(ScreenBackground())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var creditProducts: [Product] {
        commerce.products.filter { [CommerceStore.creditsID, CommerceStore.credits20ID].contains($0.id) }
            .sorted { $0.id == CommerceStore.credits20ID && $1.id != CommerceStore.credits20ID }
    }
}

private enum LocalLegalDocument: String, Identifiable { case terms, privacy; var id: String { rawValue } }

private struct LocalLegalView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LocalLegalDocument
    let language: AppLanguage
    var body: some View {
        NavigationStack {
            ScrollView { Text(localized(document == .terms ? "legal.terms-body" : "legal.privacy-body", language: language)).font(.body).foregroundStyle(AppTheme.text).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
                .background(ScreenBackground())
                .navigationTitle(localized(document == .terms ? "legal.terms" : "legal.privacy", language: language))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(localized("common.done", language: language)) { dismiss() } } }
        }
    }
}
