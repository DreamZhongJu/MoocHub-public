package model

import (
	"MOOCHUB-server/db"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
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
	progress := LearningProgress{
		UserID:          userID,
		VideoID:         videoID,
		LastPositionSec: lastPositionSec,
		ProgressPercent: progressPercent,
	}
	return db.GetDB().Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}, {Name: "video_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"last_position_sec", "progress_percent", "updated_at"}),
	}).Create(&progress).Error
}

func GetLearningProgress(userID int64, videoID int64) (LearningProgress, error) {
	var progress LearningProgress
	err := db.GetDB().Where("user_id = ? AND video_id = ?", userID, videoID).First(&progress).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return LearningProgress{}, nil
		}
		return LearningProgress{}, err
	}
	return progress, nil
}

func GetLatestLearningProgress(userID int64) (*LearningProgress, *Video, error) {
	var progress LearningProgress
	err := db.GetDB().
		Where("user_id = ?", userID).
		Order("updated_at DESC").
		First(&progress).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil, nil
		}
		return nil, nil, err
	}
	video, err := GetVideoDetails(progress.VideoID)
	if err != nil {
		return &progress, nil, err
	}
	return &progress, &video, nil
}
