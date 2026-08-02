package main

import (
	"context"
	"net/http"
	"strings"
	"time"
)

const adminCookieName = "interstellar_admin_session"

type adminContextKey struct{}

// SessionStore persists only hashes of random session tokens in SQLite. A
// process restart no longer logs every administrator out, and logout can
// revoke the server-side record immediately.
type SessionStore struct {
	store *Store
}

func NewSessionStore(store *Store) *SessionStore {
	return &SessionStore{store: store}
}

func (s *SessionStore) Create(username string) (string, time.Time, error) {
	return s.store.CreateAdminSession(username, 12*time.Hour)
}

func (s *SessionStore) Valid(token string) (string, bool) {
	return s.store.ValidateAdminSession(token)
}

func (s *SessionStore) Revoke(token string) {
	s.store.RevokeAdminSession(token)
}

func adminToken(r *http.Request) string {
	if cookie, err := r.Cookie(adminCookieName); err == nil && cookie.Value != "" {
		return cookie.Value
	}
	auth := r.Header.Get("Authorization")
	return strings.TrimPrefix(auth, "Bearer ")
}

func setAdminCookie(w http.ResponseWriter, token string, expires time.Time) {
	http.SetCookie(w, &http.Cookie{
		Name:     adminCookieName,
		Value:    token,
		Path:     "/",
		Expires:  expires,
		MaxAge:   int(time.Until(expires).Seconds()),
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteStrictMode,
	})
}

func clearAdminCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     adminCookieName,
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteStrictMode,
	})
}

func requireAdmin(sessions *SessionStore, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		username, ok := sessions.Valid(adminToken(r))
		if !ok {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "unauthorized", "code": "admin_unauthorized"})
			return
		}
		ctx := context.WithValue(r.Context(), adminContextKey{}, username)
		next(w, r.WithContext(ctx))
	}
}

func adminUsername(r *http.Request) string {
	username, _ := r.Context().Value(adminContextKey{}).(string)
	return username
}
