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
    let userID: String
    let plan: String
    let premiumExpiresAt: String?
    let credits: Credits
}

@MainActor
final class CommerceStore: ObservableObject {
    static let shared = CommerceStore()
    static let monthlyID = "premium_monthly"
    static let annualID = "premium_annual"
    static let creditsID = "credits_10"

    @Published private(set) var products: [Product] = []
    @Published private(set) var account: CommerceAccount?
    @Published private(set) var isApplePremium = false
    @Published var showsPaywall = false
    @Published var showsCredits = false

	@Published private(set) var userID: UUID
    private var updatesTask: Task<Void, Never>?

    var isPremium: Bool { isApplePremium || account?.plan != "free" }
    var totalCredits: Int { account?.credits.total ?? 0 }

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
        do { products = try await Product.products(for: [Self.monthlyID, Self.annualID, Self.creditsID]) } catch {}
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
        } catch {}
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
        } catch CommerceRelayError.httpStatus(let status) where [404, 409, 410].contains(status) {
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
        guard (200..<300).contains(http.statusCode) else { throw CommerceRelayError.httpStatus(http.statusCode) }
        return data
    }
}

enum CommerceRelayError: Error {
    case httpStatus(Int)
}

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    @State private var selectedProductID = CommerceStore.annualID

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(localized("premium.see-full-picture", language: language)).font(.title2.bold())
                    Label(localized("premium.all-insights", language: language), systemImage: "checkmark.circle")
                    Label(localized("premium.unlimited-people", language: language), systemImage: "checkmark.circle")
                    Label(localized("premium.ten-reports", language: language), systemImage: "checkmark.circle")
                }
                Section {
                    ForEach(commerce.products.filter { $0.id != CommerceStore.creditsID }.sorted { $0.id == CommerceStore.annualID && $1.id != CommerceStore.annualID }, id: \.id) { product in
                        Button { selectedProductID = product.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.id == CommerceStore.annualID ? localized("premium.annual", language: language) : localized("premium.monthly", language: language))
                                    if product.id == CommerceStore.annualID {
                                        Text(localized("premium.annual-bonus", language: language)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(product.displayPrice)
                                Image(systemName: selectedProductID == product.id ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(localized("premium.continue", language: language)) {
                    guard let product = commerce.products.first(where: { $0.id == selectedProductID }) else { return }
                    Task { await commerce.purchase(product) }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                Button(localized("premium.restore", language: language)) { Task { await commerce.restore() } }
                Section {
                    Text(localized("premium.renewal-note", language: language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(localized("legal.terms", language: language), destination: URL(string: "https://aaadmin.xiaoguiwk.top/terms")!)
                    Link(localized("legal.privacy", language: language), destination: URL(string: "https://aaadmin.xiaoguiwk.top/privacy")!)
                }
            }
            .navigationTitle("Interstellar Premium")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(localized("location.cancel", language: language)) { dismiss() } } }
        }
    }
}

struct CreditsPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    var body: some View {
        NavigationStack {
            Form {
                Text(localized("credits.need-more", language: language)).font(.title2.bold())
                if let product = commerce.products.first(where: { $0.id == CommerceStore.creditsID }) {
                    HStack { Text("10 Credits"); Spacer(); Text(product.displayPrice) }
                    Button(localized("credits.buy", language: language)) { Task { await commerce.purchase(product) } }
                        .buttonStyle(.borderedProminent)
                }
                Text(localized("credits.never-expire", language: language)).foregroundStyle(.secondary)
            }
            .navigationTitle(localized("credits.title", language: language))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(localized("location.cancel", language: language)) { dismiss() } } }
        }
    }
}
