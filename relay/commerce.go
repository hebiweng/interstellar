package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
)

const (
	creditReservationTTL = 6 * time.Minute
	freeAllowance        = 2
	premiumAllowance     = 10
)

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$`)

type CreditBalance struct {
	Allowance int `json:"allowance"`
	Bonus     int `json:"bonus"`
	Purchased int `json:"purchased"`
	Reserved  int `json:"reserved"`
	Total     int `json:"total"`
}

type CommerceUser struct {
	UserID                  string               `json:"userID"`
	CreatedAt               string               `json:"createdAt"`
	LastActiveAt            string               `json:"lastActiveAt"`
	Plan                    string               `json:"plan"`
	PremiumExpiresAt        string               `json:"premiumExpiresAt,omitempty"`
	AdminPremiumExpiresAt   string               `json:"adminPremiumExpiresAt,omitempty"`
	AppleProductID          string               `json:"appleProductID,omitempty"`
	AppleSubscriptionStatus string               `json:"appleSubscriptionStatus,omitempty"`
	ApplePremiumExpiresAt   string               `json:"applePremiumExpiresAt,omitempty"`
	Credits                 CreditBalance        `json:"credits"`
	ReportsGenerated        int                  `json:"reportsGenerated"`
	CreditGrants            []CreditGrantSummary `json:"creditGrants,omitempty"`
}

type CreditGrantSummary struct {
	ID        int64  `json:"id"`
	Source    string `json:"source"`
	Original  int    `json:"original"`
	Remaining int    `json:"remaining"`
	GrantedAt string `json:"grantedAt"`
	ExpiresAt string `json:"expiresAt,omitempty"`
}

type ReportRequestRecord struct {
	UserID           string `json:"userID"`
	RequestID        string `json:"requestID"`
	ReportID         string `json:"reportID"`
	RequestHash      string `json:"-"`
	Scope            string `json:"chartType"`
	RequestedLocale  string `json:"requestedLocale"`
	EffectiveLocale  string `json:"effectiveLocale"`
	Model            string `json:"model"`
	ReportStatus     string `json:"reportStatus"`
	CreditStatus     string `json:"creditStatus"`
	CreditCost       int    `json:"creditCost"`
	PromptTokens     int    `json:"inputTokens"`
	CompletionTokens int    `json:"outputTokens"`
	ReasoningTokens  int    `json:"reasoningTokens"`
	DurationMS       int    `json:"durationMs"`
	ErrorCode        string `json:"errorCode,omitempty"`
	ErrorMessage     string `json:"errorMessage,omitempty"`
	CreatedAt        string `json:"createdAt"`
	UpdatedAt        string `json:"updatedAt"`
	DeliveredAt      string `json:"deliveredAt,omitempty"`
}

type creditAllocation struct {
	GrantID int64 `json:"grantID"`
	Amount  int   `json:"amount"`
}

func validCommerceID(value string) bool {
	return uuidPattern.MatchString(strings.TrimSpace(value))
}

func requestDigest(body []byte) string {
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func (s *Store) SyncCommerceUser(userID, installationID string) (CommerceUser, error) {
	if !validCommerceID(userID) || strings.TrimSpace(installationID) == "" {
		return CommerceUser{}, errors.New("valid userID and installationID are required")
	}
	tx, err := s.db.Begin()
	if err != nil {
		return CommerceUser{}, err
	}
	defer tx.Rollback()
	now := time.Now().UTC()
	if err := ensureCommerceUserTx(tx, userID, installationID, now); err != nil {
		return CommerceUser{}, err
	}
	if _, err := refillAllowanceTx(tx, userID, now); err != nil {
		return CommerceUser{}, err
	}
	if err := tx.Commit(); err != nil {
		return CommerceUser{}, err
	}
	return s.GetCommerceUser(userID)
}

func ensureCommerceUserTx(tx *sql.Tx, userID, installationID string, now time.Time) error {
	stamp := now.Format(time.RFC3339)
	if _, err := tx.Exec(`INSERT INTO commerce_users(user_id, created_at, last_active_at) VALUES(?,?,?)
		ON CONFLICT(user_id) DO UPDATE SET last_active_at=excluded.last_active_at`, userID, stamp, stamp); err != nil {
		return err
	}
	hash := sha256.Sum256([]byte(installationID))
	installationHash := hex.EncodeToString(hash[:])
	var linked string
	err := tx.QueryRow(`SELECT user_id FROM user_installations WHERE installation_hash=?`, installationHash).Scan(&linked)
	if err == nil && linked != userID {
		return errors.New("installation is already linked to another user")
	}
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return err
	}
	_, err = tx.Exec(`INSERT INTO user_installations(installation_hash,user_id,linked_at) VALUES(?,?,?)
		ON CONFLICT(installation_hash) DO UPDATE SET linked_at=excluded.linked_at`, installationHash, userID, stamp)
	return err
}

func refillAllowanceTx(tx *sql.Tx, userID string, now time.Time) (string, error) {
	plan, anchor, _, err := entitlementTx(tx, userID, now)
	if err != nil {
		return "", err
	}
	amount := freeAllowance
	periodKey := "free:" + now.Format("2006-01")
	if plan != "free" {
		amount = premiumAllowance
		index := calendarMonthIndex(anchor, now)
		periodKey = plan + ":" + anchor.Format("2006-01-02") + fmt.Sprintf(":%d", index)
	}
	if _, err := tx.Exec(`UPDATE credit_grants SET remaining_amount=0
		WHERE user_id=? AND source='allowance' AND period_key<>? AND remaining_amount>0`, userID, periodKey); err != nil {
		return "", err
	}
	stamp := now.Format(time.RFC3339)
	_, err = tx.Exec(`INSERT INTO credit_grants(user_id,source,original_amount,remaining_amount,granted_at,period_key)
		VALUES(?, 'allowance', ?, ?, ?, ?)
		ON CONFLICT(user_id,source,period_key) DO NOTHING`, userID, amount, amount, stamp, periodKey)
	return periodKey, err
}

func entitlementTx(tx *sql.Tx, userID string, now time.Time) (string, time.Time, string, error) {
	var product, status, started, expires string
	err := tx.QueryRow(`SELECT product_id,status,started_at,expires_at FROM subscriptions WHERE user_id=?`, userID).
		Scan(&product, &status, &started, &expires)
	if err == nil {
		start, startErr := time.Parse(time.RFC3339, started)
		expiry, expiryErr := time.Parse(time.RFC3339, expires)
		if startErr == nil && expiryErr == nil && now.Before(expiry) && (status == "active" || status == "grace") {
			return product, start, expires, nil
		}
	} else if !errors.Is(err, sql.ErrNoRows) {
		return "", time.Time{}, "", err
	}
	var adminStart, adminExpires sql.NullString
	if err := tx.QueryRow(`SELECT admin_premium_started_at,admin_premium_expires_at FROM commerce_users WHERE user_id=?`, userID).
		Scan(&adminStart, &adminExpires); err != nil {
		return "", time.Time{}, "", err
	}
	if adminStart.Valid && adminExpires.Valid {
		start, e1 := time.Parse(time.RFC3339, adminStart.String)
		expiry, e2 := time.Parse(time.RFC3339, adminExpires.String)
		if e1 == nil && e2 == nil && now.Before(expiry) {
			return "admin", start, adminExpires.String, nil
		}
	}
	return "free", now, "", nil
}

func calendarMonthIndex(anchor, now time.Time) int {
	index := (now.Year()-anchor.Year())*12 + int(now.Month()-anchor.Month())
	if index < 0 {
		return 0
	}
	for index > 0 && now.Before(addCalendarMonthsClamped(anchor, index)) {
		index--
	}
	return index
}

func addCalendarMonthsClamped(anchor time.Time, months int) time.Time {
	year, month, day := anchor.Date()
	first := time.Date(year, month+time.Month(months), 1, anchor.Hour(), anchor.Minute(), anchor.Second(), anchor.Nanosecond(), time.UTC)
	lastDay := time.Date(first.Year(), first.Month()+1, 0, 0, 0, 0, 0, time.UTC).Day()
	if day > lastDay {
		day = lastDay
	}
	return time.Date(first.Year(), first.Month(), day, anchor.Hour(), anchor.Minute(), anchor.Second(), anchor.Nanosecond(), time.UTC)
}

func (s *Store) GetCommerceUser(userID string) (CommerceUser, error) {
	var user CommerceUser
	var adminExpiry sql.NullString
	if err := s.db.QueryRow(`SELECT user_id,created_at,last_active_at,admin_premium_expires_at FROM commerce_users WHERE user_id=?`, userID).
		Scan(&user.UserID, &user.CreatedAt, &user.LastActiveAt, &adminExpiry); err != nil {
		return user, err
	}
	user.AdminPremiumExpiresAt = adminExpiry.String
	tx, err := s.db.Begin()
	if err != nil {
		return user, err
	}
	plan, _, premiumExpiry, err := entitlementTx(tx, userID, time.Now().UTC())
	_ = tx.Rollback()
	if err != nil {
		return user, err
	}
	user.Plan, user.PremiumExpiresAt = plan, premiumExpiry
	_ = s.db.QueryRow(`SELECT product_id,status,expires_at FROM subscriptions WHERE user_id=?`, userID).
		Scan(&user.AppleProductID, &user.AppleSubscriptionStatus, &user.ApplePremiumExpiresAt)
	user.Credits, err = s.CreditBalance(userID)
	if err != nil {
		return user, err
	}
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM report_requests WHERE user_id=? AND report_status='success'`, userID).Scan(&user.ReportsGenerated)
	return user, nil
}

