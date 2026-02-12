package controllers

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/model"
	"MOOCHUB-server/notify"
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type PushController struct{}

type PushRequest struct {
	UserID  uint    `json:"user_id"`
	UserIDs []uint  `json:"user_ids"`
	Type    string  `json:"type"`
	Title   string  `json:"title" binding:"required"`
	Content string  `json:"content" binding:"required"`
	Route   string  `json:"route"`
	BizID   *uint64 `json:"biz_id"`
}

func (PushController) Send(c *gin.Context) {
	var req PushRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, http.StatusBadRequest, "参数错误")
		return
	}

	msgType := strings.TrimSpace(req.Type)
	if msgType == "" {
		msgType = "system"
	}

	targets := make([]uint, 0, len(req.UserIDs)+1)
	if req.UserID > 0 {
		targets = append(targets, req.UserID)
	}
	if len(req.UserIDs) > 0 {
		targets = append(targets, req.UserIDs...)
	}
	if len(targets) == 0 {
		ReturnError(c, http.StatusBadRequest, "user_id 或 user_ids 不能为空")
		return
	}
	seen := make(map[uint]struct{}, len(targets))
	uniq := make([]uint, 0, len(targets))
	for _, id := range targets {
		if id == 0 {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		uniq = append(uniq, id)
	}
	if len(uniq) == 0 {
		ReturnError(c, http.StatusBadRequest, "user_id 或 user_ids 不能为空")
		return
	}

	servicePath := config.FCMServiceAccountPath()
	projectID := config.FCMProjectID()
	client, err := notify.NewFCMClient(context.Background(), servicePath, projectID)
	if err != nil {
		ReturnError(c, http.StatusInternalServerError, "FCM未配置："+err.Error())
		return
	}

	sent := 0
	failed := 0

	for _, uid := range uniq {
		msgID, err := model.CreateMessageWithID(uid, msgType, req.Title, req.Content, req.BizID)
		if err != nil {
			failed++
			continue
		}

		tokens, err := model.GetDeviceTokensByUser(uid)
		if err != nil || len(tokens) == 0 {
			failed++
			continue
		}

		data := map[string]string{
			"type":       msgType,
			"message_id": fmt.Sprintf("%d", msgID),
		}
		if req.Route != "" {
			data["route"] = req.Route
		}

		for _, t := range tokens {
			if err := client.SendToToken(context.Background(), t.Token, req.Title, req.Content, data); err == nil {
				sent++
			} else {
				failed++
			}
		}
	}

	ReturnSuccess(c, 200, "发送完成", gin.H{"sent": sent, "failed": failed}, 0)
}
