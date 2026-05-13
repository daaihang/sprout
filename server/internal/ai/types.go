package ai

import (
	"context"
	"errors"
	"strings"
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
	SchemaVersion string                 `json:"schema_version"`
	ClientVersion string                 `json:"client_version,omitempty"`
	AnalysisReason string                `json:"analysis_reason"`
	RecordShell   AnalyzeRecordShell     `json:"record_shell"`
	Artifacts     []AnalyzeArtifact      `json:"artifacts"`
	KnownEntities []KnownEntityReference `json:"known_entities"`
}

type AnalyzeRecordShell struct {
	ID            string `json:"id,omitempty"`
	CreatedAt     string `json:"created_at,omitempty"`
	UpdatedAt     string `json:"updated_at,omitempty"`
	RawText       string `json:"raw_text"`
	CaptureSource string `json:"capture_source,omitempty"`
	UserMood      string `json:"user_mood,omitempty"`
	UserIntensity *int   `json:"user_intensity,omitempty"`
}

type AnalyzeArtifact struct {
	ID          string            `json:"id,omitempty"`
	Kind        string            `json:"kind"`
	Title       string            `json:"title,omitempty"`
	Summary     string            `json:"summary,omitempty"`
	TextContent string            `json:"text_content,omitempty"`
	Metadata    map[string]string `json:"metadata,omitempty"`
}

type KnownEntityReference struct {
	ID         string   `json:"id,omitempty"`
	Kind       string   `json:"kind"`
	Name       string   `json:"name"`
	Aliases    []string `json:"aliases,omitempty"`
	Confidence *float64 `json:"confidence,omitempty"`
}

type AnalyzeResponse struct {
	Tags           []string        `json:"tags"`
	Emotion        EmotionResult   `json:"emotion"`
	Entities       []EntityMention `json:"entities"`
	Edges          []CandidateEdge `json:"candidate_edges"`
	Insight        string          `json:"insight"`
	FollowUp       *FollowUp       `json:"follow_up"`
	Summary        string          `json:"summary,omitempty"`
	SalienceScore  *float64        `json:"salience_score,omitempty"`
	RetrievalTerms []string        `json:"retrieval_terms,omitempty"`
	ReflectionHint string          `json:"reflection_hint,omitempty"`
}

type EmotionResult struct {
	Label      string   `json:"label"`
	Intensity  *int     `json:"intensity,omitempty"`
	Confidence *float64 `json:"confidence,omitempty"`
}

type EntityMention struct {
	Kind        string   `json:"kind"`
	Name        string   `json:"name"`
	Canonical   string   `json:"canonical_name,omitempty"`
	Confidence  *float64 `json:"confidence,omitempty"`
	ArtifactIDs []string `json:"source_artifact_ids,omitempty"`
}

type CandidateEdge struct {
	FromName    string   `json:"from_name"`
	FromKind    string   `json:"from_kind"`
	ToName      string   `json:"to_name"`
	ToKind      string   `json:"to_kind"`
	Relation    string   `json:"relation"`
	Confidence  *float64 `json:"confidence,omitempty"`
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
	if strings.TrimSpace(r.SchemaVersion) == "" {
		return ErrInvalidAnalyzeRequest
	}
	if strings.TrimSpace(r.AnalysisReason) == "" {
		return ErrInvalidAnalyzeRequest
	}
	content := strings.TrimSpace(r.RecordShell.RawText)
	if content == "" && len(r.Artifacts) == 0 {
		return ErrInvalidAnalyzeRequest
	}
	if len(content) > 20000 {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func NormalizeResponse(resp AnalyzeResponse) AnalyzeResponse {
	if resp.Tags == nil {
		resp.Tags = []string{}
	}
	if resp.Entities == nil {
		resp.Entities = []EntityMention{}
	}
	if resp.Edges == nil {
		resp.Edges = []CandidateEdge{}
	}
	if resp.Emotion.Label == "" {
		resp.Emotion.Label = "neutral"
	}
	if resp.Insight == "" {
		resp.Insight = "No insight generated."
	}
	if strings.TrimSpace(resp.Summary) == "" {
		resp.Summary = resp.Insight
	}
	if resp.RetrievalTerms == nil {
		resp.RetrievalTerms = []string{}
	}
	if resp.FollowUp != nil && resp.FollowUp.Question == "" {
		resp.FollowUp = nil
	}
	return resp
}

func oneHourFromNow() string {
	return time.Now().UTC().Add(time.Hour).Format(time.RFC3339)
}