func (s *Store) GetCommerceUserDetail(userID string) (CommerceUser, error) {
	user, err := s.GetCommerceUser(userID)
	if err != nil {
		return user, err
	}
	rows, err := s.db.Query(`SELECT id,source,original_amount,remaining_amount,granted_at,expires_at FROM credit_grants WHERE user_id=? ORDER BY granted_at DESC,id DESC`, userID)
	if err != nil {
		return user, err
	}
	defer rows.Close()
	for rows.Next() {
		var grant CreditGrantSummary
		var expiry sql.NullString
		if err := rows.Scan(&grant.ID, &grant.Source, &grant.Original, &grant.Remaining, &grant.GrantedAt, &expiry); err != nil {
			return user, err
		}
		grant.ExpiresAt = expiry.String
		user.CreditGrants = append(user.CreditGrants, grant)
	}
	return user, rows.Err()
}

func (s *Store) CreditBalance(userID string) (CreditBalance, error) {
	var b CreditBalance
	now := time.Now().UTC().Format(time.RFC3339)
	rows, err := s.db.Query(`SELECT source,COALESCE(SUM(remaining_amount),0) FROM credit_grants
		WHERE user_id=? AND remaining_amount>0 AND (expires_at IS NULL OR expires_at>?) GROUP BY source`, userID, now)
	if err != nil {
		return b, err
	}
	defer rows.Close()
	for rows.Next() {
		var source string
		var amount int
		if err := rows.Scan(&source, &amount); err != nil {
			return b, err
		}
		switch source {
		case "allowance":
			b.Allowance += amount
		case "purchased":
			b.Purchased += amount
		default:
			b.Bonus += amount
		}
	}
	if err := rows.Err(); err != nil {
		return b, err
	}
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM credit_reservations WHERE user_id=? AND state='reserved'`, userID).Scan(&b.Reserved)
	b.Total = b.Allowance + b.Bonus + b.Purchased
	return b, nil
}

func (s *Store) ReserveCredit(userID, installationID, requestID, reportID, requestHash, scope, requestedLocale, effectiveLocale, model string) (ReportRequestRecord, error) {
	_ = s.ReleaseExpiredReservations()
	if !validCommerceID(userID) || !validCommerceID(requestID) || strings.TrimSpace(reportID) == "" || requestHash == "" {
		return ReportRequestRecord{}, errors.New("valid userID, requestID, reportID and request hash are required")
	}
	if existing, err := s.GetReportRequest(userID, requestID); err == nil {
		if existing.RequestHash != requestHash {
			return existing, errors.New("idempotency conflict")
		}
		return existing, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return ReportRequestRecord{}, err
	}
	tx, err := s.db.Begin()
	if err != nil {
		return ReportRequestRecord{}, err
	}
	defer tx.Rollback()
	now := time.Now().UTC()
	if err := ensureCommerceUserTx(tx, userID, installationID, now); err != nil {
		return ReportRequestRecord{}, err
	}
	if _, err := refillAllowanceTx(tx, userID, now); err != nil {
		return ReportRequestRecord{}, err
	}
	rows, err := tx.Query(`SELECT id,remaining_amount FROM credit_grants WHERE user_id=? AND remaining_amount>0
		AND (expires_at IS NULL OR expires_at>?) ORDER BY CASE source WHEN 'allowance' THEN 0 WHEN 'purchased' THEN 2 ELSE 1 END,
		CASE WHEN expires_at IS NULL THEN 1 ELSE 0 END, expires_at, granted_at, id`, userID, now.Format(time.RFC3339))
	if err != nil {
		return ReportRequestRecord{}, err
	}
	var allocation *creditAllocation
	for rows.Next() {
		var id int64
		var amount int
		if err := rows.Scan(&id, &amount); err != nil {
			rows.Close()
			return ReportRequestRecord{}, err
		}
		allocation = &creditAllocation{GrantID: id, Amount: 1}
		break
	}
	rows.Close()
	if allocation == nil {
		return ReportRequestRecord{}, errors.New("insufficient credits")
	}
	encoded, _ := json.Marshal([]creditAllocation{*allocation})
	stamp := now.Format(time.RFC3339)
	if _, err := tx.Exec(`UPDATE credit_grants SET remaining_amount=remaining_amount-1 WHERE id=? AND remaining_amount>0`, allocation.GrantID); err != nil {
		return ReportRequestRecord{}, err
	}
	if _, err := tx.Exec(`INSERT INTO credit_ledger(user_id,request_id,grant_id,action,delta,created_at) VALUES(?,?,?,'RESERVE',-1,?)`, userID, requestID, allocation.GrantID, stamp); err != nil {
		return ReportRequestRecord{}, err
	}
	if _, err := tx.Exec(`INSERT INTO credit_reservations(user_id,request_id,report_id,request_hash,state,allocations_json,created_at,expires_at,updated_at)
		VALUES(?,?,?,?, 'reserved',?,?,?,?)`, userID, requestID, reportID, requestHash, string(encoded), stamp, now.Add(creditReservationTTL).Format(time.RFC3339), stamp); err != nil {
		return ReportRequestRecord{}, err
	}
	if _, err := tx.Exec(`INSERT INTO report_requests(user_id,request_id,report_id,request_hash,scope,requested_locale,effective_locale,model,report_status,credit_status,created_at,updated_at)
		VALUES(?,?,?,?,?,?,?,?, 'processing','reserved',?,?)`, userID, requestID, reportID, requestHash, scope, requestedLocale, effectiveLocale, model, stamp, stamp); err != nil {
		return ReportRequestRecord{}, err
	}
	if err := tx.Commit(); err != nil {
		return ReportRequestRecord{}, err
	}
	return s.GetReportRequest(userID, requestID)
}

func (s *Store) ReleaseExpiredReservations() error {
	rows, err := s.db.Query(`SELECT user_id,request_id FROM credit_reservations WHERE state='reserved' AND expires_at<=?`, time.Now().UTC().Format(time.RFC3339))
	if err != nil {
		return err
	}
	var items [][2]string
	for rows.Next() {
		var userID, requestID string
		if err := rows.Scan(&userID, &requestID); err != nil {
			rows.Close()
			return err
		}
		items = append(items, [2]string{userID, requestID})
	}
	if err := rows.Close(); err != nil {
		return err
	}
	for _, item := range items {
		if err := s.ReleaseCredit(item[0], item[1], "delivery_ack_timeout", "client did not acknowledge local report persistence"); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) MarkReportAwaitingAcknowledgement(userID, requestID, requestHash, model string, promptTokens, completionTokens, reasoningTokens, durationMS int) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var state, storedHash string
	if err := tx.QueryRow(`SELECT state,request_hash FROM credit_reservations WHERE user_id=? AND request_id=?`, userID, requestID).Scan(&state, &storedHash); err != nil {
		return err
	}
	if storedHash != requestHash {
		return errors.New("idempotency conflict")
	}
	if state != "reserved" {
		return errors.New("credit reservation is not active")
	}
	stamp := time.Now().UTC().Format(time.RFC3339)
	result, err := tx.Exec(`UPDATE report_requests SET model=?,report_status='awaiting_ack',credit_status='reserved',prompt_tokens=?,completion_tokens=?,reasoning_tokens=?,duration_ms=?,updated_at=? WHERE user_id=? AND request_id=? AND report_status='processing'`, model, promptTokens, completionTokens, reasoningTokens, durationMS, stamp, userID, requestID)
	if err != nil {
		return err
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		return errors.New("report request is not processing")
	}
	return tx.Commit()
}

func (s *Store) ReleaseCredit(userID, requestID, errorCode, errorMessage string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var state, allocationsRaw string
	if err := tx.QueryRow(`SELECT state,allocations_json FROM credit_reservations WHERE user_id=? AND request_id=?`, userID, requestID).Scan(&state, &allocationsRaw); err != nil {
		return err
	}
	if state == "released" {
		return nil
	}
	if state == "consumed" {
		return errors.New("consumed credit cannot be released")
	}
	var allocations []creditAllocation
	if err := json.Unmarshal([]byte(allocationsRaw), &allocations); err != nil {
		return err
	}
	stamp := time.Now().UTC().Format(time.RFC3339)
	for _, item := range allocations {
		if _, err := tx.Exec(`UPDATE credit_grants SET remaining_amount=remaining_amount+? WHERE id=?`, item.Amount, item.GrantID); err != nil {
			return err
		}
		if _, err := tx.Exec(`INSERT INTO credit_ledger(user_id,request_id,grant_id,action,delta,created_at) VALUES(?,?,?,'RELEASE',?,?)`, userID, requestID, item.GrantID, item.Amount, stamp); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(`UPDATE credit_reservations SET state='released',updated_at=? WHERE user_id=? AND request_id=?`, stamp, userID, requestID); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE report_requests SET report_status='failed',credit_status='released',error_code=?,error_message=?,updated_at=? WHERE user_id=? AND request_id=?`, errorCode, safeErrorMessage(errorMessage), stamp, userID, requestID); err != nil {
		return err
	}
	return tx.Commit()
}

