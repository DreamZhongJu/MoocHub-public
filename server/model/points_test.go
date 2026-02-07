package model

import (
	"MOOCHUB-server/cache"
	"testing"

	"github.com/alicebob/miniredis/v2"
)

func TestAllowAwardIdempotent(t *testing.T) {
	mr, err := miniredis.Run()
	if err != nil {
		t.Fatalf("start miniredis: %v", err)
	}
	defer mr.Close()

	t.Setenv("REDIS_ADDR", mr.Addr())
	t.Setenv("REDIS_DB", "0")

	if err := cache.InitRedis(); err != nil {
		t.Fatalf("init redis: %v", err)
	}
	defer func() {
		_ = cache.CloseRedis()
	}()

	userID := uint(1)
	eventType := "login"

	if ok := allowAward(userID, eventType, nil); !ok {
		t.Fatalf("first award should pass")
	}
	if ok := allowAward(userID, eventType, nil); ok {
		t.Fatalf("second award should be blocked")
	}

	bizID := uint64(100)
	if ok := allowAward(userID, "comment", &bizID); !ok {
		t.Fatalf("first award with biz_id should pass")
	}
	if ok := allowAward(userID, "comment", &bizID); ok {
		t.Fatalf("second award with same biz_id should be blocked")
	}
}
