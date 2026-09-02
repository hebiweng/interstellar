package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"math/big"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const appStoreBundleID = "com.xiaoguiwk.interstellar"

type appStoreServerClient struct {
	keyID      string
	issuerID   string
	bundleID   string
	privateKey *ecdsa.PrivateKey
	httpClient *http.Client
	production string
	sandbox    string
}

type appStoreAPIError struct {
	Status int
	Body   string
}

func (e *appStoreAPIError) Error() string {
	var value struct {
		ErrorCode    int64  `json:"errorCode"`
		ErrorMessage string `json:"errorMessage"`
	}
	if json.Unmarshal([]byte(e.Body), &value) == nil && value.ErrorCode != 0 {
		return fmt.Sprintf("App Store Server API returned HTTP %d errorCode=%d", e.Status, value.ErrorCode)
	}
	return fmt.Sprintf("App Store Server API returned HTTP %d", e.Status)
}

func newAppStoreServerClientFromEnvironment() (*appStoreServerClient, error) {
	keyID := strings.TrimSpace(os.Getenv("RELAY_APP_STORE_KEY_ID"))
	issuerID := strings.TrimSpace(os.Getenv("RELAY_APP_STORE_ISSUER_ID"))
	keyPath := strings.TrimSpace(os.Getenv("RELAY_APP_STORE_PRIVATE_KEY_PATH"))
	if keyID == "" && issuerID == "" && keyPath == "" {
		return nil, nil
	}
	if keyID == "" || issuerID == "" || keyPath == "" {
		return nil, errors.New("RELAY_APP_STORE_KEY_ID, RELAY_APP_STORE_ISSUER_ID and RELAY_APP_STORE_PRIVATE_KEY_PATH must be configured together")
	}
	keyPEM, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("read App Store private key: %w", err)
	}
	block, _ := pem.Decode(keyPEM)
	if block == nil {
		return nil, errors.New("App Store private key is not PEM encoded")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse App Store private key: %w", err)
	}
	privateKey, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("App Store private key is not ECDSA")
	}
	if privateKey.Curve.Params().BitSize != 256 {
		return nil, errors.New("App Store private key must use the P-256 curve")
	}
	return &appStoreServerClient{
		keyID: keyID, issuerID: issuerID, bundleID: appStoreBundleID, privateKey: privateKey,
		httpClient: &http.Client{Timeout: 30 * time.Second},
		production: "https://api.storekit.apple.com",
		sandbox:    "https://api.storekit-sandbox.apple.com",
	}, nil
}

func (c *appStoreServerClient) authorizationToken(now time.Time) (string, error) {
	header, _ := json.Marshal(map[string]string{"alg": "ES256", "kid": c.keyID, "typ": "JWT"})
	claims, _ := json.Marshal(map[string]any{
		"iss": c.issuerID,
		"iat": now.Unix(),
		"exp": now.Add(5 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": c.bundleID,
	})
	encodedHeader := base64.RawURLEncoding.EncodeToString(header)
	encodedClaims := base64.RawURLEncoding.EncodeToString(claims)
	unsigned := encodedHeader + "." + encodedClaims
	digest := sha256.Sum256([]byte(unsigned))
	r, s, err := ecdsa.Sign(rand.Reader, c.privateKey, digest[:])
	if err != nil {
		return "", err
	}
	signature := make([]byte, 64)
	r.FillBytes(signature[:32])
	s.FillBytes(signature[32:])
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature), nil
}

func (c *appStoreServerClient) baseURL(environment string) string {
	if normalizeAppStoreEnvironment(environment) == "Sandbox" {
		return c.sandbox
	}
	return c.production
}

func (c *appStoreServerClient) request(ctx context.Context, method, environment, path string, body []byte, out any) error {
	token, err := c.authorizationToken(time.Now().UTC())
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL(environment)+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	if len(body) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return &appStoreAPIError{Status: resp.StatusCode, Body: string(responseBody)}
	}
	if out == nil {
		return nil
	}
	return json.Unmarshal(responseBody, out)
}

