package ai

import "strings"

func truncateBody(body []byte, limit int) string {
	if len(body) <= limit {
		return string(body)
	}
	return string(body[:limit]) + "…"
}

func flattenOpenAIContent(content any) string {
	switch value := content.(type) {
	case string:
		return value
	case []any:
		var builder strings.Builder
		for _, item := range value {
			block, ok := item.(map[string]any)
			if !ok {
				continue
			}
			textValue, _ := block["text"].(string)
			if textValue == "" {
				if nested, ok := block["text"].(map[string]any); ok {
					textValue, _ = nested["value"].(string)
				}
			}
			if textValue == "" {
				continue
			}
			if builder.Len() > 0 {
				builder.WriteByte('\n')
			}
			builder.WriteString(textValue)
		}
		return builder.String()
	default:
		return ""
	}
}
