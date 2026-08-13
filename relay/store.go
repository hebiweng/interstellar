package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

// Store is the SQLite-backed configuration store for the relay. Keys are
// encrypted at rest with AES-256-GCM derived from RELAY_SECRET.
type Store struct {
	db     *sql.DB
	secret []byte
}

func OpenStore(path, secret string) (*Store, error) {
	if len([]byte(strings.TrimSpace(secret))) < 32 {
		return nil, errors.New("RELAY_SECRET must contain at least 32 bytes")
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
		`CREATE TABLE IF NOT EXISTS provider_models (
			provider_id TEXT NOT NULL,
			model_id TEXT NOT NULL,
			enabled INTEGER NOT NULL DEFAULT 1,
			updated_at TEXT NOT NULL,
			PRIMARY KEY (provider_id, model_id)
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
		`CREATE TABLE IF NOT EXISTS feedback (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			type TEXT NOT NULL,
			content_enc TEXT NOT NULL,
			contact_enc TEXT NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS admin_users (
			username TEXT PRIMARY KEY,
			password_hash TEXT NOT NULL,
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS admin_sessions (
			token_hash TEXT PRIMARY KEY,
			username TEXT NOT NULL,
			created_at TEXT NOT NULL,
			expires_at TEXT NOT NULL,
			revoked_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS admin_audit (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			ts TEXT NOT NULL,
			username TEXT NOT NULL,
			action TEXT NOT NULL,
			target TEXT NOT NULL,
			metadata TEXT NOT NULL DEFAULT '{}'
		)`,
		`CREATE TABLE IF NOT EXISTS installation_usage (
			installation_hash TEXT NOT NULL,
			day TEXT NOT NULL,
			requests INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY (installation_hash, day)
		)`,
		`CREATE TABLE IF NOT EXISTS app_attest_challenges (
			challenge_id TEXT PRIMARY KEY,
			installation_hash TEXT NOT NULL,
			key_id TEXT NOT NULL DEFAULT '',
			purpose TEXT NOT NULL,
			body_hash TEXT NOT NULL DEFAULT '',
			challenge_enc TEXT NOT NULL,
			created_at TEXT NOT NULL,
			expires_at TEXT NOT NULL,
			used_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS app_attest_keys (
			key_id TEXT PRIMARY KEY,
			installation_hash TEXT NOT NULL UNIQUE,
			public_key_der BLOB NOT NULL,
			receipt_enc TEXT NOT NULL,
			sign_count INTEGER NOT NULL DEFAULT 0,
			environment TEXT NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS app_attest_tokens (
			token_hash TEXT PRIMARY KEY,
			installation_hash TEXT NOT NULL,
			key_id TEXT NOT NULL,
			created_at TEXT NOT NULL,
			expires_at TEXT NOT NULL,
			revoked_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS commerce_users (
			user_id TEXT PRIMARY KEY,
			created_at TEXT NOT NULL,
			last_active_at TEXT NOT NULL,
			admin_plan_override TEXT,
			admin_premium_started_at TEXT,
			admin_premium_expires_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS user_installations (
			installation_hash TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			linked_at TEXT NOT NULL,
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS subscriptions (
			user_id TEXT PRIMARY KEY,
			product_id TEXT NOT NULL,
			status TEXT NOT NULL,
			original_transaction_id TEXT NOT NULL,
			started_at TEXT NOT NULL,
			expires_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS store_transactions (
			transaction_id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			original_transaction_id TEXT NOT NULL,
			product_id TEXT NOT NULL,
			purchased_at TEXT NOT NULL,
			revoked_at TEXT,
			jws_hash TEXT NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS credit_grants (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT NOT NULL,
			source TEXT NOT NULL,
			original_amount INTEGER NOT NULL,
			remaining_amount INTEGER NOT NULL,
			granted_at TEXT NOT NULL,
			expires_at TEXT,
			period_key TEXT,
			apple_transaction_id TEXT,
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id),
			UNIQUE(user_id, source, period_key),
			UNIQUE(apple_transaction_id)
		)`,
		`CREATE TABLE IF NOT EXISTS credit_reservations (
			user_id TEXT NOT NULL,
			request_id TEXT NOT NULL,
			report_id TEXT NOT NULL,
			request_hash TEXT NOT NULL,
			state TEXT NOT NULL,
			allocations_json TEXT NOT NULL,
			created_at TEXT NOT NULL,
			expires_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			PRIMARY KEY(user_id, request_id),
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS credit_ledger (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT NOT NULL,
			request_id TEXT,
			grant_id INTEGER,
			action TEXT NOT NULL,
			delta INTEGER NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE TABLE IF NOT EXISTS report_requests (
			user_id TEXT NOT NULL,
			request_id TEXT NOT NULL,
			report_id TEXT NOT NULL,
			request_hash TEXT NOT NULL,
			scope TEXT NOT NULL,
			requested_locale TEXT NOT NULL,
			effective_locale TEXT NOT NULL,
			model TEXT NOT NULL DEFAULT '',
			credit_cost INTEGER NOT NULL DEFAULT 1,
			report_status TEXT NOT NULL,
			credit_status TEXT NOT NULL,
			prompt_tokens INTEGER NOT NULL DEFAULT 0,
			completion_tokens INTEGER NOT NULL DEFAULT 0,
			reasoning_tokens INTEGER NOT NULL DEFAULT 0,
			duration_ms INTEGER NOT NULL DEFAULT 0,
			error_code TEXT NOT NULL DEFAULT '',
			error_message TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			delivered_at TEXT,
			PRIMARY KEY(user_id, request_id),
			FOREIGN KEY(user_id) REFERENCES commerce_users(user_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_usage_ts ON usage_log(ts)`,
		`CREATE INDEX IF NOT EXISTS idx_feedback_status_created ON feedback(status, created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_feedback_type_created ON feedback(type, created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_provider_models_provider ON provider_models(provider_id)`,
		`CREATE INDEX IF NOT EXISTS idx_admin_sessions_expiry ON admin_sessions(expires_at)`,
		`CREATE INDEX IF NOT EXISTS idx_admin_audit_ts ON admin_audit(ts)`,
		`CREATE INDEX IF NOT EXISTS idx_app_attest_challenge_expiry ON app_attest_challenges(expires_at)`,
		`CREATE INDEX IF NOT EXISTS idx_app_attest_token_expiry ON app_attest_tokens(expires_at)`,
		`CREATE INDEX IF NOT EXISTS idx_credit_grants_user_expiry ON credit_grants(user_id, expires_at)`,
		`CREATE INDEX IF NOT EXISTS idx_reports_created ON report_requests(created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_reports_user_created ON report_requests(user_id, created_at DESC)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	if err := ensureSQLiteColumn(s.db, "report_requests", "credit_cost", "INTEGER NOT NULL DEFAULT 1"); err != nil {
		return fmt.Errorf("migrate report credit cost: %w", err)
	}
	if err := ensureSQLiteColumn(s.db, "commerce_users", "admin_plan_override", "TEXT"); err != nil {
		return fmt.Errorf("migrate admin plan override: %w", err)
	}
	if err := ensureSQLiteColumn(s.db, "commerce_users", "country_code", "TEXT NOT NULL DEFAULT ''"); err != nil {
		return fmt.Errorf("migrate commerce country code: %w", err)
	}
	// Report bodies are client-only. Remove the legacy cache table entirely so
	// no current code path can retain a generated report on Relay.
	if _, err := s.db.Exec(`DROP TABLE IF EXISTS generation_cache`); err != nil {
		return fmt.Errorf("drop legacy generation cache: %w", err)
	}
	hasLegacyReportBody, err := sqliteColumnExists(s.db, "report_requests", "payload_enc")
	if err != nil {
		return fmt.Errorf("inspect legacy report bodies: %w", err)
	}
	if hasLegacyReportBody {
		if _, err := s.db.Exec(`UPDATE report_requests SET payload_enc=NULL WHERE payload_enc IS NOT NULL`); err != nil {
			return fmt.Errorf("clear legacy report bodies: %w", err)
		}
		if _, err := s.db.Exec(`ALTER TABLE report_requests DROP COLUMN payload_enc`); err != nil {
			return fmt.Errorf("remove legacy report body column: %w", err)
		}
	}
	return nil
}

func sqliteColumnExists(db *sql.DB, table, column string) (bool, error) {
	rows, err := db.Query(`PRAGMA table_info(` + table + `)`)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, kind string
		var notNull, primaryKey int
		var defaultValue sql.NullString
		if err := rows.Scan(&cid, &name, &kind, &notNull, &defaultValue, &primaryKey); err != nil {
			return false, err
		}
		if name == column {
			return true, nil
		}
	}
	return false, rows.Err()
}

func ensureSQLiteColumn(db *sql.DB, table, column, declaration string) error {
	rows, err := db.Query(`PRAGMA table_info(` + table + `)`)
	if err != nil {
		return err
	}
	found := false
	for rows.Next() {
		var cid int
		var name, kind string
		var notNull, primaryKey int
		var defaultValue sql.NullString
		if err := rows.Scan(&cid, &name, &kind, &notNull, &defaultValue, &primaryKey); err != nil {
			rows.Close()
			return err
		}
		if name == column {
			found = true
		}
	}
	if err := rows.Close(); err != nil {
		return err
	}
	if found {
		return nil
	}
	_, err = db.Exec(`ALTER TABLE ` + table + ` ADD COLUMN ` + column + ` ` + declaration)
	return err
}

// ---- User feedback ----

type Feedback struct {
	ID        int64  `json:"id"`
	Type      string `json:"type"`
	Content   string `json:"content"`
	Contact   string `json:"contact,omitempty"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
}

func (s *Store) SaveFeedback(feedbackType, content, contact string) (Feedback, error) {
	feedbackType = strings.TrimSpace(feedbackType)
	if feedbackType != "bug" && feedbackType != "feature" && feedbackType != "other" {
		feedbackType = "other"
	}
	content = strings.TrimSpace(content)
	contact = strings.TrimSpace(contact)
	if content == "" || len([]rune(content)) > 5000 {
		return Feedback{}, errors.New("feedback content must contain 1 to 5000 characters")
	}
	if len([]rune(contact)) > 160 {
		return Feedback{}, errors.New("feedback contact must not exceed 160 characters")
	}
	contentEnc, err := s.encrypt(content)
	if err != nil {
		return Feedback{}, err
	}
	contactEnc, err := s.encrypt(contact)
	if err != nil {
		return Feedback{}, err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.Exec(
		`INSERT INTO feedback (type, content_enc, contact_enc, status, created_at, updated_at)
		 VALUES (?, ?, ?, 'pending', ?, ?)`,
		feedbackType, contentEnc, contactEnc, now, now,
	)
	if err != nil {
		return Feedback{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Feedback{}, err
	}
	return Feedback{ID: id, Type: feedbackType, Content: content, Contact: contact, Status: "pending", CreatedAt: now, UpdatedAt: now}, nil
}

func (s *Store) ListFeedback(status, feedbackType string, limit int) ([]Feedback, error) {
	if limit < 1 || limit > 200 {
		limit = 100
	}
	clauses := []string{"1 = 1"}
	args := []any{}
	if status == "pending" || status == "resolved" {
		clauses = append(clauses, "status = ?")
		args = append(args, status)
	}
	if feedbackType == "bug" || feedbackType == "feature" || feedbackType == "other" {
		clauses = append(clauses, "type = ?")
		args = append(args, feedbackType)
	}
	args = append(args, limit)
	rows, err := s.db.Query(
		`SELECT id, type, content_enc, contact_enc, status, created_at, updated_at
		 FROM feedback WHERE `+strings.Join(clauses, " AND ")+` ORDER BY created_at DESC LIMIT ?`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var feedback []Feedback
	for rows.Next() {
		var item Feedback
		var contentEnc, contactEnc string
		if err := rows.Scan(&item.ID, &item.Type, &contentEnc, &contactEnc, &item.Status, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		item.Content, err = s.decrypt(contentEnc)
		if err != nil {
			return nil, err
		}
		item.Contact, err = s.decrypt(contactEnc)
		if err != nil {
			return nil, err
		}
		feedback = append(feedback, item)
	}
	return feedback, rows.Err()
}

func (s *Store) UpdateFeedbackStatus(id int64, status string) (Feedback, error) {
	if status != "pending" && status != "resolved" {
		return Feedback{}, errors.New("feedback status must be pending or resolved")
	}
	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.Exec(`UPDATE feedback SET status = ?, updated_at = ? WHERE id = ?`, status, now, id)
	if err != nil {
		return Feedback{}, err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return Feedback{}, err
	}
	if changed == 0 {
		return Feedback{}, sql.ErrNoRows
	}
	return s.feedbackByID(id)
}

func (s *Store) feedbackByID(id int64) (Feedback, error) {
	var item Feedback
	var contentEnc, contactEnc string
	err := s.db.QueryRow(
		`SELECT id, type, content_enc, contact_enc, status, created_at, updated_at
		 FROM feedback WHERE id = ?`,
		id,
	).Scan(&item.ID, &item.Type, &contentEnc, &contactEnc, &item.Status, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		return Feedback{}, err
	}
	item.Content, err = s.decrypt(contentEnc)
	if err != nil {
		return Feedback{}, err
	}
	item.Contact, err = s.decrypt(contactEnc)
	return item, err
}

// ---- Provider CRUD ----

type Provider struct {
	ID           string `json:"id"`
	Label        string `json:"label"`
	BaseURL      string `json:"base_url"`
	APIKeySet    bool   `json:"api_key_set"`
	DefaultModel string `json:"default_model"`
	Enabled      bool   `json:"enabled"`
	IsDefault    bool   `json:"is_default"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
}

func (s *Store) ListProviders() ([]Provider, error) {
	defaultProvider, _ := s.GetSetting("default_provider")
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
		p.IsDefault = p.ID == defaultProvider
		p.CreatedAt = created
		p.UpdatedAt = updated
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) GetGenerationProvider() (*ProviderSecret, error) {
	id, err := s.GetSetting("default_provider")
	if err != nil {
		return nil, err
	}
	if id != "" {
		provider, err := s.GetProviderSecret(id)
		if err != nil {
			return nil, err
		}
		if !provider.Enabled {
			return nil, errors.New("default provider is disabled")
		}
		if provider.APIKey == "" {
			return nil, errors.New("default provider has no API key")
		}
		return provider, nil
	}
	var firstID string
	err = s.db.QueryRow(`SELECT id FROM providers WHERE enabled = 1 AND api_key_enc != '' ORDER BY created_at LIMIT 1`).Scan(&firstID)
	if err != nil {
		return nil, errors.New("no enabled provider configured")
	}
	return s.GetProviderSecret(firstID)
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
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM providers WHERE id = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM provider_models WHERE provider_id = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM settings WHERE key = 'default_provider' AND value = ?`, id); err != nil {
		return err
	}
	return tx.Commit()
}

type ProviderModel struct {
	ID        string `json:"id"`
	Enabled   bool   `json:"enabled"`
	IsDefault bool   `json:"is_default"`
}

func (s *Store) SyncProviderModels(providerID string, modelIDs []string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, modelID := range modelIDs {
		modelID = strings.TrimSpace(modelID)
		if modelID == "" {
			continue
		}
		if _, err := tx.Exec(
			`INSERT INTO provider_models (provider_id, model_id, enabled, updated_at)
			 VALUES (?, ?, 1, ?)
			 ON CONFLICT(provider_id, model_id) DO UPDATE SET updated_at = excluded.updated_at`,
			providerID, modelID, now,
		); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) ListProviderModels(providerID, defaultModel string) ([]ProviderModel, error) {
	rows, err := s.db.Query(
		`SELECT model_id, enabled FROM provider_models WHERE provider_id = ? ORDER BY model_id`,
		providerID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var models []ProviderModel
	for rows.Next() {
		var model ProviderModel
		var enabled int
		if err := rows.Scan(&model.ID, &enabled); err != nil {
			return nil, err
		}
		model.Enabled = enabled == 1
		model.IsDefault = model.ID == defaultModel
		models = append(models, model)
	}
	return models, rows.Err()
}

func (s *Store) SetProviderModelEnabled(providerID, modelID string, enabled bool) error {
	if strings.TrimSpace(providerID) == "" || strings.TrimSpace(modelID) == "" {
		return errors.New("provider and model are required")
	}
	value := 0
	if enabled {
		value = 1
	}
	_, err := s.db.Exec(
		`INSERT INTO provider_models (provider_id, model_id, enabled, updated_at)
		 VALUES (?, ?, ?, ?)
		 ON CONFLICT(provider_id, model_id) DO UPDATE SET enabled = excluded.enabled, updated_at = excluded.updated_at`,
		providerID, modelID, value, time.Now().UTC().Format(time.RFC3339),
	)
	return err
}

func (s *Store) IsProviderModelEnabled(providerID, modelID string) (bool, error) {
	var enabled int
	err := s.db.QueryRow(
		`SELECT enabled FROM provider_models WHERE provider_id = ? AND model_id = ?`,
		providerID, modelID,
	).Scan(&enabled)
	if errors.Is(err, sql.ErrNoRows) {
		// A configured default can be used immediately before the optional model
		// discovery endpoint has been called. Once explicitly disabled, the row
		// exists and generation is blocked.
		return true, nil
	}
	return enabled == 1, err
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
		`SELECT substr(ts, 1, 10) AS day, model, COUNT(*), COALESCE(SUM(ok), 0),
		        COALESCE(SUM(prompt_tokens), 0), COALESCE(SUM(completion_tokens), 0)
		 FROM usage_log WHERE ts >= ? GROUP BY day, model ORDER BY day DESC, model LIMIT 180`,
		since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var day, model string
		var count, successes, prompt, completion int
		if err := rows.Scan(&day, &model, &count, &successes, &prompt, &completion); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"day": day, "model": model, "requests": count, "successes": successes,
			"errors":        count - successes,
			"success_rate":  float64(successes) / float64(count),
			"prompt_tokens": prompt, "completion_tokens": completion,
		})
	}
	return out, rows.Err()
}

// ---- Admin users ----

func (s *Store) PasswordHash(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(hash), err
}

func (s *Store) EnsureAdmin(username, password string) error {
	if username == "" || password == "" {
		return errors.New("RELAY_ADMIN_USER and RELAY_ADMIN_PASS must be set on first run")
	}
	if len([]byte(password)) < 24 {
		return errors.New("RELAY_ADMIN_PASS must contain at least 24 bytes")
	}
	var count int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM admin_users WHERE username = ?`, username).Scan(&count)
	if count > 0 {
		var current string
		if err := s.db.QueryRow(`SELECT password_hash FROM admin_users WHERE username = ?`, username).Scan(&current); err != nil {
			return err
		}
		if strings.HasPrefix(current, "$2") {
			return nil
		}
		hash, err := s.PasswordHash(password)
		if err != nil {
			return err
		}
		_, err = s.db.Exec(`UPDATE admin_users SET password_hash = ? WHERE username = ?`, hash, username)
		return err
	}
	hash, err := s.PasswordHash(password)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(
		`INSERT INTO admin_users (username, password_hash, created_at) VALUES (?, ?, ?)`,
		username, hash, time.Now().UTC().Format(time.RFC3339),
	)
	return err
}

func (s *Store) DeleteOtherAdmins(keepUsername string) (int64, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM admin_sessions WHERE username != ?`, keepUsername); err != nil {
		return 0, err
	}
	result, err := tx.Exec(`DELETE FROM admin_users WHERE username != ?`, keepUsername)
	if err != nil {
		return 0, err
	}
	removed, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}
	return removed, tx.Commit()
}

func (s *Store) VerifyAdmin(username, password string) bool {
	var hash string
	err := s.db.QueryRow(`SELECT password_hash FROM admin_users WHERE username = ?`, username).Scan(&hash)
	if err != nil {
		return false
	}
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

// ---- Persistent admin sessions and redacted audit ----

func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

func (s *Store) CreateAdminSession(username string, ttl time.Duration) (string, time.Time, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", time.Time{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	now := time.Now().UTC()
	expires := now.Add(ttl)
	_, err := s.db.Exec(
		`INSERT INTO admin_sessions (token_hash, username, created_at, expires_at) VALUES (?, ?, ?, ?)`,
		tokenHash(token), username, now.Format(time.RFC3339), expires.Format(time.RFC3339),
	)
	return token, expires, err
}

func (s *Store) ValidateAdminSession(token string) (string, bool) {
	if token == "" {
		return "", false
	}
	var username, expires string
	err := s.db.QueryRow(
		`SELECT username, expires_at FROM admin_sessions WHERE token_hash = ? AND revoked_at IS NULL`,
		tokenHash(token),
	).Scan(&username, &expires)
	if err != nil {
		return "", false
	}
	expiresAt, err := time.Parse(time.RFC3339, expires)
	if err != nil || time.Now().UTC().After(expiresAt) {
		_, _ = s.db.Exec(`DELETE FROM admin_sessions WHERE token_hash = ?`, tokenHash(token))
		return "", false
	}
	return username, true
}

func (s *Store) RevokeAdminSession(token string) {
	_, _ = s.db.Exec(
		`UPDATE admin_sessions SET revoked_at = ? WHERE token_hash = ?`,
		time.Now().UTC().Format(time.RFC3339), tokenHash(token),
	)
}

func (s *Store) RecordAudit(username, action, target string, metadata map[string]any) error {
	encoded := JSONMarshal(metadata)
	_, err := s.db.Exec(
		`INSERT INTO admin_audit (ts, username, action, target, metadata) VALUES (?, ?, ?, ?, ?)`,
		time.Now().UTC().Format(time.RFC3339), username, action, target, encoded,
	)
	return err
}

func (s *Store) ConsumeInstallationQuota(installationID string, dailyLimit int) (int, bool, error) {
	if dailyLimit <= 0 {
		return 0, true, nil
	}
	day := time.Now().UTC().Format("2006-01-02")
	hash := tokenHash(installationID)
	_, err := s.db.Exec(
		`INSERT INTO installation_usage (installation_hash, day, requests) VALUES (?, ?, 1)
		 ON CONFLICT(installation_hash, day) DO UPDATE SET requests = requests + 1`,
		hash, day,
	)
	if err != nil {
		return 0, false, err
	}
	var count int
	if err := s.db.QueryRow(
		`SELECT requests FROM installation_usage WHERE installation_hash = ? AND day = ?`, hash, day,
	).Scan(&count); err != nil {
		return 0, false, err
	}
	return count, count <= dailyLimit, nil
}

// ---- App Attest challenges, attested keys, and short-lived installation tokens ----

type AppAttestKey struct {
	KeyID            string
	InstallationHash string
	PublicKeyDER     []byte
	SignCount        uint32
	Environment      string
}

func randomURLToken(size int) (string, error) {
	raw := make([]byte, size)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

func (s *Store) CreateAppAttestChallenge(installationID, keyID, purpose, bodyHash string, ttl time.Duration) (string, []byte, time.Time, error) {
	challenge := make([]byte, 32)
	if _, err := rand.Read(challenge); err != nil {
		return "", nil, time.Time{}, err
	}
	challengeID, err := randomURLToken(24)
	if err != nil {
		return "", nil, time.Time{}, err
	}
	encrypted, err := s.encrypt(base64.StdEncoding.EncodeToString(challenge))
	if err != nil {
		return "", nil, time.Time{}, err
	}
	now := time.Now().UTC()
	expires := now.Add(ttl)
	_, _ = s.db.Exec(`DELETE FROM app_attest_challenges WHERE expires_at < ? OR used_at IS NOT NULL`, now.Format(time.RFC3339))
	_, err = s.db.Exec(
		`INSERT INTO app_attest_challenges
		 (challenge_id, installation_hash, key_id, purpose, body_hash, challenge_enc, created_at, expires_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		challengeID, tokenHash(installationID), keyID, purpose, bodyHash, encrypted,
		now.Format(time.RFC3339), expires.Format(time.RFC3339),
	)
	return challengeID, challenge, expires, err
}

func (s *Store) ConsumeAppAttestChallenge(challengeID, installationID, keyID, purpose, bodyHash string) ([]byte, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	var encrypted, expires string
	err = tx.QueryRow(
		`SELECT challenge_enc, expires_at FROM app_attest_challenges
		 WHERE challenge_id = ? AND installation_hash = ? AND key_id = ? AND purpose = ?
		   AND body_hash = ? AND used_at IS NULL`,
		challengeID, tokenHash(installationID), keyID, purpose, bodyHash,
	).Scan(&encrypted, &expires)
	if err != nil {
		return nil, errors.New("challenge not found or already used")
	}
	expiresAt, err := time.Parse(time.RFC3339, expires)
	if err != nil || time.Now().UTC().After(expiresAt) {
		return nil, errors.New("challenge expired")
	}
	result, err := tx.Exec(
		`UPDATE app_attest_challenges SET used_at = ? WHERE challenge_id = ? AND used_at IS NULL`,
		time.Now().UTC().Format(time.RFC3339), challengeID,
	)
	if err != nil {
		return nil, err
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		return nil, errors.New("challenge already used")
	}
	plain, err := s.decrypt(encrypted)
	if err != nil {
		return nil, err
	}
	challenge, err := base64.StdEncoding.DecodeString(plain)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return challenge, nil
}

func (s *Store) SaveAppAttestKey(key AppAttestKey, installationID string, receipt []byte) error {
	receiptEnc, err := s.encrypt(base64.StdEncoding.EncodeToString(receipt))
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	installationHash := tokenHash(installationID)
	if _, err := tx.Exec(
		`UPDATE app_attest_tokens SET revoked_at = ? WHERE installation_hash = ? AND revoked_at IS NULL`,
		now, installationHash,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(
		`DELETE FROM app_attest_keys WHERE installation_hash = ? AND key_id != ?`,
		installationHash, key.KeyID,
	); err != nil {
		return err
	}
	_, err = tx.Exec(
		`INSERT INTO app_attest_keys
		 (key_id, installation_hash, public_key_der, receipt_enc, sign_count, environment, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(key_id) DO UPDATE SET
		 installation_hash = excluded.installation_hash, public_key_der = excluded.public_key_der,
		 receipt_enc = excluded.receipt_enc, sign_count = excluded.sign_count,
		 environment = excluded.environment, updated_at = excluded.updated_at`,
		key.KeyID, installationHash, key.PublicKeyDER, receiptEnc, key.SignCount,
		key.Environment, now, now,
	)
	if err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) GetAppAttestKey(keyID, installationID string) (AppAttestKey, error) {
	var key AppAttestKey
	var count int64
	err := s.db.QueryRow(
		`SELECT key_id, installation_hash, public_key_der, sign_count, environment
		 FROM app_attest_keys WHERE key_id = ? AND installation_hash = ?`,
		keyID, tokenHash(installationID),
	).Scan(&key.KeyID, &key.InstallationHash, &key.PublicKeyDER, &count, &key.Environment)
	key.SignCount = uint32(count)
	return key, err
}

func (s *Store) UpdateAppAttestCounter(keyID, installationID string, previous, next uint32) error {
	result, err := s.db.Exec(
		`UPDATE app_attest_keys SET sign_count = ?, updated_at = ?
		 WHERE key_id = ? AND installation_hash = ? AND sign_count = ?`,
		next, time.Now().UTC().Format(time.RFC3339), keyID, tokenHash(installationID), previous,
	)
	if err != nil {
		return err
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		return errors.New("assertion counter replayed")
	}
	return nil
}

func (s *Store) CreateAppAttestToken(keyID, installationID string, ttl time.Duration) (string, time.Time, error) {
	token, err := randomURLToken(32)
	if err != nil {
		return "", time.Time{}, err
	}
	now := time.Now().UTC()
	expires := now.Add(ttl)
	_, _ = s.db.Exec(`DELETE FROM app_attest_tokens WHERE expires_at < ?`, now.Format(time.RFC3339))
	_, err = s.db.Exec(
		`INSERT INTO app_attest_tokens
		 (token_hash, installation_hash, key_id, created_at, expires_at)
		 VALUES (?, ?, ?, ?, ?)`,
		tokenHash(token), tokenHash(installationID), keyID,
		now.Format(time.RFC3339), expires.Format(time.RFC3339),
	)
	return token, expires, err
}

func (s *Store) ValidateAppAttestToken(token, keyID, installationID string) bool {
	if token == "" {
		return false
	}
	var expires string
	err := s.db.QueryRow(
		`SELECT expires_at FROM app_attest_tokens
		 WHERE token_hash = ? AND key_id = ? AND installation_hash = ? AND revoked_at IS NULL`,
		tokenHash(token), keyID, tokenHash(installationID),
	).Scan(&expires)
	if err != nil {
		return false
	}
	expiresAt, err := time.Parse(time.RFC3339, expires)
	return err == nil && time.Now().UTC().Before(expiresAt)
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
