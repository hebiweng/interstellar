import XCTest
import CoreGraphics
import DeviceCheck
@testable import Interstellar

final class CommerceTests: XCTestCase {
    func testCreditPolicyMatchesMonthlyCreditContract() {
        XCTAssertEqual(CreditPolicy.firstFreePeriodCredits, 5)
        XCTAssertEqual(CreditPolicy.recurringFreeMonthlyCredits, 2)
        XCTAssertEqual(CreditPolicy.proMonthlyCredits, 10)
    }

    func testFreshAppContainerRotatesAppAttestKeyOnce() throws {
        let suiteName = "CommerceTests.AppInstallationLifecycle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var rotations = 0

        AppInstallationLifecycle.prepare(defaults: defaults) { rotations += 1 }
        AppInstallationLifecycle.prepare(defaults: defaults) { rotations += 1 }

        XCTAssertEqual(rotations, 1)
    }

    func testExistingAppContainerKeepsCurrentAppAttestKey() throws {
        let suiteName = "CommerceTests.AppInstallationLifecycle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AppInstallationLifecycle.prepare(defaults: defaults) {}
        var rotations = 0

        AppInstallationLifecycle.prepare(defaults: defaults) { rotations += 1 }

        XCTAssertEqual(rotations, 0)
    }

    func testAvailableTotalUsesVisibleCreditBuckets() {
        let credits = CommerceAccount.Credits(
            allowance: 7,
            bonus: 3,
            purchased: 20,
            reserved: 1,
            total: 30
        )

        XCTAssertEqual(credits.availableTotal, 30)
    }

	func testRelayFreeAccountOverridesStaleApplePremiumState() {
		let account = commerceAccount(plan: "free", premiumExpiresAt: nil)

		XCTAssertFalse(
			CommerceEntitlementPolicy.isPremium(
				account: account,
				isApplePremium: true,
				now: Date(timeIntervalSince1970: 1_800_000_000)
			)
		)
	}

	func testCachedRelayPremiumExpiresLocallyWithoutOpeningAppAgain() {
		let account = commerceAccount(plan: "premium", premiumExpiresAt: "2027-01-15T08:00:00Z")

		XCTAssertTrue(
			CommerceEntitlementPolicy.isPremium(
				account: account,
				isApplePremium: false,
				now: ISO8601DateFormatter().date(from: "2027-01-15T07:59:59Z")!
			)
		)
		XCTAssertFalse(
			CommerceEntitlementPolicy.isPremium(
				account: account,
				isApplePremium: true,
				now: ISO8601DateFormatter().date(from: "2027-01-15T08:00:00Z")!
			)
		)
	}

	func testAppleEntitlementIsUsedOnlyBeforeRelayAccountExists() {
		XCTAssertTrue(
			CommerceEntitlementPolicy.isPremium(
				account: nil,
				isApplePremium: true,
				now: Date(timeIntervalSince1970: 1_800_000_000)
			)
		)
	}

	func testAdminPremiumOverrideRemainsRelayAuthoritative() {
		let account = commerceAccount(plan: "premium", premiumExpiresAt: nil, adminPlanOverride: "premium")

		XCTAssertTrue(
			CommerceEntitlementPolicy.isPremium(
				account: account,
				isApplePremium: false,
				now: Date(timeIntervalSince1970: 1_800_000_000)
			)
		)
	}

	func testRelayAccountUserIDReplacesStaleLocalIdentity() {
		let stale = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
		let authoritative = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

		XCTAssertEqual(
			CommerceIdentityReconciliation.authoritativeUserID(
				responseUserID: authoritative.uuidString,
				currentUserID: stale
			),
			authoritative
		)
	}

	func testInvalidRelayAccountUserIDCannotReplaceLocalIdentity() {
		let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

		XCTAssertEqual(
			CommerceIdentityReconciliation.authoritativeUserID(
				responseUserID: "not-a-user-id",
				currentUserID: current
			),
			current
		)
	}

	func testAccountDeletionUsesCachedAppTransactionWithoutRefreshing() async throws {
		var refreshCalls = 0
		let signed = try await CommerceAppleIdentity.requiredSignedAppTransactionForDeletion(
			cached: { "cached-jws" },
			refresh: {
				refreshCalls += 1
				return "refreshed-jws"
			}
		)

		XCTAssertEqual(signed, "cached-jws")
		XCTAssertEqual(refreshCalls, 0)
	}

