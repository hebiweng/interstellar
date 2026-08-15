import XCTest
import DeviceCheck
@testable import Interstellar

final class CommerceTests: XCTestCase {
    func testAvailableTotalUsesVisibleCreditBuckets() {
        let credits = CommerceAccount.Credits(
            allowance: 7,
            bonus: 3,
            purchased: 20,
            reserved: 1,
            total: 999
        )

        XCTAssertEqual(credits.availableTotal, 30)
    }

    func testInvalidAppAttestKeyRequiresReplacement() {
        let error = NSError(domain: DCErrorDomain, code: DCError.invalidKey.rawValue)

        XCTAssertTrue(AppAttestErrorClassifier.requiresNewKey(error))
    }

    func testInvalidAppAttestInputDoesNotDiscardKey() {
        let error = NSError(domain: DCErrorDomain, code: DCError.invalidInput.rawValue)

        XCTAssertFalse(AppAttestErrorClassifier.requiresNewKey(error))
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
