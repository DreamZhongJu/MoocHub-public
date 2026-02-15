package middleware

import (
	"MOOCHUB-server/utils"

	"github.com/gin-gonic/gin"
)

func TraceIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		traceID := utils.NormalizeTraceID(c.GetHeader(utils.HeaderTraceID))
		if traceID == "" {
			traceID = utils.NewTraceID()
		}
		utils.SetTraceID(c, traceID)
		c.Next()
	}
}
