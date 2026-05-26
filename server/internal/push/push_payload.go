package push

import (
	"encoding/json"
	"strings"
	"time"
)

type DeliveryTarget struct {
	Type            string   `json:"type"`
	ID              string   `json:"id"`
	ParentRecordID  string   `json:"parent_record_id,omitempty"`
	ArtifactKind    string   `json:"artifact_kind,omitempty"`
	EntityKind      string   `json:"entity_kind,omitempty"`
	Label           string   `json:"label,omitempty"`
	SourceRecordIDs []string `json:"source_record_ids,omitempty"`
}

type DeliveryPayload struct {
	SchemaVersion   int            `json:"schema_version"`
	IntentID        string         `json:"intent_id"`
	Kind            string         `json:"kind"`
	Title           string         `json:"title,omitempty"`
	Body            string         `json:"body,omitempty"`
	PrivacyLevel    string         `json:"privacy_level,omitempty"`
	DeepLink        string         `json:"deep_link,omitempty"`
	DeliveryChannel string         `json:"delivery_channel"`
	Target          DeliveryTarget `json:"target"`
	ScheduledAt     string         `json:"scheduled_at,omitempty"`
}

func NormalizeDeliveryPayload(intent DeliveryIntent) DeliveryPayload {
	if intent.Payload.SchemaVersion > 0 {
		payload := intent.Payload
		if strings.TrimSpace(payload.IntentID) == "" {
			payload.IntentID = intent.IntentID
		}
		if strings.TrimSpace(payload.Kind) == "" {
			payload.Kind = intent.Kind
		}
		if strings.TrimSpace(payload.Title) == "" {
			payload.Title = intent.Title
		}
		if strings.TrimSpace(payload.Body) == "" {
			payload.Body = intent.Body
		}
		if strings.TrimSpace(payload.PrivacyLevel) == "" {
			payload.PrivacyLevel = firstNonEmpty(intent.PrivacyLevel, "contextual")
		}
		if strings.TrimSpace(payload.DeepLink) == "" {
			payload.DeepLink = intent.DeepLink
		}
		if strings.TrimSpace(payload.DeliveryChannel) == "" {
			payload.DeliveryChannel = "remote"
		}
		if strings.TrimSpace(payload.Target.Type) == "" {
			payload.Target.Type = firstNonEmpty(intent.Target.Type, intent.TargetType)
		}
		if strings.TrimSpace(payload.Target.ID) == "" {
			payload.Target.ID = firstNonEmpty(intent.Target.ID, intent.TargetID)
		}
		if strings.TrimSpace(payload.ScheduledAt) == "" && !intent.ScheduledAt.IsZero() {
			payload.ScheduledAt = intent.ScheduledAt.UTC().Format(time.RFC3339)
		}
		return payload
	}

	target := intent.Target
	if strings.TrimSpace(target.Type) == "" {
		target.Type = intent.TargetType
	}
	if strings.TrimSpace(target.ID) == "" {
		target.ID = intent.TargetID
	}

	payload := DeliveryPayload{
		SchemaVersion:   1,
		IntentID:        strings.TrimSpace(intent.IntentID),
		Kind:            strings.TrimSpace(intent.Kind),
		Title:           strings.TrimSpace(intent.Title),
		Body:            strings.TrimSpace(intent.Body),
		PrivacyLevel:    firstNonEmpty(intent.PrivacyLevel, "contextual"),
		DeepLink:        strings.TrimSpace(intent.DeepLink),
		DeliveryChannel: "remote",
		Target: DeliveryTarget{
			Type:            strings.TrimSpace(target.Type),
			ID:              strings.TrimSpace(target.ID),
			ParentRecordID:  strings.TrimSpace(target.ParentRecordID),
			ArtifactKind:    strings.TrimSpace(target.ArtifactKind),
			EntityKind:      strings.TrimSpace(target.EntityKind),
			Label:           strings.TrimSpace(target.Label),
			SourceRecordIDs: cleanedStrings(target.SourceRecordIDs),
		},
	}
	if !intent.ScheduledAt.IsZero() {
		payload.ScheduledAt = intent.ScheduledAt.UTC().Format(time.RFC3339)
	}
	return payload
}

func payloadJSONString(payload DeliveryPayload) string {
	data, err := json.Marshal(payload)
	if err != nil {
		return ""
	}
	return string(data)
}

func payloadFromJSONString(raw string) DeliveryPayload {
	var payload DeliveryPayload
	if strings.TrimSpace(raw) == "" {
		return payload
	}
	_ = json.Unmarshal([]byte(raw), &payload)
	return payload
}

func SupportedTargetType(value string) bool {
	switch strings.TrimSpace(value) {
	case "record", "artifact", "question", "entity", "place", "theme", "decision", "chapter", "reflection":
		return true
	default:
		return false
	}
}

func cleanedStrings(values []string) []string {
	cleaned := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	return cleaned
}
