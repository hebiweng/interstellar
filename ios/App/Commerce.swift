import Foundation
import OSLog
import Security
import StoreKit
import SwiftUI
import WebKit

struct CommerceAccount: Codable, Sendable {
    struct Credits: Codable, Sendable {
        let allowance: Int
        let bonus: Int
        let purchased: Int
        let reserved: Int
        let total: Int

        var availableTotal: Int { allowance + bonus + purchased }
    }
    struct LedgerEntry: Codable, Identifiable, Sendable {
        let id: Int64
        let requestID: String?
        let action: String
        let delta: Int
        let createdAt: String
        let scope: String?
        let reportStatus: String?
        let errorCode: String?
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
    @Published private(set) var accountSyncFailed = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productsUnavailable = false
    @Published private(set) var purchaseFailed = false
    @Published private(set) var purchasePendingSync = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRefreshingAccount = false
    @Published var showsPaywall = false
    @Published var showsCredits = false

	@Published private(set) var userID: UUID
    private var updatesTask: Task<Void, Never>?
    private var accountRefreshInProgress = false
    private var accountSyncInProgress = false

    var isPremium: Bool {
        if account?.adminPlanOverride != nil {
            return account?.plan == "premium"
        }
        return isApplePremium || account?.plan == "premium"
    }
    var totalCredits: Int { account?.credits.availableTotal ?? 0 }
    var planTitle: String {
        guard let account else { return "—" }
        return account.plan == "premium" ? "Pro" : "Free"
    }

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
        await recoverIdentityFromUnfinishedTransactionsIfNeeded()
        await loadProducts()
        await refreshEntitlements()
        await refreshAccount()
        await retryPendingAcknowledgements()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let requestedIDs = [Self.monthlyID, Self.annualID, Self.creditsID, Self.credits20ID]
            var loaded: [Product] = []
            for attempt in 0 ..< 3 {
                loaded = try await Product.products(for: requestedIDs)
                CommerceDiagnostics.logger.info(
                    "StoreKit catalog attempt=\(attempt + 1) requested=\(requestedIDs.count) returned=\(loaded.count) ids=\(loaded.map(\.id).sorted().joined(separator: ","), privacy: .public)"
                )
                if loaded.count == requestedIDs.count { break }
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
                }
            }
            products = loaded
            let returnedIDs = Set(loaded.map(\.id))
            let missingIDs = requestedIDs.filter { !returnedIDs.contains($0) }
            productsUnavailable = !missingIDs.isEmpty
            purchaseFailed = false
            CommerceDiagnostics.logger.info(
                "StoreKit catalog completed missing=\(missingIDs.joined(separator: ","), privacy: .public)"
            )
        } catch {
            products = []
            productsUnavailable = true
            CommerceDiagnostics.log(error, operation: "load_products")
        }
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
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseFailed = false
        purchasePendingSync = false
        do {
            let result = try await product.purchase(options: [.appAccountToken(userID)])
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    purchaseFailed = true
                    return
                }
                await submit(transaction, signedTransaction: verification.jwsRepresentation)
            case .pending, .userCancelled:
                return
            @unknown default:
                purchaseFailed = true
            }
        } catch {
            purchaseFailed = true
            CommerceDiagnostics.log(error, operation: "purchase")
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
        for await result in Transaction.all {
            if case let .verified(transaction) = result { await submit(transaction, signedTransaction: result.jwsRepresentation) }
        }
        await syncAccount()
    }

    func refreshAccount() async {
        guard !accountRefreshInProgress else { return }
        accountRefreshInProgress = true
        isRefreshingAccount = true
        defer {
            accountRefreshInProgress = false
            isRefreshingAccount = false
        }
        guard await syncAccount() else { return }
        if await retryUnfinishedTransactions() {
            await syncAccount()
        }
    }

    @discardableResult
    func syncAccount() async -> Bool {
        guard !accountSyncInProgress else { return false }
        accountSyncInProgress = true
        defer { accountSyncInProgress = false }
        struct Body: Encodable { let userID: String; let countryCode: String? }
        do {
            let data = try JSONEncoder().encode(Body(
                userID: userID.uuidString.lowercased(),
                countryCode: Locale.current.region?.identifier
            ))
            let response = try await CommerceRelay.post(path: "v1/account/sync", body: data)
            account = try JSONDecoder().decode(CommerceAccount.self, from: response)
            accountSyncFailed = false
            return true
        } catch {
            accountSyncFailed = true
            CommerceDiagnostics.log(error, operation: "sync_account")
            return false
        }
    }

    func enqueueReportAcknowledgement(requestID: String) {
        let pending = PendingReportAcknowledgement(
            userID: userID.uuidString.lowercased(),
            requestID: requestID
        )
        PendingReportAcknowledgements.insert(pending)
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

    @discardableResult
    private func submit(
        _ transaction: StoreKit.Transaction,
        signedTransaction: String,
        refreshAccountAfterSuccess: Bool = true
    ) async -> Bool {
        if let transactionUserID = transaction.appAccountToken, transactionUserID != userID {
            purchasePendingSync = true
            CommerceDiagnostics.logger.error("submit_transaction failed reason=app_account_token_mismatch")
            return false
        }
        // The server endpoint verifies this signed JWS before changing paid state.
        struct Body: Encodable { let userID: String; let signedTransaction: String }
        do {
            let data = try JSONEncoder().encode(Body(userID: userID.uuidString.lowercased(), signedTransaction: signedTransaction))
            _ = try await CommerceRelay.post(path: "v1/store/transactions", body: data)
            await transaction.finish()
            purchaseFailed = false
            purchasePendingSync = false
            await refreshEntitlements()
            if refreshAccountAfterSuccess {
                await syncAccount()
            }
            return true
        } catch {
        // Keep the transaction unfinished so StoreKit can redeliver it on the
        // next account refresh or app launch without charging the user again.
            purchasePendingSync = true
            CommerceDiagnostics.log(error, operation: "submit_transaction")
            return false
        }
    }

    private func retryUnfinishedTransactions() async -> Bool {
        var deliveredTransaction = false
        for await verification in Transaction.unfinished {
            guard case let .verified(transaction) = verification else { continue }
            let delivered = await submit(
                transaction,
                signedTransaction: verification.jwsRepresentation,
                refreshAccountAfterSuccess: false
            )
            guard delivered else { break }
            deliveredTransaction = true
        }
        return deliveredTransaction
    }

    private func recoverIdentityFromUnfinishedTransactionsIfNeeded() async {
        guard CommerceIdentity.wasCreatedThisLaunch else { return }
        var transactionUserIDs: [UUID] = []
        for await verification in Transaction.unfinished {
            guard case let .verified(transaction) = verification,
                  let transactionUserID = transaction.appAccountToken
            else { continue }
            transactionUserIDs.append(transactionUserID)
        }
        guard let recoveredUserID = CommerceIdentityRecovery.recoveredUserID(
            currentUserID: userID,
            wasCreatedThisLaunch: true,
            transactionUserIDs: transactionUserIDs
        ) else { return }
        CommerceIdentity.save(recoveredUserID)
        userID = recoveredUserID
    }
}

