package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
)

type compareNarrativeSection struct {
	Type     string   `json:"type,omitempty"`
	Focus    string   `json:"focus,omitempty"`
	Title    string   `json:"title"`
	Text     string   `json:"text"`
	Evidence []string `json:"evidence"`
}

type compareNarrativeResult struct {
	Version     string                    `json:"version"`
	CompareType string                    `json:"compare_type"`
	Summary     compareNarrativeSection   `json:"summary"`
	Sections    []compareNarrativeSection `json:"sections"`
}

type askDeepNarrativeSection struct {
	ID              string   `json:"id"`
	Title           string   `json:"title"`
	Body            string   `json:"body"`
	EvidenceFactIDs []string `json:"evidenceFactIDs"`
}

type askDeepNarrativeResult struct {
	Summary                string                    `json:"summary"`
	SummaryEvidenceFactIDs []string                  `json:"summaryEvidenceFactIDs"`
	Sections               []askDeepNarrativeSection `json:"sections"`
}

func validateSpecialGenerationResult(scope, compareType string, raw json.RawMessage, evidence map[string]bool) (json.RawMessage, error) {
	if strings.HasPrefix(scope, "compare.") {
		var result compareNarrativeResult
		if err := json.Unmarshal(raw, &result); err != nil {
			return nil, err
		}
		if result.Version != "1" || result.CompareType != compareType {
			return nil, errors.New("Compare version or compare_type does not match the request")
		}
		if err := sanitizeCompareSection(&result.Summary, evidence); err != nil {
			return nil, fmt.Errorf("Compare summary: %w", err)
		}
		required := requiredCompareSections(compareType)
		seen := map[string]bool{}
		if len(result.Sections) == 0 {
			return nil, errors.New("Compare sections are required")
		}
		for index := range result.Sections {
			if err := sanitizeCompareSection(&result.Sections[index], evidence); err != nil {
				return nil, fmt.Errorf("Compare section %d: %w", index, err)
			}
			seen[result.Sections[index].Type] = true
		}
		for sectionType := range required {
			if !seen[sectionType] {
				return nil, fmt.Errorf("Compare result is missing required section %q", sectionType)
			}
		}
		return json.Marshal(result)
	}

	if scope == "ask.deep_analysis" {
		var result askDeepNarrativeResult
		if err := json.Unmarshal(raw, &result); err != nil {
			return nil, err
		}
		if strings.TrimSpace(result.Summary) == "" {
			return nil, errors.New("Ask Deep Analysis summary is required")
		}
		result.SummaryEvidenceFactIDs = filterEvidence(result.SummaryEvidenceFactIDs, evidence)
		if len(result.SummaryEvidenceFactIDs) == 0 {
			return nil, errors.New("Ask Deep Analysis summary has no resolvable evidence")
		}
		kept := result.Sections[:0]
		for _, section := range result.Sections {
			section.EvidenceFactIDs = filterEvidence(section.EvidenceFactIDs, evidence)
			if strings.TrimSpace(section.ID) == "" || strings.TrimSpace(section.Title) == "" || strings.TrimSpace(section.Body) == "" || len(section.EvidenceFactIDs) == 0 {
				continue
			}
			kept = append(kept, section)
		}
		result.Sections = kept
		if len(result.Sections) == 0 {
			return nil, errors.New("Ask Deep Analysis has no section with resolvable evidence")
		}
		return json.Marshal(result)
	}
	return nil, errors.New("unsupported special generation scope")
}

func sanitizeCompareSection(section *compareNarrativeSection, evidence map[string]bool) error {
	if strings.TrimSpace(section.Title) == "" || strings.TrimSpace(section.Text) == "" {
		return errors.New("title and text are required")
	}
	section.Evidence = filterEvidence(section.Evidence, evidence)
	if len(section.Evidence) == 0 {
		return errors.New("section has no resolvable evidence")
	}
	return nil
}

func filterEvidence(values []string, allowed map[string]bool) []string {
	seen := map[string]bool{}
	kept := make([]string, 0, len(values))
	for _, value := range values {
		if allowed[value] && !seen[value] {
			seen[value] = true
			kept = append(kept, value)
		}
	}
	return kept
}

