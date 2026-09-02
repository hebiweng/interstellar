package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
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

func mustParseResult(t *testing.T, raw string) *GenerationResult {
	t.Helper()
	var result GenerationResult
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		t.Fatalf("parse: %v", err)
	}
	return &result
}

func TestParseGenerationResultAcceptsTopLevelShape(t *testing.T) {
	result, err := parseGenerationResult(`{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"}]}`, "en")
	if err != nil {
		t.Fatal(err)
	}
	if result.Report.Title != "T" || result.Report.Subtitle != "S" || len(result.Report.Sections) != 1 {
		t.Fatalf("top-level shape must be normalized: %+v", result.Report)
	}
	if err := result.Validate("en", nil); err != nil {
		t.Fatalf("normalized report must validate: %v", err)
	}
	wrapped, err := parseGenerationResult(`{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"}]}}`, "en")
	if err != nil || len(wrapped.Report.Sections) != 1 {
		t.Fatalf("wrapped shape must still parse: %+v err=%v", wrapped, err)
	}
}

func TestParseGenerationResultFlattensLayeredNatalReport(t *testing.T) {
	raw := `{"report":{"title":"本命","subtitle":"全景","coreSections":[{"number":"01","title":"核心自我","body":"核心","evidenceFactIDs":["fact.1"]}],"houses":[{"house":1,"title":"自我","body":"一宫","evidenceFactIDs":["fact.1"]},{"house":2,"title":"金钱","body":"二宫","evidenceFactIDs":["fact.1"]}],"chartSignatures":[{"number":"S1","title":"主题","body":"综合","evidenceFactIDs":["fact.1"]}],"closing":{"body":"总结","evidenceFactIDs":["fact.1"]}}}`
	result, err := parseGenerationResult(raw, "zh-Hans")
	if err != nil {
		t.Fatal(err)
	}
	if result.Report.Title != "本命" || result.Report.Subtitle != "全景" {
		t.Fatalf("heading lost: %+v", result.Report)
	}
	if len(result.Report.Sections) != 5 {
		t.Fatalf("expected 5 flattened sections, got %d", len(result.Report.Sections))
	}
	if result.Report.Sections[1].Number != "01" || result.Report.Sections[1].Title != "自我" {
		t.Fatalf("house section not normalized: %+v", result.Report.Sections[1])
	}
	closing := result.Report.Sections[4]
	if closing.Title != "总结" || closing.Body != "总结" {
		t.Fatalf("closing title must be filled: %+v", closing)
	}
	if err := result.Validate("zh-Hans", map[string]bool{"fact.1": true}); err != nil {
		t.Fatalf("flattened report must validate: %v", err)
	}
}

func TestWithOutputContractAppendsSchemaOnce(t *testing.T) {
	en := withOutputContract("Write about the chart.", "en")
	if !strings.Contains(en, `"sections"`) || !strings.Contains(en, "non-negotiable") {
		t.Fatalf("english contract missing: %q", en)
	}
	zh := withOutputContract("写解读。", "zh-Hans")
	if !strings.Contains(zh, `"sections"`) || !strings.Contains(zh, "输出契约") {
		t.Fatalf("chinese contract missing: %q", zh)
	}
	if again := withOutputContract(en, "en"); again != en {
		t.Fatal("contract must not be appended twice")
	}
}

func TestValidateAcceptsAnySectionCount(t *testing.T) {
	two := mustParseResult(t, `{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"},{"number":"02","title":"B","body":"y"}]}}`)
	if err := two.Validate("en", nil); err != nil {
		t.Fatalf("two sections must pass: %v", err)
	}
	sections := ""
	for i := 0; i < 10; i++ {
		if i > 0 {
			sections += ","
		}
		sections += `{"number":"01","title":"A","body":"x"}`
	}
	ten := mustParseResult(t, `{"report":{"title":"T","subtitle":"S","sections":[`+sections+`]}}`)
	if err := ten.Validate("zh-Hans", nil); err != nil {
		t.Fatalf("ten sections must pass: %v", err)
	}
}

func TestValidateFiltersUnknownEvidenceAndFillsNumber(t *testing.T) {
	result := mustParseResult(t, `{"report":{"title":"T","subtitle":"S","sections":[{"number":"","title":"A","body":"x","evidenceFactIDs":["fact.1","fact.unknown"]}]}}`)
	if err := result.Validate("en", map[string]bool{"fact.1": true}); err != nil {
		t.Fatal(err)
	}
	section := result.Report.Sections[0]
	if section.Number != "01" {
		t.Fatalf("missing number must be auto-filled: %q", section.Number)
	}
	if !reflect.DeepEqual(section.EvidenceFactIDs, []string{"fact.1"}) {
		t.Fatalf("unknown evidence must be filtered: %v", section.EvidenceFactIDs)
	}
}

func TestValidateRequiresRenderStructure(t *testing.T) {
	missingTitle := mustParseResult(t, `{"report":{"title":"","subtitle":"S","sections":[{"number":"01","title":"A","body":"x"}]}}`)
	if err := missingTitle.Validate("en", nil); err == nil {
		t.Fatal("missing report title must be rejected")
	}
	emptyBody := mustParseResult(t, `{"report":{"title":"T","subtitle":"S","sections":[{"number":"01","title":"A","body":"  "}]}}`)
	if err := emptyBody.Validate("en", nil); err == nil {
		t.Fatal("empty section body must be rejected")
	}
	noSections := mustParseResult(t, `{"report":{"title":"T","subtitle":"S","sections":[]}}`)
	if err := noSections.Validate("en", nil); err == nil {
		t.Fatal("zero sections must be rejected")
	}
}
