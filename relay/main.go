package main

import (
	"log"
	"net/http"
	"os"
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
	adminUser := envOr("RELAY_ADMIN_USER", "admin")
	adminPass := os.Getenv("RELAY_ADMIN_PASS")

	store, err := OpenStore(dbPath, secret)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	defer store.Close()

	seed := os.Getenv("RELAY_SEED_PROMPTS") == "1"
	if seed {
		for _, scope := range validScopes() {
			for _, locale := range []string{"zh-Hans", "en"} {
				if prompt, _, _ := store.GetPrompt(scope, locale); strings.TrimSpace(prompt) == "" {
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

	sessions := NewSessionStore(secret)
	cfg := &relayConfig{
		store:    store,
		sessions: sessions,
		client: &http.Client{
			Timeout: 180 * time.Second,
		},
		seed: true,
	}

	limiter := newRateLimiter(60, time.Minute)
	adminLimiter := newRateLimiter(10, time.Minute)

	mux := http.NewServeMux()
	mux.HandleFunc("/v1/health", cfg.handleHealth)
	mux.HandleFunc("/v1/generate", limiter.wrap(cfg.handleGenerate))

	// Admin API
	mux.HandleFunc("/admin/login", adminLimiter.wrap(cfg.handleLogin))
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
	mux.Handle("/admin/usage", requireAdmin(sessions, cfg.handleUsage))

	log.Printf("relay listening on %s", addr)
	server := &http.Server{
		Addr:              addr,
		Handler:           cors(mux),
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

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ---- Simple in-memory rate limiter (token bucket per client IP) ----

type rateLimiter struct {
	mu      sync.Mutex
	limit   int
	window  time.Duration
	clients map[string]*bucket
}

type bucket struct {
	count    int
	resetAt  time.Time
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
