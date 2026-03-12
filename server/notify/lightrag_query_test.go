package notify

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestLightRAGQueryClientQuery_AdaptsNativeResponses(t *testing.T) {
	var gotAPIKey string
	var gotPaths []string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAPIKey = r.Header.Get("X-API-Key")
		gotPaths = append(gotPaths, r.URL.Path)
		switch r.URL.Path {
		case "/query":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"response": "IOC 是控制反转。",
				"references": []map[string]any{
					{
						"reference_id": "ref_1",
						"file_path":    "course:1",
						"content":      []string{"Spring 的 IOC 容器负责 Bean 的创建。"},
					},
				},
			})
		case "/query/data":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"status":  "success",
				"message": "ok",
				"data": map[string]any{
					"entities": []map[string]any{
						{"entity_name": "IOC", "file_path": "course:1", "reference_id": "ref_1"},
						{"entity_name": "Bean", "file_path": "course:1", "reference_id": "ref_1"},
					},
					"chunks": []map[string]any{
						{"content": "Spring 的 IOC 容器负责 Bean 的创建。", "file_path": "course:1", "chunk_id": "chunk-1", "reference_id": "ref_1"},
					},
					"references": []map[string]any{
						{"reference_id": "ref_1", "file_path": "course:1"},
					},
				},
				"metadata": map[string]any{
					"query_mode": "local",
				},
			})
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	client := NewLightRAGQueryClient(srv.URL+"/query", "query-token", 2*time.Second, 5, 30*time.Second)
	resp, err := client.Query(context.Background(), LightRAGQueryRequest{
		Query:    "什么是 IOC",
		Mode:     "local",
		Scope:    "course",
		CourseID: 1,
		TopK:     5,
		TraceID:  "trace-query-1",
	})
	if err != nil {
		t.Fatalf("query failed: %v", err)
	}

	if gotAPIKey != "query-token" {
		t.Fatalf("unexpected api key header: %s", gotAPIKey)
	}
	if len(gotPaths) != 2 || gotPaths[0] != "/query" || gotPaths[1] != "/query/data" {
		t.Fatalf("unexpected request paths: %#v", gotPaths)
	}
	if resp.Answer != "IOC 是控制反转。" {
		t.Fatalf("unexpected answer: %#v", resp)
	}
	if resp.ModeUsed != "local" {
		t.Fatalf("unexpected mode: %#v", resp)
	}
	if len(resp.Entities) != 2 || resp.Entities[0] != "IOC" {
		t.Fatalf("unexpected entities: %#v", resp.Entities)
	}
	if len(resp.Sources) != 1 || resp.Sources[0].SourceID != "course:1" || resp.Sources[0].SourceURL != "/api/v1/courses/1" {
		t.Fatalf("unexpected sources: %#v", resp.Sources)
	}
	if resp.Raw == nil {
		t.Fatalf("expected raw payload")
	}
}

func TestLightRAGQueryClientQuery_RejectsEmptyEndpoint(t *testing.T) {
	client := NewLightRAGQueryClient("", "", time.Second, 5, 30*time.Second)
	if _, err := client.Query(context.Background(), LightRAGQueryRequest{Query: "test"}); err == nil {
		t.Fatal("expected error for empty endpoint")
	}
}

func TestDeriveLightRAGQueryDataEndpoint(t *testing.T) {
	got := deriveLightRAGQueryDataEndpoint("http://127.0.0.1:9621/query")
	if got != "http://127.0.0.1:9621/query/data" {
		t.Fatalf("unexpected endpoint: %s", got)
	}
	if strings.TrimSpace(deriveLightRAGQueryDataEndpoint("")) != "/data" {
		t.Fatalf("unexpected empty endpoint derivation")
	}
}
