package model

import "time"

type favoriteCourses struct {
	ID             int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	CategoryID     int64     `gorm:"column:category_id;not null" json:"category_id"`
	Title          string    `gorm:"column:title;type:varchar(128);not null" json:"title"`
	Summary        string    `gorm:"column:summary;type:varchar(1024)" json:"summary"`
	CoverURL       string    `gorm:"column:cover_url;type:varchar(512)" json:"cover_url"`
	InstructorName string    `gorm:"column:instructor_name;type:varchar(64)" json:"instructor_name"`
	Level          string    `gorm:"column:level;type:varchar(32)" json:"level"`
	Status         string    `gorm:"column:status;type:enum('draft','published')" json:"status"`
	ViewCount      int64     `gorm:"column:view_count;default:0" json:"view_count"`
	FavoriteCount  int64     `gorm:"column:favorite_count;default:0" json:"favorite_count"`
	CreatedAt      time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (favoriteCourses) TableName() string {
	return "courses"
}
