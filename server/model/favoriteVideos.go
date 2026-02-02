package model

import "time"

type FavoriteVideo struct {
	ID        int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID    int64     `gorm:"column:user_id;not null;index" json:"user_id"`
	VideoID   int64     `gorm:"column:video_id;not null;index" json:"video_id"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

func (FavoriteVideo) TableName() string {
	return "favorite_videos"
}
