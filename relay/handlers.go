package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"sort"
	"strconv"
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
	store          *Store
	sessions       *SessionStore
	client         *http.Client
	seed           bool
	dailyQuota     int
	allowDevBypass bool
	appAttest      *appAttestConfig
}

type feedbackSubmitRequest struct {
	Type    string `json:"type"`
	Content string `json:"content"`
	Contact string `json:"contact"`
}

func (c *relayConfig) handleFeedback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
	var req feedbackSubmitRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_feedback", "invalid feedback payload", false)
		return
	}
	feedback, err := c.store.SaveFeedback(req.Type, req.Content, req.Contact)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "invalid_feedback", err.Error(), false)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"ok": true,
		"feedback": map[string]any{
			"id": feedback.ID, "type": feedback.Type, "status": feedback.Status,
			"createdAt": feedback.CreatedAt,
		},
	})
}

type generateRequest struct {
	Mode                    string          `json:"mode"`                 // chart | period
	ChartKind               string          `json:"chartKind"`            // natal | current-sky | transit | secondary | solar-return | synastry
	PeriodType              string          `json:"periodType,omitempty"` // daily | monthly | solar-return
	Preset                  string          `json:"preset,omitempty"`     // modern | classical
	ProfileHash             string          `json:"profileHash"`
	SemanticFingerprint     string          `json:"semanticFingerprint,omitempty"`
	FactsHash               string          `json:"factsHash,omitempty"`
	GenerationSchemaVersion int             `json:"generationSchemaVersion,omitempty"`
	Params                  json.RawMessage `json:"params"`
	Facts                   json.RawMessage `json:"facts"`
	Locale                  string          `json:"locale"`
	ClientVer               string          `json:"clientVersion,omitempty"`
	ForceRegenerate         bool            `json:"forceRegenerate,omitempty"`
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
	return 24 * time.Hour
}

func writeError(w http.ResponseWriter, status int, code, message string, retryable bool) {
	writeJSON(w, status, map[string]any{"error": message, "code": code, "retryable": retryable})
}

