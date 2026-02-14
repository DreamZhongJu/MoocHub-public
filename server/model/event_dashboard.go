package model

import (
	"MOOCHUB-server/db"
	"sort"
	"time"
)

type AnalyticsOverview struct {
	ExposurePV     int64   `json:"exposure_pv"`
	ExposureUV     int64   `json:"exposure_uv"`
	ClickPV        int64   `json:"click_pv"`
	ClickUV        int64   `json:"click_uv"`
	PlayStartPV    int64   `json:"play_start_pv"`
	PlayStartUV    int64   `json:"play_start_uv"`
	PlayCompletePV int64   `json:"play_complete_pv"`
	PlayCompleteUV int64   `json:"play_complete_uv"`
	CTR            float64 `json:"ctr"`
	CompleteRate   float64 `json:"complete_rate"`
}

type AnalyticsTrendPoint struct {
	BucketHour     time.Time `json:"bucket_hour"`
	ExposurePV     int64     `json:"exposure_pv"`
	ExposureUV     int64     `json:"exposure_uv"`
	ClickPV        int64     `json:"click_pv"`
	ClickUV        int64     `json:"click_uv"`
	PlayStartPV    int64     `json:"play_start_pv"`
	PlayStartUV    int64     `json:"play_start_uv"`
	PlayCompletePV int64     `json:"play_complete_pv"`
	PlayCompleteUV int64     `json:"play_complete_uv"`
	CTR            float64   `json:"ctr"`
	CompleteRate   float64   `json:"complete_rate"`
}

type AnalyticsTopContent struct {
	ContentType string `json:"content_type"`
	ContentID   int64  `json:"content_id"`
	PV          int64  `json:"pv"`
	UV          int64  `json:"uv"`
}

func GetAnalyticsOverview(from time.Time, to time.Time, contentType string, scene string) (AnalyticsOverview, error) {
	var row struct {
		ExposurePV     int64 `gorm:"column:exposure_pv"`
		ExposureUV     int64 `gorm:"column:exposure_uv"`
		ClickPV        int64 `gorm:"column:click_pv"`
		ClickUV        int64 `gorm:"column:click_uv"`
		PlayStartPV    int64 `gorm:"column:play_start_pv"`
		PlayStartUV    int64 `gorm:"column:play_start_uv"`
		PlayCompletePV int64 `gorm:"column:play_complete_pv"`
		PlayCompleteUV int64 `gorm:"column:play_complete_uv"`
	}

	q := db.GetDB().Table("event_stats_hourly").
		Where("bucket_hour >= ? AND bucket_hour < ?", from, to)
	if contentType != "" {
		q = q.Where("content_type = ?", contentType)
	}
	if scene != "" {
		q = q.Where("scene = ?", scene)
	}

	if err := q.Select(`
COALESCE(SUM(CASE WHEN event_type = 'exposure' THEN pv ELSE 0 END), 0) AS exposure_pv,
COALESCE(SUM(CASE WHEN event_type = 'exposure' THEN uv ELSE 0 END), 0) AS exposure_uv,
COALESCE(SUM(CASE WHEN event_type = 'click' THEN pv ELSE 0 END), 0) AS click_pv,
COALESCE(SUM(CASE WHEN event_type = 'click' THEN uv ELSE 0 END), 0) AS click_uv,
COALESCE(SUM(CASE WHEN event_type = 'play_start' THEN pv ELSE 0 END), 0) AS play_start_pv,
COALESCE(SUM(CASE WHEN event_type = 'play_start' THEN uv ELSE 0 END), 0) AS play_start_uv,
COALESCE(SUM(CASE WHEN event_type = 'play_complete' THEN pv ELSE 0 END), 0) AS play_complete_pv,
COALESCE(SUM(CASE WHEN event_type = 'play_complete' THEN uv ELSE 0 END), 0) AS play_complete_uv
`).Scan(&row).Error; err != nil {
		return AnalyticsOverview{}, err
	}

	result := AnalyticsOverview{
		ExposurePV:     row.ExposurePV,
		ExposureUV:     row.ExposureUV,
		ClickPV:        row.ClickPV,
		ClickUV:        row.ClickUV,
		PlayStartPV:    row.PlayStartPV,
		PlayStartUV:    row.PlayStartUV,
		PlayCompletePV: row.PlayCompletePV,
		PlayCompleteUV: row.PlayCompleteUV,
	}
	if result.ExposurePV > 0 {
		result.CTR = float64(result.ClickPV) / float64(result.ExposurePV)
	}
	if result.PlayStartUV > 0 {
		result.CompleteRate = float64(result.PlayCompleteUV) / float64(result.PlayStartUV)
	}
	return result, nil
}

