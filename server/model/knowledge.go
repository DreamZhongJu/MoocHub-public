package model

import (
	"MOOCHUB-server/db"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

const (
	KnowledgeSourceTypeCourse  = "course"
	KnowledgeSourceTypeVideo   = "video"
	KnowledgeSourceTypeArticle = "article"
)

type KnowledgeSource struct {
	SourceID   string         `json:"source_id"`
	SourceType string         `json:"source_type"`
	BizID      int64          `json:"biz_id"`
	Title      string         `json:"title"`
	Summary    string         `json:"summary,omitempty"`
	Content    string         `json:"content"`
	Tags       []string       `json:"tags"`
	SourceURL  string         `json:"source_url"`
	Status     string         `json:"status"`
	UpdatedAt  time.Time      `json:"updated_at"`
	Metadata   map[string]any `json:"metadata,omitempty"`
}

func ListKnowledgeSources(sourceType string, page, pageSize int, status string) ([]KnowledgeSource, error) {
	switch normalizeKnowledgeSourceType(sourceType) {
	case KnowledgeSourceTypeCourse:
		return listCourseKnowledgeSources(page, pageSize, status)
	case KnowledgeSourceTypeVideo:
		return listVideoKnowledgeSources(page, pageSize, status)
	case KnowledgeSourceTypeArticle:
		return listArticleKnowledgeSources(page, pageSize, status)
	default:
		return nil, fmt.Errorf("unsupported knowledge source type: %s", sourceType)
	}
}

func GetKnowledgeSourceByID(sourceType string, id int64, status string) (*KnowledgeSource, error) {
	switch normalizeKnowledgeSourceType(sourceType) {
	case KnowledgeSourceTypeCourse:
		return getCourseKnowledgeSourceByID(id, status)
	case KnowledgeSourceTypeVideo:
		return getVideoKnowledgeSourceByID(id, status)
	case KnowledgeSourceTypeArticle:
		return getArticleKnowledgeSourceByID(id, status)
	default:
		return nil, fmt.Errorf("unsupported knowledge source type: %s", sourceType)
	}
}

func normalizeKnowledgeSourceType(sourceType string) string {
	return strings.ToLower(strings.TrimSpace(sourceType))
}

func listCourseKnowledgeSources(page, pageSize int, status string) ([]KnowledgeSource, error) {
	courses := make([]Courses, 0, pageSize)
	dbq := db.GetDB().Model(&Courses{})
	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("status = ?", status)
	}

	if err := dbq.Order("updated_at DESC").Order("id DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&courses).Error; err != nil {
		return nil, err
	}

	categoryNames, err := loadCategoryNameMap()
	if err != nil {
		return nil, err
	}

	items := make([]KnowledgeSource, 0, len(courses))
	for _, course := range courses {
		items = append(items, buildCourseKnowledgeSource(course, categoryNames[course.CategoryID]))
	}
	return items, nil
}

func getCourseKnowledgeSourceByID(id int64, status string) (*KnowledgeSource, error) {
	var course Courses
	dbq := db.GetDB().Model(&Courses{}).Where("id = ?", id)
	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("status = ?", status)
	}
	if err := dbq.First(&course).Error; err != nil {
		return nil, err
	}

	categoryNames, err := loadCategoryNameMap()
	if err != nil {
		return nil, err
	}
	item := buildCourseKnowledgeSource(course, categoryNames[course.CategoryID])
	return &item, nil
}

type knowledgeVideoRow struct {
	ID            int64     `gorm:"column:id"`
	CourseID      int64     `gorm:"column:course_id"`
	Title         string    `gorm:"column:title"`
	Description   string    `gorm:"column:description"`
	DurationSec   int       `gorm:"column:duration_sec"`
	VideoURL      string    `gorm:"column:video_url"`
	ThumbURL      string    `gorm:"column:thumb_url"`
	SortOrder     int       `gorm:"column:sort_order"`
	CreatedAt     time.Time `gorm:"column:created_at"`
	CourseTitle   string    `gorm:"column:course_title"`
	CourseStatus  string    `gorm:"column:course_status"`
	CourseLevel   string    `gorm:"column:course_level"`
	Instructor    string    `gorm:"column:instructor_name"`
	CourseSummary string    `gorm:"column:course_summary"`
}

