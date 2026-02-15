package workers

import (
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"encoding/json"

	"go.uber.org/zap"
)

type playEvent struct {
	Event             string `json:"event"`
	UserID            int64  `json:"user_id"`
	VideoID           int64  `json:"video_id"`
	IP                string `json:"ip"`
	UA                string `json:"ua"`
	OccurredAtUnixSec int64  `json:"occurred_at_unix_sec"`
}

func StartPlayWorker() {
	msgs, err := mq.Consume("play.view", "moochub.play.view")
	if err != nil {
		global.Log.Error("play worker consume failed", zap.Error(err))
		return
	}
	go func() {
		for msg := range msgs {
			traceID := mq.TraceIDFromDelivery(msg)
			logger := global.Log.With(
				zap.String("trace_id", traceID),
				zap.String("routing_key", msg.RoutingKey),
			)

			var evt playEvent
			if err := json.Unmarshal(msg.Body, &evt); err != nil {
				logger.Warn("play worker decode failed", zap.Error(err))
				_ = msg.Nack(false, false)
				continue
			}
			if evt.VideoID == 0 {
				logger.Warn("play worker invalid payload", zap.Int64("video_id", evt.VideoID))
				_ = msg.Nack(false, false)
				continue
			}

			video, err := model.GetVideoDetails(evt.VideoID)
			if err != nil {
				logger.Error("play worker load video failed", zap.Error(err), zap.Int64("video_id", evt.VideoID))
				_ = msg.Nack(false, false)
				continue
			}
			if err := model.IncrementCourseViewCount(video.CourseID); err != nil {
				logger.Error("play worker increment view failed", zap.Error(err), zap.Int64("course_id", video.CourseID))
				_ = msg.Nack(false, false)
				continue
			}

			_ = msg.Ack(false)
		}
	}()
}
