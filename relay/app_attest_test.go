package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/fxamacker/cbor/v2"
)

func TestAppAttestAssertionBindsBodyAndRejectsReplay(t *testing.T) {
	store := openTestStore(t)
	config, err := newAppAttestConfig(store, "TEAM.example.interstellar", "development", "1", false)
	if err != nil {
		t.Fatal(err)
	}
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	publicKeyDER, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	const installationID = "install-a"
	const keyID = "key-a"
	if err := store.SaveAppAttestKey(AppAttestKey{
		KeyID: keyID, PublicKeyDER: publicKeyDER, Environment: "development",
	}, installationID, []byte("receipt")); err != nil {
		t.Fatal(err)
	}
	token, _, err := store.CreateAppAttestToken(keyID, installationID, time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	body := []byte(`{"chartKind":"natal"}`)
	bodyDigest := sha256.Sum256(body)
	bodyHash := base64.StdEncoding.EncodeToString(bodyDigest[:])
	challengeID, challenge, _, err := store.CreateAppAttestChallenge(
		installationID, keyID, appAttestPurposeAssertion, bodyHash, time.Minute,
	)
	if err != nil {
		t.Fatal(err)
	}
	clientData, err := json.Marshal(appAttestClientData{
		ChallengeID: challengeID,
		Challenge:   base64.StdEncoding.EncodeToString(challenge),
		BodyHash:    bodyHash,
	})
	if err != nil {
		t.Fatal(err)
	}
	rpID := sha256.Sum256([]byte(config.appID))
	authData := append([]byte{}, rpID[:]...)
	// Assertions on current Apple devices retain 0x40; iOS 27+ may also append
	// the extension data indicated by 0x80.
	authData = append(authData, 0xC0)
	counter := make([]byte, 4)
	binary.BigEndian.PutUint32(counter, 1)
	authData = append(authData, counter...)
	extensions, err := cbor.Marshal(map[string]any{
		"apple_validation_category_01": uint64(3),
		"apple_bundle_version_01":      "1",
	})
	if err != nil {
		t.Fatal(err)
	}
	authData = append(authData, extensions...)
	clientHash := sha256.Sum256(clientData)
	signed := append(append([]byte{}, authData...), clientHash[:]...)
	nonce := sha256.Sum256(signed)
	signatureDigest := sha256.Sum256(nonce[:])
	signature, err := ecdsa.SignASN1(rand.Reader, privateKey, signatureDigest[:])
	if err != nil {
		t.Fatal(err)
	}
	assertion, err := cbor.Marshal(appleAssertionObject{Signature: signature, AuthData: authData})
	if err != nil {
		t.Fatal(err)
	}
	req, err := http.NewRequest(http.MethodPost, "/v1/generate", strings.NewReader(string(body)))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("X-App-Attest-Key-ID", keyID)
	req.Header.Set("X-App-Attest-Token", token)
	req.Header.Set("X-App-Attest-Challenge-ID", challengeID)
	req.Header.Set("X-App-Attest-Client-Data", base64.StdEncoding.EncodeToString(clientData))
	req.Header.Set("X-App-Attest-Assertion", base64.StdEncoding.EncodeToString(assertion))
	if err := config.verifyGenerateRequest(req, body, installationID); err != nil {
		t.Fatalf("valid assertion was rejected: %v", err)
	}
	if err := config.verifyGenerateRequest(req, body, installationID); err == nil {
		t.Fatal("replayed assertion was accepted")
	}
}

func TestAppAttestAssertionSignatureUsesECDSASHA256OverNonce(t *testing.T) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	nonce := sha256.Sum256([]byte("authenticator-data-and-client-data-hash"))
	digest := sha256.Sum256(nonce[:])
	validSignature, err := ecdsa.SignASN1(rand.Reader, privateKey, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	if !verifyAppAttestAssertionSignature(&privateKey.PublicKey, nonce[:], validSignature) {
		t.Fatal("valid ECDSA-SHA256 App Attest signature was rejected")
	}

	legacySingleHashSignature, err := ecdsa.SignASN1(rand.Reader, privateKey, nonce[:])
	if err != nil {
		t.Fatal(err)
	}
	if verifyAppAttestAssertionSignature(&privateKey.PublicKey, nonce[:], legacySingleHashSignature) {
		t.Fatal("signature that incorrectly treats nonce as the digest was accepted")
	}
}

func TestAppVerificationResponseDoesNotExposeVerifierFailure(t *testing.T) {
	recorder := httptest.NewRecorder()
	writeAppVerificationError(recorder, http.StatusUnauthorized, "app_attest_invalid", false)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusUnauthorized)
	}
	responseBody := recorder.Body.String()
	for _, internalDetail := range []string{"signature", "certificate", "credential", "x509", "counter"} {
		if strings.Contains(strings.ToLower(responseBody), internalDetail) {
			t.Fatalf("consumer response exposed verifier detail %q: %s", internalDetail, responseBody)
		}
	}
	if !strings.Contains(responseBody, `"code":"app_attest_invalid"`) {
		t.Fatalf("consumer response lost stable error code: %s", responseBody)
	}
}

