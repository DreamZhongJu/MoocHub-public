package workers

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/notify"
	"context"
	"encoding/json"
	"errors"

	"go.uber.org/zap"
	"gorm.io/gorm"
)

func StartKnowledgeSyncWorker() {
	endpoint := config.LightRAGSyncURL()
	if endpoint == "" {
		global.Log.Info("knowledge sync worker skipped: LIGHTRAG_SYNC_URL not configured")
		return
	}

	client := notify.NewLightRAGSyncClient(
		endpoint,
		config.LightRAGSyncToken(),
		config.LightRAGSyncTimeout(),
		config.BreakerFailureThreshold(),
		config.BreakerOpenTimeout(),
	)

	msgs, err := mq.Consume(mq.KnowledgeSyncRoutingKey, "moochub.knowledge.sync")
	if err != nil {
		global.Log.Error("knowledge sync worker consume failed", zap.Error(err))
		return
	}

	go func() {
		for msg := range msgs {
			traceID := mq.TraceIDFromDelivery(msg)
			logger := global.Log.With(
				zap.String("trace_id", traceID),
				zap.String("routing_key", msg.RoutingKey),
			)

			var evt mq.KnowledgeSyncPayload
			if err := json.Unmarshal(msg.Body, &evt); err != nil {
				logger.Warn("knowledge sync decode failed", zap.Error(err))
				_ = msg.Nack(false, false)
				continue
			}

			req, err := buildLightRAGSyncRequest(evt)
			if err != nil {
				logger.Warn("knowledge sync build request failed",
					zap.String("source_type", evt.SourceType),
					zap.Int64("biz_id", evt.BizID),
					zap.String("action", evt.Action),
					zap.Error(err),
				)
				_ = msg.Nack(false, false)
				continue
			}

			ctx, cancel := context.WithTimeout(context.Background(), config.LightRAGSyncTimeout())
			err = client.Sync(ctx, req)
			cancel()
			if err != nil {
				logger.Error("knowledge sync send failed",
					zap.String("source_type", evt.SourceType),
					zap.Int64("biz_id", evt.BizID),
					zap.String("action", evt.Action),
					zap.Error(err),
				)
				_ = msg.Nack(false, true)
				continue
			}

			_ = msg.Ack(false)
		}
	}()
}

func buildLightRAGSyncRequest(evt mq.KnowledgeSyncPayload) (notify.LightRAGSyncRequest, error) {
	req := notify.LightRAGSyncRequest{
		SourceType: evt.SourceType,
		BizID:      evt.BizID,
		SourceID:   evt.SourceID,
		Action:     evt.Action,
		Status:     evt.Status,
	}

	if evt.Action == mq.KnowledgeSyncActionDelete {
		return req, nil
	}

	source, err := model.GetKnowledgeSourceByID(evt.SourceType, evt.BizID, "")
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			req.Action = mq.KnowledgeSyncActionDelete
			return req, nil
		}
		return notify.LightRAGSyncRequest{}, err
	}
	req.Source = source
	if req.Status == "" && source != nil {
		req.Status = source.Status
	}
	return req, nil
}
