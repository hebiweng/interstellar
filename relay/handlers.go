package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"slices"
	"sort"
	"strconv"
	"strings"
	"sync"
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
	appStoreServer *appStoreServerClient
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
	UserID                  string          `json:"userID"`
	RequestID               string          `json:"requestID"`
	ReportID                string          `json:"reportID"`
	Mode                    string          `json:"mode"`      // chart | period
	ChartKind               string          `json:"chartKind"` // natal | current-sky | transit | secondary | solar-return | synastry
	CompareType             string          `json:"compareType,omitempty"`
	ThemeKind               string          `json:"themeKind,omitempty"`
	ReportPromptKey         string          `json:"reportPromptKey,omitempty"`
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
	if g.Mode == "compare" {
		scope := "compare." + strings.TrimSpace(g.CompareType)
		if !slices.Contains([]string{
			"compare.me_over_time", "compare.two_people", "compare.two_places",
			"compare.relationship_over_time",
		}, scope) {
			return "", errors.New("invalid compareType")
		}
		if strings.TrimSpace(g.ReportPromptKey) != scope {
			return "", errors.New("reportPromptKey does not match compare scope")
		}
		return scope, nil
	}
	if g.Mode == "ask_deep" {
		if strings.TrimSpace(g.ReportPromptKey) != "ask.deep_analysis" {
			return "", errors.New("reportPromptKey does not match Ask Deep Analysis scope")
		}
		return "ask.deep_analysis", nil
	}
	if g.Mode == "theme" {
		scope := "theme." + strings.TrimSpace(g.ThemeKind)
		if !slices.Contains(validScopes(), scope) {
			return "", errors.New("invalid themeKind")
		}
		if strings.TrimSpace(g.ReportPromptKey) != scope {
			return "", errors.New("reportPromptKey does not match theme scope")
		}
		return scope, nil
	}
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
	var scope string
	switch g.ChartKind {
	case "natal", "current-sky", "transit", "secondary", "solar-return", "synastry",
		"tertiary", "lunar-return", "solar-arc", "relocation",
		"twelfth-harmonic", "thirteenth-harmonic":
		scope = "chart." + g.ChartKind
	default:
		if strings.HasPrefix(g.ChartKind, "relationship.") && slices.Contains(validScopes(), g.ChartKind) {
			scope = g.ChartKind
		} else {
			return "", errors.New("invalid chartKind")
		}
	}
	if key := strings.TrimSpace(g.ReportPromptKey); key != "" && key != scope {
		return "", errors.New("reportPromptKey does not match chart scope")
	}
	return scope, nil
}

func creditCostForScope(scope string) int {
	if strings.HasPrefix(scope, "theme.") {
		return 2
	}
	return 1
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
			writeAppVerificationError(w, http.StatusServiceUnavailable, "app_attest_unavailable", true)
			return
		}
		if err := c.appAttest.verifyGenerateRequest(r, body, installationID); err != nil {
			logAppAttestRejection(r, "generate_assertion", err)
			writeAppVerificationError(w, http.StatusUnauthorized, "app_attest_invalid", false)
			return
		}
	}
	scope, err := req.scope()
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	requestedLocale := strings.TrimSpace(req.Locale)
	locale := effectiveReportLocale(requestedLocale)
	req.Locale = locale
	requestHash := requestDigest(body)
	if !validCommerceID(req.UserID) || !validCommerceID(req.RequestID) || strings.TrimSpace(req.ReportID) == "" {
		writeError(w, http.StatusBadRequest, "commerce_identity_required", "valid userID, requestID and reportID are required", false)
		return
	}
	if _, err := c.store.SyncCommerceUser(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "commerce_identity_conflict", err.Error(), false)
		return
	}
	retryExisting := false
	if existing, lookupErr := c.store.GetReportRequest(req.UserID, req.RequestID); lookupErr == nil {
		if existing.RequestHash != requestHash {
			writeError(w, http.StatusConflict, "idempotency_conflict", "requestID was already used for different content", false)
			return
		}
		if existing.ReportStatus == "failed" && existing.CreditStatus == "released" {
			retryExisting = true
		} else {
			writeReportState(w, existing)
			return
		}
	} else if !errors.Is(lookupErr, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, "request_lookup_failed", "could not inspect request state", true)
		return
	}

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

	prompt, version, err := c.store.GetPrompt(scope, canonicalPromptLocale)
	if err != nil {
		_ = c.store.RecordUsage(scope, model, 0, 0, false)
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "prompt lookup failed"})
		return
	}
	if strings.TrimSpace(prompt) == "" {
		if c.seed {
			prompt = defaultPrompt(scope, canonicalPromptLocale)
			_, _ = c.store.UpsertPrompt(scope, canonicalPromptLocale, prompt)
			version = 1
		} else {
			_ = c.store.RecordUsage(scope, model, 0, 0, false)
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "prompt template missing for " + scope})
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
	var reservationErr error
	if retryExisting {
		_, reservationErr = c.store.RetryCreditReservation(req.UserID, installationID, req.RequestID, requestHash, model)
	} else {
		_, reservationErr = c.store.ReserveCredit(req.UserID, installationID, req.RequestID, req.ReportID, requestHash, scope, requestedLocale, locale, model, creditCostForScope(scope))
	}
	if reservationErr != nil {
		status := http.StatusConflict
		code := "credit_reservation_failed"
		if strings.Contains(reservationErr.Error(), "insufficient") {
			status, code = http.StatusPaymentRequired, "credits_required"
		}
		writeError(w, status, code, reservationErr.Error(), false)
		return
	}

	startedAt := time.Now()
	userContent := buildUserContent(req, scope)
	key := req.UserID + "/" + req.RequestID
	if _, loaded := generationJobs.LoadOrStore(key, struct{}{}); !loaded {
		go c.runGenerationJob(key, req, scope, locale, provider, model, prompt, version, userContent, evidenceIDs, requestHash, startedAt)
	}
	writeJSON(w, http.StatusAccepted, map[string]any{"requestID": req.RequestID, "status": "generating"})
}

