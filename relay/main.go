package main

import (
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
	if envOr("RELAY_SEED_DEEPSEEK", "1") == "1" {
		deepseek, lookupErr := store.GetProvider("deepseek")
		if lookupErr != nil {
			provider, providerErr := store.UpsertProvider(Provider{
				ID:           "deepseek",
				Label:        "DeepSeek",
				BaseURL:      "https://api.deepseek.com",
				DefaultModel: "deepseek-v4-flash",
				Enabled:      true,
			}, "")
			if providerErr != nil {
				log.Fatalf("seed DeepSeek provider: %v", providerErr)
			}
			if currentDefault, _ := store.GetSetting("default_provider"); currentDefault == "" {
				if settingErr := store.SetSetting("default_provider", provider.ID); settingErr != nil {
					log.Fatalf("set default DeepSeek provider: %v", settingErr)
				}
			}
		} else if deepseek.DefaultModel == "" || deepseek.DefaultModel == "deepseek-v4-pro" {
			deepseek.DefaultModel = "deepseek-v4-flash"
			if _, providerErr := store.UpsertProvider(*deepseek, ""); providerErr != nil {
				log.Fatalf("migrate DeepSeek default model: %v", providerErr)
			}
		}
	}
	if seed {
		for _, scope := range validScopes() {
			for _, locale := range []string{"zh-Hans", "en"} {
				prompt, _, _ := store.GetPrompt(scope, locale)
				if strings.TrimSpace(prompt) == "" ||
					prompt == legacyDefaultPromptV1(scope, locale) ||
					prompt == legacyDefaultPromptV2(scope, locale) ||
					(strings.HasPrefix(scope, "chart.") && prompt == legacyDefaultPromptV3(scope, locale)) {
					if _, err := store.UpsertPrompt(scope, locale, defaultPrompt(scope, locale)); err != nil {
						log.Printf("seed prompt %s/%s: %v", scope, locale, err)
					}
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
	cfg := &relayConfig{
		store:    store,
		sessions: sessions,
		client: &http.Client{
			Timeout: 180 * time.Second,
		},
		seed:           seed,
		dailyQuota:     envInt("RELAY_DAILY_GENERATION_QUOTA", 20),
		allowDevBypass: allowDevBypass,
		appAttest:      appAttest,
	}

	limiter := newRateLimiter(60, time.Minute)
	adminLimiter := newRateLimiter(10, time.Minute)
	attestLimiter := newRateLimiter(30, time.Minute)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleAdminPage)
	mux.HandleFunc("/xiaoguiwk", handleAdminPage)
	mux.HandleFunc("/xiaoguiwk/", handleAdminPage)
	mux.HandleFunc("/v1/health", cfg.handleHealth)
	if appAttest != nil {
		mux.HandleFunc("/v1/app-attest/challenge", attestLimiter.wrap(appAttest.handleChallenge))
		mux.HandleFunc("/v1/app-attest/attest", attestLimiter.wrap(appAttest.handleAttestation))
		mux.HandleFunc("/v1/app-attest/token", attestLimiter.wrap(appAttest.handleToken))
	}
	mux.HandleFunc("/v1/generate", limiter.wrap(cfg.handleGenerate))

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
