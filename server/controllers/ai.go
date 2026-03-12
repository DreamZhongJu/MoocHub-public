package controllers

import (
	"MOOCHUB-server/config"
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

	client := notify.NewLightRAGQueryClient(
		config.LightRAGQueryURL(),
		config.LightRAGQueryToken(),
		config.LightRAGQueryTimeout(),
		config.BreakerFailureThreshold(),
		config.BreakerOpenTimeout(),
	)
	if !client.Enabled() {
		ReturnError(c, 503, "LightRAG query service is not configured")
		return
	}

	out, err := client.Query(context.Background(), notify.LightRAGQueryRequest{
		Query:     req.Query,
		Mode:      req.Mode,
		Scope:     req.Scope,
		CourseID:  req.CourseID,
		ArticleID: req.ArticleID,
		TopK:      req.TopK,
		TraceID:   utils.GetTraceID(c),
	})
	if err != nil {
		ReturnError(c, 502, "LightRAG query failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"answer":     out.Answer,
		"sources":    out.Sources,
		"entities":   out.Entities,
		"mode_used":  out.ModeUsed,
		"confidence": out.Confidence,
		"raw":        out.Raw,
	}, int64(len(out.Sources)))
}

func normalizeLightRAGValue(v string) string {
	return strings.ToLower(strings.TrimSpace(v))
}
