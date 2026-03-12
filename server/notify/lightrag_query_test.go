package notify

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLightRAGQueryClientQuery_SendsRequestAndParsesResponse(t *testing.T) {
	var gotAuth string
	var gotReq LightRAGQueryRequest

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		if err := json.NewDecoder(r.Body).Decode(&gotReq); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		_ = json.NewEncoder(w).Encode(LightRAGQueryResponse{
			Answer:   "IOC 是一种控制反转思想。",
			ModeUsed: "local",
			Sources: []LightRAGQuerySource{
				{SourceID: "course:1", SourceType: "course", BizID: 1, Title: "Spring Boot"},
			},
		})
	}))
	defer srv.Close()

	client := NewLightRAGQueryClient(srv.URL, "query-token", 2*time.Second, 5, 30*time.Second)
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

	if gotAuth != "Bearer query-token" {
		t.Fatalf("unexpected auth header: %s", gotAuth)
	}
	if gotReq.Query != "什么是 IOC" || gotReq.Mode != "local" || gotReq.Scope != "course" || gotReq.CourseID != 1 {
		t.Fatalf("unexpected request payload: %#v", gotReq)
	}
	if resp.Answer == "" || resp.ModeUsed != "local" || len(resp.Sources) != 1 {
		t.Fatalf("unexpected response payload: %#v", resp)
	}
}

func TestLightRAGQueryClientQuery_RejectsEmptyEndpoint(t *testing.T) {
	client := NewLightRAGQueryClient("", "", time.Second, 5, 30*time.Second)
	if _, err := client.Query(context.Background(), LightRAGQueryRequest{Query: "test"}); err == nil {
		t.Fatal("expected error for empty endpoint")
	}
}
