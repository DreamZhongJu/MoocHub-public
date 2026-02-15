package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/utils"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	eventTypeExposure     = "exposure"
	eventTypeClick        = "click"
	eventTypePlayStart    = "play_start"
	eventTypePlayComplete = "play_complete"
)

type EventsController struct{}

type eventTrackRequest struct {
	ContentType string `form:"content_type" json:"content_type"`
	ContentID   int64  `form:"content_id" json:"content_id"`
	Scene       string `form:"scene" json:"scene"`
	SessionID   string `form:"session_id" json:"session_id"`
	Position    int    `form:"position" json:"position"`
}

type playEventRequest struct {
	VideoID   int64  `form:"video_id" json:"video_id"`
	Scene     string `form:"scene" json:"scene"`
	SessionID string `form:"session_id" json:"session_id"`
	Position  int    `form:"position" json:"position"`
}

func (ec EventsController) Exposure(c *gin.Context) {
	ec.trackEvent(c, eventTypeExposure)
}

func (ec EventsController) Click(c *gin.Context) {
	ec.trackEvent(c, eventTypeClick)
}

func (ec EventsController) Complete(c *gin.Context) {
	ec.trackEvent(c, eventTypePlayComplete)
}

func (ec EventsController) Play(c *gin.Context) {
	var req playEventRequest
	if err := c.ShouldBind(&req); err != nil {
		ReturnError(c, 400, "invalid params")
		return
	}
	if req.VideoID <= 0 {
		ReturnError(c, 400, "invalid video_id")
		return
	}
	if req.Position < 0 {
		ReturnError(c, 400, "invalid position")
		return
	}
	if len(strings.TrimSpace(req.Scene)) > 64 || len(strings.TrimSpace(req.SessionID)) > 64 {
		ReturnError(c, 400, "params too long")
		return
	}

	payload := model.AnalyticsEventPayload{
		EventType:         eventTypePlayStart,
		ContentType:       "video",
		ContentID:         req.VideoID,
		UserID:            parseOptionalUserID(c),
		SessionID:         strings.TrimSpace(req.SessionID),
		Scene:             strings.TrimSpace(req.Scene),
		Position:          req.Position,
		IP:                c.ClientIP(),
		UA:                c.GetHeader("User-Agent"),
		OccurredAtUnixSec: time.Now().Unix(),
	}

	skipped, err := deduplicateEvent(c, payload)
	if err != nil {
		ReturnError(c, 500, "dedup failed")
		return
	}
	if skipped {
		ReturnSuccess(c, 200, "ok", gin.H{"skipped": true}, 0)
		return
	}

	legacyPayload := map[string]any{
		"event":                "play.view",
		"user_id":              payload.UserID,
		"video_id":             req.VideoID,
		"ip":                   payload.IP,
		"ua":                   payload.UA,
		"occurred_at_unix_sec": payload.OccurredAtUnixSec,
	}
	data, err := json.Marshal(legacyPayload)
	if err == nil {
		err = mq.PublishWithTrace("play.view", data, utils.GetTraceID(c))
	}
	if err != nil {
		ReturnError(c, 500, "publish failed")
		return
	}

	if err := publishAnalyticsEvent(c, payload); err != nil {
		ReturnError(c, 500, "publish failed")
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{"skipped": false}, 0)
}

func (ec EventsController) trackEvent(c *gin.Context, eventType string) {
	var req eventTrackRequest
	if err := c.ShouldBind(&req); err != nil {
		ReturnError(c, 400, "invalid params")
		return
	}

	req.ContentType = strings.TrimSpace(req.ContentType)
	req.Scene = strings.TrimSpace(req.Scene)
	req.SessionID = strings.TrimSpace(req.SessionID)
	if req.ContentType == "" {
		ReturnError(c, 400, "content_type required")
		return
	}
	if req.ContentID <= 0 {
		ReturnError(c, 400, "invalid content_id")
		return
	}
	if req.Position < 0 {
		ReturnError(c, 400, "invalid position")
		return
	}
	if len(req.ContentType) > 32 || len(req.Scene) > 64 || len(req.SessionID) > 64 {
		ReturnError(c, 400, "params too long")
		return
	}

	payload := model.AnalyticsEventPayload{
		EventType:         eventType,
		ContentType:       req.ContentType,
		ContentID:         req.ContentID,
		UserID:            parseOptionalUserID(c),
		SessionID:         req.SessionID,
		Scene:             req.Scene,
		Position:          req.Position,
		IP:                c.ClientIP(),
		UA:                c.GetHeader("User-Agent"),
		OccurredAtUnixSec: time.Now().Unix(),
	}

	skipped, err := deduplicateEvent(c, payload)
	if err != nil {
		ReturnError(c, 500, "dedup failed")
		return
	}
	if skipped {
		ReturnSuccess(c, 200, "ok", gin.H{"skipped": true}, 0)
		return
	}

	if err := publishAnalyticsEvent(c, payload); err != nil {
		ReturnError(c, 500, "publish failed")
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{"skipped": false}, 0)
}

func publishAnalyticsEvent(c *gin.Context, payload model.AnalyticsEventPayload) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return mq.PublishWithTrace("analytics.event", data, utils.GetTraceID(c))
}

func parseOptionalUserID(c *gin.Context) int64 {
	authHeader := strings.TrimSpace(c.GetHeader("Authorization"))
	if authHeader == "" {
		return 0
	}
	claims, err := utils.ParseToken(authHeader)
	if err != nil {
		return 0
	}
	return int64(claims.UserID)
}

func deduplicateEvent(c *gin.Context, evt model.AnalyticsEventPayload) (bool, error) {
	client := cache.Client()
	if client == nil {
		return false, nil
	}

	dedupKey := buildEventDedupKey(evt)
	ttl := dedupTTL(evt.EventType)
	ok, err := client.SetNX(c.Request.Context(), dedupKey, "1", ttl).Result()
	if err != nil {
		return false, err
	}
	return !ok, nil
}

func dedupTTL(eventType string) time.Duration {
	switch eventType {
	case eventTypeClick:
		return 3 * time.Second
	case eventTypePlayComplete:
		return 24 * time.Hour
	default:
		return 30 * time.Minute
	}
}

func buildEventDedupKey(evt model.AnalyticsEventPayload) string {
	subject := buildEventSubject(evt.UserID, evt.SessionID, evt.IP, evt.UA)
	base := fmt.Sprintf("event:dedup:%s:%s:%d:%s:%s", evt.EventType, evt.ContentType, evt.ContentID, evt.Scene, subject)
	if evt.EventType == eventTypePlayComplete {
		day := time.Unix(evt.OccurredAtUnixSec, 0).Format("20060102")
		return base + ":" + day
	}
	return base
}

func buildEventSubject(userID int64, sessionID string, ip string, ua string) string {
	if userID > 0 {
		return "u:" + fmt.Sprintf("%d", userID)
	}
	if sessionID != "" {
		return "s:" + sessionID
	}
	hash := sha1.Sum([]byte(ip + "|" + ua))
	return "a:" + hex.EncodeToString(hash[:8])
}
