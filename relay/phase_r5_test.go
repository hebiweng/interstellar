package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestPhaseR5GenerationScopesAndCreditCosts(t *testing.T) {
	for _, compareType := range []string{"me_over_time", "two_people", "two_places", "relationship_over_time"} {
		req := generateRequest{
			Mode: "compare", CompareType: compareType,
			ReportPromptKey: "compare." + compareType,
		}
		scope, err := req.scope()
		if err != nil || scope != req.ReportPromptKey {
			t.Fatalf("compare scope rejected: type=%s scope=%q err=%v", compareType, scope, err)
		}
		if got := creditCostForScope(scope); got != 1 {
			t.Fatalf("compare credit cost=%d, want 1", got)
		}
	}

	ask := generateRequest{Mode: "ask_deep", ReportPromptKey: "ask.deep_analysis"}
	scope, err := ask.scope()
	if err != nil || scope != "ask.deep_analysis" {
		t.Fatalf("ask deep scope rejected: scope=%q err=%v", scope, err)
	}
	if got := creditCostForScope(scope); got != 1 {
		t.Fatalf("ask deep credit cost=%d, want 1", got)
	}

	bad := generateRequest{Mode: "compare", CompareType: "two_people", ReportPromptKey: "compare.two_places"}
	if _, err := bad.scope(); err == nil {
		t.Fatal("mismatched Compare prompt key must be rejected")
	}
}

func TestPhaseR5CreditPolicyConstants(t *testing.T) {
	if firstPeriodBonus != 5 || monthlyBonus != 2 || premiumAllowance != 10 {
		t.Fatalf("unexpected Phase R5 Credit policy: first=%d recurring=%d pro=%d", firstPeriodBonus, monthlyBonus, premiumAllowance)
	}
	s := openTestStore(t)
	userID := "83838383-8383-4383-8383-838383838383"
	if _, err := s.SyncCommerceUser(userID, "phase-r5-credit-policy"); err != nil {
		t.Fatal(err)
	}
	balance, err := s.CreditBalance(userID)
	if err != nil || balance.Total != firstPeriodBonus {
		t.Fatalf("first Free period must total 5 Credits: balance=%+v err=%v", balance, err)
	}
}

func TestNewAnnualProUserReceivesThirtyFiveCreditsInFirstMonth(t *testing.T) {
	s := openTestStore(t)
	userID := "84848484-8484-4484-8484-848484848484"
	if _, err := s.SyncCommerceUser(userID, "phase-r5-annual-installation"); err != nil {
		t.Fatal(err)
	}

	now := time.Now().UTC()
	annual := AppleTransactionPayload{
		TransactionID:         "phase-r5-annual-transaction",
		OriginalTransactionID: "phase-r5-annual-original",
		ProductID:             "premium_annual",
		AppAccountToken:       userID,
		BundleID:              "com.xiaoguiwk.interstellar",
		PurchaseDate:          now.UnixMilli(),
		ExpiresDate:           now.AddDate(1, 0, 0).UnixMilli(),
	}
	if err := s.ApplyVerifiedStoreTransaction(userID, annual, "phase-r5-annual-jws"); err != nil {
		t.Fatal(err)
	}

	balance, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if balance.Allowance != firstPeriodBonus+premiumAllowance || balance.Bonus != 20 || balance.Total != 35 {
		t.Fatalf("new annual Pro user must receive 5 + 10 + 20 = 35 Credits: %+v", balance)
	}
}

