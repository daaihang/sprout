package ai

import "context"

func (p *MockProvider) AnalyzeV7(ctx context.Context, req AnalyzeV7Request, user UserContext) (AnalyzeV7Result, error) {
	if err := req.Validate(); err != nil {
		return AnalyzeV7Result{}, err
	}
	legacy, err := p.Analyze(ctx, req.ToAnalyzeRequest(), user)
	if err != nil {
		return AnalyzeV7Result{}, err
	}
	response := BuildAnalyzeV7Response(req, legacy.Response)
	return AnalyzeV7Result{
		Response: response,
		Provider: p.Name(),
		Model:    "mock-analyzer-v7",
		Usage: Usage{
			InputTokens:  legacy.Usage.InputTokens + len(req.ContextPack.RelatedMemories)*16,
			OutputTokens: legacy.Usage.OutputTokens + len(response.AffectProposals)*16 + len(response.ReflectionCandidates)*24,
		},
	}, nil
}