func requiredCompareSections(compareType string) map[string]bool {
	values := map[string][]string{
		"me_over_time":           {"key_change", "short_term", "longer_term", "stable"},
		"two_people":             {"alignment", "difference", "influence", "strength", "friction"},
		"two_places":             {"unchanged", "place_a", "place_b", "trade_off"},
		"relationship_over_time": {"baseline", "changed", "intensified", "eased", "short_term", "longer_term", "stable"},
	}
	result := map[string]bool{}
	for _, value := range values[compareType] {
		result[value] = true
	}
	return result
}

func specialOutputContract(scope, compareType string) string {
	if strings.HasPrefix(scope, "compare.") {
		required := make([]string, 0, len(requiredCompareSections(compareType)))
		for value := range requiredCompareSections(compareType) {
			required = append(required, value)
		}
		sort.Strings(required)
		return fmt.Sprintf("\n\nOutput contract (non-negotiable): return one JSON object only. Shape: {\"version\":\"1\",\"compare_type\":%q,\"summary\":{\"title\":\"...\",\"text\":\"...\",\"evidence\":[\"provided fact ID\"]},\"sections\":[{\"type\":\"required type\",\"focus\":\"optional\",\"title\":\"...\",\"text\":\"...\",\"evidence\":[\"provided fact ID\"]}]}. Include every required section type: %s. Every summary/section must cite at least one provided fact ID. Never invent evidence IDs or astrology facts.", compareType, strings.Join(required, ", "))
	}
	return "\n\nOutput contract (non-negotiable): return one JSON object only. Shape: {\"summary\":\"...\",\"summaryEvidenceFactIDs\":[\"provided fact ID\"],\"sections\":[{\"id\":\"stable-section-id\",\"title\":\"...\",\"body\":\"...\",\"evidenceFactIDs\":[\"provided fact ID\"]}]}. The summary and every section must cite provided fact IDs. Never invent evidence IDs or astrology facts."
}

func GenerateSpecial(
	ctx context.Context,
	client *http.Client,
	baseURL, apiKey, model, systemPrompt, userContent, scope, compareType string,
	evidence map[string]bool,
	optionValues ...GenerationOptions,
) (json.RawMessage, string, int, int, int, error) {
	const maxFormatRepairRetries = 3
	options := normalizedGenerationOptions(optionValues)
	var totalPrompt, totalCompletion, totalReasoning int
	var lastErr error
	for attempt := 0; attempt <= maxFormatRepairRetries; attempt++ {
		prompt := systemPrompt + specialOutputContract(scope, compareType)
		content := userContent
		thinking := "enabled"
		attemptContext := ctx
		cancel := func() {}
		if attempt == 0 {
			attemptContext, cancel = context.WithTimeout(ctx, options.FirstAttemptTimeout)
		} else {
			thinking = "disabled"
			prompt += "\n\nThe previous JSON failed validation. Repair the complete object and return JSON only."
			content += "\n\nValidation problem to repair: " + lastErr.Error()
		}
		raw, usedModel, promptTokens, completionTokens, reasoningTokens, err := generateJSONOnce(
			attemptContext, client, baseURL, apiKey, model, prompt, content, thinking, options.MaxOutputTokens,
		)
		cancel()
		totalPrompt += promptTokens
		totalCompletion += completionTokens
		totalReasoning += reasoningTokens
		if err != nil {
			var formatErr *modelOutputFormatError
			if !errors.As(err, &formatErr) {
				return nil, "", totalPrompt, totalCompletion, totalReasoning, err
			}
			lastErr = err
			continue
		}
		cleaned, validationErr := validateSpecialGenerationResult(scope, compareType, json.RawMessage(raw), evidence)
		if validationErr == nil {
			return cleaned, usedModel, totalPrompt, totalCompletion, totalReasoning, nil
		}
		lastErr = validationErr
	}
	return nil, "", totalPrompt, totalCompletion, totalReasoning, lastErr
}
