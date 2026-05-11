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

	content := strings.TrimSpace(req.Record.Content)
	lower := strings.ToLower(content)

	tags := []string{"journal"}
	emotionLabel := "neutral"
	insight := "This memory captures a steady moment worth revisiting."

	switch {
	case containsAny(lower, "happy", "开心", "满足", "excited"):
		emotionLabel = "positive"
		tags = append(tags, "gratitude")
		insight = "The note carries a clear positive signal and can anchor future reflection."
	case containsAny(lower, "sad", "难过", "焦虑", "tired", "stress"):
		emotionLabel = "tense"
		tags = append(tags, "stress")
		insight = "The note suggests unresolved pressure and may benefit from a short follow-up."
	case containsAny(lower, "movie", "film", "电影", "book", "read", "音乐", "music"):
		emotionLabel = "curious"
		tags = append(tags, "media")
		insight = "The record points to a concrete media memory that can be expanded with metadata."
	}

	personMatches := make([]PersonMatch, 0, len(req.Persons))
	for _, person := range req.Persons {
		confidence := 0.92
		personMatches = append(personMatches, PersonMatch{
			Name:       person.Name,
			Action:     "link",
			PersonID:   person.ID,
			Confidence: &confidence,
		})
	}

	var media []MediaHint
	if containsAny(lower, "movie", "film", "电影") {
		media = append(media, MediaHint{
			Type:       "movie",
			Title:      firstMeaningfulTitle(content, "Untitled Film"),
			SearchHint: "search by title and recent release year",
		})
	}
	if containsAny(lower, "book", "read", "阅读", "书") {
		media = append(media, MediaHint{
			Type:       "book",
			Title:      firstMeaningfulTitle(content, "Untitled Book"),
			SearchHint: "search by title and author",
		})
	}

	intensity := 2
	confidence := 0.84
	resp := NormalizeResponse(AnalyzeResponse{
		Tags:     tags,
		Emotion:  EmotionResult{Label: emotionLabel, Intensity: &intensity, Confidence: &confidence},
		Persons:  personMatches,
		NewMedia: media,
		Insight:  insight,
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
