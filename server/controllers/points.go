package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type PointsController struct{}

func (pc PointsController) GetBalance(c *gin.Context) {
	userID := c.GetInt64("user_id")
	balance, err := model.GetUserPointsBalance(uint(userID))
	if err != nil {
		ReturnError(c, 500, "get points failed: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{
		"points_balance": balance,
	}, 0)
}

func (pc PointsController) GetTransactions(c *gin.Context) {
	userID := c.GetInt64("user_id")
	pageStr := c.DefaultQuery("page", "1")
	sizeStr := c.DefaultQuery("page_size", "10")
	eventType := c.DefaultQuery("event_type", "")

	page, err := strconv.Atoi(pageStr)
	if err != nil || page <= 0 {
		ReturnError(c, 400, "invalid page")
		return
	}
	size, err := strconv.Atoi(sizeStr)
	if err != nil || size <= 0 {
		ReturnError(c, 400, "invalid page_size")
		return
	}

	items, total, err := model.GetPointsTransactions(uint(userID), page, size, eventType)
	if err != nil {
		ReturnError(c, 500, "get transactions failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"items": items,
		"page":  page,
		"size":  size,
		"total": total,
	}, 0)
}

func (pc PointsController) GetRank(c *gin.Context) {
	pageStr := c.DefaultQuery("page", "1")
	sizeStr := c.DefaultQuery("page_size", "20")

	page, err := strconv.Atoi(pageStr)
	if err != nil || page <= 0 {
		ReturnError(c, 400, "invalid page")
		return
	}
	size, err := strconv.Atoi(sizeStr)
	if err != nil || size <= 0 {
		ReturnError(c, 400, "invalid page_size")
		return
	}

	items, total, err := model.GetPointsRank(page, size)
	if err != nil {
		ReturnError(c, 500, "get rank failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"items": items,
		"page":  page,
		"size":  size,
		"total": total,
	}, 0)
}

func (pc PointsController) AwardPoints(c *gin.Context) {
	userIDStr := c.DefaultPostForm("user_id", "")
	eventType := c.DefaultPostForm("event_type", "")
	pointsStr := c.DefaultPostForm("points", "")
	bizIDStr := c.DefaultPostForm("biz_id", "")
	remark := c.DefaultPostForm("remark", "")

	if userIDStr == "" || eventType == "" || pointsStr == "" {
		ReturnError(c, 400, "missing params")
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil || userID == 0 {
		ReturnError(c, 400, "invalid user_id")
		return
	}
	points, err := strconv.Atoi(pointsStr)
	if err != nil || points == 0 {
		ReturnError(c, 400, "invalid points")
		return
	}

	var bizID *uint64
	if bizIDStr != "" {
		if v, err := strconv.ParseUint(bizIDStr, 10, 64); err == nil {
			bizID = &v
		}
	}

	if err := model.AwardPoints(uint(userID), eventType, points, bizID, remark); err != nil {
		ReturnError(c, 500, "award points failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", nil, 0)
}
