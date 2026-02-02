package controllers

import (
	"MOOCHUB-server/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

type CommentController struct{}

func (u CommentController) GetComments(c *gin.Context) {
	targetType := c.Query("target_type")
	targetIDStr := c.Query("target_id")
	if targetType == "" || targetIDStr == "" {
		ReturnError(c, 400, "target_type或target_id不能为空")
		return
	}
	targetID, err := strconv.ParseInt(targetIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "target_id不合法")
		return
	}
	page, _ := strconv.ParseInt(c.DefaultQuery("page", "1"), 10, 64)
	pageSize, _ := strconv.ParseInt(c.DefaultQuery("page_size", "10"), 10, 64)

	items, total, err := model.GetCommentsPaginated(targetType, targetID, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"items": items,
		"total": total,
		"page":  page,
		"size":  pageSize,
	}, 0)
}

func (u CommentController) CreateComment(c *gin.Context) {
	targetType := c.PostForm("target_type")
	targetIDStr := c.PostForm("target_id")
	content := c.PostForm("content")
	if targetType == "" || targetIDStr == "" || content == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	targetID, err := strconv.ParseInt(targetIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "target_id不合法")
		return
	}
	userID := c.GetInt64("user_id")
	comment, err := model.CreateComment(targetType, targetID, userID, content)
	if err != nil {
		ReturnError(c, 500, "发布失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "发布成功", gin.H{"comment": comment}, 0)
}

func (u CommentController) LikeComment(c *gin.Context) {
	commentID := c.Param("id")
	if commentID == "" {
		ReturnError(c, 400, "comment id不能为空")
		return
	}
	likeCount, err := model.IncrementLike(commentID)
	if err != nil {
		ReturnError(c, 500, "点赞失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "点赞成功", gin.H{"like_count": likeCount}, 0)
}
