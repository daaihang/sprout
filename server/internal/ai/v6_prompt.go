package ai

import (
	"encoding/json"
	"fmt"
)

func buildV6SystemPrompt(operation string) string {
	return `You are the cloud intelligence service for Mory, a private memory app.
Return exactly one JSON object and no markdown.
Preserve user-authored meaning. Do not invent facts.
Treat all outputs as candidates that the iOS client will review, store, or discard locally.
Prefer concise, evidence-based, non-clinical language.
Do not include raw private content beyond the requested structured fields.
If evidence is insufficient, return a low-confidence candidate instead of inventing missing facts.
Use the exact field names and JSON shape requested below.
Operation: ` + operation + `
Expected JSON shape:
` + v6OperationSchema(operation)
}

func buildV6UserPrompt(operation string, req any, user UserContext) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"operation": operation,
		"request":   req,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal v6 prompt payload: %w", err)
	}
	return string(body), nil
}

func v6OperationSchema(operation string) string {
	switch operation {
	case "refine_transcript":
		return `{
  "schema_version": 1,
  "refined_transcript": "cleaned transcript, preserving meaning while removing obvious filler/repetition",
  "suggested_title": "optional short title",
  "edits": [{"kind": "punctuation|dedupe|clarity|title", "summary": "short edit summary"}]
}`
	case "suggest_questions":
		return `{
  "schema_version": 1,
  "questions": [{
    "kind": "alias|relationship|memory_revisit|dailyReflection|clarification|life_admin",
    "prompt": "one concrete question grounded in evidence",
    "reason": "why this question is useful",
    "candidate_answers": ["optional quick answer"],
    "confidence": 0.0,
    "sensitivity": "normal|sensitive"
  }]
}`
	case "suggest_chapters":
		return `{
  "schema_version": 1,
  "chapter_candidates": [{
    "title": "stage/chapter title",
    "summary": "evidence-based explanation",
    "evidence_record_ids": ["record id"],
    "confidence": 0.0,
    "requires_confirmation": true
  }]
}`
	case "analyze_photo_semantics":
		return `{
  "schema_version": 1,
  "semantic_summary": "what this photo likely represents, using local labels/OCR/metadata only",
  "suggested_title": "optional title",
  "tags": ["tag"],
  "objects": ["object"],
  "text_highlights": ["ocr highlight"],
  "safety": "normal|sensitive|unknown",
  "confidence": 0.0
}`
	case "suggest_notification_intent":
		return `{
  "schema_version": 1,
  "intent": {
    "kind": "backgroundDone|dailyQuestion|repeatedTheme|stageForming|revisit",
    "privacy_level": "generic|contextual|sensitive",
    "title": "short notification title",
    "body": "short notification body",
    "deep_link": "optional mory:// deep link if supplied or inferable",
    "scheduled_at": "optional RFC3339 time"
  }
}`
	default:
		return `{"schema_version": 1}`
	}
}
