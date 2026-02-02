package model

import (
	"MOOCHUB-server/db"
	"fmt"
	"time"
)

type FavoriteVideo struct {
	ID         int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID     int64     `gorm:"column:user_id;not null;index" json:"user_id"`
	VideoID    int64     `gorm:"column:video_id;not null;index" json:"video_id"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	is_deleted int       `gorm:"column:is_deleted" json:"is_deleted"`
}

func (FavoriteVideo) TableName() string {
	return "favorite_videos"
}

func ToggleFavoriteVideo(userID int, videoID int64) error {
	var count int64
	err := db.GetDB().Table(FavoriteVideo{}.TableName()).
		Where("user_id = ? AND video_id = ?", userID, videoID).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count > 0 {
		var isDeleted int
		err = db.GetDB().Table(FavoriteVideo{}.TableName()).
			Where("user_id = ? AND video_id = ?", userID, videoID).
			Select("is_deleted").Row().Scan(&isDeleted)
		if err != nil {
			return err
		}
		if isDeleted == 0 {
			return fmt.Errorf("已收藏")
		}
		return db.GetDB().Table(FavoriteVideo{}.TableName()).
			Where("user_id = ? AND video_id = ?", userID, videoID).
			Update("is_deleted", 0).Error
	}

	var userCount int64
	if err := db.GetDB().Table("users").Where("id = ?", userID).Count(&userCount).Error; err != nil {
		return err
	}
	if userCount == 0 {
		return fmt.Errorf("用户不存在")
	}

	var videoCount int64
	if err := db.GetDB().Table("videos").Where("id = ?", videoID).Count(&videoCount).Error; err != nil {
		return err
	}
	if videoCount == 0 {
		return fmt.Errorf("视频不存在")
	}

	return db.GetDB().Table(FavoriteVideo{}.TableName()).Create(map[string]any{
		"user_id":    userID,
		"video_id":   videoID,
		"created_at": time.Now(),
		"is_deleted": 0,
	}).Error
}

func DeleteFavoriteVideo(userID int, videoID int64) error {
	var count int64
	err := db.GetDB().Table(FavoriteVideo{}.TableName()).
		Where("user_id = ? AND video_id = ?", userID, videoID).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count == 0 {
		return fmt.Errorf("收藏不存在")
	}

	var isDeleted int
	err = db.GetDB().Table(FavoriteVideo{}.TableName()).
		Where("user_id = ? AND video_id = ?", userID, videoID).
		Select("is_deleted").Row().Scan(&isDeleted)
	if err != nil {
		return err
	}
	if isDeleted == 1 {
		return fmt.Errorf("已删除")
	}

	return db.GetDB().Table(FavoriteVideo{}.TableName()).
		Where("user_id = ? AND video_id = ?", userID, videoID).
		Update("is_deleted", 1).Error
}

func GetFavoriteVideos(userID int) ([]Video, error) {
	var videos []Video
	err := db.GetDB().Table("favorite_videos AS fv").
		Select("v.*").
		Joins("JOIN videos v ON v.id = fv.video_id").
		Where("fv.user_id = ? AND fv.is_deleted = ?", userID, 0).
		Order("fv.created_at DESC").
		Scan(&videos).Error
	if err != nil {
		return nil, err
	}
	return videos, nil
}
