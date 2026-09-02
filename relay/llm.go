package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

type ChatMessage struct {
	Role             string `json:"role"`
	Content          string `json:"content"`
	ReasoningContent string `json:"reasoning_content,omitempty"`
}

type ChatRequest struct {
	Model           string        `json:"model"`
	Messages        []ChatMessage `json:"messages"`
	Temperature     float64       `json:"temperature"`
	MaxTokens       int           `json:"max_tokens,omitempty"`
	ReasoningEffort string        `json:"reasoning_effort,omitempty"`
	ResponseFormat  *ResponseFmt  `json:"response_format,omitempty"`
	Thinking        *ThinkingMode `json:"thinking,omitempty"`
	Stream          bool          `json:"stream"`
}

type ResponseFmt struct {
	Type string `json:"type"`
}

type ThinkingMode struct {
	Type string `json:"type"`
}

type ChatUsage struct {
	PromptTokens      int `json:"prompt_tokens"`
	CompletionTokens  int `json:"completion_tokens"`
	ReasoningTokens   int `json:"reasoning_tokens"`
	CompletionDetails struct {
		ReasoningTokens int `json:"reasoning_tokens"`
	} `json:"completion_tokens_details"`
}

type ChatChoice struct {
	Message      ChatMessage `json:"message"`
	FinishReason string      `json:"finish_reason"`
}

type ChatResponse struct {
	ID      string       `json:"id"`
	Model   string       `json:"model"`
	Choices []ChatChoice `json:"choices"`
	Usage   ChatUsage    `json:"usage"`
}

type ReportSection struct {
	Number          string   `json:"number"`
	Title           string   `json:"title"`
	Body            string   `json:"body"`
	Callout         string   `json:"callout,omitempty"`
	EvidenceFactIDs []string `json:"evidenceFactIDs"`
}

type ReportBody struct {
	Title    string          `json:"title"`
	Subtitle string          `json:"subtitle"`
	Sections []ReportSection `json:"sections"`
}

type GenerationResult struct {
	Report ReportBody `json:"report"`
}

type GenerationOptions struct {
	MaxOutputTokens     int
	FirstAttemptTimeout time.Duration
}

type modelOutputFormatError struct {
	err error
}

func (e *modelOutputFormatError) Error() string { return e.err.Error() }
func (e *modelOutputFormatError) Unwrap() error { return e.err }

func normalizedGenerationOptions(values []GenerationOptions) GenerationOptions {
	options := GenerationOptions{MaxOutputTokens: 10000, FirstAttemptTimeout: 45 * time.Second}
	if len(values) > 0 {
		if values[0].MaxOutputTokens > 0 {
			options.MaxOutputTokens = values[0].MaxOutputTokens
		}
		if values[0].FirstAttemptTimeout > 0 {
			options.FirstAttemptTimeout = values[0].FirstAttemptTimeout
		}
	}
	return options
}

// parseGenerationResult accepts the canonical {"report": {...}} shape and,
// delivery-first, also the common model variant that omits the outer
// "report" wrapper and returns the body at the top level, and the layered
// natal layout (coreSections / houses / chartSignatures / closing), which is
// flattened into the sections sequence the client renders.
func parseGenerationResult(content, locale string) (*GenerationResult, error) {
	var result GenerationResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, err
	}
	if len(result.Report.Sections) == 0 && strings.TrimSpace(result.Report.Title) == "" && strings.TrimSpace(result.Report.Subtitle) == "" {
		var probe ReportBody
		if err := json.Unmarshal([]byte(content), &probe); err == nil && len(probe.Sections) > 0 {
			result.Report = probe
		}
	}
	if len(result.Report.Sections) == 0 {
		result.Report = normalizeLayeredReport(content, locale, result.Report)
	}
	return &result, nil
}

func normalizeLayeredReport(content, locale string, base ReportBody) ReportBody {
	var alt struct {
		Report struct {
			Title        string          `json:"title"`
			Subtitle     string          `json:"subtitle"`
			CoreSections []ReportSection `json:"coreSections"`
			Houses       []struct {
				House           int      `json:"house"`
				Title           string   `json:"title"`
				Body            string   `json:"body"`
				Callout         string   `json:"callout,omitempty"`
				EvidenceFactIDs []string `json:"evidenceFactIDs"`
			} `json:"houses"`
			ChartSignatures []ReportSection `json:"chartSignatures"`
			Closing         *ReportSection  `json:"closing"`
		} `json:"report"`
	}
	if err := json.Unmarshal([]byte(content), &alt); err != nil {
		return base
	}
	r := alt.Report
	total := len(r.CoreSections) + len(r.Houses) + len(r.ChartSignatures)
	if r.Closing != nil {
		total++
	}
	if total == 0 {
		return base
	}
	sections := make([]ReportSection, 0, total)
	sections = append(sections, r.CoreSections...)
	for _, house := range r.Houses {
		sections = append(sections, ReportSection{
			Number:          fmt.Sprintf("%02d", house.House),
			Title:           house.Title,
			Body:            house.Body,
			Callout:         house.Callout,
			EvidenceFactIDs: house.EvidenceFactIDs,
		})
	}
	sections = append(sections, r.ChartSignatures...)
	if r.Closing != nil {
		closing := *r.Closing
		if strings.TrimSpace(closing.Title) == "" {
			if locale == "zh-Hans" {
				closing.Title = "总结"
			} else {
				closing.Title = "Summary"
			}
		}
		sections = append(sections, closing)
	}
	return ReportBody{Title: r.Title, Subtitle: r.Subtitle, Sections: sections}
}

