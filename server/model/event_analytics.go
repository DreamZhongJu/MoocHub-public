package model

import (
	"MOOCHUB-server/db"
	"time"
)

type AnalyticsEventPayload struct {
	EventType         string `json:"event_type"`
	ContentType       string `json:"content_type"`
	ContentID         int64  `json:"content_id"`
	UserID            int64  `json:"user_id"`
	SessionID         string `json:"session_id"`
	Scene             string `json:"scene"`
	Position          int    `json:"position"`
	IP                string `json:"ip"`
	UA                string `json:"ua"`
	OccurredAtUnixSec int64  `json:"occurred_at_unix_sec"`
}

type EventLog struct {
	ID          uint64    `gorm:"column:id;primaryKey" json:"id"`
	EventType   string    `gorm:"column:event_type" json:"event_type"`
	ContentType string    `gorm:"column:content_type" json:"content_type"`
	ContentID   int64     `gorm:"column:content_id" json:"content_id"`
	UserID      *int64    `gorm:"column:user_id" json:"user_id"`
	SessionID   string    `gorm:"column:session_id" json:"session_id"`
	Scene       string    `gorm:"column:scene" json:"scene"`
	Position    int       `gorm:"column:position" json:"position"`
	IP          string    `gorm:"column:ip" json:"ip"`
	UA          string    `gorm:"column:ua" json:"ua"`
	OccurredAt  time.Time `gorm:"column:occurred_at" json:"occurred_at"`
	CreatedAt   time.Time `gorm:"column:created_at" json:"created_at"`
}

func (EventLog) TableName() string {
	return "event_logs"
}

func CreateEventLog(evt AnalyticsEventPayload) error {
	occurredAt := time.Unix(evt.OccurredAtUnixSec, 0)
	if evt.OccurredAtUnixSec <= 0 {
		occurredAt = time.Now()
	}

	var userID *int64
	if evt.UserID > 0 {
		uid := evt.UserID
		userID = &uid
	}

	record := EventLog{
		EventType:   evt.EventType,
		ContentType: evt.ContentType,
		ContentID:   evt.ContentID,
		UserID:      userID,
		SessionID:   evt.SessionID,
		Scene:       evt.Scene,
		Position:    evt.Position,
		IP:          evt.IP,
		UA:          evt.UA,
		OccurredAt:  occurredAt,
	}

	return db.GetDB().Create(&record).Error
}

func AddEventStatsHourly(evt AnalyticsEventPayload, pvDelta int64, uvDelta int64) error {
	occurredAt := time.Unix(evt.OccurredAtUnixSec, 0)
	if evt.OccurredAtUnixSec <= 0 {
		occurredAt = time.Now()
	}
	bucketHour := occurredAt.Truncate(time.Hour)

	return db.GetDB().Exec(`
INSERT INTO event_stats_hourly (
  bucket_hour, event_type, content_type, content_id, scene, pv, uv, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
ON DUPLICATE KEY UPDATE
  pv = pv + VALUES(pv),
  uv = uv + VALUES(uv),
  updated_at = NOW()
`, bucketHour, evt.EventType, evt.ContentType, evt.ContentID, evt.Scene, pvDelta, uvDelta).Error
}
