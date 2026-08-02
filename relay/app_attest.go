package main

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/sha256"
	"crypto/x509"
	"encoding/asn1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/fxamacker/cbor/v2"
)

const appleAppAttestationRoot = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`

const (
	appAttestPurposeAttest    = "attest"
	appAttestPurposeAssertion = "assertion"
	appAttestChallengeTTL     = 5 * time.Minute
	appAttestTokenTTL         = 15 * time.Minute
)

type appAttestConfig struct {
	store            *Store
	appID            string
	environment      string
	allowDevelopment bool
	bundleVersion    string
	rootPool         *x509.CertPool
}

func newAppAttestConfig(store *Store, appID, environment, bundleVersion string, allowDevelopment bool) (*appAttestConfig, error) {
	if strings.TrimSpace(appID) == "" {
		return nil, errors.New("RELAY_APP_ATTEST_APP_ID must be set")
	}
	if environment != "development" && environment != "production" {
		return nil, errors.New("RELAY_APP_ATTEST_ENVIRONMENT must be development or production")
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM([]byte(appleAppAttestationRoot)) {
		return nil, errors.New("could not load Apple App Attestation root")
	}
	return &appAttestConfig{
		store: store, appID: appID, environment: environment, allowDevelopment: allowDevelopment,
		bundleVersion: bundleVersion, rootPool: pool,
	}, nil
}

type appAttestChallengeRequest struct {
	InstallationID string `json:"installationID"`
	KeyID          string `json:"keyID"`
	Purpose        string `json:"purpose"`
	BodyHash       string `json:"bodyHash"`
}

func (a *appAttestConfig) handleChallenge(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	var req appAttestChallengeRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid challenge request", false)
		return
	}
	req.InstallationID = strings.TrimSpace(req.InstallationID)
	req.KeyID = strings.TrimSpace(req.KeyID)
	if req.InstallationID == "" || (req.Purpose != appAttestPurposeAttest && req.Purpose != appAttestPurposeAssertion) {
		writeError(w, http.StatusBadRequest, "invalid_challenge", "installationID and valid purpose are required", false)
		return
	}
	if req.Purpose == appAttestPurposeAssertion {
		if req.KeyID == "" || !validSHA256Base64(req.BodyHash) {
			writeError(w, http.StatusBadRequest, "invalid_challenge", "keyID and SHA-256 bodyHash are required", false)
			return
		}
		if _, err := a.store.GetAppAttestKey(req.KeyID, req.InstallationID); err != nil {
			writeError(w, http.StatusUnauthorized, "attestation_required", "installation must be attested first", false)
			return
		}
	} else if req.KeyID == "" {
		writeError(w, http.StatusBadRequest, "invalid_challenge", "keyID is required", false)
		return
	}
	challengeID, challenge, expires, err := a.store.CreateAppAttestChallenge(
		req.InstallationID, req.KeyID, req.Purpose, req.BodyHash, appAttestChallengeTTL,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "challenge_unavailable", "could not create challenge", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"challengeID": challengeID,
		"challenge":   base64.StdEncoding.EncodeToString(challenge),
		"expiresAt":   expires.Format(time.RFC3339),
	})
}

type appAttestAttestationRequest struct {
	InstallationID    string `json:"installationID"`
	KeyID             string `json:"keyID"`
	ChallengeID       string `json:"challengeID"`
	AttestationObject string `json:"attestationObject"`
}

func (a *appAttestConfig) handleAttestation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	var req appAttestAttestationRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "invalid attestation request", false)
		return
	}
	challenge, err := a.store.ConsumeAppAttestChallenge(
		req.ChallengeID, req.InstallationID, req.KeyID, appAttestPurposeAttest, "",
	)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "challenge_invalid", err.Error(), false)
		return
	}
	object, err := base64.StdEncoding.DecodeString(req.AttestationObject)
	if err != nil {
		writeError(w, http.StatusBadRequest, "attestation_invalid", "attestationObject must be base64", false)
		return
	}
	verified, err := a.verifyAttestation(object, req.KeyID, challenge)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "attestation_invalid", err.Error(), false)
		return
	}
	if err := a.store.SaveAppAttestKey(verified.AppAttestKey, req.InstallationID, verified.receipt); err != nil {
		writeError(w, http.StatusInternalServerError, "attestation_store_failed", "could not store attested key", true)
		return
	}
	token, expires, err := a.store.CreateAppAttestToken(req.KeyID, req.InstallationID, appAttestTokenTTL)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_create_failed", "could not create installation token", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": token, "expiresAt": expires.Format(time.RFC3339), "environment": verified.Environment,
	})
}

type verifiedAttestation struct {
	AppAttestKey
	receipt []byte
}

type appleAttestationObject struct {
	Format    string                    `cbor:"fmt"`
	Statement appleAttestationStatement `cbor:"attStmt"`
	AuthData  []byte                    `cbor:"authData"`
}

type appleAttestationStatement struct {
	Certificates [][]byte `cbor:"x5c"`
	Receipt      []byte   `cbor:"receipt"`
}

type parsedAuthenticatorData struct {
	RPIDHash     []byte
	Flags        byte
	Counter      uint32
	AAGUID       []byte
	CredentialID []byte
	Extensions   map[string]any
}

func (a *appAttestConfig) verifyAttestation(object []byte, keyID string, challenge []byte) (*verifiedAttestation, error) {
	var value appleAttestationObject
	if err := cbor.Unmarshal(object, &value); err != nil {
		return nil, fmt.Errorf("invalid attestation CBOR: %w", err)
	}
	if value.Format != "apple-appattest" || len(value.Statement.Certificates) < 2 {
		return nil, errors.New("unexpected App Attest format or certificate chain")
	}
	auth, err := parseAuthenticatorData(value.AuthData, true)
	if err != nil {
		return nil, err
	}
	attestationEnvironment, err := a.attestationEnvironment(auth)
	if err != nil {
		return nil, err
	}
	if err := a.validateAuthenticator(auth, true, attestationEnvironment); err != nil {
		return nil, err
	}
	keyIDBytes, err := decodeBase64Any(keyID)
	if err != nil || len(keyIDBytes) != sha256.Size {
		return nil, errors.New("invalid App Attest key identifier")
	}
	if !bytes.Equal(auth.CredentialID, keyIDBytes) {
		return nil, errors.New("credential identifier does not match key identifier")
	}
	leaf, err := x509.ParseCertificate(value.Statement.Certificates[0])
	if err != nil {
		return nil, errors.New("invalid credential certificate")
	}
	intermediates := x509.NewCertPool()
	for _, raw := range value.Statement.Certificates[1:] {
		certificate, parseErr := x509.ParseCertificate(raw)
		if parseErr != nil {
			return nil, errors.New("invalid intermediate certificate")
		}
		intermediates.AddCert(certificate)
	}
	if _, err := leaf.Verify(x509.VerifyOptions{Roots: a.rootPool, Intermediates: intermediates, CurrentTime: time.Now()}); err != nil {
		return nil, fmt.Errorf("App Attest certificate chain failed: %w", err)
	}
	publicKey, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok || publicKey.Curve != elliptic.P256() {
		return nil, errors.New("credential certificate does not contain a P-256 key")
	}
	keyHash := sha256.Sum256(elliptic.Marshal(publicKey.Curve, publicKey.X, publicKey.Y))
	if !bytes.Equal(keyHash[:], keyIDBytes) {
		return nil, errors.New("credential public key does not match key identifier")
	}
	challengeHash := sha256.Sum256(challenge)
	composite := append(append([]byte{}, value.AuthData...), challengeHash[:]...)
	nonce := sha256.Sum256(composite)
	certNonce, err := appAttestCertificateNonce(leaf)
	if err != nil || !bytes.Equal(certNonce, nonce[:]) {
		return nil, errors.New("attestation challenge nonce mismatch")
	}
	publicKeyDER, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		return nil, err
	}
	return &verifiedAttestation{
		AppAttestKey: AppAttestKey{
			KeyID: keyID, PublicKeyDER: publicKeyDER, SignCount: 0, Environment: attestationEnvironment,
		},
		receipt: value.Statement.Receipt,
	}, nil
}

var appAttestNonceOID = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 2}

func appAttestCertificateNonce(certificate *x509.Certificate) ([]byte, error) {
	for _, extension := range certificate.Extensions {
		if extension.Id.Equal(appAttestNonceOID) {
			var container struct {
				Nonce []byte `asn1:"tag:1,explicit"`
			}
			if rest, err := asn1.Unmarshal(extension.Value, &container); err != nil || len(rest) != 0 || len(container.Nonce) != sha256.Size {
				return nil, errors.New("invalid App Attest nonce extension")
			}
			return container.Nonce, nil
		}
	}
	return nil, errors.New("App Attest nonce extension is missing")
}

func parseAuthenticatorData(data []byte, requireAttestedCredential bool) (*parsedAuthenticatorData, error) {
	if len(data) < 37 {
		return nil, errors.New("authenticator data is too short")
	}
	auth := &parsedAuthenticatorData{
		RPIDHash: append([]byte{}, data[:32]...), Flags: data[32], Counter: binary.BigEndian.Uint32(data[33:37]),
	}
	rest := data[37:]
	if auth.Flags&0x40 != 0 {
		if len(rest) < 18 {
			return nil, errors.New("attested credential data is incomplete")
		}
		auth.AAGUID = append([]byte{}, rest[:16]...)
		credentialLength := int(binary.BigEndian.Uint16(rest[16:18]))
		rest = rest[18:]
		if credentialLength == 0 || len(rest) < credentialLength {
			return nil, errors.New("credential identifier is incomplete")
		}
		auth.CredentialID = append([]byte{}, rest[:credentialLength]...)
		rest = rest[credentialLength:]
		var coseKey map[int]any
		var err error
		rest, err = cbor.UnmarshalFirst(rest, &coseKey)
		if err != nil {
			return nil, errors.New("credential public key is invalid CBOR")
		}
	} else if requireAttestedCredential {
		return nil, errors.New("attested credential flag is missing")
	}
	if auth.Flags&0x80 != 0 {
		if err := cbor.Unmarshal(rest, &auth.Extensions); err != nil {
			return nil, errors.New("authenticator extensions are invalid CBOR")
		}
	} else if len(rest) != 0 {
		return nil, errors.New("unexpected trailing authenticator data")
	}
	return auth, nil
}

func (a *appAttestConfig) attestationEnvironment(auth *parsedAuthenticatorData) (string, error) {
	productionAAGUID := append([]byte("appattest"), make([]byte, 7)...)
	switch {
	case bytes.Equal(auth.AAGUID, productionAAGUID):
		if a.environment != "production" {
			return "", errors.New("production App Attest is not enabled")
		}
		return "production", nil
	case bytes.Equal(auth.AAGUID, []byte("appattestdevelop")):
		if a.environment != "development" && !a.allowDevelopment {
			return "", errors.New("development App Attest is not enabled")
		}
		return "development", nil
	default:
		return "", errors.New("App Attest environment mismatch")
	}
}

func (a *appAttestConfig) validateAuthenticator(auth *parsedAuthenticatorData, attestation bool, keyEnvironment string) error {
	expectedRPID := sha256.Sum256([]byte(a.appID))
	if !bytes.Equal(auth.RPIDHash, expectedRPID[:]) {
		return errors.New("App ID hash mismatch")
	}
	if attestation {
		if auth.Counter != 0 {
			return errors.New("initial attestation counter must be zero")
		}
	}
	if keyEnvironment != "production" && keyEnvironment != "development" {
		return errors.New("stored App Attest environment is invalid")
	}
	if keyEnvironment == "development" && a.environment != "development" && !a.allowDevelopment {
		return errors.New("development App Attest is not enabled")
	}
	if auth.Extensions == nil {
		return errors.New("App Attest validation extensions are missing")
	}
	category, ok := uint32Extension(auth.Extensions["apple_validation_category_01"])
	if !ok || category == 0 || category > 6 {
		return errors.New("invalid App Attest validation category")
	}
	if keyEnvironment == "production" && category == 3 {
		return errors.New("development-signed app is not allowed in production")
	}
	bundleVersion, ok := auth.Extensions["apple_bundle_version_01"].(string)
	if !ok || (a.bundleVersion != "" && bundleVersion != a.bundleVersion) {
		return errors.New("App Attest bundle version mismatch")
	}
	return nil
}

func uint32Extension(value any) (uint32, bool) {
	switch typed := value.(type) {
	case uint64:
		return uint32(typed), typed <= ^uint64(0)>>32
	case uint32:
		return typed, true
	case []byte:
		if len(typed) == 4 {
			return binary.LittleEndian.Uint32(typed), true
		}
	}
	return 0, false
}

type appAttestClientData struct {
	ChallengeID string `json:"challengeID"`
	Challenge   string `json:"challenge"`
	BodyHash    string `json:"bodyHash"`
}

type appleAssertionObject struct {
	Signature []byte `cbor:"signature"`
	AuthData  []byte `cbor:"authenticatorData"`
}

func (a *appAttestConfig) verifyGenerateRequest(r *http.Request, body []byte, installationID string) error {
	return a.verifyRequestAssertion(r, body, installationID, true)
}

func (a *appAttestConfig) verifyRequestAssertion(r *http.Request, body []byte, installationID string, requireToken bool) error {
	keyID := strings.TrimSpace(r.Header.Get("X-App-Attest-Key-ID"))
	token := strings.TrimSpace(r.Header.Get("X-App-Attest-Token"))
	challengeID := strings.TrimSpace(r.Header.Get("X-App-Attest-Challenge-ID"))
	clientDataRaw, err := base64.StdEncoding.DecodeString(r.Header.Get("X-App-Attest-Client-Data"))
	if err != nil {
		return errors.New("invalid App Attest client data")
	}
	assertionRaw, err := base64.StdEncoding.DecodeString(r.Header.Get("X-App-Attest-Assertion"))
	if err != nil {
		return errors.New("invalid App Attest assertion")
	}
	if requireToken && !a.store.ValidateAppAttestToken(token, keyID, installationID) {
		return errors.New("installation token is missing or expired")
	}
	bodyHashBytes := sha256.Sum256(body)
	bodyHash := base64.StdEncoding.EncodeToString(bodyHashBytes[:])
	challenge, err := a.store.ConsumeAppAttestChallenge(
		challengeID, installationID, keyID, appAttestPurposeAssertion, bodyHash,
	)
	if err != nil {
		return err
	}
	var clientData appAttestClientData
	if err := json.Unmarshal(clientDataRaw, &clientData); err != nil ||
		clientData.ChallengeID != challengeID || clientData.BodyHash != bodyHash ||
		clientData.Challenge != base64.StdEncoding.EncodeToString(challenge) {
		return errors.New("assertion client data is not bound to this request")
	}
	key, err := a.store.GetAppAttestKey(keyID, installationID)
	if err != nil {
		return errors.New("attested key not found")
	}
	var assertion appleAssertionObject
	if err := cbor.Unmarshal(assertionRaw, &assertion); err != nil {
		return errors.New("assertion is invalid CBOR")
	}
	auth, err := parseAuthenticatorData(assertion.AuthData, false)
	if err != nil {
		return err
	}
	if err := a.validateAuthenticator(auth, false, key.Environment); err != nil {
		return err
	}
	if auth.Counter <= key.SignCount {
		return errors.New("assertion counter was replayed")
	}
	parsed, err := x509.ParsePKIXPublicKey(key.PublicKeyDER)
	if err != nil {
		return errors.New("stored attested key is invalid")
	}
	publicKey, ok := parsed.(*ecdsa.PublicKey)
	if !ok {
		return errors.New("stored attested key is not ECDSA")
	}
	clientDataHash := sha256.Sum256(clientDataRaw)
	signed := append(append([]byte{}, assertion.AuthData...), clientDataHash[:]...)
	nonce := sha256.Sum256(signed)
	if !ecdsa.VerifyASN1(publicKey, nonce[:], assertion.Signature) {
		return errors.New("App Attest assertion signature is invalid")
	}
	return a.store.UpdateAppAttestCounter(keyID, installationID, key.SignCount, auth.Counter)
}

type appAttestTokenRequest struct {
	InstallationID string `json:"installationID"`
	KeyID          string `json:"keyID"`
}

func (a *appAttestConfig) handleToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST required", false)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 64<<10))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "could not read token request", false)
		return
	}
	var req appAttestTokenRequest
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&req); err != nil || req.InstallationID == "" || req.KeyID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "installationID and keyID are required", false)
		return
	}
	if strings.TrimSpace(r.Header.Get("X-App-Attest-Key-ID")) != req.KeyID {
		writeError(w, http.StatusUnauthorized, "app_attest_invalid", "key ID mismatch", false)
		return
	}
	if err := a.verifyRequestAssertion(r, body, req.InstallationID, false); err != nil {
		writeError(w, http.StatusUnauthorized, "app_attest_invalid", err.Error(), false)
		return
	}
	token, expires, err := a.store.CreateAppAttestToken(req.KeyID, req.InstallationID, appAttestTokenTTL)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_create_failed", "could not create installation token", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "expiresAt": expires.Format(time.RFC3339)})
}

func validSHA256Base64(value string) bool {
	decoded, err := base64.StdEncoding.DecodeString(value)
	return err == nil && len(decoded) == sha256.Size
}

func decodeBase64Any(value string) ([]byte, error) {
	for _, encoding := range []*base64.Encoding{
		base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding,
	} {
		if decoded, err := encoding.DecodeString(value); err == nil {
			return decoded, nil
		}
	}
	return nil, errors.New("invalid base64")
}
