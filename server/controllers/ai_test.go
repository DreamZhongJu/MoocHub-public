package controllers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestAIControllerQuery_ValidatesScopeAndIDs(t *testing.T) {
	gin.SetMode(gin.TestMode)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = httptest.NewRequest(http.MethodPost, "/api/v1/ai/query", strings.NewReader(`{"query":"test","scope":"course"}`))
	c.Request.Header.Set("Content-Type", "application/json")

	AIController{}.Query(c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "course_id is required") {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}

func TestAIControllerQuery_RejectsInvalidMode(t *testing.T) {
	gin.SetMode(gin.TestMode)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = httptest.NewRequest(http.MethodPost, "/api/v1/ai/query", strings.NewReader(`{"query":"test","mode":"bad-mode"}`))
	c.Request.Header.Set("Content-Type", "application/json")

	AIController{}.Query(c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "invalid mode") {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}
