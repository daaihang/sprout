package ai

import (
	"context"
	"errors"
	"time"
)

var ErrInvalidAnalyzeRequest = errors.New("invalid analyze request")

type Provider interface {
	Name() string
	Analyze(ctx context.Context, req AnalyzeRequest, user UserContext) (AnalyzeResult, error)
}

type UserContext struct {
	UserID string
	Tier   string
}

type AnalyzeRequest struct {
	Record  RecordContent   `json:"record"`
	Persons []PersonProfile `json:"persons"`
}

type RecordContent struct {
	ID        string   `json:"id,omitempty"`
	Content   string   `json:"content"`
	CreatedAt string   `json:"created_at,omitempty"`
	Tags      []string `json:"tags,omitempty"`
}

type PersonProfile struct {
	ID              string `json:"id,omitempty"`
	Name            string `json:"name"`
	Relationship    string `json:"relationship,omitempty"`
	LastMentionedAt string `json:"last_mentioned_at,omitempty"`
}

type AnalyzeResponse struct {
	Tags     []string      `json:"tags"`
	Emotion  EmotionResult `json:"emotion"`
	Persons  []PersonMatch `json:"persons"`
	NewMedia []MediaHint   `json:"new_media"`
	Insight  string        `json:"insight"`
	FollowUp *FollowUp     `json:"follow_up"`
}

type EmotionResult struct {
	Label      string   `json:"label"`
	Intensity  *int     `json:"intensity,omitempty"`
	Confidence *float64 `json:"confidence,omitempty"`
}

type PersonMatch struct {
	Name       string   `json:"name"`
	Action     string   `json:"action"`
	PersonID   string   `json:"person_id,omitempty"`
	Confidence *float64 `json:"confidence,omitempty"`
}

type MediaHint struct {
	Type       string `json:"type"`
	Title      string `json:"title"`
	Creator    string `json:"creator,omitempty"`
	SearchHint string `json:"search_hint,omitempty"`
}

type FollowUp struct {
	Question  string `json:"question"`
	ExpiresAt string `json:"expires_at,omitempty"`
}

type Usage struct {
	InputTokens  int `json:"input_tokens,omitempty"`
	OutputTokens int `json:"output_tokens,omitempty"`
}

type AnalyzeResult struct {
	Response AnalyzeResponse `json:"response"`
	Provider string          `json:"provider"`
	Model    string          `json:"model"`
	Usage    Usage           `json:"usage"`
}

func (r AnalyzeRequest) Validate() error {
	if len(r.Record.Content) == 0 {
		return ErrInvalidAnalyzeRequest
	}
	if len(r.Record.Content) > 20000 {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func NormalizeResponse(resp AnalyzeResponse) AnalyzeResponse {
	if resp.Tags == nil {
		resp.Tags = []string{}
	}
	if resp.Persons == nil {
		resp.Persons = []PersonMatch{}
	}
	if resp.NewMedia == nil {
		resp.NewMedia = []MediaHint{}
	}
	if resp.Emotion.Label == "" {
		resp.Emotion.Label = "neutral"
	}
	if resp.Insight == "" {
		resp.Insight = "No insight generated."
	}
	if resp.FollowUp != nil && resp.FollowUp.Question == "" {
		resp.FollowUp = nil
	}
	return resp
}

func oneHourFromNow() string {
	return time.Now().UTC().Add(time.Hour).Format(time.RFC3339)
}
