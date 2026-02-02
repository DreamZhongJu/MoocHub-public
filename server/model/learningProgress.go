package model

import (
	"MOOCHUB-server/db"
	"time"
)

type LearningProgress struct {
	ID              int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID          int64     `gorm:"column:user_id;not null;index" json:"user_id"`
	VideoID         int64     `gorm:"column:video_id;not null;index" json:"video_id"`
	LastPositionSec int       `gorm:"column:last_position_sec;not null;default:0" json:"last_position_sec"`
	ProgressPercent float64   `gorm:"column:progress_percent;type:decimal(5,2);not null;default:0.00" json:"progress_percent"`
	UpdatedAt       time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (LearningProgress) TableName() string {
	return "learning_progress"
}

func UpsertLearningProgress(userID int64, videoID int64, lastPositionSec int, progressPercent float64) error {
	var existing LearningProgress
	err := db.GetDB().Where("user_id = ? AND video_id = ?", userID, videoID).First(&existing).Error
	if err == nil {
		return db.GetDB().Model(&LearningProgress{}).
			Where("user_id = ? AND video_id = ?", userID, videoID).
			Updates(map[string]any{
				"last_position_sec": lastPositionSec,
				"progress_percent":  progressPercent,
			}).Error
	}
	progress := LearningProgress{
		UserID:          userID,
		VideoID:         videoID,
		LastPositionSec: lastPositionSec,
		ProgressPercent: progressPercent,
	}
	return db.GetDB().Create(&progress).Error
}

func GetLearningProgress(userID int64, videoID int64) (LearningProgress, error) {
	var progress LearningProgress
	err := db.GetDB().Where("user_id = ? AND video_id = ?", userID, videoID).First(&progress).Error
	if err != nil {
		return LearningProgress{}, err
	}
	return progress, nil
}