var generationJobs sync.Map

func (c *relayConfig) runGenerationJob(key string, req generateRequest, scope, locale string, provider *ProviderSecret, model, prompt string, version int, userContent string, evidenceIDs map[string]bool, requestHash string, startedAt time.Time) {
	defer generationJobs.Delete(key)
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Second)
	defer cancel()
	var resultPayload any
	var usedModel string
	var promptTokens, completionTokens, reasoningTokens int
	var err error
	if strings.HasPrefix(scope, "compare.") || scope == "ask.deep_analysis" {
		var raw json.RawMessage
		raw, usedModel, promptTokens, completionTokens, reasoningTokens, err = GenerateSpecial(
			ctx, c.client, provider.BaseURL, provider.APIKey, model,
			withRequestedOutputLanguage(prompt, locale), userContent, scope, req.CompareType,
			evidenceIDs, generationOptionsForScope(scope),
		)
		if err == nil {
			err = json.Unmarshal(raw, &resultPayload)
		}
	} else {
		var result *GenerationResult
		result, usedModel, promptTokens, completionTokens, reasoningTokens, err = Generate(
			ctx, c.client, provider.BaseURL, provider.APIKey, model,
			withOutputContract(withRequestedOutputLanguage(prompt, locale), locale), userContent,
			req.Locale, evidenceIDs, generationOptionsForScope(scope),
		)
		if err == nil {
			resultPayload = result.Report
		}
	}
	if err != nil {
		_ = c.store.ReleaseCredit(req.UserID, req.RequestID, "upstream_generation_failed", err.Error())
		_ = c.store.RecordUsage(scope, model, 0, 0, false)
		log.Printf(
			"generation failed scope=%s model=%s facts_bytes=%d evidence_count=%d user_content_bytes=%d: %v",
			scope, model, len(req.Facts), len(evidenceIDs), len(userContent), err,
		)
		return
	}
	_ = c.store.RecordUsage(scope, usedModel, promptTokens, completionTokens, true)

	response := map[string]any{
		"provider":                provider.ID,
		"model":                   usedModel,
		"cached":                  false,
		"promptVersion":           version,
		"generationSchemaVersion": req.GenerationSchemaVersion,
		"generatedAt":             time.Now().UTC().Format(time.RFC3339),
		"semanticFingerprint":     req.SemanticFingerprint,
		"factsHash":               req.FactsHash,
		"requestID":               req.RequestID,
		"reportID":                req.ReportID,
	}
	if strings.HasPrefix(scope, "compare.") || scope == "ask.deep_analysis" {
		response["result"] = resultPayload
	} else {
		response["report"] = resultPayload
	}
	payload, err := json.Marshal(response)
	if err != nil {
		_ = c.store.ReleaseCredit(req.UserID, req.RequestID, "report_persistence_failed", err.Error())
		return
	}
	if err := c.store.CompleteReportGeneration(req.UserID, req.RequestID, requestHash, usedModel, promptTokens, completionTokens, reasoningTokens, int(time.Since(startedAt).Milliseconds()), string(payload)); err != nil {
		_ = c.store.ReleaseCredit(req.UserID, req.RequestID, "report_persistence_failed", err.Error())
		log.Printf("report persistence failed scope=%s request=%s: %v", scope, req.RequestID, err)
	}
}

