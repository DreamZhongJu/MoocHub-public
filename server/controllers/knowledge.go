package controllers

import (
	"MOOCHUB-server/model"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type KnowledgeController struct{}

const maxKnowledgePageSize = 100

func (kc KnowledgeController) ExportSources(c *gin.Context) {
	types := parseKnowledgeSourceTypes(c.DefaultQuery("types", "course,video,article"))
	if len(types) == 0 {
		ReturnError(c, 400, "unsupported knowledge source types")
		return
	}

	perTypeLimit, err := parsePageSizeOnly(c.DefaultQuery("per_type_limit", "100"), maxKnowledgePageSize)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	status := defaultKnowledgeStatus(c.DefaultQuery("status", "published"))
	itemsByType := make(map[string][]model.KnowledgeSource, len(types))
	counts := make(map[string]int, len(types))
	total := 0
	for _, sourceType := range types {
		items, listErr := model.ListKnowledgeSources(sourceType, 1, perTypeLimit, status)
		if listErr != nil {
			ReturnError(c, 500, "export knowledge sources failed: "+listErr.Error())
			return
		}
		itemsByType[sourceType] = items
		counts[sourceType] = len(items)
		total += len(items)
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"types":          types,
		"status":         status,
		"per_type_limit": perTypeLimit,
		"counts":         counts,
		"items_by_type":  itemsByType,
	}, int64(total))
}

func (kc KnowledgeController) ListSources(c *gin.Context) {
	sourceType := strings.TrimSpace(c.Param("type"))
	if !isSupportedKnowledgeSourceType(sourceType) {
		ReturnError(c, 400, "unsupported knowledge source type")
		return
	}

	page, pageSize, err := parsePageAndSize(c.DefaultQuery("page", "1"), c.DefaultQuery("page_size", "50"), maxKnowledgePageSize)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	status := defaultKnowledgeStatus(c.DefaultQuery("status", "published"))
	items, err := model.ListKnowledgeSources(sourceType, page, pageSize, status)
	if err != nil {
		ReturnError(c, 500, "list knowledge sources failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"source_type": sourceType,
		"status":      status,
		"page":        page,
		"page_size":   pageSize,
		"items":       items,
	}, int64(len(items)))
}

func (kc KnowledgeController) GetSourceDetail(c *gin.Context) {
	sourceType := strings.TrimSpace(c.Param("type"))
	if !isSupportedKnowledgeSourceType(sourceType) {
		ReturnError(c, 400, "unsupported knowledge source type")
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		ReturnError(c, 400, "invalid knowledge source id")
		return
	}

	status := defaultKnowledgeStatus(c.DefaultQuery("status", "published"))
	item, err := model.GetKnowledgeSourceByID(sourceType, id, status)
	if err != nil {
		if model.IsKnowledgeSourceNotFound(err) {
			ReturnError(c, 404, "knowledge source not found")
			return
		}
		ReturnError(c, 500, "get knowledge source failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"item": item,
	}, 1)
}

func isSupportedKnowledgeSourceType(sourceType string) bool {
	switch strings.ToLower(strings.TrimSpace(sourceType)) {
	case model.KnowledgeSourceTypeCourse, model.KnowledgeSourceTypeVideo, model.KnowledgeSourceTypeArticle:
		return true
	default:
		return false
	}
}

func defaultKnowledgeStatus(status string) string {
	status = strings.ToLower(strings.TrimSpace(status))
	if status == "" {
		return "published"
	}
	return status
}

func parseKnowledgeSourceTypes(raw string) []string {
	parts := strings.Split(raw, ",")
	seen := make(map[string]struct{}, len(parts))
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.ToLower(strings.TrimSpace(part))
		if !isSupportedKnowledgeSourceType(part) {
			continue
		}
		if _, ok := seen[part]; ok {
			continue
		}
		seen[part] = struct{}{}
		result = append(result, part)
	}
	return result
}

func parsePageSizeOnly(raw string, maxSize int) (int, error) {
	size, err := strconv.Atoi(raw)
	if err != nil || size <= 0 {
		return 0, errInvalid("invalid per_type_limit")
	}
	if size > maxSize {
		size = maxSize
	}
	return size, nil
}
