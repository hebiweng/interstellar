package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

// Store is the SQLite-backed configuration store for the relay. Keys are
// encrypted at rest with AES-256-GCM derived from RELAY_SECRET.
type Store struct {
	db     *sql.DB
	secret []byte
}

func OpenStore(path, secret string) (*Store, error) {
	if strings.TrimSpace(secret) == "" {
		return nil, errors.New("RELAY_SECRET must be set")
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	db.SetMaxOpenConns(1)
	s := &Store{db: db, secret: []byte(secret)}
	if err := s.migrate(); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS providers (
			id TEXT PRIMARY KEY,
			label TEXT NOT NULL,
			base_url TEXT NOT NULL,
			api_key_enc TEXT NOT NULL,
			default_model TEXT NOT NULL DEFAULT '',
			enabled INTEGER NOT NULL DEFAULT 1,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS prompt_templates (
			scope TEXT NOT NULL,
			locale TEXT NOT NULL,
			system_prompt TEXT NOT NULL,
			version INTEGER NOT NULL DEFAULT 1,
			updated_at TEXT NOT NULL,
			PRIMARY KEY (scope, locale)
		)`,
		`CREATE TABLE IF NOT EXISTS settings (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS usage_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			ts TEXT NOT NULL,
			scope TEXT NOT NULL,
			model TEXT NOT NULL,
			prompt_tokens INTEGER NOT NULL DEFAULT 0,
			completion_tokens INTEGER NOT NULL DEFAULT 0,
			ok INTEGER NOT NULL DEFAULT 1
		)`,
		`CREATE TABLE IF NOT EXISTS generation_cache (
			cache_key TEXT PRIMARY KEY,
			scope TEXT NOT NULL,
			payload TEXT NOT NULL,
			created_at TEXT NOT NULL,
			expires_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS admin_users (
			username TEXT PRIMARY KEY,
			password_hash TEXT NOT NULL,
			created_at TEXT NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS idx_usage_ts ON usage_log(ts)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	return nil
}

// ---- Provider CRUD ----

type Provider struct {
	ID           string `json:"id"`
	Label        string `json:"label"`
	BaseURL      string `json:"base_url"`
	APIKeySet    bool   `json:"api_key_set"`
	DefaultModel string `json:"default_model"`
	Enabled      bool   `json:"enabled"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
}

func (s *Store) ListProviders() ([]Provider, error) {
	rows, err := s.db.Query(`SELECT id, label, base_url, api_key_enc, default_model, enabled, created_at, updated_at FROM providers ORDER BY created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Provider
	for rows.Next() {
		var enc, def, created, updated string
		var enabled int
		p := Provider{}
		if err := rows.Scan(&p.ID, &p.Label, &p.BaseURL, &enc, &def, &enabled, &created, &updated); err != nil {
			return nil, err
		}
		p.APIKeySet = enc != ""
		p.DefaultModel = def
		p.Enabled = enabled == 1
		p.CreatedAt = created
		p.UpdatedAt = updated
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) GetProvider(id string) (*Provider, error) {
	p, err := s.ListProviders()
	if err != nil {
		return nil, err
	}
	for i := range p {
		if p[i].ID == id {
			return &p[i], nil
		}
	}
	return nil, errors.New("provider not found")
}

type ProviderSecret struct {
	Provider
	APIKey string
}

func (s *Store) GetProviderSecret(id string) (*ProviderSecret, error) {
	row := s.db.QueryRow(`SELECT id, label, base_url, api_key_enc, default_model, enabled, created_at, updated_at FROM providers WHERE id = ?`, id)
	var enc, def, created, updated string
	var enabled int
	p := &ProviderSecret{}
	if err := row.Scan(&p.ID, &p.Label, &p.BaseURL, &enc, &def, &enabled, &created, &updated); err != nil {
		return nil, err
	}
	p.APIKeySet = enc != ""
	p.DefaultModel = def
	p.Enabled = enabled == 1
	p.CreatedAt = created
	p.UpdatedAt = updated
	if enc != "" {
		key, err := s.decrypt(enc)
		if err != nil {
			return nil, err
		}
		p.APIKey = key
	}
	return p, nil
}

func (s *Store) UpsertProvider(p Provider, apiKey string) (Provider, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	enc := ""
	var err error
	if apiKey != "" {
		enc, err = s.encrypt(apiKey)
		if err != nil {
			return p, err
		}
	}
	existing, _ := s.GetProvider(p.ID)
	if existing != nil && enc == "" {
		// preserve the previously stored key
		secret, err := s.GetProviderSecret(p.ID)
		if err == nil {
			enc, _ = s.encrypt(secret.APIKey)
		}
	}
	enabled := 0
	if p.Enabled {
		enabled = 1
	}
	if existing == nil {
		_, err = s.db.Exec(
			`INSERT INTO providers (id, label, base_url, api_key_enc, default_model, enabled, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			p.ID, p.Label, p.BaseURL, enc, p.DefaultModel, enabled, now, now,
		)
	} else {
		_, err = s.db.Exec(
			`UPDATE providers SET label = ?, base_url = ?, api_key_enc = ?, default_model = ?, enabled = ?, updated_at = ? WHERE id = ?`,
			p.Label, p.BaseURL, enc, p.DefaultModel, enabled, now, p.ID,
		)
	}
	if err != nil {
		return p, err
	}
	secret, err := s.GetProviderSecret(p.ID)
	if err != nil {
		return p, err
	}
	return secret.Provider, nil
}

func (s *Store) DeleteProvider(id string) error {
	_, err := s.db.Exec(`DELETE FROM providers WHERE id = ?`, id)
	return err
}

// ---- Prompt templates ----

func (s *Store) ListPrompts() ([]map[string]any, error) {
	rows, err := s.db.Query(`SELECT scope, locale, system_prompt, version, updated_at FROM prompt_templates ORDER BY scope, locale`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var scope, locale, prompt, updated string
		var version int
		if err := rows.Scan(&scope, &locale, &prompt, &version, &updated); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"scope": scope, "locale": locale, "system_prompt": prompt,
			"version": version, "updated_at": updated,
		})
	}
	return out, rows.Err()
}

func (s *Store) GetPrompt(scope, locale string) (string, int, error) {
	var prompt string
	var version int
	err := s.db.QueryRow(`SELECT system_prompt, version FROM prompt_templates WHERE scope = ? AND locale = ?`, scope, locale).Scan(&prompt, &version)
	if errors.Is(err, sql.ErrNoRows) {
		return "", 0, nil
	}
	return prompt, version, err
}

func (s *Store) UpsertPrompt(scope, locale, prompt string) (int, error) {
	var version int
	err := s.db.QueryRow(`SELECT version FROM prompt_templates WHERE scope = ? AND locale = ?`, scope, locale).Scan(&version)
	if err != nil {
		version = 0
	}
	version++
	now := time.Now().UTC().Format(time.RFC3339)
	_, err = s.db.Exec(
		`INSERT INTO prompt_templates (scope, locale, system_prompt, version, updated_at)
		 VALUES (?, ?, ?, ?, ?)
		 ON CONFLICT(scope, locale) DO UPDATE SET system_prompt = excluded.system_prompt, version = excluded.version, updated_at = excluded.updated_at`,
		scope, locale, prompt, version, now,
	)
	return version, err
}

// ---- Settings ----

func (s *Store) GetSetting(key string) (string, error) {
	var value string
	err := s.db.QueryRow(`SELECT value FROM settings WHERE key = ?`, key).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return value, err
}

func (s *Store) SetSetting(key, value string) error {
	_, err := s.db.Exec(
		`INSERT INTO settings (key, value) VALUES (?, ?)
		 ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
		key, value,
	)
	return err
}

// ---- Usage ----

func (s *Store) RecordUsage(scope, model string, promptTokens, completionTokens int, ok bool) error {
	okInt := 0
	if ok {
		okInt = 1
	}
	_, err := s.db.Exec(
		`INSERT INTO usage_log (ts, scope, model, prompt_tokens, completion_tokens, ok) VALUES (?, ?, ?, ?, ?, ?)`,
		time.Now().UTC().Format(time.RFC3339), scope, model, promptTokens, completionTokens, okInt,
	)
	return err
}

func (s *Store) UsageSummary(days int) ([]map[string]any, error) {
	since := time.Now().UTC().AddDate(0, 0, -days).Format(time.RFC3339)
	rows, err := s.db.Query(
		`SELECT substr(ts, 1, 10) AS day, COUNT(*), COALESCE(SUM(prompt_tokens), 0), COALESCE(SUM(completion_tokens), 0)
		 FROM usage_log WHERE ts >= ? GROUP BY day ORDER BY day DESC LIMIT 90`,
		since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var day string
		var count, prompt, completion int
		if err := rows.Scan(&day, &count, &prompt, &completion); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"day": day, "requests": count, "prompt_tokens": prompt, "completion_tokens": completion,
		})
	}
	return out, rows.Err()
}

// ---- Generation cache ----

func (s *Store) CacheGet(key string) (string, bool, error) {
	var payload, expires string
	err := s.db.QueryRow(`SELECT payload, expires_at FROM generation_cache WHERE cache_key = ?`, key).Scan(&payload, &expires)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	expiresAt, err := time.Parse(time.RFC3339, expires)
	if err != nil || time.Now().UTC().After(expiresAt) {
		_, _ = s.db.Exec(`DELETE FROM generation_cache WHERE cache_key = ?`, key)
		return "", false, nil
	}
	return payload, true, nil
}

func (s *Store) CachePut(key, scope, payload string, ttl time.Duration) error {
	now := time.Now().UTC()
	expires := now.Add(ttl).Format(time.RFC3339)
	_, err := s.db.Exec(
		`INSERT INTO generation_cache (cache_key, scope, payload, created_at, expires_at)
		 VALUES (?, ?, ?, ?, ?)
		 ON CONFLICT(cache_key) DO UPDATE SET payload = excluded.payload, expires_at = excluded.expires_at`,
		key, scope, payload, now.Format(time.RFC3339), expires,
	)
	return err
}

func (s *Store) CacheClear(scope string) (int64, error) {
	res, err := s.db.Exec(`DELETE FROM generation_cache WHERE scope = ?`, scope)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// ---- Admin users ----

func (s *Store) PasswordHash(password string) string {
	mac := hmac.New(sha256.New, s.secret)
	mac.Write([]byte("admin-password:" + password))
	return hex.EncodeToString(mac.Sum(nil))
}

func (s *Store) EnsureAdmin(username, password string) error {
	if username == "" || password == "" {
		return errors.New("RELAY_ADMIN_USER and RELAY_ADMIN_PASS must be set on first run")
	}
	var count int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM admin_users WHERE username = ?`, username).Scan(&count)
	if count > 0 {
		return nil
	}
	_, err := s.db.Exec(
		`INSERT INTO admin_users (username, password_hash, created_at) VALUES (?, ?, ?)`,
		username, s.PasswordHash(password), time.Now().UTC().Format(time.RFC3339),
	)
	return err
}

func (s *Store) VerifyAdmin(username, password string) bool {
	var hash string
	err := s.db.QueryRow(`SELECT password_hash FROM admin_users WHERE username = ?`, username).Scan(&hash)
	if err != nil {
		return false
	}
	return hmac.Equal([]byte(hash), []byte(s.PasswordHash(password)))
}

// ---- Encryption ----

func (s *Store) aesKey() []byte {
	sum := sha256.Sum256([]byte("relay-key:" + string(s.secret)))
	return sum[:]
}

func (s *Store) encrypt(plain string) (string, error) {
	block, err := aes.NewCipher(s.aesKey())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	sealed := gcm.Seal(nil, nonce, []byte(plain), nil)
	return base64.StdEncoding.EncodeToString(append(nonce, sealed...)), nil
}

func (s *Store) decrypt(encoded string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(s.aesKey())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonceSize := gcm.NonceSize()
	if len(raw) < nonceSize {
		return "", errors.New("invalid ciphertext")
	}
	plain, err := gcm.Open(nil, raw[:nonceSize], raw[nonceSize:], nil)
	if err != nil {
		return "", err
	}
	return string(plain), nil
}

// ---- Misc ----

func JSONMarshal(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}
