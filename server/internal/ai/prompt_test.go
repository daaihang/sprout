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

func TestBuildAnalyzeSystemPromptMentionsContextKinds(t *testing.T) {
	sys := buildAnalyzeSystemPrompt()
	for _, kind := range []string{"weather", "music", "location"} {
		if !strings.Contains(sys, kind) {
			t.Errorf("system prompt should reference %q so the LLM treats it as ambient context; got: %s", kind, sys)
		}
	}
}
