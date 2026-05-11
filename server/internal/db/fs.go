package db

import (
	"fmt"
	"os"
)

func ensureDir(path string) error {
	if err := os.MkdirAll(path, 0o755); err != nil {
		return fmt.Errorf("create sqlite dir: %w", err)
	}
	return nil
}
