package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(JSONMarshal(v)))
}

func readJSON(r *http.Request, v any) error {
	defer r.Body.Close()
	dec := json.NewDecoder(io.LimitReader(r.Body, 4<<20))
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

type relayConfig struct {
	store    *Store
	sessions *SessionStore
	client   *http.Client
	seed     bool
}

type generateRequest struct {
	Mode        string          `json:"mode"`                  // chart | period
	ChartKind   string          `json:"chartKind"`             // natal | current-sky | transit | secondary | solar-return | synastry
	PeriodType  string          `json:"periodType,omitempty"`  // daily | monthly | solar-return
	Preset      string          `json:"preset,omitempty"`      // modern | classical
	ProfileHash string          `json:"profileHash"`
	Params      json.RawMessage `json:"params"`
	Facts       json.RawMessage `json:"facts"`
	CardIDs     []string        `json:"cardIDs"`
	Locale      string          `json:"locale"`
	ClientVer   string          `json:"clientVersion,omitempty"`
}

func (g *generateRequest) scope() (string, error) {
	if g.Mode == "period" {
		switch g.PeriodType {
		case "daily":
			return "period.daily", nil
		case "monthly":
			return "period.monthly", nil
		case "solar-return":
			return "period.solar-return", nil
		}
		return "", errors.New("invalid periodType")
	}
	switch g.ChartKind {
	case "natal", "current-sky", "transit", "secondary", "solar-return", "synastry":
		return "chart." + g.ChartKind, nil
	}
	return "", errors.New("invalid chartKind")
}

func cacheTTL(scope string) time.Duration {
	switch scope {
	case "chart.current-sky":
		return 24 * time.Hour
	case "chart.transit", "chart.solar-return":
		return 7 * 24 * time.Hour
	case "chart.secondary":
		return 30 * 24 * time.Hour
	case "chart.natal", "chart.synastry":
		return 3650 * 24 * time.Hour // effectively permanent until profile/params change
	case "period.daily", "period.monthly", "period.solar-return":
		return 3650 * 24 * time.Hour // a closed period never changes
	default:
		return 7 * 24 * time.Hour
	}
}

func (c *relayConfig) handleGenerate(w http.ResponseWriter, r *http.Request) {
	var req generateRequest
	if err := readJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid request: " + err.Error()})
		return
	}
	scope, err := req.scope()
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	locale := req.Locale
	if locale != "zh-Hans" && locale != "en" {
		locale = "en"
	}

	provider, err := c.store.GetProviderSecret("default")
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "no provider configured"})
		return
	}
	model := provider.DefaultModel
	if model == "" {
		model, _ = c.store.GetSetting("default_model")
	}
	if model == "" {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "no default model configured"})
		return
	}

	prompt, version, err := c.store.GetPrompt(scope, locale)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "prompt lookup failed"})
		return
	}
	if strings.TrimSpace(prompt) == "" {
		if c.seed {
			prompt = defaultPrompt(scope, locale)
			_, _ = c.store.UpsertPrompt(scope, locale, prompt)
			version = 1
		} else {
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "prompt template missing for " + scope})
			return
		}
	}

	cacheKey := cacheKeyFor(req, scope, model, locale, version)
	if payload, hit, _ := c.store.CacheGet(cacheKey); hit {
		var cached map[string]any
		_ = json.Unmarshal([]byte(payload), &cached)
		cached["cached"] = true
		writeJSON(w, http.StatusOK, cached)
		return
	}

	userContent := buildUserContent(req, scope)
	result, usedModel, promptTokens, completionTokens, err := Generate(
		r.Context(), c.client, provider.BaseURL, provider.APIKey, model, prompt, userContent, req.CardIDs,
	)
	if err != nil {
		_ = c.store.RecordUsage(scope, model, 0, 0, false)
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "generation failed: " + err.Error()})
		return
	}
	_ = c.store.RecordUsage(scope, usedModel, promptTokens, completionTokens, true)

	response := map[string]any{
		"report": result.Report,
		"cards":  result.Cards,
		"model":  usedModel,
		"cached": false,
	}
	payload := JSONMarshal(response)
	_ = c.store.CachePut(cacheKey, scope, payload, cacheTTL(scope))
	writeJSON(w, http.StatusOK, response)
}

func cacheKeyFor(req generateRequest, scope, model, locale string, promptVersion int) string {
	params := string(req.Params)
	if params == "" {
		params = "{}"
	}
	facts := string(req.Facts)
	if facts == "" {
		facts = "{}"
	}
	raw := strings.Join([]string{
		scope, req.Preset, req.ProfileHash, params, facts, model, locale,
		fmt.Sprintf("p%d", promptVersion), req.ClientVer,
	}, "|")
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func buildUserContent(req generateRequest, scope string) string {
	var b strings.Builder
	b.WriteString("计算事实（不可变，只能据此解读，不得补算或臆造）：\n")
	b.WriteString(string(req.Facts))
	b.WriteString("\n\n参数与范围：\n")
	b.WriteString(string(req.Params))
	if len(req.CardIDs) > 0 {
		b.WriteString("\n\n需要提供展开解读的卡片 ID：\n")
		b.WriteString(strings.Join(req.CardIDs, ", "))
	}
	return b.String()
}

// ---- Admin handlers ----

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (c *relayConfig) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := readJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid request"})
		return
	}
	if !c.store.VerifyAdmin(req.Username, req.Password) {
		writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "invalid credentials"})
		return
	}
	token, expires := c.sessions.Create(req.Username)
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "expiresAt": expires.Format(time.RFC3339)})
}

