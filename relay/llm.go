package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode"
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
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
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

type GenerationResult struct {
	Report struct {
		Title    string `json:"title"`
		Subtitle string `json:"subtitle"`
		Sections []struct {
			Number          string   `json:"number"`
			Title           string   `json:"title"`
			Body            string   `json:"body"`
			Callout         string   `json:"callout,omitempty"`
			EvidenceFactIDs []string `json:"evidenceFactIDs"`
		} `json:"sections"`
	} `json:"report"`
}

func (r *GenerationResult) Validate(
	locale string,
	requestEvidence map[string]bool,
) error {
	if strings.TrimSpace(r.Report.Title) == "" || strings.TrimSpace(r.Report.Subtitle) == "" {
		return errors.New("report title and subtitle are required")
	}
	if err := validateLanguagePurity(r.Report.Title+" "+r.Report.Subtitle, locale); err != nil {
		return fmt.Errorf("report heading: %w", err)
	}
	if len(r.Report.Sections) < 4 || len(r.Report.Sections) > 8 {
		return errors.New("report must contain 4 to 8 sections")
	}
	for index, section := range r.Report.Sections {
		if strings.TrimSpace(section.Number) == "" || strings.TrimSpace(section.Title) == "" || strings.TrimSpace(section.Body) == "" {
			return errors.New("report section has empty number, title or body")
		}
		if err := validateLanguagePurity(section.Title+" "+section.Body+" "+section.Callout, locale); err != nil {
			return fmt.Errorf("report section %d: %w", index+1, err)
		}
		if len(requestEvidence) > 0 && len(section.EvidenceFactIDs) == 0 {
			return fmt.Errorf("report section %q has no evidenceFactIDs", section.Title)
		}
		for _, id := range section.EvidenceFactIDs {
			if !requestEvidence[id] {
				return fmt.Errorf("report section %q cites unknown evidence %q", section.Title, id)
			}
		}
	}
	return nil
}

func validateLanguagePurity(text, locale string) error {
	if locale == "zh-Hans" {
		for _, r := range text {
			if unicode.Is(unicode.Han, r) {
				return nil
			}
		}
		return errors.New("text is not Simplified Chinese")
	}
	for _, r := range text {
		if unicode.Is(unicode.Han, r) {
			return errors.New("English text contains Chinese characters")
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
) (*GenerationResult, string, int, int, error) {
	var totalPromptTokens, totalCompletionTokens int
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
			attemptContext, cancel = context.WithTimeout(ctx, 45*time.Second)
		} else {
			thinkingMode = "disabled"
		}
		result, usedModel, promptTokens, completionTokens, err := generateOnce(
			attemptContext, client, baseURL, apiKey, model, prompt, content, thinkingMode,
		)
		cancel()
		totalPromptTokens += promptTokens
		totalCompletionTokens += completionTokens
		if err == nil {
			err = result.Validate(locale, requestEvidence)
		}
		if err == nil {
			return result, usedModel, totalPromptTokens, totalCompletionTokens, nil
		}
		lastErr = err
	}
	return nil, "", totalPromptTokens, totalCompletionTokens, lastErr
}

func generateOnce(
	ctx context.Context,
	client *http.Client,
	baseURL, apiKey, model, systemPrompt, userContent, thinkingMode string,
) (*GenerationResult, string, int, int, error) {
	body := ChatRequest{
		Model: model,
		Messages: []ChatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userContent},
		},
		Temperature: 0.3,
		MaxTokens:   10000,
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
		return nil, "", 0, 0, err
	}
	endpoint := strings.TrimRight(baseURL, "/") + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, "", 0, 0, err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, "", 0, 0, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, "", 0, 0, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, "", 0, 0, fmt.Errorf("upstream HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(raw)))
	}

	var chat ChatResponse
	if err := json.Unmarshal(raw, &chat); err != nil {
		return nil, "", 0, 0, fmt.Errorf("invalid upstream response: %w", err)
	}
	if len(chat.Choices) == 0 {
		return nil, "", 0, 0, errors.New("upstream returned no choices")
	}
	content := strings.TrimSpace(chat.Choices[0].Message.Content)
	reasoningBytes := len(strings.TrimSpace(chat.Choices[0].Message.ReasoningContent))
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var result GenerationResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, "", 0, 0, fmt.Errorf(
			"upstream content is not valid JSON (finish_reason=%q, content_bytes=%d, reasoning_bytes=%d): %w",
			chat.Choices[0].FinishReason,
			len(content),
			reasoningBytes,
			err,
		)
	}
	return &result, chat.Model, chat.Usage.PromptTokens, chat.Usage.CompletionTokens, nil
}
