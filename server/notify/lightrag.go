package notify

import (
	"MOOCHUB-server/resilience"
	"MOOCHUB-server/utils"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

type LightRAGSyncClient struct {
	endpoint   string
	token      string
	httpClient *http.Client
	breaker    *resilience.CircuitBreaker
}

type LightRAGSyncRequest struct {
	SourceType string `json:"source_type"`
	BizID      int64  `json:"biz_id"`
	SourceID   string `json:"source_id"`
	Action     string `json:"action"`
	Status     string `json:"status,omitempty"`
	Source     any    `json:"source,omitempty"`
}

func NewLightRAGSyncClient(endpoint, token string, timeout time.Duration, failureThreshold int, openTimeout time.Duration) *LightRAGSyncClient {
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	return &LightRAGSyncClient{
		endpoint: strings.TrimSpace(endpoint),
		token:    strings.TrimSpace(token),
		httpClient: &http.Client{
			Timeout: timeout,
		},
		breaker: resilience.NewCircuitBreaker(failureThreshold, openTimeout),
	}
}

func (c *LightRAGSyncClient) Enabled() bool {
	return c != nil && c.endpoint != ""
}

func (c *LightRAGSyncClient) Sync(ctx context.Context, req LightRAGSyncRequest) error {
	if c == nil || c.httpClient == nil {
		return errors.New("LightRAG sync client not initialized")
	}
	if c.endpoint == "" {
		return errors.New("LightRAG sync endpoint is empty")
	}
	if req.SourceType == "" || req.BizID <= 0 || req.Action == "" {
		return errors.New("invalid LightRAG sync request")
	}

	if c.breaker == nil {
		return c.syncOnce(ctx, req)
	}
	return c.breaker.Execute(func() error {
		return utils.Retry(ctx, 3, 150*time.Millisecond, 1200*time.Millisecond, shouldRetryLightRAGError, func() error {
			return c.syncOnce(ctx, req)
		})
	})
}

func (c *LightRAGSyncClient) syncOnce(ctx context.Context, req LightRAGSyncRequest) error {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		httpReq.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return &lightRAGSyncError{
			StatusCode: resp.StatusCode,
			Body:       string(respBody),
		}
	}
	return nil
}

type lightRAGSyncError struct {
	StatusCode int
	Body       string
}

func (e *lightRAGSyncError) Error() string {
	return fmt.Sprintf("LightRAG sync failed: status=%d body=%s", e.StatusCode, e.Body)
}

func shouldRetryLightRAGError(err error) bool {
	var nerr net.Error
	if errors.As(err, &nerr) {
		return true
	}
	var serr *lightRAGSyncError
	if errors.As(err, &serr) {
		if serr.StatusCode == http.StatusTooManyRequests {
			return true
		}
		return serr.StatusCode >= 500
	}
	return false
}
