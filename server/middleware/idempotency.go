package middleware

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/config"
	"MOOCHUB-server/utils"
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const idempotencyHeader = "Idempotency-Key"

type idempotencyRecord struct {
	Status int    `json:"status"`
	Body   []byte `json:"body"`
}

type bodyCaptureWriter struct {
	gin.ResponseWriter
	body bytes.Buffer
}

func (w *bodyCaptureWriter) Write(data []byte) (int, error) {
	_, _ = w.body.Write(data)
	return w.ResponseWriter.Write(data)
}

func IdempotencyMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method != http.MethodPost && c.Request.Method != http.MethodPut && c.Request.Method != http.MethodPatch && c.Request.Method != http.MethodDelete {
			c.Next()
			return
		}
		key := strings.TrimSpace(c.GetHeader(idempotencyHeader))
		if key == "" {
			c.Next()
			return
		}
		if len(key) > 128 {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{
				"msg":      "Idempotency-Key 太长",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		client := cache.Client()
		if client == nil {
			c.Next()
			return
		}

		userID, _ := c.Get("user_id")
		scope := c.ClientIP()
		if userID != nil {
			scope = "u:" + toString(userID)
		}
		hash := sha1.Sum([]byte(c.Request.Method + "|" + c.FullPath() + "|" + key + "|" + scope))
		recordKey := "idem:result:" + hex.EncodeToString(hash[:])
		lockKey := "idem:lock:" + hex.EncodeToString(hash[:])

		ctx, cancel := context.WithTimeout(c.Request.Context(), 1500*time.Millisecond)
		defer cancel()

		if data, err := client.Get(ctx, recordKey).Bytes(); err == nil && len(data) > 0 {
			var rec idempotencyRecord
			if json.Unmarshal(data, &rec) == nil && rec.Status > 0 {
				c.Header("X-Idempotent-Replay", "1")
				c.Data(rec.Status, "application/json; charset=utf-8", rec.Body)
				c.Abort()
				return
			}
		}

		locked, err := client.SetNX(ctx, lockKey, "1", 15*time.Second).Result()
		if err == nil && !locked {
			for i := 0; i < 8; i++ {
				time.Sleep(60 * time.Millisecond)
				if data, getErr := client.Get(ctx, recordKey).Bytes(); getErr == nil && len(data) > 0 {
					var rec idempotencyRecord
					if json.Unmarshal(data, &rec) == nil && rec.Status > 0 {
						c.Header("X-Idempotent-Replay", "1")
						c.Data(rec.Status, "application/json; charset=utf-8", rec.Body)
						c.Abort()
						return
					}
				}
			}
			c.AbortWithStatusJSON(http.StatusConflict, gin.H{
				"msg":      "重复请求处理中，请稍后重试",
				"trace_id": utils.GetTraceID(c),
			})
			return
		}

		if locked {
			defer client.Del(context.Background(), lockKey)
		}

		w := &bodyCaptureWriter{ResponseWriter: c.Writer}
		c.Writer = w
		c.Next()

		status := c.Writer.Status()
		if status >= 200 && status < 500 {
			rec := idempotencyRecord{
				Status: status,
				Body:   w.body.Bytes(),
			}
			if raw, mErr := json.Marshal(rec); mErr == nil {
				_ = client.Set(context.Background(), recordKey, raw, config.IdempotencyTTL()).Err()
			}
		}
	}
}

func toString(v interface{}) string {
	switch t := v.(type) {
	case string:
		return t
	case int:
		return strconv.Itoa(t)
	case int64:
		return strconv.FormatInt(t, 10)
	case uint:
		return strconv.FormatUint(uint64(t), 10)
	case uint64:
		return strconv.FormatUint(t, 10)
	default:
		return ""
	}
}
