package workers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"
)

func StartEventAnalyticsWorker() {
	msgs, err := mq.Consume("analytics.event", "moochub.analytics.event")
	if err != nil {
		global.Log.Error("analytics worker consume failed", zap.Error(err))
		return
	}

	go func() {
		for msg := range msgs {
			traceID := mq.TraceIDFromDelivery(msg)
			logger := global.Log.With(
				zap.String("trace_id", traceID),
				zap.String("routing_key", msg.RoutingKey),
			)

			var evt model.AnalyticsEventPayload
			if err := json.Unmarshal(msg.Body, &evt); err != nil {
				logger.Warn("analytics worker decode failed", zap.Error(err))
				_ = msg.Nack(false, false)
				continue
			}
			if evt.EventType == "" || evt.ContentType == "" || evt.ContentID <= 0 {
				logger.Warn("analytics worker invalid payload",
					zap.String("event_type", evt.EventType),
					zap.String("content_type", evt.ContentType),
					zap.Int64("content_id", evt.ContentID),
				)
				_ = msg.Nack(false, false)
				continue
			}
			if evt.OccurredAtUnixSec <= 0 {
				evt.OccurredAtUnixSec = time.Now().Unix()
			}

			if err := model.CreateEventLog(evt); err != nil {
				logger.Error("analytics event log insert failed", zap.Error(err))
				_ = msg.Nack(false, false)
				continue
			}

			uvDelta := int64(0)
			actor := buildAnalyticsActor(evt)
			if actor != "" {
				if markUniqueUV(evt, actor) {
					uvDelta = 1
				}
			}

			if err := model.AddEventStatsHourly(evt, 1, uvDelta); err != nil {
				logger.Error("analytics hourly stats update failed", zap.Error(err))
				_ = msg.Nack(false, false)
				continue
			}

			_ = msg.Ack(false)
		}
	}()
}

func buildAnalyticsActor(evt model.AnalyticsEventPayload) string {
	if evt.UserID > 0 {
		return fmt.Sprintf("u:%d", evt.UserID)
	}
	if strings.TrimSpace(evt.SessionID) != "" {
		return "s:" + strings.TrimSpace(evt.SessionID)
	}
	hash := sha1.Sum([]byte(strings.TrimSpace(evt.IP) + "|" + strings.TrimSpace(evt.UA)))
	return "a:" + hex.EncodeToString(hash[:8])
}

func markUniqueUV(evt model.AnalyticsEventPayload, actor string) bool {
	client := cache.Client()
	if client == nil {
		return true
	}

	occurredAt := time.Unix(evt.OccurredAtUnixSec, 0)
	hour := occurredAt.Truncate(time.Hour).Format("2006010215")
	key := fmt.Sprintf(
		"analytics:uv:%s:%s:%s:%d:%s:%s",
		hour,
		evt.EventType,
		evt.ContentType,
		evt.ContentID,
		evt.Scene,
		actor,
	)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ok, err := client.SetNX(ctx, key, "1", 2*time.Hour).Result()
	if err != nil {
		global.Log.Warn("analytics uv dedup failed, fallback count", zap.Error(err))
		return true
	}
	return ok
}