enum CommerceIdentity {
    private static let service = "com.xiaoguiwk.interstellar.commerce"
    private static let account = "anonymous-user-id"
    private static let initialState: (userID: UUID, wasCreated: Bool) = {
        if let data = KeychainValue.read(service: service, account: account),
           let raw = String(data: data, encoding: .utf8), let value = UUID(uuidString: raw) {
            return (value, false)
        }
        let value = UUID()
        KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account)
        return (value, true)
    }()

    static var userID: UUID { initialState.userID }
    static var wasCreatedThisLaunch: Bool { initialState.wasCreated }
	static func save(_ value: UUID) { KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account) }
#if DEBUG
    static func resetForTesting() { KeychainValue.remove(service: service, account: account) }
#endif
}

enum CommerceIdentityRecovery {
    static func recoveredUserID(
        currentUserID: UUID,
        wasCreatedThisLaunch: Bool,
        transactionUserIDs: [UUID]
    ) -> UUID? {
        guard wasCreatedThisLaunch, let candidate = transactionUserIDs.first else { return nil }
        guard transactionUserIDs.allSatisfy({ $0 == candidate }) else { return nil }
        return candidate == currentUserID ? nil : candidate
    }
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
        let baseURL = URL(string: "https://aaadmin.xiaoguiwk.top")!
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 20
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        let response = try await AppAttestAuthorizer.shared.send(
            request,
            body: body,
            baseURL: baseURL,
            language: .english
        )
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: response.data) as? [String: Any])?["error"] as? String
            throw CommerceRelayError.httpStatus(response.statusCode, message)
        }
        return response.data
    }
}

