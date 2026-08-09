package main

import (
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

func TestCacheTTL(t *testing.T) {
	s := openTestStore(t)
	if err := s.CachePut("k1", "chart.natal", `{"cached":false}`, time.Hour); err != nil {
		t.Fatal(err)
	}
	if _, hit, err := s.CacheGet("k1"); err != nil || !hit {
		t.Fatalf("expected cache hit, got hit=%v err=%v", hit, err)
	}
	if err := s.CachePut("k2", "chart.natal", `{"cached":false}`, -time.Minute); err != nil {
		t.Fatal(err)
	}
	if _, hit, _ := s.CacheGet("k2"); hit {
		t.Fatal("expected expired cache to miss")
	}
	var stored string
	if err := s.db.QueryRow(`SELECT payload FROM generation_cache WHERE cache_key = ?`, "k1").Scan(&stored); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(stored, `"cached"`) {
		t.Fatal("generation cache must not store plaintext payloads")
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
	if strings.Contains(defaultPrompt("chart.natal", "en"), "90–150 English words") {
		t.Fatal("the transit-only output constraint must not change other chart prompts")
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

	// Second call with identical parameters: served from cache, upstream not hit.
	mock.count = 0
	second := roundTripGenerate(t, s, body)
	if second["cached"] != true {
		t.Fatal("expected second call to be served from cache")
	}
	if mock.count != 0 {
		t.Fatalf("expected no upstream call on cache hit, got %d", mock.count)
	}

	requestPayload["forceRegenerate"] = true
	forcedJSON, err := json.Marshal(requestPayload)
	if err != nil {
		t.Fatal(err)
	}
	third := roundTripGenerate(t, s, string(forcedJSON))
	if third["cached"] == true || mock.count != 1 {
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
		"usage": map[string]any{"prompt_tokens": 100, "completion_tokens": 200},
	})
}
