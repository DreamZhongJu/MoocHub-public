package controllers

import (
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"MOOCHUB-server/utils"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type RecommendController struct{}

func (rc RecommendController) GetCourseFeed(c *gin.Context) {
	page, pageSize, err := parsePageAndSize(c.DefaultQuery("page", "1"), c.DefaultQuery("page_size", "10"), maxCoursePageSize)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}
	seed, _ := strconv.ParseInt(strings.TrimSpace(c.DefaultQuery("seed", "0")), 10, 64)

	userID := parseOptionalRecommendUserID(c)
	courseIDs, topCategories, err := model.BuildMinimalPersonalizedCourseIDs(userID, page, pageSize, seed)
	if err != nil {
		ReturnError(c, 500, "get recommend feed failed: "+err.Error())
		return
	}

	courses, err := model.GetCoursesByIDsPreserveOrder(courseIDs)
	if err != nil {
		ReturnError(c, 500, "load recommended courses failed: "+err.Error())
		return
	}
	for i := range courses {
		if url, resolveErr := storage.ResolveClientObjectURL(courses[i].CoverURL); resolveErr == nil && url != "" {
			courses[i].CoverURL = url
		}
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"courses": courses,
		"strategy": gin.H{
			"name":              "minimal_rule_recommend_v1",
			"personal_ratio":    70,
			"popular_ratio":     30,
			"user_id":           userID,
			"top_category_ids":  topCategories,
			"popular_window_7d": true,
			"recent_window_24h": true,
			"seed":              seed,
		},
	}, int64(len(courses)))
}

func parseOptionalRecommendUserID(c *gin.Context) int64 {
	authHeader := strings.TrimSpace(c.GetHeader("Authorization"))
	if authHeader == "" {
		return 0
	}
	claims, err := utils.ParseToken(authHeader)
	if err != nil {
		return 0
	}
	return int64(claims.UserID)
}

func trackRecommendInteractionForCourse(userID int64, courseID int64, action string) {
	if userID <= 0 || courseID <= 0 {
		return
	}
	_ = model.RecordRecommendInteraction(userID, courseID, action)
}

func trackRecommendInteractionForCourseForm(c *gin.Context, userID int64, key string, action string) {
	value := strings.TrimSpace(c.PostForm(key))
	if value == "" {
		return
	}
	id, err := strconv.ParseInt(value, 10, 64)
	if err != nil || id <= 0 {
		return
	}
	trackRecommendInteractionForCourse(userID, id, action)
}
