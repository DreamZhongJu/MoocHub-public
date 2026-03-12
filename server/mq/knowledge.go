package mq

import (
	"encoding/json"

	amqp "github.com/rabbitmq/amqp091-go"
)

const (
	KnowledgeSyncRoutingKey     = "knowledge.sync"
	KnowledgeSyncDeadRoutingKey = "knowledge.sync.dead"

	KnowledgeSyncQueueName     = "moochub.knowledge.sync"
	KnowledgeSyncDeadQueueName = "moochub.knowledge.sync.dead"

	knowledgeSyncRetryHeader = "x-retry-count"

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

func PublishKnowledgeSyncRetryWithTrace(payload KnowledgeSyncPayload, traceID string, retryCount int) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return PublishWithHeaders(
		KnowledgeSyncRoutingKey,
		body,
		traceID,
		amqp.Table{knowledgeSyncRetryHeader: retryCount},
	)
}

func PublishKnowledgeSyncDeadWithTrace(body []byte, traceID string, retryCount int) error {
	return PublishWithHeaders(
		KnowledgeSyncDeadRoutingKey,
		body,
		traceID,
		amqp.Table{knowledgeSyncRetryHeader: retryCount},
	)
}

func ConsumeKnowledgeSync() (<-chan amqp.Delivery, error) {
	if err := ensureKnowledgeSyncTopology(); err != nil {
		return nil, err
	}
	if ch == nil {
		return nil, nil
	}
	return ch.Consume(
		KnowledgeSyncQueueName,
		"",
		false,
		false,
		false,
		false,
		nil,
	)
}

func RetryCountFromDelivery(msg amqp.Delivery) int {
	if msg.Headers == nil {
		return 0
	}
	raw, ok := msg.Headers[knowledgeSyncRetryHeader]
	if !ok {
		return 0
	}
	switch v := raw.(type) {
	case int:
		if v < 0 {
			return 0
		}
		return v
	case int32:
		if v < 0 {
			return 0
		}
		return int(v)
	case int64:
		if v < 0 {
			return 0
		}
		return int(v)
	case float64:
		if v < 0 {
			return 0
		}
		return int(v)
	default:
		return 0
	}
}

func ensureKnowledgeSyncTopology() error {
	if ch == nil {
		return nil
	}
	if _, err := ch.QueueDeclare(
		KnowledgeSyncQueueName,
		true,
		false,
		false,
		false,
		nil,
	); err != nil {
		return err
	}
	if err := ch.QueueBind(KnowledgeSyncQueueName, KnowledgeSyncRoutingKey, exchangeName, false, nil); err != nil {
		return err
	}
	if _, err := ch.QueueDeclare(
		KnowledgeSyncDeadQueueName,
		true,
		false,
		false,
		false,
		nil,
	); err != nil {
		return err
	}
	return ch.QueueBind(KnowledgeSyncDeadQueueName, KnowledgeSyncDeadRoutingKey, exchangeName, false, nil)
}
