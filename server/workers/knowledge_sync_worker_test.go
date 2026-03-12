package workers

import (
	"MOOCHUB-server/mq"
	"testing"
)

func TestBuildLightRAGSyncRequest_DeleteKeepsMinimalPayload(t *testing.T) {
	req, err := buildLightRAGSyncRequest(mq.KnowledgeSyncPayload{
		SourceType: "article",
		BizID:      9,
		SourceID:   "article:9",
		Action:     mq.KnowledgeSyncActionDelete,
	})
	if err != nil {
		t.Fatalf("build request failed: %v", err)
	}
	if req.Action != mq.KnowledgeSyncActionDelete {
		t.Fatalf("expected delete action, got %s", req.Action)
	}
	if req.Source != nil {
		t.Fatalf("expected nil source for delete, got %#v", req.Source)
	}
	if req.SourceID != "article:9" {
		t.Fatalf("unexpected source id: %s", req.SourceID)
	}
}
