package main

import (
	"encoding/json"
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
