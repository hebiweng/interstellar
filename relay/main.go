package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "health" {
		// Health-check subcommand: used by the container healthcheck without
		// requiring wget/curl in the runtime image.
		target := envOr("RELAY_HEALTH_URL", "http://127.0.0.1:8080/v1/health")
		resp, err := http.Get(target)
		if err != nil {
			os.Exit(1)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			os.Exit(1)
		}
		return
	}
	addr := envOr("RELAY_ADDR", ":8080")
	dbPath := envOr("RELAY_DB_PATH", "./relay.db")
	secret := os.Getenv("RELAY_SECRET")
	adminUser := os.Getenv("RELAY_ADMIN_USER")
	adminPass := os.Getenv("RELAY_ADMIN_PASS")

	store, err := OpenStore(dbPath, secret)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	defer store.Close()

	seed := os.Getenv("RELAY_SEED_PROMPTS") == "1"
	// Provider presets are seeded so the admin console can switch providers
	// without manual SQL. API keys are only ever entered via the admin console.
	if envOr("RELAY_SEED_PROVIDERS", "1") == "1" {
		seedProviderPresets(store)
	}
	if seed {
		for _, scope := range validScopes() {
			prompt, _, _ := store.GetPrompt(scope, canonicalPromptLocale)
			if shouldReplaceSeededPrompt(scope, prompt) {
				if _, err := store.UpsertPrompt(scope, canonicalPromptLocale, defaultPrompt(scope, canonicalPromptLocale)); err != nil {
					log.Printf("seed prompt %s/%s: %v", scope, canonicalPromptLocale, err)
				}
			}
		}
	}
	if err := store.EnsureAdmin(adminUser, adminPass); err != nil {
		log.Fatalf("admin bootstrap: %v", err)
	}
	if envOr("RELAY_PRUNE_OTHER_ADMINS", "0") == "1" {
		if !store.VerifyAdmin(adminUser, adminPass) {
			log.Fatal("admin bootstrap verification failed; refusing to prune existing admins")
		}
		if removed, pruneErr := store.DeleteOtherAdmins(adminUser); pruneErr != nil {
			log.Fatalf("prune legacy admins: %v", pruneErr)
		} else if removed > 0 {
			_ = store.RecordAudit(adminUser, "admin.prune", "legacy-admins", map[string]any{"removed": removed})
		}
	}

	sessions := NewSessionStore(store)
	allowDevBypass := os.Getenv("RELAY_ALLOW_DEV_BYPASS") == "1"
	var appAttest *appAttestConfig
	appAttestAppID := strings.TrimSpace(os.Getenv("RELAY_APP_ATTEST_APP_ID"))
	if appAttestAppID != "" {
		appAttest, err = newAppAttestConfig(
			store,
			appAttestAppID,
			envOr("RELAY_APP_ATTEST_ENVIRONMENT", "production"),
			os.Getenv("RELAY_APP_ATTEST_BUNDLE_VERSION"),
			os.Getenv("RELAY_APP_ATTEST_ALLOW_DEVELOPMENT") == "1",
		)
		if err != nil {
			log.Fatalf("App Attest: %v", err)
		}
	} else if !allowDevBypass {
		log.Fatal("App Attest: RELAY_APP_ATTEST_APP_ID must be set when development bypass is disabled")
	}
	appStoreServer, err := newAppStoreServerClientFromEnvironment()
	if err != nil {
		log.Fatalf("App Store Server API: %v", err)
	}
	cfg := &relayConfig{
		store:    store,
		sessions: sessions,
		client: &http.Client{
			Timeout: 600 * time.Second,
		},
		seed:           seed,
		dailyQuota:     envInt("RELAY_DAILY_GENERATION_QUOTA", 20),
		allowDevBypass: allowDevBypass,
		appAttest:      appAttest,
		appStoreServer: appStoreServer,
	}
	if recovered, err := store.FailStuckGenerations(); err != nil {
		log.Printf("recover stuck generations: %v", err)
	} else if recovered > 0 {
		log.Printf("marked %d interrupted generations as failed", recovered)
	}

	limiter := newRateLimiter(60, time.Minute)
	adminLimiter := newRateLimiter(10, time.Minute)
	attestLimiter := newRateLimiter(30, time.Minute)
	feedbackLimiter := newRateLimiter(10, time.Hour)
	if appStoreServer != nil {
		intervalHours := envInt("RELAY_APP_STORE_RECONCILE_INTERVAL_HOURS", 6)
		if intervalHours < 1 {
			intervalHours = 1
		}
		go cfg.runAppStoreReconciliation(context.Background(), time.Duration(intervalHours)*time.Hour)
	} else {
		log.Printf("App Store Server API reconciliation disabled: credentials are not configured")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleAdminPage)
	mux.HandleFunc("/xiaoguiwk", handleAdminPage)
	mux.HandleFunc("/xiaoguiwk/", handleAdminPage)
	mux.HandleFunc("/v1/health", cfg.handleHealth)
	mux.HandleFunc("/privacy", handleLegalPage)
	mux.HandleFunc("/terms", handleLegalPage)
	if appAttest != nil {
		mux.HandleFunc("/v1/app-attest/challenge", attestLimiter.wrap(appAttest.handleChallenge))
		mux.HandleFunc("/v1/app-attest/attest", attestLimiter.wrap(appAttest.handleAttestation))
		mux.HandleFunc("/v1/app-attest/token", attestLimiter.wrap(appAttest.handleToken))
	}
	mux.HandleFunc("/v1/generate", limiter.wrap(cfg.handleGenerate))
	mux.HandleFunc("/v1/account/sync", limiter.wrap(cfg.handleAccountSync))
	mux.HandleFunc("/v1/account/delete", limiter.wrap(cfg.handleAccountDelete))
	mux.HandleFunc("/v1/account/restore", limiter.wrap(cfg.handleAccountRestore))
	mux.HandleFunc("/v1/store/transactions", limiter.wrap(cfg.handleStoreTransaction))
	mux.HandleFunc("/v1/store/notifications", limiter.wrap(cfg.handleAppStoreNotification))
	mux.HandleFunc("/v1/reports/ack", limiter.wrap(cfg.handleReportAck))
	mux.HandleFunc("/v1/reports/status", limiter.wrap(cfg.handleReportStatus))
	mux.HandleFunc("/v1/reports/fetch", limiter.wrap(cfg.handleReportFetch))
	mux.HandleFunc("/v1/feedback", feedbackLimiter.wrap(cfg.handleFeedback))

	// Admin API
	mux.HandleFunc("/admin/login", adminLimiter.wrap(cfg.handleLogin))
	mux.Handle("/admin/logout", requireAdmin(sessions, cfg.handleLogout))
	mux.Handle("/admin/session", requireAdmin(sessions, cfg.handleSession))
	mux.Handle("/admin/providers", requireAdmin(sessions, cfg.handleProviders))
	mux.HandleFunc("/admin/providers/", requireAdmin(sessions, func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		switch {
		case strings.HasSuffix(path, "/models"):
			cfg.handleProviderModels(w, r)
		case strings.HasSuffix(path, "/test"):
			cfg.handleProviderTest(w, r)
		case r.Method == http.MethodDelete:
			cfg.handleProviderDelete(w, r)
		default:
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "not found"})
		}
	}))
	mux.Handle("/admin/prompts", requireAdmin(sessions, cfg.handlePrompts))
	mux.HandleFunc("/admin/prompts/", requireAdmin(sessions, cfg.handlePromptRestore))
	mux.Handle("/admin/models", requireAdmin(sessions, cfg.handleModelState))
	mux.Handle("/admin/usage", requireAdmin(sessions, cfg.handleUsage))
	mux.Handle("/admin/reports", requireAdmin(sessions, cfg.handleAdminReports))
	mux.Handle("/admin/users", requireAdmin(sessions, cfg.handleAdminUsers))
	mux.HandleFunc("/admin/users/", requireAdmin(sessions, cfg.handleAdminUserItem))
	mux.Handle("/admin/feedback", requireAdmin(sessions, cfg.handleAdminFeedback))
	mux.HandleFunc("/admin/feedback/", requireAdmin(sessions, cfg.handleAdminFeedbackItem))

	log.Printf("relay listening on %s", addr)
	server := &http.Server{
		Addr:              addr,
		Handler:           sameOrigin(mux, os.Getenv("RELAY_ALLOWED_ORIGIN")),
		ReadHeaderTimeout: 10 * time.Second,
	}
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("server: %v", err)
	}
}

