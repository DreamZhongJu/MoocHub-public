package notify

import (
	"MOOCHUB-server/model"
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

var ErrLightRAGDeleteUnsupported = errors.New("LightRAG native delete is not supported without doc id mapping")

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

type lightRAGNativeTextRequest struct {
	Text       string `json:"text"`
	FileSource string `json:"file_source"`
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
	if req.Action == "delete" {
		return ErrLightRAGDeleteUnsupported
	}

	nativeReq, err := buildLightRAGNativeTextRequest(req)
	if err != nil {
		return err
	}

	if c.breaker == nil {
		return c.syncOnce(ctx, nativeReq)
	}
	return c.breaker.Execute(func() error {
		return utils.Retry(ctx, 3, 150*time.Millisecond, 1200*time.Millisecond, shouldRetryLightRAGError, func() error {
			return c.syncOnce(ctx, nativeReq)
		})
	})
}

func buildLightRAGNativeTextRequest(req LightRAGSyncRequest) (lightRAGNativeTextRequest, error) {
	src, err := normalizeKnowledgeSource(req.Source)
	if err != nil {
		return lightRAGNativeTextRequest{}, err
	}
	text := buildLightRAGSyncText(src)
	if strings.TrimSpace(text) == "" {
		return lightRAGNativeTextRequest{}, errors.New("knowledge source content is empty")
	}
	return lightRAGNativeTextRequest{
		Text:       text,
		FileSource: strings.TrimSpace(req.SourceID),
	}, nil
}

func normalizeKnowledgeSource(source any) (*model.KnowledgeSource, error) {
	if source == nil {
		return nil, errors.New("knowledge source is nil")
	}
	if ks, ok := source.(*model.KnowledgeSource); ok && ks != nil {
		return ks, nil
	}
	if ks, ok := source.(model.KnowledgeSource); ok {
		return &ks, nil
	}
	body, err := json.Marshal(source)
	if err != nil {
		return nil, err
	}
	var ks model.KnowledgeSource
	if err := json.Unmarshal(body, &ks); err != nil {
		return nil, err
	}
	return &ks, nil
}

func buildLightRAGSyncText(src *model.KnowledgeSource) string {
	parts := make([]string, 0, 8)
	if v := strings.TrimSpace(src.Title); v != "" {
		parts = append(parts, "Title: "+v)
	}
	if v := strings.TrimSpace(src.Summary); v != "" {
		parts = append(parts, "Summary: "+v)
	}
	if v := strings.TrimSpace(src.Content); v != "" {
		parts = append(parts, "Content:\n"+v)
	}
	if len(src.Tags) > 0 {
		filtered := make([]string, 0, len(src.Tags))
		for _, tag := range src.Tags {
			tag = strings.TrimSpace(tag)
			if tag != "" {
				filtered = append(filtered, tag)
			}
		}
		if len(filtered) > 0 {
			parts = append(parts, "Tags: "+strings.Join(filtered, ", "))
		}
	}
	if v := strings.TrimSpace(src.SourceURL); v != "" {
		parts = append(parts, "SourceURL: "+v)
	}
	return strings.TrimSpace(strings.Join(parts, "\n\n"))
}

func (c *LightRAGSyncClient) syncOnce(ctx context.Context, req lightRAGNativeTextRequest) error {
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
		httpReq.Header.Set("X-API-Key", c.token)
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
