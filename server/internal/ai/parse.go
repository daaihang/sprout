package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

func parseAnalysisRecordResponse(raw string) (AnalysisRecordResponse, error) {
	candidate := extractJSONObject(raw)
	if candidate == "" {
		return AnalysisRecordResponse{}, fmt.Errorf("no JSON object found in model response: %s", summarizeRaw(raw))
	}

	var resp AnalysisRecordResponse
	if err := json.Unmarshal([]byte(candidate), &resp); err != nil {
		return AnalysisRecordResponse{}, fmt.Errorf("decode analyze response: %w; raw=%s", err, summarizeRaw(raw))
	}

	return NormalizeAnalysisRecordResponse(resp), nil
}

func parseReflectionResponse(raw string) (ReflectionResponse, error) {
	candidate := extractJSONObject(raw)
	if candidate == "" {
		return ReflectionResponse{}, fmt.Errorf("no JSON object found in reflection model response: %s", summarizeRaw(raw))
	}

	var resp ReflectionResponse
	if err := json.Unmarshal([]byte(candidate), &resp); err != nil {
		return ReflectionResponse{}, fmt.Errorf("decode reflection response: %w; raw=%s", err, summarizeRaw(raw))
	}

	if strings.TrimSpace(resp.Title) == "" {
		resp.Title = "Reflection Candidate"
	}
	if strings.TrimSpace(resp.Body) == "" {
		resp.Body = "No reflection generated."
	}
	if resp.SourceRecordIDs == nil {
		resp.SourceRecordIDs = []string{}
	}
	return resp, nil
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

func summarizeRaw(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if len(trimmed) <= 256 {
		return trimmed
	}
	return trimmed[:256] + "…"
}