func generationOptionsForScope(scope string) GenerationOptions {
	if strings.HasPrefix(scope, "theme.") {
		return GenerationOptions{MaxOutputTokens: 16000, FirstAttemptTimeout: 90 * time.Second}
	}
	return GenerationOptions{}
}

func writeReportState(w http.ResponseWriter, rec ReportRequestRecord) {
	switch rec.ReportStatus {
	case "awaiting_ack", "success":
		writeJSON(w, http.StatusOK, map[string]any{"requestID": rec.RequestID, "status": "completed"})
	case "failed":
		writeJSON(w, http.StatusOK, map[string]any{"requestID": rec.RequestID, "status": "failed", "code": rec.ErrorCode, "error": safeErrorMessage(rec.ErrorMessage)})
	default:
		writeJSON(w, http.StatusAccepted, map[string]any{"requestID": rec.RequestID, "status": "generating"})
	}
}

func (c *relayConfig) handleReportStatus(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID    string `json:"userID"`
		RequestID string `json:"requestID"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil || !validCommerceID(req.UserID) || !validCommerceID(req.RequestID) {
		writeError(w, http.StatusBadRequest, "invalid_request", "valid userID and requestID are required", false)
		return
	}
	if _, err := c.store.SyncCommerceUser(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "identity_conflict", err.Error(), false)
		return
	}
	rec, err := c.store.GetReportRequest(req.UserID, req.RequestID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "report_not_found", "no report task with this requestID", false)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "report_status_unavailable", "could not load report status", true)
		return
	}
	writeReportState(w, rec)
}

func (c *relayConfig) handleReportFetch(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID    string `json:"userID"`
		RequestID string `json:"requestID"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil || !validCommerceID(req.UserID) || !validCommerceID(req.RequestID) {
		writeError(w, http.StatusBadRequest, "invalid_request", "valid userID and requestID are required", false)
		return
	}
	if _, err := c.store.SyncCommerceUser(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "identity_conflict", err.Error(), false)
		return
	}
	rec, err := c.store.GetReportRequest(req.UserID, req.RequestID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "report_not_found", "no report task with this requestID", false)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "report_unavailable", "could not load report", true)
		return
	}
	switch rec.ReportStatus {
	case "failed":
		writeError(w, http.StatusGone, "report_failed", "report generation failed; credit was released", false)
		return
	case "awaiting_ack":
	default:
		writeError(w, http.StatusAccepted, "report_generating", "report is still generating", true)
		return
	}
	payload, err := c.store.GetReportPayload(req.UserID, req.RequestID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "report_payload_missing", "completed report payload is unavailable", true)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(payload))
}

func validateGenerationRequest(req generateRequest) (map[string]bool, error) {
	if req.Mode != "period" {
		if req.SemanticFingerprint == "" || req.FactsHash == "" || req.GenerationSchemaVersion <= 0 {
			return nil, errors.New("semanticFingerprint, factsHash and generationSchemaVersion are required")
		}
	}
	var raw any
	if err := json.Unmarshal(req.Facts, &raw); err != nil {
		return nil, errors.New("facts must be a JSON object")
	}
	object, ok := raw.(map[string]any)
	if !ok {
		return nil, errors.New("facts must be a JSON object")
	}
	if req.Mode == "compare" || req.Mode == "ask_deep" {
		if key := prohibitedAIFactKey(object); key != "" {
			return nil, fmt.Errorf("facts contain prohibited private field %q", key)
		}
	}
	evidence := map[string]bool{}
	var ids []string
	switch req.Mode {
	case "compare":
		payloadType, _ := object["compare_type"].(string)
		if strings.TrimSpace(payloadType) != strings.TrimSpace(req.CompareType) {
			return nil, errors.New("facts compare_type does not match compareType")
		}
		facts, _ := object["facts"].(map[string]any)
		for _, name := range []string{"baseline", "snapshotA", "snapshotB", "relationship"} {
			ids = append(ids, factIDs(facts[name])...)
		}
	case "ask_deep":
		ids = append(ids, factIDs(object["facts"])...)
	default:
		ids = append(ids, factIDs(object["evidenceFacts"])...)
	}
	for _, id := range ids {
		if id == "" || evidence[id] {
			return nil, errors.New("evidence fact IDs must be non-empty and unique")
		}
		evidence[id] = true
	}
	if req.Mode != "period" && len(evidence) == 0 {
		return nil, errors.New("chart generation requires stable evidence facts")
	}
	return evidence, nil
}

func factIDs(value any) []string {
	items, _ := value.([]any)
	ids := make([]string, 0, len(items))
	for _, item := range items {
		object, _ := item.(map[string]any)
		id, _ := object["id"].(string)
		if strings.TrimSpace(id) == "" {
			id = compareFactIdentity(object["identity"])
		}
		ids = append(ids, strings.TrimSpace(id))
	}
	return ids
}

