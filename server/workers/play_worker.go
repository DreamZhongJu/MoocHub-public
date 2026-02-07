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
			var evt playEvent
			if err := json.Unmarshal(msg.Body, &evt); err != nil {
				_ = msg.Nack(false, false)
				continue
			}
			if evt.VideoID == 0 {
				_ = msg.Nack(false, false)
				continue
			}

			video, err := model.GetVideoDetails(evt.VideoID)
			if err != nil {
				_ = msg.Nack(false, false)
				continue
			}
			if err := model.IncrementCourseViewCount(video.CourseID); err != nil {
				_ = msg.Nack(false, false)
				continue
			}

			_ = msg.Ack(false)
		}
	}()
}
