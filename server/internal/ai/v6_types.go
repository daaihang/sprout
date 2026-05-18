package ai

import "strings"

type TranscriptRefinementRequest struct {
	SchemaVersion   int    `json:"schema_version"`
	Locale          string `json:"locale,omitempty"`
	RecordID        string `json:"record_id,omitempty"`
	AudioArtifactID string `json:"audio_artifact_id,omitempty"`
	RawTranscript   string `json:"raw_transcript"`
	Style           string `json:"style,omitempty"`
	AllowTitle      bool   `json:"allow_title"`
}

type TranscriptEdit struct {
	Kind    string `json:"kind"`
	Summary string `json:"summary"`
}

type TranscriptRefinementResponse struct {
	SchemaVersion     int              `json:"schema_version"`
	RefinedTranscript string           `json:"refined_transcript"`
	SuggestedTitle    string           `json:"suggested_title,omitempty"`
	Edits             []TranscriptEdit `json:"edits"`
}

type TranscriptRefinementResult struct {
	Response TranscriptRefinementResponse `json:"response"`
	Provider string                       `json:"provider"`
	Model    string                       `json:"model"`
	Usage    Usage                        `json:"usage"`
}

type IntelligenceTarget struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Kind string `json:"kind,omitempty"`
}

type EvidenceSnippet struct {
	RecordID   string `json:"record_id,omitempty"`
	ArtifactID string `json:"artifact_id,omitempty"`
	Snippet    string `json:"snippet"`
	CreatedAt  string `json:"created_at,omitempty"`
}

type KnownProfileSummary struct {
	DisplayName        string   `json:"display_name,omitempty"`
	Aliases            []string `json:"aliases,omitempty"`
	RelationshipToUser string   `json:"relationship_to_user,omitempty"`
}

type QuestionSuggestionPreferences struct {
	AllowSensitiveQuestions bool   `json:"allow_sensitive_questions"`
	QuestionTone            string `json:"question_tone,omitempty"`
}

type QuestionSuggestionRequest struct {
	SchemaVersion  int                           `json:"schema_version"`
	Locale         string                        `json:"locale,omitempty"`
	Target         IntelligenceTarget            `json:"target"`
	Evidence       []EvidenceSnippet             `json:"evidence"`
	KnownProfile   KnownProfileSummary           `json:"known_profile,omitempty"`
	UserPreferences QuestionSuggestionPreferences `json:"user_preferences,omitempty"`
}

type QuestionCandidate struct {
	Kind             string   `json:"kind"`
	Prompt           string   `json:"prompt"`
	Reason           string   `json:"reason"`
	CandidateAnswers []string `json:"candidate_answers"`
	Confidence       float64  `json:"confidence"`
	Sensitivity       string   `json:"sensitivity"`
}

type QuestionSuggestionResponse struct {
	SchemaVersion int                 `json:"schema_version"`
	Questions     []QuestionCandidate `json:"questions"`
}

type QuestionSuggestionResult struct {
	Response QuestionSuggestionResponse `json:"response"`
	Provider string                     `json:"provider"`
	Model    string                     `json:"model"`
	Usage    Usage                      `json:"usage"`
}

type TimeWindow struct {
	Start string `json:"start"`
	End   string `json:"end"`
}

type ChapterSignal struct {
	Kind        string  `json:"kind"`
	Label       string  `json:"label"`
	RecordCount int     `json:"record_count"`
	Salience    float64 `json:"salience"`
}

type ChapterSuggestionRequest struct {
	SchemaVersion   int               `json:"schema_version"`
	Locale          string            `json:"locale,omitempty"`
	TimeWindow      TimeWindow        `json:"time_window"`
	Signals         []ChapterSignal   `json:"signals"`
	EvidenceSnippets []EvidenceSnippet `json:"evidence_snippets"`
}

type ChapterCandidate struct {
	Title                string   `json:"title"`
	Summary              string   `json:"summary"`
	EvidenceRecordIDs    []string `json:"evidence_record_ids"`
	Confidence           float64  `json:"confidence"`
	RequiresConfirmation bool     `json:"requires_confirmation"`
}

type ChapterSuggestionResponse struct {
	SchemaVersion     int                `json:"schema_version"`
	ChapterCandidates []ChapterCandidate `json:"chapter_candidates"`
}

