package model

import (
	"MOOCHUB-server/db"
	"strconv"
	"time"

	"gorm.io/gorm"
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
	db := db.GetDB().Model(&Courses{}).Where("status = ?", "published")
	if categoryID != 0 {
		db = db.Where("category_id = ?", categoryID)
	}
	switch sort {
	case "view_count":
		db = db.Order("view_count DESC").Order("id DESC")
	case "favorite_count":
		db = db.Order("favorite_count DESC").Order("id DESC")
	default:
		db = db.Order("created_at DESC").Order("id DESC")
	}
	pageInt, err := strconv.Atoi(page)
	if err != nil {
		return nil, err
	}
	if pageInt < 1 {
		pageInt = 1
	}
	pageSizeInt, err := strconv.Atoi(pageSize)
	if err != nil {
		return nil, err
	}
	if pageSizeInt < 1 {
		pageSizeInt = 10
	}
	if pageSizeInt > 100 {
		pageSizeInt = 100
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

func CreateCourse(course *Courses) error {
	return db.GetDB().Create(course).Error
}

func UpdateCourse(id int64, updates map[string]any) error {
	if len(updates) == 0 {
		return nil
	}
	return db.GetDB().Model(&Courses{}).Where("id = ?", id).Updates(updates).Error
}

func DeleteCourse(id int64) error {
	return db.GetDB().Where("id = ?", id).Delete(&Courses{}).Error
}

func IncrementCourseViewCount(courseID int64) error {
	return db.GetDB().Model(&Courses{}).
		Where("id = ?", courseID).
		UpdateColumn("view_count", gorm.Expr("view_count + 1")).Error
}

func GetHotCourseIDs(limit int) ([]int64, error) {
	if limit <= 0 {
		limit = 10
	}
	if limit > 100 {
		limit = 100
	}
	ids := make([]int64, 0, limit)
	err := db.GetDB().Model(&Courses{}).
		Where("status = ?", "published").
		Order("view_count DESC").
		Order("id DESC").
		Limit(limit).
		Pluck("id", &ids).Error
	if err != nil {
		return nil, err
	}
	return ids, nil
}