// outputContractSuffix is appended to every generation prompt so editable
// prompt templates can never remove or weaken the JSON structure the client
// depends on. Prompt authors remain free to change tone, depth and guidance.
func outputContractSuffix(locale string) string {
	if locale == "zh-Hans" {
		return "\n\n输出契约（不可更改）：只输出一个 JSON 对象，不得输出任何其他文字。结构必须是：\n{\"report\":{\"title\":\"一句话标题\",\"subtitle\":\"一句话副标题\",\"sections\":[{\"number\":\"01\",\"title\":\"章节标题\",\"body\":\"整合分析\",\"callout\":\"可选的一句话强调\",\"evidenceFactIDs\":[\"来自请求的事实 ID\"]}]}}\nreport.sections 至少包含一个章节。在输出限制之前完成并闭合 JSON。"
	}
	return "\n\nOutput contract (non-negotiable): return exactly one JSON object and no text outside it, with this shape:\n{\"report\":{\"title\":\"one-sentence title\",\"subtitle\":\"one-sentence subtitle\",\"sections\":[{\"number\":\"01\",\"title\":\"section title\",\"body\":\"integrated analysis\",\"callout\":\"optional one-line emphasis\",\"evidenceFactIDs\":[\"fact ID from the request\"]}]}}\nreport.sections must contain at least one section. Complete and close the JSON before the output limit."
}

func withOutputContract(prompt, locale string) string {
	if strings.Contains(prompt, "输出契约（不可更改）") || strings.Contains(prompt, "Output contract (non-negotiable)") {
		return prompt
	}
	return prompt + outputContractSuffix(locale)
}

func effectiveReportLocale(locale string) string {
	switch locale {
	case "en", "zh-Hans", "es", "fr", "tr", "de", "it", "ko":
		return locale
	default:
		return "en"
	}
}

func withRequestedOutputLanguage(prompt, locale string) string {
	language := map[string]string{
		"en": "English", "zh-Hans": "Simplified Chinese", "es": "Spanish",
		"fr": "French", "tr": "Turkish", "de": "German", "it": "Italian", "ko": "Korean",
	}[effectiveReportLocale(locale)]
	return prompt + fmt.Sprintf(
		"\n\nOutput language (non-negotiable): write every user-visible report value in %s (%s). Keep JSON keys and evidenceFactIDs unchanged.",
		language, effectiveReportLocale(locale),
	)
}

func (r *GenerationResult) Validate(
	locale string,
	requestEvidence map[string]bool,
) error {
	_ = locale
	// Delivery-first contract: the report is model-generated content, so the
	// relay only enforces the structural fields the client needs to render.
	// Section count, lengths and language purity are intentionally not
	// policed, and unknown evidence references are filtered instead of
	// rejecting the whole report.
	if strings.TrimSpace(r.Report.Title) == "" || strings.TrimSpace(r.Report.Subtitle) == "" {
		return errors.New("report title and subtitle are required")
	}
	if len(r.Report.Sections) == 0 {
		return errors.New("report must contain at least one section")
	}
	for index := range r.Report.Sections {
		section := &r.Report.Sections[index]
		if strings.TrimSpace(section.Title) == "" || strings.TrimSpace(section.Body) == "" {
			return errors.New("report section has empty title or body")
		}
		if strings.TrimSpace(section.Number) == "" {
			section.Number = fmt.Sprintf("%02d", index+1)
		}
		if len(requestEvidence) > 0 {
			kept := section.EvidenceFactIDs[:0]
			for _, id := range section.EvidenceFactIDs {
				if requestEvidence[id] {
					kept = append(kept, id)
				}
			}
			section.EvidenceFactIDs = kept
		}
	}
	return nil
}

