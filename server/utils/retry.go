package utils

import (
	"context"
	"time"
)

func Retry(ctx context.Context, attempts int, baseDelay time.Duration, maxDelay time.Duration, shouldRetry func(error) bool, fn func() error) error {
	if attempts <= 1 {
		return fn()
	}
	if baseDelay <= 0 {
		baseDelay = 120 * time.Millisecond
	}
	if maxDelay < baseDelay {
		maxDelay = baseDelay
	}

	var lastErr error
	delay := baseDelay
	for i := 0; i < attempts; i++ {
		if err := fn(); err != nil {
			lastErr = err
			if i == attempts-1 || (shouldRetry != nil && !shouldRetry(err)) {
				return err
			}
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(delay):
			}
			delay *= 2
			if delay > maxDelay {
				delay = maxDelay
			}
			continue
		}
		return nil
	}
	return lastErr
}
