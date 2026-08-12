package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func (c *relayConfig) readAuthorizedCommerceBody(w http.ResponseWriter, r *http.Request) ([]byte, string, bool) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return nil, "", false
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "could not read request", false)
		return nil, "", false
	}
	installationID := strings.TrimSpace(r.Header.Get("X-Installation-ID"))
	if installationID == "" {
		writeError(w, http.StatusUnauthorized, "installation_required", "installation identity is required", false)
		return nil, "", false
	}
	devBypass := c.allowDevBypass && r.Header.Get("X-App-Attest-Development-Bypass") == "1"
	if !devBypass {
		if c.appAttest == nil {
			writeError(w, http.StatusServiceUnavailable, "app_attest_unavailable", "App Attest is not configured", true)
			return nil, "", false
		}
		if err := c.appAttest.verifyGenerateRequest(r, body, installationID); err != nil {
			writeError(w, http.StatusUnauthorized, "app_attest_invalid", err.Error(), false)
			return nil, "", false
		}
	}
	return body, installationID, true
}

func (c *relayConfig) handleAccountSync(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID string `json:"userID"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid account sync request", false)
		return
	}
	user, err := c.store.SyncCommerceUser(req.UserID, installationID)
	if err != nil {
		writeError(w, http.StatusConflict, "account_sync_failed", err.Error(), false)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (c *relayConfig) handleStoreTransaction(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID            string `json:"userID"`
		SignedTransaction string `json:"signedTransaction"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_transaction", "invalid transaction request", false)
		return
	}
	value, err := verifyAppleTransactionJWS(req.SignedTransaction)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_unverified", err.Error(), false)
		return
	}
	if !validCommerceID(req.UserID) || !strings.EqualFold(value.AppAccountToken, req.UserID) {
		writeError(w, http.StatusUnprocessableEntity, "account_token_mismatch", "verified appAccountToken does not match userID", false)
		return
	}
	if err = c.store.LinkVerifiedInstallation(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "identity_link_failed", err.Error(), false)
		return
	}
	if err = c.store.ApplyVerifiedStoreTransaction(req.UserID, value, req.SignedTransaction); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_rejected", err.Error(), false)
		return
	}
	user, err := c.store.GetCommerceUser(req.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "account_unavailable", "could not reload account", true)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (c *relayConfig) handleAppStoreNotification(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	var envelope struct {
		SignedPayload string `json:"signedPayload"`
	}
	if readJSON(r, &envelope) != nil || envelope.SignedPayload == "" {
		writeError(w, http.StatusBadRequest, "invalid_notification", "signedPayload is required", false)
		return
	}
	payload, err := verifyAppleJWS(envelope.SignedPayload)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "notification_unverified", err.Error(), false)
		return
	}
	var notification struct {
		NotificationType string `json:"notificationType"`
		Data             struct {
			BundleID              string `json:"bundleId"`
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			SignedRenewalInfo     string `json:"signedRenewalInfo"`
		} `json:"data"`
	}
	if json.Unmarshal(payload, &notification) != nil || notification.Data.SignedTransactionInfo == "" {
		writeError(w, http.StatusUnprocessableEntity, "notification_unsupported", "notification has no signed transaction", false)
		return
	}
	transaction, err := verifyAppleTransactionJWS(notification.Data.SignedTransactionInfo)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_unverified", err.Error(), false)
		return
	}
	if notification.Data.SignedRenewalInfo != "" {
		renewalPayload, renewalErr := verifyAppleJWS(notification.Data.SignedRenewalInfo)
		if renewalErr != nil {
			writeError(w, http.StatusUnprocessableEntity, "renewal_unverified", renewalErr.Error(), false)
			return
		}
		var renewal struct {
			GracePeriodExpiresDate int64 `json:"gracePeriodExpiresDate"`
		}
		if json.Unmarshal(renewalPayload, &renewal) != nil {
			writeError(w, http.StatusUnprocessableEntity, "renewal_invalid", "signed renewal payload is invalid", false)
			return
		}
		transaction.GraceExpiresDate = renewal.GracePeriodExpiresDate
	}
	if notification.Data.BundleID != "" && notification.Data.BundleID != transaction.BundleID {
		writeError(w, http.StatusUnprocessableEntity, "bundle_mismatch", "notification bundle does not match transaction", false)
		return
	}
	userID := strings.ToLower(transaction.AppAccountToken)
	if !validCommerceID(userID) {
		writeError(w, http.StatusUnprocessableEntity, "account_token_missing", "verified transaction has no valid appAccountToken", false)
		return
	}
	if err := c.store.ApplyVerifiedStoreTransaction(userID, transaction, notification.Data.SignedTransactionInfo); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_rejected", err.Error(), false)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "type": notification.NotificationType})
}

