package notify

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLightRAGSyncClientSync_SendsRequest(t *testing.T) {
	var gotAuth string
	var gotContentType string
	var gotReq LightRAGSyncRequest

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
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
			"title": "Go 并发编程",
		},
	})
	if err != nil {
		t.Fatalf("sync failed: %v", err)
	}

	if gotAuth != "Bearer sync-token" {
		t.Fatalf("unexpected auth header: %s", gotAuth)
	}
	if gotContentType != "application/json" {
		t.Fatalf("unexpected content type: %s", gotContentType)
	}
	if gotReq.SourceType != "course" || gotReq.BizID != 1 || gotReq.Action != "upsert" {
		t.Fatalf("unexpected request payload: %#v", gotReq)
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