func shouldReplaceSeededPrompt(scope, prompt string) bool {
	return strings.TrimSpace(prompt) == "" ||
		prompt == legacyDefaultPromptV1(scope, canonicalPromptLocale) ||
		prompt == legacyDefaultPromptV2(scope, canonicalPromptLocale) ||
		(strings.HasPrefix(scope, "chart.") && prompt == legacyDefaultPromptV3(scope, canonicalPromptLocale)) ||
		(strings.HasPrefix(scope, "theme.") && prompt == legacyThemeDefaultPromptV1(scope))
}

// providerPresets lists the built-in provider presets. Presets only prefill
// connection details; API keys are entered via the admin console and the
// active provider is the default_provider setting, never hardcoded here.
var providerPresets = []Provider{
	{
		ID:           "deepseek",
		Label:        "DeepSeek",
		BaseURL:      "https://api.deepseek.com",
		DefaultModel: "deepseek-v4-flash",
		Enabled:      true,
	},
	{
		ID:      "openai",
		Label:   "OpenAI (ChatGPT)",
		BaseURL: "https://api.openai.com",
		Enabled: true,
	},
}

func seedProviderPresets(store *Store) {
	for _, preset := range providerPresets {
		existing, lookupErr := store.GetProvider(preset.ID)
		if lookupErr != nil {
			if _, err := store.UpsertProvider(preset, ""); err != nil {
				log.Fatalf("seed provider %s: %v", preset.ID, err)
			}
			continue
		}
		// Migrate the legacy DeepSeek default model only; never touch API keys
		// or admin edits.
		if existing.ID == "deepseek" && (existing.DefaultModel == "" || existing.DefaultModel == "deepseek-v4-pro") {
			existing.DefaultModel = "deepseek-v4-flash"
			if _, err := store.UpsertProvider(*existing, ""); err != nil {
				log.Fatalf("migrate DeepSeek default model: %v", err)
			}
		}
	}
	if currentDefault, _ := store.GetSetting("default_provider"); currentDefault == "" {
		if err := store.SetSetting("default_provider", providerPresets[0].ID); err != nil {
			log.Fatalf("set default provider: %v", err)
		}
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func sameOrigin(next http.Handler, allowedOrigin string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && (allowedOrigin == "" || origin != allowedOrigin) {
			writeJSON(w, http.StatusForbidden, map[string]any{"error": "origin not allowed", "code": "origin_denied"})
			return
		}
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", strings.Join([]string{
			"Content-Type", "Authorization", "X-Installation-ID",
			"X-App-Attest-Key-ID", "X-App-Attest-Token", "X-App-Attest-Challenge-ID",
			"X-App-Attest-Client-Data", "X-App-Attest-Assertion", "X-App-Attest-Development-Bypass",
		}, ", "))
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func envInt(key string, fallback int) int {
	value, err := strconv.Atoi(os.Getenv(key))
	if err != nil {
		return fallback
	}
	return value
}

