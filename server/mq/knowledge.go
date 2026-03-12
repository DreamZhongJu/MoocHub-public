package mq

import "encoding/json"

const (
	KnowledgeSyncRoutingKey = "knowledge.sync"

	KnowledgeSyncActionUpsert = "upsert"
	KnowledgeSyncActionDelete = "delete"
)

type KnowledgeSyncPayload struct {
	SourceType string         `json:"source_type"`
	BizID      int64          `json:"biz_id"`
	SourceID   string         `json:"source_id"`
	Action     string         `json:"action"`
	Status     string         `json:"status,omitempty"`
	Metadata   map[string]any `json:"metadata,omitempty"`
}

func PublishKnowledgeSyncWithTrace(payload KnowledgeSyncPayload, traceID string) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return PublishWithTrace(KnowledgeSyncRoutingKey, body, traceID)
}
