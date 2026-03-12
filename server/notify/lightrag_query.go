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

type LightRAGQueryClient struct {
	endpoint   string
	token      string
	httpClient *http.Client
	breaker    *resilience.CircuitBreaker
}

type LightRAGQueryRequest struct {
	Query     string `json:"query"`
	Mode      string `json:"mode,omitempty"`
	Scope     string `json:"scope,omitempty"`
	CourseID  int64  `json:"course_id,omitempty"`
	ArticleID int64  `json:"article_id,omitempty"`
	TopK      int    `json:"top_k,omitempty"`
	TraceID   string `json:"trace_id,omitempty"`
}

type LightRAGQuerySource struct {
	SourceID   string  `json:"source_id"`
	SourceType string  `json:"source_type"`
	BizID      int64   `json:"biz_id"`
	Title      string  `json:"title,omitempty"`
	SourceURL  string  `json:"source_url,omitempty"`
	Snippet    string  `json:"snippet,omitempty"`
	Score      float64 `json:"score,omitempty"`
}

type LightRAGQueryResponse struct {
	Answer     string                `json:"answer"`
	Sources    []LightRAGQuerySource `json:"sources,omitempty"`
	Entities   []string              `json:"entities,omitempty"`
	ModeUsed   string                `json:"mode_used,omitempty"`
	Confidence float64               `json:"confidence,omitempty"`
	Raw        map[string]any        `json:"raw,omitempty"`
}

func NewLightRAGQueryClient(endpoint, token string, timeout time.Duration, failureThreshold int, openTimeout time.Duration) *LightRAGQueryClient {
	if timeout <= 0 {
		timeout = 8 * time.Second
	}
	return &LightRAGQueryClient{
		endpoint: strings.TrimSpace(endpoint),
		token:    strings.TrimSpace(token),
		httpClient: &http.Client{
			Timeout: timeout,
		},
		breaker: resilience.NewCircuitBreaker(failureThreshold, openTimeout),
	}
}

func (c *LightRAGQueryClient) Enabled() bool {
	return c != nil && c.endpoint != ""
}

func (c *LightRAGQueryClient) Query(ctx context.Context, req LightRAGQueryRequest) (*LightRAGQueryResponse, error) {
	if c == nil || c.httpClient == nil {
		return nil, errors.New("LightRAG query client not initialized")
	}
	if c.endpoint == "" {
		return nil, errors.New("LightRAG query endpoint is empty")
	}
	if strings.TrimSpace(req.Query) == "" {
		return nil, errors.New("query is empty")
	}

	var out *LightRAGQueryResponse
	run := func() error {
		resp, err := c.queryOnce(ctx, req)
		if err != nil {
			return err
		}
		out = resp
		return nil
	}
	if c.breaker == nil {
		if err := run(); err != nil {
			return nil, err
		}
		return out, nil
	}
	err := c.breaker.Execute(func() error {
		return utils.Retry(ctx, 2, 120*time.Millisecond, 800*time.Millisecond, shouldRetryLightRAGQueryError, run)
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *LightRAGQueryClient) queryOnce(ctx context.Context, req LightRAGQueryRequest) (*LightRAGQueryResponse, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		httpReq.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return nil, &lightRAGQueryError{
			StatusCode: resp.StatusCode,
			Body:       string(respBody),
		}
	}

	var out LightRAGQueryResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

type lightRAGQueryError struct {
	StatusCode int
	Body       string
}

func (e *lightRAGQueryError) Error() string {
	return fmt.Sprintf("LightRAG query failed: status=%d body=%s", e.StatusCode, e.Body)
}

func shouldRetryLightRAGQueryError(err error) bool {
	var nerr net.Error
	if errors.As(err, &nerr) {
		return true
	}
	var serr *lightRAGQueryError
	if errors.As(err, &serr) {
		if serr.StatusCode == http.StatusTooManyRequests {
			return true
		}
		return serr.StatusCode >= 500
	}
	return false
}