func compareFactIdentity(value any) string {
	identity, _ := value.(map[string]any)
	if len(identity) == 0 {
		return ""
	}
	components := make([]string, 0, 6)
	for _, key := range []string{"technique", "factType", "sourceObject", "targetObject", "relation", "referenceChart"} {
		text, _ := identity[key].(string)
		text = strings.ToLower(strings.TrimSpace(text))
		if text == "" {
			text = "_"
		} else {
			text = strings.Join(strings.Fields(text), "_")
			text = strings.ReplaceAll(text, "|", "%7c")
		}
		components = append(components, text)
	}
	return strings.Join(components, "|")
}

func prohibitedAIFactKey(value any) string {
	forbidden := map[string]bool{
		"latitude": true, "longitude": true, "coordinate": true, "coordinates": true,
		"timezone": true, "timezoneid": true, "time_zone": true, "time_zone_id": true,
		"profile": true, "birthprofile": true, "birth_profile": true,
		"birthdate": true, "birth_date": true, "utcdate": true, "utc_date": true,
		"julianday": true, "julian_day": true, "snapshot": true,
		"chartsnapshot": true, "chart_snapshot": true, "renderedchart": true,
		"rendered_chart": true, "wheel": true, "wheelscreenshot": true,
	}
	switch typed := value.(type) {
	case map[string]any:
		for key, child := range typed {
			if forbidden[strings.ToLower(strings.TrimSpace(key))] {
				return key
			}
			if found := prohibitedAIFactKey(child); found != "" {
				return found
			}
		}
	case []any:
		for _, child := range typed {
			if found := prohibitedAIFactKey(child); found != "" {
				return found
			}
		}
	}
	return ""
}

func buildUserContent(req generateRequest, scope string) string {
	var b strings.Builder
	if req.Locale == "zh-Hans" {
		b.WriteString("计算事实（不可变，只能据此解读，不得补算或臆造）：\n")
	} else {
		b.WriteString("Calculated facts (immutable; interpret only these facts and never recompute or invent):\n")
	}
	b.WriteString(llmSafeJSON(req.Facts, true))
	if req.Locale == "zh-Hans" {
		b.WriteString("\n\n参数与范围：\n")
	} else {
		b.WriteString("\n\nParameters and scope:\n")
	}
	b.WriteString(llmSafeJSON(req.Params, false))
	return b.String()
}

func llmSafeJSON(raw json.RawMessage, sanitizeNestedParams bool) string {
	var value any
	if err := json.Unmarshal(raw, &value); err != nil {
		return string(raw)
	}
	if object, ok := value.(map[string]any); ok {
		if sanitizeNestedParams {
			sanitizeLLMFacts(object)
		} else {
			value = allowedLLMContext(object)
		}
	}
	encoded, err := json.Marshal(value)
	if err != nil {
		return string(raw)
	}
	return string(encoded)
}

func sanitizeLLMFacts(facts map[string]any) {
	if params, ok := facts["params"].(map[string]any); ok {
		context := allowedLLMContext(params)
		if len(context) == 0 {
			delete(facts, "params")
		} else {
			facts["params"] = context
		}
	}
	for _, key := range []string{"chart", "reference"} {
		if chart, ok := facts[key].(map[string]any); ok {
			removeRawChartTime(chart)
		}
	}
	if partner, ok := facts["partner"].(map[string]any); ok {
		if chart, ok := partner["chart"].(map[string]any); ok {
			removeRawChartTime(chart)
		}
	}
	removeTimeZoneMetadata(facts)
}

func allowedLLMContext(params map[string]any) map[string]any {
	context := map[string]any{}
	for _, key := range []string{"relationship", "theme", "analysisMode", "period", "focus"} {
		if value, ok := params[key]; ok {
			context[key] = value
		}
	}
	return context
}

func removeRawChartTime(chart map[string]any) {
	delete(chart, "utcDate")
	delete(chart, "julianDay")
}

func removeTimeZoneMetadata(value any) {
	switch current := value.(type) {
	case map[string]any:
		for key, child := range current {
			if strings.EqualFold(key, "timezone") || strings.EqualFold(key, "timeZoneIdentifier") {
				delete(current, key)
				continue
			}
			removeTimeZoneMetadata(child)
		}
	case []any:
		for _, child := range current {
			removeTimeZoneMetadata(child)
		}
	}
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
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "provider base_url is required"})
			return
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
	_, usedModel, _, _, _, err := Generate(ctx, c.client, provider.BaseURL, provider.APIKey, model,
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
		if req.Locale != canonicalPromptLocale {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "prompt locale must be en"})
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
		locale = canonicalPromptLocale
	}
	if locale != canonicalPromptLocale {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "prompt locale must be en"})
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
