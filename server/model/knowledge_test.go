package model

import (
	"strings"
	"testing"
	"time"
)

func TestBuildCourseKnowledgeSource(t *testing.T) {
	now := time.Date(2026, 3, 12, 10, 0, 0, 0, time.UTC)
	course := Courses{
		ID:         7,
		CategoryID: 2,
		Title:      "Go 并发编程",
		Summary:    "讲解 goroutine 与 channel",
		Instructor: "teacher-a",
		Level:      "advanced",
		Status:     "published",
		UpdatedAt:  now,
	}

	item := buildCourseKnowledgeSource(course, "后端开发")
	if item.SourceID != "course:7" {
		t.Fatalf("unexpected source id: %s", item.SourceID)
	}
	if item.SourceType != KnowledgeSourceTypeCourse {
		t.Fatalf("unexpected source type: %s", item.SourceType)
	}
	if !strings.Contains(item.Content, "Go 并发编程") || !strings.Contains(item.Content, "goroutine") {
		t.Fatalf("unexpected content: %s", item.Content)
	}
	if len(item.Tags) == 0 {
		t.Fatalf("expected tags to be populated")
	}
	if item.SourceURL != "/api/v1/courses/7" {
		t.Fatalf("unexpected source url: %s", item.SourceURL)
	}
}

func TestBuildArticleKnowledgeSource(t *testing.T) {
	now := time.Date(2026, 3, 12, 10, 0, 0, 0, time.UTC)
	article := Article{
		ID:        3,
		UserID:    12,
		Title:     "Redis 缓存击穿",
		Summary:   "缓存热点保护策略",
		Content:   "介绍互斥锁和 stale 数据兜底。",
		Status:    "published",
		UpdatedAt: now,
	}

	item := buildArticleKnowledgeSource(article)
	if item.SourceID != "article:3" {
		t.Fatalf("unexpected source id: %s", item.SourceID)
	}
	if !strings.Contains(item.Content, "缓存热点保护策略") || !strings.Contains(item.Content, "互斥锁") {
		t.Fatalf("unexpected content: %s", item.Content)
	}
	if item.Metadata["user_id"] != int64(12) {
		t.Fatalf("unexpected metadata user_id: %#v", item.Metadata["user_id"])
	}
}
