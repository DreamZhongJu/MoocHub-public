package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"context"
	"time"

	"github.com/gin-gonic/gin"
)

type CourseCategoriesController struct{}

func (ccc CourseCategoriesController) GetCategories(c *gin.Context) {
	categories := make([]model.CourseCategory, 0)
	_, _, err := cache.FillJSONWithHotKey(
		c.Request.Context(),
		"categories:list",
		&categories,
		func(ctx context.Context) (interface{}, error) {
			return model.GetAllCourseCategories()
		},
		cache.CacheLoadOptions{
			TTL:      5 * time.Minute,
			StaleTTL: 30 * time.Minute,
		},
	)
	if err != nil {
		ReturnError(c, 500, "获取课程分类失败: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "获取成功", gin.H{
		"categories": categories,
	}, 0)
}
