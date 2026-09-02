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
			writeAppVerificationError(w, http.StatusServiceUnavailable, "app_attest_unavailable", true)
			return nil, "", false
		}
		if err := c.appAttest.verifyGenerateRequest(r, body, installationID); err != nil {
			logAppAttestRejection(r, "commerce_assertion", err)
			writeAppVerificationError(w, http.StatusUnauthorized, "app_attest_invalid", false)
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
		UserID               string `json:"userID"`
		CountryCode          string `json:"countryCode"`
		SignedAppTransaction string `json:"signedAppTransaction"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid account sync request", false)
		return
	}
	appTransactionID := ""
	if req.SignedAppTransaction != "" {
		appTransaction, verifyErr := verifiedAppTransaction(req.SignedAppTransaction)
		if verifyErr != nil {
			writeError(w, http.StatusUnprocessableEntity, "app_transaction_unverified", verifyErr.Error(), false)
			return
		}
		appTransactionID = appTransaction.AppTransactionID
	}
	user, err := c.store.SyncCommerceUserWithAppleIdentity(req.UserID, installationID, req.CountryCode, appTransactionID)
	if err != nil {
		writeError(w, http.StatusConflict, "account_sync_failed", err.Error(), false)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

type verifiedAppleAppTransaction struct {
	AppTransactionID string `json:"appTransactionId"`
	BundleID         string `json:"bundleId"`
	Environment      string `json:"environment"`
}

func verifiedAppTransaction(jws string) (verifiedAppleAppTransaction, error) {
	var value verifiedAppleAppTransaction
	payload, err := verifyAppleJWS(jws)
	if err != nil {
		return value, err
	}
	if json.Unmarshal(payload, &value) != nil || strings.TrimSpace(value.AppTransactionID) == "" {
		return value, errors.New("signed App Transaction is invalid")
	}
	if value.BundleID != appStoreBundleID {
		return value, errors.New("App Transaction bundle ID is invalid")
	}
	return value, nil
}

func (c *relayConfig) handleAccountDelete(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID               string `json:"userID"`
		NewUserID            string `json:"newUserID"`
		SignedAppTransaction string `json:"signedAppTransaction"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid account deletion request", false)
		return
	}
	appTransaction, err := verifiedAppTransaction(req.SignedAppTransaction)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "app_transaction_unverified", err.Error(), false)
		return
	}
	user, err := c.store.DeactivateCommerceUser(req.UserID, req.NewUserID, installationID, appTransaction.AppTransactionID)
	if err != nil {
		writeError(w, http.StatusConflict, "account_delete_failed", err.Error(), false)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (c *relayConfig) handleAccountRestore(w http.ResponseWriter, r *http.Request) {
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
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid restore request", false)
		return
	}
	value, err := verifyAppleTransactionJWS(req.SignedTransaction)
	if err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_unverified", err.Error(), false)
		return
	}
	if value.ProductID != "premium_monthly" && value.ProductID != "premium_annual" {
		writeError(w, http.StatusUnprocessableEntity, "subscription_required", "only subscriptions can be restored", false)
		return
	}
	if value.RevocationDate > 0 || value.ExpiresDate <= time.Now().UTC().UnixMilli() {
		writeError(w, http.StatusConflict, "subscription_inactive", "the Apple subscription is not active", false)
		return
	}
	if err := c.store.CanRestoreSubscription(req.UserID, strings.ToLower(value.AppAccountToken)); err != nil {
		writeError(w, http.StatusConflict, "restore_identity_conflict", err.Error(), false)
		return
	}
	if c.appStoreServer == nil {
		writeError(w, http.StatusServiceUnavailable, "app_store_server_unavailable", "subscription restore is temporarily unavailable", true)
		return
	}
	if err := c.appStoreServer.setAppAccountToken(r.Context(), value.OriginalTransactionID, value.Environment, strings.ToLower(req.UserID)); err != nil {
		writeError(w, http.StatusBadGateway, "app_account_token_update_failed", "could not rebind the Apple subscription", true)
		return
	}
	if err := c.store.LinkVerifiedInstallation(req.UserID, installationID); err != nil {
		writeError(w, http.StatusConflict, "identity_link_failed", err.Error(), false)
		return
	}
	value.AppAccountToken = strings.ToLower(req.UserID)
	if err := c.store.ApplyVerifiedStoreTransaction(req.UserID, value, req.SignedTransaction); err != nil {
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

func (c *relayConfig) handleStoreTransaction(w http.ResponseWriter, r *http.Request) {
	body, installationID, ok := c.readAuthorizedCommerceBody(w, r)
	if !ok {
		return
	}
	var req struct {
		UserID            string `json:"userID"`
		SignedTransaction string `json:"signedTransaction"`
		TransactionID     string `json:"transactionID"`
		ProductID         string `json:"productID"`
		AppAccountToken   string `json:"appAccountToken"`
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(&req) != nil {
		writeError(w, http.StatusBadRequest, "invalid_transaction", "invalid transaction request", false)
		return
	}
	if !validCommerceID(req.UserID) {
		writeError(w, http.StatusBadRequest, "invalid_transaction", "valid userID is required", false)
		return
	}
	current, err := c.store.SyncCommerceUser(req.UserID, installationID)
	if err != nil {
		writeError(w, http.StatusConflict, "identity_link_failed", err.Error(), false)
		return
	}
	writeTerminal := func(user CommerceUser, disposition string) {
		writeJSON(w, http.StatusOK, struct {
			CommerceUser
			TransactionDisposition string `json:"transactionDisposition"`
		}{CommerceUser: user, TransactionDisposition: disposition})
	}
	value, err := verifyAppleTransactionJWS(req.SignedTransaction)
	if err != nil {
		if req.ProductID == "credits_10" || req.ProductID == "credits_20" {
			if auditErr := c.store.RecordStoreTransactionReconciliation(
				current.UserID,
				req.TransactionID,
				req.ProductID,
				req.AppAccountToken,
				"rejected_permanent",
				"transaction_unverified",
				req.SignedTransaction,
			); auditErr != nil {
				writeError(w, http.StatusInternalServerError, "transaction_audit_failed", "could not record transaction reconciliation", true)
				return
			}
			writeTerminal(current, "rejected_permanent")
			return
		}
		writeError(w, http.StatusUnprocessableEntity, "transaction_unverified", err.Error(), false)
		return
	}
	if validationErr := validateAppleTransactionPayload(value); validationErr != nil {
		if value.ProductID == "credits_10" || value.ProductID == "credits_20" {
			if auditErr := c.store.RecordStoreTransactionReconciliation(
				current.UserID,
				value.TransactionID,
				value.ProductID,
				value.AppAccountToken,
				"rejected_permanent",
				"transaction_rejected",
				req.SignedTransaction,
			); auditErr != nil {
				writeError(w, http.StatusInternalServerError, "transaction_audit_failed", "could not record transaction reconciliation", true)
				return
			}
			writeTerminal(current, "rejected_permanent")
			return
		}
		writeError(w, http.StatusUnprocessableEntity, "transaction_rejected", validationErr.Error(), false)
		return
	}
	if value.ProductID == "credits_10" || value.ProductID == "credits_20" {
		user, applyErr := c.store.ApplyVerifiedStoreTransactionForCurrentUser(current.UserID, installationID, value, req.SignedTransaction)
		if applyErr != nil {
			writeError(w, http.StatusInternalServerError, "transaction_reconciliation_failed", "could not reconcile transaction", true)
			return
		}
		disposition := "settled_owner"
		if value.AppAccountToken == "" || strings.EqualFold(value.AppAccountToken, current.UserID) {
			disposition = "credited_current"
		}
		writeTerminal(user, disposition)
		return
	}
	if !strings.EqualFold(value.AppAccountToken, current.UserID) {
		writeError(w, http.StatusUnprocessableEntity, "account_token_mismatch", "verified appAccountToken does not match userID", false)
		return
	}
	if err = c.store.ApplyVerifiedStoreTransaction(current.UserID, value, req.SignedTransaction); err != nil {
		writeError(w, http.StatusUnprocessableEntity, "transaction_rejected", err.Error(), false)
		return
	}
	user, err := c.store.GetCommerceUser(current.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "account_unavailable", "could not reload account", true)
		return
	}
	writeTerminal(user, "credited_current")
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
	notificationType, duplicate, failure := c.processSignedAppStoreNotification(envelope.SignedPayload)
	if failure != nil {
		writeError(w, failure.status, failure.code, failure.message, false)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "type": notificationType, "duplicate": duplicate})
}