func (c *relayConfig) handleGenerate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 4<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "could not read request", false)
		return
	}
	var req generateRequest
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid request: "+err.Error(), false)
		return
	}
	installationID := strings.TrimSpace(r.Header.Get("X-Installation-ID"))
	devBypass := c.allowDevBypass && r.Header.Get("X-App-Attest-Development-Bypass") == "1"
	if installationID == "" {
		writeError(w, http.StatusUnauthorized, "installation_required", "installation identity is required", false)
		return
	}
	if !devBypass {
		if c.appAttest == nil {
			writeError(w, http.StatusServiceUnavailable, "app_attest_unavailable", "App Attest is not configured", true)
			return
		}
		if err := c.appAttest.verifyGenerateRequest(r, body, installationID); err != nil {
			writeError(w, http.StatusUnauthorized, "app_attest_invalid", err.Error(), false)
			return
		}
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
	req.Locale = locale

	evidenceIDs, err := validateGenerationRequest(req)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_generation_contract", err.Error(), false)
		return
	}

	provider, err := c.store.GetGenerationProvider()
	if err != nil {
		_ = c.store.RecordUsage(scope, "unconfigured", 0, 0, false)
		writeError(w, http.StatusServiceUnavailable, "provider_unavailable", err.Error(), true)
		return
	}
	model := provider.DefaultModel
	if model == "" {
		model, _ = c.store.GetSetting("default_model")
	}
	if model == "" {
		_ = c.store.RecordUsage(scope, "unconfigured", 0, 0, false)
		writeError(w, http.StatusServiceUnavailable, "model_unavailable", "no default model configured", true)
		return
	}
	if enabled, modelErr := c.store.IsProviderModelEnabled(provider.ID, model); modelErr != nil {
		writeError(w, http.StatusInternalServerError, "model_state_unavailable", modelErr.Error(), true)
		return
	} else if !enabled {
		writeError(w, http.StatusServiceUnavailable, "model_disabled", "the default model is disabled", false)
		return
	}

	prompt, version, err := c.store.GetPrompt(scope, locale)
	if err != nil {
		_ = c.store.RecordUsage(scope, model, 0, 0, false)
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "prompt lookup failed"})
		return
	}
	if strings.TrimSpace(prompt) == "" {
		if c.seed {
			prompt = defaultPrompt(scope, locale)
			_, _ = c.store.UpsertPrompt(scope, locale, prompt)
			version = 1
		} else {
			_ = c.store.RecordUsage(scope, model, 0, 0, false)
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "prompt template missing for " + scope})
			return
		}
	}

	cacheKey := cacheKeyFor(req, scope, model, locale, version)
	if !req.ForceRegenerate {
		if payload, hit, _ := c.store.CacheGet(cacheKey); hit {
			var cached map[string]any
			_ = json.Unmarshal([]byte(payload), &cached)
			cached["cached"] = true
			_ = c.store.RecordUsage(scope, model, 0, 0, true)
			writeJSON(w, http.StatusOK, cached)
			return
		}
	}

	count, allowed, err := c.store.ConsumeInstallationQuota(installationID, c.dailyQuota)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "quota_unavailable", "could not verify daily quota", true)
		return
	}
	w.Header().Set("X-Daily-Generation-Count", fmt.Sprintf("%d", count))
	if !allowed {
		writeError(w, http.StatusTooManyRequests, "daily_quota_exceeded", "daily generation quota exceeded", false)
		return
	}

	userContent := buildUserContent(req, scope)
	result, usedModel, promptTokens, completionTokens, err := Generate(
		r.Context(), c.client, provider.BaseURL, provider.APIKey, model, prompt, userContent,
		req.Locale, evidenceIDs,
	)
	if err != nil {
		_ = c.store.RecordUsage(scope, model, 0, 0, false)
		log.Printf(
			"generation failed scope=%s model=%s facts_bytes=%d evidence_count=%d user_content_bytes=%d: %v",
			scope, model, len(req.Facts), len(evidenceIDs), len(userContent), err,
		)
		writeError(w, http.StatusBadGateway, "upstream_generation_failed", "generation failed: "+err.Error(), true)
		return
	}
	_ = c.store.RecordUsage(scope, usedModel, promptTokens, completionTokens, true)

	response := map[string]any{
		"report":                  result.Report,
		"provider":                provider.ID,
		"model":                   usedModel,
		"cached":                  false,
		"promptVersion":           version,
		"generationSchemaVersion": req.GenerationSchemaVersion,
		"generatedAt":             time.Now().UTC().Format(time.RFC3339),
		"semanticFingerprint":     req.SemanticFingerprint,
		"factsHash":               req.FactsHash,
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
		scope, req.Preset, req.ProfileHash, req.SemanticFingerprint, req.FactsHash,
		fmt.Sprintf("schema%d", req.GenerationSchemaVersion), params, facts, model, locale,
		fmt.Sprintf("p%d", promptVersion), req.ClientVer,
	}, "|")
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func validateGenerationRequest(req generateRequest) (map[string]bool, error) {
	if req.Mode != "period" {
		if req.SemanticFingerprint == "" || req.FactsHash == "" || req.GenerationSchemaVersion <= 0 {
			return nil, errors.New("semanticFingerprint, factsHash and generationSchemaVersion are required")
		}
	}
	var facts struct {
		EvidenceFacts []struct {
			ID string `json:"id"`
		} `json:"evidenceFacts"`
	}
	if err := json.Unmarshal(req.Facts, &facts); err != nil {
		return nil, errors.New("facts must be a JSON object")
	}
	evidence := map[string]bool{}
	for _, fact := range facts.EvidenceFacts {
		if fact.ID == "" || evidence[fact.ID] {
			return nil, errors.New("evidence fact IDs must be non-empty and unique")
		}
		evidence[fact.ID] = true
	}
	if req.Mode != "period" && len(evidence) == 0 {
		return nil, errors.New("chart generation requires stable evidence facts")
	}
	return evidence, nil
}

func buildUserContent(req generateRequest, scope string) string {
	var b strings.Builder
	if req.Locale == "zh-Hans" {
		b.WriteString("计算事实（不可变，只能据此解读，不得补算或臆造）：\n")
	} else {
		b.WriteString("Calculated facts (immutable; interpret only these facts and never recompute or invent):\n")
	}
	b.WriteString(string(req.Facts))
	if req.Locale == "zh-Hans" {
		b.WriteString("\n\n参数与范围：\n")
	} else {
		b.WriteString("\n\nParameters and scope:\n")
	}
	b.WriteString(string(req.Params))
	return b.String()
}