// ---- Simple in-memory rate limiter (token bucket per client IP) ----

type rateLimiter struct {
	mu      sync.Mutex
	limit   int
	window  time.Duration
	clients map[string]*bucket
}

type bucket struct {
	count   int
	resetAt time.Time
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{limit: limit, window: window, clients: map[string]*bucket{}}
}

func (rl *rateLimiter) wrap(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := clientIP(r)
		rl.mu.Lock()
		b, ok := rl.clients[ip]
		now := time.Now()
		if !ok || now.After(b.resetAt) {
			b = &bucket{count: 0, resetAt: now.Add(rl.window)}
			rl.clients[ip] = b
		}
		b.count++
		remaining := b.resetAt.Sub(now).Seconds()
		rl.mu.Unlock()
		if b.count > rl.limit {
			w.Header().Set("Retry-After", fmtSeconds(remaining))
			writeJSON(w, http.StatusTooManyRequests, map[string]any{"error": "rate limit exceeded"})
			return
		}
		next(w, r)
	}
}

func fmtSeconds(seconds float64) string {
	return strings.TrimSuffix(strings.TrimSuffix(time.Duration(seconds*float64(time.Second)).String(), "0s"), "s")
}

func clientIP(r *http.Request) string {
	if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
		parts := strings.Split(forwarded, ",")
		return strings.TrimSpace(parts[0])
	}
	host := r.RemoteAddr
	if idx := strings.LastIndex(host, ":"); idx >= 0 {
		return host[:idx]
	}
	return host
}