func listVideoKnowledgeSources(page, pageSize int, status string) ([]KnowledgeSource, error) {
	rows := make([]knowledgeVideoRow, 0, pageSize)
	dbq := db.GetDB().Table("videos AS v").
		Select(
			"v.id, v.course_id, v.title, v.description, v.duration_sec, v.video_url, v.thumb_url, v.sort_order, v.created_at, " +
				"c.title AS course_title, c.status AS course_status, c.level AS course_level, c.instructor_name, c.summary AS course_summary",
		).
		Joins("JOIN courses c ON c.id = v.course_id")

	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("c.status = ?", status)
	}

	if err := dbq.Order("v.created_at DESC").Order("v.id DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Scan(&rows).Error; err != nil {
		return nil, err
	}

	items := make([]KnowledgeSource, 0, len(rows))
	for _, row := range rows {
		items = append(items, buildVideoKnowledgeSource(row))
	}
	return items, nil
}

func getVideoKnowledgeSourceByID(id int64, status string) (*KnowledgeSource, error) {
	var row knowledgeVideoRow
	dbq := db.GetDB().Table("videos AS v").
		Select(
			"v.id, v.course_id, v.title, v.description, v.duration_sec, v.video_url, v.thumb_url, v.sort_order, v.created_at, "+
				"c.title AS course_title, c.status AS course_status, c.level AS course_level, c.instructor_name, c.summary AS course_summary",
		).
		Joins("JOIN courses c ON c.id = v.course_id").
		Where("v.id = ?", id)

	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("c.status = ?", status)
	}

	if err := dbq.Take(&row).Error; err != nil {
		return nil, err
	}

	item := buildVideoKnowledgeSource(row)
	return &item, nil
}

func listArticleKnowledgeSources(page, pageSize int, status string) ([]KnowledgeSource, error) {
	articles := make([]Article, 0, pageSize)
	dbq := db.GetDB().Model(&Article{})
	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("status = ?", status)
	}

	if err := dbq.Order("updated_at DESC").Order("id DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&articles).Error; err != nil {
		return nil, err
	}

	items := make([]KnowledgeSource, 0, len(articles))
	for _, article := range articles {
		items = append(items, buildArticleKnowledgeSource(article))
	}
	return items, nil
}

func getArticleKnowledgeSourceByID(id int64, status string) (*KnowledgeSource, error) {
	var article Article
	dbq := db.GetDB().Model(&Article{}).Where("id = ?", id)
	if strings.TrimSpace(status) != "" {
		dbq = dbq.Where("status = ?", status)
	}
	if err := dbq.First(&article).Error; err != nil {
		return nil, err
	}

	item := buildArticleKnowledgeSource(article)
	return &item, nil
}

func loadCategoryNameMap() (map[int64]string, error) {
	categories, err := GetAllCourseCategories()
	if err != nil {
		return nil, err
	}
	result := make(map[int64]string, len(categories))
	for _, category := range categories {
		result[category.ID] = strings.TrimSpace(category.Name)
	}
	return result, nil
}

func buildCourseKnowledgeSource(course Courses, categoryName string) KnowledgeSource {
	tags := make([]string, 0, 4)
	if strings.TrimSpace(categoryName) != "" {
		tags = append(tags, "category:"+strings.TrimSpace(categoryName))
	}
	if strings.TrimSpace(course.Level) != "" {
		tags = append(tags, "level:"+strings.TrimSpace(course.Level))
	}
	if strings.TrimSpace(course.Instructor) != "" {
		tags = append(tags, "instructor:"+strings.TrimSpace(course.Instructor))
	}

	contentParts := []string{strings.TrimSpace(course.Title), strings.TrimSpace(course.Summary)}
	return KnowledgeSource{
		SourceID:   fmt.Sprintf("%s:%d", KnowledgeSourceTypeCourse, course.ID),
		SourceType: KnowledgeSourceTypeCourse,
		BizID:      course.ID,
		Title:      strings.TrimSpace(course.Title),
		Summary:    strings.TrimSpace(course.Summary),
		Content:    joinKnowledgeContent(contentParts...),
		Tags:       tags,
		SourceURL:  fmt.Sprintf("/api/v1/courses/%d", course.ID),
		Status:     course.Status,
		UpdatedAt:  course.UpdatedAt,
		Metadata: map[string]any{
			"category_id":     course.CategoryID,
			"category_name":   strings.TrimSpace(categoryName),
			"instructor_name": strings.TrimSpace(course.Instructor),
			"level":           strings.TrimSpace(course.Level),
			"cover_url":       strings.TrimSpace(course.CoverURL),
		},
	}
}

