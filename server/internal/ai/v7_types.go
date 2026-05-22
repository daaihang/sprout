package ai

import "strings"

const V7AnalyzePromptVersion = "mory-v7-analyze-2026-05-23"

type AnalyzeV7Request struct {
	SchemaVersion      int                         `json:"schema_version"`
	ClientRequestID    string                      `json:"client_request_id,omitempty"`
	RecordShell        AnalyzeRecordShell          `json:"record_shell"`
	Artifacts          []AnalyzeArtifact           `json:"artifacts"`
	KnownEntities      []KnownEntityReference      `json:"known_entities,omitempty"`
	MoodEvidence       []AnalyzeV7MoodEvidence     `json:"mood_evidence,omitempty"`
	ContextPack        AnalyzeV7ContextPack        `json:"context_pack"`
	ClientCapabilities AnalyzeV7ClientCapabilities `json:"client_capabilities,omitempty"`
	DebugOptions       *DebugOptions               `json:"debug_options,omitempty"`
}

type AnalyzeV7MoodEvidence struct {
	ID            string            `json:"id,omitempty"`
	RecordID      string            `json:"record_id,omitempty"`
	Valence       *float64          `json:"valence,omitempty"`
	Arousal       *float64          `json:"arousal,omitempty"`
	Dominance     *float64          `json:"dominance,omitempty"`
	Intensity     *float64          `json:"intensity,omitempty"`
	Labels        []string          `json:"labels,omitempty"`
	ToneHints     []string          `json:"tone_hints,omitempty"`
	Sources       []string          `json:"sources,omitempty"`
	Confidence    *float64          `json:"confidence,omitempty"`
	UserConfirmed bool              `json:"user_confirmed"`
	Evidence      []EvidenceSnippet `json:"evidence,omitempty"`
}

type AnalyzeV7ContextPack struct {
	PackID            string                      `json:"pack_id,omitempty"`
	TargetRecordID    string                      `json:"target_record_id,omitempty"`
	SelfBrief         *AnalyzeV7SelfBrief         `json:"self_brief,omitempty"`
	KnownProfiles     []AnalyzeV7KnownProfile     `json:"known_profiles,omitempty"`
	RelatedMemories   []AnalyzeV7RelatedMemory    `json:"related_memories,omitempty"`
	RelatedArcs       []AnalyzeV7RelatedArc       `json:"related_arcs,omitempty"`
	PriorReflections  []AnalyzeV7PriorReflection  `json:"prior_reflections,omitempty"`
	CorrectionSignals []AnalyzeV7CorrectionSignal `json:"correction_signals,omitempty"`
	AffectHistory     []AnalyzeV7AffectHistory    `json:"affect_history,omitempty"`
	PrivacyDecisions  []AnalyzeV7PrivacyDecision  `json:"privacy_decisions,omitempty"`
	BudgetReport      AnalyzeV7BudgetReport       `json:"budget_report,omitempty"`
	RetrievalReport   AnalyzeV7RetrievalReport    `json:"retrieval_report,omitempty"`
	BuiltAt           string                      `json:"built_at,omitempty"`
}

type AnalyzeV7SelfBrief struct {
	SelfEntityID    string   `json:"self_entity_id,omitempty"`
	DisplayName     string   `json:"display_name,omitempty"`
	Aliases         []string `json:"aliases,omitempty"`
	RoleLabels      []string `json:"role_labels,omitempty"`
	GoalTitles      []string `json:"goal_titles,omitempty"`
	ExpressionHints []string `json:"expression_hints,omitempty"`
	PrivacyMode     string   `json:"privacy_mode,omitempty"`
}

type AnalyzeV7KnownProfile struct {
	EntityID            string   `json:"entity_id,omitempty"`
	Kind                string   `json:"kind,omitempty"`
	DisplayName         string   `json:"display_name,omitempty"`
	RelationshipToUser  string   `json:"relationship_to_user,omitempty"`
	MentionCount        int      `json:"mention_count,omitempty"`
	CommonContextLabels []string `json:"common_context_labels,omitempty"`
	Confidence          *float64 `json:"confidence,omitempty"`
	InclusionReason     string   `json:"inclusion_reason,omitempty"`
}

