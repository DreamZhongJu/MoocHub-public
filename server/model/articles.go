package model

import (
	"MOOCHUB-server/db"
	"strconv"
	"time"

	"gorm.io/gorm"
)

type Article struct {
	ID        int64     `gorm:"column:id;primaryKey" json:"id"`
	UserID    int64     `gorm:"column:user_id" json:"user_id"`
	Title     string    `gorm:"column:title" json:"title"`
	Summary   string    `gorm:"column:summary" json:"summary"`
	CoverURL  string    `gorm:"column:cover_url" json:"cover_url"`
	Content   string    `gorm:"column:content" json:"content"`
	Status    string    `gorm:"column:status" json:"status"`
	ViewCount int64     `gorm:"column:view_count" json:"view_count"`
	LikeCount int64     `gorm:"column:like_count" json:"like_count"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at" json:"updated_at"`
}

func GetArticles(sort string, page string, pageSize string) ([]Article, error) {
	var articles []Article
	dbq := db.GetDB()

	switch sort {
	case "view_count":
		dbq = dbq.Order("view_count DESC")
	case "like_count":
		dbq = dbq.Order("like_count DESC")
	default:
		dbq = dbq.Order("created_at DESC")
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
	dbq = dbq.Offset(offset).Limit(pageSizeInt)

	if err := dbq.Find(&articles).Error; err != nil {
		return nil, err
	}
	return articles, nil
}

func GetArticleByID(id int64) (*Article, error) {
	var article Article
	if err := db.GetDB().Where("id = ?", id).First(&article).Error; err != nil {
		return nil, err
	}
	return &article, nil
}

func CreateArticle(article *Article) error {
	return db.GetDB().Create(article).Error
}

func UpdateArticle(id int64, updates map[string]any) error {
	if len(updates) == 0 {
		return nil
	}
	return db.GetDB().Model(&Article{}).Where("id = ?", id).Updates(updates).Error
}

func DeleteArticle(id int64) error {
	return db.GetDB().Where("id = ?", id).Delete(&Article{}).Error
}

func IncrementArticleViewCount(articleID int64) error {
	return db.GetDB().Model(&Article{}).
		Where("id = ?", articleID).
		UpdateColumn("view_count", gorm.Expr("view_count + 1")).Error
}

func IncrementArticleLikeCount(articleID int64) (int64, error) {
	if err := db.GetDB().Model(&Article{}).
		Where("id = ?", articleID).
		UpdateColumn("like_count", gorm.Expr("like_count + 1")).Error; err != nil {
		return 0, err
	}
	var likeCount int64
	if err := db.GetDB().Model(&Article{}).
		Select("like_count").
		Where("id = ?", articleID).
		Scan(&likeCount).Error; err != nil {
		return 0, err
	}
	return likeCount, nil
}
