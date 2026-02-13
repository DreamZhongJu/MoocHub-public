package model

import (
	"MOOCHUB-server/db"
	"fmt"
	"time"
)

type FavoriteArticle struct {
	ID         int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	UserID     int64     `gorm:"column:user_id;not null;index" json:"user_id"`
	ArticleID  int64     `gorm:"column:article_id;not null;index" json:"article_id"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	is_deleted int       `gorm:"column:is_deleted" json:"is_deleted"`
}

func (FavoriteArticle) TableName() string {
	return "favorite_articles"
}

func ToggleFavoriteArticle(userID int, articleID int64) error {
	var count int64
	err := db.GetDB().Table(FavoriteArticle{}.TableName()).
		Where("user_id = ? AND article_id = ?", userID, articleID).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count > 0 {
		var isDeleted int
		err = db.GetDB().Table(FavoriteArticle{}.TableName()).
			Where("user_id = ? AND article_id = ?", userID, articleID).
			Select("is_deleted").Row().Scan(&isDeleted)
		if err != nil {
			return err
		}
		if isDeleted == 0 {
			return fmt.Errorf("已收藏")
		}
		return db.GetDB().Table(FavoriteArticle{}.TableName()).
			Where("user_id = ? AND article_id = ?", userID, articleID).
			Update("is_deleted", 0).Error
	}

	var userCount int64
	if err := db.GetDB().Table("users").Where("id = ?", userID).Count(&userCount).Error; err != nil {
		return err
	}
	if userCount == 0 {
		return fmt.Errorf("用户不存在")
	}

	var articleCount int64
	if err := db.GetDB().Table("articles").Where("id = ?", articleID).Count(&articleCount).Error; err != nil {
		return err
	}
	if articleCount == 0 {
		return fmt.Errorf("文章不存在")
	}

	return db.GetDB().Table(FavoriteArticle{}.TableName()).Create(map[string]any{
		"user_id":    userID,
		"article_id": articleID,
		"created_at": time.Now(),
		"is_deleted": 0,
	}).Error
}

func DeleteFavoriteArticle(userID int, articleID int64) error {
	var count int64
	err := db.GetDB().Table(FavoriteArticle{}.TableName()).
		Where("user_id = ? AND article_id = ?", userID, articleID).
		Count(&count).Error
	if err != nil {
		return err
	}
	if count == 0 {
		return fmt.Errorf("收藏不存在")
	}

	var isDeleted int
	err = db.GetDB().Table(FavoriteArticle{}.TableName()).
		Where("user_id = ? AND article_id = ?", userID, articleID).
		Select("is_deleted").Row().Scan(&isDeleted)
	if err != nil {
		return err
	}
	if isDeleted == 1 {
		return fmt.Errorf("已删除")
	}

	return db.GetDB().Table(FavoriteArticle{}.TableName()).
		Where("user_id = ? AND article_id = ?", userID, articleID).
		Update("is_deleted", 1).Error
}

func GetFavoriteArticles(userID int) ([]Article, error) {
	var articles []Article
	err := db.GetDB().Table("favorite_articles AS fa").
		Select("a.*").
		Joins("JOIN articles a ON a.id = fa.article_id").
		Where("fa.user_id = ? AND fa.is_deleted = ?", userID, 0).
		Order("fa.created_at DESC").
		Scan(&articles).Error
	if err != nil {
		return nil, err
	}
	return articles, nil
}