func safeErrorMessage(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > 240 {
		value = value[:240]
	}
	return value
}

func (s *Store) GetReportRequest(userID, requestID string) (ReportRequestRecord, error) {
	var r ReportRequestRecord
	var delivered sql.NullString
	err := s.db.QueryRow(`SELECT user_id,request_id,report_id,request_hash,scope,requested_locale,effective_locale,model,report_status,credit_status,prompt_tokens,completion_tokens,reasoning_tokens,duration_ms,error_code,error_message,created_at,updated_at,delivered_at FROM report_requests WHERE user_id=? AND request_id=?`, userID, requestID).
		Scan(&r.UserID, &r.RequestID, &r.ReportID, &r.RequestHash, &r.Scope, &r.RequestedLocale, &r.EffectiveLocale, &r.Model, &r.ReportStatus, &r.CreditStatus, &r.PromptTokens, &r.CompletionTokens, &r.ReasoningTokens, &r.DurationMS, &r.ErrorCode, &r.ErrorMessage, &r.CreatedAt, &r.UpdatedAt, &delivered)
	if err != nil {
		return r, err
	}
	r.DeliveredAt = delivered.String
	r.CreditCost = 1
	return r, err
}

func (s *Store) AcknowledgeReport(userID, requestID string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var state, status string
	if err = tx.QueryRow(`SELECT r.state,q.report_status FROM credit_reservations r JOIN report_requests q ON q.user_id=r.user_id AND q.request_id=r.request_id WHERE r.user_id=? AND r.request_id=?`, userID, requestID).Scan(&state, &status); err != nil {
		return err
	}
	if state == "consumed" && status == "success" {
		return nil
	}
	if state != "reserved" || status != "awaiting_ack" {
		return errors.New("report is not awaiting acknowledgement")
	}
	stamp := time.Now().UTC().Format(time.RFC3339)
	if _, err = tx.Exec(`UPDATE credit_reservations SET state='consumed',updated_at=? WHERE user_id=? AND request_id=? AND state='reserved'`, stamp, userID, requestID); err != nil {
		return err
	}
	if _, err = tx.Exec(`UPDATE report_requests SET report_status='success',credit_status='consumed',delivered_at=?,updated_at=? WHERE user_id=? AND request_id=? AND report_status='awaiting_ack'`, stamp, stamp, userID, requestID); err != nil {
		return err
	}
	if _, err = tx.Exec(`INSERT INTO credit_ledger(user_id,request_id,action,delta,created_at) VALUES(?,?,'CONSUME',0,?)`, userID, requestID, stamp); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) GrantAdminCredits(userID string, amount int, expiresAt *time.Time, operator string) error {
	if amount < 1 || amount > 10000 {
		return errors.New("amount must be between 1 and 10000")
	}
	stamp := time.Now().UTC().Format(time.RFC3339)
	var expiry any
	if expiresAt != nil {
		expiry = expiresAt.UTC().Format(time.RFC3339)
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	result, err := tx.Exec(`INSERT INTO credit_grants(user_id,source,original_amount,remaining_amount,granted_at,expires_at) VALUES(?,'admin',?,?,?,?)`, userID, amount, amount, stamp, expiry)
	if err != nil {
		return err
	}
	id, _ := result.LastInsertId()
	if _, err = tx.Exec(`INSERT INTO credit_ledger(user_id,grant_id,action,delta,created_at) VALUES(?,?,'ADMIN_GRANT',?,?)`, userID, id, amount, stamp); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return err
	}
	return s.RecordAudit(operator, "credits.grant", userID, map[string]any{"amount": amount, "expiresAt": expiry})
}

