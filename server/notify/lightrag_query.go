package notify

import (
	"MOOCHUB-server/db"
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
	"strconv"
	"strings"
	"time"
)

const lightRAGSnippetLimit = 320

type LightRAGQueryClient struct {
	endpoint          string
	dataEndpoint      string
	token             string
	httpClient        *http.Client
	breaker           *resilience.CircuitBreaker
	allowDataFallback bool
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
	SourceID   string   `json:"source_id"`
	SourceType string   `json:"source_type"`
	BizID      int64    `json:"biz_id"`
	Title      string   `json:"title,omitempty"`
	SourceURL  string   `json:"source_url,omitempty"`
	Snippet    string   `json:"snippet,omitempty"`
	Score      *float64 `json:"score,omitempty"`
}

type LightRAGQueryResponse struct {
	Answer     string                `json:"answer"`
	Sources    []LightRAGQuerySource `json:"sources,omitempty"`
	Entities   []string              `json:"entities,omitempty"`
	ModeUsed   string                `json:"mode_used,omitempty"`
	Confidence *float64              `json:"confidence,omitempty"`
	Raw        map[string]any        `json:"raw,omitempty"`
}

type lightRAGNativeQueryRequest struct {
	Query             string `json:"query"`
	Mode              string `json:"mode,omitempty"`
	TopK              int    `json:"top_k,omitempty"`
	IncludeReferences bool   `json:"include_references,omitempty"`
}

type lightRAGNativeQueryResponse struct {
	Response   string                    `json:"response"`
	References []lightRAGNativeReference `json:"references,omitempty"`
}

type lightRAGNativeReference struct {
	ReferenceID string   `json:"reference_id"`
	FilePath    string   `json:"file_path"`
	Content     []string `json:"content,omitempty"`
}

type lightRAGNativeQueryDataResponse struct {
	Status   string                  `json:"status"`
	Message  string                  `json:"message"`
	Data     lightRAGNativeQueryData `json:"data"`
	Metadata map[string]any          `json:"metadata,omitempty"`
}

type lightRAGNativeQueryData struct {
	Entities      []lightRAGNativeEntity      `json:"entities,omitempty"`
	Relationships []map[string]any            `json:"relationships,omitempty"`
	Chunks        []lightRAGNativeChunk       `json:"chunks,omitempty"`
	References    []lightRAGNativeReferenceID `json:"references,omitempty"`
}

type lightRAGNativeEntity struct {
	EntityName  string `json:"entity_name"`
	FilePath    string `json:"file_path"`
	ReferenceID string `json:"reference_id"`
}

type lightRAGNativeChunk struct {
	Content     string `json:"content"`
	FilePath    string `json:"file_path"`
	ChunkID     string `json:"chunk_id"`
	ReferenceID string `json:"reference_id"`
}

type lightRAGNativeReferenceID struct {
	ReferenceID string `json:"reference_id"`
	FilePath    string `json:"file_path"`
}

func NewLightRAGQueryClient(endpoint, token string, timeout time.Duration, failureThreshold int, openTimeout time.Duration) *LightRAGQueryClient {
	if timeout <= 0 {
		timeout = 120 * time.Second
	}
	trimmed := strings.TrimSpace(endpoint)
	return &LightRAGQueryClient{
		endpoint:          trimmed,
		dataEndpoint:      deriveLightRAGQueryDataEndpoint(trimmed),
		token:             strings.TrimSpace(token),
		httpClient:        &http.Client{Timeout: timeout},
		breaker:           resilience.NewCircuitBreaker(failureThreshold, openTimeout),
		allowDataFallback: true,
	}
}

func deriveLightRAGQueryDataEndpoint(endpoint string) string {
	endpoint = strings.TrimSpace(endpoint)
	endpoint = strings.TrimRight(endpoint, "/")
	if strings.HasSuffix(endpoint, "/query") {
		return endpoint + "/data"
	}
	return endpoint + "/data"
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
	nativeReq := lightRAGNativeQueryRequest{
		Query:             buildLightRAGScopedQuery(req),
		Mode:              req.Mode,
		TopK:              req.TopK,
		IncludeReferences: true,
	}

	queryResp, err := c.doQueryRequest(ctx, c.endpoint, nativeReq)
	if err != nil {
		return nil, err
	}

	var dataResp *lightRAGNativeQueryDataResponse
	if c.dataEndpoint != "" {
		dataResp, err = c.doQueryDataRequest(ctx, c.dataEndpoint, nativeReq)
		if err != nil && !c.allowDataFallback {
			return nil, err
		}
	}

	return buildUnifiedLightRAGQueryResponse(req, queryResp, dataResp), nil
}

func buildLightRAGScopedQuery(req LightRAGQueryRequest) string {
	query := strings.TrimSpace(req.Query)
	if query == "" {
		return ""
	}

	switch req.Scope {
	case "article":
		if req.ArticleID > 0 {
			return fmt.Sprintf(
				"[scope=article:%d]\n请仅基于 article:%d 对应的知识内容回答，不要混入其他文章或课程内容。\n问题：%s",
				req.ArticleID,
				req.ArticleID,
				query,
			)
		}
	case "course":
		if req.CourseID > 0 {
			return fmt.Sprintf(
				"[scope=course:%d]\n请仅基于 course:%d 对应的课程与视频知识回答，不要混入其他课程或文章内容。\n问题：%s",
				req.CourseID,
				req.CourseID,
				query,
			)
		}
	}

	return query
}

