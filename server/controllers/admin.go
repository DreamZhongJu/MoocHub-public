package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"context"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AdminController struct{}

func (ac AdminController) CreateCourse(c *gin.Context) {
	categoryIDStr := c.DefaultPostForm("category_id", "")
	title := c.DefaultPostForm("title", "")
	summary := c.DefaultPostForm("summary", "")
	coverURL := c.DefaultPostForm("cover_url", "")
	instructor := c.DefaultPostForm("instructor_name", "")
	level := c.DefaultPostForm("level", "")
	status := c.DefaultPostForm("status", "draft")
	if categoryIDStr == "" || title == "" || summary == "" || coverURL == "" || instructor == "" || level == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	categoryID, err := strconv.ParseInt(categoryIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "category_id不合法")
		return
	}

	course := &model.Courses{
		CategoryID: categoryID,
		Title:      title,
		Summary:    summary,
		CoverURL:   coverURL,
		Instructor: instructor,
		Level:      level,
		Status:     status,
	}
	if err := model.CreateCourse(course); err != nil {
		ReturnError(c, 500, "创建课程失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = cache.DeleteByPattern(ctx, "courses:list:*", 100)
	}
	ReturnSuccess(c, 200, "创建成功", gin.H{"course": course}, 0)
}

func (ac AdminController) UpdateCourse(c *gin.Context) {
	idStr := c.Param("id")
	if idStr == "" {
		ReturnError(c, 400, "id不能为空")
		return
	}
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "id不合法")
		return
	}

	updates := map[string]any{}
	if v := c.DefaultPostForm("category_id", ""); v != "" {
		categoryID, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			ReturnError(c, 400, "category_id不合法")
			return
		}
		updates["category_id"] = categoryID
	}
	if v := c.DefaultPostForm("title", ""); v != "" {
		updates["title"] = v
	}
	if v := c.DefaultPostForm("summary", ""); v != "" {
		updates["summary"] = v
	}
	if v := c.DefaultPostForm("cover_url", ""); v != "" {
		updates["cover_url"] = v
	}
	if v := c.DefaultPostForm("instructor_name", ""); v != "" {
		updates["instructor_name"] = v
	}
	if v := c.DefaultPostForm("level", ""); v != "" {
		updates["level"] = v
	}
	if v := c.DefaultPostForm("status", ""); v != "" {
		updates["status"] = v
	}
	if len(updates) == 0 {
		ReturnError(c, 400, "未提供可更新字段")
		return
	}

	if err := model.UpdateCourse(id, updates); err != nil {
		ReturnError(c, 500, "更新课程失败："+err.Error())
		return
	}

	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Del(ctx, "courses:detail:"+idStr).Err()
		_ = cache.DeleteByPattern(ctx, "courses:list:*", 100)
	}

	ReturnSuccess(c, 200, "更新成功", nil, 0)
}

func (ac AdminController) DeleteCourse(c *gin.Context) {
	idStr := c.Param("id")
	if idStr == "" {
		ReturnError(c, 400, "id不能为空")
		return
	}
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "id不合法")
		return
	}
	if err := model.DeleteCourse(id); err != nil {
		ReturnError(c, 500, "删除课程失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Del(ctx, "courses:detail:"+idStr).Err()
		_ = cache.DeleteByPattern(ctx, "courses:list:*", 100)
	}
	ReturnSuccess(c, 200, "删除成功", nil, 0)
}

func (ac AdminController) CreateVideo(c *gin.Context) {
	courseIDStr := c.DefaultPostForm("course_id", "")
	title := c.DefaultPostForm("title", "")
	description := c.DefaultPostForm("description", "")
	durationStr := c.DefaultPostForm("duration_sec", "")
	videoURL := c.DefaultPostForm("video_url", "")
	thumbURL := c.DefaultPostForm("thumb_url", "")
	sortStr := c.DefaultPostForm("sort_order", "0")
	if courseIDStr == "" || title == "" || durationStr == "" || videoURL == "" || thumbURL == "" {
		ReturnError(c, 400, "参数不能为空")
		return
	}
	courseID, err := strconv.ParseInt(courseIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "course_id不合法")
		return
	}
	duration, err := strconv.Atoi(durationStr)
	if err != nil {
		ReturnError(c, 400, "duration_sec不合法")
		return
	}
	sortOrder, err := strconv.Atoi(sortStr)
	if err != nil {
		ReturnError(c, 400, "sort_order不合法")
		return
	}

	video := &model.Video{
		CourseID:    courseID,
		Title:       title,
		Description: description,
		DurationSec: duration,
		VideoURL:    videoURL,
		ThumbURL:    thumbURL,
		SortOrder:   sortOrder,
	}
	if err := model.CreateVideo(video); err != nil {
		ReturnError(c, 500, "创建视频失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		_ = client.Del(ctx, fmt.Sprintf("courses:detail:%d", courseID)).Err()
	}
	ReturnSuccess(c, 200, "创建成功", gin.H{"video": video}, 0)
}

