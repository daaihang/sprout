package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

func analyzeResponseTool() anthropicTool {
	return anthropicTool{
		Name:        "submit_analyze_response",
		Description: "Submit the final structured analyze response for the journaling record.",
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"tags": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
				"emotion": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"label":      map[string]any{"type": "string"},
						"intensity":  map[string]any{"type": "number"},
						"confidence": map[string]any{"type": "number"},
					},
					"required": []string{"label"},
				},
				"entities": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"kind":                map[string]any{"type": "string"},
							"name":                map[string]any{"type": "string"},
							"canonical_name":      map[string]any{"type": "string"},
							"confidence":          map[string]any{"type": "number"},
							"source_artifact_ids": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
						},
						"required": []string{"kind", "name"},
					},
				},
				"candidate_edges": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"from_name":  map[string]any{"type": "string"},
							"from_kind":  map[string]any{"type": "string"},
							"to_name":    map[string]any{"type": "string"},
							"to_kind":    map[string]any{"type": "string"},
							"relation":   map[string]any{"type": "string"},
							"confidence": map[string]any{"type": "number"},
						},
						"required": []string{"from_name", "from_kind", "to_name", "to_kind", "relation"},
					},
				},
				"insight":        map[string]any{"type": "string"},
				"summary":        map[string]any{"type": "string"},
				"salience_score": map[string]any{"type": "number"},
				"retrieval_terms": map[string]any{
					"type":  "array",
					"items": map[string]any{"type": "string"},
				},
				"reflection_hint": map[string]any{"type": "string"},
				"follow_up": map[string]any{
					"anyOf": []any{
						map[string]any{"type": "null"},
						map[string]any{
							"type": "object",
							"properties": map[string]any{
								"question":   map[string]any{"type": "string"},
								"expires_at": map[string]any{"type": "string"},
							},
							"required": []string{"question"},
						},
					},
				},
			},
			"required": []string{"tags", "emotion", "entities", "candidate_edges", "insight"},
		},
	}
}

func anthropicToolResponse(blocks []anthropicContentBlock) (AnalyzeResponse, error) {
	for _, block := range blocks {
		if block.Type != "tool_use" || block.Name != "submit_analyze_response" {
			continue
		}
		var response AnalyzeResponse
		if err := json.Unmarshal(block.Input, &response); err != nil {
			return AnalyzeResponse{}, fmt.Errorf("decode anthropic tool response: %w", err)
		}
		return NormalizeResponse(response), nil
	}

	text := joinAnthropicText(blocks)
	return parseAnalyzeResponse(text)
}

func joinAnthropicText(blocks []anthropicContentBlock) string {
	var builder strings.Builder
	for _, block := range blocks {
		if block.Type != "text" {
			continue
		}
		if builder.Len() > 0 {
			builder.WriteByte('\n')
		}
		builder.WriteString(block.Text)
	}
	return builder.String()
}