type ChapterSuggestionResult struct {
	Response ChapterSuggestionResponse `json:"response"`
	Provider string                    `json:"provider"`
	Model    string                    `json:"model"`
	Usage    Usage                     `json:"usage"`
}

type PhotoSemanticAnalysisRequest struct {
	SchemaVersion   int               `json:"schema_version"`
	Locale          string            `json:"locale,omitempty"`
	RecordID        string            `json:"record_id,omitempty"`
	PhotoArtifactID string            `json:"photo_artifact_id,omitempty"`
	LocalLabels     []string          `json:"local_labels,omitempty"`
	OCRText         string            `json:"ocr_text,omitempty"`
	CaptionHint     string            `json:"caption_hint,omitempty"`
	Metadata        map[string]string `json:"metadata,omitempty"`
}

type PhotoSemanticAnalysisResponse struct {
	SchemaVersion   int      `json:"schema_version"`
	SemanticSummary string   `json:"semantic_summary"`
	SuggestedTitle  string   `json:"suggested_title,omitempty"`
	Tags           []string `json:"tags"`
	Objects        []string `json:"objects"`
	TextHighlights []string `json:"text_highlights"`
	Safety          string   `json:"safety"`
	Confidence     float64  `json:"confidence"`
}

type PhotoSemanticAnalysisResult struct {
	Response PhotoSemanticAnalysisResponse `json:"response"`
	Provider string                        `json:"provider"`
	Model    string                        `json:"model"`
	Usage    Usage                         `json:"usage"`
}

type NotificationIntentPreferences struct {
	MaxPerDay           int    `json:"max_per_day,omitempty"`
	QuietHoursStart    string `json:"quiet_hours_start,omitempty"`
	QuietHoursEnd      string `json:"quiet_hours_end,omitempty"`
	RichPreviewsEnabled bool   `json:"rich_previews_enabled"`
}

type NotificationIntentSuggestionRequest struct {
	SchemaVersion   int                           `json:"schema_version"`
	Locale          string                        `json:"locale,omitempty"`
	TimeZone        string                        `json:"time_zone,omitempty"`
	Trigger         string                        `json:"trigger"`
	RecentEvidence  []EvidenceSnippet             `json:"recent_evidence,omitempty"`
	Question        *QuestionCandidate             `json:"question,omitempty"`
	Preferences     NotificationIntentPreferences `json:"preferences,omitempty"`
}

type NotificationIntentCandidate struct {
	Kind         string `json:"kind"`
	PrivacyLevel string `json:"privacy_level"`
	Title        string `json:"title"`
	Body         string `json:"body"`
	DeepLink     string `json:"deep_link,omitempty"`
	ScheduledAt  string `json:"scheduled_at,omitempty"`
}

type NotificationIntentSuggestionResponse struct {
	SchemaVersion int                         `json:"schema_version"`
	Intent        NotificationIntentCandidate `json:"intent"`
}

type NotificationIntentSuggestionResult struct {
	Response NotificationIntentSuggestionResponse `json:"response"`
	Provider string                               `json:"provider"`
	Model    string                               `json:"model"`
	Usage    Usage                                `json:"usage"`
}

func (r TranscriptRefinementRequest) Validate() error {
	if strings.TrimSpace(r.RawTranscript) == "" {
		return ErrInvalidAnalyzeRequest
	}
	if len(r.RawTranscript) > 20000 {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func (r QuestionSuggestionRequest) Validate() error {
	if strings.TrimSpace(r.Target.Type) == "" || strings.TrimSpace(r.Target.ID) == "" {
		return ErrInvalidAnalyzeRequest
	}
	if len(r.Evidence) == 0 {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func (r ChapterSuggestionRequest) Validate() error {
	if len(r.Signals) == 0 && len(r.EvidenceSnippets) == 0 {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func (r PhotoSemanticAnalysisRequest) Validate() error {
	if len(r.LocalLabels) == 0 && strings.TrimSpace(r.OCRText) == "" && strings.TrimSpace(r.CaptionHint) == "" {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}

func (r NotificationIntentSuggestionRequest) Validate() error {
	if strings.TrimSpace(r.Trigger) == "" {
		return ErrInvalidAnalyzeRequest
	}
	return nil
}
