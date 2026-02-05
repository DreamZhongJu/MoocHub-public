package controllers

import (
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"strconv"

	"github.com/gin-gonic/gin"
)

type FavoriteController struct{}

func (fc FavoriteController) ToggleFavorite(c *gin.Context) {
	courseIDStr := c.PostForm("course_id")
	if courseIDStr == "" {
		ReturnError(c, 400, "course_id不能为空")
		return
	}
	courseID, _ := strconv.ParseInt(courseIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "用户未登录")
		return
	}
	if err := model.ToggleFavoriteCourse(int(uid), courseID); err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) DeleteFavorite(c *gin.Context) {
	courseIDStr := c.Param("id")
	if courseIDStr == "" {
		ReturnError(c, 400, "course_id不能为空")
		return
	}
	courseID, _ := strconv.ParseInt(courseIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "用户未登录")
		return
	}
	if err := model.DeleteFavoriteCourse(int(uid), courseID); err != nil {
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
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "用户未登录")
		return
	}
	if err := model.ToggleFavoriteVideo(int(uid), videoID); err != nil {
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
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "用户未登录")
		return
	}
	if err := model.DeleteFavoriteVideo(int(uid), videoID); err != nil {
		ReturnError(c, 500, "操作失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "操作成功", nil, 0)
}

func (fc FavoriteController) GetFavorites(c *gin.Context) {
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "用户未登录")
		return
	}
	courses, err := model.GetFavoriteCourses(int(uid))
	if err != nil {
		ReturnError(c, 500, "获取收藏课程失败："+err.Error())
		return
	}
	videos, err := model.GetFavoriteVideos(int(uid))
	if err != nil {
		ReturnError(c, 500, "获取收藏视频失败："+err.Error())
		return
	}
	for i := range videos {
		if url, err := storage.ResolveObjectURL(videos[i].VideoURL); err == nil && url != "" {
			videos[i].VideoURL = url
		}
		if url, err := storage.ResolveObjectURL(videos[i].ThumbURL); err == nil && url != "" {
			videos[i].ThumbURL = url
		}
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
		"videos":  videos,
	}, 0)
}