func buildVideoKnowledgeSource(row knowledgeVideoRow) KnowledgeSource {
	tags := make([]string, 0, 4)
	if strings.TrimSpace(row.CourseTitle) != "" {
		tags = append(tags, "course:"+strings.TrimSpace(row.CourseTitle))
	}
	if strings.TrimSpace(row.CourseLevel) != "" {
		tags = append(tags, "level:"+strings.TrimSpace(row.CourseLevel))
	}
	if strings.TrimSpace(row.Instructor) != "" {
		tags = append(tags, "instructor:"+strings.TrimSpace(row.Instructor))
	}

	contentParts := []string{
		strings.TrimSpace(row.CourseTitle),
		strings.TrimSpace(row.CourseSummary),
		strings.TrimSpace(row.Title),
		strings.TrimSpace(row.Description),
	}
	return KnowledgeSource{
		SourceID:   fmt.Sprintf("%s:%d", KnowledgeSourceTypeVideo, row.ID),
		SourceType: KnowledgeSourceTypeVideo,
		BizID:      row.ID,
		Title:      strings.TrimSpace(row.Title),
		Summary:    strings.TrimSpace(row.Description),
		Content:    joinKnowledgeContent(contentParts...),
		Tags:       tags,
		SourceURL:  fmt.Sprintf("/api/v1/videos/%d", row.ID),
		Status:     row.CourseStatus,
		UpdatedAt:  row.CreatedAt,
		Metadata: map[string]any{
			"course_id":       row.CourseID,
			"course_title":    strings.TrimSpace(row.CourseTitle),
			"duration_sec":    row.DurationSec,
			"sort_order":      row.SortOrder,
			"video_url":       strings.TrimSpace(row.VideoURL),
			"thumb_url":       strings.TrimSpace(row.ThumbURL),
			"instructor_name": strings.TrimSpace(row.Instructor),
		},
	}
}

func buildArticleKnowledgeSource(article Article) KnowledgeSource {
	tags := []string{fmt.Sprintf("author_id:%d", article.UserID)}
	contentParts := []string{
		strings.TrimSpace(article.Title),
		strings.TrimSpace(article.Summary),
		strings.TrimSpace(article.Content),
	}
	return KnowledgeSource{
		SourceID:   fmt.Sprintf("%s:%d", KnowledgeSourceTypeArticle, article.ID),
		SourceType: KnowledgeSourceTypeArticle,
		BizID:      article.ID,
		Title:      strings.TrimSpace(article.Title),
		Summary:    strings.TrimSpace(article.Summary),
		Content:    joinKnowledgeContent(contentParts...),
		Tags:       tags,
		SourceURL:  fmt.Sprintf("/api/v1/articles/%d", article.ID),
		Status:     article.Status,
		UpdatedAt:  article.UpdatedAt,
		Metadata: map[string]any{
			"user_id":    article.UserID,
			"cover_url":  strings.TrimSpace(article.CoverURL),
			"view_count": article.ViewCount,
			"like_count": article.LikeCount,
		},
	}
}

func joinKnowledgeContent(parts ...string) string {
	filtered := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		filtered = append(filtered, part)
	}
	return strings.Join(filtered, "\n\n")
}

func IsKnowledgeSourceNotFound(err error) bool {
	return errors.Is(err, gorm.ErrRecordNotFound)
}
