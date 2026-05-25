package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

func parseV6JSONResponse[T any](raw string, normalize func(*T)) (T, error) {
	var zero T
	candidate := extractJSONObject(raw)
	if candidate == "" {
		return zero, fmt.Errorf("no JSON object found in v6 model response: %s", summarizeRaw(raw))
	}

	var resp T
	if err := json.Unmarshal([]byte(candidate), &resp); err != nil {
		return zero, fmt.Errorf("decode v6 response: %w; raw=%s", err, summarizeRaw(raw))
	}
	if normalize != nil {
		normalize(&resp)
	}
	return resp, nil
}

func normalizeTranscriptRefinementResponse(resp *TranscriptRefinementResponse) {
	if resp.SchemaVersion == 0 {
		resp.SchemaVersion = 1
	}
	resp.RefinedTranscript = strings.TrimSpace(resp.RefinedTranscript)
	if resp.RefinedTranscript == "" {
		resp.RefinedTranscript = "No transcript refinement generated."
	}
	resp.SuggestedTitle = strings.TrimSpace(resp.SuggestedTitle)
	if resp.Edits == nil {
		resp.Edits = []TranscriptEdit{}
	}
}
func normalizeQuestionSuggestionResponse(resp *QuestionSuggestionResponse) {
	if resp.SchemaVersion == 0 {
		resp.SchemaVersion = 1
	}
	if resp.Questions == nil {
		resp.Questions = []QuestionCandidate{}
	}
	for i := range resp.Questions {
		resp.Questions[i].Prompt = strings.TrimSpace(resp.Questions[i].Prompt)
		resp.Questions[i].Reason = strings.TrimSpace(resp.Questions[i].Reason)
		if resp.Questions[i].Kind == "" {
			resp.Questions[i].Kind = "dailyReflection"
		}
		if resp.Questions[i].Sensitivity == "" {
			resp.Questions[i].Sensitivity = "normal"
		}
		if resp.Questions[i].CandidateAnswers == nil {
			resp.Questions[i].CandidateAnswers = []string{}
		}
	}
}

func normalizeChapterSuggestionResponse(resp *ChapterSuggestionResponse) {
	if resp.SchemaVersion == 0 {
		resp.SchemaVersion = 1
	}
	if resp.ChapterCandidates == nil {
		resp.ChapterCandidates = []ChapterCandidate{}
	}
	for i := range resp.ChapterCandidates {
		if resp.ChapterCandidates[i].EvidenceRecordIDs == nil {
			resp.ChapterCandidates[i].EvidenceRecordIDs = []string{}
		}
	}
}

func normalizePhotoSemanticAnalysisResponse(resp *PhotoSemanticAnalysisResponse) {
	if resp.SchemaVersion == 0 {
		resp.SchemaVersion = 1
	}
	resp.SemanticSummary = strings.TrimSpace(resp.SemanticSummary)
	if resp.SemanticSummary == "" {
		resp.SemanticSummary = "No semantic photo summary generated."
	}
	if resp.Tags == nil {
		resp.Tags = []string{}
	}
	if resp.Objects == nil {
		resp.Objects = []string{}
	}
	if resp.TextHighlights == nil {
		resp.TextHighlights = []string{}
	}
	if resp.Safety == "" {
		resp.Safety = "normal"
	}
}
