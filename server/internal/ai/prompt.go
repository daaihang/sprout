package ai

import (
	"encoding/json"
	"fmt"
)

func buildAnalyzeSystemPrompt() string {
	return `You are the journaling analysis service for Sprout.
Return exactly one JSON object and no markdown.
The JSON must match this shape:
{
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
}
Use empty arrays instead of null for collections.
Prefer structured entities over prose guesses.
Only use the allowed entity kinds.
Entity "name" and "canonical_name" must be short labels, usually 1 to 4 words.
Never copy an entire sentence or artifact summary into an entity name.
For "decision", extract a concise decision label such as "leave current job" instead of repeating the full note.
If you are unsure, omit the entity instead of inventing or over-expanding it.
Artifacts with kind "weather", "music", or "location" are ambient context auto-captured at recording time, not the user's primary subject.
Use them to enrich tags (e.g. weather mood), retrieval_terms (e.g. place name, track name), and at most one "place" or "theme" entity if clearly salient.
Do not promote ambient context into "decision" entities or central insights.`
}

func buildAnalyzeUserPrompt(req AnalyzeRequest, user UserContext) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"schema_version": req.SchemaVersion,
		"client_version": req.ClientVersion,
		"analysis_reason": req.AnalysisReason,
		"record_shell": req.RecordShell,
		"artifacts": req.Artifacts,
		"known_entities": req.KnownEntities,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal analyze prompt payload: %w", err)
	}
	return string(body), nil
}

func buildReflectionSystemPrompt(mode string) string {
	return `You are the reflection service for Sprout.
Return exactly one JSON object and no markdown.
The JSON must match this shape:
{
  "title": "string",
  "body": "string",
  "evidence_summary": "string",
  "confidence": 0.0,
  "source_record_ids": ["string"]
}
Keep the tone evidence-based, restrained, and specific.
Do not invent facts beyond the provided record shell, artifacts, linked arc context, and prompt.
Use short titles and concise reflective bodies. Mode: ` + mode
}

func buildReflectionUserPrompt(req ReflectionRequest, user UserContext, mode string) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"mode":           mode,
		"record_shell":   req.RecordShell,
		"artifacts":      req.Artifacts,
		"linked_arc_id":  req.LinkedArcID,
		"known_entities": req.KnownEntities,
		"prompt":         req.Prompt,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal reflection prompt payload: %w", err)
	}
	return string(body), nil
}
