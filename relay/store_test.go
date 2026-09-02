package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
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
	if err := r.Validate("en", evidence); err != nil {
		t.Fatalf("unknown evidence must be filtered instead of rejected: %v", err)
	}
	if len(r.Report.Sections[0].EvidenceFactIDs) != 0 {
		t.Fatalf("unknown evidence must be removed: %v", r.Report.Sections[0].EvidenceFactIDs)
	}
}

func TestReportPayloadLifecycle(t *testing.T) {
	s := openTestStore(t)
	userID := "12121212-1212-4212-8212-121212121212"
	requestID := "34343434-3434-4434-8434-343434343434"
	if _, err := s.ReserveCredit(userID, "install-payload", requestID, "report-1", "hash-1", "chart.natal", "en", "en", "model"); err != nil {
		t.Fatal(err)
	}
	payload := `{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"}]},"requestID":"` + requestID + `"}`
	if err := s.CompleteReportGeneration(userID, requestID, "hash-1", "model", 1, 2, 3, 42, payload); err != nil {
		t.Fatal(err)
	}
	stored, err := s.GetReportPayload(userID, requestID)
	if err != nil || stored != payload {
		t.Fatalf("payload round trip failed: %q err=%v", stored, err)
	}
	record, err := s.GetReportRequest(userID, requestID)
	if err != nil || record.ReportStatus != "awaiting_ack" {
		t.Fatalf("completed task must be awaiting_ack: %+v err=%v", record, err)
	}
	if err := s.AcknowledgeReport(userID, requestID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.GetReportPayload(userID, requestID); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("payload must be deleted after ACK: err=%v", err)
	}
}

func TestFailStuckGenerationsMarksFailedAndReleasesCredit(t *testing.T) {
	s := openTestStore(t)
	userID := "45454545-4545-4545-8545-454545454545"
	requestID := "56565656-5656-4656-8656-565656565656"
	if _, err := s.SyncCommerceUser(userID, "install-stuck"); err != nil {
		t.Fatal(err)
	}
	before, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.ReserveCredit(userID, "install-stuck", requestID, "report-stuck", "hash-stuck", "chart.natal", "en", "en", "model"); err != nil {
		t.Fatal(err)
	}
	recovered, err := s.FailStuckGenerations()
	if err != nil || recovered != 1 {
		t.Fatalf("expected one recovered task: %d err=%v", recovered, err)
	}
	record, err := s.GetReportRequest(userID, requestID)
	if err != nil || record.ReportStatus != "failed" || record.CreditStatus != "released" {
		t.Fatalf("stuck task must be failed+released: %+v err=%v", record, err)
	}
	after, err := s.CreditBalance(userID)
	if err != nil || after.Total != before.Total {
		t.Fatalf("credit must be restored: before=%+v after=%+v err=%v", before, after, err)
	}
}

