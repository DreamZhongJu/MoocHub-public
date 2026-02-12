package model

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/db"
	"context"
	"fmt"
	"strconv"
	"time"

	"gorm.io/gorm"
)

// Message represents a notification item.
type Message struct {
	ID        uint64    `gorm:"column:id;primaryKey" json:"id"`
	UserID    uint      `gorm:"column:user_id" json:"user_id"`
	Type      string    `gorm:"column:type" json:"type"`
	Title     string    `gorm:"column:title" json:"title"`
	Content   string    `gorm:"column:content" json:"content"`
	BizID     *uint64   `gorm:"column:biz_id" json:"biz_id"`
	IsRead    bool      `gorm:"column:is_read" json:"is_read"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
}

func (Message) TableName() string {
	return "messages"
}

const unreadTTL = 10 * time.Minute

func unreadKey(userID uint) string {
	return fmt.Sprintf("msg:unread:%d", userID)
}

func unreadTypeKey(userID uint, msgType string) string {
	return fmt.Sprintf("msg:unread:%d:%s", userID, msgType)
}

// CreateMessage inserts a message and bumps unread counters.
func CreateMessage(userID uint, msgType, title, content string, bizID *uint64) error {
	return db.GetDB().Transaction(func(tx *gorm.DB) error {
		item := Message{
			UserID:  userID,
			Type:    msgType,
			Title:   title,
			Content: content,
			BizID:   bizID,
			IsRead:  false,
		}
		if err := tx.Create(&item).Error; err != nil {
			return err
		}

		if client := cache.Client(); client != nil {
			ctx := context.Background()
			_ = client.Incr(ctx, unreadKey(userID)).Err()
			if msgType != "" {
				_ = client.Incr(ctx, unreadTypeKey(userID, msgType)).Err()
			}
		}
		return nil
	})
}

// CreateMessageWithID inserts a message and returns its ID.
func CreateMessageWithID(userID uint, msgType, title, content string, bizID *uint64) (uint64, error) {
	var createdID uint64
	err := db.GetDB().Transaction(func(tx *gorm.DB) error {
		item := Message{
			UserID:  userID,
			Type:    msgType,
			Title:   title,
			Content: content,
			BizID:   bizID,
			IsRead:  false,
		}
		if err := tx.Create(&item).Error; err != nil {
			return err
		}
		createdID = item.ID

		if client := cache.Client(); client != nil {
			ctx := context.Background()
			_ = client.Incr(ctx, unreadKey(userID)).Err()
			if msgType != "" {
				_ = client.Incr(ctx, unreadTypeKey(userID, msgType)).Err()
			}
		}
		return nil
	})
	return createdID, err
}

// GetMessages returns message list with pagination.
func GetMessages(userID uint, msgType string, page, pageSize int) ([]Message, int64, error) {
	var items []Message
	var total int64

	q := db.GetDB().Model(&Message{}).Where("user_id = ?", userID)
	if msgType != "" {
		q = q.Where("type = ?", msgType)
	}

	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := q.Order("id DESC").Offset(offset).Limit(pageSize).Find(&items).Error; err != nil {
		return nil, 0, err
	}

	return items, total, nil
}

// GetUnreadCount returns unread count, optionally by type.
func GetUnreadCount(userID uint, msgType string) (int64, error) {
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		key := unreadKey(userID)
		if msgType != "" {
			key = unreadTypeKey(userID, msgType)
		}
		if v, err := client.Get(ctx, key).Result(); err == nil && v != "" {
			if n, err := strconv.ParseInt(v, 10, 64); err == nil {
				return n, nil
			}
		}
	}

	q := db.GetDB().Model(&Message{}).Where("user_id = ? AND is_read = 0", userID)
	if msgType != "" {
		q = q.Where("type = ?", msgType)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return 0, err
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		key := unreadKey(userID)
		if msgType != "" {
			key = unreadTypeKey(userID, msgType)
		}
		_ = client.Set(ctx, key, total, unreadTTL).Err()
	}

	return total, nil
}

// MarkReadByIDs marks given message IDs as read.
func MarkReadByIDs(userID uint, ids []uint64) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}

	var unreadCount int64
	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ? AND is_read = 0 AND id IN ?", userID, ids).
		Count(&unreadCount).Error; err != nil {
		return 0, err
	}

	if unreadCount == 0 {
		return 0, nil
	}

	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ? AND id IN ?", userID, ids).
		Updates(map[string]any{"is_read": true}).Error; err != nil {
		return 0, err
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.DecrBy(ctx, unreadKey(userID), unreadCount).Err()
	}
	return unreadCount, nil
}

// MarkReadByType marks all messages of a type as read.
func MarkReadByType(userID uint, msgType string) (int64, error) {
	if msgType == "" {
		return 0, nil
	}

	var unreadCount int64
	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ? AND is_read = 0 AND type = ?", userID, msgType).
		Count(&unreadCount).Error; err != nil {
		return 0, err
	}
	if unreadCount == 0 {
		return 0, nil
	}

	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ? AND type = ?", userID, msgType).
		Updates(map[string]any{"is_read": true}).Error; err != nil {
		return 0, err
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.DecrBy(ctx, unreadKey(userID), unreadCount).Err()
		_ = client.Set(ctx, unreadTypeKey(userID, msgType), 0, unreadTTL).Err()
	}
	return unreadCount, nil
}

// MarkReadAll marks all messages as read.
func MarkReadAll(userID uint) (int64, error) {
	var unreadCount int64
	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ? AND is_read = 0", userID).
		Count(&unreadCount).Error; err != nil {
		return 0, err
	}
	if unreadCount == 0 {
		return 0, nil
	}

	if err := db.GetDB().Model(&Message{}).
		Where("user_id = ?", userID).
		Updates(map[string]any{"is_read": true}).Error; err != nil {
		return 0, err
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Set(ctx, unreadKey(userID), 0, unreadTTL).Err()
	}
	return unreadCount, nil
}
