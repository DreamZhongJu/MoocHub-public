package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type MessageController struct{}

func (mc MessageController) GetMessages(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "用户未登录")
		return
	}

	msgType := c.DefaultQuery("type", "")
	pageStr := c.DefaultQuery("page", "1")
	pageSizeStr := c.DefaultQuery("page_size", "20")

	page, err := strconv.Atoi(pageStr)
	if err != nil || page <= 0 {
		ReturnError(c, 400, "invalid page")
		return
	}
	pageSize, err := strconv.Atoi(pageSizeStr)
	if err != nil || pageSize <= 0 {
		ReturnError(c, 400, "invalid page_size")
		return
	}

	items, total, err := model.GetMessages(uint(userID), msgType, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取消息失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"items": items,
		"page":  page,
		"size":  pageSize,
		"total": total,
	}, total)
}

func (mc MessageController) GetUnreadCount(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "用户未登录")
		return
	}

	msgType := c.DefaultQuery("type", "")
	count, err := model.GetUnreadCount(uint(userID), msgType)
	if err != nil {
		ReturnError(c, 500, "获取未读数失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{
		"unread_count": count,
	}, 0)
}

type markReadReq struct {
	IDs  []uint64 `json:"ids"`
	Type string   `json:"type"`
	All  bool     `json:"all"`
}

func (mc MessageController) MarkRead(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "用户未登录")
		return
	}

	var req markReadReq
	_ = c.ShouldBindJSON(&req)

	var updated int64
	var err error

	switch {
	case req.All:
		updated, err = model.MarkReadAll(uint(userID))
	case req.Type != "":
		updated, err = model.MarkReadByType(uint(userID), req.Type)
	case len(req.IDs) > 0:
		updated, err = model.MarkReadByIDs(uint(userID), req.IDs)
	default:
		ReturnError(c, 400, "缺少参数")
		return
	}

	if err != nil {
		ReturnError(c, 500, "标记已读失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{
		"updated": updated,
	}, 0)
}

type awardMessageReq struct {
	UserID  uint    `json:"user_id"`
	Type    string  `json:"type"`
	Title   string  `json:"title"`
	Content string  `json:"content"`
	BizID   *uint64 `json:"biz_id"`
}

// AwardMessage creates a message via internal call.
func (mc MessageController) AwardMessage(c *gin.Context) {
	var req awardMessageReq
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	if req.UserID == 0 || req.Type == "" || req.Title == "" || req.Content == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}

	if err := model.CreateMessage(req.UserID, req.Type, req.Title, req.Content, req.BizID); err != nil {
		ReturnError(c, 500, "创建消息失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{}, 0)
}
