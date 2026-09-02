package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"strings"
	"testing"
	"time"
)

func TestAppleStoreCertPoolIncludesAppleRoots(t *testing.T) {
	pool, err := appleStoreCertPool()
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	if pool == nil || len(pool.Subjects()) == 0 {
		t.Fatal("pool must contain the embedded Apple roots")
	}
}

func TestVerifyAppleJWSRejectsMalformedInput(t *testing.T) {
	if _, err := verifyAppleJWS("not-a-jws"); err == nil {
		t.Fatal("malformed JWS must be rejected")
	}
}

func TestVerifyAppleJWSRejectsChainOutsideAppleRoots(t *testing.T) {
	caKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	caTemplate := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Test Root"},
		NotBefore:             now.Add(-time.Hour),
		NotAfter:              now.Add(time.Hour),
		IsCA:                  true,
		KeyUsage:              x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}
	caDER, err := x509.CreateCertificate(rand.Reader, caTemplate, caTemplate, &caKey.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}
	caCert, err := x509.ParseCertificate(caDER)
	if err != nil {
		t.Fatal(err)
	}
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	leafTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "Test Leaf"},
		NotBefore:    now.Add(-time.Hour),
		NotAfter:     now.Add(time.Hour),
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTemplate, caCert, &leafKey.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}

	header, err := json.Marshal(map[string]any{
		"alg": "ES256",
		"x5c": []string{
			base64.StdEncoding.EncodeToString(leafDER),
			base64.StdEncoding.EncodeToString(caDER),
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(map[string]any{"transactionId": "t"})
	if err != nil {
		t.Fatal(err)
	}
	signingInput := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	digest := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, leafKey, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	sigBytes := make([]byte, 64)
	r.FillBytes(sigBytes[:32])
	s.FillBytes(sigBytes[32:])
	jws := signingInput + "." + base64.RawURLEncoding.EncodeToString(sigBytes)

	if _, err := verifyAppleJWS(jws); err == nil {
		t.Fatal("a chain outside the Apple roots must be rejected")
	} else if !strings.Contains(err.Error(), "certificate chain is invalid") {
		t.Fatalf("expected chain rejection, got %v", err)
	}
}