// ---- Admin handlers ----

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (c *relayConfig) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	var req loginRequest
	if err := readJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid request"})
		return
	}
	if !c.store.VerifyAdmin(req.Username, req.Password) {
		writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "invalid credentials"})
		return
	}
	token, expires, err := c.sessions.Create(req.Username)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "session_create_failed", "could not create session", true)
		return
	}
	setAdminCookie(w, token, expires)
	_ = c.store.RecordAudit(req.Username, "admin.login", req.Username, map[string]any{})
	writeJSON(w, http.StatusOK, map[string]any{"expiresAt": expires.Format(time.RFC3339)})
}

func (c *relayConfig) handleLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	username := adminUsername(r)
	c.sessions.Revoke(adminToken(r))
	clearAdminCookie(w)
	_ = c.store.RecordAudit(username, "admin.logout", username, map[string]any{})
	writeJSON(w, http.StatusOK, map[string]any{"loggedOut": true})
}

func (c *relayConfig) handleSession(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"authenticated": true, "username": adminUsername(r)})
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
			IsDefault    bool   `json:"is_default"`
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
		if p.DefaultModel != "" {
			enabled, modelErr := c.store.IsProviderModelEnabled(p.ID, p.DefaultModel)
			if modelErr != nil {
				writeError(w, http.StatusInternalServerError, "model_state_unavailable", modelErr.Error(), true)
				return
			}
			if !enabled {
				writeError(w, http.StatusBadRequest, "model_disabled", "a disabled model cannot be the default", false)
				return
			}
		}
		saved, err := c.store.UpsertProvider(p, raw.APIKey)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		if raw.IsDefault {
			if !saved.Enabled {
				writeError(w, http.StatusBadRequest, "provider_disabled", "a disabled provider cannot be the default", false)
				return
			}
			if err := c.store.SetSetting("default_provider", saved.ID); err != nil {
				writeError(w, http.StatusInternalServerError, "default_provider_failed", err.Error(), true)
				return
			}
			saved.IsDefault = true
		} else if currentDefault, _ := c.store.GetSetting("default_provider"); currentDefault == saved.ID {
			// Saving unrelated fields must not silently change routing. Choosing
			// another provider as default is the explicit way to replace it.
			saved.IsDefault = true
		}
		_ = c.store.RecordAudit(adminUsername(r), "provider.upsert", saved.ID, map[string]any{
			"enabled": saved.Enabled, "defaultModel": saved.DefaultModel, "apiKeyChanged": raw.APIKey != "",
		})
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
	_ = c.store.RecordAudit(adminUsername(r), "provider.delete", id, map[string]any{})
	writeJSON(w, http.StatusOK, map[string]any{"deleted": id})
}

func (c *relayConfig) handleProviderModels(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
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
	if !provider.Enabled {
		writeError(w, http.StatusConflict, "provider_disabled", "provider is disabled", false)
		return
	}
	models, err := fetchModels(r.Context(), c.client, provider.BaseURL, provider.APIKey)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]any{"error": "fetch models failed: " + err.Error()})
		return
	}
	modelIDs := make([]string, 0, len(models))
	for _, model := range models {
		modelIDs = append(modelIDs, model["id"].(string))
	}
	if err := c.store.SyncProviderModels(provider.ID, modelIDs); err != nil {
		writeError(w, http.StatusInternalServerError, "model_sync_failed", err.Error(), true)
		return
	}
	stored, err := c.store.ListProviderModels(provider.ID, provider.DefaultModel)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "model_list_failed", err.Error(), true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"models": stored})
}

