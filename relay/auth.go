package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
	"sync"
	"time"
)

// SessionStore is an in-memory admin session registry. Tokens expire after
// 12 hours and are HMAC-signed so they cannot be forged without RELAY_SECRET.
type SessionStore struct {
	mu     sync.Mutex
	secret []byte
	tokens map[string]time.Time
}

func NewSessionStore(secret string) *SessionStore {
	return &SessionStore{secret: []byte(secret), tokens: map[string]time.Time{}}
}

func (s *SessionStore) sign(username string, expires time.Time) string {
	mac := hmac.New(sha256.New, s.secret)
	mac.Write([]byte("session:" + username + ":" + expires.UTC().Format(time.RFC3339)))
	return hex.EncodeToString(mac.Sum(nil))
}

func (s *SessionStore) Create(username string) (string, time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	expires := time.Now().UTC().Add(12 * time.Hour)
	token := s.sign(username, expires)
	s.tokens[token] = expires
	return token, expires
}

func (s *SessionStore) Valid(token string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	expires, ok := s.tokens[token]
	if !ok {
		return false
	}
	if time.Now().UTC().After(expires) {
		delete(s.tokens, token)
		return false
	}
	return true
}

func (s *SessionStore) Revoke(token string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.tokens, token)
}

func requireAdmin(sessions *SessionStore, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		token := strings.TrimPrefix(auth, "Bearer ")
		if token == "" || !sessions.Valid(token) {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "unauthorized"})
			return
		}
		next(w, r)
	}
}
