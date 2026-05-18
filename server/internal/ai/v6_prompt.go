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
Operation: ` + operation
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