type appStoreNotificationFailure struct {
	status  int
	code    string
	message string
}

type appStoreNotification struct {
	NotificationType string `json:"notificationType"`
	Subtype          string `json:"subtype"`
	NotificationUUID string `json:"notificationUUID"`
	Data             struct {
		BundleID              string `json:"bundleId"`
		Environment           string `json:"environment"`
		SignedTransactionInfo string `json:"signedTransactionInfo"`
		SignedRenewalInfo     string `json:"signedRenewalInfo"`
	} `json:"data"`
}

func notificationFailure(code, message string) *appStoreNotificationFailure {
	return &appStoreNotificationFailure{status: http.StatusUnprocessableEntity, code: code, message: message}
}

func (c *relayConfig) processSignedAppStoreNotification(signedPayload string) (string, bool, *appStoreNotificationFailure) {
	payload, err := verifyAppleJWS(signedPayload)
	if err != nil {
		return "", false, notificationFailure("notification_unverified", err.Error())
	}
	return c.processVerifiedAppStoreNotification(payload)
}

func (c *relayConfig) processVerifiedAppStoreNotification(payload []byte) (string, bool, *appStoreNotificationFailure) {
	var notification appStoreNotification
	if json.Unmarshal(payload, &notification) != nil || strings.TrimSpace(notification.NotificationType) == "" {
		return "", false, notificationFailure("notification_invalid", "signed notification payload is invalid")
	}
	if notification.Data.BundleID != "" && notification.Data.BundleID != "com.xiaoguiwk.interstellar" {
		return "", false, notificationFailure("bundle_mismatch", "notification bundle ID is invalid")
	}
	if c.store != nil && notification.NotificationUUID != "" {
		processed, err := c.store.AppStoreNotificationProcessed(notification.NotificationUUID)
		if err != nil {
			return "", false, notificationFailure("notification_audit_failed", "could not check notification audit")
		}
		if processed {
			return notification.NotificationType, true, nil
		}
	}
	// Apple's V2 TEST notification proves delivery of the signed outer payload,
	// but intentionally contains no signed transaction or renewal information.
	if notification.NotificationType == "TEST" {
		if c.store != nil && notification.NotificationUUID != "" {
			if err := c.store.RecordAppStoreNotification(processedAppStoreNotification{
				UUID: notification.NotificationUUID, Type: notification.NotificationType,
				Subtype: notification.Subtype, Environment: notification.Data.Environment,
			}); err != nil {
				return "", false, notificationFailure("notification_audit_failed", "could not record notification audit")
			}
		}
		return notification.NotificationType, false, nil
	}
	if notification.Data.SignedTransactionInfo == "" {
		// Some valid V2 notifications carry renewal or app-level information
		// without a transaction. Acknowledge and audit them so Apple does not
		// retry forever; periodic status reconciliation remains authoritative.
		if c.store != nil && notification.NotificationUUID != "" {
			if err := c.store.RecordAppStoreNotification(processedAppStoreNotification{
				UUID: notification.NotificationUUID, Type: notification.NotificationType,
				Subtype: notification.Subtype, Environment: notification.Data.Environment,
			}); err != nil {
				return "", false, notificationFailure("notification_audit_failed", "could not record notification audit")
			}
		}
		return notification.NotificationType, false, nil
	}
	transaction, err := verifyAppleTransactionJWS(notification.Data.SignedTransactionInfo)
	if err != nil {
		return "", false, notificationFailure("transaction_unverified", err.Error())
	}
	if notification.Data.SignedRenewalInfo != "" {
		renewalPayload, renewalErr := verifyAppleJWS(notification.Data.SignedRenewalInfo)
		if renewalErr != nil {
			return "", false, notificationFailure("renewal_unverified", renewalErr.Error())
		}
		var renewal struct {
			GracePeriodExpiresDate int64 `json:"gracePeriodExpiresDate"`
		}
		if json.Unmarshal(renewalPayload, &renewal) != nil {
			return "", false, notificationFailure("renewal_invalid", "signed renewal payload is invalid")
		}
		transaction.GraceExpiresDate = renewal.GracePeriodExpiresDate
	}
	if notification.Data.BundleID != "" && notification.Data.BundleID != transaction.BundleID {
		return "", false, notificationFailure("bundle_mismatch", "notification bundle does not match transaction")
	}
	switch notification.NotificationType {
	case "EXPIRED", "GRACE_PERIOD_EXPIRED":
		transaction.ServerStatus = 2
	case "DID_FAIL_TO_RENEW":
		transaction.ServerStatus = 3
	case "REFUND", "REVOKE":
		transaction.ServerStatus = 5
	}
	userID := strings.ToLower(transaction.AppAccountToken)
	if !validCommerceID(userID) {
		return "", false, notificationFailure("account_token_missing", "verified transaction has no valid appAccountToken")
	}
	if err := c.store.ApplyVerifiedStoreTransaction(userID, transaction, notification.Data.SignedTransactionInfo); err != nil {
		return "", false, notificationFailure("transaction_rejected", err.Error())
	}
	if notification.NotificationUUID != "" {
		if err := c.store.RecordAppStoreNotification(processedAppStoreNotification{
			UUID: notification.NotificationUUID, Type: notification.NotificationType,
			Subtype: notification.Subtype, Environment: normalizeAppStoreEnvironment(notification.Data.Environment),
			TransactionID: transaction.TransactionID, OriginalTransactionID: transaction.OriginalTransactionID,
		}); err != nil {
			return "", false, notificationFailure("notification_audit_failed", "could not record notification audit")
		}
	}
	return notification.NotificationType, false, nil
}

func (c *relayConfig) handleVerifiedAppStoreNotification(w http.ResponseWriter, payload []byte) {
	notificationType, duplicate, failure := c.processVerifiedAppStoreNotification(payload)
	if failure != nil {
		writeError(w, failure.status, failure.code, failure.message, false)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "type": notificationType, "duplicate": duplicate})
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
	case "credits-deduct":
		var req struct {
			Amount int `json:"amount"`
		}
		if readJSON(r, &req) != nil {
			writeError(w, http.StatusBadRequest, "invalid_credit_deduction", "invalid Credit deduction", false)
			return
		}
		if err := c.store.DeductAdminCredits(userID, req.Amount, adminUsername(r)); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "credit_deduction_failed", err.Error(), false)
			return
		}
	case "credits-reset":
		if err := c.store.ResetAdminCredits(userID, adminUsername(r)); err != nil {
			writeError(w, http.StatusUnprocessableEntity, "credit_reset_failed", err.Error(), false)
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
