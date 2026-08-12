package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

func TestGenerateFallsBackFromLowThinkingToDisabled(t *testing.T) {
	var thinkingModes []string
	var reasoningEfforts []string
	var maxTokens []int
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request struct {
			MaxTokens       int    `json:"max_tokens"`
			ReasoningEffort string `json:"reasoning_effort"`
			Thinking        struct {
				Type string `json:"type"`
			} `json:"thinking"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Fatal(err)
		}
		thinkingModes = append(thinkingModes, request.Thinking.Type)
		reasoningEfforts = append(reasoningEfforts, request.ReasoningEffort)
		maxTokens = append(maxTokens, request.MaxTokens)

		content := `not-json`
		if len(thinkingModes) == 2 {
			content = `{"report":{"title":"Transit report","subtitle":"Current patterns","sections":[` +
				`{"number":"01","title":"Theme","body":"Current evidence supports this theme.","evidenceFactIDs":["fact.1"]},` +
				`{"number":"02","title":"Context","body":"The same evidence supplies context.","evidenceFactIDs":["fact.1"]},` +
				`{"number":"03","title":"Response","body":"A measured response fits the evidence.","evidenceFactIDs":["fact.1"]},` +
				`{"number":"04","title":"Focus","body":"Keep attention on the supplied fact.","evidenceFactIDs":["fact.1"]}` +
				`]}}`
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"model": "deepseek-v4-flash",
			"choices": []map[string]any{{
				"message":       map[string]any{"role": "assistant", "content": content},
				"finish_reason": "stop",
			}},
			"usage": map[string]any{"prompt_tokens": 10, "completion_tokens": 20},
		})
	}))
	defer server.Close()

	result, _, _, _, _, err := Generate(
		context.Background(), server.Client(), server.URL, "key", "deepseek-v4-flash",
		"Return JSON.", `{"evidenceFacts":[{"id":"fact.1"}]}`, "en", map[string]bool{"fact.1": true},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result == nil || len(result.Report.Sections) != 4 {
		t.Fatal("fallback did not return the valid report")
	}
	if !reflect.DeepEqual(thinkingModes, []string{"enabled", "disabled"}) {
		t.Fatalf("thinking modes = %v", thinkingModes)
	}
	if !reflect.DeepEqual(reasoningEfforts, []string{"low", ""}) {
		t.Fatalf("reasoning efforts = %v", reasoningEfforts)
	}
	if !reflect.DeepEqual(maxTokens, []int{10000, 10000}) {
		t.Fatalf("max tokens = %v", maxTokens)
	}
}