func TestFreeUserReceivesTwoCreditsAfterFirstMonth(t *testing.T) {
	s := openTestStore(t)
	userID := "85858585-8585-4585-8585-858585858585"
	if _, err := s.SyncCommerceUser(userID, "phase-r5-free-installation"); err != nil {
		t.Fatal(err)
	}

	tx, err := s.db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := refillAllowanceTx(tx, userID, time.Now().UTC().AddDate(0, 1, 0)); err != nil {
		_ = tx.Rollback()
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	balance, err := s.CreditBalance(userID)
	if err != nil {
		t.Fatal(err)
	}
	if balance.Total != monthlyBonus {
		t.Fatalf("Free user must receive 2 Credits after the first month: %+v", balance)
	}
}

func TestPhaseR5EvidenceExtractionAndPrivacyBoundary(t *testing.T) {
	compare := generateRequest{
		Mode: "compare", CompareType: "two_people", SemanticFingerprint: "semantic", FactsHash: "facts", GenerationSchemaVersion: 1,
		Facts: json.RawMessage(`{
			"compare_type":"two_people",
			"facts":{"baseline":[{"identity":{"technique":"natal","factType":"point","sourceObject":"Sun","targetObject":null,"relation":null,"referenceChart":"baseline"},"state":{},"metadata":{}}],"snapshotA":[],"snapshotB":[],"relationship":[{"id":"relationship.aspect"}]},
			"diff":{}
		}`),
	}
	evidence, err := validateGenerationRequest(compare)
	if err != nil || !evidence["natal|point|sun|_|_|baseline"] || !evidence["relationship.aspect"] || len(evidence) != 2 {
		t.Fatalf("Compare evidence extraction failed: evidence=%v err=%v", evidence, err)
	}

	mismatchedCompare := compare
	mismatchedCompare.CompareType = "two_places"
	if _, err := validateGenerationRequest(mismatchedCompare); err == nil {
		t.Fatal("Compare facts compare_type must match the requested compareType")
	}

	ask := generateRequest{
		Mode: "ask_deep", SemanticFingerprint: "semantic", FactsHash: "facts", GenerationSchemaVersion: 1,
		Facts: json.RawMessage(`{"questionType":"yes_no","question":"Will this work?","facts":[{"id":"horary|ruler|sun|_","category":"ruler","values":{"sign":"aries"}}],"locale":"en"}`),
	}
	evidence, err = validateGenerationRequest(ask)
	if err != nil || !evidence["horary|ruler|sun|_"] || len(evidence) != 1 {
		t.Fatalf("Ask evidence extraction failed: evidence=%v err=%v", evidence, err)
	}

	forbidden := ask
	forbidden.Facts = json.RawMessage(`{"questionType":"yes_no","question":"test","timeZone":"Asia/Shanghai","facts":[{"id":"known"}]}`)
	if _, err := validateGenerationRequest(forbidden); err == nil {
		t.Fatal("private raw time-zone fields must be rejected")
	}
	for _, privateKey := range []string{"birthDate", "utcDate", "julianDay", "snapshot"} {
		forbidden.Facts = json.RawMessage(`{"questionType":"yes_no","question":"test","facts":[{"id":"known","` + privateKey + `":"private"}]}`)
		if _, err := validateGenerationRequest(forbidden); err == nil {
			t.Fatalf("private raw field %q must be rejected", privateKey)
		}
	}
}

func TestPhaseR5SpecialNarrativesRequireResolvableEvidence(t *testing.T) {
	valid := map[string]bool{"known": true}

	compare := json.RawMessage(`{
		"version":"1","compare_type":"me_over_time",
		"summary":{"title":"Summary","text":"Text","evidence":["known","unknown"]},
		"sections":[
			{"type":"key_change","title":"Change","text":"Text","evidence":["known"]},
			{"type":"short_term","title":"Short","text":"Text","evidence":["known"]},
			{"type":"longer_term","title":"Long","text":"Text","evidence":["known"]},
			{"type":"stable","title":"Stable","text":"Text","evidence":["known"]}
		]
	}`)
	clean, err := validateSpecialGenerationResult("compare.me_over_time", "me_over_time", compare, valid)
	if err != nil {
		t.Fatalf("valid Compare result rejected: %v", err)
	}
	if string(clean) == string(compare) {
		t.Fatal("unknown evidence should be removed from the persisted result")
	}

	invalidAsk := json.RawMessage(`{"summary":"Summary","summaryEvidenceFactIDs":["unknown"],"sections":[{"id":"one","title":"Title","body":"Body","evidenceFactIDs":["unknown"]}]}`)
	if _, err := validateSpecialGenerationResult("ask.deep_analysis", "", invalidAsk, valid); err == nil {
		t.Fatal("all-invalid Ask evidence must invalidate the response")
	}
}

func TestPhaseR5SpecialGenerationRetriesFormatAtMostThreeTimes(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"model":"test","choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}`))
	}))
	defer server.Close()

	_, _, _, _, _, err := GenerateSpecial(
		context.Background(), server.Client(), server.URL, "key", "model", "system", "facts",
		"ask.deep_analysis", "", map[string]bool{"known": true},
		GenerationOptions{FirstAttemptTimeout: time.Second},
	)
	if err == nil {
		t.Fatal("invalid format must fail after bounded repair attempts")
	}
	if calls != 4 {
		t.Fatalf("initial request plus three format repairs = 4 calls, got %d", calls)
	}
}

func TestPhaseR5SpecialGenerationDoesNotRetryTransportOrHTTPFailure(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		http.Error(w, "unavailable", http.StatusServiceUnavailable)
	}))
	defer server.Close()

	_, _, _, _, _, err := GenerateSpecial(
		context.Background(), server.Client(), server.URL, "key", "model", "system", "facts",
		"compare.two_people", "two_people", map[string]bool{"known": true},
		GenerationOptions{FirstAttemptTimeout: time.Second},
	)
	if err == nil {
		t.Fatal("upstream HTTP failure must be returned")
	}
	if calls != 1 {
		t.Fatalf("non-format failure must not be retried, got %d calls", calls)
	}
}

func TestPhaseR5FailedGenerationCanReserveAgainWithoutDuplicateFinalCharge(t *testing.T) {
	s := openTestStore(t)
	userID := "81818181-8181-4181-8181-818181818181"
	requestID := "82828282-8282-4282-8282-828282828282"
	if _, err := s.SyncCommerceUser(userID, "phase-r5-retry-installation"); err != nil {
		t.Fatal(err)
	}
	before, err := s.CreditBalance(userID)
	if err != nil || before.Total < 1 {
		t.Fatalf("retry test needs one Credit: balance=%+v err=%v", before, err)
	}
	if _, err := s.ReserveCredit(userID, "phase-r5-retry-installation", requestID, "report", "same-hash", "compare.two_people", "en", "en", "model", 1); err != nil {
		t.Fatal(err)
	}
	if err := s.ReleaseCredit(userID, requestID, "upstream_generation_failed", "invalid evidence"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.RetryCreditReservation(userID, "phase-r5-retry-installation", requestID, "same-hash", "model"); err != nil {
		t.Fatal(err)
	}
	if err := s.CompleteReportGeneration(userID, requestID, "same-hash", "model", 1, 1, 0, 1, `{"result":{}}`); err != nil {
		t.Fatal(err)
	}
	if err := s.AcknowledgeReport(userID, requestID); err != nil {
		t.Fatal(err)
	}
	after, err := s.CreditBalance(userID)
	if err != nil || after.Total != before.Total-1 {
		t.Fatalf("retry must consume exactly one final Credit: before=%+v after=%+v err=%v", before, after, err)
	}
}

func TestPhaseR5RetryCreditReservationRejectsInvalidIdentity(t *testing.T) {
	s := openTestStore(t)
	if _, err := s.RetryCreditReservation("invalid", "installation", "invalid", "hash", "model"); err == nil {
		t.Fatal("retry must reject invalid commerce identifiers before touching state")
	}
}
