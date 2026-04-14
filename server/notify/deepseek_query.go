package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type DeepSeekClient struct {
	baseURL    string
	apiKey     string
	model      string
	httpClient *http.Client
}

type DeepSeekQueryRequest struct {
	Query     string
	Mode      string
	Scope     string
	CourseID  int64
	ArticleID int64
	TraceID   string
	Context   *DeepSeekContext
}

type DeepSeekContext struct {
	SourceID   string
	SourceType string
	BizID      int64
	Title      string
	Summary    string
	Content    string
	SourceURL  string
}

type DeepSeekQueryResponse struct {
	Answer string
	Model  string
}

type deepSeekMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type deepSeekChatRequest struct {
	Model       string            `json:"model"`
	Messages    []deepSeekMessage `json:"messages"`
	Temperature float64           `json:"temperature,omitempty"`
}

type deepSeekChatResponse struct {
	ID      string `json:"id"`
	Model   string `json:"model"`
	Choices []struct {
		Message deepSeekMessage `json:"message"`
	} `json:"choices"`
}

func NewDeepSeekClient(baseURL, apiKey, model string, timeout time.Duration) *DeepSeekClient {
	if timeout <= 0 {
		timeout = 120 * time.Second
	}
	baseURL = strings.TrimSpace(strings.TrimRight(baseURL, "/"))
	if strings.TrimSpace(model) == "" {
		model = "deepseek-chat"
	}
	return &DeepSeekClient{
		baseURL:    baseURL,
		apiKey:     strings.TrimSpace(apiKey),
		model:      strings.TrimSpace(model),
		httpClient: &http.Client{Timeout: timeout},
	}
}

func (c *DeepSeekClient) Enabled() bool {
	return c != nil && c.baseURL != "" && c.apiKey != ""
}

func (c *DeepSeekClient) Query(ctx context.Context, req DeepSeekQueryRequest) (*DeepSeekQueryResponse, error) {
	if c == nil || c.httpClient == nil {
		return nil, errors.New("DeepSeek client not initialized")
	}
	if c.baseURL == "" {
		return nil, errors.New("DeepSeek API base URL is empty")
	}
	if c.apiKey == "" {
		return nil, errors.New("DeepSeek API key is empty")
	}
	if strings.TrimSpace(req.Query) == "" {
		return nil, errors.New("query is empty")
	}

	apiReq := deepSeekChatRequest{
		Model:       c.model,
		Messages:    buildDeepSeekMessages(req),
		Temperature: 0.2,
	}
	payload, err := json.Marshal(apiReq)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 4*1024*1024))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("DeepSeek query failed: status=%d body=%s", resp.StatusCode, string(body))
	}

	var out deepSeekChatResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, err
	}
	if len(out.Choices) == 0 {
		return nil, errors.New("DeepSeek query failed: empty choices")
	}

	return &DeepSeekQueryResponse{
		Answer: strings.TrimSpace(out.Choices[0].Message.Content),
		Model:  strings.TrimSpace(out.Model),
	}, nil
}

func buildDeepSeekMessages(req DeepSeekQueryRequest) []deepSeekMessage {
	systemPrompt := "你是在线学习社区的智能学习助教。请使用简体中文回答，优先输出准确、结构化、可学习的内容。"

	scopeHint := buildDeepSeekScopeHint(req)
	contextBlock := buildDeepSeekContextBlock(req.Context)

	userPrompt := strings.TrimSpace(req.Query)
	if contextBlock != "" {
		userPrompt = contextBlock + "\n\n用户问题：\n" + userPrompt
	}
	if scopeHint != "" {
		userPrompt = scopeHint + "\n\n" + userPrompt
	}

	return []deepSeekMessage{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userPrompt},
	}
}

func buildDeepSeekScopeHint(req DeepSeekQueryRequest) string {
	switch strings.TrimSpace(req.Scope) {
	case "course":
		if req.CourseID > 0 {
			return fmt.Sprintf("当前上下文：course_id=%d。请尽量围绕该课程相关内容作答。", req.CourseID)
		}
	case "article":
		if req.ArticleID > 0 {
			return fmt.Sprintf("当前上下文：article_id=%d。请尽量围绕该文章相关内容作答。", req.ArticleID)
		}
	}
	return ""
}

func buildDeepSeekContextBlock(ctx *DeepSeekContext) string {
	if ctx == nil {
		return ""
	}
	content := strings.TrimSpace(ctx.Content)
	if content == "" {
		return ""
	}
	if len(content) > 6000 {
		content = content[:6000] + "\n...(内容已截断)"
	}

	lines := []string{
		"【学习内容上下文】",
		fmt.Sprintf("source_id: %s", strings.TrimSpace(ctx.SourceID)),
		fmt.Sprintf("source_type: %s", strings.TrimSpace(ctx.SourceType)),
		fmt.Sprintf("biz_id: %d", ctx.BizID),
	}
	if strings.TrimSpace(ctx.Title) != "" {
		lines = append(lines, "title: "+strings.TrimSpace(ctx.Title))
	}
	if strings.TrimSpace(ctx.Summary) != "" {
		lines = append(lines, "summary: "+strings.TrimSpace(ctx.Summary))
	}
	if strings.TrimSpace(ctx.SourceURL) != "" {
		lines = append(lines, "source_url: "+strings.TrimSpace(ctx.SourceURL))
	}
	lines = append(lines, "content:")
	lines = append(lines, content)
	return strings.Join(lines, "\n")
}
