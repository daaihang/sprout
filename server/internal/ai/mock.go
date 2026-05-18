package ai

import (
	"context"
	"strings"
)

type MockProvider struct{}

func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

func (p *MockProvider) Name() string {
	return "mock"
}

func (p *MockProvider) Analyze(_ context.Context, req AnalyzeRequest, user UserContext) (AnalyzeResult, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeResult{}, err
	}

	parts := []string{req.RecordShell.RawText}
	for _, artifact := range req.Artifacts {
		parts = append(parts, strings.TrimSpace(strings.Join([]string{
			artifact.Kind,
			artifact.Title,
			artifact.Summary,
			artifact.TextContent,
		}, " ")))
	}
	content := strings.TrimSpace(strings.Join(parts, "\n"))
	lower := strings.ToLower(content)

	tags := []string{"journal"}
	emotionLabel := "neutral"
	insight := "This memory captures a steady moment worth revisiting."
	summary := "A steady memory with enough structure to revisit later."
	reflectionHint := "This could matter later if it starts repeating."
	entities := []EntityMention{}
	edges := []CandidateEdge{}
	retrievalTerms := []string{"journal", "memory"}
	salienceScore := 0.46

	switch {
	case containsAny(lower, "happy", "开心", "满足", "excited"):
		emotionLabel = "positive"
		tags = append(tags, "gratitude")
		insight = "The note carries a clear positive signal and can anchor future reflection."
		summary = "A positive memory with gratitude and emotional lift."
		reflectionHint = "Track whether gratitude keeps clustering around the same people or settings."
		retrievalTerms = append(retrievalTerms, "gratitude", "positive_moment")
		salienceScore = 0.72
	case containsAny(lower, "sad", "难过", "焦虑", "tired", "stress"):
		emotionLabel = "tense"
		tags = append(tags, "stress")
		insight = "The note suggests unresolved pressure and may benefit from a short follow-up."
		summary = "A tense memory with unresolved pressure."
		reflectionHint = "Check if this pressure is isolated or part of a larger pattern."
		retrievalTerms = append(retrievalTerms, "stress", "pressure")
		salienceScore = 0.78
	case containsAny(lower, "movie", "film", "电影", "book", "read", "音乐", "music"):
		emotionLabel = "curious"
		tags = append(tags, "media")
		insight = "The record points to a concrete media memory that can be expanded with metadata."
		summary = "A media-related memory with concrete references."
		reflectionHint = "Media references may become stronger signals once linked across time."
		retrievalTerms = append(retrievalTerms, "media", "cultural_reference")
		salienceScore = 0.58
	}

	for _, known := range req.KnownEntities {
		if strings.EqualFold(known.Kind, "person") && containsAny(lower, known.Name) {
			confidence := 0.92
			entities = append(entities, EntityMention{
				Kind:       "person",
				Name:       known.Name,
				Canonical:  known.Name,
				Confidence: &confidence,
			})
		}
	}

	if containsAny(lower, "妈妈", "母亲", "mom", "mother") {
		confidence := 0.93
		entities = append(entities, EntityMention{
			Kind:       "person",
			Name:       "妈妈",
			Canonical:  "妈妈",
			Confidence: &confidence,
		})
	}
	if containsAny(lower, "上海", "beijing", "tokyo", "shanghai") {
		confidence := 0.86
		name := "Shanghai"
		if containsAny(lower, "上海") {
			name = "上海"
		}
		entities = append(entities, EntityMention{
			Kind:       "place",
			Name:       name,
			Canonical:  name,
			Confidence: &confidence,
		})
	}
	for _, tag := range tags {
		confidence := 0.8
		entities = append(entities, EntityMention{
			Kind:       "theme",
			Name:       tag,
			Canonical:  tag,
			Confidence: &confidence,
		})
	}
	if containsAny(lower, "决定", "decide", "should", "选择") {
		confidence := 0.78
		entities = append(entities, EntityMention{
			Kind:       "decision",
			Name:       firstMeaningfulTitle(content, "pending decision"),
			Canonical:  firstMeaningfulTitle(content, "pending decision"),
			Confidence: &confidence,
		})
	}
	if len(entities) >= 2 {
		confidence := 0.72
		edges = append(edges, CandidateEdge{
			FromName:   entities[0].Name,
			FromKind:   entities[0].Kind,
			ToName:     entities[1].Name,
			ToKind:     entities[1].Kind,
			Relation:   "MENTIONED_WITH",
			Confidence: &confidence,
		})
	}

	intensity := 2.0
	confidence := 0.84
	resp := NormalizeResponse(AnalyzeResponse{
		Tags:     tags,
		Emotion:  EmotionResult{Label: emotionLabel, Intensity: &intensity, Confidence: &confidence},
		Entities: entities,
		Edges:    edges,
		Insight:  insight,
		Summary:  summary,
		SalienceScore: &salienceScore,
		RetrievalTerms: uniqueStrings(retrievalTerms),
		ReflectionHint: reflectionHint,
		FollowUp: &FollowUp{
			Question:  "What part of this moment do you want to remember a month from now?",
			ExpiresAt: oneHourFromNow(),
		},
	})

	return AnalyzeResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-analyzer-v1",
		Usage:    Usage{InputTokens: len(content) / 4, OutputTokens: 120},
	}, nil
}

