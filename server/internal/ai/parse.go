package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

func parseAnalyzeResponse(raw string) (AnalyzeResponse, error) {
	candidate := extractJSONObject(raw)
	if candidate == "" {
		return AnalyzeResponse{}, fmt.Errorf("no JSON object found in model response")
	}

	var resp AnalyzeResponse
	if err := json.Unmarshal([]byte(candidate), &resp); err != nil {
		return AnalyzeResponse{}, fmt.Errorf("decode analyze response: %w", err)
	}

	return NormalizeResponse(resp), nil
}

func extractJSONObject(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start == -1 || end == -1 || end < start {
		return ""
	}
	return raw[start : end+1]
}
