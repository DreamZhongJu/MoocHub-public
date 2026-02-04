package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type CoursesController struct{}

func (cc CoursesController) GetCourses(c *gin.Context) {
	category_id := c.DefaultQuery("category_id", "0")
	sort := c.DefaultQuery("sort", "default")
	page := c.DefaultQuery("page", "1")
	pageSize := c.DefaultQuery("page_size", "10")

	categoryID, err := strconv.ParseInt(category_id, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid category_id")
		return
	}

	courses, err := model.GetCoursesByCategory(categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程详情失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
	}, 0)
}

func (cc CoursesController) GetCourseDetails(c *gin.Context) {
	id := c.Param("id")
	idInt, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid course id")
		return
	}
	courses, err := model.GetCoursesDetails(idInt)
	if err != nil {
		ReturnError(c, 500, "获取课程详情失败："+err.Error())
		return
	}
	videos, err := model.GetVideosByCourseID(idInt)
	if err != nil {
		ReturnError(c, 500, "获取课程视频失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
		"videos":  videos,
	}, 0)
}

func (cc CoursesController) GetCoursesByCategoryID(c *gin.Context) {
	categoryIDStr := c.Param("id")
	sort := c.DefaultQuery("sort", "default")
	page := c.DefaultQuery("page", "1")
	pageSize := c.DefaultQuery("page_size", "10")

	categoryID, err := strconv.ParseInt(categoryIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid category id")
		return
	}

	courses, err := model.GetCoursesByCategory(categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程详情失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
	}, 0)
}
