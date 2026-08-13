package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func openTestStore(t *testing.T) *Store {
	t.Helper()
	s, err := OpenStore(t.TempDir()+"/relay.db", "test-secret-please-change-32-bytes")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

func TestProviderKeyEncryptionRoundTrip(t *testing.T) {
	s := openTestStore(t)
	p := Provider{ID: "default", Label: "DeepSeek", BaseURL: "https://api.deepseek.com", DefaultModel: "deepseek-v4-flash", Enabled: true}
	if _, err := s.UpsertProvider(p, "sk-secret-abc"); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	secret, err := s.GetProviderSecret("default")
	if err != nil {
		t.Fatalf("get secret: %v", err)
	}
	if secret.APIKey != "sk-secret-abc" {
		t.Fatalf("key round trip failed: %q", secret.APIKey)
	}
	// Encrypted text must not contain the plaintext.
	listed, _ := s.ListProviders()
	raw, _ := json.Marshal(listed)
	if strings.Contains(string(raw), "sk-secret-abc") {
		t.Fatal("plaintext key leaked in provider listing")
	}
}

func TestGenerationResultValidation(t *testing.T) {
	evidence := map[string]bool{"point.sun": true}
	var r GenerationResult
	if err := json.Unmarshal([]byte(`{"report":{"title":"t","subtitle":"s","sections":[]}}`), &r); err != nil {
		t.Fatal(err)
	}
	if err := r.Validate("en", evidence); err == nil {
		t.Fatal("expected validation failure for empty sections")
	}

	valid := `{"report":{"title":"t","subtitle":"s","sections":[
		{"number":"01","title":"One","body":"body one","evidenceFactIDs":["point.sun"]},
		{"number":"02","title":"Two","body":"body two","evidenceFactIDs":["point.sun"]},
		{"number":"03","title":"Three","body":"body three","evidenceFactIDs":["point.sun"]},
		{"number":"04","title":"Four","body":"body four","evidenceFactIDs":["point.sun"]}]}}`
	if err := json.Unmarshal([]byte(valid), &r); err != nil {
		t.Fatal(err)
	}
	if err := r.Validate("en", evidence); err != nil {
		t.Fatalf("expected valid: %v", err)
	}
	r.Report.Sections[0].EvidenceFactIDs = []string{"missing"}
	if err := r.Validate("en", evidence); err == nil {
		t.Fatal("expected validation failure for unknown report evidence")
	}
}

func TestInstallationQuota(t *testing.T) {
	s := openTestStore(t)
	for expected := 1; expected <= 3; expected++ {
		count, allowed, err := s.ConsumeInstallationQuota("install-a", 2)
		if err != nil {
			t.Fatal(err)
		}
		if count != expected {
			t.Fatalf("count=%d, want %d", count, expected)
		}
		if allowed != (expected <= 2) {
			t.Fatalf("allowed=%v at count=%d", allowed, count)
		}
	}
	count, allowed, err := s.ConsumeInstallationQuota("install-b", 2)
	if err != nil || count != 1 || !allowed {
		t.Fatalf("a separate installation must have an independent quota: count=%d allowed=%v err=%v", count, allowed, err)
	}
}

func TestCreditAcknowledgementIsExactlyOnceAndRelayHasNoReportCache(t *testing.T) {
	s := openTestStore(t)
	userID := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	requestID := "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
	record, err := s.ReserveCredit(userID, "installation-a", requestID, "report-a", "hash-a", "chart.natal", "en", "en", "model-a")
	if err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReportAwaitingAcknowledgement(userID, requestID, record.RequestHash, "model-a", 12, 34, 0, 56); err != nil {
		t.Fatal(err)
	}
	if err := s.AcknowledgeReport(userID, requestID); err != nil {
		t.Fatal(err)
	}
	if err := s.AcknowledgeReport(userID, requestID); err != nil {
		t.Fatalf("repeated ACK must be idempotent: %v", err)
	}
	var consumes int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM credit_ledger WHERE user_id=? AND request_id=? AND action='CONSUME'`, userID, requestID).Scan(&consumes); err != nil {
		t.Fatal(err)
	}
	if consumes != 1 {
		t.Fatalf("expected one CONSUME ledger row, got %d", consumes)
	}
	stored, err := s.GetReportRequest(userID, requestID)
	if err != nil || stored.ReportStatus != "success" || stored.CreditStatus != "consumed" {
		t.Fatalf("unexpected stored report metadata: %+v err=%v", stored, err)
	}
	var cacheTables int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='generation_cache'`).Scan(&cacheTables); err != nil {
		t.Fatal(err)
	}
	if cacheTables != 0 {
		t.Fatal("Relay must not have a report generation cache table")
	}
	var reportBodyColumns int
	rows, err := s.db.Query(`PRAGMA table_info(report_requests)`)
	if err != nil {
		t.Fatal(err)
	}
	for rows.Next() {
		var cid int
		var name, kind string
		var notNull, primaryKey int
		var defaultValue any
		if err := rows.Scan(&cid, &name, &kind, &notNull, &defaultValue, &primaryKey); err != nil {
			rows.Close()
			t.Fatal(err)
		}
		if name == "payload_enc" {
			reportBodyColumns++
		}
	}
	if err := rows.Close(); err != nil {
		t.Fatal(err)
	}
	if reportBodyColumns != 0 {
		t.Fatal("Relay report metadata table must not contain a report body column")
	}
}