type AnalyzeV7RelatedMemory struct {
	RecordID         string   `json:"record_id,omitempty"`
	Title            string   `json:"title,omitempty"`
	Snippet          string   `json:"snippet,omitempty"`
	CreatedAt        string   `json:"created_at,omitempty"`
	UserMood         string   `json:"user_mood,omitempty"`
	Score            float64  `json:"score,omitempty"`
	InclusionReasons []string `json:"inclusion_reasons,omitempty"`
}

type AnalyzeV7RelatedArc struct {
	ArcID           string   `json:"arc_id,omitempty"`
	Title           string   `json:"title,omitempty"`
	Summary         string   `json:"summary,omitempty"`
	Status          string   `json:"status,omitempty"`
	SourceRecordIDs []string `json:"source_record_ids,omitempty"`
	Score           float64  `json:"score,omitempty"`
}

type AnalyzeV7PriorReflection struct {
	ReflectionID    string   `json:"reflection_id,omitempty"`
	Title           string   `json:"title,omitempty"`
	EvidenceSummary string   `json:"evidence_summary,omitempty"`
	Status          string   `json:"status,omitempty"`
	SourceRecordIDs []string `json:"source_record_ids,omitempty"`
	Confidence      float64  `json:"confidence,omitempty"`
}

type AnalyzeV7CorrectionSignal struct {
	ID         string `json:"id,omitempty"`
	Kind       string `json:"kind,omitempty"`
	TargetType string `json:"target_type,omitempty"`
	TargetID   string `json:"target_id,omitempty"`
	Status     string `json:"status,omitempty"`
	Summary    string `json:"summary,omitempty"`
	AnsweredAt string `json:"answered_at,omitempty"`
}

type AnalyzeV7AffectHistory struct {
	Mood             string   `json:"mood,omitempty"`
	Count            int      `json:"count,omitempty"`
	LatestRecordID   string   `json:"latest_record_id,omitempty"`
	AverageValence   *float64 `json:"average_valence,omitempty"`
	AverageArousal   *float64 `json:"average_arousal,omitempty"`
	AverageDominance *float64 `json:"average_dominance,omitempty"`
	ToneHints        []string `json:"tone_hints,omitempty"`
	Sources          []string `json:"sources,omitempty"`
}

type AnalyzeV7PrivacyDecision struct {
	SourceType string `json:"source_type,omitempty"`
	SourceID   string `json:"source_id,omitempty"`
	Action     string `json:"action,omitempty"`
	Reason     string `json:"reason,omitempty"`
}

type AnalyzeV7BudgetReport struct {
	MaxProfiles             int `json:"max_profiles,omitempty"`
	MaxRelatedMemories      int `json:"max_related_memories,omitempty"`
	MaxArcs                 int `json:"max_arcs,omitempty"`
	MaxReflections          int `json:"max_reflections,omitempty"`
	MaxCorrections          int `json:"max_corrections,omitempty"`
	MaxAffectHistory        int `json:"max_affect_history,omitempty"`
	SelectedProfiles        int `json:"selected_profiles,omitempty"`
	SelectedRelatedMemories int `json:"selected_related_memories,omitempty"`
	SelectedArcs            int `json:"selected_arcs,omitempty"`
	SelectedReflections     int `json:"selected_reflections,omitempty"`
	SelectedCorrections     int `json:"selected_corrections,omitempty"`
	SelectedAffectHistory   int `json:"selected_affect_history,omitempty"`
	DroppedByBudget         int `json:"dropped_by_budget,omitempty"`
	DroppedByPrivacy        int `json:"dropped_by_privacy,omitempty"`
}

type AnalyzeV7RetrievalReport struct {
	SemanticSearchStatus string   `json:"semantic_search_status,omitempty"`
	RetrievalSources     []string `json:"retrieval_sources,omitempty"`
	CandidateMemoryCount int      `json:"candidate_memory_count,omitempty"`
	FallbackReason       string   `json:"fallback_reason,omitempty"`
}

