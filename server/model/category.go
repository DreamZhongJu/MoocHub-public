package model

import (
	"time"

	"github.com/DreamZhongJu/next-shop/dao"
)

// Category represents a row in the categories table.
type Category struct {
	ID        int       `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Name      string    `gorm:"column:name;type:varchar(50);not null" json:"name"`
	Level1ID  int       `gorm:"column:level1_id" json:"level1_id"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

// TableName binds the model to the categories table.
func (Category) TableName() string {
	return "categories"
}

// GetAllCategories returns all category records.
func GetAllCategories() ([]Category, error) {
	var categories []Category
	err := dao.GetDB().Find(&categories).Error
	return categories, err
}

// GetLevel2ByLevel1ID returns level-2 categories under a specific level-1 category.
func GetLevel2ByLevel1ID(level1ID int) ([]Category, error) {
	var categories []Category
	err := dao.GetDB().Where("level1_id = ?", level1ID).Find(&categories).Error
	return categories, err
}

// Level1Category represents a row in the category_level1 table (一级分类).
type Level1Category struct {
	ID        int       `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Name      string    `gorm:"column:name;type:varchar(50);not null" json:"name"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

// TableName binds Level1Category to the category_level1 table.
func (Level1Category) TableName() string {
	return "category_level1"
}

// GetAllLevel1Categories returns all level-1 category records.
func GetAllLevel1Categories() ([]Level1Category, error) {
	var categories []Level1Category
	err := dao.GetDB().Find(&categories).Error
	return categories, err
}