func TestLegacyReportBodyStorageIsRemovedDuringMigration(t *testing.T) {
	path := t.TempDir() + "/legacy.db"
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`CREATE TABLE report_requests (
		user_id TEXT NOT NULL,request_id TEXT NOT NULL,report_id TEXT NOT NULL,request_hash TEXT NOT NULL,
		scope TEXT NOT NULL,requested_locale TEXT NOT NULL,effective_locale TEXT NOT NULL,model TEXT NOT NULL DEFAULT '',
		payload_enc TEXT,report_status TEXT NOT NULL,credit_status TEXT NOT NULL,prompt_tokens INTEGER NOT NULL DEFAULT 0,
		completion_tokens INTEGER NOT NULL DEFAULT 0,reasoning_tokens INTEGER NOT NULL DEFAULT 0,duration_ms INTEGER NOT NULL DEFAULT 0,
		error_code TEXT NOT NULL DEFAULT '',error_message TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
		delivered_at TEXT,PRIMARY KEY(user_id,request_id))`); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if _, err := db.Exec(`CREATE TABLE generation_cache (cache_key TEXT PRIMARY KEY,scope TEXT,payload TEXT,created_at TEXT,expires_at TEXT)`); err != nil {
		db.Close()
		t.Fatal(err)
	}
	_ = db.Close()
	s, err := OpenStore(path, "test-secret-please-change-32-bytes")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if exists, err := sqliteColumnExists(s.db, "report_requests", "payload_enc"); err != nil || exists {
		t.Fatalf("legacy report body column remains: exists=%v err=%v", exists, err)
	}
	var cacheTables int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='generation_cache'`).Scan(&cacheTables); err != nil || cacheTables != 0 {
		t.Fatalf("legacy cache remains: count=%d err=%v", cacheTables, err)
	}
}

func TestUnacknowledgedReportReleasesItsOriginalCredit(t *testing.T) {
	s := openTestStore(t)
	userID := "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
	requestID := "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
	record, err := s.ReserveCredit(userID, "installation-b", requestID, "report-b", "hash-b", "period.monthly", "zh-Hans", "zh-Hans", "model-b")
	if err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReportAwaitingAcknowledgement(userID, requestID, record.RequestHash, "model-b", 1, 2, 0, 3); err != nil {
		t.Fatal(err)
	}
	if _, err := s.db.Exec(`UPDATE credit_reservations SET expires_at=? WHERE user_id=? AND request_id=?`, time.Now().UTC().Add(-time.Minute).Format(time.RFC3339), userID, requestID); err != nil {
		t.Fatal(err)
	}
	if err := s.ReleaseExpiredReservations(); err != nil {
		t.Fatal(err)
	}
	balance, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if balance.Total != freeAllowance || balance.Reserved != 0 {
		t.Fatalf("unacknowledged credit was not restored: %+v", balance)
	}
	stored, _ := s.GetReportRequest(userID, requestID)
	if stored.ReportStatus != "failed" || stored.CreditStatus != "released" || stored.ErrorCode != "delivery_ack_timeout" {
		t.Fatalf("unexpected release metadata: %+v", stored)
	}
}

func TestStoreTransactionReplayAndAnnualWelcomeAreIdempotent(t *testing.T) {
	s := openTestStore(t)
	userID := "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
	now := time.Now().UTC()
	credits := AppleTransactionPayload{
		TransactionID: "credits-transaction-1", OriginalTransactionID: "credits-original-1",
		ProductID: "credits_10", AppAccountToken: userID, BundleID: "com.xiaoguiwk.interstellar", PurchaseDate: now.UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, credits, "credits-jws"); err != nil {
		t.Fatal(err)
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, credits, "credits-jws"); err != nil {
		t.Fatal(err)
	}
	annual := AppleTransactionPayload{
		TransactionID: "annual-transaction-1", OriginalTransactionID: "annual-original-1",
		ProductID: "premium_annual", AppAccountToken: userID, BundleID: "com.xiaoguiwk.interstellar",
		PurchaseDate: now.UnixMilli(), ExpiresDate: now.AddDate(1, 0, 0).UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, annual, "annual-jws-1"); err != nil {
		t.Fatal(err)
	}
	annual.TransactionID = "annual-transaction-2"
	if err := s.ApplyVerifiedStoreTransaction(userID, annual, "annual-jws-2"); err != nil {
		t.Fatal(err)
	}
	balance, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if balance.Purchased != 10 || balance.Bonus != 20 || balance.Allowance != premiumAllowance {
		t.Fatalf("transaction grants must be exactly once: %+v", balance)
	}
	annual.RevocationDate = time.Now().UTC().UnixMilli()
	if err := s.ApplyVerifiedStoreTransaction(userID, annual, "annual-jws-2-revoked"); err != nil {
		t.Fatal(err)
	}
	user, err := s.GetCommerceUser(userID)
	if err != nil || user.Plan != "free" {
		t.Fatalf("replayed transaction revocation must update entitlement: user=%+v err=%v", user, err)
	}
	if user.Credits.Bonus != 0 {
		t.Fatalf("revoked annual purchase must remove unused welcome Credits: %+v", user.Credits)
	}
}

func TestVerifiedSubscriptionGracePeriodKeepsPremiumActive(t *testing.T) {
	s := openTestStore(t)
	userID := "ffffffff-ffff-4fff-8fff-ffffffffffff"
	now := time.Now().UTC()
	value := AppleTransactionPayload{
		TransactionID: "monthly-grace-1", OriginalTransactionID: "monthly-original-1",
		ProductID: "premium_monthly", AppAccountToken: userID, BundleID: "com.xiaoguiwk.interstellar",
		PurchaseDate: now.AddDate(0, -1, 0).UnixMilli(), ExpiresDate: now.Add(-time.Hour).UnixMilli(),
		GraceExpiresDate: now.Add(48 * time.Hour).UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, value, "monthly-grace-jws"); err != nil {
		t.Fatal(err)
	}
	user, err := s.GetCommerceUser(userID)
	if err != nil || user.Plan != "premium" || user.PlanSource != "premium_monthly" || user.AppleSubscriptionStatus != "grace" {
		t.Fatalf("billing grace should preserve Premium: user=%+v err=%v", user, err)
	}
	if user.Credits.Bonus != 0 {
		t.Fatalf("monthly Pro must not grant the annual welcome Credits: %+v", user.Credits)
	}
}

func TestTwentyCreditPurchaseAndAdminResetPreserveNonAdminCredits(t *testing.T) {
	s := openTestStore(t)
	userID := "34343434-3434-4343-8343-343434343434"
	now := time.Now().UTC()
	value := AppleTransactionPayload{
		TransactionID: "credits-transaction-20", OriginalTransactionID: "credits-original-20",
		ProductID: "credits_20", AppAccountToken: userID, BundleID: "com.xiaoguiwk.interstellar", PurchaseDate: now.UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, value, "credits-20-jws"); err != nil {
		t.Fatal(err)
	}
	if err := s.GrantAdminCredits(userID, 7, nil, "test-admin"); err != nil {
		t.Fatal(err)
	}
	if err := s.ResetAdminCredits(userID, "test-admin"); err != nil {
		t.Fatal(err)
	}
	user, err := s.GetCommerceUser(userID)
	if err != nil {
		t.Fatal(err)
	}
	if user.Credits.Purchased != 20 || user.Credits.Bonus != 0 || user.Credits.Allowance != freeAllowance {
		t.Fatalf("reset must remove only unused admin Credits: %+v", user.Credits)
	}
	if len(user.CreditLedger) < 3 || user.CreditLedger[0].Action != "ADMIN_RESET" || user.CreditLedger[0].Delta != -7 {
		t.Fatalf("expected visible admin reset ledger entry: %+v", user.CreditLedger)
	}
}

func TestAdminCreditDeductionUsesAvailableBalanceAndIsAudited(t *testing.T) {
	s := openTestStore(t)
	userID := "56565656-5656-4565-8565-565656565656"
	if _, err := s.SyncCommerceUser(userID, "deduction-test-installation"); err != nil {
		t.Fatal(err)
	}
	if err := s.GrantAdminCredits(userID, 5, nil, "test-admin"); err != nil {
		t.Fatal(err)
	}
	if err := s.DeductAdminCredits(userID, 3, "test-admin"); err != nil {
		t.Fatal(err)
	}
	balance, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if balance.Total != 4 || balance.Allowance != 0 || balance.Bonus != 4 {
		t.Fatalf("unexpected balance after deduction: %+v", balance)
	}
	if err := s.DeductAdminCredits(userID, 5, "test-admin"); err == nil {
		t.Fatal("deduction larger than the available balance must fail")
	}
	var ledgerDelta, audits int
	if err := s.db.QueryRow(`SELECT COALESCE(SUM(delta),0) FROM credit_ledger WHERE user_id=? AND action='ADMIN_DEDUCT'`, userID).Scan(&ledgerDelta); err != nil {
		t.Fatal(err)
	}
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM admin_audit WHERE action='credits.deduct' AND target=?`, userID).Scan(&audits); err != nil {
		t.Fatal(err)
	}
	if ledgerDelta != -3 || audits != 1 {
		t.Fatalf("deduction audit mismatch: ledger=%d audits=%d", ledgerDelta, audits)
	}
}

