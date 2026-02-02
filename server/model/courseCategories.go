package model

import "MOOCHUB-server/db"

type courseCategory struct {
	ID        int64  `bson:"_id,omitempty" json:"id"`
	Name      string `bson:"name" json:"name"`
	ParentID  *int64 `bson:"parent_id,omitempty" json:"parent_id,omitempty"`
	SortOrder int    `bson:"sort_order" json:"sort_order"`
}

func GetAllCourseCategories() ([]courseCategory, error) {
	var categories []courseCategory
	result := db.GetDB().Order("sort_order asc").Find(&categories)
	if result.Error != nil {
		return nil, result.Error
	}
	return categories, nil
}
