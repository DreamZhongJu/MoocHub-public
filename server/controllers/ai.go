package controllers

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/model"
	"MOOCHUB-server/notify"
	"MOOCHUB-server/utils"
	"context"
	"strings"

	"github.com/gin-gonic/gin"
)

type AIController struct{}

type aiQueryRequest struct {
	Query     string `json:"query"`
	Mode      string `json:"mode"`
	Scope     string `json:"scope"`
	CourseID  int64  `json:"course_id"`
	ArticleID int64  `json:"article_id"`
	TopK      int    `json:"top_k"`
}

var (
	allowedLightRAGModes = map[string]struct{}{
		"":       {},
		"local":  {},
		"global": {},
		"hybrid": {},
		"mix":    {},
		"naive":  {},
	}
	allowedLightRAGScopes = map[string]struct{}{
		"":        {},
		"all":     {},
		"course":  {},
		"article": {},
	}
)

func (AIController) Query(c *gin.Context) {
	var req aiQueryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		ReturnError(c, 400, "invalid request body")
		return
	}

	req.Query = strings.TrimSpace(req.Query)
	req.Mode = normalizeLightRAGValue(req.Mode)
	req.Scope = normalizeLightRAGValue(req.Scope)
	if req.Query == "" {
		ReturnError(c, 400, "query is required")
		return
	}
	if _, ok := allowedLightRAGModes[req.Mode]; !ok {
		ReturnError(c, 400, "invalid mode")
		return
	}
	if _, ok := allowedLightRAGScopes[req.Scope]; !ok {
		ReturnError(c, 400, "invalid scope")
		return
	}
	if req.CourseID > 0 && req.ArticleID > 0 {
		ReturnError(c, 400, "course_id and article_id cannot both be set")
		return
	}
	if req.Scope == "course" && req.CourseID <= 0 {
		ReturnError(c, 400, "course_id is required when scope=course")
		return
	}
	if req.Scope == "article" && req.ArticleID <= 0 {
		ReturnError(c, 400, "article_id is required when scope=article")
		return
	}
	if req.TopK < 0 || req.TopK > 20 {
		ReturnError(c, 400, "top_k must be between 0 and 20")
		return
	}

	var sourceCtx *model.KnowledgeSource
	switch req.Scope {
	case "article":
		item, err := model.GetKnowledgeSourceByID(model.KnowledgeSourceTypeArticle, req.ArticleID, "")
		if err != nil {
			if model.IsKnowledgeSourceNotFound(err) {
				ReturnError(c, 404, "article not found")
				return
			}
			ReturnError(c, 500, "load article context failed")
			return
		}
		sourceCtx = item
	case "course":
		item, err := model.GetKnowledgeSourceByID(model.KnowledgeSourceTypeCourse, req.CourseID, "")
		if err != nil {
			if model.IsKnowledgeSourceNotFound(err) {
				ReturnError(c, 404, "course not found")
				return
			}
			ReturnError(c, 500, "load course context failed")
			return
		}
		sourceCtx = item
	}

	client := notify.NewDeepSeekClient(
		config.DeepSeekAPIBaseURL(),
		config.DeepSeekAPIKey(),
		config.DeepSeekModel(),
		config.DeepSeekTimeout(),
	)
	if !client.Enabled() {
		ReturnError(c, 503, "DeepSeek API is not configured")
		return
	}

	out, err := client.Query(context.Background(), notify.DeepSeekQueryRequest{
		Query:     req.Query,
		Mode:      req.Mode,
		Scope:     req.Scope,
		CourseID:  req.CourseID,
		ArticleID: req.ArticleID,
		TraceID:   utils.GetTraceID(c),
		Context:   toDeepSeekContext(sourceCtx),
	})
	if err != nil {
		ReturnError(c, 502, "DeepSeek query failed: "+err.Error())
		return
	}

	sources := []gin.H{}
	if sourceCtx != nil {
		sources = append(sources, gin.H{
			"source_id":   sourceCtx.SourceID,
			"source_type": sourceCtx.SourceType,
			"biz_id":      sourceCtx.BizID,
			"title":       sourceCtx.Title,
			"source_url":  sourceCtx.SourceURL,
			"snippet":     sourceCtx.Summary,
		})
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"answer":     out.Answer,
		"sources":    sources,
		"entities":   []any{},
		"mode_used":  "deepseek",
		"confidence": nil,
		"raw": gin.H{
			"provider":          "deepseek",
			"model":             out.Model,
			"context_source_id": pickSourceID(sourceCtx),
		},
	}, 0)
}

func normalizeLightRAGValue(v string) string {
	return strings.ToLower(strings.TrimSpace(v))
}

func toDeepSeekContext(src *model.KnowledgeSource) *notify.DeepSeekContext {
	if src == nil {
		return nil
	}
	return &notify.DeepSeekContext{
		SourceID:   src.SourceID,
		SourceType: src.SourceType,
		BizID:      src.BizID,
		Title:      src.Title,
		Summary:    src.Summary,
		Content:    src.Content,
		SourceURL:  src.SourceURL,
	}
}

func pickSourceID(src *model.KnowledgeSource) string {
	if src == nil {
		return ""
	}
	return src.SourceID
}