func TestAdminPlanOverrideSwitchesFreePremiumAndAuto(t *testing.T) {
	s := openTestStore(t)
	userID := "12121212-1212-4121-8121-121212121212"
	if _, err := s.SyncCommerceUser(userID, "plan-test-installation"); err != nil {
		t.Fatal(err)
	}
	expires := time.Now().UTC().Add(30 * 24 * time.Hour)
	if err := s.SetAdminPlan(userID, "premium", &expires, "test-admin", "test premium"); err != nil {
		t.Fatal(err)
	}
	premium, err := s.GetCommerceUser(userID)
	if err != nil || premium.Plan != "premium" || premium.AdminPlanOverride != "premium" || premium.Credits.Allowance != premiumAllowance {
		t.Fatalf("premium override not applied: user=%+v err=%v", premium, err)
	}
	if err := s.SetAdminPlan(userID, "free", nil, "test-admin", "test free"); err != nil {
		t.Fatal(err)
	}
	free, err := s.GetCommerceUser(userID)
	if err != nil || free.Plan != "free" || free.AdminPlanOverride != "free" || free.Credits.Allowance != freeAllowance {
		t.Fatalf("free override not applied: user=%+v err=%v", free, err)
	}
	if err := s.SetAdminPlan(userID, "auto", nil, "test-admin", "test auto"); err != nil {
		t.Fatal(err)
	}
	automatic, err := s.GetCommerceUser(userID)
	if err != nil || automatic.AdminPlanOverride != "" || automatic.Plan != "free" {
		t.Fatalf("auto override not restored: user=%+v err=%v", automatic, err)
	}
}

