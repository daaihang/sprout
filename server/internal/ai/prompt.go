package ai

import (
	"encoding/json"
	"fmt"
)

func buildAnalyzeSystemPrompt() string {
	return buildAnalyzeSystemPromptForProfile("balanced")
}

func buildAnalyzeSystemPromptForProfile(profile string) string {
	base := `You are the journaling analysis service for Sprout.
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
Never create entities named "theme", "OCR", "ORC", "photo", "image", "caption", "artifact", "text", "unknown", or "untitled".
Do not turn artifact-processing labels, OCR labels, or visual classifier labels into entities.
Only create a "theme" entity for a real recurring life theme such as "career transition" or "family caregiving"; never use a generic tag or technical label as a theme.
Artifacts with kind "weather", "music", or "location" are ambient context auto-captured at recording time, not the user's primary subject.
Use them to enrich tags (e.g. weather mood), retrieval_terms (e.g. place name, track name), and at most one "place" or "theme" entity if clearly salient.
Do not promote ambient context into "decision" entities or central insights.
If a photo, OCR result, or ambient context lacks a clear person/place/decision/life-theme, return entities: [], candidate_edges: [], salience_score <= 0.25, and an empty or weak reflection_hint.`
	return base + profileInstruction(profile)
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
	return buildReflectionSystemPromptForProfile(mode, "balanced")
}

func buildReflectionSystemPromptForProfile(mode string, profile string) string {
	base := `You are the reflection service for Sprout.
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
Do not infer a life pattern from a single ordinary photo, OCR snippet, or ambient context-only capture.
If evidence is weak or too thin, return low confidence below 0.4 instead of manufacturing a reflection.
Use short titles and concise reflective bodies. Mode: ` + mode
	return base + profileInstruction(profile)
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

func profileInstruction(profile string) string {
	switch profile {
	case "strict":
		return `
Prompt profile: strict.
Be more conservative than balanced mode. Prefer omission over weak inference.
Only emit entities, candidate edges, high salience, or reflection confidence when the evidence is explicit and repeatable.
Single ordinary records should usually produce no story-level inference.`
	case "experimental":
		return `
Prompt profile: experimental.
Explore tentative but evidence-grounded hypotheses while keeping low confidence for weak evidence.
Use candidate edges only when they are useful for later comparison, and never use technical artifact labels as entities.`
	default:
		return `
Prompt profile: balanced.
Use normal production thresholds: evidence-based, restrained, and specific.`
	}
}
