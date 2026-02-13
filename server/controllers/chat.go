package controllers

import (
	"MOOCHUB-server/model"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type ChatController struct{}

type createPrivateConversationReq struct {
	TargetUserID uint64 `json:"target_user_id"`
}

type createGroupConversationReq struct {
	Name      string   `json:"name"`
	AvatarURL string   `json:"avatar_url"`
	MemberIDs []uint64 `json:"member_ids"`
}

type addGroupMembersReq struct {
	UserIDs []uint64 `json:"user_ids"`
}

type sendChatMessageReq struct {
	ConversationID uint64 `json:"conversation_id"`
	MsgType        string `json:"msg_type"`
	Content        string `json:"content"`
	ExtraJSON      string `json:"extra_json"`
}

type markChatReadReq struct {
	ConversationID uint64 `json:"conversation_id"`
	LastMessageID  uint64 `json:"last_message_id"`
}

func (cc ChatController) GetConversations(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 20
	}

	items, total, err := model.GetConversationList(uint64(userID), page, pageSize)
	if err != nil {
		ReturnError(c, 500, "failed to get conversations: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"items": items,
		"page":  page,
		"size":  pageSize,
		"total": total,
	}, total)
}

func (cc ChatController) CreatePrivateConversation(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	var req createPrivateConversationReq
	if err := c.ShouldBindJSON(&req); err != nil || req.TargetUserID == 0 {
		ReturnError(c, 400, "target_user_id is required")
		return
	}

	conv, err := model.CreateOrGetPrivateConversation(uint64(userID), req.TargetUserID)
	if err != nil {
		ReturnError(c, 400, "failed to create private conversation: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", conv, 0)
}

func (cc ChatController) CreateGroupConversation(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	var req createGroupConversationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, 400, "invalid request")
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		ReturnError(c, 400, "name is required")
		return
	}

	conv, err := model.CreateGroupConversation(uint64(userID), req.Name, req.AvatarURL, req.MemberIDs)
	if err != nil {
		ReturnError(c, 500, "failed to create group: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", conv, 0)
}

func (cc ChatController) AddGroupMembers(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}
	conversationID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || conversationID == 0 {
		ReturnError(c, 400, "invalid conversation id")
		return
	}

	var req addGroupMembersReq
	if err := c.ShouldBindJSON(&req); err != nil || len(req.UserIDs) == 0 {
		ReturnError(c, 400, "user_ids is required")
		return
	}

	if err := model.AddGroupMembers(conversationID, uint64(userID), req.UserIDs); err != nil {
		ReturnError(c, 500, "failed to add members: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{}, 0)
}

func (cc ChatController) GetMessages(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	conversationID, err := strconv.ParseUint(c.DefaultQuery("conversation_id", "0"), 10, 64)
	if err != nil || conversationID == 0 {
		ReturnError(c, 400, "conversation_id is required")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 20
	}

	items, total, err := model.GetConversationMessages(conversationID, uint64(userID), page, pageSize)
	if err != nil {
		ReturnError(c, 500, "failed to get messages: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"items":           items,
		"conversation_id": conversationID,
		"page":            page,
		"size":            pageSize,
		"total":           total,
	}, total)
}

func (cc ChatController) SendMessage(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	var req sendChatMessageReq
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, 400, "invalid request")
		return
	}
	if req.ConversationID == 0 {
		ReturnError(c, 400, "conversation_id is required")
		return
	}
	req.Content = strings.TrimSpace(req.Content)
	if req.Content == "" {
		ReturnError(c, 400, "content is required")
		return
	}

	msg, err := model.CreateChatMessage(req.ConversationID, uint64(userID), req.MsgType, req.Content, req.ExtraJSON)
	if err != nil {
		ReturnError(c, 500, "failed to send message: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", msg, 0)
}

func (cc ChatController) MarkRead(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}

	var req markChatReadReq
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, 400, "invalid request")
		return
	}
	if req.ConversationID == 0 {
		ReturnError(c, 400, "conversation_id is required")
		return
	}

	if err := model.MarkConversationRead(req.ConversationID, uint64(userID), req.LastMessageID); err != nil {
		ReturnError(c, 500, "failed to mark read: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{}, 0)
}

func (cc ChatController) GetUnreadCount(c *gin.Context) {
	userID := c.GetInt64("user_id")
	if userID <= 0 {
		ReturnError(c, 401, "unauthorized")
		return
	}
	count, err := model.GetChatUnreadCount(uint64(userID))
	if err != nil {
		ReturnError(c, 500, "failed to get unread count: "+err.Error())
		return
	}
	ReturnSuccess(c, 200, "ok", gin.H{"unread_count": count}, 0)
}
