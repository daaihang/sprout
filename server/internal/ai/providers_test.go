package ai

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"sprout/server/internal/config"
)

func TestAnthropicProviderAnalyze(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", r.Method)
		}
		if got := r.Header.Get("x-api-key"); got != "anthropic-key" {
			t.Fatalf("unexpected api key header %q", got)
		}
		if got := r.Header.Get("anthropic-version"); got != "2023-06-01" {
			t.Fatalf("unexpected anthropic version %q", got)
		}

		var req anthropicRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode anthropic request: %v", err)
		}
		if req.Model != "claude-test" {
			t.Fatalf("unexpected model %q", req.Model)
		}

		if req.ToolChoice == nil || req.ToolChoice.Name != "submit_analyze_response" {
			t.Fatalf("expected anthropic tool choice")
		}
		if len(req.Tools) != 1 || req.Tools[0].Name != "submit_analyze_response" {
			t.Fatalf("expected anthropic tool schema")
		}

		writeTestJSON(w, map[string]any{
			"model": "claude-test",
			"content": []map[string]any{
				{
					"type": "tool_use",
					"name": "submit_analyze_response",
					"input": map[string]any{
						"tags":            []string{"journal"},
						"emotion":         map[string]any{"label": "positive", "intensity": 3, "confidence": 0.9},
						"entities":        []any{},
						"candidate_edges": []any{},
						"insight":         "live anthropic",
						"summary":         "anthropic summary",
						"salience_score":  0.67,
						"retrieval_terms": []string{"gratitude", "journal"},
						"reflection_hint": "watch for repetition",
						"follow_up":       nil,
					},
				},
			},
			"usage": map[string]any{
				"input_tokens":  111,
				"output_tokens": 222,
			},
		})
	}))
	defer server.Close()

	provider := NewAnthropicProvider(
		&http.Client{Timeout: 2 * time.Second},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		config.Config{
			AIAPIKey:         "anthropic-key",
			AIBaseURL:        server.URL,
			AIModel:          "claude-test",
			AnthropicVersion: "2023-06-01",
		},
	)

	result, err := provider.Analyze(context.Background(), AnalyzeRequest{
		SchemaVersion:  "record_aggregate.v1",
		AnalysisReason: "preview",
		RecordShell:    AnalyzeRecordShell{RawText: "今天很开心"},
	}, UserContext{UserID: "user-1", Tier: "grow"})
	if err != nil {
		t.Fatalf("anthropic analyze: %v", err)
	}
	if result.Provider != "anthropic" || result.Model != "claude-test" {
		t.Fatalf("unexpected result meta: %+v", result)
	}
	if result.Response.Insight != "live anthropic" {
		t.Fatalf("unexpected insight %q", result.Response.Insight)
	}
}

func TestOpenAICompatibleProviderAnalyze(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer openai-key" {
			t.Fatalf("unexpected auth header %q", got)
		}

		var req openAIChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode openai request: %v", err)
		}
		if req.Model != "gpt-test" {
			t.Fatalf("unexpected model %q", req.Model)
		}
		if req.ResponseFormat["type"] != "json_object" {
			t.Fatalf("expected json_object response format")
		}

		writeTestJSON(w, map[string]any{
			"model": "gpt-test",
			"choices": []map[string]any{
				{
					"message": map[string]any{
						"content": `{"tags":["journal","gratitude"],"emotion":{"label":"positive","intensity":4,"confidence":0.88},"entities":[],"candidate_edges":[],"insight":"live openai","summary":"openai summary","salience_score":0.71,"retrieval_terms":["gratitude","journal"],"reflection_hint":"watch for repeated gratitude anchors","follow_up":null}`,
					},
				},
			},
			"usage": map[string]any{
				"prompt_tokens":     12,
				"completion_tokens": 34,
			},
		})
	}))
	defer server.Close()

	provider := NewOpenAICompatibleProvider(
		&http.Client{Timeout: 2 * time.Second},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		config.Config{
			AIAPIKey:  "openai-key",
			AIBaseURL: server.URL,
			AIModel:   "gpt-test",
		},
	)

	result, err := provider.Analyze(context.Background(), AnalyzeRequest{
		SchemaVersion:  "record_aggregate.v1",
		AnalysisReason: "preview",
		RecordShell:    AnalyzeRecordShell{RawText: "今天很开心"},
	}, UserContext{UserID: "user-1", Tier: "grow"})
	if err != nil {
		t.Fatalf("openai analyze: %v", err)
	}
	if result.Provider != "openai_compatible" || result.Model != "gpt-test" {
		t.Fatalf("unexpected result meta: %+v", result)
	}
	if result.Response.Insight != "live openai" {
		t.Fatalf("unexpected insight %q", result.Response.Insight)
	}
}

