package model

import (
	"MOOCHUB-server/db"
	"strconv"
	"time"
)

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

func GetCoursesByCategory(categoryID int64, sort string, page string, pageSize string) ([]Courses, error) {
	var courses []Courses
	db := db.GetDB()
	if categoryID != 0 {
		db = db.Where("category_id = ?", categoryID)
	}
	switch sort {
	case "view_count":
		db = db.Order("view_count DESC")
	case "favorite_count":
		db = db.Order("favorite_count DESC")
	default:
		db = db.Order("created_at DESC")
	}
	pageInt, err := strconv.Atoi(page)
	if err != nil {
		return nil, err
	}
	pageSizeInt, err := strconv.Atoi(pageSize)
	if err != nil {
		return nil, err
	}
	offset := (pageInt - 1) * pageSizeInt
	db = db.Offset(offset).Limit(pageSizeInt)
	result := db.Find(&courses)
	if result.Error != nil {
		return nil, result.Error
	}
	return courses, nil
}
func GetCoursesDetails(ID int64) ([]Courses, error) {
	var courses []Courses
	result := db.GetDB().Where("id = ?", ID).Find(&courses)
	if result.Error != nil {
		return nil, result.Error
	}
	return courses, nil
}
