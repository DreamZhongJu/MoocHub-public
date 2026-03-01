package middleware

import (
	"MOOCHUB-server/utils"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	ContextUserID   = "user_id"
	ContextUserRole = "user_role"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		claims, ok := parseAndSetClaims(c)
		if !ok {
			return
		}

		c.Set(ContextUserID, int64(claims.UserID))
		c.Set(ContextUserRole, normalizeRole(claims.Role))
		c.Next()
	}
}

func AdminMiddleware() gin.HandlerFunc {
	return RoleMiddleware("admin")
}

func RoleMiddleware(allowedRoles ...string) gin.HandlerFunc {
	allowed := make(map[string]struct{}, len(allowedRoles))
	for _, role := range allowedRoles {
		role = normalizeRole(role)
		if role == "" {
			continue
		}
		allowed[role] = struct{}{}
	}

	return func(c *gin.Context) {
		claims, ok := parseAndSetClaims(c)
		if !ok {
			return
		}

		role := normalizeRole(claims.Role)
		if _, pass := allowed[role]; !pass {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"msg":      "permission denied",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		c.Set(ContextUserID, int64(claims.UserID))
		c.Set(ContextUserRole, role)
		c.Next()
	}
}

func parseAndSetClaims(c *gin.Context) (*utils.Claims, bool) {
	authHeader := c.GetHeader("Authorization")
	if strings.TrimSpace(authHeader) == "" {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
			"msg":      "missing authorization token",
			"trace_id": utils.GetTraceID(c),
		})
		return nil, false
	}

	claims, err := utils.ParseToken(authHeader)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
			"msg":      "invalid token: " + err.Error(),
			"trace_id": utils.GetTraceID(c),
		})
		return nil, false
	}
	return claims, true
}

func normalizeRole(role string) string {
	return strings.ToLower(strings.TrimSpace(role))
}
