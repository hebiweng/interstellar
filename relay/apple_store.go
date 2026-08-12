package main

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"strings"
)

func verifyAppleTransactionJWS(jws string) (AppleTransactionPayload, error) {
	payload, err := verifyAppleJWS(jws)
	if err != nil {
		return AppleTransactionPayload{}, err
	}
	var value AppleTransactionPayload
	if err := json.Unmarshal(payload, &value); err != nil {
		return AppleTransactionPayload{}, err
	}
	return value, nil
}

func verifyAppleJWS(jws string) ([]byte, error) {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid Apple JWS")
	}
	headerRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, err
	}
	var header struct {
		Algorithm    string   `json:"alg"`
		Certificates []string `json:"x5c"`
	}
	if err = json.Unmarshal(headerRaw, &header); err != nil {
		return nil, err
	}
	if header.Algorithm != "ES256" || len(header.Certificates) < 2 {
		return nil, errors.New("unsupported Apple signature")
	}
	certificates := make([]*x509.Certificate, 0, len(header.Certificates))
	for _, encoded := range header.Certificates {
		der, e := base64.StdEncoding.DecodeString(encoded)
		if e != nil {
			return nil, e
		}
		cert, e := x509.ParseCertificate(der)
		if e != nil {
			return nil, e
		}
		certificates = append(certificates, cert)
	}
	roots, err := x509.SystemCertPool()
	if err != nil {
		return nil, err
	}
	intermediates := x509.NewCertPool()
	for _, cert := range certificates[1:] {
		intermediates.AddCert(cert)
	}
	if _, err = certificates[0].Verify(x509.VerifyOptions{Roots: roots, Intermediates: intermediates}); err != nil {
		return nil, errors.New("Apple certificate chain is invalid")
	}
	key, ok := certificates[0].PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("Apple signing key is not ECDSA")
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(signature) != 64 {
		return nil, errors.New("invalid Apple signature")
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if !ecdsa.Verify(key, digest[:], new(big.Int).SetBytes(signature[:32]), new(big.Int).SetBytes(signature[32:])) {
		return nil, errors.New("Apple signature verification failed")
	}
	return base64.RawURLEncoding.DecodeString(parts[1])
}
