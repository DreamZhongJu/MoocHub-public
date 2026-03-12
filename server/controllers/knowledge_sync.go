package controllers

import (
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/utils"
	"strings"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func publishKnowledgeSyncEvent(c *gin.Context, sourceType string, bizID int64, action string, status string, metadata map[string]any) {
	if bizID <= 0 || strings.TrimSpace(sourceType) == "" || strings.TrimSpace(action) == "" {
		return
	}

	payload := mq.KnowledgeSyncPayload{
		SourceType: sourceType,
		BizID:      bizID,
		SourceID:   sourceType + ":" + formatInt64(bizID),
		Action:     action,
		Status:     strings.TrimSpace(status),
		Metadata:   metadata,
	}
	if err := mq.PublishKnowledgeSyncWithTrace(payload, utils.GetTraceID(c)); err != nil {
		global.Log.Warn("publish knowledge sync failed",
			zap.String("trace_id", utils.GetTraceID(c)),
			zap.String("source_type", sourceType),
			zap.Int64("biz_id", bizID),
			zap.String("action", action),
			zap.Error(err),
		)
	}
}

func publishCourseKnowledgeSync(c *gin.Context, course *model.Courses, action string) {
	if course == nil {
		return
	}
	eventAction := normalizeKnowledgeSyncAction(action, course.Status)
	publishKnowledgeSyncEvent(c, model.KnowledgeSourceTypeCourse, course.ID, eventAction, course.Status, map[string]any{
		"category_id":     course.CategoryID,
		"instructor_name": strings.TrimSpace(course.Instructor),
		"level":           strings.TrimSpace(course.Level),
		"updated_at":      course.UpdatedAt,
	})
}

func publishVideoKnowledgeSync(c *gin.Context, video *model.Video, courseStatus string, action string) {
	if video == nil {
		return
	}
	eventAction := normalizeKnowledgeSyncAction(action, courseStatus)
	publishKnowledgeSyncEvent(c, model.KnowledgeSourceTypeVideo, video.ID, eventAction, strings.TrimSpace(courseStatus), map[string]any{
		"course_id":    video.CourseID,
		"duration_sec": video.DurationSec,
		"sort_order":   video.SortOrder,
		"created_at":   video.CreatedAt,
	})
}

func publishArticleKnowledgeSync(c *gin.Context, article *model.Article, action string) {
	if article == nil {
		return
	}
	eventAction := normalizeKnowledgeSyncAction(action, article.Status)
	publishKnowledgeSyncEvent(c, model.KnowledgeSourceTypeArticle, article.ID, eventAction, article.Status, map[string]any{
		"user_id":    article.UserID,
		"updated_at": article.UpdatedAt,
	})
}

func normalizeKnowledgeSyncAction(action string, status string) string {
	action = strings.ToLower(strings.TrimSpace(action))
	if action == mq.KnowledgeSyncActionDelete {
		return mq.KnowledgeSyncActionDelete
	}
	if strings.ToLower(strings.TrimSpace(status)) != "published" {
		return mq.KnowledgeSyncActionDelete
	}
	return mq.KnowledgeSyncActionUpsert
}

func formatInt64(v int64) string {
	return strconvFormatInt(v)
}
