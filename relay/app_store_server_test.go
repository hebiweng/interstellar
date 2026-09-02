package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func TestAppStoreServerAuthorizationToken(t *testing.T) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	client := &appStoreServerClient{
		keyID: "KEY123", issuerID: "issuer-id", bundleID: appStoreBundleID, privateKey: privateKey,
	}
	now := time.Unix(1_800_000_000, 0).UTC()
	token, err := client.authorizationToken(now)
	if err != nil {
		t.Fatal(err)
	}
	if !verifyJWTSignatureForTest(token, &privateKey.PublicKey) {
		t.Fatal("App Store authorization token signature is invalid")
	}
	parts := strings.Split(token, ".")
	claimsJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatal(err)
	}
	var claims struct {
		Issuer   string `json:"iss"`
		Audience string `json:"aud"`
		BundleID string `json:"bid"`
		IssuedAt int64  `json:"iat"`
		Expires  int64  `json:"exp"`
	}
	if err := json.Unmarshal(claimsJSON, &claims); err != nil {
		t.Fatal(err)
	}
	if claims.Issuer != "issuer-id" || claims.Audience != "appstoreconnect-v1" || claims.BundleID != appStoreBundleID {
		t.Fatalf("unexpected App Store JWT claims: %+v", claims)
	}
	if claims.IssuedAt != now.Unix() || claims.Expires != now.Add(5*time.Minute).Unix() {
		t.Fatalf("unexpected App Store JWT lifetime: %+v", claims)
	}
}

func TestAppStoreNotificationAuditIsIdempotent(t *testing.T) {
	store := openTestStore(t)
	cfg := &relayConfig{store: store}
	payload := []byte(`{
		"notificationType":"TEST",
		"notificationUUID":"00000000-0000-4000-8000-000000000099",
		"data":{"bundleId":"com.xiaoguiwk.interstellar","environment":"Production"}
	}`)
	_, duplicate, failure := cfg.processVerifiedAppStoreNotification(payload)
	if failure != nil || duplicate {
		t.Fatalf("first TEST notification failed=%+v duplicate=%v", failure, duplicate)
	}
	_, duplicate, failure = cfg.processVerifiedAppStoreNotification(payload)
	if failure != nil || !duplicate {
		t.Fatalf("duplicate TEST notification failed=%+v duplicate=%v", failure, duplicate)
	}
	var count int
	if err := store.db.QueryRow(`SELECT COUNT(*) FROM app_store_notifications WHERE notification_uuid=?`, "00000000-0000-4000-8000-000000000099").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("expected one notification audit row, got %d", count)
	}
}

func TestSetAppAccountTokenUsesAppleRebindEndpoint(t *testing.T) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	var method, path, token string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		method = r.Method
		path = r.URL.EscapedPath()
		var body struct {
			AppAccountToken string `json:"appAccountToken"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		token = body.AppAccountToken
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	client := &appStoreServerClient{
		keyID: "KEY123", issuerID: "issuer-id", bundleID: appStoreBundleID, privateKey: privateKey,
		httpClient: server.Client(), production: server.URL, sandbox: server.URL,
	}
	if err := client.setAppAccountToken(context.Background(), "original/transaction", "Sandbox", "20202020-2020-4020-8020-202020202020"); err != nil {
		t.Fatal(err)
	}
	if method != http.MethodPut || path != "/inApps/v1/transactions/original%2Ftransaction/appAccountToken" || token != "20202020-2020-4020-8020-202020202020" {
		t.Fatalf("unexpected rebind request method=%s path=%s token=%s", method, path, token)
	}
}

func TestLiveAppStoreServerCredentials(t *testing.T) {
	if os.Getenv("RELAY_APP_STORE_LIVE_TEST") != "1" {
		t.Skip("set RELAY_APP_STORE_LIVE_TEST=1 to verify configured Apple credentials")
	}
	client, err := newAppStoreServerClientFromEnvironment()
	if err != nil {
		t.Fatal(err)
	}
	if client == nil {
		t.Fatal("App Store Server API credentials are not configured")
	}
	end := time.Now().UTC()
	start := end.Add(-time.Minute)
	for _, environment := range []string{"Production", "Sandbox"} {
		if _, err := client.getNotificationHistory(context.Background(), environment, start, end, ""); err != nil {
			var apiErr *appStoreAPIError
			if environment == "Production" && os.Getenv("RELAY_APP_STORE_ALLOW_PRERELEASE_PRODUCTION_401") == "1" && errors.As(err, &apiErr) && apiErr.Status == 401 {
				t.Log("Production Server API is unavailable before the first production release; Sandbox credentials are still verified")
				continue
			}
			t.Fatalf("%s App Store Server API credential check failed: %v", environment, err)
		}
	}
}