// Generate calls the OpenAI-compatible upstream and returns the validated,
// structured interpretation.
func Generate(
	ctx context.Context,
	client *http.Client,
	baseURL, apiKey, model, systemPrompt, userContent string,
	locale string,
	requestEvidence map[string]bool,
	optionValues ...GenerationOptions,
) (*GenerationResult, string, int, int, int, error) {
	options := normalizedGenerationOptions(optionValues)
	var totalPromptTokens, totalCompletionTokens, totalReasoningTokens int
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		prompt := systemPrompt
		content := userContent
		if attempt == 1 {
			prompt += "\n\nYour previous output failed structural validation. Return one complete corrected report JSON object only. Keep every section within the requested length, compress detail when needed, and prioritize closing every JSON object and array before the output limit. Do not omit evidenceFactIDs and do not add facts."
			content += "\n\nValidation problem to repair: " + lastErr.Error()
		}
		thinkingMode := "enabled"
		attemptContext := ctx
		cancel := func() {}
		if attempt == 0 {
			attemptContext, cancel = context.WithTimeout(ctx, options.FirstAttemptTimeout)
		} else {
			thinkingMode = "disabled"
		}
		result, usedModel, promptTokens, completionTokens, reasoningTokens, err := generateOnce(
			attemptContext, client, baseURL, apiKey, model, prompt, content, thinkingMode, locale, options.MaxOutputTokens,
		)
		cancel()
		totalPromptTokens += promptTokens
		totalCompletionTokens += completionTokens
		totalReasoningTokens += reasoningTokens
		if err == nil {
			err = result.Validate(locale, requestEvidence)
		}
		if err != nil && generationShapeDebugEnabled() {
			if result == nil {
				log.Printf("generation shape: no parseable result err=%v", err)
			} else {
				log.Printf(
					"generation shape: sections=%d title=%t subtitle=%t err=%v",
					len(result.Report.Sections),
					strings.TrimSpace(result.Report.Title) != "",
					strings.TrimSpace(result.Report.Subtitle) != "",
					err,
				)
			}
		}
		if err == nil {
			return result, usedModel, totalPromptTokens, totalCompletionTokens, totalReasoningTokens, nil
		}
		lastErr = err
	}
	return nil, "", totalPromptTokens, totalCompletionTokens, totalReasoningTokens, lastErr
}

func generationShapeDebugEnabled() bool {
	return os.Getenv("RELAY_GENERATION_DEBUG") == "1"
}

func generateOnce(
	ctx context.Context,
	client *http.Client,
	baseURL, apiKey, model, systemPrompt, userContent, thinkingMode, locale string,
	maxOutputTokens int,
) (*GenerationResult, string, int, int, int, error) {
	content, usedModel, promptTokens, completionTokens, reasoningTokens, err := generateJSONOnce(
		ctx, client, baseURL, apiKey, model, systemPrompt, userContent, thinkingMode, maxOutputTokens,
	)
	if err != nil {
		return nil, "", promptTokens, completionTokens, reasoningTokens, err
	}
	result, err := parseGenerationResult(content, locale)
	if err != nil {
		return nil, "", promptTokens, completionTokens, reasoningTokens, err
	}
	return result, usedModel, promptTokens, completionTokens, reasoningTokens, nil
}

func generateJSONOnce(
	ctx context.Context,
	client *http.Client,
	baseURL, apiKey, model, systemPrompt, userContent, thinkingMode string,
	maxOutputTokens int,
) (string, string, int, int, int, error) {
	body := ChatRequest{
		Model: model,
		Messages: []ChatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userContent},
		},
		Temperature: 0.3,
		MaxTokens:   maxOutputTokens,
		ResponseFormat: &ResponseFmt{
			Type: "json_object",
		},
		Thinking: &ThinkingMode{Type: thinkingMode},
		Stream:   false,
	}
	if thinkingMode == "enabled" {
		body.ReasoningEffort = "low"
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return "", "", 0, 0, 0, err
	}
	endpoint := strings.TrimRight(baseURL, "/") + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return "", "", 0, 0, 0, err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return "", "", 0, 0, 0, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return "", "", 0, 0, 0, err
	}
	if resp.StatusCode != http.StatusOK {
		return "", "", 0, 0, 0, fmt.Errorf("upstream HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(raw)))
	}

	var chat ChatResponse
	if err := json.Unmarshal(raw, &chat); err != nil {
		return "", "", 0, 0, 0, fmt.Errorf("invalid upstream response: %w", err)
	}
	if len(chat.Choices) == 0 {
		return "", "", 0, 0, 0, errors.New("upstream returned no choices")
	}
	content := strings.TrimSpace(chat.Choices[0].Message.Content)
	reasoningBytes := len(strings.TrimSpace(chat.Choices[0].Message.ReasoningContent))
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var probe any
	if err := json.Unmarshal([]byte(content), &probe); err != nil {
		return "", "", 0, 0, 0, &modelOutputFormatError{err: fmt.Errorf(
			"upstream content is not valid JSON (finish_reason=%q, content_bytes=%d, reasoning_bytes=%d): %w",
			chat.Choices[0].FinishReason,
			len(content),
			reasoningBytes,
			err,
		)}
	}
	reasoningTokens := chat.Usage.ReasoningTokens
	if reasoningTokens == 0 {
		reasoningTokens = chat.Usage.CompletionDetails.ReasoningTokens
	}
	return content, chat.Model, chat.Usage.PromptTokens, chat.Usage.CompletionTokens, reasoningTokens, nil
}