private enum CommerceDiagnostics {
    static let logger = Logger(subsystem: "com.xiaoguiwk.interstellar", category: "Commerce")

    static func log(_ error: Error, operation: String) {
        let value = error as NSError
        logger.error(
            "\(operation, privacy: .public) failed domain=\(value.domain, privacy: .public) code=\(value.code)"
        )
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
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    @State private var selectedProductID = CommerceStore.annualID
    @State private var legalDocument: LegalDocument?

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
                        productChoice(
                            id: CommerceStore.monthlyID,
                            titleKey: "premium.monthly",
                            fallbackPrice: "$4.99",
                            periodKey: "premium.per-month"
                        )
                        productChoice(
                            id: CommerceStore.annualID,
                            titleKey: "premium.annual",
                            fallbackPrice: "$39.99",
                            periodKey: "premium.per-year",
                            detailKey: "premium.annual-bonus"
                        )
                    }

                    productAvailability

                    VStack(spacing: 0) {
                        benefit("premium.all-insights", value: localized("premium.included", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.unlimited-people", value: localized("premium.unlimited", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.ten-credits", value: localized("premium.per-period", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.annual-welcome", value: localized("premium.annual-only", language: language), sparkle: true)
                    }

                    Button {
                        Task {
                            if let product = commerce.products.first(where: { $0.id == selectedProductID }) {
                                await commerce.purchase(product)
                            } else {
                                await commerce.loadProducts()
                            }
                        }
                    } label: {
                        Text(purchaseButtonTitle)
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .drawerTapTarget(minHeight: 52)
                    }
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16))
                    .buttonStyle(.plain)
                    .disabled(commerce.isPurchasing)

                    Button {
                        commerce.showsPaywall = false
                    } label: {
                        Text(localized("location.cancel", language: language))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                            .drawerTapTarget(minHeight: 52)
                    }
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
            .sheet(item: $legalDocument) { LegalDocumentView(document: $0, language: language) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task {
            if commerce.products.isEmpty { await commerce.loadProducts() }
        }
    }

    private var purchaseButtonTitle: String {
        if commerce.isPurchasing {
            return localized("commerce.processing-purchase", language: language)
        }
        if commerce.isLoadingProducts {
            return localized("commerce.loading-products", language: language)
        }
        if commerce.products.first(where: { $0.id == selectedProductID }) == nil {
            return localized("commerce.retry-products", language: language)
        }
        return selectedProductID == CommerceStore.annualID
            ? localized("premium.choose-annual", language: language)
            : localized("premium.choose-monthly", language: language)
    }

    @ViewBuilder
    private var productAvailability: some View {
        if commerce.isLoadingProducts {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.loading-products", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.purchasePendingSync {
            Text(localized("commerce.purchase-pending-sync", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.violet)
        } else if commerce.productsUnavailable {
            Text(localized("commerce.products-unavailable", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        } else if commerce.purchaseFailed {
            Text(localized("commerce.purchase-failed", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        }
    }

    private func productChoice(
        id: String,
        titleKey: String,
        fallbackPrice: String,
        periodKey: String,
        detailKey: String? = nil
    ) -> some View {
        let product = commerce.products.first { $0.id == id }
        return Button { selectedProductID = id } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedProductID == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(AppTheme.violet)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(titleKey, language: language))
                        .font(.headline).foregroundStyle(AppTheme.text)
                    if let detailKey {
                        Text(localized(detailKey, language: language)).font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product?.displayPrice ?? fallbackPrice).font(.title3.bold()).foregroundStyle(AppTheme.text)
                    Text(localized(periodKey, language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                }
            }.padding(16)
            .background(selectedProductID == id ? AppTheme.violet.opacity(0.13) : AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedProductID == id ? AppTheme.violet : AppTheme.line))
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
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                Text(localized("credits.need-more", language: language)).font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                Text(localized("credits.purchase-description", language: language)).font(.subheadline).foregroundStyle(AppTheme.muted)
                creditPurchaseButton(id: CommerceStore.creditsID, amount: 10, fallbackPrice: "$1.99")
                creditPurchaseButton(id: CommerceStore.credits20ID, amount: 20, fallbackPrice: "$2.99")
                productAvailability
                Text(localized("credits.never-expire", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
                Button {
                    commerce.showsCredits = false
                } label: {
                    Text(localized("location.cancel", language: language))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .drawerTapTarget(minHeight: 52)
                }
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
                .buttonStyle(.plain)
            }.padding(20).background(ScreenBackground())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            if commerce.products.isEmpty { await commerce.loadProducts() }
        }
    }

    private func creditPurchaseButton(id: String, amount: Int, fallbackPrice: String) -> some View {
        let product = commerce.products.first { $0.id == id }
        return Button {
            Task {
                if let product {
                    await commerce.purchase(product)
                } else {
                    await commerce.loadProducts()
                }
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(amount) Credits").font(.title3.bold()).foregroundStyle(AppTheme.text)
                    Text(localized("credits.permanent-pack", language: language)).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text(product?.displayPrice ?? fallbackPrice).font(.title3.bold()).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(AppTheme.violet, in: Capsule())
            }
            .padding(17)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
            .drawerTapTarget(minHeight: 54)
        }
        .buttonStyle(.plain)
        .disabled(commerce.isPurchasing)
    }

    @ViewBuilder
    private var productAvailability: some View {
        if commerce.isPurchasing {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.processing-purchase", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.isLoadingProducts {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.loading-products", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.purchasePendingSync {
            Text(localized("commerce.purchase-pending-sync", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.violet)
        } else if commerce.productsUnavailable {
            Text(localized("commerce.products-unavailable", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        } else if commerce.purchaseFailed {
            Text(localized("commerce.purchase-failed", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        }
    }
}

private enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var url: URL {
        URL(string: "https://aaadmin.xiaoguiwk.top/\(rawValue)")!
    }
}

private struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument
    let language: AppLanguage
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ScrollView {
                        Text(localized(document == .terms ? "legal.terms-body" : "legal.privacy-body", language: language))
                            .font(.body)
                            .foregroundStyle(AppTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                } else {
                    LegalWebView(url: document.url, loadFailed: $loadFailed)
                }
            }
                .background(ScreenBackground())
                .navigationTitle(localized(document == .terms ? "legal.terms" : "legal.privacy", language: language))
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Text(document.url.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("common.done", language: language)) { dismiss() }
                    }
                }
        }
    }
}

private struct LegalWebView: UIViewRepresentable {
    let url: URL
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(loadFailed: $loadFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var loadFailed: Bool

        init(loadFailed: Binding<Bool>) {
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadFailed = true
        }
    }
}
