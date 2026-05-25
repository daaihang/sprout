package ai

import "strings"

func containsAny(value string, terms ...string) bool {
	for _, term := range terms {
		if strings.Contains(value, strings.ToLower(term)) {
			return true
		}
	}
	return false
}

func firstMeaningfulTitle(content, fallback string) string {
	fields := strings.Fields(content)
	if len(fields) == 0 {
		return fallback
	}
	if len(fields) > 5 {
		fields = fields[:5]
	}
	title := strings.Join(fields, " ")
	if strings.TrimSpace(title) == "" {
		return fallback
	}
	return title
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	ordered := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		key := strings.ToLower(value)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		ordered = append(ordered, value)
	}
	return ordered
}

func extractArtifactSummaries(artifacts []AnalysisArtifact) []string {
	values := make([]string, 0, len(artifacts))
	for _, artifact := range artifacts {
		candidate := strings.TrimSpace(strings.Join([]string{
			artifact.Kind,
			artifact.Title,
			artifact.Summary,
			artifact.TextContent,
		}, " "))
		if candidate != "" {
			values = append(values, candidate)
		}
	}
	return values
}

func nonEmptyStrings(values []string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
