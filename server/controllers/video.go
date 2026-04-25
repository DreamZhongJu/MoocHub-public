package controllers

import (
	"MOOCHUB-server/global"
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type VideoController struct{}

func (vc VideoController) GetVideoDetails(c *gin.Context) {
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
	if url, err := storage.ResolveClientObjectURL(video.VideoURL); err == nil && url != "" {
		video.VideoURL = url
	} else if err != nil {
		global.Log.Error("minio presign video_url failed", zap.Error(err))
	}
	if url, err := storage.ResolveClientObjectURL(video.ThumbURL); err == nil && url != "" {
		video.ThumbURL = url
	} else if err != nil {
		global.Log.Error("minio presign thumb_url failed", zap.Error(err))
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"video": video,
	}, 0)
}
