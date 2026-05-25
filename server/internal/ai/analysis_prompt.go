package ai

import (
	"encoding/json"
	"fmt"
)

func buildAnalysisSystemPrompt() string {
	return `You are the Mory long-term memory analysis service.
Return exactly one JSON object and no markdown.
The JSON must match this top-level shape:
{
  "analysis": {
    "tags": ["string"],
    "emotion": {"label":"string","intensity":1.0,"confidence":0.0},
    "entities": [{"kind":"person|place|theme|decision","name":"string","canonical_name":"string","confidence":0.0,"source_artifact_ids":["string"]}],
    "candidate_edges": [{"from_name":"string","from_kind":"string","to_name":"string","to_kind":"string","relation":"string","confidence":0.0}],
    "insight": "string",
    "summary": "string",
    "salience_score": 0.0,
    "retrieval_terms": ["string"],
    "reflection_hint": "string",
    "follow_up": {"question":"string","expires_at":"RFC3339 string"} | null
  },
  "affect_proposals": [{"valence":0.0,"arousal":0.0,"dominance":0.0,"intensity":0.0,"labels":["string"],"tone_hints":["string"],"confidence":0.0,"evidence":[{"record_id":"string","artifact_id":"string","snippet":"string","created_at":"string"}],"requires_confirmation":true,"raw_input":"string"}],
  "graph_delta_proposals": [],
  "profile_update_proposals": [],
  "merge_split_candidates": [],
  "arc_candidates": [{"title":"string","summary":"string","source_record_ids":["string"],"confidence":0.0}],
  "reflection_candidates": [{"title":"string","body":"string","evidence_summary":"string","confidence":0.0,"source_record_ids":["string"],"source_artifact_ids":["string"],"source_entity_ids":["string"]}],
  "question_candidates": [{"kind":"dailyReflection|entityRelationship|entityAlias|entityMerge|themeConfirmation|decisionStatus|placeMeaning","prompt":"string","reason":"string","candidate_answers":["string"],"confidence":0.0,"sensitivity":"low|normal|personal|sensitive","target_type":"record|entity|place|theme|decision","target_id":"string","source_record_ids":["string"],"source_artifact_ids":["string"]}],
  "quality": {"confidence":0.0,"uncertainty_reasons":["string"],"needs_user_check":["string"]}
}
Use empty arrays instead of null for all proposal collections.
Use the context_pack as bounded evidence; never infer from hidden history.
Treat weather, music, location, photos, OCR, links, receipts, screenshots, menus, invoices, and calendar captures as ambient carriers unless the user's text or context_pack makes them meaningful.
Metadata-only links, dramatic article titles, screenshots, receipts, menus, invoices, and calendar OCR are carriers, not automatic entities or storylines.
Multiple ambient artifacts near the same time do not create a storyline by themselves.
Preserve the user's language. Chinese or mixed Chinese/English notes can be meaningful. Avoid over-generalizing from one thin record.
Never create entities named "theme", "OCR", "ORC", "photo", "image", "caption", "artifact", "text", "unknown", "untitled", "quality tuning", "quality tuning lab", "debug", "fixture", "scenario", "receipt", "screenshot", "bookmark", or "link".
Do not turn artifact-processing labels, OCR labels, or visual classifier labels into entities.
For weak metadata-only captures, return entities: [], candidate_edges: [], salience_score <= 0.25.
AI output is proposal-first: never claim merges, relationships, or self-profile changes as facts unless evidence is explicit.
For same-name people, do not merge identities without explicit user confirmation or strong evidence.
If tone is ambiguous, add "tone" to quality.needs_user_check and set affect proposal requires_confirmation to true.
Only create arc/reflection candidates when related_memories, related_arcs, or prior_reflections provide real longitudinal evidence.
Emotion alone is not enough for a reflection. Stronger evidence includes first-person speech transcript that names a recurring constraint, a concrete commitment such as protect mornings for writing before meetings, or repeated concrete decisions.
Sensitive stress, health, money, or despair language should be handled conservatively.
Do not include sensitive details that privacy_decisions marked drop, redact, localOnly, or blockCloud.`
}

func buildAnalysisUserPrompt(req AnalysisRequest, user UserContext) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"client_request_id":   req.ClientRequestID,
		"record_shell":        req.RecordShell,
		"artifacts":           req.Artifacts,
		"known_entities":      req.KnownEntities,
		"mood_evidence":       req.MoodEvidence,
		"context_pack":        req.ContextPack,
		"client_capabilities": req.ClientCapabilities,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal analysis prompt payload: %w", err)
	}
	return string(body), nil
}

func parseAnalysisResponse(raw string) (AnalysisResponse, error) {
	candidate := extractJSONObject(raw)
	if candidate == "" {
		return AnalysisResponse{}, fmt.Errorf("no JSON object found in analysis model response: %s", summarizeRaw(raw))
	}
	var resp AnalysisResponse
	if err := json.Unmarshal([]byte(candidate), &resp); err != nil {
		return AnalysisResponse{}, fmt.Errorf("decode analysis response: %w; raw=%s", err, summarizeRaw(raw))
	}
	return NormalizeAnalysisResponse(resp), nil
}

func NormalizeAnalysisResponse(resp AnalysisResponse) AnalysisResponse {
	resp.Analysis = NormalizeAnalysisRecordResponse(resp.Analysis)
	if resp.AffectProposals == nil {
		resp.AffectProposals = []AnalysisAffectProposal{}
	}
	if resp.GraphDeltaProposals == nil {
		resp.GraphDeltaProposals = []AnalysisGraphDeltaProposal{}
	}
	if resp.ProfileUpdateProposals == nil {
		resp.ProfileUpdateProposals = []AnalysisProfileUpdateProposal{}
	}
	if resp.MergeSplitCandidates == nil {
		resp.MergeSplitCandidates = []AnalysisMergeSplitCandidate{}
	}
	if resp.ArcCandidates == nil {
		resp.ArcCandidates = []AnalysisArcCandidate{}
	}
	if resp.ReflectionCandidates == nil {
		resp.ReflectionCandidates = []AnalysisReflectionCandidate{}
	}
	if resp.QuestionCandidates == nil {
		resp.QuestionCandidates = []AnalysisQuestionCandidate{}
	}
	if resp.Quality.UncertaintyReasons == nil {
		resp.Quality.UncertaintyReasons = []string{}
	}
	if resp.Quality.NeedsUserCheck == nil {
		resp.Quality.NeedsUserCheck = []string{}
	}
	return resp
}