func (p *MockProvider) GenerateReflection(_ context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error) {
	body := strings.TrimSpace(req.Prompt)
	if body == "" {
		body = strings.TrimSpace(req.RecordShell.RawText)
	}
	if body == "" {
		body = "A reflection candidate."
	}
	resp := ReflectionResponse{
		Title:          "Reflection Candidate",
		Body:           body,
		EvidenceSummary: strings.TrimSpace(strings.Join([]string{req.RecordShell.RawText, strings.Join(extractArtifactSummaries(req.Artifacts), " | ")}, " | ")),
		Confidence:     0.61,
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
		Title:          "Reflection Replay",
		Body:           body,
		EvidenceSummary: strings.TrimSpace(strings.Join(extractArtifactSummaries(req.Artifacts), " | ")),
		Confidence:     0.58,
		SourceRecordIDs: nonEmptyStrings([]string{req.RecordShell.ID}),
	}
	return ReflectionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-reflection-v1",
		Usage:    Usage{InputTokens: len(body) / 4, OutputTokens: 42},
	}, nil
}

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
			Sensitivity:       "normal",
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

func (p *MockProvider) SuggestNotificationIntent(_ context.Context, req NotificationIntentSuggestionRequest, user UserContext) (NotificationIntentSuggestionResult, error) {
	if err := req.Validate(); err != nil {
		return NotificationIntentSuggestionResult{}, err
	}

	body := "A memory prompt is ready."
	deepLink := ""
	kind := strings.TrimSpace(req.Trigger)
	if kind == "" {
		kind = "dailyQuestion"
	}
	if req.Question != nil && strings.TrimSpace(req.Question.Prompt) != "" {
		body = "A question is ready for today."
		deepLink = "mory://questions"
	}
	if req.Preferences.RichPreviewsEnabled && req.Question != nil && strings.TrimSpace(req.Question.Prompt) != "" {
		body = req.Question.Prompt
	}

	resp := NotificationIntentSuggestionResponse{
		SchemaVersion: 1,
		Intent: NotificationIntentCandidate{
			Kind:         kind,
			PrivacyLevel: "generic",
			Title:        "Mory",
			Body:         body,
			DeepLink:     deepLink,
		},
	}
	return NotificationIntentSuggestionResult{
		Response: resp,
		Provider: p.Name(),
		Model:    "mock-v6-notification-v1",
		Usage:    Usage{InputTokens: len(req.RecentEvidence) * 20, OutputTokens: 48},
	}, nil
}

func containsAny(value string, terms ...string) bool {
	for _, term := range terms {
		if strings.Contains(value, strings.ToLower(term)) {
			return true
		}
	}
	return false
}

func firstMeaningfulTitle(content, fallback string) string {
	fields := strings.Fields(content)
	if len(fields) == 0 {
		return fallback
	}
	if len(fields) > 5 {
		fields = fields[:5]
	}
	title := strings.Join(fields, " ")
	if strings.TrimSpace(title) == "" {
		return fallback
	}
	return title
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	ordered := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		key := strings.ToLower(value)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		ordered = append(ordered, value)
	}
	return ordered
}

func extractArtifactSummaries(artifacts []AnalyzeArtifact) []string {
	values := make([]string, 0, len(artifacts))
	for _, artifact := range artifacts {
		candidate := strings.TrimSpace(strings.Join([]string{
			artifact.Kind,
			artifact.Title,
			artifact.Summary,
			artifact.TextContent,
		}, " "))
		if candidate != "" {
			values = append(values, candidate)
		}
	}
	return values
}

func nonEmptyStrings(values []string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
