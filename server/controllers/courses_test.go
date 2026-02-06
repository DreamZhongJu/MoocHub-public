package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
)

func TestGetCourses_CacheHit(t *testing.T) {
	gin.SetMode(gin.TestMode)

	mr, err := miniredis.Run()
	if err != nil {
		t.Fatalf("start miniredis: %v", err)
	}
	defer mr.Close()

	t.Setenv("REDIS_ADDR", mr.Addr())
	t.Setenv("REDIS_DB", "0")

	if err := cache.InitRedis(); err != nil {
		t.Fatalf("init redis: %v", err)
	}
	defer func() {
		_ = cache.CloseRedis()
	}()

	now := time.Date(2026, 2, 6, 0, 0, 0, 0, time.UTC)
	courses := []model.Courses{
		{
			ID:            1,
			CategoryID:    2,
			Title:         "Test Course",
			Summary:       "Summary",
			CoverURL:      "cover.png",
			Instructor:    "Instructor",
			Level:         "beginner",
			Status:        "published",
			ViewCount:     10,
			FavoriteCount: 2,
			CreatedAt:     now,
			UpdatedAt:     now,
		},
	}

	cached, err := json.Marshal(courses)
	if err != nil {
		t.Fatalf("marshal courses: %v", err)
	}

	cacheKey := "courses:list:cat:0:sort:default:page:1:size:10"
	mr.Set(cacheKey, string(cached))

	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest("GET", "/api/v1/courses?category_id=0&sort=default&page=1&page_size=10", nil)

	var controller CoursesController
	controller.GetCourses(c)

	if w.Code != 200 {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp struct {
		Code int `json:"Code"`
		Data struct {
			Courses []model.Courses `json:"courses"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("expected Code 200, got %d", resp.Code)
	}
	if len(resp.Data.Courses) != 1 {
		t.Fatalf("expected 1 course, got %d", len(resp.Data.Courses))
	}
	if resp.Data.Courses[0].ID != courses[0].ID {
		t.Fatalf("expected course id %d, got %d", courses[0].ID, resp.Data.Courses[0].ID)
	}
	if resp.Data.Courses[0].Title != courses[0].Title {
		t.Fatalf("expected title %q, got %q", courses[0].Title, resp.Data.Courses[0].Title)
	}
}
