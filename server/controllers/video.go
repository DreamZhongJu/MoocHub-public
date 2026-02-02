package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type VideoController struct{}

func (vc VideoController) GetVideoDetails(c *gin.Context) {
	// Implementation for getting video details goes here
	id := c.Param("id")
	idInt, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid video id")
		return
	}
	video, err := model.GetVideoDetails(idInt)
	if err != nil {
		ReturnError(c, 500, "获取视频详情失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"video": video,
	}, 0)
}
