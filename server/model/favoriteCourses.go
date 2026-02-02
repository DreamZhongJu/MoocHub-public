package model

import (
	"MOOCHUB-server/db"
	"fmt"
	"time"
)

type favoriteCourses struct {
	UserID     int       `gorm:"column:user_id" json:"user_id"`
	CourseID   int64     `gorm:"column:course_id" json:"course_id"`
	CreatedAt  time.Time `gorm:"column:created_at" json:"created_at"`
	is_deleted int       `gorm:"column:is_deleted" json:"is_deleted"`
}

func (favoriteCourses) TableName() string {
	return "favorite_courses"
}

func ToggleFavoriteCourse(userID int, courseID int64) error {
	var count int64
	err := db.GetDB().Table(favoriteCourses{}.TableName()).
		Where("user_id = ? AND course_id = ?", userID, courseID).
		Count(&count).Error
	if err != nil {
		return err
	}

	if count > 0 {
		var isDeleted int
		err = db.GetDB().Table(favoriteCourses{}.TableName()).
			Where("user_id = ? AND course_id = ?", userID, courseID).
			Select("is_deleted").Row().Scan(&isDeleted)
		if err != nil {
			return err
		}
		if isDeleted == 0 {
			return fmt.Errorf("已收藏")
		}
		// 如果 is_deleted 是 1，更新为 0
		err = db.GetDB().Table(favoriteCourses{}.TableName()).
			Where("user_id = ? AND course_id = ?", userID, courseID).
			Update("is_deleted", 0).Error
		return err
	}

	// 检查 user_id 是否存在
	var userCount int64
	if err := db.GetDB().Table("users").Where("id = ?", userID).Count(&userCount).Error; err != nil {
		return err
	}
	if userCount == 0 {
		return fmt.Errorf("用户不存在")
	}
	// 检查 course_id 是否存在
	var courseCount int64
	if err := db.GetDB().Table("courses").Where("id = ?", courseID).Count(&courseCount).Error; err != nil {
		return err
	}
	if courseCount == 0 {
		return fmt.Errorf("课程不存在")
	}
	// 插入收藏记录
	err = db.GetDB().Table(favoriteCourses{}.TableName()).Create(map[string]any{
		"user_id":    userID,
		"course_id":  courseID,
		"created_at": time.Now(),
		"is_deleted": 0,
	}).Error
	return err
}

func DeleteFavoriteCourse(userID int, courseID int64) error {
	var count int64
	err := db.GetDB().Table(favoriteCourses{}.TableName()).
		Where("user_id = ? AND course_id = ?", userID, courseID).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count == 0 {
		return fmt.Errorf("收藏不存在")
	}

	var isDeleted int
	err = db.GetDB().Table(favoriteCourses{}.TableName()).
		Where("user_id = ? AND course_id = ?", userID, courseID).
		Select("is_deleted").Row().Scan(&isDeleted)
	if err != nil {
		return err
	}
	if isDeleted == 1 {
		return fmt.Errorf("已删除")
	}

	err = db.GetDB().Table(favoriteCourses{}.TableName()).
		Where("user_id = ? AND course_id = ?", userID, courseID).
		Update("is_deleted", 1).Error
	return err
}

func GetFavoriteCourses(userID int) ([]Courses, error) {
	var courses []Courses
	err := db.GetDB().Table("favorite_courses AS fc").
		Select("c.*").
		Joins("JOIN courses c ON c.id = fc.course_id").
		Where("fc.user_id = ? AND fc.is_deleted = ?", userID, 0).
		Order("fc.created_at DESC").
		Scan(&courses).Error
	if err != nil {
		return nil, err
	}
	return courses, nil
}