type appStoreStatusResponse struct {
	BundleID    string `json:"bundleId"`
	Environment string `json:"environment"`
	Data        []struct {
		LastTransactions []struct {
			OriginalTransactionID string `json:"originalTransactionId"`
			Status                int    `json:"status"`
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			SignedRenewalInfo     string `json:"signedRenewalInfo"`
		} `json:"lastTransactions"`
	} `json:"data"`
}

func (c *appStoreServerClient) getAllSubscriptionStatuses(ctx context.Context, transactionID, environment string) (appStoreStatusResponse, error) {
	var response appStoreStatusResponse
	path := "/inApps/v1/subscriptions/" + url.PathEscape(transactionID)
	err := c.request(ctx, http.MethodGet, environment, path, nil, &response)
	return response, err
}

func (c *appStoreServerClient) setAppAccountToken(ctx context.Context, originalTransactionID, environment, appAccountToken string) error {
	body, _ := json.Marshal(map[string]string{"appAccountToken": appAccountToken})
	path := "/inApps/v1/transactions/" + url.PathEscape(originalTransactionID) + "/appAccountToken"
	return c.request(ctx, http.MethodPut, environment, path, body, nil)
}

type appStoreNotificationHistoryResponse struct {
	HasMore             bool   `json:"hasMore"`
	PaginationToken     string `json:"paginationToken"`
	NotificationHistory []struct {
		SignedPayload string `json:"signedPayload"`
	} `json:"notificationHistory"`
}

func (c *appStoreServerClient) getNotificationHistory(ctx context.Context, environment string, start, end time.Time, paginationToken string) (appStoreNotificationHistoryResponse, error) {
	body, _ := json.Marshal(map[string]any{
		"startDate":    start.UnixMilli(),
		"endDate":      end.UnixMilli(),
		"onlyFailures": true,
	})
	path := "/inApps/v1/notifications/history"
	if paginationToken != "" {
		path += "?paginationToken=" + url.QueryEscape(paginationToken)
	}
	var response appStoreNotificationHistoryResponse
	err := c.request(ctx, http.MethodPost, environment, path, body, &response)
	return response, err
}

func (c *relayConfig) reconcileAppStoreSubscriptions(ctx context.Context) (int, error) {
	items, err := c.store.ListSubscriptionsForReconciliation()
	if err != nil {
		return 0, err
	}
	updated := 0
	failed := 0
	for _, item := range items {
		response, err := c.appStoreServer.getAllSubscriptionStatuses(ctx, item.OriginalTransactionID, item.Environment)
		if apiErr := new(appStoreAPIError); err != nil && normalizeAppStoreEnvironment(item.Environment) == "Production" && errors.As(err, &apiErr) && (apiErr.Status == http.StatusUnauthorized || (apiErr.Status == http.StatusNotFound && strings.Contains(apiErr.Body, "4040010"))) {
			// Older rows predate environment persistence. Apple recommends trying
			// Production first and falling back to Sandbox for a missing transaction.
			// Before an app has a production release, Apple may return 401 instead
			// of 404 for an otherwise valid Server API key, so that response also
			// receives a Sandbox fallback.
			response, err = c.appStoreServer.getAllSubscriptionStatuses(ctx, item.OriginalTransactionID, "Sandbox")
		}
		if err != nil {
			failed++
			continue
		}
		if response.BundleID != appStoreBundleID {
			failed++
			continue
		}
		var selected *AppleTransactionPayload
		var selectedJWS string
		for _, group := range response.Data {
			for _, latest := range group.LastTransactions {
				transaction, verifyErr := verifyAppleTransactionJWS(latest.SignedTransactionInfo)
				if verifyErr != nil {
					return updated, verifyErr
				}
				if !strings.EqualFold(transaction.AppAccountToken, item.UserID) || transaction.OriginalTransactionID != item.OriginalTransactionID {
					continue
				}
				transaction.ServerStatus = latest.Status
				if latest.SignedRenewalInfo != "" {
					renewalPayload, verifyErr := verifyAppleJWS(latest.SignedRenewalInfo)
					if verifyErr != nil {
						return updated, verifyErr
					}
					var renewal struct {
						GracePeriodExpiresDate int64 `json:"gracePeriodExpiresDate"`
					}
					if err := json.Unmarshal(renewalPayload, &renewal); err != nil {
						return updated, err
					}
					transaction.GraceExpiresDate = renewal.GracePeriodExpiresDate
				}
				if selected == nil || transaction.ExpiresDate > selected.ExpiresDate {
					candidate := transaction
					selected = &candidate
					selectedJWS = latest.SignedTransactionInfo
				}
			}
		}
		if selected == nil {
			failed++
			continue
		}
		if err := c.store.ApplyVerifiedStoreTransaction(item.UserID, *selected, selectedJWS); err != nil {
			failed++
			continue
		}
		updated++
	}
	if failed > 0 {
		return updated, fmt.Errorf("%d subscription status queries failed", failed)
	}
	return updated, nil
}

