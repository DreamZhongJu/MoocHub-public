package controllers

import (
    "MOOCHUB-server/model"
    "MOOCHUB-server/storage"
    "strconv"

    "github.com/gin-gonic/gin"
)

type ArticlesController struct{}

func (ac ArticlesController) GetArticles(c *gin.Context) {
    sort := c.DefaultQuery("sort", "default")
    page := c.DefaultQuery("page", "1")
    pageSize := c.DefaultQuery("page_size", "10")

    articles, err := model.GetArticles(sort, page, pageSize)
    if err != nil {
        ReturnError(c, 500, "get articles failed: "+err.Error())
        return
    }
    for i := range articles {
        if url, err := storage.ResolveObjectURL(articles[i].CoverURL); err == nil && url != "" {
            articles[i].CoverURL = url
        }
    }

    ReturnSuccess(c, 200, "ok", gin.H{
        "articles": articles,
    }, 0)
}

func (ac ArticlesController) GetArticleDetail(c *gin.Context) {
    idStr := c.Param("id")
    id, err := strconv.ParseInt(idStr, 10, 64)
    if err != nil {
        ReturnError(c, 400, "invalid article id")
        return
    }
    article, err := model.GetArticleByID(id)
    if err != nil {
        ReturnError(c, 500, "get article failed: "+err.Error())
        return
    }
    if url, err := storage.ResolveObjectURL(article.CoverURL); err == nil && url != "" {
        article.CoverURL = url
    }
    ReturnSuccess(c, 200, "ok", gin.H{
        "article": article,
    }, 0)
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
    ReturnSuccess(c, 200, "ok", gin.H{"article": article}, 0)
}

func (ac ArticlesController) LikeArticle(c *gin.Context) {
    idStr := c.Param("id")
    id, err := strconv.ParseInt(idStr, 10, 64)
    if err != nil {
        ReturnError(c, 400, "invalid article id")
        return
    }
    likeCount, err := model.IncrementArticleLikeCount(id)
    if err != nil {
        ReturnError(c, 500, "like article failed: "+err.Error())
        return
    }
    ReturnSuccess(c, 200, "ok", gin.H{
        "like_count": likeCount,
    }, 0)
}

func (ac ArticlesController) ViewArticle(c *gin.Context) {
    idStr := c.Param("id")
    id, err := strconv.ParseInt(idStr, 10, 64)
    if err != nil {
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
    ReturnSuccess(c, 200, "ok", gin.H{
        "view_count": article.ViewCount,
    }, 0)
}
