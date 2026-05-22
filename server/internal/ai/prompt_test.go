package ai

import (
	"strings"
	"testing"
)

func TestBuildAnalyzeUserPromptIncludesContextArtifacts(t *testing.T) {
	req := AnalyzeRequest{
		SchemaVersion:  "v4",
		AnalysisReason: "test",
		RecordShell: AnalyzeRecordShell{
			ID:      "rec-1",
			RawText: "Walked home.",
		},
		Artifacts: []AnalyzeArtifact{
			{
				Kind:        "weather",
				Title:       "Sunny 22°C",
				Summary:     "Sunny · 22°C · Humidity 45%",
				TextContent: "Sunny · 22°C · Humidity 45%",
				Metadata: map[string]string{
					"condition":          "Sunny",
					"temperatureCelsius": "22.0",
					"humidity":           "0.45",
					"windSpeedKmh":       "5.2",
					"uvIndex":            "3",
				},
			},
			{
				Kind:        "music",
				Title:       "Nightcall – Kavinsky",
				Summary:     "Nightcall · Kavinsky · OutRun",
				TextContent: "Nightcall · Kavinsky · OutRun",
				Metadata: map[string]string{
					"trackName":       "Nightcall",
					"artistName":      "Kavinsky",
					"albumName":       "OutRun",
					"durationSeconds": "258",
				},
			},
			{
				Kind:        "location",
				Title:       "Home",
				Summary:     "Berkeley CA",
				TextContent: "Berkeley CA",
				Metadata: map[string]string{
					"latitude":  "37.87",
					"longitude": "-122.27",
				},
			},
		},
	}

	body, err := buildAnalyzeUserPrompt(req, UserContext{UserID: "u1", Tier: "free"})
	if err != nil {
		t.Fatalf("buildAnalyzeUserPrompt error: %v", err)
	}

	mustContain := []string{
		`"kind":"weather"`,
		`"kind":"music"`,
		`"kind":"location"`,
		"Nightcall",
		"Kavinsky",
		"Sunny",
		"Berkeley",
		"temperatureCelsius",
		"trackName",
		"latitude",
	}
	for _, needle := range mustContain {
		if !strings.Contains(body, needle) {
			t.Errorf("prompt body missing %q; body=%s", needle, body)
		}
	}
}

func TestBuildAnalyzeUserPromptIncludesV7ContextPackAndMoodEvidence(t *testing.T) {
	confidence := 0.64
	req := AnalyzeRequest{
		SchemaVersion:   "analyze.v7",
		ClientVersion:   "mory.v7",
		ClientRequestID: "client-v7",
		AnalysisReason:  "capture_ingest_context_v7",
		RecordShell: AnalyzeRecordShell{
			ID:      "rec-1",
			RawText: "I joked that I was annoyed after dinner.",
		},
		MoodEvidence: []AnalyzeV7MoodEvidence{
			{
				ID:            "mood-1",
				RecordID:      "rec-1",
				Labels:        []string{"mockFrustrated"},
				ToneHints:     []string{"joking"},
				Confidence:    &confidence,
				UserConfirmed: true,
			},
		},
		ContextPack: &AnalyzeV7ContextPack{
			PackID:         "pack-1",
			TargetRecordID: "rec-1",
			RelatedMemories: []AnalyzeV7RelatedMemory{
				{RecordID: "rec-old", Snippet: "Earlier dinner joke with the same roommate."},
			},
			PrivacyDecisions: []AnalyzeV7PrivacyDecision{
				{SourceType: "memory", SourceID: "sensitive-1", Action: "redact", Reason: "sensitive boundary"},
			},
		},
		ClientCapabilities: &AnalyzeV7ClientCapabilities{SupportsContextAwareReflection: true},
	}

	body, err := buildAnalyzeUserPrompt(req, UserContext{UserID: "u1", Tier: "free"})
	if err != nil {
		t.Fatalf("buildAnalyzeUserPrompt error: %v", err)
	}

	for _, needle := range []string{
		`"client_request_id":"client-v7"`,
		`"mood_evidence"`,
		`"tone_hints":["joking"]`,
		`"context_pack"`,
		`"related_memories"`,
		`"privacy_decisions"`,
		`"client_capabilities"`,
	} {
		if !strings.Contains(body, needle) {
			t.Errorf("prompt body missing %q; body=%s", needle, body)
		}
	}
}

