package middleware

import (
	"MOOCHUB-server/utils"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestAuthMiddleware_MissingToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/protected", AuthMiddleware(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestAuthMiddleware_ValidTokenPasses(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := utils.GenerateToken(8, "student")
	if err != nil {
		t.Fatalf("generate token: %v", err)
	}

	r := gin.New()
	r.GET("/protected", AuthMiddleware(), func(c *gin.Context) {
		uid, ok := c.Get("user_id")
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"msg": "missing user_id"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"user_id": uid})
	})

	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%s", w.Code, w.Body.String())
	}
}

func TestAdminMiddleware_RejectsNonAdmin(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := utils.GenerateToken(9, "student")
	if err != nil {
		t.Fatalf("generate token: %v", err)
	}

	r := gin.New()
	r.GET("/admin", AdminMiddleware(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	req := httptest.NewRequest(http.MethodGet, "/admin", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", w.Code)
	}
}
