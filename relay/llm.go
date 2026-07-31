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
)

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Model          string        `json:"model"`
	Messages       []ChatMessage `json:"messages"`
	Temperature    float64       `json:"temperature"`
	MaxTokens      int           `json:"max_tokens,omitempty"`
	ResponseFormat *ResponseFmt  `json:"response_format,omitempty"`
	Stream         bool          `json:"stream"`
}

type ResponseFmt struct {
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
			Number  string `json:"number"`
			Title   string `json:"title"`
			Body    string `json:"body"`
			Callout string `json:"callout,omitempty"`
		} `json:"sections"`
	} `json:"report"`
	Cards map[string]struct {
		Detail string `json:"detail"`
	} `json:"cards"`
}

func (r *GenerationResult) Validate(expectedCardIDs []string) error {
	if len(r.Report.Sections) < 4 {
		return errors.New("report must contain at least 4 sections")
	}
	for _, section := range r.Report.Sections {
		if strings.TrimSpace(section.Title) == "" || strings.TrimSpace(section.Body) == "" {
			return errors.New("report section has empty title or body")
		}
	}
	for _, id := range expectedCardIDs {
		card, ok := r.Cards[id]
		if !ok || strings.TrimSpace(card.Detail) == "" {
			return fmt.Errorf("missing card detail for %q", id)
		}
	}
	return nil
}

// Generate calls the OpenAI-compatible upstream and returns the validated,
// structured interpretation.
func Generate(ctx context.Context, client *http.Client, baseURL, apiKey, model, systemPrompt, userContent string, expectedCardIDs []string) (*GenerationResult, string, int, int, error) {
	body := ChatRequest{
		Model: model,
		Messages: []ChatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userContent},
		},
		Temperature: 0.3,
		MaxTokens:   6000,
		ResponseFormat: &ResponseFmt{
			Type: "json_object",
		},
		Stream: false,
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
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var result GenerationResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		return nil, "", 0, 0, fmt.Errorf("upstream content is not valid JSON: %w", err)
	}
	if err := result.Validate(expectedCardIDs); err != nil {
		return nil, "", 0, 0, fmt.Errorf("structured output validation failed: %w", err)
	}
	return &result, chat.Model, chat.Usage.PromptTokens, chat.Usage.CompletionTokens, nil
}
