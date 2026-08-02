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
	"net/http"
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
	authData = append(authData, 0x80)
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
	signature, err := ecdsa.SignASN1(rand.Reader, privateKey, nonce[:])
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
