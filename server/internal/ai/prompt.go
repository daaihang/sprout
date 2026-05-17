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
Never create entities named "theme", "OCR", "ORC", "photo", "image", "caption", "artifact", "text", "unknown", "untitled", "quality tuning", "quality tuning lab", "debug", "fixture", "scenario", "receipt", "screenshot", "bookmark", or "link".
Do not turn artifact-processing labels, OCR labels, or visual classifier labels into entities.
Ignore debug provenance strings such as "quality tuning lab: <scenario>"; they exist only for test traceability and must never become tags, themes, entities, candidate edges, summaries, salience evidence, reflection hints, or storyline anchors.
Only create a "theme" entity for a real recurring life theme such as "career transition" or "family caregiving"; never use a generic tag or technical label as a theme.
Artifacts with kind "weather", "music", or "location" are ambient context auto-captured at recording time, not the user's primary subject.
Use them to enrich tags (e.g. weather mood), retrieval_terms (e.g. place name, track name), and at most one "place" or "theme" entity if clearly salient.
Do not promote ambient context into "decision" entities or central insights.
If a photo, OCR result, or ambient context lacks a clear person/place/decision/life-theme, return entities: [], candidate_edges: [], salience_score <= 0.25, and an empty or weak reflection_hint.`
	quality := `
Quality calibration:
- Length matters: terse notes and single-sentence reactions should usually have low salience unless they name a concrete person, place, decision, commitment, or recurring pattern.
- Emotion alone is not enough for a reflection. Strong emotion with thin evidence should preserve the emotion label but avoid story-level inference.
- Link saves and article bookmarks are weak signals unless the user explains why the link matters to their life or a decision.
- Metadata-only links, dramatic article titles, screenshots, receipts, menus, invoices, and calendar OCR are carriers, not life evidence; do not create entities, arcs, or reflection hints from them without user-authored meaning.
- Speech transcripts can be reflective, but only extract themes that are explicitly stated or repeated.
- A first-person speech transcript that names a recurring constraint, protected time, creative work, or boundary can use salience_score >= 0.75 and a concrete reflection_hint when the transcript has enough evidence text.
- For voice notes like "I keep returning to the same question about how to protect mornings for writing before meetings", return a concrete reflection_hint and treat it as an explicit recurring constraint rather than a thin ordinary note.
- Preserve the user's language. Chinese or mixed Chinese/English notes can be meaningful; summarize faithfully and extract concise bilingual labels only from explicit user-authored content.
- For same-name people, do not merge identities unless context, aliases, or known_entities make it clear they are the same person.
- Sensitive stress, health, money, or despair language should be handled conservatively: preserve emotion and concrete facts, avoid diagnosis, avoid life-pattern inference from one short note, and keep salience low unless there is explicit repeated evidence.
- Multiple ambient artifacts near the same time do not create a storyline by themselves.`
	return base + quality + profileInstruction(profile)
}

func buildAnalyzeUserPrompt(req AnalyzeRequest, user UserContext) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"schema_version":  req.SchemaVersion,
		"client_version":  req.ClientVersion,
		"analysis_reason": req.AnalysisReason,
		"record_shell":    req.RecordShell,
		"artifacts":       req.Artifacts,
		"known_entities":  req.KnownEntities,
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
	quality := `
Quality calibration:
- Do not turn one short emotional sentence into a life pattern.
- Treat repeated concrete decisions, named people, commitments, or recurring constraints as stronger evidence than general mood.
- Treat first-person voice transcripts about a recurring constraint or protected creative time as eligible for a specific reflection when the evidence is explicit.
- For sensitive stress, health, money, or despair language, stay factual and do not diagnose or generalize beyond the evidence.
- For bookmarks, photos, OCR, and ambient context, require explicit user-written meaning before suggesting a reflection.`
	return base + quality + profileInstruction(profile)
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
Single ordinary records should usually produce no story-level inference.
First-person voice transcripts that explicitly name a recurring constraint and protected creative time may produce a concrete reflection_hint even in strict mode.
For single photo, OCR, receipt, debug, or quality-tuning captures, use entities: [], candidate_edges: [], salience_score <= 0.25, and reflection_hint: "" unless the user-written content explicitly names a real person, place, decision, or recurring life theme.`
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