func (c *relayConfig) handleProviders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		providers, err := c.store.ListProviders()
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"providers": providers})
	case http.MethodPost, http.MethodPut:
		var p Provider
		body, _ := io.ReadAll(r.Body)
		_ = r.Body.Close()
		var raw struct {
			ID           string `json:"id"`
			Label        string `json:"label"`
			BaseURL      string `json:"base_url"`
			APIKey       string `json:"api_key"`
			DefaultModel string `json:"default_model"`
			Enabled      bool   `json:"enabled"`
		}
		if err := json.Unmarshal(body, &raw); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid provider payload"})
			return
		}
		if raw.ID == "" {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "provider id is required"})
			return
		}
		p = Provider{
			ID: raw.ID, Label: raw.Label, BaseURL: strings.TrimRight(raw.BaseURL, "/"),
			DefaultModel: raw.DefaultModel, Enabled: raw.Enabled,
		}
		if p.Label == "" {
			p.Label = raw.ID
		}
		if p.BaseURL == "" {
			p.BaseURL = "https://api.deepseek.com"
		}
		saved, err := c.store.UpsertProvider(p, raw.APIKey)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"provider": saved})
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method not allowed"})
	}
}

func (c *relayConfig) handleProviderDelete(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/admin/providers/")
	if id == "" || strings.Contains(id, "/") {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid provider id"})
		return
	}
	if err := c.store.DeleteProvider(id); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"deleted": id})
}

func (c *relayConfig) handleProviderModels(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/admin/providers/")
	id = strings.TrimSuffix(id, "/models")
	if id == "" || strings.Contains(id, "/") {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid provider id"})
		return
	}
	provider, err := c.store.GetProviderSecret(id)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "provider not found"})
		return
	}
	models, err := fetchModels(r.Context(), c.client, provider.BaseURL, provider.APIKey)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "fetch models failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"models": models})
}

func fetchModels(ctx context.Context, client *http.Client, baseURL, apiKey string) ([]map[string]any, error) {
	endpoint := strings.TrimRight(baseURL, "/") + "/models"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Accept", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("upstream HTTP %d", resp.StatusCode)
	}
	var payload struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 2<<20)).Decode(&payload); err != nil {
		return nil, err
	}
	var out []map[string]any
	for _, m := range payload.Data {
		out = append(out, map[string]any{"id": m.ID})
	}
	sort.Slice(out, func(i, j int) bool { return out[i]["id"].(string) < out[j]["id"].(string) })
	return out, nil
}

func (c *relayConfig) handleProviderTest(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/admin/providers/")
	id = strings.TrimSuffix(id, "/test")
	provider, err := c.store.GetProviderSecret(id)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "provider not found"})
		return
	}
	model := provider.DefaultModel
	if model == "" {
		model, _ = c.store.GetSetting("default_model")
	}
	if model == "" {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "no default model set"})
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()
	_, usedModel, _, _, err := Generate(ctx, c.client, provider.BaseURL, provider.APIKey, model,
		"You are a connectivity check. Reply with a JSON object: {\"ok\": true}", "{}", nil)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "model": usedModel})
}

func (c *relayConfig) handlePrompts(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		prompts, err := c.store.ListPrompts()
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"prompts": prompts})
	case http.MethodPut:
		var req struct {
			Scope        string `json:"scope"`
			Locale       string `json:"locale"`
			SystemPrompt string `json:"system_prompt"`
		}
		if err := readJSON(r, &req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid prompt payload"})
			return
		}
		valid := false
		for _, s := range validScopes() {
			if s == req.Scope {
				valid = true
				break
			}
		}
		if !valid {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "unknown scope"})
			return
		}
		if req.Locale != "zh-Hans" && req.Locale != "en" {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "locale must be zh-Hans or en"})
			return
		}
		version, err := c.store.UpsertPrompt(req.Scope, req.Locale, req.SystemPrompt)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"scope": req.Scope, "locale": req.Locale, "version": version})
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method not allowed"})
	}
}

func (c *relayConfig) handlePromptRestore(w http.ResponseWriter, r *http.Request) {
	scope := strings.TrimPrefix(r.URL.Path, "/admin/prompts/")
	scope = strings.TrimSuffix(scope, "/restore")
	var locale string
	if idx := strings.LastIndex(scope, "/"); idx >= 0 {
		locale = scope[idx+1:]
		scope = scope[:idx]
	}
	if locale == "" {
		locale = "zh-Hans"
	}
	if locale != "zh-Hans" && locale != "en" {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "locale must be zh-Hans or en"})
		return
	}
	version, err := c.store.UpsertPrompt(scope, locale, defaultPrompt(scope, locale))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"scope": scope, "locale": locale, "version": version, "restored": true})
}

func (c *relayConfig) handleUsage(w http.ResponseWriter, r *http.Request) {
	days := 30
	usage, err := c.store.UsageSummary(days)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"days": days, "usage": usage})
}

func (c *relayConfig) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "time": time.Now().UTC().Format(time.RFC3339)})
}
