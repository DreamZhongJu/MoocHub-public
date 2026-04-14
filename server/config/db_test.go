package config

import "testing"

func TestDisableCourseListCache(t *testing.T) {
	t.Setenv("DISABLE_COURSE_LIST_CACHE", "true")
	if !DisableCourseListCache() {
		t.Fatal("expected course list cache to be disabled")
	}

	t.Setenv("DISABLE_COURSE_LIST_CACHE", "false")
	if DisableCourseListCache() {
		t.Fatal("expected course list cache to remain enabled")
	}
}
