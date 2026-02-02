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
