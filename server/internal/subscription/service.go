package subscription

import (
	"context"
	"fmt"
)

type Service struct {
	mode        string
	defaultTier string
}

type Status struct {
	UserID string `json:"user_id"`
	Tier   string `json:"tier"`
	Source string `json:"source"`
}

func NewService(mode, defaultTier string) *Service {
	return &Service{mode: mode, defaultTier: defaultTier}
}

func (s *Service) Verify(_ context.Context, userID string) (Status, error) {
	if userID == "" {
		return Status{}, fmt.Errorf("userID is required")
	}
	return Status{
		UserID: userID,
		Tier:   s.defaultTier,
		Source: s.mode,
	}, nil
}
