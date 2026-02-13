package model

import (
	"MOOCHUB-server/db"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

const (
	ChatConversationTypePrivate = "private"
	ChatConversationTypeGroup   = "group"
	ChatMessageTypeText         = "text"
)

type ChatConversation struct {
	ID            uint64     `gorm:"column:id;primaryKey" json:"id"`
	Type          string     `gorm:"column:type" json:"type"`
	Name          string     `gorm:"column:name" json:"name"`
	AvatarURL     string     `gorm:"column:avatar_url" json:"avatar_url"`
	PrivateKey    *string    `gorm:"column:private_key" json:"private_key"`
	CreatorID     uint64     `gorm:"column:creator_id" json:"creator_id"`
	LastMessage   string     `gorm:"column:last_message" json:"last_message"`
	LastMessageAt *time.Time `gorm:"column:last_message_at" json:"last_message_at"`
	CreatedAt     time.Time  `gorm:"column:created_at" json:"created_at"`
	UpdatedAt     time.Time  `gorm:"column:updated_at" json:"updated_at"`
	IsDeleted     bool       `gorm:"column:is_deleted" json:"is_deleted"`
}

func (ChatConversation) TableName() string {
	return "chat_conversations"
}

type ChatConversationMember struct {
	ID                uint64     `gorm:"column:id;primaryKey" json:"id"`
	ConversationID    uint64     `gorm:"column:conversation_id" json:"conversation_id"`
	UserID            uint64     `gorm:"column:user_id" json:"user_id"`
	Role              string     `gorm:"column:role" json:"role"`
	LastReadMessageID uint64     `gorm:"column:last_read_message_id" json:"last_read_message_id"`
	LastReadAt        *time.Time `gorm:"column:last_read_at" json:"last_read_at"`
	JoinedAt          time.Time  `gorm:"column:joined_at" json:"joined_at"`
	IsDeleted         bool       `gorm:"column:is_deleted" json:"is_deleted"`
	CreatedAt         time.Time  `gorm:"column:created_at" json:"created_at"`
	UpdatedAt         time.Time  `gorm:"column:updated_at" json:"updated_at"`
}

func (ChatConversationMember) TableName() string {
	return "chat_conversation_members"
}

type ChatMessage struct {
	ID             uint64    `gorm:"column:id;primaryKey" json:"id"`
	ConversationID uint64    `gorm:"column:conversation_id" json:"conversation_id"`
	SenderID       uint64    `gorm:"column:sender_id" json:"sender_id"`
	MsgType        string    `gorm:"column:msg_type" json:"msg_type"`
	Content        string    `gorm:"column:content" json:"content"`
	ExtraJSON      string    `gorm:"column:extra_json" json:"extra_json"`
	CreatedAt      time.Time `gorm:"column:created_at" json:"created_at"`
	IsDeleted      bool      `gorm:"column:is_deleted" json:"is_deleted"`
}

func (ChatMessage) TableName() string {
	return "chat_messages"
}

type ConversationListItem struct {
	ID            uint64     `json:"id"`
	Type          string     `json:"type"`
	Name          string     `json:"name"`
	AvatarURL     string     `json:"avatar_url"`
	LastMessage   string     `json:"last_message"`
	LastMessageAt *time.Time `json:"last_message_at"`
	UnreadCount   int64      `json:"unread_count"`
}

type ChatMessageItem struct {
	ID             uint64    `json:"id"`
	ConversationID uint64    `json:"conversation_id"`
	SenderID       uint64    `json:"sender_id"`
	SenderName     string    `json:"sender_name"`
	SenderAvatar   string    `json:"sender_avatar"`
	MsgType        string    `json:"msg_type"`
	Content        string    `json:"content"`
	ExtraJSON      string    `json:"extra_json"`
	CreatedAt      time.Time `json:"created_at"`
}

func privateConversationKey(userA, userB uint64) string {
	if userA < userB {
		return fmt.Sprintf("%d:%d", userA, userB)
	}
	return fmt.Sprintf("%d:%d", userB, userA)
}

func upsertConversationMemberTx(tx *gorm.DB, conversationID, userID uint64, role string) error {
	var item ChatConversationMember
	err := tx.Where("conversation_id = ? AND user_id = ?", conversationID, userID).First(&item).Error
	if err == nil {
		updates := map[string]any{
			"is_deleted": false,
		}
		if role != "" && item.Role != role {
			updates["role"] = role
		}
		return tx.Model(&item).Updates(updates).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	now := time.Now()
	member := ChatConversationMember{
		ConversationID: conversationID,
		UserID:         userID,
		Role:           role,
		JoinedAt:       now,
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	return tx.Create(&member).Error
}

func IsConversationMember(conversationID, userID uint64) (bool, error) {
	var count int64
	err := db.GetDB().
		Model(&ChatConversationMember{}).
		Where("conversation_id = ? AND user_id = ? AND is_deleted = 0", conversationID, userID).
		Count(&count).Error
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func GetConversationByID(conversationID uint64) (*ChatConversation, error) {
	var item ChatConversation
	err := db.GetDB().Where("id = ? AND is_deleted = 0", conversationID).First(&item).Error
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func CreateOrGetPrivateConversation(userID, targetUserID uint64) (*ChatConversation, error) {
	if userID == 0 || targetUserID == 0 {
		return nil, errors.New("invalid user id")
	}
	if userID == targetUserID {
		return nil, errors.New("cannot chat with self")
	}

	key := privateConversationKey(userID, targetUserID)
	dbConn := db.GetDB()

	var existing ChatConversation
	if err := dbConn.Where("private_key = ? AND is_deleted = 0", key).First(&existing).Error; err == nil {
		if err := dbConn.Transaction(func(tx *gorm.DB) error {
			if err := upsertConversationMemberTx(tx, existing.ID, userID, "member"); err != nil {
				return err
			}
			return upsertConversationMemberTx(tx, existing.ID, targetUserID, "member")
		}); err != nil {
			return nil, err
		}
		return &existing, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	var created ChatConversation
	err := dbConn.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		created = ChatConversation{
			Type:       ChatConversationTypePrivate,
			PrivateKey: &key,
			CreatorID:  userID,
			CreatedAt:  now,
			UpdatedAt:  now,
		}
		if err := tx.Create(&created).Error; err != nil {
			return err
		}
		if err := upsertConversationMemberTx(tx, created.ID, userID, "member"); err != nil {
			return err
		}
		return upsertConversationMemberTx(tx, created.ID, targetUserID, "member")
	})
	if err != nil {
		return nil, err
	}
	return &created, nil
}

func CreateGroupConversation(creatorID uint64, name, avatarURL string, memberIDs []uint64) (*ChatConversation, error) {
	if creatorID == 0 {
		return nil, errors.New("invalid creator id")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, errors.New("group name required")
	}

	uniqueMembers := map[uint64]struct{}{creatorID: {}}
	for _, id := range memberIDs {
		if id > 0 {
			uniqueMembers[id] = struct{}{}
		}
	}

	now := time.Now()
	item := ChatConversation{
		Type:      ChatConversationTypeGroup,
		Name:      name,
		AvatarURL: avatarURL,
		CreatorID: creatorID,
		CreatedAt: now,
		UpdatedAt: now,
	}

	err := db.GetDB().Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&item).Error; err != nil {
			return err
		}
		for id := range uniqueMembers {
			role := "member"
			if id == creatorID {
				role = "owner"
			}
			if err := upsertConversationMemberTx(tx, item.ID, id, role); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func AddGroupMembers(conversationID, operatorID uint64, userIDs []uint64) error {
	if conversationID == 0 || operatorID == 0 {
		return errors.New("invalid params")
	}
	conv, err := GetConversationByID(conversationID)
	if err != nil {
		return err
	}
	if conv.Type != ChatConversationTypeGroup {
		return errors.New("only group conversation supports add members")
	}

	ok, err := IsConversationMember(conversationID, operatorID)
	if err != nil {
		return err
	}
	if !ok {
		return errors.New("no permission")
	}

	return db.GetDB().Transaction(func(tx *gorm.DB) error {
		for _, userID := range userIDs {
			if userID == 0 {
				continue
			}
			if err := upsertConversationMemberTx(tx, conversationID, userID, "member"); err != nil {
				return err
			}
		}
		return nil
	})
}

func CreateChatMessage(conversationID, senderID uint64, msgType, content, extraJSON string) (*ChatMessage, error) {
	if conversationID == 0 || senderID == 0 {
		return nil, errors.New("invalid params")
	}
	content = strings.TrimSpace(content)
	if content == "" {
		return nil, errors.New("content required")
	}
	if msgType == "" {
		msgType = ChatMessageTypeText
	}
	extraJSON = strings.TrimSpace(extraJSON)
	if extraJSON == "" {
		extraJSON = "{}"
	}
	ok, err := IsConversationMember(conversationID, senderID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, errors.New("user is not conversation member")
	}

	msg := ChatMessage{
		ConversationID: conversationID,
		SenderID:       senderID,
		MsgType:        msgType,
		Content:        content,
		ExtraJSON:      extraJSON,
		CreatedAt:      time.Now(),
	}
	err = db.GetDB().Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&msg).Error; err != nil {
			return err
		}
		now := msg.CreatedAt
		return tx.Model(&ChatConversation{}).
			Where("id = ?", conversationID).
			Updates(map[string]any{
				"last_message":    content,
				"last_message_at": now,
				"updated_at":      now,
			}).Error
	})
	if err != nil {
		return nil, err
	}
	return &msg, nil
}

func GetConversationMessages(conversationID, userID uint64, page, pageSize int) ([]ChatMessageItem, int64, error) {
	ok, err := IsConversationMember(conversationID, userID)
	if err != nil {
		return nil, 0, err
	}
	if !ok {
		return nil, 0, errors.New("user is not conversation member")
	}

	var total int64
	if err := db.GetDB().Model(&ChatMessage{}).
		Where("conversation_id = ? AND is_deleted = 0", conversationID).
		Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	rows := make([]ChatMessageItem, 0)
	err = db.GetDB().Raw(`
SELECT
	m.id,
	m.conversation_id,
	m.sender_id,
	COALESCE(NULLIF(u.nickname, ''), NULLIF(u.username, ''), CONCAT('user_', m.sender_id)) AS sender_name,
	COALESCE(u.avatar_url, '') AS sender_avatar,
	m.msg_type,
	m.content,
	COALESCE(m.extra_json, '') AS extra_json,
	m.created_at
FROM chat_messages m
LEFT JOIN users u ON u.id = m.sender_id
WHERE m.conversation_id = ? AND m.is_deleted = 0
ORDER BY m.id DESC
LIMIT ? OFFSET ?`, conversationID, pageSize, offset).Scan(&rows).Error
	if err != nil {
		return nil, 0, err
	}
	return rows, total, nil
}

func MarkConversationRead(conversationID, userID, lastMessageID uint64) error {
	if conversationID == 0 || userID == 0 {
		return errors.New("invalid params")
	}

	now := time.Now()
	return db.GetDB().Model(&ChatConversationMember{}).
		Where("conversation_id = ? AND user_id = ? AND is_deleted = 0", conversationID, userID).
		Updates(map[string]any{
			"last_read_message_id": lastMessageID,
			"last_read_at":         now,
		}).Error
}

func GetConversationList(userID uint64, page, pageSize int) ([]ConversationListItem, int64, error) {
	if userID == 0 {
		return nil, 0, errors.New("invalid user id")
	}
	offset := (page - 1) * pageSize

	var total int64
	if err := db.GetDB().Raw(`
SELECT COUNT(1)
FROM chat_conversation_members cm
JOIN chat_conversations c ON c.id = cm.conversation_id AND c.is_deleted = 0
WHERE cm.user_id = ? AND cm.is_deleted = 0
`, userID).Scan(&total).Error; err != nil {
		return nil, 0, err
	}

	type rowItem struct {
		ID            uint64     `gorm:"column:id"`
		Type          string     `gorm:"column:type"`
		Name          string     `gorm:"column:name"`
		AvatarURL     string     `gorm:"column:avatar_url"`
		LastMessage   string     `gorm:"column:last_message"`
		LastMessageAt *time.Time `gorm:"column:last_message_at"`
		UnreadCount   int64      `gorm:"column:unread_count"`
	}
	rows := make([]rowItem, 0)
	err := db.GetDB().Raw(`
SELECT
	c.id,
	c.type,
	COALESCE(c.name, '') AS name,
	COALESCE(c.avatar_url, '') AS avatar_url,
	COALESCE(c.last_message, '') AS last_message,
	c.last_message_at,
	COALESCE(SUM(CASE WHEN m.id > COALESCE(cm.last_read_message_id, 0) AND m.sender_id <> ? THEN 1 ELSE 0 END), 0) AS unread_count
FROM chat_conversation_members cm
JOIN chat_conversations c ON c.id = cm.conversation_id AND c.is_deleted = 0
LEFT JOIN chat_messages m ON m.conversation_id = c.id AND m.is_deleted = 0
WHERE cm.user_id = ? AND cm.is_deleted = 0
GROUP BY c.id, c.type, c.name, c.avatar_url, c.last_message, c.last_message_at, cm.last_read_message_id
ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
LIMIT ? OFFSET ?
`, userID, userID, pageSize, offset).Scan(&rows).Error
	if err != nil {
		return nil, 0, err
	}

	items := make([]ConversationListItem, 0, len(rows))
	for _, row := range rows {
		item := ConversationListItem{
			ID:            row.ID,
			Type:          row.Type,
			Name:          row.Name,
			AvatarURL:     row.AvatarURL,
			LastMessage:   row.LastMessage,
			LastMessageAt: row.LastMessageAt,
			UnreadCount:   row.UnreadCount,
		}
		// For private conversation, fill display name/avatar from the peer user.
		if item.Type == ChatConversationTypePrivate {
			peerName, peerAvatar, _ := GetPrivateConversationPeer(item.ID, userID)
			if peerName != "" {
				item.Name = peerName
			} else if item.Name == "" {
				item.Name = "private chat"
			}
			if peerAvatar != "" {
				item.AvatarURL = peerAvatar
			}
		}
		items = append(items, item)
	}
	return items, total, nil
}

func GetPrivateConversationPeer(conversationID, userID uint64) (string, string, error) {
	type peerRow struct {
		Name      string `gorm:"column:name"`
		AvatarURL string `gorm:"column:avatar_url"`
	}
	var row peerRow
	err := db.GetDB().Raw(`
SELECT
	COALESCE(NULLIF(u.nickname, ''), NULLIF(u.username, ''), CONCAT('user_', u.id)) AS name,
	COALESCE(u.avatar_url, '') AS avatar_url
FROM chat_conversation_members cm
JOIN users u ON u.id = cm.user_id
WHERE cm.conversation_id = ? AND cm.user_id <> ? AND cm.is_deleted = 0
LIMIT 1
`, conversationID, userID).Scan(&row).Error
	if err != nil {
		return "", "", err
	}
	return row.Name, row.AvatarURL, nil
}

func GetChatUnreadCount(userID uint64) (int64, error) {
	var total int64
	err := db.GetDB().Raw(`
SELECT COALESCE(SUM(unread_count), 0) AS total FROM (
	SELECT
		COALESCE(SUM(CASE WHEN m.id > COALESCE(cm.last_read_message_id, 0) AND m.sender_id <> ? THEN 1 ELSE 0 END), 0) AS unread_count
	FROM chat_conversation_members cm
	JOIN chat_conversations c ON c.id = cm.conversation_id AND c.is_deleted = 0
	LEFT JOIN chat_messages m ON m.conversation_id = c.id AND m.is_deleted = 0
	WHERE cm.user_id = ? AND cm.is_deleted = 0
	GROUP BY cm.conversation_id, cm.last_read_message_id
) t
`, userID, userID).Scan(&total).Error
	return total, err
}