func TestBuildAnalyzeSystemPromptMentionsContextKinds(t *testing.T) {
	sys := buildAnalyzeSystemPrompt()
	for _, kind := range []string{"weather", "music", "location"} {
		if !strings.Contains(sys, kind) {
			t.Errorf("system prompt should reference %q so the LLM treats it as ambient context; got: %s", kind, sys)
		}
	}
}

func TestBuildAnalyzeSystemPromptRejectsTechnicalEntityNoise(t *testing.T) {
	sys := buildAnalyzeSystemPrompt()
	for _, needle := range []string{
		`Never create entities named "theme", "OCR", "ORC", "photo", "image", "caption", "artifact", "text", "unknown", "untitled"`,
		`"quality tuning", "quality tuning lab", "debug", "fixture", "scenario", "receipt", "screenshot", "bookmark", or "link"`,
		"Do not turn artifact-processing labels, OCR labels, or visual classifier labels into entities.",
		"return entities: [], candidate_edges: [], salience_score <= 0.25",
		"Emotion alone is not enough for a reflection.",
		"first-person speech transcript that names a recurring constraint",
		"protect mornings for writing before meetings",
		"Preserve the user's language. Chinese or mixed Chinese/English notes can be meaningful",
		"For same-name people, do not merge identities",
		"Sensitive stress, health, money, or despair language should be handled conservatively",
		"Metadata-only links, dramatic article titles, screenshots, receipts, menus, invoices, and calendar OCR are carriers",
		"Multiple ambient artifacts near the same time do not create a storyline by themselves.",
	} {
		if !strings.Contains(sys, needle) {
			t.Errorf("system prompt missing quality rule %q; got: %s", needle, sys)
		}
	}
}

func TestBuildReflectionSystemPromptAsksForLowConfidenceWhenEvidenceIsWeak(t *testing.T) {
	sys := buildReflectionSystemPrompt("generate")
	for _, needle := range []string{
		"Do not infer a life pattern from a single ordinary photo",
		"return low confidence below 0.4",
		"Do not turn one short emotional sentence into a life pattern.",
		"Treat repeated concrete decisions, named people, commitments, or recurring constraints as stronger evidence",
		"first-person voice transcripts about a recurring constraint",
		"protected creative time",
		"For sensitive stress, health, money, or despair language, stay factual",
	} {
		if !strings.Contains(sys, needle) {
			t.Errorf("reflection prompt missing quality rule %q; got: %s", needle, sys)
		}
	}
}

func TestPromptProfileDefaultsToBalanced(t *testing.T) {
	var opts *DebugOptions
	if got := opts.PromptProfileOrDefault(); got != "balanced" {
		t.Fatalf("nil debug options default = %q, want balanced", got)
	}
	if got := (&DebugOptions{PromptProfile: "unknown"}).PromptProfileOrDefault(); got != "balanced" {
		t.Fatalf("unknown debug profile = %q, want balanced", got)
	}
}

func TestStrictPromptProfileAddsConservativeRules(t *testing.T) {
	sys := buildAnalyzeSystemPromptForProfile("strict")
	for _, needle := range []string{
		"Prompt profile: strict.",
		"Prefer omission over weak inference.",
		"Single ordinary records should usually produce no story-level inference.",
		"single photo, OCR, receipt, debug, or quality-tuning captures",
	} {
		if !strings.Contains(sys, needle) {
			t.Errorf("strict prompt missing %q; got: %s", needle, sys)
		}
	}
}

func TestAnalyzePromptIgnoresDebugProvenance(t *testing.T) {
	sys := buildAnalyzeSystemPromptForProfile("balanced")
	for _, needle := range []string{
		`"quality tuning lab"`,
		"Ignore debug provenance strings",
		"must never become tags, themes, entities, candidate edges, summaries, salience evidence, reflection hints, or storyline anchors",
	} {
		if !strings.Contains(sys, needle) {
			t.Errorf("analyze prompt missing debug provenance rule %q; got: %s", needle, sys)
		}
	}
}