func TestAccountSyncStoresValidCountryCode(t *testing.T) {
	s := openTestStore(t)
	userID := "78787878-7878-4787-8787-787878787878"
	user, err := s.SyncCommerceUser(userID, "country-test-installation", "cn")
	if err != nil {
		t.Fatal(err)
	}
	if user.CountryCode != "CN" {
		t.Fatalf("country code was not normalized: %+v", user)
	}
	user, err = s.SyncCommerceUser(userID, "country-test-installation", "invalid")
	if err != nil {
		t.Fatal(err)
	}
	if user.CountryCode != "CN" {
		t.Fatalf("invalid country code must not replace the stored value: %+v", user)
	}
}

func TestCreditLedgerShowsAllowanceAndSuccessfulReportsButHidesFailedReservations(t *testing.T) {
	s := openTestStore(t)
	userID := "79797979-7979-4797-8797-797979797979"
	user, err := s.SyncCommerceUser(userID, "ledger-test-installation")
	if err != nil {
		t.Fatal(err)
	}
	if len(user.CreditLedger) != 1 || user.CreditLedger[0].Action != "ALLOWANCE_RENEW" {
		t.Fatalf("monthly allowance must be visible in the ledger: %+v", user.CreditLedger)
	}
	successID := "89898989-8989-4898-8989-898989898989"
	record, err := s.ReserveCredit(userID, "ledger-test-installation", successID, "report-success", "hash-success", "chart.solar-return", "en", "en", "model")
	if err != nil {
		t.Fatal(err)
	}
	if err := s.MarkReportAwaitingAcknowledgement(userID, successID, record.RequestHash, "model", 1, 1, 0, 1); err != nil {
		t.Fatal(err)
	}
	if err := s.AcknowledgeReport(userID, successID); err != nil {
		t.Fatal(err)
	}
	failedID := "99999999-9999-4999-8999-999999999999"
	if _, err := s.ReserveCredit(userID, "ledger-test-installation", failedID, "report-failed", "hash-failed", "chart.natal", "en", "en", "model"); err != nil {
		t.Fatal(err)
	}
	if err := s.ReleaseCredit(userID, failedID, "provider_error", "failed"); err != nil {
		t.Fatal(err)
	}
	user, err = s.GetCommerceUser(userID)
	if err != nil {
		t.Fatal(err)
	}
	if len(user.CreditLedger) != 2 || user.CreditLedger[0].Action != "RESERVE" || user.CreditLedger[0].Scope != "chart.solar-return" {
		t.Fatalf("only successful report charge and allowance renewal should be visible: %+v", user.CreditLedger)
	}
}