type AnalyzeV7ClientCapabilities struct {
	SupportsProfileProposals       bool `json:"supports_profile_proposals,omitempty"`
	SupportsMergeCandidates        bool `json:"supports_merge_candidates,omitempty"`
	SupportsAffectSnapshot         bool `json:"supports_affect_snapshot,omitempty"`
	SupportsContextAwareReflection bool `json:"supports_context_aware_reflection,omitempty"`
	SupportsProposalOnlyWriteback  bool `json:"supports_proposal_only_writeback,omitempty"`
}

type AnalyzeV7Response struct {
	Analysis               AnalyzeResponse                  `json:"analysis"`
	AffectProposals        []AnalyzeV7AffectProposal        `json:"affect_proposals"`
	GraphDeltaProposals    []AnalyzeV7GraphDeltaProposal    `json:"graph_delta_proposals"`
	ProfileUpdateProposals []AnalyzeV7ProfileUpdateProposal `json:"profile_update_proposals"`
	MergeSplitCandidates   []AnalyzeV7MergeSplitCandidate   `json:"merge_split_candidates"`
	ArcCandidates          []AnalyzeV7ArcCandidate          `json:"arc_candidates"`
	ReflectionCandidates   []AnalyzeV7ReflectionCandidate   `json:"reflection_candidates"`
	QuestionCandidates     []AnalyzeV7QuestionCandidate     `json:"question_candidates"`
	Quality                AnalyzeV7Quality                 `json:"quality"`
}

type AnalyzeV7AffectProposal struct {
	ProposalID           string            `json:"proposal_id,omitempty"`
	Valence              *float64          `json:"valence,omitempty"`
	Arousal              *float64          `json:"arousal,omitempty"`
	Dominance            *float64          `json:"dominance,omitempty"`
	Intensity            *float64          `json:"intensity,omitempty"`
	Labels               []string          `json:"labels"`
	ToneHints            []string          `json:"tone_hints"`
	Confidence           *float64          `json:"confidence,omitempty"`
	Evidence             []EvidenceSnippet `json:"evidence"`
	RequiresConfirmation bool              `json:"requires_confirmation"`
	RawInput             string            `json:"raw_input,omitempty"`
}

type AnalyzeV7GraphDeltaProposal struct {
	ProposalID           string                         `json:"proposal_id,omitempty"`
	Operations           []AnalyzeV7GraphDeltaOperation `json:"operations"`
	Confidence           *float64                       `json:"confidence,omitempty"`
	RequiresConfirmation bool                           `json:"requires_confirmation"`
	Evidence             []EvidenceSnippet              `json:"evidence"`
}

type AnalyzeV7GraphDeltaOperation struct {
	Kind         string            `json:"kind"`
	TargetType   string            `json:"target_type"`
	TargetID     string            `json:"target_id"`
	RelatedID    string            `json:"related_id,omitempty"`
	StringValue  string            `json:"string_value,omitempty"`
	NumericValue *float64          `json:"numeric_value,omitempty"`
	Metadata     map[string]string `json:"metadata"`
}

type AnalyzeV7ProfileUpdateProposal struct {
	ProposalID           string            `json:"proposal_id,omitempty"`
	TargetEntityID       string            `json:"target_entity_id"`
	ProfileKind          string            `json:"profile_kind"`
	Field                string            `json:"field"`
	ProposedValue        string            `json:"proposed_value"`
	Confidence           *float64          `json:"confidence,omitempty"`
	Evidence             []EvidenceSnippet `json:"evidence"`
	RequiresConfirmation bool              `json:"requires_confirmation"`
}

type AnalyzeV7MergeSplitCandidate struct {
	CandidateID      string            `json:"candidate_id,omitempty"`
	Kind             string            `json:"kind"`
	SourceEntityIDs  []string          `json:"source_entity_ids"`
	TargetEntityID   string            `json:"target_entity_id,omitempty"`
	Confidence       *float64          `json:"confidence,omitempty"`
	PositiveEvidence []EvidenceSnippet `json:"positive_evidence"`
	NegativeEvidence []EvidenceSnippet `json:"negative_evidence"`
	Question         string            `json:"question,omitempty"`
}

