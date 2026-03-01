package utils

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestRetry_SucceedsAfterRetries(t *testing.T) {
	ctx := context.Background()
	calls := 0
	err := Retry(ctx, 3, 5*time.Millisecond, 10*time.Millisecond, func(err error) bool {
		return true
	}, func() error {
		calls++
		if calls < 3 {
			return errors.New("temporary")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("expected nil error, got %v", err)
	}
	if calls != 3 {
		t.Fatalf("expected 3 calls, got %d", calls)
	}
}

func TestRetry_StopsWhenShouldRetryFalse(t *testing.T) {
	ctx := context.Background()
	calls := 0
	targetErr := errors.New("do not retry")
	err := Retry(ctx, 5, 5*time.Millisecond, 10*time.Millisecond, func(err error) bool {
		return false
	}, func() error {
		calls++
		return targetErr
	})
	if !errors.Is(err, targetErr) {
		t.Fatalf("expected target error, got %v", err)
	}
	if calls != 1 {
		t.Fatalf("expected 1 call, got %d", calls)
	}
}

func TestRetry_ContextCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	calls := 0
	err := Retry(ctx, 3, 50*time.Millisecond, 100*time.Millisecond, func(err error) bool {
		return true
	}, func() error {
		calls++
		return errors.New("temporary")
	})

	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context canceled, got %v", err)
	}
	if calls != 1 {
		t.Fatalf("expected 1 call before cancel exit, got %d", calls)
	}
}