func GetAnalyticsTrend(from time.Time, to time.Time, contentType string, scene string) ([]AnalyticsTrendPoint, error) {
	var rows []struct {
		BucketHour time.Time `gorm:"column:bucket_hour"`
		EventType  string    `gorm:"column:event_type"`
		PV         int64     `gorm:"column:pv"`
		UV         int64     `gorm:"column:uv"`
	}

	q := db.GetDB().Table("event_stats_hourly").
		Where("bucket_hour >= ? AND bucket_hour < ?", from, to)
	if contentType != "" {
		q = q.Where("content_type = ?", contentType)
	}
	if scene != "" {
		q = q.Where("scene = ?", scene)
	}

	if err := q.Select("bucket_hour, event_type, SUM(pv) AS pv, SUM(uv) AS uv").
		Group("bucket_hour, event_type").
		Order("bucket_hour ASC").
		Find(&rows).Error; err != nil {
		return nil, err
	}

	points := make(map[int64]*AnalyticsTrendPoint)
	for bucket := from.Truncate(time.Hour); bucket.Before(to); bucket = bucket.Add(time.Hour) {
		key := bucket.Unix()
		points[key] = &AnalyticsTrendPoint{BucketHour: bucket}
	}

	for _, row := range rows {
		key := row.BucketHour.Truncate(time.Hour).Unix()
		point, ok := points[key]
		if !ok {
			point = &AnalyticsTrendPoint{BucketHour: row.BucketHour.Truncate(time.Hour)}
			points[key] = point
		}
		switch row.EventType {
		case "exposure":
			point.ExposurePV += row.PV
			point.ExposureUV += row.UV
		case "click":
			point.ClickPV += row.PV
			point.ClickUV += row.UV
		case "play_start":
			point.PlayStartPV += row.PV
			point.PlayStartUV += row.UV
		case "play_complete":
			point.PlayCompletePV += row.PV
			point.PlayCompleteUV += row.UV
		}
	}

	result := make([]AnalyticsTrendPoint, 0, len(points))
	keys := make([]int64, 0, len(points))
	for key := range points {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool { return keys[i] < keys[j] })

	for _, key := range keys {
		point := points[key]
		if point.ExposurePV > 0 {
			point.CTR = float64(point.ClickPV) / float64(point.ExposurePV)
		}
		if point.PlayStartUV > 0 {
			point.CompleteRate = float64(point.PlayCompleteUV) / float64(point.PlayStartUV)
		}
		result = append(result, *point)
	}

	return result, nil
}

func GetAnalyticsTopContent(eventType string, from time.Time, to time.Time, contentType string, scene string, limit int) ([]AnalyticsTopContent, error) {
	var rows []AnalyticsTopContent

	q := db.GetDB().Table("event_stats_hourly").
		Select("content_type, content_id, SUM(pv) AS pv, SUM(uv) AS uv").
		Where("event_type = ? AND bucket_hour >= ? AND bucket_hour < ?", eventType, from, to).
		Group("content_type, content_id").
		Order("pv DESC")
	if contentType != "" {
		q = q.Where("content_type = ?", contentType)
	}
	if scene != "" {
		q = q.Where("scene = ?", scene)
	}
	if limit > 0 {
		q = q.Limit(limit)
	}

	if err := q.Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}