	func testAccountDeletionRefreshesAppTransactionWhenCachedValueIsUnavailable() async throws {
		var refreshCalls = 0
		let signed = try await CommerceAppleIdentity.requiredSignedAppTransactionForDeletion(
			cached: { throw AppTransactionTestError.unavailable },
			refresh: {
				refreshCalls += 1
				return "refreshed-jws"
			}
		)

		XCTAssertEqual(signed, "refreshed-jws")
		XCTAssertEqual(refreshCalls, 1)
	}

	func testEveryConsumableCanBeReconciledByRelay() {
		let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
		let ancestor = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

		XCTAssertTrue(
			CommerceTransactionOwnership.canReconcile(
				productID: "credits_10",
				appAccountToken: ancestor,
				currentUserID: current
			)
		)
		XCTAssertTrue(
			CommerceTransactionOwnership.canReconcile(
				productID: "credits_20",
				appAccountToken: nil,
				currentUserID: current
			)
		)
	}

	func testSubscriptionStillRequiresCurrentAccountToken() {
		let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
		let foreign = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

		XCTAssertFalse(
			CommerceTransactionOwnership.canReconcile(
				productID: "premium_annual",
				appAccountToken: foreign,
				currentUserID: current
			)
		)
	}

	func testRelayTerminalConsumableDispositionsAreFinished() {
		for disposition in ["credited_current", "settled_owner", "rejected_permanent"] {
			XCTAssertTrue(CommerceTransactionDisposition.shouldFinish(disposition))
		}
		XCTAssertFalse(CommerceTransactionDisposition.shouldFinish(nil))
	}

	func testOnlyCurrentCreditDispositionIsPresentedAsPurchaseSuccess() {
		XCTAssertFalse(CommerceTransactionDisposition.shouldShowPurchaseFailure("credited_current"))
		XCTAssertTrue(CommerceTransactionDisposition.shouldShowPurchaseFailure("settled_owner"))
		XCTAssertTrue(CommerceTransactionDisposition.shouldShowPurchaseFailure("rejected_permanent"))
	}

	func testActiveAndRecoverableSubscriptionStatesRequireRestore() {
		XCTAssertTrue(CommerceSubscriptionPurchasePolicy.requiresRestore(for: [.subscribed]))
		XCTAssertTrue(CommerceSubscriptionPurchasePolicy.requiresRestore(for: [.inGracePeriod]))
		XCTAssertTrue(CommerceSubscriptionPurchasePolicy.requiresRestore(for: [.inBillingRetryPeriod]))
	}

	func testExpiredOrRevokedSubscriptionDoesNotRequireRestore() {
		XCTAssertFalse(CommerceSubscriptionPurchasePolicy.requiresRestore(for: [.expired]))
		XCTAssertFalse(CommerceSubscriptionPurchasePolicy.requiresRestore(for: [.revoked]))
	}

	private func commerceAccount(
		plan: String,
		premiumExpiresAt: String?,
		adminPlanOverride: String? = nil
	) -> CommerceAccount {
		CommerceAccount(
			userID: "11111111-1111-4111-8111-111111111111",
			plan: plan,
			planSource: plan == "premium" ? "premium_monthly" : "free",
			adminPlanOverride: adminPlanOverride,
			premiumExpiresAt: premiumExpiresAt,
			creditsRenewAt: nil,
			credits: .init(allowance: 0, bonus: 0, purchased: 0, reserved: 0, total: 0),
			creditLedger: [],
			transactionDisposition: nil
		)
	}

    func testRelayEnvironmentPrefersProcessEnvironment() {
        let resolved = RelayEnvironment.resolve(
            environment: ["INTERSTELLAR_RELAY_BASE_URL": "https://override.example.com"],
            infoValue: "https://baked.example.com"
        )

        XCTAssertEqual(resolved.url.host, "override.example.com")
        XCTAssertEqual(resolved.source, "environment")
    }

    func testRelayEnvironmentUsesBakedInfoValue() {
        let resolved = RelayEnvironment.resolve(
            environment: [:],
            infoValue: "https://baked.example.com"
        )

        XCTAssertEqual(resolved.url.host, "baked.example.com")
        XCTAssertEqual(resolved.source, "info-plist")
    }

