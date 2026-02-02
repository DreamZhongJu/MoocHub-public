package model

import (
	"MOOCHUB-server/db"
	"time"
)

type Video struct {
	ID          int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	CourseID    int64     `gorm:"column:course_id;not null;index" json:"course_id"`
	Title       string    `gorm:"column:title;type:varchar(128);not null" json:"title"`
	Description string    `gorm:"column:description;type:varchar(1024)" json:"description"`
	DurationSec int       `gorm:"column:duration_sec;not null" json:"duration_sec"`
	VideoURL    string    `gorm:"column:video_url;type:varchar(512);not null" json:"video_url"`
	ThumbURL    string    `gorm:"column:thumb_url;type:varchar(512)" json:"thumb_url"`
	SortOrder   int       `gorm:"column:sort_order;not null;default:0" json:"sort_order"`
	CreatedAt   time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

func (Video) TableName() string {
	return "videos"
}

func GetVideosByCourseID(courseID int64) ([]Video, error) {
	var videos []Video
	result := db.GetDB().Where("course_id = ?", courseID).Order("sort_order ASC").Find(&videos)
	if result.Error != nil {
		return nil, result.Error
	}
	return videos, nil
}
