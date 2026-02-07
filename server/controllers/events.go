package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/utils"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type EventsController struct{}

func (ec EventsController) Play(c *gin.Context) {
	videoIDStr := c.DefaultPostForm("video_id", "")
	if videoIDStr == "" {
		ReturnError(c, 400, "video_id required")
		return
	}
	videoID, err := strconv.ParseInt(videoIDStr, 10, 64)
	if err != nil || videoID <= 0 {
		ReturnError(c, 400, "invalid video_id")
		return
	}

	var userID int64
	if authHeader := c.GetHeader("Authorization"); authHeader != "" {
		if claims, err := utils.ParseToken(authHeader); err == nil {
			userID = int64(claims.UserID)
		}
	}

	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if client := cache.Client(); client != nil {
		dedupKey := buildPlayDedupKey(userID, videoID, ip, ua)
		ok, err := client.SetNX(c.Request.Context(), dedupKey, "1", 30*time.Minute).Result()
		if err == nil && !ok {
			ReturnSuccess(c, 200, "ok", gin.H{"skipped": true}, 0)
			return
		}
	}

	payload := map[string]any{
		"event":                "play.view",
		"user_id":              userID,
		"video_id":             videoID,
		"ip":                   ip,
		"ua":                   ua,
		"occurred_at_unix_sec": time.Now().Unix(),
	}
	if data, err := json.Marshal(payload); err == nil {
		_ = mq.Publish("play.view", data)
	}

	ReturnSuccess(c, 200, "ok", gin.H{"skipped": false}, 0)
}

func buildPlayDedupKey(userID int64, videoID int64, ip string, ua string) string {
	if userID > 0 {
		return "play:view:u:" + strconv.FormatInt(userID, 10) + ":v:" + strconv.FormatInt(videoID, 10)
	}
	hash := sha1.Sum([]byte(ip + "|" + ua))
	finger := hex.EncodeToString(hash[:8])
	return "play:view:a:" + finger + ":v:" + strconv.FormatInt(videoID, 10)
}
