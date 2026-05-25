package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

func (p *AnthropicProvider) RefineTranscript(ctx context.Context, req TranscriptRefinementRequest, user UserContext) (TranscriptRefinementResult, error) {
	if err := req.Validate(); err != nil {
		return TranscriptRefinementResult{}, err
	}
	raw, model, usage, err := p.runV6JSON(ctx, "refine_transcript", req, user)
	if err != nil {
		return TranscriptRefinementResult{}, err
	}
	resp, err := parseV6JSONResponse(raw, normalizeTranscriptRefinementResponse)
	if err != nil {
		return TranscriptRefinementResult{}, err
	}
	return TranscriptRefinementResult{Response: resp, Provider: p.Name(), Model: model, Usage: usage}, nil
}

func (p *AnthropicProvider) SuggestQuestions(ctx context.Context, req QuestionSuggestionRequest, user UserContext) (QuestionSuggestionResult, error) {
	if err := req.Validate(); err != nil {
		return QuestionSuggestionResult{}, err
	}
	raw, model, usage, err := p.runV6JSON(ctx, "suggest_questions", req, user)
	if err != nil {
		return QuestionSuggestionResult{}, err
	}
	resp, err := parseV6JSONResponse(raw, normalizeQuestionSuggestionResponse)
	if err != nil {
		return QuestionSuggestionResult{}, err
	}
	return QuestionSuggestionResult{Response: resp, Provider: p.Name(), Model: model, Usage: usage}, nil
}

func (p *AnthropicProvider) SuggestChapters(ctx context.Context, req ChapterSuggestionRequest, user UserContext) (ChapterSuggestionResult, error) {
	if err := req.Validate(); err != nil {
		return ChapterSuggestionResult{}, err
	}
	raw, model, usage, err := p.runV6JSON(ctx, "suggest_chapters", req, user)
	if err != nil {
		return ChapterSuggestionResult{}, err
	}
	resp, err := parseV6JSONResponse(raw, normalizeChapterSuggestionResponse)
	if err != nil {
		return ChapterSuggestionResult{}, err
	}
	return ChapterSuggestionResult{Response: resp, Provider: p.Name(), Model: model, Usage: usage}, nil
}

func (p *AnthropicProvider) AnalyzePhotoSemantics(ctx context.Context, req PhotoSemanticAnalysisRequest, user UserContext) (PhotoSemanticAnalysisResult, error) {
	if err := req.Validate(); err != nil {
		return PhotoSemanticAnalysisResult{}, err
	}
	raw, model, usage, err := p.runV6JSON(ctx, "analyze_photo_semantics", req, user)
	if err != nil {
		return PhotoSemanticAnalysisResult{}, err
	}
	resp, err := parseV6JSONResponse(raw, normalizePhotoSemanticAnalysisResponse)
	if err != nil {
		return PhotoSemanticAnalysisResult{}, err
	}
	return PhotoSemanticAnalysisResult{Response: resp, Provider: p.Name(), Model: model, Usage: usage}, nil
}

func (p *AnthropicProvider) runV6JSON(ctx context.Context, operation string, req any, user UserContext) (string, string, Usage, error) {
	userPrompt, err := buildV6UserPrompt(operation, req, user)
	if err != nil {
		return "", "", Usage{}, err
	}
	systemPrompt := buildV6SystemPrompt(operation)
	payload := anthropicRequest{
		Model:     p.model,
		MaxTokens: 700,
		System:    systemPrompt,
		Messages: []anthropicMessage{{
			Role: "user",
			Content: []anthropicContentRequest{{
				Type: "text",
				Text: userPrompt,
			}},
		}},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", "", Usage{}, fmt.Errorf("marshal anthropic v6 request: %w", err)
	}

	p.logger.Info("📤 anthropic v6 request",
		"provider", p.Name(),
		"operation", operation,
		"model", p.model,
		"user_id", user.UserID,
		"request_body_len", len(body),
	)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(body))
	if err != nil {
		return "", "", Usage{}, fmt.Errorf("create anthropic v6 request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-api-key", p.apiKey)
	httpReq.Header.Set("anthropic-version", p.version)
	if p.heliconeKey != "" {
		httpReq.Header.Set("Helicone-Auth", "Bearer "+p.heliconeKey)
		if user.UserID != "" {
			httpReq.Header.Set("Helicone-User-Id", user.UserID)
		}
	}

	start := time.Now()
	resp, err := doRequestWithRetry(ctx, p.client, httpReq, p.maxRetries, p.backoff)
	elapsed := time.Since(start)
	if err != nil {
		p.logger.Error("❌ anthropic v6 request failed", "operation", operation, "duration_ms", elapsed.Milliseconds(), "error", err)
		return "", "", Usage{}, fmt.Errorf("anthropic v6 request failed: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return "", "", Usage{}, fmt.Errorf("read anthropic v6 response: %w", err)
	}
	if resp.StatusCode >= 300 {
		p.logger.Error("❌ anthropic v6 response failed", "operation", operation, "status", resp.StatusCode, "body", truncateBody(responseBody, 2048))
		return "", "", Usage{}, fmt.Errorf("anthropic v6 status %d", resp.StatusCode)
	}

	var decoded anthropicResponse
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		return "", "", Usage{}, fmt.Errorf("decode anthropic v6 response: %w", err)
	}

	return joinAnthropicText(decoded.Content), decoded.Model, Usage{
		InputTokens:  decoded.Usage.InputTokens,
		OutputTokens: decoded.Usage.OutputTokens,
	}, nil
}