func (c *relayConfig) handleModelState(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "PUT required", false)
		return
	}
	var req struct {
		ProviderID string `json:"provider_id"`
		ModelID    string `json:"model_id"`
		Enabled    bool   `json:"enabled"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_model_payload", "invalid model payload", false)
		return
	}
	provider, err := c.store.GetProvider(req.ProviderID)
	if err != nil {
		writeError(w, http.StatusNotFound, "provider_not_found", "provider not found", false)
		return
	}
	if err := c.store.SetProviderModelEnabled(req.ProviderID, req.ModelID, req.Enabled); err != nil {
		writeError(w, http.StatusInternalServerError, "model_update_failed", err.Error(), true)
		return
	}
	_ = c.store.RecordAudit(adminUsername(r), "model.update", req.ProviderID+"/"+req.ModelID, map[string]any{
		"enabled": req.Enabled, "isDefault": provider.DefaultModel == req.ModelID,
	})
	writeJSON(w, http.StatusOK, map[string]any{"provider_id": req.ProviderID, "model_id": req.ModelID, "enabled": req.Enabled})
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
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/admin/providers/")
	id = strings.TrimSuffix(id, "/test")
	provider, err := c.store.GetProviderSecret(id)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "provider not found"})
		return
	}
	if !provider.Enabled {
		writeError(w, http.StatusConflict, "provider_disabled", "provider is disabled", false)
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
	if enabled, modelErr := c.store.IsProviderModelEnabled(provider.ID, model); modelErr != nil {
		writeError(w, http.StatusInternalServerError, "model_state_unavailable", modelErr.Error(), true)
		return
	} else if !enabled {
		writeError(w, http.StatusConflict, "model_disabled", "model is disabled", false)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()
	_, usedModel, _, _, err := Generate(ctx, c.client, provider.BaseURL, provider.APIKey, model,
		`You are a connectivity check. Return JSON only. Create a report object with a title, subtitle and exactly four non-empty sections. Each section has number, title, body and an empty evidenceFactIDs array.`,
		`{"purpose":"provider connectivity test; do not interpret user data"}`, "en", nil)
	if err != nil {
		_ = c.store.RecordAudit(adminUsername(r), "provider.test", id, map[string]any{"ok": false, "model": model})
		log.Printf("provider test failed provider=%s model=%s: %v", id, model, err)
		writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": err.Error()})
		return
	}
	_ = c.store.RecordAudit(adminUsername(r), "provider.test", id, map[string]any{"ok": true, "model": usedModel})
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
		req.SystemPrompt = strings.TrimSpace(req.SystemPrompt)
		if req.SystemPrompt == "" {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "system_prompt must not be empty"})
			return
		}
		version, err := c.store.UpsertPrompt(req.Scope, req.Locale, req.SystemPrompt)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		_ = c.store.RecordAudit(adminUsername(r), "prompt.update", req.Scope+"/"+req.Locale, map[string]any{"version": version})
		writeJSON(w, http.StatusOK, map[string]any{"scope": req.Scope, "locale": req.Locale, "version": version})
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method not allowed"})
	}
}

func (c *relayConfig) handlePromptRestore(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
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
	valid := false
	for _, candidate := range validScopes() {
		if scope == candidate {
			valid = true
			break
		}
	}
	if !valid {
		writeError(w, http.StatusBadRequest, "invalid_scope", "unknown prompt scope", false)
		return
	}
	version, err := c.store.UpsertPrompt(scope, locale, defaultPrompt(scope, locale))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	_ = c.store.RecordAudit(adminUsername(r), "prompt.restore", scope+"/"+locale, map[string]any{"version": version})
	writeJSON(w, http.StatusOK, map[string]any{"scope": scope, "locale": locale, "version": version, "restored": true})
}

func (c *relayConfig) handleUsage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	days := 30
	usage, err := c.store.UsageSummary(days)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"days": days, "usage": usage})
}

func (c *relayConfig) handleAdminFeedback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	feedbackType := strings.TrimSpace(r.URL.Query().Get("type"))
	items, err := c.store.ListFeedback(status, feedbackType, 200)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "feedback_unavailable", "could not load feedback", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"total": len(items), "items": items})
}

func (c *relayConfig) handleAdminFeedbackItem(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPatch {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "PATCH required", false)
		return
	}
	rawID := strings.Trim(strings.TrimPrefix(r.URL.Path, "/admin/feedback/"), "/")
	id, err := strconv.ParseInt(rawID, 10, 64)
	if err != nil || id < 1 {
		writeError(w, http.StatusBadRequest, "invalid_feedback_id", "invalid feedback id", false)
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_feedback_status", "invalid feedback status", false)
		return
	}
	item, err := c.store.UpdateFeedbackStatus(id, strings.TrimSpace(req.Status))
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "feedback_not_found", "feedback not found", false)
		return
	}
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "invalid_feedback_status", err.Error(), false)
		return
	}
	_ = c.store.RecordAudit(adminUsername(r), "feedback.status", rawID, map[string]any{"status": item.Status})
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "feedback": item})
}

func (c *relayConfig) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "time": time.Now().UTC().Format(time.RFC3339)})
}
