package ai

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
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
		SchemaVersion: "record_aggregate.v1",
		AnalysisReason: "preview",
		RecordShell: AnalyzeRecordShell{RawText: "今天很开心"},
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
		SchemaVersion: "record_aggregate.v1",
		AnalysisReason: "preview",
		RecordShell: AnalyzeRecordShell{RawText: "今天很开心"},
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

func writeTestJSON(w http.ResponseWriter, payload any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(payload)
}
