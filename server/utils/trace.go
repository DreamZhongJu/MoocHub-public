package utils

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	HeaderTraceID     = "X-Trace-Id"
	ContextTraceIDKey = "trace_id"
)

type traceContextKey string

const traceIDCtxKey traceContextKey = "trace_id"

func NewTraceID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "trace-fallback"
	}
	return hex.EncodeToString(b[:])
}

func NormalizeTraceID(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" || len(raw) > 64 {
		return ""
	}
	for _, r := range raw {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			continue
		}
		return ""
	}
	return raw
}

func SetTraceID(c *gin.Context, traceID string) {
	c.Set(ContextTraceIDKey, traceID)
	c.Writer.Header().Set(HeaderTraceID, traceID)
	c.Request.Header.Set(HeaderTraceID, traceID)
	c.Request = c.Request.WithContext(WithTraceID(c.Request.Context(), traceID))
}

func GetTraceID(c *gin.Context) string {
	if v, ok := c.Get(ContextTraceIDKey); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func WithTraceID(ctx context.Context, traceID string) context.Context {
	if strings.TrimSpace(traceID) == "" {
		return ctx
	}
	return context.WithValue(ctx, traceIDCtxKey, traceID)
}

func TraceIDFromContext(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	if v := ctx.Value(traceIDCtxKey); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
