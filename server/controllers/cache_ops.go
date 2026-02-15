package controllers

import (
	"MOOCHUB-server/workers"
	"strings"

	"github.com/gin-gonic/gin"
)

type CacheOpsController struct{}

func (co CacheOpsController) Prewarm(c *gin.Context) {
	trigger := strings.TrimSpace(c.DefaultPostForm("trigger", "manual"))
	if trigger == "" {
		trigger = "manual"
	}
	workers.RunCacheWarmupNow("api:" + trigger)
	ReturnSuccess(c, 200, "cache prewarm done", gin.H{
		"trigger": trigger,
	}, 1)
}
