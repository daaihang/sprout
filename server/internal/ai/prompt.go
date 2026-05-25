package ai

import (
	"encoding/json"
	"fmt"
)

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