func (c *LightRAGQueryClient) doQueryRequest(ctx context.Context, endpoint string, req lightRAGNativeQueryRequest) (*lightRAGNativeQueryResponse, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		httpReq.Header.Set("X-API-Key", c.token)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return nil, &lightRAGQueryError{StatusCode: resp.StatusCode, Body: string(respBody)}
	}
	var out lightRAGNativeQueryResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *LightRAGQueryClient) doQueryDataRequest(ctx context.Context, endpoint string, req lightRAGNativeQueryRequest) (*lightRAGNativeQueryDataResponse, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if c.token != "" {
		httpReq.Header.Set("X-API-Key", c.token)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return nil, &lightRAGQueryError{StatusCode: resp.StatusCode, Body: string(respBody)}
	}
	var out lightRAGNativeQueryDataResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}

func buildUnifiedLightRAGQueryResponse(req LightRAGQueryRequest, queryResp *lightRAGNativeQueryResponse, dataResp *lightRAGNativeQueryDataResponse) *LightRAGQueryResponse {
	out := &LightRAGQueryResponse{
		Answer:   strings.TrimSpace(queryResp.Response),
		ModeUsed: req.Mode,
		Raw: map[string]any{
			"query_response": queryResp,
		},
	}
	if dataResp != nil {
		out.Raw["query_data"] = dataResp
		if mode, ok := dataResp.Metadata["query_mode"].(string); ok && strings.TrimSpace(mode) != "" {
			out.ModeUsed = strings.TrimSpace(mode)
		}
	}
	out.Sources = mergeLightRAGSources(queryResp, dataResp)
	out.Entities = collectLightRAGEntities(dataResp)
	return out
}

func mergeLightRAGSources(queryResp *lightRAGNativeQueryResponse, dataResp *lightRAGNativeQueryDataResponse) []LightRAGQuerySource {
	sources := map[string]*LightRAGQuerySource{}

	upsert := func(filePath, snippet string) {
		filePath = strings.TrimSpace(filePath)
		if filePath == "" {
			return
		}
		item, ok := sources[filePath]
		if !ok {
			sourceType, bizID := parseLightRAGFileSource(filePath)
			item = &LightRAGQuerySource{
				SourceID:   filePath,
				SourceType: sourceType,
				BizID:      bizID,
				Title:      resolveLightRAGSourceTitle(sourceType, bizID, filePath),
				SourceURL:  buildSourceURL(sourceType, bizID),
			}
			sources[filePath] = item
		}
		if item.Snippet == "" && strings.TrimSpace(snippet) != "" {
			item.Snippet = trimLightRAGSnippet(snippet)
		}
	}

	for _, ref := range queryResp.References {
		upsert(ref.FilePath, strings.Join(ref.Content, "\n"))
	}
	if dataResp != nil {
		for _, chunk := range dataResp.Data.Chunks {
			upsert(chunk.FilePath, chunk.Content)
		}
		for _, ref := range dataResp.Data.References {
			upsert(ref.FilePath, "")
		}
	}

	items := make([]LightRAGQuerySource, 0, len(sources))
	for _, item := range sources {
		items = append(items, *item)
	}
	return items
}

func resolveLightRAGSourceTitle(sourceType string, bizID int64, fallback string) string {
	fallback = strings.TrimSpace(fallback)
	if bizID <= 0 || db.GetDB() == nil {
		return fallback
	}
	switch sourceType {
	case "article":
		article, err := model.GetArticleByID(bizID)
		if err == nil && strings.TrimSpace(article.Title) != "" {
			return strings.TrimSpace(article.Title)
		}
	case "course":
		course, err := model.GetCourseByID(bizID)
		if err == nil && strings.TrimSpace(course.Title) != "" {
			return strings.TrimSpace(course.Title)
		}
	case "video":
		video, err := model.GetVideoDetails(bizID)
		if err == nil && strings.TrimSpace(video.Title) != "" {
			return strings.TrimSpace(video.Title)
		}
	}
	return fallback
}

func trimLightRAGSnippet(snippet string) string {
	snippet = strings.TrimSpace(snippet)
	if snippet == "" {
		return ""
	}
	runes := []rune(snippet)
	if len(runes) <= lightRAGSnippetLimit {
		return snippet
	}
	return strings.TrimSpace(string(runes[:lightRAGSnippetLimit])) + "..."
}

func collectLightRAGEntities(dataResp *lightRAGNativeQueryDataResponse) []string {
	if dataResp == nil {
		return nil
	}
	seen := make(map[string]struct{}, len(dataResp.Data.Entities))
	items := make([]string, 0, len(dataResp.Data.Entities))
	for _, entity := range dataResp.Data.Entities {
		name := strings.TrimSpace(entity.EntityName)
		if name == "" {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		items = append(items, name)
	}
	return items
}

func parseLightRAGFileSource(fileSource string) (string, int64) {
	parts := strings.SplitN(strings.TrimSpace(fileSource), ":", 2)
	if len(parts) != 2 {
		return "", 0
	}
	bizID, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64)
	if err != nil || bizID <= 0 {
		return strings.TrimSpace(parts[0]), 0
	}
	return strings.TrimSpace(parts[0]), bizID
}

func buildSourceURL(sourceType string, bizID int64) string {
	if bizID <= 0 {
		return ""
	}
	switch sourceType {
	case "course":
		return "/api/v1/courses/" + strconv.FormatInt(bizID, 10)
	case "video":
		return "/api/v1/videos/" + strconv.FormatInt(bizID, 10)
	case "article":
		return "/api/v1/articles/" + strconv.FormatInt(bizID, 10)
	default:
		return ""
	}
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
