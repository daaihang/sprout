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
  "emotion": {"label":"string","intensity":1,"confidence":0.0},
  "persons": [{"name":"string","action":"link|create","person_id":"string","confidence":0.0}],
  "new_media": [{"type":"string","title":"string","creator":"string","search_hint":"string"}],
  "insight": "string",
  "follow_up": {"question":"string","expires_at":"RFC3339 string"} | null
}
Use empty arrays instead of null for collections.
Only include person_id when linking an existing person.`
}

func buildAnalyzeUserPrompt(req AnalyzeRequest, user UserContext) (string, error) {
	payload := map[string]any{
		"user": map[string]string{
			"user_id": user.UserID,
			"tier":    user.Tier,
		},
		"record":  req.Record,
		"persons": req.Persons,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal analyze prompt payload: %w", err)
	}
	return string(body), nil
}
