package workers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/global"
	"MOOCHUB-server/mq"
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go.uber.org/zap"
)

type progressEvent struct {
	Event             string  `json:"event"`
	UserID            int64   `json:"user_id"`
	VideoID           int64   `json:"video_id"`
	LastPositionSec   int     `json:"last_position_sec"`
	ProgressPercent   float64 `json:"progress_percent"`
	OccurredAtUnixSec int64   `json:"occurred_at_unix_sec"`
}

func StartProgressWorker() {
	msgs, err := mq.Consume("progress.updated", "moochub.progress.updated")
	if err != nil {
		global.Log.Error("progress worker consume failed", zap.Error(err))
		return
	}
	go func() {
		for msg := range msgs {
			var evt progressEvent
			if err := json.Unmarshal(msg.Body, &evt); err != nil {
				_ = msg.Nack(false, false)
				continue
			}
			if evt.UserID == 0 || evt.VideoID == 0 {
				_ = msg.Nack(false, false)
				continue
			}

			payload, _ := json.Marshal(map[string]any{
				"video_id":             evt.VideoID,
				"last_position_sec":    evt.LastPositionSec,
				"progress_percent":     evt.ProgressPercent,
				"occurred_at_unix_sec": evt.OccurredAtUnixSec,
			})

			client := cache.Client()
			if client != nil {
				ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
				_ = client.Set(ctx, buildLastWatchKey(evt.UserID), payload, 7*24*time.Hour).Err()
				cancel()
			}
			_ = msg.Ack(false)
		}
	}()
}

func buildLastWatchKey(userID int64) string {
	return "user:last_watch:" + fmt.Sprint(userID)
}
