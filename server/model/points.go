package model

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/db"
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type PointsTransaction struct {
	ID        uint64    `gorm:"column:id;primaryKey" json:"id"`
	UserID    uint      `gorm:"column:user_id" json:"user_id"`
	EventType string    `gorm:"column:event_type" json:"event_type"`
	Points    int       `gorm:"column:points" json:"points"`
	BizID     *uint64   `gorm:"column:biz_id" json:"biz_id"`
	Remark    string    `gorm:"column:remark" json:"remark"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
}

const pointsBalanceTTL = 10 * time.Minute
const pointsDedupTTL = 24 * time.Hour

func pointsBalanceKey(userID uint) string {
	return fmt.Sprintf("points:balance:%d", userID)
}

func pointsRankKey() string {
	return "points:rank"
}

func pointsDedupKey(userID uint, eventType string, bizID *uint64) string {
	if bizID != nil {
		return fmt.Sprintf("points:dedup:%s:%d:%d", eventType, userID, *bizID)
	}
	date := time.Now().Format("20060102")
	return fmt.Sprintf("points:dedup:%s:%d:%s", eventType, userID, date)
}

// allowAward 使用 Redis 做幂等与防刷控制。
// 返回 false 表示本次积分发放应被跳过（已在窗口内处理过）。
func allowAward(userID uint, eventType string, bizID *uint64) bool {
	client := cache.Client()
	if client == nil {
		return true
	}
	key := pointsDedupKey(userID, eventType, bizID)
	ok, err := client.SetNX(context.Background(), key, "1", pointsDedupTTL).Result()
	if err != nil {
		// Redis 异常不应阻断主流程。
		return true
	}
	return ok
}

func refreshPointsCache(userID uint) (int, error) {
	var user Users
	if err := db.GetDB().Select("points_balance").First(&user, userID).Error; err != nil {
		return 0, err
	}
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Set(ctx, pointsBalanceKey(userID), user.PointsBalance, pointsBalanceTTL).Err()
		_ = client.ZAdd(ctx, pointsRankKey(), redisZ(userID, user.PointsBalance).(redis.Z)).Err()
	}
	return user.PointsBalance, nil
}

func redisZ(userID uint, balance int) interface{} {
	return redis.Z{
		Score:  float64(balance),
		Member: strconv.FormatUint(uint64(userID), 10),
	}
}

func AwardPoints(userID uint, eventType string, points int, bizID *uint64, remark string) (int, error) {
	// 幂等与防刷：窗口内已发放过则跳过。
	if !allowAward(userID, eventType, bizID) {
		balance, err := GetUserPointsBalance(userID)
		if err != nil {
			return 0, nil
		}
		return balance, nil
	}
	if err := db.GetDB().Transaction(func(tx *gorm.DB) error {
		record := PointsTransaction{
			UserID:    userID,
			EventType: eventType,
			Points:    points,
			BizID:     bizID,
			Remark:    remark,
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}
		if err := tx.Model(&Users{}).Where("id = ?", userID).
			UpdateColumn("points_balance", gorm.Expr("points_balance + ?", points)).Error; err != nil {
			return err
		}
		return nil
	}); err != nil {
		return 0, err
	}
	// refresh cache and rank after transaction
	balance, err := refreshPointsCache(userID)
	if err != nil {
		return 0, err
	}
	return balance, nil
}

func GetUserPointsBalance(userID uint) (int, error) {
	if client := cache.Client(); client != nil {
		if v, err := client.Get(context.Background(), pointsBalanceKey(userID)).Result(); err == nil && v != "" {
			if n, err := strconv.Atoi(v); err == nil {
				return n, nil
			}
		}
	}
	return refreshPointsCache(userID)
}

func GetPointsTransactions(userID uint, page int, pageSize int, eventType string) ([]PointsTransaction, int64, error) {
	var items []PointsTransaction
	var total int64

	q := db.GetDB().Model(&PointsTransaction{}).Where("user_id = ?", userID)
	if eventType != "" {
		q = q.Where("event_type = ?", eventType)
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

type PointsRankItem struct {
	UserID        uint   `json:"user_id"`
	Username      string `json:"username"`
	Nickname      string `json:"nickname"`
	AvatarURL     string `json:"avatar_url"`
	PointsBalance int    `json:"points_balance"`
}

func GetPointsRank(page int, pageSize int) ([]PointsRankItem, int64, error) {
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		start := int64((page - 1) * pageSize)
		stop := start + int64(pageSize) - 1
		zs, err := client.ZRevRangeWithScores(ctx, pointsRankKey(), start, stop).Result()
		if err == nil && len(zs) > 0 {
			ids := make([]uint, 0, len(zs))
			order := make([]string, 0, len(zs))
			scoreMap := make(map[string]int, len(zs))
			for _, z := range zs {
				idStr, ok := z.Member.(string)
				if !ok {
					continue
				}
				idVal, err := strconv.ParseUint(idStr, 10, 64)
				if err != nil {
					continue
				}
				ids = append(ids, uint(idVal))
				order = append(order, idStr)
				scoreMap[idStr] = int(z.Score)
			}

			var users []Users
			if err := db.GetDB().Model(&Users{}).
				Select("id, username, nickname, avatar_url, points_balance").
				Where("id IN ?", ids).
				Find(&users).Error; err != nil {
				return nil, 0, err
			}

			userMap := make(map[string]Users, len(users))
			for _, u := range users {
				userMap[strconv.FormatUint(uint64(u.ID), 10)] = u
			}

			items := make([]PointsRankItem, 0, len(order))
			for _, idStr := range order {
				u, ok := userMap[idStr]
				if !ok {
					continue
				}
				items = append(items, PointsRankItem{
					UserID:        u.ID,
					Username:      u.Username,
					Nickname:      u.Nickname,
					AvatarURL:     u.AvatarURL,
					PointsBalance: scoreMap[idStr],
				})
			}

			total, _ := client.ZCard(ctx, pointsRankKey()).Result()
			return items, total, nil
		}
	}

	var items []PointsRankItem
	var total int64

	if err := db.GetDB().Model(&Users{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := db.GetDB().Model(&Users{}).
		Select("id as user_id, username, nickname, avatar_url, points_balance").
		Order("points_balance DESC").
		Offset(offset).Limit(pageSize).
		Scan(&items).Error; err != nil {
		return nil, 0, err
	}

	return items, total, nil
}
