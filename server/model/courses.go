package model

import "time"

type Courses struct {
	ID            int64     `gorm:"column:id;primaryKey" json:"id"`
	CategoryID    int64     `gorm:"column:category_id" json:"category_id"`
	Title         string    `gorm:"column:title" json:"title"`
	Summary       string    `gorm:"column:summary" json:"summary"`
	CoverURL      string    `gorm:"column:cover_url" json:"cover_url"`
	Instructor    string    `gorm:"column:instructor_name" json:"instructor_name"`
	Level         string    `gorm:"column:level" json:"level"`
	Status        string    `gorm:"column:status" json:"status"`
	ViewCount     int64     `gorm:"column:view_count" json:"view_count"`
	FavoriteCount int64     `gorm:"column:favorite_count" json:"favorite_count"`
	CreatedAt     time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt     time.Time `gorm:"column:updated_at" json:"updated_at"`
}
