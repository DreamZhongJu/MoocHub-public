package middleware

import (
	"MOOCHUB-server/utils"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(401, gin.H{
				"msg":      "请求未携带token",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		claims, err := utils.ParseToken(authHeader)
		if err != nil {
			c.AbortWithStatusJSON(401, gin.H{
				"msg":      "Token无效或已过期: " + err.Error(),
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		c.Set("user_id", int64(claims.UserID))
		c.Next()
	}
}

func AdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(401, gin.H{
				"msg":      "请求未携带token",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		claims, err := utils.ParseToken(authHeader)
		if err != nil {
			c.AbortWithStatusJSON(401, gin.H{
				"msg":      "Token无效或已过期: " + err.Error(),
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		if claims.Role != "admin" {
			c.AbortWithStatusJSON(403, gin.H{
				"msg":      "无管理员权限",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		c.Set("user_id", int64(claims.UserID))
		c.Next()
	}
}
