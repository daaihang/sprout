package ai

import (
	"context"
	"strings"
)

func (p *MockProvider) RefineTranscript(_ context.Context, req TranscriptRefinementRequest, user UserContext) (TranscriptRefinementResult, error) {
	if err := req.Validate(); err != nil {
		return TranscriptRefinementResult{}, err
	}

	refined := strings.TrimSpace(req.RawTranscript)
	refined = strings.Join(strings.Fields(refined), " ")
	if !strings.HasSuffix(refined, ".") && !strings.HasSuffix(refined, "。") && !strings.HasSuffix(refined, "!") && !strings.HasSuffix(refined, "！") && !strings.HasSuffix(refined, "?") && !strings.HasSuffix(refined, "？") {
		if containsAny(refined, "我", "今天", "昨天", "妈妈", "工作") {
			refined += "。"
		} else {
			refined += "."
		}
	}

	title := ""
	if req.AllowTitle {
		title = firstMeaningfulTitle(refined, "Voice Memory")
	}

	resp := TranscriptRefinementResponse{
		SchemaVersion:     1,
		RefinedTranscript: refined,
		SuggestedTitle:    title,
		Edits: []TranscriptEdit{{
			Kind:    "punctuation",
			Summary: "Cleaned spacing and added a sentence ending while preserving the transcript meaning.",
		}},
	}
	return TranscriptRefinementResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-v6-transcript-v1",
		Usage:    Usage{InputTokens: len(req.RawTranscript) / 4, OutputTokens: len(refined) / 4},
	}, nil
}

func (p *MockProvider) SuggestQuestions(_ context.Context, req QuestionSuggestionRequest, user UserContext) (QuestionSuggestionResult, error) {
	if err := req.Validate(); err != nil {
		return QuestionSuggestionResult{}, err
	}

	displayName := strings.TrimSpace(req.KnownProfile.DisplayName)
	if displayName == "" {
		displayName = strings.TrimSpace(req.Target.Kind)
	}
	if displayName == "" {
		displayName = "this"
	}

	kind := "dailyReflection"
	prompt := "What detail would make this memory easier to understand later?"
	reason := "Recent evidence has enough context for a gentle follow-up."
	answers := []string{}
	switch strings.ToLower(req.Target.Type) {
	case "entity":
		if strings.EqualFold(req.Target.Kind, "person") {
			kind = "entityRelationship"
			prompt = "Who is " + displayName + " to you?"
			reason = displayName + " appears in recent memories, but their relationship is not confirmed."
			answers = []string{"friend", "coworker", "family", "partner", "other"}
		} else {
			kind = "themeConfirmation"
			prompt = "Is " + displayName + " a theme you want Mory to track?"
			reason = displayName + " appears as a possible repeated topic."
			answers = []string{"yes", "not now", "hide"}
		}
	case "record":
		prompt = "What part of this moment do you want Mory to remember?"
	}

	resp := QuestionSuggestionResponse{
		SchemaVersion: 1,
		Questions: []QuestionCandidate{{
			Kind:             kind,
			Prompt:           prompt,
			Reason:           reason,
			CandidateAnswers: answers,
			Confidence:       0.72,
			Sensitivity:      "normal",
		}},
	}
	return QuestionSuggestionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-v6-question-v1",
		Usage:    Usage{InputTokens: len(req.Evidence) * 24, OutputTokens: 80},
	}, nil
}

func (p *MockProvider) SuggestChapters(_ context.Context, req ChapterSuggestionRequest, user UserContext) (ChapterSuggestionResult, error) {
	if err := req.Validate(); err != nil {
		return ChapterSuggestionResult{}, err
	}

	label := "A Pattern Is Forming"
	if len(req.Signals) > 0 && strings.TrimSpace(req.Signals[0].Label) != "" {
		label = req.Signals[0].Label
	}
	recordIDs := make([]string, 0, len(req.EvidenceSnippets))
	for _, evidence := range req.EvidenceSnippets {
		if strings.TrimSpace(evidence.RecordID) != "" {
			recordIDs = append(recordIDs, strings.TrimSpace(evidence.RecordID))
		}
	}

	resp := ChapterSuggestionResponse{
		SchemaVersion: 1,
		ChapterCandidates: []ChapterCandidate{{
			Title:                firstMeaningfulTitle(label, "A Pattern Is Forming"),
			Summary:              "Mory noticed repeated evidence around " + label + ".",
			EvidenceRecordIDs:    uniqueStrings(recordIDs),
			Confidence:           0.68,
			RequiresConfirmation: true,
		}},
	}
	return ChapterSuggestionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-v6-chapter-v1",
		Usage:    Usage{InputTokens: len(req.Signals)*16 + len(req.EvidenceSnippets)*24, OutputTokens: 90},
	}, nil
}

func (p *MockProvider) AnalyzePhotoSemantics(_ context.Context, req PhotoSemanticAnalysisRequest, user UserContext) (PhotoSemanticAnalysisResult, error) {
	if err := req.Validate(); err != nil {
		return PhotoSemanticAnalysisResult{}, err
	}

	objects := uniqueStrings(req.LocalLabels)
	highlights := []string{}
	if trimmed := strings.TrimSpace(req.OCRText); trimmed != "" {
		highlights = append(highlights, firstMeaningfulTitle(trimmed, trimmed))
	}
	summaryParts := append([]string{}, objects...)
	summaryParts = append(summaryParts, highlights...)
	summary := strings.TrimSpace(strings.Join(summaryParts, ", "))
	if summary == "" {
		summary = strings.TrimSpace(req.CaptionHint)
	}
	if summary == "" {
		summary = "Photo with local visual signals."
	}

	resp := PhotoSemanticAnalysisResponse{
		SchemaVersion:   1,
		SemanticSummary: "Photo context: " + summary,
		SuggestedTitle:  firstMeaningfulTitle(summary, "Photo Memory"),
		Tags:            uniqueStrings(append([]string{"photo"}, objects...)),
		Objects:         objects,
		TextHighlights:  highlights,
		Safety:          "normal",
		Confidence:      0.62,
	}
	return PhotoSemanticAnalysisResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-v6-photo-v1",
		Usage:    Usage{InputTokens: len(req.OCRText)/4 + len(req.LocalLabels)*4, OutputTokens: 80},
	}, nil
}
