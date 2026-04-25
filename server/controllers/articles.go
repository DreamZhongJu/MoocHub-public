package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"MOOCHUB-server/mq"
	"MOOCHUB-server/storage"
	"context"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type ArticlesController struct{}

const maxArticlePageSize = 50

func (ac ArticlesController) GetArticles(c *gin.Context) {
	sort := c.DefaultQuery("sort", "default")
	page, pageSize, err := parsePageAndSize(c.DefaultQuery("page", "1"), c.DefaultQuery("page_size", "10"), maxArticlePageSize)
	if err != nil {
		ReturnError(c, 400, err.Error())
		return
	}

	cacheKey := "articles:list:sort:" + sort + ":page:" + strconv.Itoa(page) + ":size:" + strconv.Itoa(pageSize)
	articles := make([]model.Article, 0)
	_, _, err = cache.FillJSONWithHotKey(
		c.Request.Context(),
		cacheKey,
		&articles,
		func(ctx context.Context) (interface{}, error) {
			return model.GetArticles(sort, strconv.Itoa(page), strconv.Itoa(pageSize))
		},
		cache.CacheLoadOptions{
			TTL:      2 * time.Minute,
			StaleTTL: 10 * time.Minute,
		},
	)
	if err != nil {
		ReturnError(c, 500, "get articles failed: "+err.Error())
		return
	}

	for i := range articles {
		if url, resolveErr := storage.ResolveClientObjectURL(articles[i].CoverURL); resolveErr == nil && url != "" {
			articles[i].CoverURL = url
		}
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"articles": articles,
	}, int64(len(articles)))
}

func (ac ArticlesController) GetArticleDetail(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		ReturnError(c, 400, "invalid article id")
		return
	}

	cacheKey := "articles:detail:" + strconv.FormatInt(id, 10)
	article := model.Article{}
	_, _, err = cache.FillJSONWithHotKey(
		c.Request.Context(),
		cacheKey,
		&article,
		func(ctx context.Context) (interface{}, error) {
			return model.GetArticleByID(id)
		},
		cache.CacheLoadOptions{
			TTL:      2 * time.Minute,
			StaleTTL: 10 * time.Minute,
		},
	)
	if err != nil {
		ReturnError(c, 500, "get article failed: "+err.Error())
		return
	}

	if url, resolveErr := storage.ResolveClientObjectURL(article.CoverURL); resolveErr == nil && url != "" {
		article.CoverURL = url
	}
	ReturnSuccess(c, 200, "ok", gin.H{
		"article": article,
	}, 1)
}

func (ac ArticlesController) CreateArticle(c *gin.Context) {
	userID := c.GetInt64("user_id")
	title := c.DefaultPostForm("title", "")
	summary := c.DefaultPostForm("summary", "")
	coverURL := c.DefaultPostForm("cover_url", "")
	content := c.DefaultPostForm("content", "")
	status := c.DefaultPostForm("status", "published")
	if title == "" || summary == "" || content == "" {
		ReturnError(c, 400, "missing required fields")
		return
	}

	article := &model.Article{
		UserID:   userID,
		Title:    title,
		Summary:  summary,
		CoverURL: coverURL,
		Content:  content,
		Status:   status,
	}
	if err := model.CreateArticle(article); err != nil {
		ReturnError(c, 500, "create article failed: "+err.Error())
		return
	}
	publishArticleKnowledgeSync(c, article, mq.KnowledgeSyncActionUpsert)

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = cache.DeleteByPattern(ctx, "articles:list:*", 100)
	}

	ReturnSuccess(c, 200, "ok", gin.H{"article": article}, 1)
}

func (ac ArticlesController) LikeArticle(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		ReturnError(c, 400, "invalid article id")
		return
	}
	likeCount, err := model.IncrementArticleLikeCount(id)
	if err != nil {
		ReturnError(c, 500, "like article failed: "+err.Error())
		return
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Del(ctx, "articles:detail:"+strconv.FormatInt(id, 10)).Err()
		_ = cache.DeleteByPattern(ctx, "articles:list:*", 100)
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"like_count": likeCount,
	}, 1)
}

func (ac ArticlesController) ViewArticle(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		ReturnError(c, 400, "invalid article id")
		return
	}
	if err := model.IncrementArticleViewCount(id); err != nil {
		ReturnError(c, 500, "view article failed: "+err.Error())
		return
	}
	article, err := model.GetArticleByID(id)
	if err != nil {
		ReturnError(c, 500, "view article failed: "+err.Error())
		return
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Del(ctx, "articles:detail:"+strconv.FormatInt(id, 10)).Err()
		_ = cache.DeleteByPattern(ctx, "articles:list:*", 100)
	}

	ReturnSuccess(c, 200, "ok", gin.H{
		"view_count": article.ViewCount,
	}, 1)
}
