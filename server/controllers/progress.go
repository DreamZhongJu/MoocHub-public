package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type ProgressController struct{}

func (pc ProgressController) UpsertProgress(c *gin.Context) {
	videoIDStr := c.DefaultPostForm("video_id", "")
	lastPosStr := c.DefaultPostForm("last_position_sec", "0")
	progressStr := c.DefaultPostForm("progress_percent", "0")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id不能为空")
		return
	}
	videoID, err := strconv.ParseInt(videoIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "video_id不合法")
		return
	}
	lastPos, err := strconv.Atoi(lastPosStr)
	if err != nil {
		ReturnError(c, 400, "last_position_sec不合法")
		return
	}
	progress, err := strconv.ParseFloat(progressStr, 64)
	if err != nil {
		ReturnError(c, 400, "progress_percent不合法")
		return
	}

	userID := c.GetInt64("user_id")
	if err := model.UpsertLearningProgress(userID, videoID, lastPos, progress); err != nil {
		ReturnError(c, 500, "更新失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "更新成功", nil, 0)
}

func (pc ProgressController) GetProgress(c *gin.Context) {
	videoIDStr := c.Param("video_id")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id不能为空")
		return
	}
	videoID, err := strconv.ParseInt(videoIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "video_id不合法")
		return
	}
	userID := c.GetInt64("user_id")
	progress, err := model.GetLearningProgress(userID, videoID)
	if err != nil {
		ReturnError(c, 500, "获取失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"last_position_sec": progress.LastPositionSec,
		"progress_percent":  progress.ProgressPercent,
	}, 0)
}

func (pc ProgressController) GetLatestProgress(c *gin.Context) {
	userID := c.GetInt64("user_id")
	progress, video, err := model.GetLatestLearningProgress(userID)
	if err != nil {
		ReturnError(c, 500, "获取失败："+err.Error())
		return
	}
	if progress == nil || video == nil {
		ReturnSuccess(c, 200, "暂无进度", gin.H{}, 0)
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"progress": gin.H{
			"last_position_sec": progress.LastPositionSec,
			"progress_percent":  progress.ProgressPercent,
		},
		"video": video,
	}, 0)
}
