package controllers

import (
	"MOOCHUB-server/model"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type AdminAnalyticsController struct{}

func (ac AdminAnalyticsController) Overview(c *gin.Context) {
	from, to, err := parseAnalyticsTimeRange(c)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	contentType := strings.ToLower(strings.TrimSpace(c.DefaultQuery("content_type", "")))
	if !isValidContentType(contentType) {
		ReturnError(c, 400, "invalid content_type")
		return
	}
	scene := strings.TrimSpace(c.DefaultQuery("scene", ""))
	if len(scene) > 64 {
		ReturnError(c, 400, "invalid scene")
		return
	}

	overview, err := model.GetAnalyticsOverview(from, to, contentType, scene)
	if err != nil {
		ReturnError(c, 500, "load overview failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"from":         from.Format(time.RFC3339),
		"to":           to.Format(time.RFC3339),
		"content_type": contentType,
		"scene":        scene,
		"overview":     overview,
	}, 1)
}

func (ac AdminAnalyticsController) Trend(c *gin.Context) {
	from, to, err := parseAnalyticsTimeRange(c)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	contentType := strings.ToLower(strings.TrimSpace(c.DefaultQuery("content_type", "")))
	if !isValidContentType(contentType) {
		ReturnError(c, 400, "invalid content_type")
		return
	}
	scene := strings.TrimSpace(c.DefaultQuery("scene", ""))
	if len(scene) > 64 {
		ReturnError(c, 400, "invalid scene")
		return
	}

	items, err := model.GetAnalyticsTrend(from, to, contentType, scene)
	if err != nil {
		ReturnError(c, 500, "load trend failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"from":         from.Format(time.RFC3339),
		"to":           to.Format(time.RFC3339),
		"content_type": contentType,
		"scene":        scene,
		"items":        items,
	}, int64(len(items)))
}

func (ac AdminAnalyticsController) Top(c *gin.Context) {
	from, to, err := parseAnalyticsTimeRange(c)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	eventType := strings.ToLower(strings.TrimSpace(c.DefaultQuery("event_type", "click")))
	if !isValidEventType(eventType) {
		ReturnError(c, 400, "invalid event_type")
		return
	}

	contentType := strings.ToLower(strings.TrimSpace(c.DefaultQuery("content_type", "")))
	if !isValidContentType(contentType) {
		ReturnError(c, 400, "invalid content_type")
		return
	}

	scene := strings.TrimSpace(c.DefaultQuery("scene", ""))
	if len(scene) > 64 {
		ReturnError(c, 400, "invalid scene")
		return
	}

	limit := 10
	if raw := strings.TrimSpace(c.DefaultQuery("limit", "10")); raw != "" {
		v, err := strconv.Atoi(raw)
		if err != nil || v <= 0 {
			ReturnError(c, 400, "invalid limit")
			return
		}
		if v > 100 {
			v = 100
		}
		limit = v
	}

	items, err := model.GetAnalyticsTopContent(eventType, from, to, contentType, scene, limit)
	if err != nil {
		ReturnError(c, 500, "load top content failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"from":         from.Format(time.RFC3339),
		"to":           to.Format(time.RFC3339),
		"event_type":   eventType,
		"content_type": contentType,
		"scene":        scene,
		"items":        items,
	}, int64(len(items)))
}

func parseAnalyticsTimeRange(c *gin.Context) (time.Time, time.Time, error) {
	now := time.Now()
	to := now
	from := now.Add(-24 * time.Hour)

	var err error
	if raw := strings.TrimSpace(c.Query("to")); raw != "" {
		to, err = parseFlexibleTime(raw)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
	}
	if raw := strings.TrimSpace(c.Query("from")); raw != "" {
		from, err = parseFlexibleTime(raw)
		if err != nil {
			return time.Time{}, time.Time{}, err
		}
	}

	from = from.Truncate(time.Hour)
	to = to.Truncate(time.Hour).Add(time.Hour)
	if !from.Before(to) {
		return time.Time{}, time.Time{}, errInvalidRange()
	}
	if to.Sub(from) > 31*24*time.Hour {
		return time.Time{}, time.Time{}, errRangeTooLarge()
	}
	return from, to, nil
}

func parseFlexibleTime(raw string) (time.Time, error) {
	if sec, err := strconv.ParseInt(raw, 10, 64); err == nil {
		return time.Unix(sec, 0), nil
	}

	layouts := []string{
		time.RFC3339,
		"2006-01-02 15:04:05",
		"2006-01-02 15:04",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if t, err := time.ParseInLocation(layout, raw, time.Local); err == nil {
			return t, nil
		}
	}
	return time.Time{}, errInvalidTime()
}

func isValidContentType(contentType string) bool {
	if contentType == "" {
		return true
	}
	return contentType == "course" || contentType == "article" || contentType == "video"
}

func isValidEventType(eventType string) bool {
	return eventType == "exposure" ||
		eventType == "click" ||
		eventType == "play_start" ||
		eventType == "play_complete"
}

func errInvalidRange() error {
	return &analyticsBadRequestError{message: "invalid time range"}
}

func errRangeTooLarge() error {
	return &analyticsBadRequestError{message: "time range too large, max 31 days"}
}

func errInvalidTime() error {
	return &analyticsBadRequestError{message: "invalid time format"}
}

type analyticsBadRequestError struct {
	message string
}

func (e *analyticsBadRequestError) Error() string {
	return e.message
}
