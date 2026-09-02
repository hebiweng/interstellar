package main

import (
	_ "embed"
	"net/http"
)

//go:embed admin.html
var adminPage []byte

func handleAdminPage(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && r.URL.Path != "/xiaoguiwk" && r.URL.Path != "/xiaoguiwk/" {
		writeError(w, http.StatusNotFound, "not_found", "not found", false)
		return
	}
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET required", false)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Security-Policy", "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
	_, _ = w.Write(adminPage)
}
