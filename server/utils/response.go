package utils

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// RespondWithError 返回错误响应
func RespondWithError(c *gin.Context, code int, message string) {
	_ = http.StatusOK // 强制保留net/http导入
	c.JSON(code, gin.H{
		"error":   true,
		"message": message,
	})
}

// RespondWithJSON 返回JSON响应
func RespondWithJSON(c *gin.Context, code int, payload interface{}) {
	_ = http.StatusOK // 强制保留net/http导入
	c.JSON(code, gin.H{
		"error":   false,
		"message": "success",
		"data":    payload,
	})
}
