package ai

import (
	"context"
	"strings"
)

func (p *MockProvider) GenerateReflection(_ context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	body := strings.TrimSpace(req.Prompt)
	if body == "" {
		body = strings.TrimSpace(req.RecordShell.RawText)
	}
	if body == "" {
		body = "A reflection candidate."
	}
	resp := ReflectionResponse{
		Title:           "Reflection Candidate",
		Body:            body,
		EvidenceSummary: strings.TrimSpace(strings.Join([]string{req.RecordShell.RawText, strings.Join(extractArtifactSummaries(req.Artifacts), " | ")}, " | ")),
		Confidence:      0.61,
		SourceRecordIDs: nonEmptyStrings([]string{req.RecordShell.ID}),
	}
	return ReflectionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-reflection-v1",
		Usage:    Usage{InputTokens: len(body) / 4, OutputTokens: 48},
	}, nil
}

func (p *MockProvider) ReplayReflection(_ context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	body := strings.TrimSpace(req.Prompt)
	if body == "" {
		body = strings.TrimSpace(req.RecordShell.RawText)
	}
	if body == "" {
		body = "Reflection replay."
	}
	resp := ReflectionResponse{
		Title:           "Reflection Replay",
		Body:            body,
		EvidenceSummary: strings.TrimSpace(strings.Join(extractArtifactSummaries(req.Artifacts), " | ")),
		Confidence:      0.58,
		SourceRecordIDs: nonEmptyStrings([]string{req.RecordShell.ID}),
	}
	return ReflectionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-reflection-v1",
		Usage:    Usage{InputTokens: len(body) / 4, OutputTokens: 42},
	}, nil
}
