package controllers

import (
	"MOOCHUB-server/model"
	"net/http"

	"github.com/gin-gonic/gin"
)

type DeviceTokenController struct{}

type DeviceTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform"`
}

func (DeviceTokenController) Register(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, http.StatusUnauthorized, "未登录")
		return
	}

	var req DeviceTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, http.StatusBadRequest, "参数错误")
		return
	}

	if req.Platform == "" {
		req.Platform = "android"
	}

	if err := model.UpsertDeviceToken(uint(userID), req.Platform, req.Token); err != nil {
		ReturnError(c, http.StatusInternalServerError, "保存失败: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "保存成功", gin.H{"token": req.Token}, 0)
}
