package model

import (
	"MOOCHUB-server/db"
	"strings"
)

func SearchCourses(keyword string, categoryID int64, sort string, page int, pageSize int) ([]Courses, int64, error) {
	kw := strings.TrimSpace(keyword)
	like := "%" + kw + "%"

	query := db.GetDB().
		Model(&Courses{}).
		Where("status = ?", "published").
		Where("(title LIKE ? OR summary LIKE ? OR instructor_name LIKE ?)", like, like, like)

	if categoryID > 0 {
		query = query.Where("category_id = ?", categoryID)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	switch sort {
	case "view_count":
		query = query.Order("view_count DESC")
	case "favorite_count":
		query = query.Order("favorite_count DESC")
	case "created_at":
		query = query.Order("created_at DESC")
	default:
		query = query.Order("view_count DESC").Order("favorite_count DESC").Order("created_at DESC")
	}

	offset := (page - 1) * pageSize
	var items []Courses
	if err := query.Offset(offset).Limit(pageSize).Find(&items).Error; err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func SearchArticles(keyword string, sort string, page int, pageSize int) ([]Article, int64, error) {
	kw := strings.TrimSpace(keyword)
	like := "%" + kw + "%"

	query := db.GetDB().
		Model(&Article{}).
		Where("status = ?", "published").
		Where("(title LIKE ? OR summary LIKE ? OR content LIKE ?)", like, like, like)

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	switch sort {
	case "view_count":
		query = query.Order("view_count DESC")
	case "like_count":
		query = query.Order("like_count DESC")
	case "created_at":
		query = query.Order("created_at DESC")
	default:
		query = query.Order("view_count DESC").Order("like_count DESC").Order("created_at DESC")
	}

	offset := (page - 1) * pageSize
	var items []Article
	if err := query.Offset(offset).Limit(pageSize).Find(&items).Error; err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

func SearchSuggestions(keyword string, limit int) ([]string, error) {
	kw := strings.TrimSpace(keyword)
	if kw == "" {
		return []string{}, nil
	}
	if limit <= 0 {
		limit = 8
	}
	if limit > 20 {
		limit = 20
	}

	like := "%" + kw + "%"
	var courseTitles []string
	var instructors []string
	var articleTitles []string

	if err := db.GetDB().
		Model(&Courses{}).
		Where("status = ?", "published").
		Where("title LIKE ?", like).
		Order("view_count DESC").
		Limit(limit).
		Pluck("title", &courseTitles).Error; err != nil {
		return nil, err
	}

	if err := db.GetDB().
		Model(&Courses{}).
		Where("status = ?", "published").
		Where("instructor_name LIKE ?", like).
		Order("view_count DESC").
		Limit(limit).
		Pluck("instructor_name", &instructors).Error; err != nil {
		return nil, err
	}

	if err := db.GetDB().
		Model(&Article{}).
		Where("status = ?", "published").
		Where("title LIKE ?", like).
		Order("view_count DESC").
		Limit(limit).
		Pluck("title", &articleTitles).Error; err != nil {
		return nil, err
	}

	uniq := make(map[string]struct{}, limit)
	out := make([]string, 0, limit)
	collect := func(list []string) {
		for _, item := range list {
			val := strings.TrimSpace(item)
			if val == "" {
				continue
			}
			if _, ok := uniq[val]; ok {
				continue
			}
			uniq[val] = struct{}{}
			out = append(out, val)
			if len(out) >= limit {
				return
			}
		}
	}

	collect(courseTitles)
	if len(out) < limit {
		collect(instructors)
	}
	if len(out) < limit {
		collect(articleTitles)
	}

	return out, nil
}