func (c *relayConfig) handleReportAck(w http.ResponseWriter, r *http.Request) {
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
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid report acknowledgement", false)
		return
	}
	if _, err := c.store.SyncCommerceUser(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "identity_conflict", err.Error(), false)
		return
	}
	err := c.store.AcknowledgeReport(req.UserID, req.RequestID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "report_not_found", "report is not available for acknowledgement", false)
		return
	}
	if err != nil {
		if strings.Contains(err.Error(), "not awaiting acknowledgement") {
			writeError(w, http.StatusConflict, "ack_not_pending", "report reservation is no longer awaiting acknowledgement", false)
			return
		}
		writeError(w, http.StatusInternalServerError, "ack_failed", "could not acknowledge report delivery", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (c *relayConfig) handleAdminReports(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	q := r.URL.Query()
	items, err := c.store.ListReportRequests(q.Get("userID"), q.Get("chartType"), q.Get("language"), q.Get("status"), q.Get("date"), 200)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "reports_unavailable", "could not load reports", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": len(items)})
}

func (c *relayConfig) handleAdminUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	users, err := c.store.ListCommerceUsers(200)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "users_unavailable", "could not load users", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": users, "total": len(users)})
}

func (c *relayConfig) handleAdminUserItem(w http.ResponseWriter, r *http.Request) {
	path := strings.Trim(strings.TrimPrefix(r.URL.Path, "/admin/users/"), "/")
	parts := strings.Split(path, "/")
	if len(parts) < 1 || !validCommerceID(parts[0]) {
		writeError(w, http.StatusBadRequest, "invalid_user", "valid user UUID required", false)
		return
	}
	userID := parts[0]
	if len(parts) == 1 && r.Method == http.MethodGet {
		user, err := c.store.GetCommerceUserDetail(userID)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "user_not_found", "user not found", false)
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "user_unavailable", "could not load user", true)
			return
		}
		writeJSON(w, http.StatusOK, user)
		return
	}
	if len(parts) != 2 || r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "unsupported user operation", false)
		return
	}
	switch parts[1] {
	case "credits":
		var req struct {
			Amount    int    `json:"amount"`
			ExpiresAt string `json:"expiresAt"`
		}
		if readJSON(r, &req) != nil {
			writeError(w, http.StatusBadRequest, "invalid_credit_grant", "invalid credit grant", false)
			return
		}
		var expiry *time.Time
		if req.ExpiresAt != "" {
			value, err := time.Parse(time.RFC3339, req.ExpiresAt)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid_expiration", "expiresAt must be ISO-8601", false)
				return
			}
			expiry = &value
		}
		if err := c.store.GrantAdminCredits(userID, req.Amount, expiry, adminUsername(r)); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "credit_grant_failed", err.Error(), false)
			return
		}
	case "premium":
		var req struct {
			ExpiresAt string `json:"expiresAt"`
			Reason    string `json:"reason"`
		}
		if readJSON(r, &req) != nil {
			writeError(w, http.StatusBadRequest, "invalid_premium_grant", "invalid premium grant", false)
			return
		}
		var expiry *time.Time
		if req.ExpiresAt != "" {
			value, err := time.Parse(time.RFC3339, req.ExpiresAt)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid_expiration", "expiresAt must be ISO-8601", false)
				return
			}
			expiry = &value
		}
		if err := c.store.SetAdminPremium(userID, expiry, adminUsername(r), req.Reason); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "premium_update_failed", err.Error(), false)
			return
		}
	case "plan":
		var req struct {
			Plan      string `json:"plan"`
			ExpiresAt string `json:"expiresAt"`
			Reason    string `json:"reason"`
		}
		if readJSON(r, &req) != nil {
			writeError(w, http.StatusBadRequest, "invalid_plan", "invalid plan override", false)
			return
		}
		var expiry *time.Time
		if req.ExpiresAt != "" {
			value, err := time.Parse(time.RFC3339, req.ExpiresAt)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid_expiration", "expiresAt must be ISO-8601", false)
				return
			}
			expiry = &value
		}
		if err := c.store.SetAdminPlan(userID, req.Plan, expiry, adminUsername(r), req.Reason); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "plan_update_failed", err.Error(), false)
			return
		}
	default:
		writeError(w, http.StatusNotFound, "not_found", "unknown user operation", false)
		return
	}
	user, err := c.store.GetCommerceUser(userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "user_unavailable", "could not reload user", true)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func parsePositiveInt(value string, fallback int) int {
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}
