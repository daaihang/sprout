package ai

import (
	"context"
	"strings"
)

func (p *MockProvider) Analyze(_ context.Context, req AnalysisRequest, _ UserContext) (AnalysisResult, error) {
	if err := req.Validate(); err != nil {
		return AnalysisResult{}, err
	}

	analysis := mockAnalysisRecordResponse(req)
	response := BuildAnalysisResponse(req, analysis)
	return AnalysisResult{
		Response: response,
		Provider: p.Name(),
		Model:    "mock-analysis",
		Usage: Usage{
			InputTokens:  len(req.RecordShell.RawText)/4 + len(req.Artifacts)*12 + len(req.ContextPack.RelatedMemories)*16,
			OutputTokens: 120 + len(response.AffectProposals)*16 + len(response.ReflectionCandidates)*24,
		},
	}, nil
}

func mockAnalysisRecordResponse(req AnalysisRequest) AnalysisRecordResponse {
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
		title := firstMeaningfulTitle(content, "pending decision")
		entities = append(entities, EntityMention{
			Kind:       "decision",
			Name:       title,
			Canonical:  title,
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
	return NormalizeAnalysisRecordResponse(AnalysisRecordResponse{
		Tags:           tags,
		Emotion:        EmotionResult{Label: emotionLabel, Intensity: &intensity, Confidence: &confidence},
		Entities:       entities,
		Edges:          edges,
		Insight:        insight,
		Summary:        summary,
		SalienceScore:  &salienceScore,
		RetrievalTerms: uniqueStrings(retrievalTerms),
		ReflectionHint: reflectionHint,
		FollowUp: &FollowUp{
			Question:  "What part of this moment do you want to remember a month from now?",
			ExpiresAt: oneHourFromNow(),
		},
	})
}
