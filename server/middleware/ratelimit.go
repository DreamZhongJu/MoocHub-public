package middleware

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/utils"
	"context"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type RateLimitOptions struct {
	Name          string
	Limit         int
	Window        time.Duration
	KeyFn         func(*gin.Context) string
	SkipOnNoRedis bool
}

func RateLimitMiddleware(opts RateLimitOptions) gin.HandlerFunc {
	if opts.Limit <= 0 {
		opts.Limit = 100
	}
	if opts.Window <= 0 {
		opts.Window = time.Minute
	}
	if strings.TrimSpace(opts.Name) == "" {
		opts.Name = "default"
	}
	if opts.KeyFn == nil {
		opts.KeyFn = func(c *gin.Context) string {
			return c.ClientIP()
		}
	}

	return func(c *gin.Context) {
		client := cache.Client()
		if client == nil {
			if opts.SkipOnNoRedis {
				c.Next()
				return
			}
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"msg":      "服务限流中，请稍后再试",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		subject := strings.TrimSpace(opts.KeyFn(c))
		if subject == "" {
			subject = c.ClientIP()
		}

		now := time.Now().UTC().Unix()
		windowSec := int64(opts.Window / time.Second)
		if windowSec <= 0 {
			windowSec = 60
		}
		slot := now / windowSec
		key := fmt.Sprintf("ratelimit:%s:%s:%d", opts.Name, subject, slot)

		ctx, cancel := context.WithTimeout(c.Request.Context(), 1200*time.Millisecond)
		defer cancel()
		count, err := client.Incr(ctx, key).Result()
		if err != nil {
			c.Next()
			return
		}
		if count == 1 {
			_ = client.Expire(ctx, key, opts.Window+5*time.Second).Err()
		}

		remain := opts.Limit - int(count)
		if remain < 0 {
			remain = 0
		}
		c.Header("X-RateLimit-Limit", strconv.Itoa(opts.Limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remain))

		if int(count) > opts.Limit {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"msg":      "请求过于频繁，请稍后再试",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}
		c.Next()
	}
}

func KeyByIP(c *gin.Context) string {
	return c.ClientIP()
}

func KeyByUserOrIP(c *gin.Context) string {
	if v, ok := c.Get("user_id"); ok {
		return fmt.Sprintf("u:%v", v)
	}
	return "ip:" + c.ClientIP()
}