    func testAppAttestDiagnosticsKeepOnlyEndpointAndServerCode() throws {
        let url = try XCTUnwrap(
            URL(string: "https://aaadmin.xiaoguiwk.top/v1/app-attest/attest?token=secret")
        )
        let data = Data(#"{"error":"App verification failed. Please try again.","code":"attestation_invalid","token":"secret"}"#.utf8)

        XCTAssertEqual(
            AppAttestDiagnosticFormatter.endpoint(for: url),
            "aaadmin.xiaoguiwk.top/v1/app-attest/attest"
        )
        XCTAssertEqual(AppAttestDiagnosticFormatter.serverCode(from: data), "attestation_invalid")
        XCTAssertEqual(AppAttestDiagnosticFormatter.serverCode(from: Data(#"{"error":"temporary"}"#.utf8)), "none")
    }

    func testAppAttestEnvironmentUsesConfiguredValueForKeyStorage() {
        XCTAssertEqual(AppAttestEnvironment.normalized("production"), "production")
        XCTAssertEqual(AppAttestEnvironment.normalized("development"), "development")
        XCTAssertEqual(AppAttestEnvironment.normalized(nil), "production")
        XCTAssertEqual(AppAttestEnvironment.normalized("unexpected"), "production")
    }

    func testTestBuildUsesProductionAppAttestEnvironment() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "APP_ATTEST_ENVIRONMENT") as? String,
            "production"
        )
    }

    func testAccountSyncRetriesWithoutAppleIdentityOnlyForExactIdentityConflict() {
        XCTAssertTrue(
            CommerceAccountSyncPolicy.shouldRetryWithoutAppleIdentity(
                status: 409,
                message: "Apple identity is already linked to another active account",
                hadSignedAppTransaction: true
            )
        )
        XCTAssertFalse(
            CommerceAccountSyncPolicy.shouldRetryWithoutAppleIdentity(
                status: 409,
                message: "installation is already linked to another user",
                hadSignedAppTransaction: true
            )
        )
        XCTAssertFalse(
            CommerceAccountSyncPolicy.shouldRetryWithoutAppleIdentity(
                status: 409,
                message: "Apple identity is already linked to another active account",
                hadSignedAppTransaction: false
            )
        )
    }

    func testRelayEnvironmentIgnoresInvalidValuesAndFallsBack() {
        let resolved = RelayEnvironment.resolve(
            environment: ["INTERSTELLAR_RELAY_BASE_URL": "not a url"],
            infoValue: nil
        )

#if targetEnvironment(simulator)
        XCTAssertEqual(resolved.url.absoluteString, "http://127.0.0.1:8080")
#else
        XCTAssertEqual(resolved.url.absoluteString, "https://aaadmin.xiaoguiwk.top")
        XCTAssertEqual(resolved.source, "fallback-production")
#endif
    }

    func testPendingGenerationRoundTrip() throws {
        let item = PendingGeneration(
            requestID: "11111111-1111-4111-8111-111111111111",
            reportID: "natal-fingerprint-1",
            kind: "chart",
            chartPrefix: "natal",
            periodScope: nil,
            params: ["anchor": "2026-08-19"],
            subjectHashes: ["hash-a"],
            preset: "modern",
            locale: "zh-Hans",
            factsHash: "facts-1",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([PendingGeneration].self, from: data)
        XCTAssertEqual(decoded, [item])
        XCTAssertEqual(decoded.first?.id, item.requestID)
    }

    func testReportTaskStateDecodesAllStates() throws {
        let generating = try JSONDecoder().decode(
            ReportTaskState.self,
            from: Data(#"{"requestID":"r1","status":"generating"}"#.utf8)
        )
        XCTAssertEqual(generating.status, "generating")
        XCTAssertNil(generating.error)
        let completed = try JSONDecoder().decode(
            ReportTaskState.self,
            from: Data(#"{"requestID":"r1","status":"completed"}"#.utf8)
        )
        XCTAssertEqual(completed.status, "completed")
        let failed = try JSONDecoder().decode(
            ReportTaskState.self,
            from: Data(#"{"requestID":"r1","status":"failed","code":"upstream_generation_failed","error":"model exploded"}"#.utf8)
        )
        XCTAssertEqual(failed.status, "failed")
        XCTAssertEqual(failed.code, "upstream_generation_failed")
        XCTAssertEqual(failed.error, "model exploded")
    }

    func testInvalidAppAttestKeyRequiresReplacement() {
        let error = NSError(domain: DCErrorDomain, code: DCError.invalidKey.rawValue)

        XCTAssertTrue(AppAttestErrorClassifier.requiresNewKey(error))
    }

    func testInvalidAppAttestInputDoesNotDiscardKey() {
        let error = NSError(domain: DCErrorDomain, code: DCError.invalidInput.rawValue)

        XCTAssertFalse(AppAttestErrorClassifier.requiresNewKey(error))
    }

    func testTransactionOwnershipAcceptsCurrentCommerceUser() {
        let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

        XCTAssertTrue(
            CommerceTransactionOwnership.matches(
                appAccountToken: current,
                userID: current
            )
        )
    }

    func testTransactionOwnershipRejectsForeignAndMissingTokens() {
        let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let foreign = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        XCTAssertFalse(
            CommerceTransactionOwnership.matches(
                appAccountToken: foreign,
                userID: current
            )
        )
        XCTAssertFalse(
            CommerceTransactionOwnership.matches(
                appAccountToken: nil,
                userID: current
            )
        )
    }

    func testFreshIdentityRecoversSinglePendingTransactionAccount() {
        let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let purchased = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        XCTAssertEqual(
            CommerceIdentityRecovery.recoveredUserID(
                currentUserID: current,
                wasCreatedThisLaunch: true,
                transactionUserIDs: [purchased, purchased]
            ),
            purchased
        )
    }

    func testExistingIdentityDoesNotSwitchToPendingTransactionAccount() {
        let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let purchased = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        XCTAssertNil(
            CommerceIdentityRecovery.recoveredUserID(
                currentUserID: current,
                wasCreatedThisLaunch: false,
                transactionUserIDs: [purchased]
            )
        )
    }

    func testFreshIdentityRejectsConflictingPendingTransactionAccounts() {
        let current = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let first = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let second = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!

        XCTAssertNil(
            CommerceIdentityRecovery.recoveredUserID(
                currentUserID: current,
                wasCreatedThisLaunch: true,
                transactionUserIDs: [first, second]
            )
        )
    }
}

private enum AppTransactionTestError: Error {
	case unavailable
}

@MainActor
final class AIReportTaskManagerTests: XCTestCase {
    func testRecoverMissingNeverCreatesTask() async throws {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsResult = nil
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        let result: String? = try await manager.recover(
            requestID: "missing",
            language: .english
        ) { data in
            String(decoding: data, as: UTF8.self)
        }

        XCTAssertNil(result)
        XCTAssertEqual(transport.createCount, 0)
        XCTAssertEqual(transport.statusIfExistsCount, 1)
        XCTAssertEqual(transport.fetchCount, 0)
    }

    func testRecoverGeneratingPollsAndFetchesWithoutCreate() async throws {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsResult = state(
            requestID: "r1",
            status: "generating"
        )
        transport.statusQueue = [
            state(requestID: "r1", status: "completed"),
        ]
        transport.fetchData = Data("done".utf8)

        var generatingCount = 0
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        let result: String? = try await manager.recover(
            requestID: "r1",
            language: .english,
            onGenerating: { generatingCount += 1 }
        ) { data in
            String(decoding: data, as: UTF8.self)
        }

        XCTAssertEqual(result, "done")
        XCTAssertEqual(generatingCount, 1)
        XCTAssertEqual(transport.createCount, 0)
        XCTAssertEqual(transport.fetchCount, 1)
    }

    func testRecoverRelayFailureNeverCreatesTask() async {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsResult = state(
            requestID: "r2",
            status: "failed",
            error: "provider failed"
        )
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        do {
            let _: String? = try await manager.recover(
                requestID: "r2",
                language: .english
            ) { data in
                String(decoding: data, as: UTF8.self)
            }
            XCTFail("Expected relay failure")
        } catch AIReportTaskError.relayFailed(let message) {
            XCTAssertEqual(message, "provider failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(transport.createCount, 0)
    }

    func testRecoverDeliveryFailureNeverCreatesTask() async {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsError = AIReportTaskError.delivery(
            "network unavailable"
        )
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        do {
            let _: String? = try await manager.recover(
                requestID: "r3",
                language: .english
            ) { data in
                String(decoding: data, as: UTF8.self)
            }
            XCTFail("Expected delivery failure")
        } catch AIReportTaskError.delivery(let message) {
            XCTAssertEqual(message, "network unavailable")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(transport.createCount, 0)
    }

    func testRecoverCompletedDecodeFailureNeverCreatesTask() async {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsResult = state(
            requestID: "bad-envelope",
            status: "completed"
        )
        transport.fetchData = Data("invalid".utf8)
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        do {
            let _: String? = try await manager.recover(
                requestID: "bad-envelope",
                language: .english
            ) { _ in
                throw TestDecodeError.invalid
            }
            XCTFail("Expected decode failure")
        } catch TestDecodeError.invalid {
            // Expected. A completed-but-invalid delivery must never regenerate.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(transport.createCount, 0)
        XCTAssertEqual(transport.fetchCount, 1)
    }

    func testCreateDeliveryFailureIsNotRetriedAutomatically() async {
        let transport = FakeAIReportTaskTransport()
        transport.createError = AIReportTaskError.delivery(
            "request delivery uncertain"
        )
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        do {
            let _: String = try await manager.submit(
                requestID: "create-uncertain",
                body: Data("{}".utf8),
                language: .english
            ) { data in
                String(decoding: data, as: UTF8.self)
            }
            XCTFail("Expected delivery failure")
        } catch AIReportTaskError.delivery(let message) {
            XCTAssertEqual(message, "request delivery uncertain")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(transport.createCount, 1)
        XCTAssertEqual(transport.statusIfExistsCount, 0)
        XCTAssertEqual(transport.fetchCount, 0)
    }

    func testExplicitRetryMayResubmitRelayConfirmedFailure() async throws {
        let transport = FakeAIReportTaskTransport()
        transport.statusIfExistsResult = state(
            requestID: "retry-id",
            status: "failed",
            error: "old failure"
        )
        transport.statusQueue = [
            state(requestID: "retry-id", status: "completed"),
        ]
        transport.fetchData = Data("recovered-after-retry".utf8)

        let requestBody = try JSONSerialization.data(
            withJSONObject: [
                "requestID": "retry-id",
                "mode": "compare",
            ]
        )
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        let result: String = try await manager.submit(
            requestID: "retry-id",
            body: requestBody,
            language: .english,
            recoverFirst: true
        ) { data in
            String(decoding: data, as: UTF8.self)
        }

        XCTAssertEqual(result, "recovered-after-retry")
        XCTAssertEqual(transport.statusIfExistsCount, 1)
        XCTAssertEqual(transport.createCount, 1)
        XCTAssertEqual(transport.createdRequestID, "retry-id")
        XCTAssertEqual(transport.fetchCount, 1)
    }

    func testNormalSubmitDoesNotRunRecoveryFirst() async throws {
        let transport = FakeAIReportTaskTransport()
        transport.statusQueue = [
            state(requestID: "new-id", status: "completed"),
        ]
        transport.fetchData = Data("new-result".utf8)

        let body = try JSONSerialization.data(
            withJSONObject: ["requestID": "new-id"]
        )
        let manager = AIReportTaskManager(
            client: transport,
            pollIntervalNanoseconds: 1
        )

        let result: String = try await manager.submit(
            requestID: "new-id",
            body: body,
            language: .english
        ) { data in
            String(decoding: data, as: UTF8.self)
        }

        XCTAssertEqual(result, "new-result")
        XCTAssertEqual(transport.statusIfExistsCount, 0)
        XCTAssertEqual(transport.createCount, 1)
        XCTAssertEqual(transport.fetchCount, 1)
    }

    private func state(
        requestID: String,
        status: String,
        error: String? = nil
    ) -> ReportTaskState {
        ReportTaskState(
            requestID: requestID,
            status: status,
            code: nil,
            error: error
        )
    }
}

private enum TestDecodeError: Error {
    case invalid
}

@MainActor
private final class FakeAIReportTaskTransport: AIReportTaskTransport {
    var createCount = 0
    var statusCount = 0
    var statusIfExistsCount = 0
    var fetchCount = 0

    var createError: Error?
    var statusIfExistsResult: ReportTaskState?
    var statusIfExistsError: Error?
    var statusQueue: [ReportTaskState] = []
    var fetchData = Data()
    var createdRequestID: String?

    func createTask(
        body: Data,
        language: AppLanguage
    ) async throws -> ReportTaskState {
        _ = language
        createCount += 1
        if let createError {
            throw createError
        }
        if let json = try? JSONSerialization.jsonObject(with: body)
            as? [String: Any]
        {
            createdRequestID = json["requestID"] as? String
        }
        return ReportTaskState(
            requestID: createdRequestID,
            status: "generating",
            code: nil,
            error: nil
        )
    }

    func status(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState {
        _ = userID
        _ = requestID
        _ = language
        statusCount += 1
        if statusQueue.isEmpty {
            return ReportTaskState(
                requestID: requestID,
                status: "generating",
                code: nil,
                error: nil
            )
        }
        return statusQueue.removeFirst()
    }

    func statusIfExists(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> ReportTaskState? {
        _ = userID
        _ = requestID
        _ = language
        statusIfExistsCount += 1
        if let statusIfExistsError {
            throw statusIfExistsError
        }
        return statusIfExistsResult
    }

    func fetch(
        userID: String,
        requestID: String,
        language: AppLanguage
    ) async throws -> Data {
        _ = userID
        _ = requestID
        _ = language
        fetchCount += 1
        return fetchData
    }
}

final class R5ChartWheelGeometryTests: XCTestCase {
    func testSimpleGeometryStaysInsideSafeBoundsAcrossPhoneWidths() {
        // ChartsView uses 18pt page padding on each side. These are the
        // resulting content widths for the supported iPhone width classes.
        let screenWidths: [CGFloat] = [375, 390, 393, 402, 430]

        for screenWidth in screenWidths {
            let contentWidth = screenWidth - 36
            let geometry = ChartGeometry(
                size: CGSize(
                    width: contentWidth,
                    height: contentWidth
                ),
                mode: .simple,
                externalLabelReserve: 0
            )

            XCTAssertGreaterThan(geometry.wheelRadius, 0)
            XCTAssertGreaterThanOrEqual(
                geometry.safeLabelBounds.minX,
                8,
                "screen width \(screenWidth)"
            )
            XCTAssertLessThanOrEqual(
                geometry.safeLabelBounds.maxX,
                contentWidth - 8,
                "screen width \(screenWidth)"
            )
            XCTAssertLessThanOrEqual(
                geometry.wheelRadius * 2,
                geometry.safeLabelBounds.width + 0.001,
                "screen width \(screenWidth)"
            )
            XCTAssertLessThan(
                geometry.zodiacRadius,
                geometry.wheelRadius,
                "screen width \(screenWidth)"
            )
            XCTAssertLessThan(
                geometry.outerPlanetRadius,
                geometry.zodiacRadius,
                "screen width \(screenWidth)"
            )
            XCTAssertLessThan(
                geometry.aspectRadius,
                geometry.outerPlanetRadius,
                "screen width \(screenWidth)"
            )
        }
    }

    func testAxisLabelClampNeverLeavesSafeBounds() {
        let geometry = ChartGeometry(
            size: CGSize(width: 339, height: 339),
            mode: .simple,
            externalLabelReserve: 0
        )

        for longitude in stride(
            from: 0.0,
            to: 360.0,
            by: 5.0
        ) {
            let point = geometry.clampedLabelPoint(
                longitude: longitude,
                rotation: 127.5,
                radius: geometry.wheelRadius - 6,
                horizontalReserve: 17,
                verticalReserve: 9
            )

            XCTAssertGreaterThanOrEqual(
                point.x,
                geometry.safeLabelBounds.minX + 17 - 0.001
            )
            XCTAssertLessThanOrEqual(
                point.x,
                geometry.safeLabelBounds.maxX - 17 + 0.001
            )
            XCTAssertGreaterThanOrEqual(
                point.y,
                geometry.safeLabelBounds.minY + 9 - 0.001
            )
            XCTAssertLessThanOrEqual(
                point.y,
                geometry.safeLabelBounds.maxY - 9 + 0.001
            )
        }
    }

    func testSimpleAndProShareSameGeometryTypeWithDifferentDensity() {
        let size = CGSize(width: 339, height: 339)
        let simple = ChartGeometry(
            size: size,
            mode: .simple,
            externalLabelReserve: 0
        )
        let pro = ChartGeometry(
            size: size,
            mode: .pro,
            externalLabelReserve: 0
        )

        XCTAssertEqual(simple.center, pro.center)
        XCTAssertEqual(simple.wheelRadius, pro.wheelRadius)
        XCTAssertNotEqual(
            simple.outerPlanetRadius,
            pro.outerPlanetRadius
        )

        XCTAssertTrue(ChartDisplayConfig.simple.showSummary)
        XCTAssertFalse(ChartDisplayConfig.pro.showSummary)
        XCTAssertFalse(ChartDisplayConfig.simple.showPlanetTable)
        XCTAssertTrue(ChartDisplayConfig.pro.showPlanetTable)
    }
}