func (ac AdminController) UpdateVideo(c *gin.Context) {
	idStr := c.Param("id")
	if idStr == "" {
		ReturnError(c, 400, "id不能为空")
		return
	}
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "id不合法")
		return
	}

	updates := map[string]any{}
	oldCourseID := int64(0)
	if oldVideo, err := model.GetVideoDetails(id); err == nil {
		oldCourseID = oldVideo.CourseID
	}
	newCourseID := int64(0)
	hasNewCourse := false
	if v := c.DefaultPostForm("course_id", ""); v != "" {
		courseID, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			ReturnError(c, 400, "course_id不合法")
			return
		}
		updates["course_id"] = courseID
		newCourseID = courseID
		hasNewCourse = true
	}
	if v := c.DefaultPostForm("title", ""); v != "" {
		updates["title"] = v
	}
	if v := c.DefaultPostForm("description", ""); v != "" {
		updates["description"] = v
	}
	if v := c.DefaultPostForm("duration_sec", ""); v != "" {
		duration, err := strconv.Atoi(v)
		if err != nil {
			ReturnError(c, 400, "duration_sec不合法")
			return
		}
		updates["duration_sec"] = duration
	}
	if v := c.DefaultPostForm("video_url", ""); v != "" {
		updates["video_url"] = v
	}
	if v := c.DefaultPostForm("thumb_url", ""); v != "" {
		updates["thumb_url"] = v
	}
	if v := c.DefaultPostForm("sort_order", ""); v != "" {
		sortOrder, err := strconv.Atoi(v)
		if err != nil {
			ReturnError(c, 400, "sort_order不合法")
			return
		}
		updates["sort_order"] = sortOrder
	}
	if len(updates) == 0 {
		ReturnError(c, 400, "未提供可更新字段")
		return
	}

	if err := model.UpdateVideo(id, updates); err != nil {
		ReturnError(c, 500, "更新视频失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil {
		ctx := context.Background()
		if oldCourseID != 0 {
			_ = client.Del(ctx, fmt.Sprintf("courses:detail:%d", oldCourseID)).Err()
		}
		if hasNewCourse && newCourseID != 0 && newCourseID != oldCourseID {
			_ = client.Del(ctx, fmt.Sprintf("courses:detail:%d", newCourseID)).Err()
		}
	}
	ReturnSuccess(c, 200, "更新成功", nil, 0)
}

func (ac AdminController) DeleteVideo(c *gin.Context) {
	idStr := c.Param("id")
	if idStr == "" {
		ReturnError(c, 400, "id不能为空")
		return
	}
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "id不合法")
		return
	}
	courseID := int64(0)
	if oldVideo, err := model.GetVideoDetails(id); err == nil {
		courseID = oldVideo.CourseID
	}
	if err := model.DeleteVideo(id); err != nil {
		ReturnError(c, 500, "删除视频失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil && courseID != 0 {
		ctx := context.Background()
		_ = client.Del(ctx, fmt.Sprintf("courses:detail:%d", courseID)).Err()
	}
	ReturnSuccess(c, 200, "删除成功", nil, 0)
}

func (ac AdminController) DeleteComment(c *gin.Context) {
	commentID := c.Param("id")
	if commentID == "" {
		ReturnError(c, 400, "comment id不能为空")
		return
	}
	if err := model.SoftDeleteComment(commentID); err != nil {
		ReturnError(c, 500, "删除评论失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "删除成功", nil, 0)
}
