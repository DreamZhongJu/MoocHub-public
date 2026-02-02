package model

import "time"

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