type AnalyzeV7ArcCandidate struct {
	CandidateID     string   `json:"candidate_id,omitempty"`
	Title           string   `json:"title"`
	Summary         string   `json:"summary"`
	SourceRecordIDs []string `json:"source_record_ids"`
	Confidence      *float64 `json:"confidence,omitempty"`
}

type AnalyzeV7ReflectionCandidate struct {
	CandidateID       string   `json:"candidate_id,omitempty"`
	Title             string   `json:"title"`
	Body              string   `json:"body"`
	EvidenceSummary   string   `json:"evidence_summary"`
	Confidence        float64  `json:"confidence"`
	SourceRecordIDs   []string `json:"source_record_ids"`
	SourceArtifactIDs []string `json:"source_artifact_ids"`
	SourceEntityIDs   []string `json:"source_entity_ids"`
}

type AnalyzeV7QuestionCandidate struct {
	CandidateID       string   `json:"candidate_id,omitempty"`
	Kind              string   `json:"kind"`
	Prompt            string   `json:"prompt"`
	Reason            string   `json:"reason"`
	CandidateAnswers  []string `json:"candidate_answers"`
	Confidence        float64  `json:"confidence"`
	Sensitivity       string   `json:"sensitivity"`
	TargetType        string   `json:"target_type,omitempty"`
	TargetID          string   `json:"target_id,omitempty"`
	SourceRecordIDs   []string `json:"source_record_ids"`
	SourceArtifactIDs []string `json:"source_artifact_ids"`
}

type AnalyzeV7Quality struct {
	Confidence         float64  `json:"confidence"`
	UncertaintyReasons []string `json:"uncertainty_reasons"`
	NeedsUserCheck     []string `json:"needs_user_check"`
}