func (s *Store) SetAdminPremium(userID string, expiresAt *time.Time, operator, reason string) error {
	now := time.Now().UTC()
	var expiry any
	action := "premium.revoke"
	if expiresAt != nil {
		if !expiresAt.After(now) {
			return errors.New("expiration must be in the future")
		}
		expiry = expiresAt.UTC().Format(time.RFC3339)
		action = "premium.grant"
	}
	res, err := s.db.Exec(`UPDATE commerce_users SET admin_premium_started_at=CASE WHEN ? IS NULL THEN NULL ELSE COALESCE(admin_premium_started_at,?) END,admin_premium_expires_at=? WHERE user_id=?`, expiry, now.Format(time.RFC3339), expiry, userID)
	if err != nil {
		return err
	}
	changed, _ := res.RowsAffected()
	if changed == 0 {
		return sql.ErrNoRows
	}
	return s.RecordAudit(operator, action, userID, map[string]any{"expiresAt": expiry, "reason": safeErrorMessage(reason)})
}

func (s *Store) ListCommerceUsers(limit int) ([]CommerceUser, error) {
	if limit < 1 || limit > 500 {
		limit = 200
	}
	rows, err := s.db.Query(`SELECT user_id FROM commerce_users ORDER BY last_active_at DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	out := make([]CommerceUser, 0, len(ids))
	for _, id := range ids {
		user, err := s.GetCommerceUser(id)
		if err != nil {
			return nil, err
		}
		out = append(out, user)
	}
	return out, nil
}

func (s *Store) ListReportRequests(userID, scope, locale, status, date string, limit int) ([]ReportRequestRecord, error) {
	if limit < 1 || limit > 500 {
		limit = 200
	}
	clauses := []string{"1=1"}
	args := []any{}
	for _, filter := range []struct{ column, value string }{{"user_id", userID}, {"scope", scope}, {"requested_locale", locale}, {"report_status", status}} {
		if strings.TrimSpace(filter.value) != "" {
			clauses = append(clauses, filter.column+"=?")
			args = append(args, filter.value)
		}
	}
	if date != "" {
		clauses = append(clauses, "substr(created_at,1,10)=?")
		args = append(args, date)
	}
	args = append(args, limit)
	rows, err := s.db.Query(`SELECT user_id,request_id,report_id,request_hash,scope,requested_locale,effective_locale,model,report_status,credit_status,prompt_tokens,completion_tokens,reasoning_tokens,duration_ms,error_code,error_message,created_at,updated_at,delivered_at FROM report_requests WHERE `+strings.Join(clauses, " AND ")+` ORDER BY created_at DESC LIMIT ?`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ReportRequestRecord
	for rows.Next() {
		var r ReportRequestRecord
		var delivered sql.NullString
		if err := rows.Scan(&r.UserID, &r.RequestID, &r.ReportID, &r.RequestHash, &r.Scope, &r.RequestedLocale, &r.EffectiveLocale, &r.Model, &r.ReportStatus, &r.CreditStatus, &r.PromptTokens, &r.CompletionTokens, &r.ReasoningTokens, &r.DurationMS, &r.ErrorCode, &r.ErrorMessage, &r.CreatedAt, &r.UpdatedAt, &delivered); err != nil {
			return nil, err
		}
		r.DeliveredAt = delivered.String
		r.CreditCost = 1
		out = append(out, r)
	}
	return out, rows.Err()
}

type AppleTransactionPayload struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
	AppAccountToken       string `json:"appAccountToken"`
	BundleID              string `json:"bundleId"`
	PurchaseDate          int64  `json:"purchaseDate"`
	ExpiresDate           int64  `json:"expiresDate"`
	RevocationDate        int64  `json:"revocationDate"`
	Environment           string `json:"environment"`
	GraceExpiresDate      int64  `json:"-"`
}

func (s *Store) ApplyVerifiedStoreTransaction(userID string, value AppleTransactionPayload, jws string) error {
	if value.AppAccountToken != "" && !strings.EqualFold(value.AppAccountToken, userID) {
		return errors.New("appAccountToken does not match userID")
	}
	if value.BundleID != "com.xiaoguiwk.interstellar" {
		return errors.New("transaction bundle ID is invalid")
	}
	if value.TransactionID == "" || value.OriginalTransactionID == "" {
		return errors.New("transaction identifiers are required")
	}
	if value.ProductID != "premium_monthly" && value.ProductID != "premium_annual" && value.ProductID != "credits_10" {
		return errors.New("unknown product")
	}
	now := time.Now().UTC()
	purchase := time.UnixMilli(value.PurchaseDate).UTC()
	if value.PurchaseDate == 0 {
		purchase = now
	}
	sum := sha256.Sum256([]byte(jws))
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.Exec(`INSERT INTO commerce_users(user_id,created_at,last_active_at) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET last_active_at=excluded.last_active_at`, userID, now.Format(time.RFC3339), now.Format(time.RFC3339)); err != nil {
		return err
	}
	var revokedAt any
	if value.RevocationDate > 0 {
		revokedAt = time.UnixMilli(value.RevocationDate).UTC().Format(time.RFC3339)
	}
	var existingTransaction int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM store_transactions WHERE transaction_id=?`, value.TransactionID).Scan(&existingTransaction); err != nil {
		return err
	}
	_, err = tx.Exec(`INSERT INTO store_transactions(transaction_id,user_id,original_transaction_id,product_id,purchased_at,revoked_at,jws_hash,created_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(transaction_id) DO UPDATE SET revoked_at=COALESCE(excluded.revoked_at,store_transactions.revoked_at),jws_hash=excluded.jws_hash`, value.TransactionID, userID, value.OriginalTransactionID, value.ProductID, purchase.Format(time.RFC3339), revokedAt, hex.EncodeToString(sum[:]), now.Format(time.RFC3339))
	if err != nil {
		return err
	}
	inserted := existingTransaction == 0
	if value.ProductID == "credits_10" {
		if value.RevocationDate > 0 {
			var grantID int64
			var remaining int
			err := tx.QueryRow(`SELECT id,remaining_amount FROM credit_grants WHERE apple_transaction_id=?`, value.TransactionID).Scan(&grantID, &remaining)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			if err == nil {
				if _, err = tx.Exec(`UPDATE credit_grants SET remaining_amount=0,expires_at=? WHERE id=?`, now.Format(time.RFC3339), grantID); err != nil {
					return err
				}
				if remaining > 0 {
					if _, err = tx.Exec(`INSERT INTO credit_ledger(user_id,grant_id,action,delta,created_at) VALUES(?,?,'REVOCATION',?,?)`, userID, grantID, -remaining, now.Format(time.RFC3339)); err != nil {
						return err
					}
				}
			}
			return tx.Commit()
		}
		if !inserted {
			return tx.Commit()
		}
		grant, err := tx.Exec(`INSERT INTO credit_grants(user_id,source,original_amount,remaining_amount,granted_at,apple_transaction_id) VALUES(?,'purchased',10,10,?,?)`, userID, now.Format(time.RFC3339), value.TransactionID)
		if err != nil {
			return err
		}
		grantID, _ := grant.LastInsertId()
		if _, err = tx.Exec(`INSERT INTO credit_ledger(user_id,grant_id,action,delta,created_at) VALUES(?,?,'PURCHASE',10,?)`, userID, grantID, now.Format(time.RFC3339)); err != nil {
			return err
		}
	} else {
		expires := time.UnixMilli(value.ExpiresDate).UTC()
		status := "active"
		if value.GraceExpiresDate > 0 && time.UnixMilli(value.GraceExpiresDate).UTC().After(expires) {
			expires = time.UnixMilli(value.GraceExpiresDate).UTC()
			status = "grace"
		}
		if value.RevocationDate > 0 || !expires.After(now) {
			status = "revoked"
		}
		if _, err = tx.Exec(`INSERT INTO subscriptions(user_id,product_id,status,original_transaction_id,started_at,expires_at,updated_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET product_id=excluded.product_id,status=excluded.status,original_transaction_id=excluded.original_transaction_id,started_at=excluded.started_at,expires_at=excluded.expires_at,updated_at=excluded.updated_at`, userID, value.ProductID, status, value.OriginalTransactionID, purchase.Format(time.RFC3339), expires.Format(time.RFC3339), now.Format(time.RFC3339)); err != nil {
			return err
		}
		if value.ProductID == "premium_annual" && status == "active" {
			_, err = tx.Exec(`INSERT INTO credit_grants(user_id,source,original_amount,remaining_amount,granted_at,expires_at,period_key,apple_transaction_id) VALUES(?,'annual_welcome',20,20,?,?,'once',?) ON CONFLICT(user_id,source,period_key) DO NOTHING`, userID, now.Format(time.RFC3339), purchase.AddDate(1, 0, 0).Format(time.RFC3339), value.TransactionID)
			if err != nil {
				return err
			}
		}
		if value.ProductID == "premium_annual" && status == "revoked" {
			rows, err := tx.Query(`SELECT id,remaining_amount FROM credit_grants WHERE user_id=? AND source='annual_welcome'`, userID)
			if err != nil {
				return err
			}
			var revoked []creditAllocation
			for rows.Next() {
				var item creditAllocation
				if err := rows.Scan(&item.GrantID, &item.Amount); err != nil {
					rows.Close()
					return err
				}
				revoked = append(revoked, item)
			}
			if err := rows.Close(); err != nil {
				return err
			}
			for _, item := range revoked {
				if _, err = tx.Exec(`UPDATE credit_grants SET remaining_amount=0,expires_at=? WHERE id=?`, now.Format(time.RFC3339), item.GrantID); err != nil {
					return err
				}
				if item.Amount > 0 {
					if _, err = tx.Exec(`INSERT INTO credit_ledger(user_id,grant_id,action,delta,created_at) VALUES(?,?,'REVOCATION',?,?)`, userID, item.GrantID, -item.Amount, now.Format(time.RFC3339)); err != nil {
						return err
					}
				}
			}
		}
	}
	if _, err = refillAllowanceTx(tx, userID, now); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) LinkVerifiedInstallation(userID, installationID string) error {
	if !validCommerceID(userID) || installationID == "" {
		return errors.New("valid commerce identity required")
	}
	now := time.Now().UTC()
	hash := sha256.Sum256([]byte(installationID))
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.Exec(`INSERT INTO commerce_users(user_id,created_at,last_active_at) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET last_active_at=excluded.last_active_at`, userID, now.Format(time.RFC3339), now.Format(time.RFC3339)); err != nil {
		return err
	}
	if _, err = tx.Exec(`INSERT INTO user_installations(installation_hash,user_id,linked_at) VALUES(?,?,?) ON CONFLICT(installation_hash) DO UPDATE SET user_id=excluded.user_id,linked_at=excluded.linked_at`, hex.EncodeToString(hash[:]), userID, now.Format(time.RFC3339)); err != nil {
		return err
	}
	return tx.Commit()
}
