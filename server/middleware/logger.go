package middleware

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/global"
	"MOOCHUB-server/utils"
	"errors"
	"fmt"
	"hash/fnv"
	"net"
	"net/http"
	"net/http/httputil"
	"os"
	"runtime/debug"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func GinLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		traceID := utils.GetTraceID(c)
		userID, hasUserID := c.Get("user_id")

		writeColoredConsoleLine(c, status, latency, path, query)

		fields := []zap.Field{
			zap.String("trace_id", traceID),
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.String("query", query),
			zap.String("ip", c.ClientIP()),
			zap.String("user_agent", c.Request.UserAgent()),
			zap.Duration("latency", latency),
			zap.Int("resp_bytes", c.Writer.Size()),
		}
		if hasUserID {
			fields = append(fields, zap.Any("user_id", userID))
		}
		if errMsg := c.Errors.ByType(gin.ErrorTypePrivate).String(); errMsg != "" {
			fields = append(fields, zap.String("errors", errMsg))
		}

		slowThreshold := config.LogSlowRequestThreshold()
		sampleRate := config.LogAccessSampleRate()
		if !shouldWriteAccessLog(status, latency, slowThreshold, traceID, sampleRate) {
			return
		}

		switch {
		case status >= http.StatusInternalServerError:
			global.Log.Error("http_request", fields...)
		case status >= http.StatusBadRequest:
			global.Log.Warn("http_request", fields...)
		default:
			global.Log.Info("http_request", fields...)
		}
	}
}

func writeColoredConsoleLine(c *gin.Context, status int, latency time.Duration, path, query string) {
	params := gin.LogFormatterParams{
		Request:      c.Request,
		TimeStamp:    time.Now(),
		StatusCode:   status,
		Latency:      latency,
		ClientIP:     c.ClientIP(),
		Method:       c.Request.Method,
		Path:         path,
		ErrorMessage: c.Errors.ByType(gin.ErrorTypePrivate).String(),
		BodySize:     c.Writer.Size(),
	}
	statusColor := params.StatusCodeColor()
	methodColor := params.MethodColor()
	resetColor := params.ResetColor()
	requestURI := path
	if query != "" {
		requestURI = path + "?" + query
	}

	_, _ = fmt.Fprintf(
		gin.DefaultWriter,
		"[HTTP] %s | %s%3d%s | %12v | %15s | %s%-7s%s %q\n",
		params.TimeStamp.Format("2006/01/02 - 15:04:05"),
		statusColor, status, resetColor,
		latency,
		params.ClientIP,
		methodColor, params.Method, resetColor,
		requestURI,
	)
}

func shouldWriteAccessLog(status int, latency time.Duration, slowThreshold time.Duration, traceID string, sampleRate float64) bool {
	if status >= http.StatusBadRequest {
		return true
	}
	if slowThreshold > 0 && latency >= slowThreshold {
		return true
	}
	return sampleByTrace(traceID, sampleRate)
}

func sampleByTrace(traceID string, rate float64) bool {
	if rate >= 1 {
		return true
	}
	if rate <= 0 {
		return false
	}
	if traceID == "" {
		return true
	}
	hasher := fnv.New32a()
	_, _ = hasher.Write([]byte(traceID))
	bucket := float64(hasher.Sum32()%10000) / 10000.0
	return bucket < rate
}

func GinRecovery(stack bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if rec := recover(); rec != nil {
				traceID := utils.GetTraceID(c)
				brokenPipe := false
				var netErr *net.OpError
				if errors.As(asError(rec), &netErr) {
					var syscallErr *os.SyscallError
					if errors.As(netErr.Err, &syscallErr) {
						msg := strings.ToLower(syscallErr.Error())
						if strings.Contains(msg, "broken pipe") || strings.Contains(msg, "connection reset by peer") {
							brokenPipe = true
						}
					}
				}

				httpRequest, _ := httputil.DumpRequest(c.Request, false)
				fields := []zap.Field{
					zap.String("trace_id", traceID),
					zap.Any("error", rec),
					zap.String("request", string(httpRequest)),
				}
				if stack {
					fields = append(fields, zap.String("stack", string(debug.Stack())))
				}

				if brokenPipe {
					global.Log.Warn("panic_broken_pipe", fields...)
					_ = c.Error(asError(rec))
					c.Abort()
					return
				}

				global.Log.Error("panic_recovered", fields...)
				c.AbortWithStatus(http.StatusInternalServerError)
			}
		}()
		c.Next()
	}
}

func asError(v interface{}) error {
	if err, ok := v.(error); ok {
		return err
	}
	return fmt.Errorf("%v", v)
}