func (r AnalyzeV7Request) Validate() error {
	if r.SchemaVersion != 7 {
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

func (r AnalyzeV7Request) ToAnalyzeRequest() AnalyzeRequest {
	return AnalyzeRequest{
		SchemaVersion:      "analyze.v7",
		ClientVersion:      "mory.v7",
		ClientRequestID:    r.ClientRequestID,
		AnalysisReason:     "capture_ingest_context_v7",
		RecordShell:        r.RecordShell,
		Artifacts:          r.Artifacts,
		KnownEntities:      r.KnownEntities,
		MoodEvidence:       r.MoodEvidence,
		ContextPack:        &r.ContextPack,
		ClientCapabilities: &r.ClientCapabilities,
		DebugOptions:       r.DebugOptions,
	}
}

func BuildAnalyzeV7Response(req AnalyzeV7Request, analysis AnalyzeResponse) AnalyzeV7Response {
	analysis = NormalizeResponse(analysis)
	quality := buildAnalyzeV7Quality(req, analysis)
	return AnalyzeV7Response{
		Analysis:               analysis,
		AffectProposals:        buildAnalyzeV7AffectProposals(req, analysis, quality),
		GraphDeltaProposals:    []AnalyzeV7GraphDeltaProposal{},
		ProfileUpdateProposals: []AnalyzeV7ProfileUpdateProposal{},
		MergeSplitCandidates:   []AnalyzeV7MergeSplitCandidate{},
		ArcCandidates:          buildAnalyzeV7ArcCandidates(req, analysis),
		ReflectionCandidates:   buildAnalyzeV7ReflectionCandidates(req, analysis, quality),
		QuestionCandidates:     buildAnalyzeV7QuestionCandidates(req, analysis, quality),
		Quality:                quality,
	}
}

func buildAnalyzeV7Quality(req AnalyzeV7Request, analysis AnalyzeResponse) AnalyzeV7Quality {
	confidence := 0.5
	if analysis.SalienceScore != nil {
		confidence = clamp01(*analysis.SalienceScore)
	} else if analysis.Emotion.Confidence != nil {
		confidence = clamp01(*analysis.Emotion.Confidence)
	}

	reasons := []string{}
	needsUserCheck := []string{}
	relatedCount := len(req.ContextPack.RelatedMemories)
	if relatedCount == 0 {
		reasons = append(reasons, "thin_context")
	}
	if relatedCount < 2 {
		reasons = append(reasons, "insufficient_longitudinal_evidence")
	}
	for _, decision := range req.ContextPack.PrivacyDecisions {
		switch strings.TrimSpace(decision.Action) {
		case "drop", "redact", "localOnly", "blockCloud":
			reasons = append(reasons, "sensitive_content_redacted")
		}
	}
	if len(req.MoodEvidence) == 0 {
		reasons = append(reasons, "missing_structured_mood_evidence")
		needsUserCheck = append(needsUserCheck, "tone")
	}
	for _, mood := range req.MoodEvidence {
		if mood.Confidence == nil || *mood.Confidence < 0.6 || !mood.UserConfirmed {
			needsUserCheck = append(needsUserCheck, "tone")
			break
		}
	}
	return AnalyzeV7Quality{
		Confidence:         confidence,
		UncertaintyReasons: uniqueStrings(reasons),
		NeedsUserCheck:     uniqueStrings(needsUserCheck),
	}
}

func buildAnalyzeV7AffectProposals(req AnalyzeV7Request, analysis AnalyzeResponse, quality AnalyzeV7Quality) []AnalyzeV7AffectProposal {
	if strings.TrimSpace(analysis.Emotion.Label) == "" {
		return []AnalyzeV7AffectProposal{}
	}
	evidence := []EvidenceSnippet{}
	if strings.TrimSpace(req.RecordShell.RawText) != "" {
		evidence = append(evidence, EvidenceSnippet{
			RecordID:  req.RecordShell.ID,
			Snippet:   truncateForEvidence(req.RecordShell.RawText, 240),
			CreatedAt: req.RecordShell.CreatedAt,
		})
	}
	return []AnalyzeV7AffectProposal{
		{
			Valence:              valenceForEmotionLabel(analysis.Emotion.Label),
			Arousal:              arousalForEmotionLabel(analysis.Emotion.Label),
			Intensity:            analysis.Emotion.Intensity,
			Labels:               affectLabelsForEmotionLabel(analysis.Emotion.Label),
			ToneHints:            toneHintsForEmotionLabel(analysis.Emotion.Label, quality),
			Confidence:           analysis.Emotion.Confidence,
			Evidence:             evidence,
			RequiresConfirmation: len(quality.NeedsUserCheck) > 0,
			RawInput:             req.RecordShell.UserMood,
		},
	}
}

func buildAnalyzeV7ReflectionCandidates(req AnalyzeV7Request, analysis AnalyzeResponse, quality AnalyzeV7Quality) []AnalyzeV7ReflectionCandidate {
	hint := strings.TrimSpace(analysis.ReflectionHint)
	if hint == "" || len(req.ContextPack.RelatedMemories) == 0 {
		return []AnalyzeV7ReflectionCandidate{}
	}
	sourceIDs := []string{req.RecordShell.ID}
	evidence := []string{}
	for _, memory := range req.ContextPack.RelatedMemories {
		sourceIDs = append(sourceIDs, memory.RecordID)
		if strings.TrimSpace(memory.Snippet) != "" && len(evidence) < 3 {
			evidence = append(evidence, truncateForEvidence(memory.Snippet, 180))
		}
	}
	return []AnalyzeV7ReflectionCandidate{
		{
			Title:             "Pattern to revisit",
			Body:              hint,
			EvidenceSummary:   strings.Join(evidence, " | "),
			Confidence:        quality.Confidence,
			SourceRecordIDs:   uniqueStrings(sourceIDs),
			SourceArtifactIDs: artifactIDs(req.Artifacts),
			SourceEntityIDs:   knownEntityIDs(req.KnownEntities),
		},
	}
}

func buildAnalyzeV7QuestionCandidates(req AnalyzeV7Request, analysis AnalyzeResponse, quality AnalyzeV7Quality) []AnalyzeV7QuestionCandidate {
	if analysis.FollowUp == nil || strings.TrimSpace(analysis.FollowUp.Question) == "" {
		return []AnalyzeV7QuestionCandidate{}
	}
	return []AnalyzeV7QuestionCandidate{
		{
			Kind:              "dailyReflection",
			Prompt:            analysis.FollowUp.Question,
			Reason:            "Analyze v7 follow-up from current memory and context pack.",
			CandidateAnswers:  []string{},
			Confidence:        quality.Confidence,
			Sensitivity:       "normal",
			TargetType:        "record",
			TargetID:          req.RecordShell.ID,
			SourceRecordIDs:   []string{req.RecordShell.ID},
			SourceArtifactIDs: artifactIDs(req.Artifacts),
		},
	}
}

func buildAnalyzeV7ArcCandidates(req AnalyzeV7Request, analysis AnalyzeResponse) []AnalyzeV7ArcCandidate {
	if analysis.SalienceScore == nil || *analysis.SalienceScore < 0.74 || len(req.ContextPack.RelatedMemories) < 2 {
		return []AnalyzeV7ArcCandidate{}
	}
	sourceIDs := []string{req.RecordShell.ID}
	for _, memory := range req.ContextPack.RelatedMemories {
		sourceIDs = append(sourceIDs, memory.RecordID)
	}
	return []AnalyzeV7ArcCandidate{
		{
			Title:           firstNonEmptyString(analysis.Summary, "Emerging pattern"),
			Summary:         firstNonEmptyString(analysis.ReflectionHint, analysis.Insight),
			SourceRecordIDs: uniqueStrings(sourceIDs),
			Confidence:      analysis.SalienceScore,
		},
	}
}

func valenceForEmotionLabel(label string) *float64 {
	var value float64
	switch strings.ToLower(strings.TrimSpace(label)) {
	case "positive", "happy", "gratitude", "curious":
		value = 0.6
	case "tense", "stress", "sad", "angry", "anxious":
		value = -0.6
	default:
		value = 0
	}
	return &value
}

func arousalForEmotionLabel(label string) *float64 {
	var value float64
	switch strings.ToLower(strings.TrimSpace(label)) {
	case "tense", "stress", "angry", "anxious", "excited":
		value = 0.75
	case "positive", "happy", "gratitude", "curious":
		value = 0.45
	default:
		value = 0.3
	}
	return &value
}

func affectLabelsForEmotionLabel(label string) []string {
	switch strings.ToLower(strings.TrimSpace(label)) {
	case "positive", "happy", "gratitude":
		return []string{"grateful"}
	case "curious":
		return []string{"curious"}
	case "tense", "stress":
		return []string{"stressed"}
	case "sad":
		return []string{"sad"}
	case "anxious":
		return []string{"anxious"}
	default:
		return []string{"uncertain"}
	}
}

func toneHintsForEmotionLabel(label string, quality AnalyzeV7Quality) []string {
	for _, check := range quality.NeedsUserCheck {
		if check == "tone" {
			return []string{"uncertain"}
		}
	}
	switch strings.ToLower(strings.TrimSpace(label)) {
	case "tense", "stress":
		return []string{"venting"}
	default:
		return []string{}
	}
}

func artifactIDs(artifacts []AnalyzeArtifact) []string {
	result := []string{}
	for _, artifact := range artifacts {
		if strings.TrimSpace(artifact.ID) != "" {
			result = append(result, artifact.ID)
		}
	}
	return result
}

func knownEntityIDs(entities []KnownEntityReference) []string {
	result := []string{}
	for _, entity := range entities {
		if strings.TrimSpace(entity.ID) != "" {
			result = append(result, entity.ID)
		}
	}
	return result
}

func truncateForEvidence(value string, limit int) string {
	trimmed := strings.TrimSpace(value)
	if limit <= 0 || len(trimmed) <= limit {
		return trimmed
	}
	return strings.TrimSpace(trimmed[:limit])
}

func clamp01(value float64) float64 {
	if value < 0 {
		return 0
	}
	if value > 1 {
		return 1
	}
	return value
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}
