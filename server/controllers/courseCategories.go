package controllers

import (
	"MOOCHUB-server/model"

	"github.com/gin-gonic/gin"
)

type CourseCategoriesController struct{}

func (ccc CourseCategoriesController) GetCategories(c *gin.Context) {
	categories, err := model.GetAllCourseCategories()
	if err != nil {
		ReturnError(c, 500, "获取课程分类失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"categories": categories,
	}, 0)
}
