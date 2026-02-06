package controllers

import (
	"MOOCHUB-server/cache"
	"MOOCHUB-server/model"
	"MOOCHUB-server/storage"
	"context"
	"encoding/json"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type CoursesController struct{}

func (cc CoursesController) GetCourses(c *gin.Context) {
	categoryIDStr := c.DefaultQuery("category_id", "0")
	sort := c.DefaultQuery("sort", "default")
	page := c.DefaultQuery("page", "1")
	pageSize := c.DefaultQuery("page_size", "10")

	categoryID, err := strconv.ParseInt(categoryIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid category_id")
		return
	}

	cacheKey := "courses:list:cat:" + categoryIDStr + ":sort:" + sort + ":page:" + page + ":size:" + pageSize
	if client := cache.Client(); client != nil {
		if cached, err := client.Get(context.Background(), cacheKey).Result(); err == nil && cached != "" {
			var courses []model.Courses
			if jsonErr := json.Unmarshal([]byte(cached), &courses); jsonErr == nil {
				ReturnSuccess(c, 200, "获取成功", gin.H{
					"courses": courses,
				}, 0)
				return
			}
		}
	}

	courses, err := model.GetCoursesByCategory(categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程列表失败："+err.Error())
		return
	}
	if client := cache.Client(); client != nil {
		if data, err := json.Marshal(courses); err == nil {
			_ = client.Set(context.Background(), cacheKey, string(data), 2*time.Minute).Err()
		}
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
	}, 0)
}

func (cc CoursesController) GetCourseDetails(c *gin.Context) {
	id := c.Param("id")
	idInt, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid course id")
		return
	}
	cacheKey := "courses:detail:" + id
	if client := cache.Client(); client != nil {
		if cached, err := client.Get(context.Background(), cacheKey).Result(); err == nil && cached != "" {
			var payload struct {
				Courses []model.Courses `json:"courses"`
				Videos  []model.Video   `json:"videos"`
			}
			if jsonErr := json.Unmarshal([]byte(cached), &payload); jsonErr == nil {
				for i := range payload.Videos {
					if url, err := storage.ResolveObjectURL(payload.Videos[i].VideoURL); err == nil && url != "" {
						payload.Videos[i].VideoURL = url
					}
					if url, err := storage.ResolveObjectURL(payload.Videos[i].ThumbURL); err == nil && url != "" {
						payload.Videos[i].ThumbURL = url
					}
				}
				ReturnSuccess(c, 200, "获取成功", gin.H{
					"courses": payload.Courses,
					"videos":  payload.Videos,
				}, 0)
				return
			}
		}
	}

	course, err := model.GetCoursesDetails(idInt)
	if err != nil {
		ReturnError(c, 500, "获取课程详情失败："+err.Error())
		return
	}
	videos, err := model.GetVideosByCourseID(idInt)
	if err != nil {
		ReturnError(c, 500, "获取课程视频失败："+err.Error())
		return
	}
	for i := range videos {
		if url, err := storage.ResolveObjectURL(videos[i].VideoURL); err == nil && url != "" {
			videos[i].VideoURL = url
		}
		if url, err := storage.ResolveObjectURL(videos[i].ThumbURL); err == nil && url != "" {
			videos[i].ThumbURL = url
		}
	}
	if client := cache.Client(); client != nil {
		payload := struct {
			Courses []model.Courses `json:"courses"`
			Videos  []model.Video   `json:"videos"`
		}{
			Courses: course,
			Videos:  videos,
		}
		if data, err := json.Marshal(payload); err == nil {
			_ = client.Set(context.Background(), cacheKey, string(data), 2*time.Minute).Err()
		}
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": course,
		"videos":  videos,
	}, 0)
}

func (cc CoursesController) GetCoursesByCategoryID(c *gin.Context) {
	categoryIDStr := c.Param("id")
	sort := c.DefaultQuery("sort", "default")
	page := c.DefaultQuery("page", "1")
	pageSize := c.DefaultQuery("page_size", "10")

	categoryID, err := strconv.ParseInt(categoryIDStr, 10, 64)
	if err != nil {
		ReturnError(c, 400, "invalid category id")
		return
	}

	courses, err := model.GetCoursesByCategory(categoryID, sort, page, pageSize)
	if err != nil {
		ReturnError(c, 500, "获取课程列表失败："+err.Error())
		return
	}
	ReturnSuccess(c, 200, "获取成功", gin.H{
		"courses": courses,
	}, 0)
}
