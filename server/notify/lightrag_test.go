package notify

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestLightRAGSyncClientSync_SendsNativeTextRequest(t *testing.T) {
	var gotAPIKey string
	var gotContentType string
	var gotReq map[string]any

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAPIKey = r.Header.Get("X-API-Key")
		gotContentType = r.Header.Get("Content-Type")
		if err := json.NewDecoder(r.Body).Decode(&gotReq); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := NewLightRAGSyncClient(srv.URL, "sync-token", 2*time.Second, 5, 30*time.Second)
	err := client.Sync(context.Background(), LightRAGSyncRequest{
		SourceType: "course",
		BizID:      1,
		SourceID:   "course:1",
		Action:     "upsert",
		Status:     "published",
		Source: map[string]any{
			"title":      "Go 并发编程",
			"summary":    "讲解 goroutine",
			"content":    "channel 与同步原语",
			"source_url": "/api/v1/courses/1",
		},
	})
	if err != nil {
		t.Fatalf("sync failed: %v", err)
	}

	if gotAPIKey != "sync-token" {
		t.Fatalf("unexpected api key header: %s", gotAPIKey)
	}
	if gotContentType != "application/json" {
		t.Fatalf("unexpected content type: %s", gotContentType)
	}
	if gotReq["file_source"] != "course:1" {
		t.Fatalf("unexpected file_source: %#v", gotReq)
	}
	text, _ := gotReq["text"].(string)
	if text == "" || !containsAll(text, []string{"Go 并发编程", "讲解 goroutine", "/api/v1/courses/1"}) {
		t.Fatalf("unexpected text payload: %s", text)
	}
}

func TestLightRAGSyncClientSync_SkipsDeleteWithoutDocMapping(t *testing.T) {
	client := NewLightRAGSyncClient("http://127.0.0.1:9621/documents/text", "", time.Second, 5, 30*time.Second)
	err := client.Sync(context.Background(), LightRAGSyncRequest{
		SourceType: "course",
		BizID:      1,
		SourceID:   "course:1",
		Action:     "delete",
	})
	if !errors.Is(err, ErrLightRAGDeleteUnsupported) {
		t.Fatalf("expected ErrLightRAGDeleteUnsupported, got %v", err)
	}
}

func TestLightRAGSyncClientSync_RejectsEmptyEndpoint(t *testing.T) {
	client := NewLightRAGSyncClient("", "", time.Second, 5, 30*time.Second)
	err := client.Sync(context.Background(), LightRAGSyncRequest{
		SourceType: "course",
		BizID:      1,
		Action:     "upsert",
	})
	if err == nil {
		t.Fatal("expected error for empty endpoint")
	}
}

func containsAll(text string, subs []string) bool {
	for _, sub := range subs {
		if sub != "" && !strings.Contains(text, sub) {
			return false
		}
	}
	return true
}