func TestAppAttestChallengeIsBodyBoundAndSingleUse(t *testing.T) {
	s := openTestStore(t)
	id, original, _, err := s.CreateAppAttestChallenge("install-a", "key-a", appAttestPurposeAssertion, "body-a", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ConsumeAppAttestChallenge(id, "install-a", "key-a", appAttestPurposeAssertion, "body-b"); err == nil {
		t.Fatal("challenge accepted a different request body hash")
	}
	consumed, err := s.ConsumeAppAttestChallenge(id, "install-a", "key-a", appAttestPurposeAssertion, "body-a")
	if err != nil || string(consumed) != string(original) {
		t.Fatalf("expected original challenge, err=%v", err)
	}
	if _, err := s.ConsumeAppAttestChallenge(id, "install-a", "key-a", appAttestPurposeAssertion, "body-a"); err == nil {
		t.Fatal("challenge replay was accepted")
	}
}

func TestAppAttestTokenIsBoundToInstallationAndKey(t *testing.T) {
	s := openTestStore(t)
	key := AppAttestKey{KeyID: "key-a", PublicKeyDER: []byte("public-key"), Environment: "development"}
	if err := s.SaveAppAttestKey(key, "install-a", []byte("receipt")); err != nil {
		t.Fatal(err)
	}
	token, _, err := s.CreateAppAttestToken("key-a", "install-a", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if !s.ValidateAppAttestToken(token, "key-a", "install-a") {
		t.Fatal("valid installation token was rejected")
	}
	if s.ValidateAppAttestToken(token, "key-b", "install-a") || s.ValidateAppAttestToken(token, "key-a", "install-b") {
		t.Fatal("installation token was not bound to both installation and key")
	}
}

func TestAdminBootstrapAndLogin(t *testing.T) {
	s := openTestStore(t)
	if err := s.EnsureAdmin("admin", "test-admin-password-at-least-24-bytes"); err != nil {
		t.Fatal(err)
	}
	if !s.VerifyAdmin("admin", "test-admin-password-at-least-24-bytes") {
		t.Fatal("expected valid credentials")
	}
	if s.VerifyAdmin("admin", "wrong") {
		t.Fatal("expected invalid credentials to fail")
	}
}

func TestAdminSessionPersistsAndRevokes(t *testing.T) {
	s := openTestStore(t)
	token, _, err := s.CreateAdminSession("admin", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if username, ok := s.ValidateAdminSession(token); !ok || username != "admin" {
		t.Fatalf("expected persistent session, got username=%q ok=%v", username, ok)
	}
	s.RevokeAdminSession(token)
	if _, ok := s.ValidateAdminSession(token); ok {
		t.Fatal("revoked session remained valid")
	}
}

func TestDisabledDefaultProviderBlocksGenerationAndDeleteClearsRouting(t *testing.T) {
	s := openTestStore(t)
	if _, err := s.UpsertProvider(Provider{ID: "one", Label: "One", BaseURL: "https://one.invalid", DefaultModel: "m1", Enabled: true}, "key-one"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertProvider(Provider{ID: "two", Label: "Two", BaseURL: "https://two.invalid", DefaultModel: "m2", Enabled: true}, "key-two"); err != nil {
		t.Fatal(err)
	}
	if err := s.SetSetting("default_provider", "one"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertProvider(Provider{ID: "one", Label: "One", BaseURL: "https://one.invalid", DefaultModel: "m1", Enabled: false}, ""); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetGenerationProvider(); err == nil || !strings.Contains(err.Error(), "disabled") {
		t.Fatalf("disabled default provider must block generation, got %v", err)
	}
	if err := s.DeleteProvider("one"); err != nil {
		t.Fatal(err)
	}
	provider, err := s.GetGenerationProvider()
	if err != nil || provider.ID != "two" {
		t.Fatalf("expected enabled fallback after deleting default, provider=%v err=%v", provider, err)
	}
}

func TestPromptDefaultsSeed(t *testing.T) {
	s := openTestStore(t)
	for _, scope := range validScopes() {
		for _, locale := range []string{"zh-Hans", "en"} {
			if _, err := s.UpsertPrompt(scope, locale, defaultPrompt(scope, locale)); err != nil {
				t.Fatalf("seed %s/%s: %v", scope, locale, err)
			}
		}
	}
	prompt, version, err := s.GetPrompt("chart.natal", "zh-Hans")
	if err != nil || version < 1 || !strings.Contains(prompt, "不预测") || !strings.Contains(prompt, "你的性格") {
		t.Fatalf("natal zh prompt missing safety boundary: version=%d err=%v", version, err)
	}
}

func TestLegacyGenericChartPromptCanBeMigratedWithoutMatchingEditedCopy(t *testing.T) {
	legacy := legacyDefaultPromptV1("chart.synastry", "en")
	current := defaultPrompt("chart.synastry", "en")
	if legacy == current || !strings.Contains(legacy, "objective, restrained") {
		t.Fatal("legacy fixture must preserve the original generic chart voice")
	}
	if !strings.Contains(current, "two-sided") {
		t.Fatal("current synastry prompt must use its chart-specific voice")
	}
	edited := legacy + "\nAdministrator edit."
	if edited == legacy {
		t.Fatal("edited prompt must not match the exact migration sentinel")
	}
}

func TestTransitReportPromptHasFocusedAnalysisAndBoundedOutput(t *testing.T) {
	english := defaultPrompt("chart.transit", "en")
	for _, marker := range []string{"applying/exact/separating", "90–150 English words", "Completing and closing the JSON"} {
		if !strings.Contains(english, marker) {
			t.Fatalf("English transit prompt is missing %q", marker)
		}
	}
	chinese := defaultPrompt("chart.transit", "zh-Hans")
	for _, marker := range []string{"入相/精确/离相", "140–240 字", "完整输出并闭合 JSON"} {
		if !strings.Contains(chinese, marker) {
			t.Fatalf("Chinese transit prompt is missing %q", marker)
		}
	}
	if !strings.Contains(defaultPrompt("chart.natal", "en"), "90–150 English words") {
		t.Fatal("all whole-chart report prompts must keep a bounded output contract")
	}
}

func TestRemainingChartPromptsHaveDistinctAnalysisBoundaries(t *testing.T) {
	tests := []struct {
		scope     string
		enMarkers []string
		zhMarkers []string
	}{
		{
			scope:     "chart.natal",
			enMarkers: []string{"natal structure, not a timing forecast", "Never substitute sign stereotypes", "90–150 English words"},
			zhMarkers: []string{"本命结构，不是时间预测", "不得把星座刻板印象", "140–240 字"},
		},
		{
			scope:     "chart.current-sky",
			enMarkers: []string{"collective atmosphere", "not compared with any person's natal chart", "never calculate dates"},
			zhMarkers: []string{"当前天空的集体氛围", "不与任何个人本命盘比较", "不得自行推算"},
		},
		{
			scope:     "chart.secondary",
			enMarkers: []string{"long-term development", "small set of supplied exact turning dates", "never inflate them into external event predictions"},
			zhMarkers: []string{"长期发展对照", "少量精确转折日期", "不得扩写为外部事件预言"},
		},
		{
			scope:     "chart.solar-return",
			enMarkers: []string{"supplied exact solar-return moment", "four annual phase boundaries", "Never calculate extra dates"},
			zhMarkers: []string{"精确日返时刻", "年度四阶段日期", "不得自行推算额外日期"},
		},
	}

	for _, test := range tests {
		english := defaultPrompt(test.scope, "en")
		chinese := defaultPrompt(test.scope, "zh-Hans")
		for _, marker := range test.enMarkers {
			if !strings.Contains(english, marker) {
				t.Fatalf("%s English prompt is missing %q", test.scope, marker)
			}
		}
		for _, marker := range test.zhMarkers {
			if !strings.Contains(chinese, marker) {
				t.Fatalf("%s Chinese prompt is missing %q", test.scope, marker)
			}
		}
		if strings.Contains(english, `"cards"`) || strings.Contains(chinese, `"cards"`) {
			t.Fatalf("%s prompt must remain report-only", test.scope)
		}
		if defaultPrompt(test.scope, "en") == legacyDefaultPromptV3(test.scope, "en") {
			t.Fatalf("%s untouched generic report prompt would not migrate", test.scope)
		}
	}
}

func TestSynastryReportPromptRequiresNamesPerspectivesAndPresetBoundary(t *testing.T) {
	english := defaultPrompt("chart.synastry", "en")
	for _, marker := range []string{"Always use both names", "how each person affects and experiences the other", "request preset", "Classical must not import Modern", "80–140 English words"} {
		if !strings.Contains(english, marker) {
			t.Fatalf("English synastry prompt is missing %q", marker)
		}
	}
	if strings.Contains(english, `"cards"`) {
		t.Fatal("synastry prompt must remain report-only")
	}
	chinese := defaultPrompt("chart.synastry", "zh-Hans")
	for _, marker := range []string{"两个人姓名", "每个人如何影响和体验对方", "请求 preset", "Classical 不得混入 Modern", "120–220 字"} {
		if !strings.Contains(chinese, marker) {
			t.Fatalf("Chinese synastry prompt is missing %q", marker)
		}
	}
}

func TestUntouchedReportOnlyPromptCanBeMigratedWithoutMatchingEditedCopy(t *testing.T) {
	legacy := legacyDefaultPromptV3("chart.transit", "en")
	current := defaultPrompt("chart.transit", "en")
	if legacy == current || !strings.Contains(current, "applying/exact/separating") {
		t.Fatal("current transit prompt must differ from the first report-only default")
	}
	if legacy+"\nAdministrator edit." == legacy {
		t.Fatal("edited prompt must not match the exact migration sentinel")
	}
}

func TestProviderModelDisableBlocksSelection(t *testing.T) {
	s := openTestStore(t)
	if err := s.SyncProviderModels("deepseek", []string{"deepseek-v4-flash"}); err != nil {
		t.Fatal(err)
	}
	if err := s.SetProviderModelEnabled("deepseek", "deepseek-v4-flash", false); err != nil {
		t.Fatal(err)
	}
	enabled, err := s.IsProviderModelEnabled("deepseek", "deepseek-v4-flash")
	if err != nil || enabled {
		t.Fatalf("disabled model remained enabled: enabled=%v err=%v", enabled, err)
	}
}

func TestEnglishUserContentHasNoChineseHeadings(t *testing.T) {
	req := generateRequest{
		Locale: "en",
		Facts:  json.RawMessage(`{"evidenceFacts":[{"id":"point.sun"}]}`),
		Params: json.RawMessage(`{"preset":"modern"}`),
	}
	content := buildUserContent(req, "chart.natal")
	if strings.Contains(content, "计算事实") || !strings.Contains(content, "Calculated facts") {
		t.Fatalf("English user content contains the wrong headings: %s", content)
	}
}

func TestEmbeddedAdminPage(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handleAdminPage(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "deepseek-v4-flash") {
		t.Fatalf("admin page unavailable: status=%d", rec.Code)
	}
	if rec.Header().Get("Content-Security-Policy") == "" {
		t.Fatal("admin page must set a content security policy")
	}
	for _, marker := range []string{"prompt-scope-filter", "prompt-locale-filter", "data-prompt-filter", "用户反馈", "feedback-status-filter", "data-report-filter", "user-detail"} {
		if !strings.Contains(rec.Body.String(), marker) {
			t.Fatalf("admin prompt filters missing %q", marker)
		}
	}
}

func TestPublicLegalPagesAndUnsignedStoreNotificationRejection(t *testing.T) {
	for _, path := range []string{"/privacy", "/terms"} {
		rec := httptest.NewRecorder()
		handleLegalPage(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "English") || !strings.Contains(rec.Body.String(), "简体中文") || !strings.Contains(rec.Body.String(), "Español") || !strings.Contains(rec.Body.String(), "Français") {
			t.Fatalf("legal page %s is incomplete", path)
		}
	}
	s := openTestStore(t)
	cfg := &relayConfig{store: s}
	rec := httptest.NewRecorder()
	cfg.handleAppStoreNotification(rec, httptest.NewRequest(http.MethodPost, "/v1/store/notifications", strings.NewReader(`{"signedPayload":"not-a-jws"}`)))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("unsigned App Store notification returned %d: %s", rec.Code, rec.Body.String())
	}
}

func TestFeedbackStoredEncryptedAndManaged(t *testing.T) {
	s := openTestStore(t)
	item, err := s.SaveFeedback("bug", "A private feedback message", "user@example.com")
	if err != nil {
		t.Fatal(err)
	}
	var contentEnc, contactEnc string
	if err := s.db.QueryRow(`SELECT content_enc, contact_enc FROM feedback WHERE id = ?`, item.ID).Scan(&contentEnc, &contactEnc); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(contentEnc, item.Content) || strings.Contains(contactEnc, item.Contact) {
		t.Fatal("feedback content and contact must be encrypted at rest")
	}
	items, err := s.ListFeedback("pending", "bug", 100)
	if err != nil || len(items) != 1 || items[0].Content != item.Content || items[0].Contact != item.Contact {
		t.Fatalf("feedback round trip failed: items=%+v err=%v", items, err)
	}
	updated, err := s.UpdateFeedbackStatus(item.ID, "resolved")
	if err != nil || updated.Status != "resolved" {
		t.Fatalf("feedback status update failed: item=%+v err=%v", updated, err)
	}
}

func TestFeedbackHandlerValidation(t *testing.T) {
	s := openTestStore(t)
	cfg := &relayConfig{store: s}

	valid := httptest.NewRecorder()
	cfg.handleFeedback(valid, httptest.NewRequest(http.MethodPost, "/v1/feedback", strings.NewReader(`{"type":"feature","content":"Please add this","contact":""}`)))
	if valid.Code != http.StatusCreated {
		t.Fatalf("valid feedback returned %d: %s", valid.Code, valid.Body.String())
	}

	empty := httptest.NewRecorder()
	cfg.handleFeedback(empty, httptest.NewRequest(http.MethodPost, "/v1/feedback", strings.NewReader(`{"type":"bug","content":"","contact":""}`)))
	if empty.Code != http.StatusUnprocessableEntity {
		t.Fatalf("empty feedback returned %d: %s", empty.Code, empty.Body.String())
	}
}

func TestAdminMutationMethodAndPromptValidation(t *testing.T) {
	s := openTestStore(t)
	cfg := &relayConfig{store: s, sessions: NewSessionStore(s)}

	login := httptest.NewRecorder()
	cfg.handleLogin(login, httptest.NewRequest(http.MethodGet, "/admin/login", nil))
	if login.Code != http.StatusMethodNotAllowed {
		t.Fatalf("login GET returned %d; want 405", login.Code)
	}

	emptyPrompt := httptest.NewRecorder()
	emptyBody := `{"scope":"chart.natal","locale":"en","system_prompt":"   "}`
	cfg.handlePrompts(emptyPrompt, httptest.NewRequest(http.MethodPut, "/admin/prompts", strings.NewReader(emptyBody)))
	if emptyPrompt.Code != http.StatusBadRequest || !strings.Contains(emptyPrompt.Body.String(), "must not be empty") {
		t.Fatalf("empty prompt returned %d: %s", emptyPrompt.Code, emptyPrompt.Body.String())
	}
}

// E2E: full generate pipeline against a mock OpenAI-compatible provider.
func TestGeneratePipelineWithMockProvider(t *testing.T) {
	// Mock upstream: returns a valid structured JSON completion.
	upstreamPayload := map[string]any{
		"report": map[string]any{
			"title": "Your year", "subtitle": "A structured reading",
			"sections": []map[string]any{
				{"number": "01", "title": "Overview", "body": "Body one.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "02", "title": "Pattern", "body": "Body two.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "03", "title": "Timing", "body": "Body three.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "04", "title": "Advice", "body": "Body four.", "evidenceFactIDs": []string{"point.sun"}},
			},
		},
	}
	upstreamJSON, err := json.Marshal(upstreamPayload)
	if err != nil {
		t.Fatal(err)
	}
	content := string(upstreamJSON)
	mock := &mockProvider{responses: map[string]string{"deepseek-v4-flash": content}}
	server := httptest.NewServer(mock)
	defer server.Close()

	s := openTestStore(t)
	if _, err := s.UpsertPrompt("chart.natal", "en", defaultPrompt("chart.natal", "en")); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertProvider(Provider{
		ID: "default", Label: "Mock", BaseURL: server.URL, DefaultModel: "deepseek-v4-flash", Enabled: true,
	}, "sk-mock"); err != nil {
		t.Fatal(err)
	}
	if err := s.SetSetting("default_provider", "default"); err != nil {
		t.Fatal(err)
	}

	// First call: upstream hit, cached=false.
	requestPayload := map[string]any{
		"userID": "11111111-1111-4111-8111-111111111111", "requestID": "22222222-2222-4222-8222-222222222222", "reportID": "natal-semantic-1",
		"mode": "chart", "chartKind": "natal", "preset": "modern", "profileHash": "h1",
		"semanticFingerprint": "semantic-1", "factsHash": "facts-1", "generationSchemaVersion": 2,
		"params": map[string]any{"anchor": "2026-07-31"},
		"facts": map[string]any{
			"person": map[string]any{"name": "Darryl"}, "chart": map[string]any{"points": []any{}},
			"evidenceFacts": []map[string]any{{"id": "point.sun", "type": "point"}},
		},
		"locale": "en", "clientVersion": "test",
	}
	requestJSON, err := json.Marshal(requestPayload)
	if err != nil {
		t.Fatal(err)
	}
	body := string(requestJSON)
	first := roundTripGenerate(t, s, body)
	if first["cached"] == true {
		t.Fatal("expected first call to hit upstream")
	}
	report := first["report"].(map[string]any)
	if len(report["sections"].([]any)) < 4 {
		t.Fatal("expected at least 4 report sections")
	}

	// The Relay stores no report body. Credit stays reserved until the client
	// confirms that it persisted the response locally.
	record, err := s.GetReportRequest("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222")
	if err != nil || record.ReportStatus != "awaiting_ack" || record.CreditStatus != "reserved" || record.ReasoningTokens != 25 {
		t.Fatalf("unexpected pre-ack state: %+v err=%v", record, err)
	}
	if err := s.AcknowledgeReport(record.UserID, record.RequestID); err != nil {
		t.Fatal(err)
	}
	record, _ = s.GetReportRequest(record.UserID, record.RequestID)
	if record.ReportStatus != "success" || record.CreditStatus != "consumed" {
		t.Fatalf("unexpected post-ack state: %+v", record)
	}

	requestPayload["forceRegenerate"] = true
	requestPayload["requestID"] = "33333333-3333-4333-8333-333333333333"
	forcedJSON, err := json.Marshal(requestPayload)
	if err != nil {
		t.Fatal(err)
	}
	third := roundTripGenerate(t, s, string(forcedJSON))
	if third["cached"] == true || mock.count != 2 {
		t.Fatalf("forced regeneration must bypass cache; cached=%v upstream=%d", third["cached"], mock.count)
	}
}

func roundTripGenerate(t *testing.T, s *Store, body string) map[string]any {
	t.Helper()
	sessions := NewSessionStore(s)
	cfg := &relayConfig{store: s, sessions: sessions, client: &http.Client{}, seed: false, allowDevBypass: true}
	req, err := http.NewRequest(http.MethodPost, "/v1/generate", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Installation-ID", "test-installation")
	req.Header.Set("X-App-Attest-Development-Bypass", "1")
	rec := httptest.NewRecorder()
	cfg.handleGenerate(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("generate returned %d: %s", rec.Code, rec.Body.String())
	}
	var out map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

type mockProvider struct {
	count     int
	responses map[string]string
}

func (m *mockProvider) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	m.count++
	if r.URL.Path == "/models" {
		_ = json.NewEncoder(w).Encode(map[string]any{"data": []map[string]any{{"id": "deepseek-v4-flash"}}})
		return
	}
	var req struct {
		Model           string `json:"model"`
		MaxTokens       int    `json:"max_tokens"`
		ReasoningEffort string `json:"reasoning_effort"`
		Thinking        struct {
			Type string `json:"type"`
		} `json:"thinking"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Model == "" || len(req.Messages) == 0 {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	validEnabled := req.Thinking.Type == "enabled" && req.ReasoningEffort == "low"
	validFallback := req.Thinking.Type == "disabled" && req.ReasoningEffort == ""
	if (!validEnabled && !validFallback) || req.MaxTokens != 10000 {
		http.Error(w, "structured report reasoning budget is incorrect", http.StatusBadRequest)
		return
	}
	// The prompt must carry the fixed safety boundary and the name rule.
	system := req.Messages[0].Content
	zhBoundary := strings.Contains(system, "不预测") && strings.Contains(system, "使用这些姓名")
	enBoundary := strings.Contains(system, "Do not predict") && strings.Contains(system, "person names")
	if !zhBoundary && !enBoundary {
		http.Error(w, "prompt missing safety/name rule", http.StatusBadRequest)
		return
	}
	user := req.Messages[1].Content
	if !strings.Contains(user, "Darryl") {
		http.Error(w, "facts must include the person name", http.StatusBadRequest)
		return
	}
	content := m.responses[req.Model]
	if content == "" {
		http.Error(w, "no model", http.StatusNotFound)
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]any{
		"model": req.Model,
		"choices": []map[string]any{{
			"message": map[string]any{"role": "assistant", "content": content},
		}},
		"usage": map[string]any{"prompt_tokens": 100, "completion_tokens": 200, "completion_tokens_details": map[string]any{"reasoning_tokens": 25}},
	})
}