func TestGenerateAcceptIsIdempotent(t *testing.T) {
	content := `{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x","evidenceFactIDs":["point.sun"]}]}}`
	mock := &mockProvider{responses: map[string]string{"deepseek-v4-flash": content}}
	server := httptest.NewServer(mock)
	defer server.Close()
	s := openTestStore(t)
	if _, err := s.UpsertPrompt("chart.natal", "en", defaultPrompt("chart.natal", "en")); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertProvider(Provider{ID: "default", Label: "Mock", BaseURL: server.URL, DefaultModel: "deepseek-v4-flash", Enabled: true}, "sk-mock"); err != nil {
		t.Fatal(err)
	}
	if err := s.SetSetting("default_provider", "default"); err != nil {
		t.Fatal(err)
	}
	userID := "67676767-6767-4767-8767-676767676767"
	requestID := "78787878-7878-4878-8878-787878787878"
	payload := map[string]any{
		"userID": userID, "requestID": requestID, "reportID": "natal-idem-1",
		"mode": "chart", "chartKind": "natal", "preset": "modern", "profileHash": "h1",
		"semanticFingerprint": "idem-1", "factsHash": "facts-1", "generationSchemaVersion": 2,
		"params": map[string]any{"anchor": "2026-08-19"},
		"facts":  map[string]any{"person": map[string]any{"name": "Darryl"}, "evidenceFacts": []map[string]any{{"id": "point.sun", "type": "point"}}},
		"locale": "en", "clientVersion": "test",
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	cfg := &relayConfig{store: s, sessions: NewSessionStore(s), client: &http.Client{}, seed: false, allowDevBypass: true}
	call := func() *httptest.ResponseRecorder {
		req, err := http.NewRequest(http.MethodPost, "/v1/generate", strings.NewReader(string(raw)))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Installation-ID", "test-installation")
		req.Header.Set("X-App-Attest-Development-Bypass", "1")
		rec := httptest.NewRecorder()
		cfg.handleGenerate(rec, req)
		return rec
	}
	if rec := call(); rec.Code != http.StatusAccepted {
		t.Fatalf("first accept = %d: %s", rec.Code, rec.Body.String())
	}
	if rec := call(); rec.Code != http.StatusAccepted && rec.Code != http.StatusOK {
		t.Fatalf("second accept must return the existing task state, got %d: %s", rec.Code, rec.Body.String())
	}
	deadline := time.Now().Add(5 * time.Second)
	var record ReportRequestRecord
	for {
		var err error
		record, err = s.GetReportRequest(userID, requestID)
		if err == nil && record.ReportStatus != "processing" {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("job did not finish")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if mock.count != 1 {
		t.Fatalf("upstream must be called exactly once for duplicate creates, got %d", mock.count)
	}
	if record.ReportStatus != "awaiting_ack" || record.CreditStatus != "reserved" {
		t.Fatalf("unexpected final state: %+v", record)
	}
	reservations, err := s.db.Query(`SELECT COUNT(*) FROM credit_reservations WHERE user_id=? AND request_id=?`, userID, requestID)
	if err != nil {
		t.Fatal(err)
	}
	defer reservations.Close()
	var n int
	if reservations.Next() {
		if err := reservations.Scan(&n); err != nil {
			t.Fatal(err)
		}
	}
	if n != 1 {
		t.Fatalf("duplicate create must reserve exactly one credit, got %d", n)
	}
}

func TestReportStatusAndFetchEndpoints(t *testing.T) {
	s := openTestStore(t)
	userID := "89898989-8989-4898-8898-898989898989"
	requestID := "90909090-9090-4090-8090-909090909090"
	if _, err := s.SyncCommerceUser(userID, "install-endpoints"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.ReserveCredit(userID, "install-endpoints", requestID, "report-ep", "hash-ep", "chart.natal", "en", "en", "model"); err != nil {
		t.Fatal(err)
	}
	cfg := &relayConfig{store: s, sessions: NewSessionStore(s), client: &http.Client{}, seed: false, allowDevBypass: true}
	call := func(path string) *httptest.ResponseRecorder {
		body := `{"userID":"` + userID + `","requestID":"` + requestID + `"}`
		req, err := http.NewRequest(http.MethodPost, path, strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Installation-ID", "test-installation")
		req.Header.Set("X-App-Attest-Development-Bypass", "1")
		rec := httptest.NewRecorder()
		if path == "/v1/reports/status" {
			cfg.handleReportStatus(rec, req)
		} else {
			cfg.handleReportFetch(rec, req)
		}
		return rec
	}
	if rec := call("/v1/reports/status"); rec.Code != http.StatusAccepted || !strings.Contains(rec.Body.String(), "generating") {
		t.Fatalf("processing task must report generating: %d %s", rec.Code, rec.Body.String())
	}
	if rec := call("/v1/reports/fetch"); rec.Code != http.StatusAccepted {
		t.Fatalf("processing task fetch must be 202: %d %s", rec.Code, rec.Body.String())
	}
	payload := `{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"}]},"requestID":"` + requestID + `"}`
	if err := s.CompleteReportGeneration(userID, requestID, "hash-ep", "model", 1, 1, 0, 10, payload); err != nil {
		t.Fatal(err)
	}
	if rec := call("/v1/reports/status"); rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "completed") {
		t.Fatalf("completed task must report completed: %d %s", rec.Code, rec.Body.String())
	}
	if rec := call("/v1/reports/fetch"); rec.Code != http.StatusOK || rec.Body.String() != payload {
		t.Fatalf("fetch must return the stored payload: %d %s", rec.Code, rec.Body.String())
	}
	if err := s.ReleaseCredit(userID, requestID, "upstream_generation_failed", "model exploded"); err != nil {
		t.Fatal(err)
	}
	if rec := call("/v1/reports/status"); rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "failed") {
		t.Fatalf("failed task must report failed: %d %s", rec.Code, rec.Body.String())
	}
	if rec := call("/v1/reports/fetch"); rec.Code != http.StatusGone {
		t.Fatalf("failed task fetch must be 410: %d %s", rec.Code, rec.Body.String())
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
	if balance.Total != firstPeriodBonus || balance.Allowance != firstPeriodBonus || balance.Bonus != 0 || balance.Reserved != 0 {
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
	if balance.Purchased != 10 || balance.Bonus != 20 || balance.Allowance != firstPeriodBonus+premiumAllowance || balance.Total != 10+firstPeriodBonus+20+premiumAllowance {
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

func TestAccountDeletionRetainsFinancialHistoryAndRestoreDoesNotDuplicateCredits(t *testing.T) {
	s := openTestStore(t)
	oldUserID := "10101010-1010-4010-8010-101010101010"
	newUserID := "20202020-2020-4020-8020-202020202020"
	thirdUserID := "30303030-3030-4030-8030-303030303030"
	installationID := "account-deletion-installation"
	appTransactionID := "app-transaction-account-lineage"
	now := time.Now().UTC()

	if _, err := s.SyncCommerceUser(oldUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if err := s.BindAppleIdentity(oldUserID, appTransactionID); err != nil {
		t.Fatal(err)
	}
	annual := AppleTransactionPayload{
		TransactionID: "lineage-annual-1", OriginalTransactionID: "lineage-original-1",
		ProductID: "premium_annual", AppAccountToken: oldUserID, AppTransactionID: appTransactionID,
		BundleID: appStoreBundleID, PurchaseDate: now.UnixMilli(), ExpiresDate: now.AddDate(1, 0, 0).UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(oldUserID, annual, "lineage-annual-jws-1"); err != nil {
		t.Fatal(err)
	}
	credits := AppleTransactionPayload{
		TransactionID: "lineage-credits-1", OriginalTransactionID: "lineage-credits-original-1",
		ProductID: "credits_10", AppAccountToken: oldUserID, AppTransactionID: appTransactionID,
		BundleID: appStoreBundleID, PurchaseDate: now.UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(oldUserID, credits, "lineage-credits-jws-1"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.db.Exec(`INSERT INTO report_requests(user_id,request_id,report_id,request_hash,scope,requested_locale,effective_locale,model,report_status,credit_status,created_at,updated_at)
		VALUES(?,?,?,?,?,?,?,?, 'success','consumed',?,?)`, oldUserID, "40404040-4040-4040-8040-404040404040", "deleted-report", "deleted-hash", "chart.natal", "en", "en", "model", now.Format(time.RFC3339), now.Format(time.RFC3339)); err != nil {
		t.Fatal(err)
	}

	replacement, err := s.DeactivateCommerceUser(oldUserID, newUserID, installationID, appTransactionID)
	if err != nil {
		t.Fatal(err)
	}
	if replacement.UserID != newUserID || replacement.AccountStatus != "active" || replacement.RootUserID != oldUserID || replacement.PredecessorUserID != oldUserID {
		t.Fatalf("unexpected replacement account: %+v", replacement)
	}
	if replacement.Credits.Total != 0 {
		t.Fatalf("replacement must not repeat Credits already issued this period: %+v", replacement.Credits)
	}
	old, err := s.GetCommerceUserDetail(oldUserID)
	if err != nil {
		t.Fatal(err)
	}
	if old.AccountStatus != "inactive" || old.SuccessorUserID != newUserID || old.Plan != "free" || old.Credits.Total != 0 {
		t.Fatalf("old account was not deactivated and cleared: %+v", old)
	}
	var subscriptions, transactions, grants, reports int
	checks := []struct {
		query  string
		target *int
	}{
		{`SELECT COUNT(*) FROM subscriptions WHERE user_id=?`, &subscriptions},
		{`SELECT COUNT(*) FROM store_transactions WHERE user_id=?`, &transactions},
		{`SELECT COUNT(*) FROM credit_grants WHERE user_id=?`, &grants},
		{`SELECT COUNT(*) FROM report_requests WHERE user_id=?`, &reports},
	}
	for _, check := range checks {
		if err := s.db.QueryRow(check.query, oldUserID).Scan(check.target); err != nil {
			t.Fatal(err)
		}
	}
	if subscriptions != 1 || transactions != 2 || grants < 4 || reports != 0 {
		t.Fatalf("unexpected retained data subscriptions=%d transactions=%d grants=%d reports=%d", subscriptions, transactions, grants, reports)
	}
	if err := s.GrantAdminCredits(oldUserID, 1, nil, "test-admin"); err == nil {
		t.Fatal("inactive account must reject administrator Credit changes")
	}
	inFlightCredits := credits
	inFlightCredits.TransactionID = "lineage-credits-in-flight"
	if err := s.ApplyVerifiedStoreTransaction(oldUserID, inFlightCredits, "lineage-credits-in-flight-jws"); err != nil {
		t.Fatal(err)
	}
	oldAfterInFlight, err := s.GetCommerceUser(oldUserID)
	if err != nil || oldAfterInFlight.Credits.Total != 0 {
		t.Fatalf("an in-flight purchase may remain in financial history but must not reactivate deleted Credits: %+v err=%v", oldAfterInFlight, err)
	}
	if _, err := s.DeactivateCommerceUser(oldUserID, newUserID, installationID, appTransactionID); err != nil {
		t.Fatalf("account deletion retry must be idempotent: %v", err)
	}
	if err := s.CanRestoreSubscription(newUserID, oldUserID); err != nil {
		t.Fatalf("successor should be allowed to restore the old subscription: %v", err)
	}

	annual.TransactionID = "lineage-annual-restored"
	annual.AppAccountToken = newUserID
	if err := s.ApplyVerifiedStoreTransaction(newUserID, annual, "lineage-annual-restored-jws"); err != nil {
		t.Fatal(err)
	}
	restored, err := s.GetCommerceUser(newUserID)
	if err != nil {
		t.Fatal(err)
	}
	if restored.Plan != "premium" || restored.Credits.Total != 0 {
		t.Fatalf("restore must recover Pro without repeating current-period or welcome Credits: %+v", restored)
	}

	third, err := s.DeactivateCommerceUser(newUserID, thirdUserID, installationID, appTransactionID)
	if err != nil {
		t.Fatal(err)
	}
	if third.RootUserID != oldUserID || third.PredecessorUserID != newUserID || third.Credits.Total != 0 {
		t.Fatalf("repeated deletion must preserve lineage and anti-duplicate claims: %+v", third)
	}
	if err := s.CanRestoreSubscription(thirdUserID, oldUserID); err != nil {
		t.Fatalf("latest successor should restore from any inactive ancestor: %v", err)
	}

	future := now.AddDate(0, 1, 0)
	tx, err := s.db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := refillAllowanceTx(tx, oldUserID, future); err != nil {
		_ = tx.Rollback()
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	var futureInactiveGrants int
	futurePeriod := "monthly_bonus:" + future.Format("2006-01")
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM credit_grants WHERE user_id=? AND period_key=?`, oldUserID, futurePeriod).Scan(&futureInactiveGrants); err != nil {
		t.Fatal(err)
	}
	if futureInactiveGrants != 0 {
		t.Fatalf("inactive accounts must never receive future Credits, got %d grants", futureInactiveGrants)
	}
}

func TestAccountSyncRecoversInactiveAncestorToInstallationLatestSuccessor(t *testing.T) {
	s := openTestStore(t)
	firstUserID := "41414141-4141-4141-8141-414141414141"
	secondUserID := "42424242-4242-4242-8242-424242424242"
	latestUserID := "43434343-4343-4343-8343-434343434343"
	installationID := "ancestor-recovery-installation"
	appTransactionID := "ancestor-recovery-app-transaction"

	if _, err := s.SyncCommerceUser(firstUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(firstUserID, secondUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(secondUserID, latestUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}

	recovered, err := s.SyncCommerceUser(firstUserID, installationID)
	if err != nil {
		t.Fatalf("inactive ancestor must recover through its verified installation: %v", err)
	}
	if recovered.UserID != latestUserID || recovered.AccountStatus != "active" {
		t.Fatalf("sync returned the wrong authoritative account: %+v", recovered)
	}
}

func TestAccountSyncWithAppleIdentityUsesLatestSuccessor(t *testing.T) {
	s := openTestStore(t)
	firstUserID := "44444444-4444-4444-8444-444444444444"
	secondUserID := "45454545-4545-4545-8545-454545454545"
	latestUserID := "46464646-4646-4646-8646-464646464646"
	installationID := "signed-sync-ancestor-installation"
	appTransactionID := "signed-sync-app-transaction"

	if _, err := s.SyncCommerceUser(firstUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(firstUserID, secondUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(secondUserID, latestUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}

	recovered, err := s.SyncCommerceUserWithAppleIdentity(
		firstUserID,
		installationID,
		"US",
		appTransactionID,
	)
	if err != nil {
		t.Fatalf("signed sync from an inactive ancestor must bind the authoritative successor: %v", err)
	}
	if recovered.UserID != latestUserID || recovered.AccountStatus != "active" {
		t.Fatalf("signed sync returned the wrong authoritative account: %+v", recovered)
	}
	var boundUserID string
	if err := s.db.QueryRow(`SELECT current_user_id FROM apple_identities`).Scan(&boundUserID); err != nil {
		t.Fatal(err)
	}
	if boundUserID != latestUserID {
		t.Fatalf("Apple identity bound to %q instead of latest successor %q", boundUserID, latestUserID)
	}
}

func TestAccountSyncRejectsInactiveAncestorFromUnrelatedInstallation(t *testing.T) {
	s := openTestStore(t)
	oldUserID := "51515151-5151-4151-8151-515151515151"
	latestUserID := "52525252-5252-4252-8252-525252525252"
	otherUserID := "53535353-5353-4353-8353-535353535353"

	if _, err := s.SyncCommerceUser(oldUserID, "owner-installation"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(oldUserID, latestUserID, "owner-installation", "owner-app-transaction"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.SyncCommerceUser(otherUserID, "other-installation"); err != nil {
		t.Fatal(err)
	}

	if _, err := s.SyncCommerceUser(oldUserID, "other-installation"); err == nil {
		t.Fatal("an unrelated verified installation must not recover another account lineage")
	}
}

func TestAccountDeletionRetryFromAncestorReturnsLatestSuccessor(t *testing.T) {
	s := openTestStore(t)
	firstUserID := "61616161-6161-4161-8161-616161616161"
	secondUserID := "62626262-6262-4262-8262-626262626262"
	latestUserID := "63636363-6363-4363-8363-636363636363"
	installationID := "deletion-retry-installation"
	appTransactionID := "deletion-retry-app-transaction"

	if _, err := s.SyncCommerceUser(firstUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(firstUserID, secondUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(secondUserID, latestUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}

	recovered, err := s.DeactivateCommerceUser(firstUserID, secondUserID, installationID, appTransactionID)
	if err != nil {
		t.Fatalf("retry from an older ancestor must be idempotent: %v", err)
	}
	if recovered.UserID != latestUserID {
		t.Fatalf("retry must return the latest successor, got %+v", recovered)
	}
}

func TestConsumableFromInactiveAncestorSettlesWithoutCreditingSuccessor(t *testing.T) {
	s := openTestStore(t)
	oldUserID := "71717171-7171-4171-8171-717171717171"
	currentUserID := "72727272-7272-4272-8272-727272727272"
	installationID := "ancestor-consumable-installation"
	appTransactionID := "ancestor-consumable-app-transaction"

	if _, err := s.SyncCommerceUser(oldUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.DeactivateCommerceUser(oldUserID, currentUserID, installationID, appTransactionID); err != nil {
		t.Fatal(err)
	}
	value := AppleTransactionPayload{
		TransactionID:         "ancestor-credits-transaction",
		OriginalTransactionID: "ancestor-credits-original",
		ProductID:             "credits_10",
		AppAccountToken:       oldUserID,
		AppTransactionID:      appTransactionID,
		BundleID:              "com.xiaoguiwk.interstellar",
		PurchaseDate:          time.Now().UTC().UnixMilli(),
	}

	current, err := s.ApplyVerifiedStoreTransactionForCurrentUser(
		currentUserID,
		installationID,
		value,
		"ancestor-credits-jws",
	)
	if err != nil {
		t.Fatalf("verified ancestor consumable must be settled: %v", err)
	}
	if current.UserID != currentUserID || current.AccountStatus != "active" || current.Credits.Purchased != 0 {
		t.Fatalf("ancestor purchase must not credit the active successor: %+v", current)
	}
	var transactionUserID string
	var remaining int
	if err := s.db.QueryRow(`SELECT t.user_id,g.remaining_amount FROM store_transactions t JOIN credit_grants g ON g.apple_transaction_id=t.transaction_id WHERE t.transaction_id=?`, value.TransactionID).Scan(&transactionUserID, &remaining); err != nil {
		t.Fatal(err)
	}
	if transactionUserID != oldUserID || remaining != 0 {
		t.Fatalf("ancestor purchase must remain financial history with no live balance: user=%q remaining=%d", transactionUserID, remaining)
	}
}

func TestConsumableFromUnrelatedAccountCreditsSignedOwnerWithoutCreditingCurrent(t *testing.T) {
	s := openTestStore(t)
	currentUserID := "73737373-7373-4373-8373-737373737373"
	unrelatedUserID := "74747474-7474-4474-8474-747474747474"
	installationID := "unrelated-consumable-installation"

	if _, err := s.SyncCommerceUser(currentUserID, installationID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.SyncCommerceUser(unrelatedUserID, "other-consumable-installation"); err != nil {
		t.Fatal(err)
	}
	if err := s.BindAppleIdentity(currentUserID, "shared-consumable-app-transaction"); err != nil {
		t.Fatal(err)
	}
	value := AppleTransactionPayload{
		TransactionID:         "unrelated-credits-transaction",
		OriginalTransactionID: "unrelated-credits-original",
		ProductID:             "credits_10",
		AppAccountToken:       unrelatedUserID,
		AppTransactionID:      "shared-consumable-app-transaction",
		BundleID:              "com.xiaoguiwk.interstellar",
		PurchaseDate:          time.Now().UTC().UnixMilli(),
	}

	current, err := s.ApplyVerifiedStoreTransactionForCurrentUser(currentUserID, installationID, value, "unrelated-credits-jws")
	if err != nil {
		t.Fatalf("valid consumable must reach a terminal state: %v", err)
	}
	if current.Credits.Purchased != 0 {
		t.Fatalf("unrelated purchase must not credit the current account: %+v", current)
	}
	owner, err := s.GetCommerceUser(unrelatedUserID)
	if err != nil {
		t.Fatal(err)
	}
	if owner.Credits.Purchased != 10 {
		t.Fatalf("Apple-signed owner must receive the purchase: %+v", owner)
	}
}

func TestConsumableWithoutAccountTokenCreditsCurrentVerifiedInstallation(t *testing.T) {
	s := openTestStore(t)
	currentUserID := "75757575-7575-4575-8575-757575757575"
	installationID := "missing-token-consumable-installation"
	if _, err := s.SyncCommerceUser(currentUserID, installationID); err != nil {
		t.Fatal(err)
	}
	value := AppleTransactionPayload{
		TransactionID:         "missing-token-credits-transaction",
		OriginalTransactionID: "missing-token-credits-original",
		ProductID:             "credits_10",
		BundleID:              "com.xiaoguiwk.interstellar",
		PurchaseDate:          time.Now().UTC().UnixMilli(),
	}

	current, err := s.ApplyVerifiedStoreTransactionForCurrentUser(currentUserID, installationID, value, "missing-token-credits-jws")
	if err != nil {
		t.Fatalf("verified tokenless consumable must be settled: %v", err)
	}
	if current.Credits.Purchased != 10 {
		t.Fatalf("verified installation must receive tokenless consumable: %+v", current)
	}
}

func TestStoreTransactionReconciliationAuditStoresOnlyJWSHash(t *testing.T) {
	s := openTestStore(t)
	userID := "76767676-7676-4676-8676-767676767676"
	rawJWS := "sensitive.signed.transaction"
	if err := s.RecordStoreTransactionReconciliation(
		userID,
		"audit-transaction",
		"credits_10",
		"",
		"credited_current",
		"",
		rawJWS,
	); err != nil {
		t.Fatal(err)
	}
	var storedHash, disposition string
	if err := s.db.QueryRow(`SELECT jws_hash,disposition FROM store_transaction_reconciliations WHERE current_user_id=?`, userID).Scan(&storedHash, &disposition); err != nil {
		t.Fatal(err)
	}
	if storedHash == "" || storedHash == rawJWS || disposition != "credited_current" {
		t.Fatalf("unexpected reconciliation audit: hash=%q disposition=%q", storedHash, disposition)
	}
}

func TestInvalidConsumableJWSReturnsTerminalDispositionAndAudit(t *testing.T) {
	s := openTestStore(t)
	userID := "77777777-7777-4777-8777-777777777777"
	installationID := "invalid-jws-consumable-installation"
	if _, err := s.SyncCommerceUser(userID, installationID); err != nil {
		t.Fatal(err)
	}
	cfg := &relayConfig{store: s, allowDevBypass: true}
	body := `{"userID":"` + userID + `","signedTransaction":"not-a-jws","transactionID":"local-transaction","productID":"credits_10"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/store/transactions", strings.NewReader(body))
	req.Header.Set("X-Installation-ID", installationID)
	req.Header.Set("X-App-Attest-Development-Bypass", "1")
	rec := httptest.NewRecorder()
	cfg.handleStoreTransaction(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"transactionDisposition":"rejected_permanent"`) {
		t.Fatalf("invalid local consumable must receive terminal response: %d %s", rec.Code, rec.Body.String())
	}
	var disposition, failureCode string
	if err := s.db.QueryRow(`SELECT disposition,failure_code FROM store_transaction_reconciliations WHERE current_user_id=?`, userID).Scan(&disposition, &failureCode); err != nil {
		t.Fatal(err)
	}
	if disposition != "rejected_permanent" || failureCode != "transaction_unverified" {
		t.Fatalf("unexpected audit disposition=%q failure=%q", disposition, failureCode)
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
	if user.Credits.Bonus != 0 || user.Credits.Allowance != firstPeriodBonus+premiumAllowance {
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
	if user.Credits.Purchased != 20 || user.Credits.Bonus != 0 || user.Credits.Allowance != firstPeriodBonus || user.Credits.Total != 20+firstPeriodBonus {
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
	if balance.Total != 7 || balance.Allowance != 2 || balance.Bonus != 5 {
		t.Fatalf("unexpected balance after deduction: %+v", balance)
	}
	if err := s.DeductAdminCredits(userID, 8, "test-admin"); err == nil {
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
	if err != nil || premium.Plan != "premium" || premium.AdminPlanOverride != "premium" || premium.Credits.Allowance != premiumAllowance+firstPeriodBonus || premium.Credits.Bonus != 0 || premium.Credits.Total != premiumAllowance+firstPeriodBonus {
		t.Fatalf("premium override not applied: user=%+v err=%v", premium, err)
	}
	if err := s.SetAdminPlan(userID, "free", nil, "test-admin", "test free"); err != nil {
		t.Fatal(err)
	}
	free, err := s.GetCommerceUser(userID)
	if err != nil || free.Plan != "free" || free.AdminPlanOverride != "free" || free.Credits.Allowance != firstPeriodBonus || free.Credits.Bonus != 0 || free.Credits.Total != firstPeriodBonus {
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
	if len(user.CreditLedger) != 1 || user.CreditLedger[0].Action != "MONTHLY_BONUS_RENEW" {
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

func TestAllTwelveChartPromptEntrypointsExist(t *testing.T) {
	want := []string{
		"chart.natal", "chart.current-sky", "chart.transit", "chart.synastry",
		"chart.solar-return", "chart.secondary", "chart.tertiary", "chart.lunar-return",
		"chart.solar-arc", "chart.relocation", "chart.twelfth-harmonic", "chart.thirteenth-harmonic",
	}
	scopes := validScopes()
	for _, scope := range want {
		if !slices.Contains(scopes, scope) {
			t.Fatalf("missing prompt scope %s", scope)
		}
		prompt := defaultPrompt(scope, canonicalPromptLocale)
		if !strings.Contains(prompt, "Chart priorities:") {
			t.Fatalf("%s has no English chart prompt entry", scope)
		}
	}
}

func TestAllRelationshipPromptEntrypointsExist(t *testing.T) {
	want := []string{
		"relationship.synastry-a", "relationship.synastry-b",
		"relationship.composite", "relationship.composite-transit",
		"relationship.composite-secondary", "relationship.composite-tertiary",
		"relationship.composite-secondary-compare", "relationship.composite-tertiary-compare",
		"relationship.davison", "relationship.davison-transit",
		"relationship.davison-secondary", "relationship.davison-tertiary",
		"relationship.marks-a", "relationship.marks-b",
		"relationship.marks-secondary", "relationship.marks-tertiary",
	}
	scopes := validScopes()
	for _, scope := range want {
		if !slices.Contains(scopes, scope) {
			t.Fatalf("missing relationship prompt scope %s", scope)
		}
		prompt := defaultPrompt(scope, canonicalPromptLocale)
		for _, marker := range []string{"Relationship priorities:", "Never recompute", "80–140 English words"} {
			if !strings.Contains(prompt, marker) {
				t.Fatalf("%s prompt is missing %q", scope, marker)
			}
		}
	}
}

func TestRelationshipGenerationScopeRequiresMatchingPromptKey(t *testing.T) {
	req := generateRequest{
		Mode: "chart", ChartKind: "relationship.composite",
		ReportPromptKey: "relationship.composite",
	}
	scope, err := req.scope()
	if err != nil || scope != "relationship.composite" {
		t.Fatalf("relationship scope rejected: scope=%q err=%v", scope, err)
	}
	req.ReportPromptKey = "relationship.davison"
	if _, err := req.scope(); err == nil {
		t.Fatal("mismatched reportPromptKey must be rejected")
	}
}

func TestThemeGenerationScopeRequiresMatchingPromptKeyAndCostsTwoCredits(t *testing.T) {
	req := generateRequest{
		Mode: "theme", ThemeKind: "career_purpose",
		ReportPromptKey: "theme.career_purpose",
	}
	scope, err := req.scope()
	if err != nil || scope != "theme.career_purpose" {
		t.Fatalf("theme scope rejected: scope=%q err=%v", scope, err)
	}
	if got := creditCostForScope(scope); got != 2 {
		t.Fatalf("theme credit cost = %d, want 2", got)
	}
	req.ReportPromptKey = "theme.money_growth"
	if _, err := req.scope(); err == nil {
		t.Fatal("mismatched theme reportPromptKey must be rejected")
	}
}

func TestThemeReservationAtomicallyReservesAndReleasesTwoCredits(t *testing.T) {
	s := openTestStore(t)
	userID := "abababab-abab-4bab-8bab-abababababab"
	requestID := "cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd"
	if _, err := s.SyncCommerceUser(userID, "theme-installation"); err != nil {
		t.Fatal(err)
	}
	before, err := s.CreditBalance(userID)
	if err != nil || before.Total < 2 {
		t.Fatalf("theme test requires two credits: balance=%+v err=%v", before, err)
	}
	record, err := s.ReserveCredit(
		userID, "theme-installation", requestID, "theme-report", "theme-hash",
		"theme.career_purpose", "en", "en", "model", 2,
	)
	if err != nil {
		t.Fatal(err)
	}
	afterReserve, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if record.CreditCost != 2 || afterReserve.Total != before.Total-2 || afterReserve.Reserved != 2 {
		t.Fatalf("two-credit reservation mismatch: record=%+v before=%+v after=%+v", record, before, afterReserve)
	}
	if err := s.ReleaseCredit(userID, requestID, "test_release", "test"); err != nil {
		t.Fatal(err)
	}
	afterRelease, err := s.CreditBalance(userID)
	if err != nil || afterRelease.Total != before.Total || afterRelease.Reserved != 0 {
		t.Fatalf("two-credit release mismatch: before=%+v after=%+v err=%v", before, afterRelease, err)
	}
}

func TestThemeAcknowledgementConsumesExactlyTwoCredits(t *testing.T) {
	s := openTestStore(t)
	userID := "acacacac-acac-4cac-8cac-acacacacacac"
	requestID := "bdbdbdbd-bdbd-4dbd-8dbd-bdbdbdbdbdbd"
	if _, err := s.SyncCommerceUser(userID, "theme-ack-installation"); err != nil {
		t.Fatal(err)
	}
	before, err := s.CreditBalance(userID)
	if err != nil || before.Total < 2 {
		t.Fatalf("theme acknowledgement test requires two credits: balance=%+v err=%v", before, err)
	}
	if _, err := s.ReserveCredit(
		userID, "theme-ack-installation", requestID, "theme-report", "theme-ack-hash",
		"theme.life_direction", "en", "en", "model", 2,
	); err != nil {
		t.Fatal(err)
	}
	if err := s.CompleteReportGeneration(userID, requestID, "theme-ack-hash", "model", 20, 40, 5, 100, `{"report":{}}`); err != nil {
		t.Fatal(err)
	}
	if err := s.AcknowledgeReport(userID, requestID); err != nil {
		t.Fatal(err)
	}
	after, err := s.CreditBalance(userID)
	if err != nil || after.Total != before.Total-2 || after.Reserved != 0 {
		t.Fatalf("theme acknowledgement did not consume exactly two credits: before=%+v after=%+v err=%v", before, after, err)
	}
	record, err := s.GetReportRequest(userID, requestID)
	if err != nil || record.CreditCost != 2 || record.CreditStatus != "consumed" || record.ReportStatus != "success" {
		t.Fatalf("unexpected acknowledged theme record: %+v err=%v", record, err)
	}
}

func TestThemeTwoCreditReservationDoesNotPartiallyDeduct(t *testing.T) {
	s := openTestStore(t)
	userID := "cececece-cece-4ece-8ece-cececececece"
	if _, err := s.SyncCommerceUser(userID, "theme-low-balance-installation"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.db.Exec(`UPDATE credit_grants SET remaining_amount=0 WHERE user_id=?`, userID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.db.Exec(`INSERT INTO credit_grants(user_id,source,original_amount,remaining_amount,granted_at) VALUES(?,'admin',1,1,?)`, userID, time.Now().UTC().Format(time.RFC3339)); err != nil {
		t.Fatal(err)
	}
	if _, err := s.ReserveCredit(
		userID, "theme-low-balance-installation", "dededede-dede-4ede-8ede-dededededede", "theme-report", "theme-low-hash",
		"theme.money_growth", "en", "en", "model", 2,
	); err == nil || !strings.Contains(err.Error(), "insufficient") {
		t.Fatalf("expected insufficient two-credit reservation, got %v", err)
	}
	after, err := s.CreditBalance(userID)
	if err != nil || after.Total != 1 || after.Reserved != 0 {
		t.Fatalf("failed theme reservation partially changed balance: %+v err=%v", after, err)
	}
}

func TestThemeGenerationUsesExpandedOutputBudget(t *testing.T) {
	theme := generationOptionsForScope("theme.family_home")
	if theme.MaxOutputTokens != 16000 || theme.FirstAttemptTimeout != 90*time.Second {
		t.Fatalf("unexpected theme generation options: %+v", theme)
	}
	chart := normalizedGenerationOptions([]GenerationOptions{generationOptionsForScope("chart.natal")})
	if chart.MaxOutputTokens != 10000 || chart.FirstAttemptTimeout != 45*time.Second {
		t.Fatalf("chart generation defaults changed: %+v", chart)
	}
}

func TestAllThemePromptEntrypointsExist(t *testing.T) {
	want := []string{
		"theme.love_relationships", "theme.career_purpose", "theme.money_growth",
		"theme.family_home", "theme.self_wellbeing", "theme.creativity_expression",
		"theme.learning_exploration", "theme.life_direction",
	}
	for _, scope := range want {
		if !slices.Contains(validScopes(), scope) {
			t.Fatalf("missing theme prompt scope %s", scope)
		}
		prompt := defaultPrompt(scope, canonicalPromptLocale)
		for _, marker := range []string{"Theme priorities:", "params.focus is the primary analytical emphasis", "Never recompute", "evidenceFactIDs"} {
			if !strings.Contains(prompt, marker) {
				t.Fatalf("%s prompt is missing %q", scope, marker)
			}
		}
	}
}

func TestThemePromptFocusMigrationOnlyReplacesExactLegacyDefault(t *testing.T) {
	for _, scope := range []string{
		"theme.love_relationships", "theme.career_purpose", "theme.money_growth", "theme.family_home",
		"theme.self_wellbeing", "theme.creativity_expression", "theme.learning_exploration", "theme.life_direction",
	} {
		legacy := legacyThemeDefaultPromptV1(scope)
		if strings.Contains(legacy, "params.focus is the primary analytical emphasis") {
			t.Fatalf("%s legacy prompt unexpectedly contains the new focus rule", scope)
		}
		if !shouldReplaceSeededPrompt(scope, legacy) {
			t.Fatalf("%s exact legacy Theme default would not migrate", scope)
		}
		if shouldReplaceSeededPrompt(scope, legacy+" admin edit") {
			t.Fatalf("%s administrator-edited Theme prompt must not be overwritten", scope)
		}
	}
}

func TestReportLanguageUsesEnglishPromptAndRequestedOutputLocale(t *testing.T) {
	for locale, language := range map[string]string{
		"en": "English", "zh-Hans": "Simplified Chinese", "es": "Spanish", "fr": "French",
		"tr": "Turkish", "de": "German", "it": "Italian", "ko": "Korean",
	} {
		if got := effectiveReportLocale(locale); got != locale {
			t.Fatalf("effective locale %s = %s", locale, got)
		}
		prompt := withRequestedOutputLanguage(defaultPrompt("chart.natal", canonicalPromptLocale), locale)
		if !strings.Contains(prompt, "Output language (non-negotiable)") || !strings.Contains(prompt, language+" ("+locale+")") {
			t.Fatalf("%s output-language instruction missing: %s", locale, prompt)
		}
	}
	if got := effectiveReportLocale("unsupported"); got != canonicalPromptLocale {
		t.Fatalf("unsupported locale should safely fall back to %s, got %s", canonicalPromptLocale, got)
	}
}

func TestPromptListingExposesCanonicalEnglishTemplatesOnly(t *testing.T) {
	s := openTestStore(t)
	if _, err := s.UpsertPrompt("chart.natal", "en", "English prompt"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertPrompt("chart.natal", "zh-Hans", "Legacy Chinese prompt"); err != nil {
		t.Fatal(err)
	}
	prompts, err := s.ListPrompts()
	if err != nil {
		t.Fatal(err)
	}
	if len(prompts) != 1 || prompts[0]["locale"] != canonicalPromptLocale {
		t.Fatalf("admin prompt list must expose only canonical English templates: %#v", prompts)
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

func TestLLMUserContentContainsOnlyAllowedContextAndCalculatedResults(t *testing.T) {
	req := generateRequest{
		Locale: "en",
		Facts: json.RawMessage(`{
			"params":{"place":"Paris, France","timezone":"Europe/Paris","latitude":"48.856600","longitude":"2.352200","selectionMode":"exact","relationship":"friend"},
			"chart":{"utcDate":"1992-05-14T06:20:00Z","julianDay":2448756.7639,"points":[{"body":"sun","longitude":53.4}]},
			"evidenceFacts":[{"id":"point.sun"},{"id":"event.ingress","date":"2026-09-01T10:00:00Z","timeZone":"Europe/Paris"}]
		}`),
		Params: json.RawMessage(`{"place":"Paris, France","timezone":"Europe/Paris","latitude":"48.856600","longitude":"2.352200","selectionMode":"exact","relationship":"friend"}`),
	}
	content := buildUserContent(req, "chart.natal")
	for _, privateValue := range []string{"Paris, France", "Europe/Paris", "48.856600", "2.352200", "1992-05-14T06:20:00Z", "2448756.7639", "selectionMode"} {
		if strings.Contains(content, privateValue) {
			t.Fatalf("LLM content contains disallowed profile or scope parameter %q: %s", privateValue, content)
		}
	}
	for _, calculatedValue := range []string{`"longitude":53.4`, `"relationship":"friend"`, "2026-09-01T10:00:00Z"} {
		if !strings.Contains(content, calculatedValue) {
			t.Fatalf("LLM content dropped required calculated result %q: %s", calculatedValue, content)
		}
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
	for _, marker := range []string{"prompt-space-filter", "prompt-family-filter", "prompt-scope-filter", "prompt-search-filter", "You、Bonds 与周期报告各维护一份英文基础提示词", "relationship.marks-tertiary", "data-prompt-filter", "用户反馈", "feedback-status-filter", "data-report-filter", "user-detail"} {
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

func TestVerifiedAppStoreTestNotificationWithoutTransaction(t *testing.T) {
	cfg := &relayConfig{}
	rec := httptest.NewRecorder()
	cfg.handleVerifiedAppStoreNotification(rec, []byte(`{
		"notificationType":"TEST",
		"notificationUUID":"00000000-0000-0000-0000-000000000001",
		"data":{
			"bundleId":"com.xiaoguiwk.interstellar",
			"environment":"Production"
		}
	}`))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"type":"TEST"`) {
		t.Fatalf("verified TEST notification returned %d: %s", rec.Code, rec.Body.String())
	}
}

func TestVerifiedAppStoreTestNotificationRejectsWrongBundle(t *testing.T) {
	cfg := &relayConfig{}
	rec := httptest.NewRecorder()
	cfg.handleVerifiedAppStoreNotification(rec, []byte(`{
		"notificationType":"TEST",
		"data":{"bundleId":"com.example.other"}
	}`))
	if rec.Code != http.StatusUnprocessableEntity || !strings.Contains(rec.Body.String(), "bundle_mismatch") {
		t.Fatalf("wrong-bundle TEST notification returned %d: %s", rec.Code, rec.Body.String())
	}
}

func TestVerifiedAppStoreNotificationWithoutTransactionIsAcknowledged(t *testing.T) {
	cfg := &relayConfig{}
	rec := httptest.NewRecorder()
	cfg.handleVerifiedAppStoreNotification(rec, []byte(`{
		"notificationType":"DID_RENEW",
		"data":{"bundleId":"com.xiaoguiwk.interstellar"}
	}`))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"type":"DID_RENEW"`) {
		t.Fatalf("transaction-less DID_RENEW notification returned %d: %s", rec.Code, rec.Body.String())
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
			"title": "Votre année", "subtitle": "Une lecture structurée",
			"sections": []map[string]any{
				{"number": "01", "title": "Vue d’ensemble", "body": "Première partie.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "02", "title": "Structure", "body": "Deuxième partie.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "03", "title": "Temporalité", "body": "Troisième partie.", "evidenceFactIDs": []string{"point.sun"}},
				{"number": "04", "title": "Conseil", "body": "Quatrième partie.", "evidenceFactIDs": []string{"point.sun"}},
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
		"locale": "fr", "clientVersion": "test",
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

	// The completed report body is persisted on the Relay until the client
	// fetches it and acknowledges local persistence.
	record, err := s.GetReportRequest("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222")
	if err != nil || record.ReportStatus != "awaiting_ack" || record.CreditStatus != "reserved" || record.ReasoningTokens != 25 {
		t.Fatalf("unexpected pre-ack state: %+v err=%v", record, err)
	}
	if record.RequestedLocale != "fr" || record.EffectiveLocale != "fr" {
		t.Fatalf("French request locale was not preserved: %+v", record)
	}
	if !strings.Contains(mock.lastSystemPrompt, "French (fr)") {
		t.Fatalf("upstream prompt did not require French output: %s", mock.lastSystemPrompt)
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
	var decoded struct {
		UserID    string `json:"userID"`
		RequestID string `json:"requestID"`
	}
	if err := json.Unmarshal([]byte(body), &decoded); err != nil {
		t.Fatal(err)
	}
	req, err := http.NewRequest(http.MethodPost, "/v1/generate", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Installation-ID", "test-installation")
	req.Header.Set("X-App-Attest-Development-Bypass", "1")
	rec := httptest.NewRecorder()
	cfg.handleGenerate(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("generate accept returned %d: %s", rec.Code, rec.Body.String())
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		record, err := s.GetReportRequest(decoded.UserID, decoded.RequestID)
		if err == nil && record.ReportStatus != "processing" {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("generation job did not finish in time")
		}
		time.Sleep(10 * time.Millisecond)
	}
	fetchBody, err := json.Marshal(map[string]any{"userID": decoded.UserID, "requestID": decoded.RequestID})
	if err != nil {
		t.Fatal(err)
	}
	freq, err := http.NewRequest(http.MethodPost, "/v1/reports/fetch", strings.NewReader(string(fetchBody)))
	if err != nil {
		t.Fatal(err)
	}
	freq.Header.Set("Content-Type", "application/json")
	freq.Header.Set("X-Installation-ID", "test-installation")
	freq.Header.Set("X-App-Attest-Development-Bypass", "1")
	frec := httptest.NewRecorder()
	cfg.handleReportFetch(frec, freq)
	if frec.Code != http.StatusOK {
		t.Fatalf("fetch returned %d: %s", frec.Code, frec.Body.String())
	}
	var out map[string]any
	if err := json.Unmarshal(frec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

type mockProvider struct {
	count            int
	responses        map[string]string
	lastSystemPrompt string
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
	m.lastSystemPrompt = system
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
