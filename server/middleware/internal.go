package middleware

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/utils"

	"github.com/gin-gonic/gin"
)

func InternalMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("X-Internal-Token")
		if token == "" || token != config.InternalToken() {
			c.AbortWithStatusJSON(403, gin.H{
				"msg":      "internal token invalid",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}
		c.Next()
	}
}
