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
	s, err := OpenStore(t.TempDir()+"/relay.db", "test-secret-please-change")
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
	var r GenerationResult
	if err := json.Unmarshal([]byte(`{"report":{"title":"t","subtitle":"s","sections":[]},"cards":{}}`), &r); err != nil {
		t.Fatal(err)
	}
	if err := r.Validate([]string{"a"}); err == nil {
		t.Fatal("expected validation failure for empty sections")
	}

	valid := `{"report":{"title":"t","subtitle":"s","sections":[
		{"number":"01","title":"One","body":"body one"},
		{"number":"02","title":"Two","body":"body two"},
		{"number":"03","title":"Three","body":"body three"},
		{"number":"04","title":"Four","body":"body four"}]},
		"cards":{"a":{"detail":"detail a"},"b":{"detail":"detail b"}}}`
	if err := json.Unmarshal([]byte(valid), &r); err != nil {
		t.Fatal(err)
	}
	if err := r.Validate([]string{"a", "b"}); err != nil {
		t.Fatalf("expected valid: %v", err)
	}
	if err := r.Validate([]string{"a", "missing"}); err == nil {
		t.Fatal("expected validation failure for missing card")
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
}

func TestAdminBootstrapAndLogin(t *testing.T) {
	s := openTestStore(t)
	if err := s.EnsureAdmin("admin", "pw"); err != nil {
		t.Fatal(err)
	}
	if !s.VerifyAdmin("admin", "pw") {
		t.Fatal("expected valid credentials")
	}
	if s.VerifyAdmin("admin", "wrong") {
		t.Fatal("expected invalid credentials to fail")
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
	if err != nil || version < 1 || !strings.Contains(prompt, "不预测") {
		t.Fatalf("natal zh prompt missing safety boundary: version=%d err=%v", version, err)
	}
}

// E2E: full generate pipeline against a mock OpenAI-compatible provider.
func TestGeneratePipelineWithMockProvider(t *testing.T) {
	// Mock upstream: returns a valid structured JSON completion.
	mock := &mockProvider{responses: map[string]string{
		"deepseek-v4-flash": `{"report":{"title":"Your year","subtitle":"A structured reading","sections":[
			{"number":"01","title":"Overview","body":"Body one."},
			{"number":"02","title":"Pattern","body":"Body two."},
			{"number":"03","title":"Timing","body":"Body three."},
			{"number":"04","title":"Advice","body":"Body four."}]},
			"cards":{"a":{"detail":"Card A detail."},"b":{"detail":"Card B detail."}}}`,
	}}
	server := httptest.NewServer(mock)
	defer server.Close()

	s := openTestStore(t)
	if _, err := s.UpsertPrompt("chart.natal", "zh-Hans", defaultPrompt("chart.natal", "zh-Hans")); err != nil {
		t.Fatal(err)
	}
	if _, err := s.UpsertProvider(Provider{
		ID: "default", Label: "Mock", BaseURL: server.URL, DefaultModel: "deepseek-v4-flash", Enabled: true,
	}, "sk-mock"); err != nil {
		t.Fatal(err)
	}

	// First call: upstream hit, cached=false.
	body := `{"mode":"chart","chartKind":"natal","preset":"modern","profileHash":"h1","params":{"anchor":"2026-07-31"},"facts":{"person":{"name":"Darryl"},"chart":{"points":[]}},"cardIDs":["a","b"],"locale":"zh-Hans","clientVersion":"test"}`
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
}

func roundTripGenerate(t *testing.T, s *Store, body string) map[string]any {
	t.Helper()
	sessions := NewSessionStore("test-secret-please-change")
	cfg := &relayConfig{store: s, sessions: sessions, client: &http.Client{}, seed: false}
	req, err := http.NewRequest(http.MethodPost, "/v1/generate", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
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
		Model    string `json:"model"`
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
	// The prompt must carry the fixed safety boundary and the name rule.
	system := req.Messages[0].Content
	if !strings.Contains(system, "不预测") || !strings.Contains(system, "使用这些姓名") {
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