func TestAnthropicProviderGenerateReflection(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", r.Method)
		}

		var req anthropicRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode anthropic request: %v", err)
		}
		if req.System == "" || req.Messages[0].Content[0].Text == "" {
			t.Fatalf("expected reflection prompt payload")
		}

		writeTestJSON(w, map[string]any{
			"model": "claude-test",
			"content": []map[string]any{
				{
					"type": "text",
					"text": `{"title":"Planning Pattern","body":"Dinner with Linh keeps surfacing as a reliable planning unlock.","evidence_summary":"Dinner note | quarter plan","confidence":0.74,"source_record_ids":["r1"]}`,
				},
			},
			"usage": map[string]any{
				"input_tokens":  88,
				"output_tokens": 55,
			},
		})
	}))
	defer server.Close()

	provider := NewAnthropicProvider(
		&http.Client{Timeout: 2 * time.Second},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		config.Config{
			AIAPIKey:         "anthropic-key",
			AIBaseURL:        server.URL,
			AIModel:          "claude-test",
			AnthropicVersion: "2023-06-01",
		},
	)

	result, err := provider.GenerateReflection(context.Background(), ReflectionRequest{
		RecordShell: AnalyzeRecordShell{ID: "r1", RawText: "Dinner with Linh clarified the quarter plan."},
		Artifacts:   []AnalyzeArtifact{{ID: "a1", Kind: "text", Title: "Dinner note"}},
	}, UserContext{UserID: "user-1", Tier: "grow"})
	if err != nil {
		t.Fatalf("anthropic generate reflection: %v", err)
	}
	if result.Response.Title != "Planning Pattern" {
		t.Fatalf("unexpected reflection title %q", result.Response.Title)
	}
	if result.Provider != "anthropic" {
		t.Fatalf("unexpected provider %q", result.Provider)
	}
}

func TestOpenAICompatibleProviderReplayReflection(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", r.Method)
		}

		var req openAIChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode openai request: %v", err)
		}
		if req.ResponseFormat["type"] != "json_object" {
			t.Fatalf("expected json object response format")
		}

		writeTestJSON(w, map[string]any{
			"model": "gpt-test",
			"choices": []map[string]any{
				{
					"message": map[string]any{
						"content": `{"title":"Reflection Replay","body":"The planning pattern is not random; it keeps appearing around calm post-dinner review.","evidence_summary":"Dinner note","confidence":0.66,"source_record_ids":["r1"]}`,
					},
				},
			},
			"usage": map[string]any{
				"prompt_tokens":     20,
				"completion_tokens": 32,
			},
		})
	}))
	defer server.Close()

	provider := NewOpenAICompatibleProvider(
		&http.Client{Timeout: 2 * time.Second},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		config.Config{
			AIAPIKey:  "openai-key",
			AIBaseURL: server.URL,
			AIModel:   "gpt-test",
		},
	)

	result, err := provider.ReplayReflection(context.Background(), ReflectionRequest{
		RecordShell: AnalyzeRecordShell{ID: "r1", RawText: "Dinner with Linh clarified the quarter plan."},
		LinkedArcID: "arc-1",
		Prompt:      "Restate the reflection with more emphasis on the planning pattern.",
	}, UserContext{UserID: "user-1", Tier: "grow"})
	if err != nil {
		t.Fatalf("openai replay reflection: %v", err)
	}
	if result.Response.Title != "Reflection Replay" {
		t.Fatalf("unexpected reflection title %q", result.Response.Title)
	}
	if result.Provider != "openai_compatible" {
		t.Fatalf("unexpected provider %q", result.Provider)
	}
}

func TestOpenAICompatibleProviderV6RefineTranscript(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req openAIChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode openai request: %v", err)
		}
		if req.ResponseFormat["type"] != "json_object" {
			t.Fatalf("expected json object response format")
		}
		if !strings.Contains(req.Messages[0].Content, `"refined_transcript"`) {
			t.Fatalf("expected v6 transcript schema in system prompt")
		}

		writeTestJSON(w, map[string]any{
			"model": "gpt-test",
			"choices": []map[string]any{
				{
					"message": map[string]any{
						"content": `{"schema_version":1,"refined_transcript":"今天和阿远聊了搬家的事。","suggested_title":"搬家讨论","edits":[{"kind":"punctuation","summary":"补全标点"}]}`,
					},
				},
			},
			"usage": map[string]any{
				"prompt_tokens":     9,
				"completion_tokens": 13,
			},
		})
	}))
	defer server.Close()

	provider := NewOpenAICompatibleProvider(
		&http.Client{Timeout: 2 * time.Second},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		config.Config{
			AIAPIKey:  "openai-key",
			AIBaseURL: server.URL,
			AIModel:   "gpt-test",
		},
	)

	result, err := provider.RefineTranscript(context.Background(), TranscriptRefinementRequest{
		RawTranscript: "今天 和 阿远 聊了 搬家 的事",
		AllowTitle:    true,
	}, UserContext{UserID: "user-1", Tier: "grow"})
	if err != nil {
		t.Fatalf("refine transcript: %v", err)
	}
	if result.Response.RefinedTranscript == "" || result.Response.SuggestedTitle != "搬家讨论" {
		t.Fatalf("unexpected transcript result: %+v", result)
	}
	if result.Usage.InputTokens != 9 || result.Usage.OutputTokens != 13 {
		t.Fatalf("unexpected usage: %+v", result.Usage)
	}
}

func TestResolveOpenAICompatibleEndpoint(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{
			name: "empty uses openai default",
			raw:  "",
			want: "https://api.openai.com/v1/chat/completions",
		},
		{
			name: "deepseek root appends completions path",
			raw:  "https://api.deepseek.com",
			want: "https://api.deepseek.com/chat/completions",
		},
		{
			name: "v1 suffix appends completions path",
			raw:  "https://api.example.com/v1",
			want: "https://api.example.com/v1/chat/completions",
		},
		{
			name: "chat suffix appends completions leaf",
			raw:  "https://api.example.com/chat",
			want: "https://api.example.com/chat/completions",
		},
		{
			name: "full endpoint remains unchanged",
			raw:  "https://api.example.com/chat/completions",
			want: "https://api.example.com/chat/completions",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := resolveOpenAICompatibleEndpoint(tt.raw); got != tt.want {
				t.Fatalf("resolveOpenAICompatibleEndpoint(%q) = %q, want %q", tt.raw, got, tt.want)
			}
		})
	}
}

func writeTestJSON(w http.ResponseWriter, payload any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(payload)
}
