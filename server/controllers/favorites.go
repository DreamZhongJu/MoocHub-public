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
		ReturnError(c, 400, "course_id is required")
		return
	}
	courseID, _ := strconv.ParseInt(courseIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.ToggleFavoriteCourse(int(uid), courseID); err != nil {
		ReturnError(c, 500, "toggle favorite failed: "+err.Error())
		return
	}
	trackRecommendInteractionForCourse(uid, courseID, "favorite")
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) DeleteFavorite(c *gin.Context) {
	courseIDStr := c.Param("id")
	if courseIDStr == "" {
		ReturnError(c, 400, "course_id is required")
		return
	}
	courseID, _ := strconv.ParseInt(courseIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.DeleteFavoriteCourse(int(uid), courseID); err != nil {
		ReturnError(c, 500, "delete favorite failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) ToggleFavoriteVideo(c *gin.Context) {
	videoIDStr := c.PostForm("video_id")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id is required")
		return
	}
	videoID, _ := strconv.ParseInt(videoIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.ToggleFavoriteVideo(int(uid), videoID); err != nil {
		ReturnError(c, 500, "toggle favorite failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) DeleteFavoriteVideo(c *gin.Context) {
	videoIDStr := c.Param("id")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id is required")
		return
	}
	videoID, _ := strconv.ParseInt(videoIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.DeleteFavoriteVideo(int(uid), videoID); err != nil {
		ReturnError(c, 500, "delete favorite failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) ToggleFavoriteArticle(c *gin.Context) {
	articleIDStr := c.PostForm("article_id")
	if articleIDStr == "" {
		ReturnError(c, 400, "article_id is required")
		return
	}
	articleID, _ := strconv.ParseInt(articleIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.ToggleFavoriteArticle(int(uid), articleID); err != nil {
		ReturnError(c, 500, "toggle favorite failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) DeleteFavoriteArticle(c *gin.Context) {
	articleIDStr := c.Param("id")
	if articleIDStr == "" {
		ReturnError(c, 400, "article_id is required")
		return
	}
	articleID, _ := strconv.ParseInt(articleIDStr, 10, 64)
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	if err := model.DeleteFavoriteArticle(int(uid), articleID); err != nil {
		ReturnError(c, 500, "delete favorite failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", nil, 0)
}

func (fc FavoriteController) GetFavorites(c *gin.Context) {
	userIDVal, _ := c.Get("user_id")
	uid, ok := userIDVal.(int64)
	if !ok {
		ReturnError(c, 401, "unauthorized")
		return
	}
	courses, err := model.GetFavoriteCourses(int(uid))
	if err != nil {
		ReturnError(c, 500, "get favorite courses failed: "+err.Error())
		return
	}
	videos, err := model.GetFavoriteVideos(int(uid))
	if err != nil {
		ReturnError(c, 500, "get favorite videos failed: "+err.Error())
		return
	}
	articles, err := model.GetFavoriteArticles(int(uid))
	if err != nil {
		ReturnError(c, 500, "get favorite articles failed: "+err.Error())
		return
	}
	for i := range videos {
		if url, err := storage.ResolveClientObjectURL(videos[i].VideoURL); err == nil && url != "" {
			videos[i].VideoURL = url
		}
		if url, err := storage.ResolveClientObjectURL(videos[i].ThumbURL); err == nil && url != "" {
			videos[i].ThumbURL = url
		}
	}
	for i := range articles {
		if url, err := storage.ResolveClientObjectURL(articles[i].CoverURL); err == nil && url != "" {
			articles[i].CoverURL = url
		}
	}
	ReturnSuccess(c, 200, "ok", gin.H{
		"courses":  courses,
		"videos":   videos,
		"articles": articles,
	}, 0)
}