func TestProductionConfigCanExplicitlyAcceptCryptographicDevelopmentAttestations(t *testing.T) {
	store := openTestStore(t)
	productionOnly, err := newAppAttestConfig(store, "TEAM.example.interstellar", "production", "1", false)
	if err != nil {
		t.Fatal(err)
	}
	dual, err := newAppAttestConfig(store, "TEAM.example.interstellar", "production", "1", true)
	if err != nil {
		t.Fatal(err)
	}
	auth := &parsedAuthenticatorData{AAGUID: []byte("appattestdevelop")}
	if _, err := productionOnly.attestationEnvironment(auth); err == nil {
		t.Fatal("production-only config accepted a development AAGUID")
	}
	if environment, err := dual.attestationEnvironment(auth); err != nil || environment != "development" {
		t.Fatalf("dual environment rejected a valid development AAGUID: environment=%q err=%v", environment, err)
	}
}

func TestBundleVersionPolicySupportsFutureBuildsWithoutDisablingValidation(t *testing.T) {
	policy, err := parseBundleVersionPolicy("1+,20-22,7")
	if err != nil {
		t.Fatal(err)
	}
	for _, version := range []string{"1", "6", "20", "22"} {
		if !policy.matches(version) {
			t.Fatalf("version %s was rejected", version)
		}
	}
	for _, version := range []string{"", "-1", "abc"} {
		if policy.matches(version) {
			t.Fatalf("invalid version %q was accepted", version)
		}
	}
	if _, err := parseBundleVersionPolicy("22-20"); err == nil {
		t.Fatal("reversed bundle version range was accepted")
	}
}

func TestAuthenticatorAcceptsLegacyPayloadWithoutValidationExtensions(t *testing.T) {
	store := openTestStore(t)
	const appID = "TEAM.example.interstellar"
	config, err := newAppAttestConfig(store, appID, "development", "1", false)
	if err != nil {
		t.Fatal(err)
	}
	rpID := sha256.Sum256([]byte(appID))
	auth := &parsedAuthenticatorData{RPIDHash: rpID[:]}
	if err := config.validateAuthenticator(auth, true, "development"); err != nil {
		t.Fatalf("legacy authenticator data was rejected: %v", err)
	}
}

func TestAuthenticatorStillRejectsInvalidValidationExtensions(t *testing.T) {
	store := openTestStore(t)
	const appID = "TEAM.example.interstellar"
	config, err := newAppAttestConfig(store, appID, "development", "1", false)
	if err != nil {
		t.Fatal(err)
	}
	rpID := sha256.Sum256([]byte(appID))
	auth := &parsedAuthenticatorData{
		RPIDHash: rpID[:],
		Extensions: map[string]any{
			"apple_validation_category_01": uint64(0),
			"apple_bundle_version_01":      "1",
		},
	}
	if err := config.validateAuthenticator(auth, true, "development"); err == nil {
		t.Fatal("invalid validation category was accepted")
	}
}

func TestAppAttestCertificateChainDoesNotAssumeTLSServerUsage(t *testing.T) {
	now := time.Now()
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	rootTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(1), NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour),
		IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign,
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	root, err := x509.ParseCertificate(rootDER)
	if err != nil {
		t.Fatal(err)
	}
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	leafTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(2), NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour),
		KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageCodeSigning},
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTemplate, root, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	leaf, err := x509.ParseCertificate(leafDER)
	if err != nil {
		t.Fatal(err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(root)
	if _, err := leaf.Verify(x509.VerifyOptions{Roots: roots, CurrentTime: now}); err == nil {
		t.Fatal("test certificate unexpectedly passed the default TLS server usage")
	}
	if err := verifyAppAttestCertificateChain(leaf, x509.NewCertPool(), roots, now); err != nil {
		t.Fatalf("valid non-TLS attestation chain was rejected: %v", err)
	}
}

func TestLegacyAssertionWithAttestedCredentialFlagHasNoCredentialPayload(t *testing.T) {
	appIDHash := sha256.Sum256([]byte("TEAM.example.interstellar"))
	authenticatorData := make([]byte, 37)
	copy(authenticatorData[:32], appIDHash[:])
	authenticatorData[32] = 0x40
	binary.BigEndian.PutUint32(authenticatorData[33:37], 1)

	auth, err := parseAuthenticatorData(authenticatorData, false)
	if err != nil {
		t.Fatalf("valid 37-byte legacy assertion was rejected: %v", err)
	}
	if auth.Flags != 0x40 || auth.Counter != 1 || auth.Extensions != nil {
		t.Fatalf("legacy assertion parsed incorrectly: flags=%#x counter=%d extensions=%v", auth.Flags, auth.Counter, auth.Extensions)
	}
	if _, err := parseAuthenticatorData(authenticatorData, true); err == nil {
		t.Fatal("the same payload was incorrectly accepted as an initial attestation")
	}
}