func (c *relayConfig) recoverAppStoreNotificationHistory(ctx context.Context, environment string, now time.Time) (int, error) {
	key := "app_store_history_checkpoint_" + strings.ToLower(normalizeAppStoreEnvironment(environment))
	start := now.Add(-24 * time.Hour)
	if value, _ := c.store.GetSetting(key); value != "" {
		if checkpoint, err := time.Parse(time.RFC3339, value); err == nil {
			start = checkpoint.Add(-5 * time.Minute)
		}
	}
	end := now.UTC()
	paginationToken := ""
	processed := 0
	for page := 0; page < 1000; page++ {
		response, err := c.appStoreServer.getNotificationHistory(ctx, environment, start, end, paginationToken)
		if err != nil {
			return processed, err
		}
		for _, item := range response.NotificationHistory {
			_, _, failure := c.processSignedAppStoreNotification(item.SignedPayload)
			if failure != nil {
				return processed, errors.New(failure.code)
			}
			processed++
		}
		if !response.HasMore {
			if err := c.store.SetSetting(key, end.Format(time.RFC3339)); err != nil {
				return processed, err
			}
			return processed, nil
		}
		if response.PaginationToken == "" || response.PaginationToken == paginationToken {
			return processed, errors.New("App Store notification history pagination stalled")
		}
		paginationToken = response.PaginationToken
	}
	return processed, errors.New("App Store notification history exceeded page limit")
}

func (c *relayConfig) runAppStoreReconciliation(ctx context.Context, interval time.Duration) {
	run := func() {
		updated, statusErr := c.reconcileAppStoreSubscriptions(ctx)
		productionHistory, productionErr := c.recoverAppStoreNotificationHistory(ctx, "Production", time.Now().UTC())
		sandboxHistory, sandboxErr := c.recoverAppStoreNotificationHistory(ctx, "Sandbox", time.Now().UTC())
		if statusErr != nil || productionErr != nil || sandboxErr != nil {
			log.Printf("App Store reconciliation failed status=%v production_history=%v sandbox_history=%v", statusErr, productionErr, sandboxErr)
			return
		}
		log.Printf("App Store reconciliation complete subscriptions=%d production_history=%d sandbox_history=%d", updated, productionHistory, sandboxHistory)
	}
	run()
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			run()
		}
	}
}

func verifyJWTSignatureForTest(token string, publicKey *ecdsa.PublicKey) bool {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return false
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(signature) != 64 {
		return false
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	return ecdsa.Verify(publicKey, digest[:], new(big.Int).SetBytes(signature[:32]), new(big.Int).SetBytes(signature[32:]))
}
