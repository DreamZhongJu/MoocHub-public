package controllers

import (
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type SearchController struct{}

func (sc SearchController) Search(c *gin.Context) {
	keyword := strings.TrimSpace(c.Query("keyword"))
	if keyword == "" {
		ReturnError(c, 400, "keyword is required")
		return
	}

	scope := strings.ToLower(strings.TrimSpace(c.DefaultQuery("scope", "all")))
	if scope != "all" && scope != "course" && scope != "article" {
		scope = "all"
	}
	sort := strings.ToLower(strings.TrimSpace(c.DefaultQuery("sort", "default")))

	categoryIDStr := c.DefaultQuery("category_id", "0")
	categoryID, err := strconv.ParseInt(categoryIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid category_id")
		return
	}

	page := 1
	if raw := c.DefaultQuery("page", "1"); raw != "" {
		p, err := strconv.Atoi(raw)
		if err != nil || p <= 0 {
			ReturnError(c, 400, "invalid page")
			return
		}
		page = p
	}

	pageSize := 10
	if raw := c.DefaultQuery("page_size", "10"); raw != "" {
		ps, err := strconv.Atoi(raw)
		if err != nil || ps <= 0 {
			ReturnError(c, 400, "invalid page_size")
			return
		}
		if ps > 50 {
			ps = 50
		}
		pageSize = ps
	}

	courses := []model.Courses{}
	articles := []model.Article{}
	var totalCourses int64
	var totalArticles int64

	if scope == "all" || scope == "course" {
		nextCourses, total, err := model.SearchCourses(keyword, categoryID, sort, page, pageSize)
		if err != nil {
			ReturnError(c, 500, "search courses failed: "+err.Error())
			return
		}
		for i := range nextCourses {
			if url, err := storage.ResolveObjectURL(nextCourses[i].CoverURL); err == nil && url != "" {
				nextCourses[i].CoverURL = url
			}
		}
		courses = nextCourses
		totalCourses = total
	}

	if scope == "all" || scope == "article" {
		nextArticles, total, err := model.SearchArticles(keyword, sort, page, pageSize)
		if err != nil {
			ReturnError(c, 500, "search articles failed: "+err.Error())
			return
		}
		for i := range nextArticles {
			if url, err := storage.ResolveObjectURL(nextArticles[i].CoverURL); err == nil && url != "" {
				nextArticles[i].CoverURL = url
			}
		}
		articles = nextArticles
		totalArticles = total
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"keyword":        keyword,
		"scope":          scope,
		"sort":           sort,
		"page":           page,
		"page_size":      pageSize,
		"total_courses":  totalCourses,
		"total_articles": totalArticles,
		"courses":        courses,
		"articles":       articles,
	}, totalCourses+totalArticles)
}

func (sc SearchController) Suggest(c *gin.Context) {
	keyword := strings.TrimSpace(c.Query("keyword"))
	if keyword == "" {
		ReturnSuccess(c, 200, "ok", gin.H{
			"keyword":     keyword,
			"suggestions": []string{},
		}, 0)
		return
	}

	limit := 8
	if raw := c.DefaultQuery("limit", "8"); raw != "" {
		v, err := strconv.Atoi(raw)
		if err != nil || v <= 0 {
			ReturnError(c, 400, "invalid limit")
			return
		}
		if v > 20 {
			v = 20
		}
		limit = v
	}

	suggestions, err := model.SearchSuggestions(keyword, limit)
	if err != nil {
		ReturnError(c, 500, "search suggest failed: "+err.Error())
		return
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"keyword":     keyword,
		"suggestions": suggestions,
	}, int64(len(suggestions)))
}
