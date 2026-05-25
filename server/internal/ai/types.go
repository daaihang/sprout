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
	AnalyzeV7(ctx context.Context, req AnalyzeV7Request, user UserContext) (AnalyzeV7Result, error)
	GenerateReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error)
	ReplayReflection(ctx context.Context, req ReflectionRequest, user UserContext) (ReflectionResult, error)
	RefineTranscript(ctx context.Context, req TranscriptRefinementRequest, user UserContext) (TranscriptRefinementResult, error)
	SuggestQuestions(ctx context.Context, req QuestionSuggestionRequest, user UserContext) (QuestionSuggestionResult, error)
	SuggestChapters(ctx context.Context, req ChapterSuggestionRequest, user UserContext) (ChapterSuggestionResult, error)
	AnalyzePhotoSemantics(ctx context.Context, req PhotoSemanticAnalysisRequest, user UserContext) (PhotoSemanticAnalysisResult, error)
}

type UserContext struct {
	UserID string
	Tier   string
}

type AnalyzeRequest struct {
	SchemaVersion      string                       `json:"schema_version"`
	ClientVersion      string                       `json:"client_version,omitempty"`
	ClientRequestID    string                       `json:"client_request_id,omitempty"`
	AnalysisReason     string                       `json:"analysis_reason"`
	RecordShell        AnalyzeRecordShell           `json:"record_shell"`
	Artifacts          []AnalyzeArtifact            `json:"artifacts"`
	KnownEntities      []KnownEntityReference       `json:"known_entities"`
	MoodEvidence       []AnalyzeV7MoodEvidence      `json:"mood_evidence,omitempty"`
	ContextPack        *AnalyzeV7ContextPack        `json:"context_pack,omitempty"`
	ClientCapabilities *AnalyzeV7ClientCapabilities `json:"client_capabilities,omitempty"`
	DebugOptions       *DebugOptions                `json:"debug_options,omitempty"`
}

type AnalyzeRecordShell struct {
	ID            string `json:"id,omitempty"`
	CreatedAt     string `json:"created_at,omitempty"`
	UpdatedAt     string `json:"updated_at,omitempty"`
	RawText       string `json:"raw_text"`
	CaptureSource string `json:"capture_source,omitempty"`
	UserMood      string `json:"user_mood,omitempty"`
	UserIntensity *int   `json:"user_intensity,omitempty"`
	InputContext  string `json:"input_context,omitempty"`
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
	Intensity  *float64 `json:"intensity,omitempty"`
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
	FromName   string   `json:"from_name"`
	FromKind   string   `json:"from_kind"`
	ToName     string   `json:"to_name"`
	ToKind     string   `json:"to_kind"`
	Relation   string   `json:"relation"`
	Confidence *float64 `json:"confidence,omitempty"`
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

type AnalyzeV7Result struct {
	Response AnalyzeV7Response `json:"response"`
	Provider string            `json:"provider"`
	Model    string            `json:"model"`
	Usage    Usage             `json:"usage"`
}

type ReflectionRequest struct {
	RecordShell   AnalyzeRecordShell     `json:"record_shell"`
	Artifacts     []AnalyzeArtifact      `json:"artifacts"`
	LinkedArcID   string                 `json:"linked_arc_id,omitempty"`
	KnownEntities []KnownEntityReference `json:"known_entities,omitempty"`
	Prompt        string                 `json:"prompt,omitempty"`
	DebugOptions  *DebugOptions          `json:"debug_options,omitempty"`
}

type DebugOptions struct {
	PromptProfile string `json:"prompt_profile,omitempty"`
}

func (d *DebugOptions) PromptProfileOrDefault() string {
	if d == nil {
		return "balanced"
	}
	switch strings.ToLower(strings.TrimSpace(d.PromptProfile)) {
	case "strict":
		return "strict"
	case "experimental":
		return "experimental"
	default:
		return "balanced"
	}
}

type ReflectionResponse struct {
	Title           string   `json:"title"`
	Body            string   `json:"body"`
	EvidenceSummary string   `json:"evidence_summary"`
	Confidence      float64  `json:"confidence"`
	SourceRecordIDs []string `json:"source_record_ids"`
}

type ReflectionResult struct {
	Response ReflectionResponse `json:"response"`
	Provider string             `json:"provider"`
	Model    string             `json:"model"`
	Usage    Usage              `json:"usage"`
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

func (r ReflectionRequest) ValidateGenerate() error {
	if strings.TrimSpace(r.RecordShell.RawText) == "" && len(r.Artifacts) == 0 && strings.TrimSpace(r.Prompt) == "" {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func (r ReflectionRequest) ValidateReplay() error {
	if strings.TrimSpace(r.Prompt) == "" && strings.TrimSpace(r.RecordShell.RawText) == "" {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func oneHourFromNow() string {
	return time.Now().UTC().Add(time.Hour).Format(time.RFC3339)
}
