package workers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
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

	// 定时批量刷库：每 10 秒将 Redis 中的进度缓冲写入 MySQL
	go func() {
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			flushProgressBuffer()
		}
	}()

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
				// 写入 Redis 缓冲，等待批量刷库
				bufferKey := buildProgressBufferKey()
				fieldKey := buildProgressBufferField(evt.UserID, evt.VideoID)
				_ = client.HSet(ctx, bufferKey, fieldKey, payload).Err()
				_ = client.Expire(ctx, bufferKey, 24*time.Hour).Err()
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

func buildProgressBufferKey() string {
	return "progress:buffer"
}

func buildProgressBufferField(userID int64, videoID int64) string {
	return fmt.Sprintf("%d:%d", userID, videoID)
}

func flushProgressBuffer() {
	client := cache.Client()
	if client == nil {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	bufferKey := buildProgressBufferKey()
	entries, err := client.HGetAll(ctx, bufferKey).Result()
	if err != nil || len(entries) == 0 {
		return
	}

	for field, raw := range entries {
		var payload struct {
			VideoID         int64   `json:"video_id"`
			LastPositionSec int     `json:"last_position_sec"`
			ProgressPercent float64 `json:"progress_percent"`
		}
		if err := json.Unmarshal([]byte(raw), &payload); err != nil {
			_ = client.HDel(ctx, bufferKey, field).Err()
			continue
		}

		var userID int64
		var videoID int64
		if _, err := fmt.Sscanf(field, "%d:%d", &userID, &videoID); err != nil {
			_ = client.HDel(ctx, bufferKey, field).Err()
			continue
		}

		if err := model.UpsertLearningProgress(userID, videoID, payload.LastPositionSec, payload.ProgressPercent); err != nil {
			global.Log.Error("progress batch upsert failed", zap.Error(err))
			continue
		}

		_ = client.HDel(ctx, bufferKey, field).Err()
	}
}
