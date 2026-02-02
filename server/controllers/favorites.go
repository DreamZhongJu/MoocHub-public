package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type FavoriteController struct{}

func (fc FavoriteController) ToggleFavorite(c *gin.Context) {
	course_iD := c.PostForm("course_id")
	if course_iD == "" {
		ReturnError(c, 400, "course_id不能为空")
		return
	}
	courseID, _ := strconv.ParseInt(course_iD, 10, 64)
	userId := c.GetInt("user_id")
	err := model.ToggleFavoriteCourse(userId, courseID)
	if err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) DeleteFavorite(c *gin.Context) {
	course_iD := c.Param("id")
	if course_iD == "" {
		ReturnError(c, 400, "course_id不能为空")
		return
	}
	courseID, _ := strconv.ParseInt(course_iD, 10, 64)
	userId := c.GetInt("user_id")
	err := model.DeleteFavoriteCourse(userId, courseID)
	if err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) ToggleFavoriteVideo(c *gin.Context) {
	videoIDStr := c.PostForm("video_id")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id不能为空")
		return
	}
	videoID, _ := strconv.ParseInt(videoIDStr, 10, 64)
	userID := c.GetInt("user_id")
	err := model.ToggleFavoriteVideo(userID, videoID)
	if err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) DeleteFavoriteVideo(c *gin.Context) {
	videoIDStr := c.Param("id")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id不能为空")
		return
	}
	videoID, _ := strconv.ParseInt(videoIDStr, 10, 64)
	userID := c.GetInt("user_id")
	err := model.DeleteFavoriteVideo(userID, videoID)
	if err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) GetFavorites(c *gin.Context) {
	userID := c.GetInt("user_id")
	courses, err := model.GetFavoriteCourses(userID)
	if err != nil {
		ReturnError(c, 500, "获取收藏课程失败："+err.Error())
		return
	}
	videos, err := model.GetFavoriteVideos(userID)
	if err != nil {
		ReturnError(c, 500, "获取收藏视频失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
		"videos":  videos,
	}, 0)
}
