package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

func analysisResponseTool() anthropicTool {
	return anthropicTool{
		Name:        "submit_analysis_response",
		Description: "Submit the final structured memory analysis response.",
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"analysis":                 map[string]any{"type": "object"},
				"affect_proposals":         map[string]any{"type": "array"},
				"graph_delta_proposals":    map[string]any{"type": "array"},
				"profile_update_proposals": map[string]any{"type": "array"},
				"merge_split_candidates":   map[string]any{"type": "array"},
				"arc_candidates":           map[string]any{"type": "array"},
				"reflection_candidates":    map[string]any{"type": "array"},
				"question_candidates":      map[string]any{"type": "array"},
				"quality":                  map[string]any{"type": "object"},
			},
			"required": []string{"analysis", "quality"},
		},
	}
}

func anthropicAnalysisResponse(blocks []anthropicContentBlock) (AnalysisResponse, error) {
	for _, block := range blocks {
		if block.Type != "tool_use" || block.Name != "submit_analysis_response" {
			continue
		}
		var response AnalysisResponse
		if err := json.Unmarshal(block.Input, &response); err != nil {
			return AnalysisResponse{}, fmt.Errorf("decode anthropic analysis tool response: %w", err)
		}
		return NormalizeAnalysisResponse(response), nil
	}

	text := joinAnthropicText(blocks)
	return parseAnalysisResponse(text)
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
